#!/usr/bin/env node
'use strict';
// UserPromptSubmit hook: surface THIS session's own CURRENT-TASK (project + session scoped, via hook-state.js)
// when it has unchecked "- [ ]" items. Reads ONLY this session's CURRENT-TASK.<sid>.md — never a bare cwd file
// and never a machine-global one — so a task from another project/session in the same folder can't be injected.
//
// Added 2026-07-03 (two more mechanical, no-judgment-required durable-file fixes):
//  (a) PROMPT_LOG: every incoming prompt gets appended verbatim to PROMPT_LOG.<sid>.md. This is the
//      raw ask, unlosable to a compact-summary paraphrase or a re-derived goal — the sweep found one
//      session re-derived its own overarching goal from scratch ~20 times because it lived only in
//      rolling compact summaries. A hook can't judge WHAT matters in a prompt; it can just never lose it.
//  (b) needs-approval surfacing: if /longrun's watcher logged anything to
//      .longrun-needs-approval.<sid>.md while unattended (a dontAsk denial or an auto-mode classifier
//      block), inject it as additionalContext so it's impossible to miss on the next prompt, then
//      archive it (append to .SURFACED.md, delete the live file) so it doesn't repeat forever.
//  (c) recent hook-timeout surfacing (added after the parts-cache stall /investigate, 2026-07-03): a
//      PreToolUse hook that TIMES OUT (Claude Code emits a "hook_cancelled" attachment, timedOut:true)
//      has the same practical effect as a hook CRASHING -- its check never ran for that tool call. This
//      is silent otherwise; a hook has no way to detect its OWN cancellation from inside itself. Scan the
//      tail of THIS session's own transcript for recent timeouts on the security-critical PreToolUse:Bash
//      hooks and surface it, instead of it sitting invisibly in the JSONL.
//
// Added 2026-07-07 (skill-compliance sweep, "The Fix" proposal, applied on Douglas's explicit go-ahead):
// the sweep found an 11% unprompted skill-invocation rate (7 of 62 clear moments) -- brainstorming/
// systematic-debugging/impeccable routinely skipped when the prompt itself plainly called for one. Added
// HERE, as one more check in this same UserPromptSubmit hook, rather than as a new standalone hook file:
// this machine's own hook-error sweep (same day) found "Cannot find module" failures under concurrent-
// process load, and spawning a 34th separate node.exe per prompt only makes that contention worse. Scope
// is intentionally narrow: only patterns detectable from the HUMAN's prompt text. verification-before-
// completion's trigger ("about to claim work is complete") is about Claude's own forthcoming response, not
// anything present in the user's message, so a UserPromptSubmit hook structurally cannot catch it -- not
// attempted here, not silently pretended to cover it either.
const path = require('path');
const fs = require('fs');
const S = require(path.join(__dirname, 'hook-state.js'));

const MAX_LOG_ENTRY = 4000; // cap a single pasted prompt so one giant paste can't bloat the log unboundedly
const SECURITY_HOOK_NAMES = ['block-secret-dump', 'check-secret-exposure', 'block-dangerous-bash',
  'guard-env-mutation', 'guard-bulk-delete', 'block-egress-exfil', 'block-nasa-web-egress'];
const TIMEOUT_LOOKBACK_MS = 15 * 60 * 1000; // 15 min -- matches the existing background-check-in cadence
const NO_QUEUE_TURN_THRESHOLD = 3; // matches precompact-save-guard.js's own threshold, for consistency
const SKILL_LOOKBACK_MS = 15 * 60 * 1000; // same window as the hook-timeout check, for one consistent cadence
const STOP_FAILURE_LOOKBACK_MS = 15 * 60 * 1000; // same cadence as the other transcript-tail checks
const SKILL_PATTERNS = [
  // test-driven-development is checked BEFORE systematic-debugging deliberately: its own canonical phrase
  // ("write a failing test first") contains the word "failing", which systematic-debugging's pattern also
  // matches -- since SKILL_PATTERNS.find() returns the first array match, TDD would never be reachable via
  // its own most natural phrasing if it sat after systematic-debugging (found live via this hook's own test
  // battery, 2026-07-07). TDD's pattern is narrow enough (requires "write ... test(s) first", "TDD", or
  // "red-green-refactor") that moving it first doesn't swallow genuine bug-report prompts -- "the tests are
  // failing" still falls through to systematic-debugging below since it doesn't match TDD's phrasing.
  { skill: 'superpowers:test-driven-development',
    re: /\b(test[- ]?driven development|TDD|write (?:a |the )?(?:failing )?tests? first|red[- ]green(?:[- ]refactor)?)\b/i },
  { skill: 'superpowers:systematic-debugging',
    re: /\b(bug|broken|doesn'?t work|not working|unexpected|crash(?:es|ed|ing)?|fails?|failing|glitch(?:es|ing)?|why (?:did|does|is|isn'?t|wasn'?t)|stopped working)\b/i },
  { skill: 'impeccable',
    re: /\b(looks? (?:bad|wrong|weird|off|ugly|vibe.?coded)|redesign|make it (?:look better|prettier|bolder|nicer)|too (?:busy|loud|plain)|spacing (?:is|looks?)|layout (?:is|looks?)|colou?rs? (?:are|look)|fonts? (?:look|are)|critique|(?:UI|dashboard) (?:looks?|is))\b/i },
  { skill: 'superpowers:brainstorming',
    re: /\b(build (?:a|an|me|it)|create a|add (?:a |an |new )?(?:feature|component|tool|dashboard|page)|make (?:a|an) (?:app|tool|dashboard)|implement a new|new feature)\b/i },
  // Added 2026-07-07: skill-coverage audit (Douglas: "are there other skills that the hook should
  // cover?"). Discovery ran across superpowers (14 skills), impeccable (23 sub-commands -- all routed
  // through the single 'impeccable' Skill-tool name already covered above, so no separate entries),
  // warp/codex (confirmed zero backing content, orphaned config), claude-personalities (disable-model-
  // invocation:true by the skill's own design -- explicit-slash-command-only, excluded on principle), and
  // Douglas's 64 custom commands. Only genuinely distinctive, low-ambiguity human-prompt phrasings made
  // the cut -- see the full rationale + exclusion walk-through in this session's CURRENT-TASK notes.
  { skill: 'superpowers:writing-plans',
    re: /\b(write (?:a |me a )?plan|draft a plan|make a plan|plan (?:this|it) out|implementation plan|spec out)\b/i },
  { skill: 'superpowers:using-git-worktrees',
    re: /\b((?:git )?worktrees?)\b/i },
  { skill: 'superpowers:writing-skills',
    re: /\b(write a (?:new )?skill|new claude (?:code )?skill|editing (?:this|the) skill|skill\.md)\b/i },
  { skill: 'superpowers:requesting-code-review',
    re: /\b(review (?:this|my) (?:code|pr|diff|changes)|do a code review|code review this)\b/i },
  { skill: 'superpowers:receiving-code-review',
    re: /\b(code review feedback|reviewer (?:says|said|left|commented)|review comments|feedback from (?:the )?review(?:er)?)\b/i },
  { skill: 'superpowers:finishing-a-development-branch',
    re: /\b(merge (?:this|the) branch|ready to merge|open a (?:pr|pull request)|wrap up (?:this|the) (?:branch|feature)|integrate this branch)\b/i },
  { skill: 'astral:ruff',
    re: /\b(ruff|flake8|isort|lint (?:this|my|the) (?:python|code))\b/i },
  { skill: 'astral:ty',
    re: /\b(type[- ]?check(?:ing)? python|python type[- ]?check(?:ing)?|mypy|run ty)\b/i },
  { skill: 'astral:uv',
    re: /\b(uv (?:add|sync|venv|pip|run|lock|init)|use uv (?:to|for)|virtualenv|pyenv|pipx)\b/i },
  // Added 2026-07-07: extended to Claude Code's own built-in bundled skills (verified against official
  // docs, not guessed -- code-review/batch/debug/loop/claude-api/run/verify/simplify/security-review).
  // debug and code-review excluded as redundant with systematic-debugging/requesting-code-review above
  // (adding a 3rd overlapping nudge for the same intent would just be confusing, not more useful); run,
  // batch, loop excluded as too generic to anchor without high false-positive risk.
  //
  // CORRECTION (2026-07-07, deeper research after Douglas asked "you didn't explain what debug does"):
  // built-in /debug is NOT redundant with systematic-debugging -- confirmed against official docs, it
  // introspects Claude Code's OWN session (why a hook didn't fire, why a tool call failed silently, why a
  // skill didn't trigger), not application code. That's a genuinely distinct, distinct-from-anything-else-
  // installed capability -- and exactly the kind of question Douglas has asked THIS session multiple times
  // about hook behavior. Added below, correcting the earlier (wrong) exclusion.
  { skill: 'debug',
    re: /\b(why didn'?t (?:this|the|that) hook fire|why did (?:this|the|that) (?:tool call|hook) fail|why (?:isn'?t|didn'?t) (?:the )?skill (?:trigger|fire)|debug (?:this|the) session|claude code (?:is|seems) (?:confused|acting weird))\b/i },
  { skill: 'security-review',
    re: /\b(security review|check (?:this|it) for vulnerabilities|is this (?:secure|safe from|vulnerable)|security (?:audit|issues?) (?:on|in|for) this)\b/i },
  { skill: 'verify',
    re: /\b(verify (?:this|it) (?:actually )?works?|check (?:this|it) (?:actually )?works? in (?:the )?(?:app|browser)|does this actually work|confirm (?:this|it) works?)\b/i },
  { skill: 'simplify',
    re: /\b(simplify this|this (?:is|got|has gotten) too (?:complex|complicated|messy|sprawling)|clean(?:\s+up)? this (?:code|mess)|too much going on here)\b/i },
  // Added 2026-07-07/08: transcript-mining pass (Douglas: "please look through my actual transcripts to
  // get a specific knowledge of what i say when i need specific things"). A digest-then-mine workflow over
  // 60 real session digests extracted VERBATIM phrasing that actually preceded each Skill tool_use
  // historically -- replacing guessed phrasing with real evidence for 8 skills that had ZERO coverage
  // before (not corrections, skills the earlier guessed set never anticipated at all). Each cites the real
  // quote(s) it's built from.
  { skill: 'daily-activity',
    re: /\b(run (?:the |a )?daily report|daily report skill|daily report\/update skill|daily activity skill)\b/i },
    // cites: "run daily report please" / "run the daily report skill for both yesterday and today." /
    // "run the daily report/update skill" / "run the daily report skill plz"
  { skill: 'daily-review',
    re: /\bd\w*aily review( skill)?\b/i },
    // tolerant of the real typo "deaily review skill"; also matches "the daily review skill"
  { skill: 'rollover',
    re: /\b(run (?:the |a )?rollover( skill)?|session rollover( handoff)?)\b/i },
    // cites: "run the rollover so that I can restart a session..." / "make a session rollover handoff..." /
    // "run the rollover skill? and explain what it does"
  { skill: 'longrun',
    re: /\b(long ?run(?:ning)? (?:mode|auto|skill|watcher|dashboard)|go(?:ing)? into long ?run|adaptive long running)\b/i },
    // cites: "adaptive long running with a greenfield" / "going into long run auto mode..." /
    // "remake the long run skill so that it gets the watcher going..."
  { skill: 'solo-review',
    re: /\bsolo review\b/i },
    // cites: "run /solo-review on the whole dashboard/app" / "just solo review"
  { skill: 'update-config',
    re: /\b(add (?:a |an )?.{0,20}\ballow ?list|always allow|add (?:a |an )?permission|covered by .{0,20}hooks|make the (?:keep going )?hook (?:robust|more robust)|change (?:the )?(?:hook )?timeout|make the timeout \d+)\b/i },
    // cites: "add a very tightly scoped allow list to remove user sentinels" / "make powershell also
    // covered by all of my safetry hooks" / "always allow browser stuff for office.com stuff" /
    // "make the timeout 15 seconds" / "can you make the keep going hook robust"
  { skill: 'deep-search',
    re: /\b(do research on|find everything (?:you can )?about|research (?:on|into) how (?:other|people)|find (?:me )?(?:good |advanced )?examples? online|look up .{0,25}(?:frameworks|online))\b/i },
    // cites: "do research on hwo to get around this feature" / "find everything you can about nasa
    // ignition" / "do research on how other coders handle this" / "find me good advanced examples of
    // each of these online" / "look up different preseantion frameworks"
  { skill: 'claude-sync',
    re: /\b(claude sync|cloud sync|sync my (?:claude )?config|claude global config)\b/i },
    // cites: "I thought you were going to fix Cloud Sync so that you could put fixes in the Cloud Global
    // config" (note: Douglas genuinely says "Cloud Sync" not "Claude Sync") / "run the claude sync skill"
  // Deliberately NOT added as individual patterns: spar, probe, tune. Real evidence shows these are almost
  // always named TOGETHER as a group ("run whatever skills in this list that you haven't yet: solo review,
  // spar, tune, probe" -- verbatim, from two separate sessions), not via distinct individual phrasing --
  // and all three are common enough English words (boxing/radio/investigation) that single-word patterns
  // would be false-positive-prone. This is itself the strongest evidence for a group/chain-detection
  // mechanism rather than three more single-skill regexes -- see the "Harden Tail" chain proposal in this
  // session's CURRENT-TASK notes, not yet built (needs Douglas's go-ahead).
];

// Added 2026-07-06: precompact-save-guard.js already catches "no durable task file" -- but only at
// /compact time, which can be arbitrarily far into a long session (found live: a real multi-turn Interface
// Extractor Viewer session ran the whole way through with no WORK_QUEUE ever seeded, only caught when a
// manual /compact got blocked). task-state-reminder.js already fires every prompt but only reminds about a
// CURRENT-TASK that ALREADY EXISTS -- it had no check at all for one never having been created. This closes
// that gap: same turn-count signal precompact already uses, moved to the point where seeding would actually
// help (early in the session), not the point where it's already too late to matter. Fires ONCE per session
// (a marker file, not a nag on every subsequent prompt) and self-clears the moment a real queue file exists.
function checkMissingQueue(input) {
  const hasTaskFile = !!S.firstExisting(S.sessionDocCandidates(input, 'WORK_QUEUE')) ||
                       !!S.firstExisting(S.sessionDocCandidates(input, 'CURRENT-TASK'));
  if (hasTaskFile) return null;
  const markerPath = S.sessionFlagWrite(input, '.no-queue-nudge-sent');
  if (S.exists(markerPath)) return null; // already nudged this session -- don't nag every turn
  const turns = countHumanTurns(S.norm((input && input.transcript_path) || ''));
  if (turns < NO_QUEUE_TURN_THRESHOLD) return null;
  try { S.ensureDir(path.dirname(markerPath)); fs.writeFileSync(markerPath, new Date().toISOString()); } catch (_) {}
  return `${turns} human turns into this session with no durable task queue (CURRENT-TASK.md / ` +
    `WORK_QUEUE.${S.sid(input)}.md) seeded yet. Per your own CLAUDE.md rule, seed one NOW -- one \`- [ ]\` ` +
    `per outstanding item, plus anything already done -- before continuing with more tool calls.`;
}

function countHumanTurns(tpath) {
  if (!tpath) return 0;
  let data; try { data = fs.readFileSync(tpath, 'utf8'); } catch (_) { return 0; }
  let n = 0;
  for (const ln of data.split(/\r?\n/)) {
    if (!ln) continue;
    let o; try { o = JSON.parse(ln); } catch (_) { continue; }
    if (o && o.type === 'user' && o.message && typeof o.message.content === 'string') n++;
  }
  return n;
}

function checkRecentHookTimeouts(input) {
  const tpath = input.transcript_path;
  if (!tpath) return null;
  let stat;
  try { stat = fs.statSync(tpath); } catch (_) { return null; }
  const TAIL = 300 * 1024; // only read the tail -- transcripts can be 60MB+, this hook has a 5s budget
  let chunk;
  try {
    const fd = fs.openSync(tpath, 'r');
    const len = Math.min(stat.size, TAIL);
    const buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, stat.size - len);
    fs.closeSync(fd);
    chunk = buf.toString('utf8');
  } catch (_) { return null; }

  const cutoff = Date.now() - TIMEOUT_LOOKBACK_MS;
  const hits = new Set();
  for (const line of chunk.split('\n')) {
    if (!line.includes('"hook_cancelled"') || !line.includes('"timedOut":true')) continue;
    let o; try { o = JSON.parse(line); } catch (_) { continue; }
    const a = o.attachment;
    if (!a || a.type !== 'hook_cancelled' || !a.timedOut) continue;
    if (o.timestamp && Date.parse(o.timestamp) < cutoff) continue;
    const name = (a.command || a.hookName || '').split(/[\\/]/).pop().replace(/\.js$/, '');
    if (SECURITY_HOOK_NAMES.some(n => name.includes(n))) hits.add(name);
  }
  if (!hits.size) return null;
  return `${hits.size} security PreToolUse hook(s) TIMED OUT (>5s, cancelled) in the last 15 min of this ` +
    `session's own transcript: ${[...hits].join(', ')}. A cancelled hook never ran its check for that tool ` +
    `call -- same practical effect as it crashing. Worth naming this to Douglas if it recurs; not necessarily ` +
    `a security incident on its own (verify before concluding a cause -- e.g. check for a session that self- ` +
    `recovered normally afterward vs. one that stayed degraded).`;
}

// Added 2026-07-07 (Douglas: "can you make the keep going hook robust" against real uv_spawn/EUNKNOWN
// and "No stderr output" Stop-hook crashes pasted from a Text-to-Spaceship session). Stop hooks fail OPEN
// by design (AGENTS.md: "both fail OPEN and only ever vote 'keep going' -- never trap") -- so when
// keep-going.js/wait-on-usage-limit.js fail to even SPAWN under heavy concurrent-process load, the turn
// silently ends with zero indication the safety net didn't run. That failure IS recorded, though: Claude
// Code's own transcript writes a top-level "hookErrors":[...] array of strings on the Stop-hook record.
// Verified directly against the real e9971f8e-ead0-4ec3-8ae2-ba9c67cf7945.jsonl transcript Douglas pasted
// from: a genuine crash's string is a harness-generated wrapper -- "Failed to run: EUNKNOWN: unknown
// error, uv_spawn" or "Failed with non-blocking status code: No stderr output" -- while keep-going.js's
// OWN legitimate exit-2 block reads "[<hook path>]: KEEP GOING -- ...". Matching on the "Failed to run:" /
// "Failed with non-blocking status code:" wrapper prefixes (not the two specific error texts) generalizes
// to whatever new spawn-failure text the harness produces next, while explicitly excluding the KEEP GOING
// categorization quirk so a hook doing its job correctly is never misreported as broken.
function checkStopHookFailures(input) {
  const tpath = input.transcript_path;
  if (!tpath) return null;
  let stat;
  try { stat = fs.statSync(tpath); } catch (_) { return null; }
  const TAIL = 300 * 1024; // same tail-only budget as the other transcript-scanning checks
  let chunk;
  try {
    const fd = fs.openSync(tpath, 'r');
    const len = Math.min(stat.size, TAIL);
    const buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, stat.size - len);
    fs.closeSync(fd);
    chunk = buf.toString('utf8');
  } catch (_) { return null; }

  const cutoff = Date.now() - STOP_FAILURE_LOOKBACK_MS;
  const hits = [];
  for (const line of chunk.split('\n')) {
    if (!line.includes('"hookErrors":[') || line.includes('"hookErrors":[]')) continue;
    let o; try { o = JSON.parse(line); } catch (_) { continue; }
    if (!Array.isArray(o.hookErrors) || !o.hookErrors.length) continue;
    if (o.timestamp && Date.parse(o.timestamp) < cutoff) continue;
    for (const e of o.hookErrors) {
      if (typeof e !== 'string') continue;
      if (/^\[.*\]:\s*KEEP GOING/.test(e)) continue; // legitimate block, not a crash -- explicitly excluded
      if (/^Failed to run:|^Failed with non-blocking status code:/.test(e)) hits.push(e);
    }
  }
  if (!hits.length) return null;
  const uniq = [...new Set(hits)];
  return `${uniq.length} Stop-hook safety-net failure(s) in the last 15 min of this session's own transcript ` +
    `-- keep-going.js / wait-on-usage-limit.js failed to even RUN (not a deliberate block): ${uniq.join(' | ')}. ` +
    `Stop hooks fail OPEN by design, so the turn(s) this happened on ended with the autonomous-continue safety ` +
    `net never actually checking anything. This machine's own pattern this session: OS-level process-spawn ` +
    `contention under heavy concurrent Claude/Codex load, not a bug in the hook script itself -- worth naming ` +
    `to Douglas if it keeps recurring, and worth checking whether too many concurrent long-running loops are active.`;
}

function checkSkillInvocationGap(input) {
  const prompt = typeof input.prompt === 'string' ? input.prompt : '';
  if (!prompt.trim()) return null;
  const match = SKILL_PATTERNS.find(p => p.re.test(prompt));
  if (!match) return null;

  const tpath = input.transcript_path;
  if (!tpath) return null;
  let stat;
  try { stat = fs.statSync(tpath); } catch (_) { return null; }
  const TAIL = 300 * 1024; // same tail-only budget as checkRecentHookTimeouts -- transcripts can be 60MB+
  let chunk;
  try {
    const fd = fs.openSync(tpath, 'r');
    const len = Math.min(stat.size, TAIL);
    const buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, stat.size - len);
    fs.closeSync(fd);
    chunk = buf.toString('utf8');
  } catch (_) { return null; }

  const cutoff = Date.now() - SKILL_LOOKBACK_MS;
  for (const line of chunk.split('\n')) {
    if (!line.includes('"name":"Skill"') && !line.includes('"name": "Skill"')) continue;
    let o; try { o = JSON.parse(line); } catch (_) { continue; }
    if (o.timestamp && Date.parse(o.timestamp) < cutoff) continue;
    const content = o.message && o.message.content;
    if (!Array.isArray(content)) continue;
    if (content.some(b => b && b.type === 'tool_use' && b.name === 'Skill')) return null; // recent Skill call -> suppress
  }

  return `This prompt reads like it calls for **${match.skill}**, and no Skill tool call has fired in the ` +
    `last 15 minutes of this session. Per CLAUDE.md's standing rule, check whether it applies before ` +
    `implementing directly -- this is a nudge, not a requirement; use judgment if it genuinely doesn't fit.`;
}

// Added 2026-07-08: chain-suggester (Douglas: "start a workflow for building skills that chain together
// multiple skills, as i am hoping to do with my build pathways"). A digest-then-mine pass over 60 real
// session transcripts found Douglas invokes solo-review/probe/spar/tune as a named GROUP -- verbatim, from
// two separate sessions: "run whatever skills in this list that you haven't yet: solo review, spar, tune,
// probe." -- rather than each having distinct individual phrasing (that's WHY no individual SKILL_PATTERNS
// entry exists for spar/probe/tune above). Chain data lives in skill-pathways.json (shared with the
// skill-build-pathways.html editor as the intended single source of truth going forward -- the HTML tool
// still reads its own embedded PRESETS for now; wiring it to read this same file is a follow-up, not done
// here per the design's own v1 scope). Tracks per-session progress so a chain that's already fully run
// doesn't nag every subsequent prompt.
const CHAIN_STEP_RE_CACHE = new Map();
function chainStepRegex(step) {
  if (CHAIN_STEP_RE_CACHE.has(step)) return CHAIN_STEP_RE_CACHE.get(step);
  const re = new RegExp('\\b' + step.replace(/-/g, '[-\\s]?') + '\\b', 'i');
  CHAIN_STEP_RE_CACHE.set(step, re);
  return re;
}

function loadChains() {
  try {
    const raw = fs.readFileSync(path.join(__dirname, 'skill-pathways.json'), 'utf8');
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed.chains) ? parsed.chains : [];
  } catch (_) { return []; } // missing/malformed file -> no chains, never throws
}

function scanTranscriptForChainSteps(tpath, steps, fromOffset) {
  const found = new Set();
  let stat;
  try { stat = fs.statSync(tpath); } catch (_) { return { found, newOffset: fromOffset || 0 }; }
  const start = Math.max(0, fromOffset || 0);
  if (start >= stat.size) return { found, newOffset: stat.size }; // nothing new since last scan
  const len = stat.size - start;
  let chunk;
  try {
    const fd = fs.openSync(tpath, 'r');
    const buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, start);
    fs.closeSync(fd);
    chunk = buf.toString('utf8');
  } catch (_) { return { found, newOffset: fromOffset || 0 }; }

  for (const line of chunk.split('\n')) {
    if (!line.includes('"name":"Skill"') && !line.includes('"name": "Skill"')) continue;
    let o; try { o = JSON.parse(line); } catch (_) { continue; }
    const content = o.message && o.message.content;
    if (!Array.isArray(content)) continue;
    for (const b of content) {
      if (!b || b.type !== 'tool_use' || b.name !== 'Skill') continue;
      const invoked = (b.input && b.input.skill) || '';
      for (const step of steps) {
        if (chainStepRegex(step).test(invoked)) found.add(step);
      }
    }
  }
  return { found, newOffset: stat.size };
}

function checkChainOpportunity(input) {
  const prompt = typeof input.prompt === 'string' ? input.prompt : '';
  if (!prompt.trim()) return null;
  const tpath = input.transcript_path;
  if (!tpath) return null;
  const chains = loadChains();
  if (!chains.length) return null;

  for (const chain of chains) {
    const namedInPrompt = chain.steps.filter(s => chainStepRegex(s).test(prompt));
    if (namedInPrompt.length < (chain.minNamedToTrigger || 2)) continue;

    const progressPath = S.sessionFlagWrite(input, '.chain-progress.' + chain.id) + '.json';
    let progress = { lastOffset: 0, completed: [] };
    try { progress = Object.assign(progress, JSON.parse(fs.readFileSync(progressPath, 'utf8'))); } catch (_) {}

    const { found, newOffset } = scanTranscriptForChainSteps(tpath, chain.steps, progress.lastOffset);
    const completedSet = new Set([...progress.completed, ...found]);
    try {
      S.ensureDir(path.dirname(progressPath));
      fs.writeFileSync(progressPath, JSON.stringify({ lastOffset: newOffset, completed: [...completedSet] }));
    } catch (_) {}

    const remaining = chain.steps.filter(s => !completedSet.has(s));
    if (!remaining.length) continue; // this chain already fully run this session -- don't nag a finished chain

    return `This prompt names ${namedInPrompt.length} of the **${chain.name}** chain's skills together ` +
      `(${chain.steps.join(' -> ')}), matching how you've asked for this cluster before. ` +
      `Remaining this session: ${remaining.join(', ')}. Not a requirement -- just surfacing the full chain ` +
      `since you tend to ask for it as a group rather than one skill at a time.`;
  }
  return null;
}

function appendPromptLog(input) {
  try {
    const prompt = typeof input.prompt === 'string' ? input.prompt : '';
    if (!prompt.trim()) return;
    const file = S.sessionDocWrite(input, 'PROMPT_LOG');
    S.ensureDir(path.dirname(file));
    const truncated = prompt.length > MAX_LOG_ENTRY
      ? prompt.slice(0, MAX_LOG_ENTRY) + `\n...[truncated, ${prompt.length} chars total]`
      : prompt;
    fs.appendFileSync(file, `\n## ${new Date().toISOString()}\n${truncated}\n`);
  } catch (_) { /* never block a prompt over a logging failure */ }
}

function needsApprovalCandidates(input) {
  const sidv = S.sid(input);
  if (!sidv) return [];
  const name = `.longrun-needs-approval.${sidv}.md`;
  return S.dedupe
    ? S.dedupe([S.stateDir(input) + '/' + name, S.workspaceRoot(S.cwdOf(input)) + '/' + name])
    : [S.stateDir(input) + '/' + name, S.workspaceRoot(S.cwdOf(input)) + '/' + name];
}

function surfaceNeedsApproval(input) {
  const file = needsApprovalCandidates(input).find(S.exists);
  if (!file) return null;
  let content = '';
  try { content = fs.readFileSync(file, 'utf8').trim(); } catch (_) { return null; }
  if (!content) return null;
  try {
    fs.appendFileSync(file.replace(/\.md$/, '.SURFACED.md'), `\n---- surfaced ${new Date().toISOString()} ----\n${content}\n`);
    fs.unlinkSync(file); // archived; don't re-surface the same items on every future prompt
  } catch (_) { /* if archiving fails, still surface it this once below */ }
  return content;
}

(function () {
  try {
    const input = S.readStdin();
    if (!S.sid(input)) return; // no session id -> nothing to scope to

    appendPromptLog(input);

    const parts = [];
    const approval = surfaceNeedsApproval(input);
    if (approval) {
      parts.push(`/longrun surfaced items needing your decision from its last unattended run (dontAsk denials ` +
        `and/or auto-mode classifier blocks) — mention these at the START of your response, don't bury them:\n\n${approval}`);
    }

    const file = S.firstExisting(S.sessionDocCandidates(input, 'CURRENT-TASK'));
    if (file) {
      const content = fs.readFileSync(file, 'utf8').trim();
      if (content && content.includes('- [ ]')) {
        parts.push(`This session's CURRENT-TASK has unchecked items:\n\n${content}\n\nUpdate it before touching code.`);
      }
    } else {
      const missingQueueWarning = checkMissingQueue(input);
      if (missingQueueWarning) parts.push(missingQueueWarning);
    }

    const timeoutWarning = checkRecentHookTimeouts(input);
    if (timeoutWarning) parts.push(timeoutWarning);

    const skillGap = checkSkillInvocationGap(input);
    if (skillGap) parts.push(skillGap);

    const chainOpp = checkChainOpportunity(input);
    if (chainOpp) parts.push(chainOpp);

    const stopFailure = checkStopHookFailures(input);
    if (stopFailure) parts.push(stopFailure);

    if (parts.length) {
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'UserPromptSubmit',
          additionalContext: parts.join('\n\n---\n\n'),
        },
      }));
    }
  } catch (_) {}
})();
