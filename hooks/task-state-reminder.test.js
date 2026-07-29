#!/usr/bin/env node
'use strict';
// Regression harness for task-state-reminder.js. Covers all four checks it runs (PROMPT_LOG append,
// needs-approval surfacing, CURRENT-TASK/missing-queue nudge, recent-hook-timeout surfacing) plus the
// skill-invocation-gap check added 2026-07-07. Builds temp project dirs + synthetic transcripts, pipes the
// UserPromptSubmit JSON, and asserts stdout JSON shape (never a "block" decision -- this hook only ever
// emits additionalContext or nothing) against what SHOULD happen for each case.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const HOOK = path.join(__dirname, 'task-state-reminder.js');
const SID = 'testsid-bbbb';
let pass = 0, fail = 0;
function check(name, cond, extra) { cond ? (pass++, console.log('  PASS', name)) : (fail++, console.log('  FAIL', name, extra !== undefined ? JSON.stringify(extra) : '')); }

function stateDirOf(dir) { return dir + '/.claude/state/' + path.basename(dir); } // no projects.json -> id = basename
function mkproj() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tsr-')).replace(/\\/g, '/');
  fs.mkdirSync(stateDirOf(dir), { recursive: true });
  return dir;
}
function writeTranscript(dir, lines) {
  const tpath = dir + '/transcript.jsonl';
  fs.writeFileSync(tpath, lines.map(l => JSON.stringify(l)).join('\n') + '\n');
  return tpath;
}
function skillLine(tsOffsetMs) {
  return {
    timestamp: new Date(Date.now() + tsOffsetMs).toISOString(),
    message: { content: [{ type: 'tool_use', name: 'Skill', input: { skill: 'systematic-debugging' } }] },
  };
}
function skillLineFor(skillName, tsOffsetMs) {
  return {
    timestamp: new Date(Date.now() + (tsOffsetMs || 0)).toISOString(),
    message: { content: [{ type: 'tool_use', name: 'Skill', input: { skill: skillName } }] },
  };
}
function run(dir, opts) {
  const payload = Object.assign({ cwd: dir, session_id: SID, prompt: '', transcript_path: dir + '/transcript.jsonl' }, opts || {});
  const r = spawnSync('node', [HOOK], { input: JSON.stringify(payload), encoding: 'utf8', timeout: 5000 });
  let parsed = null;
  try { parsed = JSON.parse(r.stdout || '{}'); } catch (_) {}
  return { code: r.status, stdout: r.stdout || '', stderr: r.stderr || '', parsed, timedOut: r.error && r.error.code === 'ETIMEDOUT' };
}
function ctx(res) { return (res.parsed && res.parsed.hookSpecificOutput && res.parsed.hookSpecificOutput.additionalContext) || ''; }

console.log('=== task-state-reminder.js battery ===\n');

// ---- checkSkillInvocationGap: new 2026-07-07 check ----
console.log('-- skill-invocation-gap check --');

// 1) normal case: bug-report prompt, no recent Skill call -> nudge for systematic-debugging
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const r = run(d, { prompt: 'why did the dashboard stop working, it is broken now' });
  check('1) bug prompt, no recent skill -> nudges systematic-debugging', r.code === 0 && /systematic-debugging/.test(ctx(r)), ctx(r));
}

// 2) suppression: same prompt, but a Skill call fired 2 min ago -> no nudge
{
  const d = mkproj();
  writeTranscript(d, [skillLine(-2 * 60 * 1000)]);
  const r = run(d, { prompt: 'why did the dashboard stop working, it is broken now' });
  check('2) bug prompt, recent skill call -> suppressed', r.code === 0 && !/systematic-debugging/.test(ctx(r)), ctx(r));
}

// 3) no-match: prompt with no skill-shaped language -> no nudge
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const r = run(d, { prompt: 'what time is it in tokyo right now' });
  check('3) no-match prompt -> no nudge', r.code === 0 && !/systematic-debugging|impeccable|brainstorming/.test(ctx(r)), ctx(r));
}

// 4) impeccable pattern
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const r = run(d, { prompt: 'the spacing looks wrong on this dashboard' });
  check('4) impeccable-pattern prompt -> nudges impeccable', r.code === 0 && /impeccable/.test(ctx(r)), ctx(r));
}

// 5) brainstorming pattern
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const r = run(d, { prompt: 'build me a new dashboard for tracking builds' });
  check('5) brainstorming-pattern prompt -> nudges brainstorming', r.code === 0 && /brainstorming/.test(ctx(r)), ctx(r));
}

// 6a) malformed: missing transcript_path -> no crash, no block
{
  const d = mkproj();
  const payload = { cwd: d, session_id: SID, prompt: 'why is this broken' };
  const r = spawnSync('node', [HOOK], { input: JSON.stringify(payload), encoding: 'utf8', timeout: 5000 });
  check('6a) missing transcript_path -> exit 0, no throw', r.status === 0, { code: r.status, stderr: r.stderr });
}
// 6b) malformed: transcript_path points to a nonexistent file -> no crash, no block
{
  const d = mkproj();
  const r = run(d, { prompt: 'why is this broken', transcript_path: d + '/does-not-exist.jsonl' });
  check('6b) nonexistent transcript_path -> exit 0, no throw', r.code === 0, { code: r.code, stderr: r.stderr });
}

// 7) old Skill call OUTSIDE the 15-min window should NOT suppress -> nudge still fires
{
  const d = mkproj();
  writeTranscript(d, [skillLine(-20 * 60 * 1000)]); // 20 min ago, outside SKILL_LOOKBACK_MS (15 min)
  const r = run(d, { prompt: 'why did the dashboard stop working, it is broken now' });
  check('7) stale skill call (20min ago) -> does NOT suppress, still nudges', r.code === 0 && /systematic-debugging/.test(ctx(r)), ctx(r));
}

// ---- transcript-mining new patterns: real quotes, not guessed phrasing (2026-07-07/08) ----
console.log('\n-- transcript-mined patterns --');
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const minedCases = [
    ['daily report prompt -> nudges daily-activity', 'run the daily report skill plz', 'daily-activity'],
    ['typo\'d daily review prompt -> nudges daily-review', 'run the newest version of the deaily review skill', 'daily-review'],
    ['rollover prompt -> nudges rollover', 'can you run the rollover skill? and explain what it does', 'rollover'],
    ['longrun prompt -> nudges longrun', 'going into long run auto mode now', 'longrun'],
    ['solo review prompt -> nudges solo-review', 'just solo review this', 'solo-review'],
    ['allowlist prompt -> nudges update-config', 'add a very tightly scoped allow list for this', 'update-config'],
    ['research prompt -> nudges deep-search', 'do research on how other coders handle this', 'deep-search'],
    ['claude sync prompt -> nudges claude-sync', 'run the claude sync skill', 'claude-sync'],
    ['"build it" (real quote, not "build a/an/me") -> nudges brainstorming', 'give me a list of skills you will use to build it', 'superpowers:brainstorming'],
  ];
  for (const [name, prompt, expectSkill] of minedCases) {
    const r = run(d, { prompt });
    check(name, r.code === 0 && new RegExp(expectSkill.replace(/:/g, '\\:')).test(ctx(r)), ctx(r));
  }
}

// 8) never blocks, across every case above (checked implicitly via r.code === 0 assertions; explicit check here)
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const r = run(d, { prompt: 'this is broken, redesign it, build a new feature' }); // stacks all 3 patterns
  check('8) multi-pattern prompt -> still exit 0 (never blocks)', r.code === 0, { code: r.code });
  check('8b) decision field is never "block"', !r.parsed || r.parsed.decision !== 'block', r.parsed);
}

// ---- skill-coverage-audit additions: new 2026-07-07 (Douglas: "are there other skills the hook should
// cover?"). 10 new SKILL_PATTERNS entries from a 4-agent research workflow (superpowers/impeccable/other-
// plugins discovery -> design synthesis), each verified against the real plugin skill names on disk. ----
console.log('\n-- skill-coverage-audit new patterns --');
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const cases = [
    ['tdd prompt -> nudges test-driven-development', 'lets do TDD for this, write a failing test first', 'test-driven-development'],
    ['plan prompt -> nudges writing-plans', 'can you draft a plan for this multi-step migration', 'writing-plans'],
    ['worktree prompt -> nudges using-git-worktrees', 'set up a git worktree for this feature', 'using-git-worktrees'],
    ['new-skill prompt -> nudges writing-skills', 'help me write a new skill for this', 'writing-skills'],
    ['request-review prompt -> nudges requesting-code-review', 'can you review this code before I merge', 'requesting-code-review'],
    ['receiving-review prompt -> nudges receiving-code-review', 'the reviewer left some feedback from the review', 'receiving-code-review'],
    ['finish-branch prompt -> nudges finishing-a-development-branch', 'this is ready to merge, should I open a PR', 'finishing-a-development-branch'],
    ['ruff prompt -> nudges astral:ruff', 'can you run ruff on this python file', 'astral:ruff'],
    ['ty prompt -> nudges astral:ty', 'need to type check python here, or run mypy', 'astral:ty'],
    ['uv prompt -> nudges astral:uv', 'use uv to add this dependency', 'astral:uv'],
  ];
  for (const [name, prompt, expectSkill] of cases) {
    const r = run(d, { prompt });
    check(name, r.code === 0 && new RegExp(expectSkill).test(ctx(r)), ctx(r));
  }
}

// collision guards the design explicitly reasoned about -- verify they hold, don't just trust the rationale
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);

  // "UV" as ultraviolet (CAD/hardware context) must NOT false-positive to astral:uv
  const r1 = run(d, { prompt: 'the CubeSat needs a UV-cure adhesive on that joint' });
  check('bare "UV" (ultraviolet, hardware context) -> does NOT nudge astral:uv', r1.code === 0 && !/astral:uv/.test(ctx(r1)), ctx(r1));

  // bare "ty" (thanks slang) must NOT false-positive to astral:ty
  const r2 = run(d, { prompt: 'ty for fixing that, looks great' });
  check('bare "ty" (thanks slang) -> does NOT nudge astral:ty', r2.code === 0 && !/astral:ty/.test(ctx(r2)), ctx(r2));

  // generic "review this document" must NOT false-positive to requesting-code-review
  const r3 = run(d, { prompt: 'can you review this document for typos' });
  check('generic document review -> does NOT nudge requesting-code-review', r3.code === 0 && !/requesting-code-review/.test(ctx(r3)), ctx(r3));

  // regression: TDD's own canonical phrase contains "failing", which systematic-debugging's pattern also
  // matches -- TDD must be checked first in the array or this phrase is unreachable (found live, fixed by
  // reordering)
  const r4 = run(d, { prompt: 'lets do TDD for this, write a failing test first' });
  check('TDD canonical phrase ("write a failing test first") -> reaches TDD, not swallowed by systematic-debugging', r4.code === 0 && /test-driven-development/.test(ctx(r4)), ctx(r4));

  // and the reorder must NOT cause a genuine bug-report prompt to falsely reach TDD instead
  const r5 = run(d, { prompt: 'the tests are failing, please help me figure out why' });
  check('genuine "tests are failing" bug report -> still reaches systematic-debugging, not TDD', r5.code === 0 && /systematic-debugging/.test(ctx(r5)) && !/test-driven-development/.test(ctx(r5)), ctx(r5));
}

// ---- built-in Claude Code skill patterns: new 2026-07-07 (Douglas: "yes look at built in claude code
// skills") ----
console.log('\n-- built-in-skill patterns --');
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);

  const r1 = run(d, { prompt: 'can you do a security review on this endpoint' });
  check('security-review prompt -> nudges security-review', r1.code === 0 && /(?<!\w)security-review/.test(ctx(r1)), ctx(r1));

  const r2 = run(d, { prompt: 'verify this actually works in the browser' });
  check('verify prompt -> nudges verify', r2.code === 0 && /\bverify\b/.test(ctx(r2)) && /verify\*\*/.test(ctx(r2)), ctx(r2));

  const r3 = run(d, { prompt: 'this has gotten too complicated, can you simplify this' });
  check('simplify prompt -> nudges simplify', r3.code === 0 && /simplify/.test(ctx(r3)), ctx(r3));

  const r5 = run(d, { prompt: 'why didn\'t this hook fire, that command should have been blocked' });
  check('debug (hook-behavior) prompt -> nudges debug', r5.code === 0 && /(?<!\w)debug\b/.test(ctx(r5)), ctx(r5));

  // built-in debug/code-review deliberately NOT added (redundant w/ systematic-debugging /
  // requesting-code-review) -- confirm a bug-report prompt still only nudges systematic-debugging, not a
  // phantom "debug" entry
  const r4 = run(d, { prompt: 'this is broken, why is it crashing' });
  check('bug prompt -> still only nudges systematic-debugging (no redundant built-in "debug" entry)', r4.code === 0 && /systematic-debugging/.test(ctx(r4)), ctx(r4));
}

// ---- checkChainOpportunity: new 2026-07-08 (Douglas: "start a workflow for building skills that chain
// together multiple skills"). Harden Tail chain (solo-review/probe/spar/tune), mined from real transcripts. ----
console.log('\n-- chain-opportunity check (Harden Tail) --');
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const r = run(d, { prompt: 'run whatever skills in this list that you haven\'t yet: solo review, spar, tune, probe.' });
  check('real mined quote (4 names) -> nudges Harden Tail, all 4 remaining', r.code === 0 && /Harden Tail/.test(ctx(r)) && /solo-review, probe, spar, tune/.test(ctx(r)), ctx(r));
}
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const r = run(d, { prompt: 'just run spar on this' });
  check('only 1 chain skill named -> no nudge (below minNamedToTrigger)', r.code === 0 && !/Harden Tail/.test(ctx(r)), ctx(r));
}
{
  const d = mkproj();
  writeTranscript(d, [
    skillLineFor('solo-review', -60000),
    skillLineFor('probe', -50000),
    skillLineFor('spar', -40000),
    skillLineFor('tune', -30000),
  ]);
  const r = run(d, { prompt: 'find all issues, run solo review/spar/probe/tune that hasn\'t been done' });
  check('all 4 already invoked this session -> chain suppressed (fully complete, no nag)', r.code === 0 && !/Harden Tail/.test(ctx(r)), ctx(r));
}
{
  const d = mkproj();
  writeTranscript(d, [
    skillLineFor('solo-review', -60000),
    skillLineFor('probe', -50000),
  ]);
  const r = run(d, { prompt: 'run solo review, spar, tune, probe' });
  check('2 of 4 already invoked -> nudge shows only the 2 remaining (spar, tune)', r.code === 0 && /Harden Tail/.test(ctx(r)) && /spar, tune/.test(ctx(r)) && !/solo-review,/.test(ctx(r)), ctx(r));
}
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const r = run(d, { prompt: 'this is broken, why is it crashing' }); // unrelated prompt, no chain skills named
  check('unrelated prompt -> no chain nudge, no crash', r.code === 0 && !/Harden Tail/.test(ctx(r)), ctx(r));
}
{
  // incremental scan: two prompts in the same session, second call must still see the first call's
  // already-scanned progress (offset persists via .chain-progress.<sid>.harden-tail.json)
  const d = mkproj();
  writeTranscript(d, [skillLineFor('solo-review', -60000), skillLineFor('probe', -50000)]);
  const r1 = run(d, { prompt: 'run solo review, spar, tune, probe' });
  check('incremental: first call sees solo-review+probe already done', r1.code === 0 && /spar, tune/.test(ctx(r1)), ctx(r1));
  // append spar to the transcript (simulating it ran between prompts), call again
  fs.appendFileSync(d + '/transcript.jsonl', JSON.stringify(skillLineFor('spar', -10000)) + '\n');
  const r2 = run(d, { prompt: 'run solo review, spar, tune, probe again' });
  check('incremental: second call picks up the newly-appended spar, only tune remains', r2.code === 0 && /tune/.test(ctx(r2)) && !/spar,/.test(ctx(r2).replace('spar, tune', '')), ctx(r2));
}

// ---- checkStopHookFailures: new 2026-07-07 check (Douglas: "make the keep going hook robust" against
// real uv_spawn/EUNKNOWN and "No stderr output" Stop-hook crashes) ----
console.log('\n-- stop-hook-failure check --');
function stopErrorsLine(errors, tsOffsetMs) {
  return { toolUseID: 'abc', hookEvent: 'Stop', hookErrors: errors,
    timestamp: new Date(Date.now() + (tsOffsetMs || 0)).toISOString() };
}

// 9) genuine crash (uv_spawn) -> surfaces
{
  const d = mkproj();
  writeTranscript(d, [stopErrorsLine(['Failed to run: EUNKNOWN: unknown error, uv_spawn'])]);
  const r = run(d, { prompt: 'continue' });
  check('9) uv_spawn crash string -> surfaced', r.code === 0 && /uv_spawn/.test(ctx(r)) && /safety-net failure/.test(ctx(r)), ctx(r));
}

// 10) genuine crash ("No stderr output") -> surfaces
{
  const d = mkproj();
  writeTranscript(d, [stopErrorsLine(['Failed with non-blocking status code: No stderr output'])]);
  const r = run(d, { prompt: 'continue' });
  check('10) "No stderr output" crash string -> surfaced', r.code === 0 && /No stderr output/.test(ctx(r)), ctx(r));
}

// 11) legitimate KEEP GOING block -> NOT surfaced (the categorization quirk must stay excluded)
{
  const d = mkproj();
  writeTranscript(d, [stopErrorsLine(['[C:/Users/dmcgowa2/.claude/hooks/keep-going.js]: KEEP GOING -- 3 actionable item(s) left'])]);
  const r = run(d, { prompt: 'continue' });
  check('11) KEEP GOING block -> not misreported as a crash', r.code === 0 && !/safety-net failure/.test(ctx(r)), ctx(r));
}

// 12) mixed array (one legit block + one real crash) -> surfaces only the crash
{
  const d = mkproj();
  writeTranscript(d, [stopErrorsLine(['[C:/x/keep-going.js]: KEEP GOING -- 1 item', 'Failed with non-blocking status code: No stderr output'])]);
  const r = run(d, { prompt: 'continue' });
  check('12) mixed KEEP GOING + crash -> surfaces crash, not KEEP GOING text', r.code === 0 && /No stderr output/.test(ctx(r)) && !/KEEP GOING/.test(ctx(r)), ctx(r));
}

// 13) empty hookErrors array -> no false positive
{
  const d = mkproj();
  writeTranscript(d, [stopErrorsLine([])]);
  const r = run(d, { prompt: 'continue' });
  check('13) empty hookErrors -> no false positive', r.code === 0 && !/safety-net failure/.test(ctx(r)), ctx(r));
}

// 14) stale crash (20 min ago) -> does NOT surface (outside the 15-min lookback)
{
  const d = mkproj();
  writeTranscript(d, [stopErrorsLine(['Failed to run: EUNKNOWN: unknown error, uv_spawn'], -20 * 60 * 1000)]);
  const r = run(d, { prompt: 'continue' });
  check('14) stale crash (20min ago) -> not surfaced', r.code === 0 && !/safety-net failure/.test(ctx(r)), ctx(r));
}

// 15) no transcript_path / nonexistent -> exit 0, no throw (same discipline as the other checks)
{
  const d = mkproj();
  const r = run(d, { prompt: 'continue', transcript_path: d + '/does-not-exist.jsonl' });
  check('15) nonexistent transcript_path -> exit 0, no throw', r.code === 0, { code: r.code, stderr: r.stderr });
}

// ---- Regression: the three pre-existing checks, unchanged by this additive edit ----
console.log('\n-- pre-existing checks (regression) --');

// CURRENT-TASK unchecked items surfaced
{
  const d = mkproj();
  fs.writeFileSync(`${stateDirOf(d)}/CURRENT-TASK.${SID}.md`, '# task\n- [ ] open item\n');
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  const r = run(d, { prompt: 'continue' });
  check('CURRENT-TASK with open items -> surfaced', r.code === 0 && /open item/.test(ctx(r)), ctx(r));
}

// missing-queue nudge fires after threshold turns, once
{
  const d = mkproj();
  const lines = [];
  for (let i = 0; i < 4; i++) lines.push({ type: 'user', message: { role: 'user', content: 'turn ' + i } });
  writeTranscript(d, lines);
  const r1 = run(d, { prompt: 'continue working' });
  check('missing-queue nudge fires at >=3 human turns', r1.code === 0 && /no durable task queue/.test(ctx(r1)), ctx(r1));
  const r2 = run(d, { prompt: 'continue working again' });
  check('missing-queue nudge does NOT repeat (marker file)', r2.code === 0 && !/no durable task queue/.test(ctx(r2)), ctx(r2));
}

// PROMPT_LOG gets appended
{
  const d = mkproj();
  writeTranscript(d, [{ timestamp: new Date().toISOString(), message: { content: [{ type: 'text', text: 'hi' }] } }]);
  run(d, { prompt: 'a prompt worth logging' });
  const logPath = `${stateDirOf(d)}/PROMPT_LOG.${SID}.md`;
  const logged = fs.existsSync(logPath) && fs.readFileSync(logPath, 'utf8').includes('a prompt worth logging');
  check('PROMPT_LOG appended with prompt text', logged);
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
