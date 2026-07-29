#!/usr/bin/env node
'use strict';
// Stop hook — HARDENED keep-going, now PROJECT + SESSION scoped via hook-state.js.
// Blocks a stop (exit 2) ONLY while THIS session (within its resolved project) has genuine actionable work;
// otherwise allows the stop (exit 0). Can never trap a session, never bleed across sessions OR projects that
// share one workspace folder, and never interferes with a subagent/Workflow stage.
//
// Rules (each maps to a mined failure mode):
//  R1 fail-OPEN on any self-error (a broken hook must never trap/abort the turn)            [hook-crash-self]
//  R2 no session_id -> allow stop (never block unscoped; no shared bare-queue fallback)     [no-session-id]
//  R3 sentinels are (project,sid)-scoped: .need-user/.stop-autorun/.no-keepgoing.<sid>      [cross-session]
//  R5 subagent / Workflow-stage stop -> passthrough (exit 0); only the top session drives   [workflow-interference]
//  R6 actionable = [ ]/[~] under -,*,+ or 1./1) bullets; parked=[!]/[?]; checkbox-shaped typos stay pending [parked-only]
//  R7 no driver file -> allow; file present but read failed -> fail open                     [queue-empty]
//  R8 stale .work-complete.<sid> while work remains -> delete it, block anyway              [premature-done]
//  R9 actionable>0 -> exit 2 with the count + next item text                                [the keep-going job]
//  R10 no-progress cap: identical pending set N times in a row -> release (exit 0)          [infinite-block]
//  R11 parked-only / empty -> allow stop with a one-line stderr reason                      [parked-only]
//  R12 output contract: exit code (2=block,0=allow) + stderr text ONLY; never stdout JSON   [hook-crash-self]
//  R14 completion-promise LOOP (consolidated from the ralph-loop plugin): while an armed
//      loop file exists for THIS session, keep going until the agent emits <promise>X</promise>
//      or max_iterations is hit. Runs before R0 (survives stop_hook_active), session-isolated,
//      haltable by the R3 sentinels / /cancel-ralph. Makes keep-going the SOLE Stop hook.   [ralph-consolidation]
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const S = require(path.join(__dirname, 'hook-state.js'));

// ---- R14 completion-promise loop helpers (consolidated from the ralph-loop plugin) ----
// State lives in the ralph-loop plugin's own file (so its /ralph-loop arming command still works),
// project-relative, with session_id stamped for isolation. keep-going is the executor; the plugin's
// own Stop hook is neutralized so there is exactly one Stop voter.
function readRalphState(cwd) {
  const p = S.norm(cwd) + '/.claude/ralph-loop.local.md';
  let raw; try { raw = fs.readFileSync(p, 'utf8'); } catch (_) { return null; }
  const m = /^---\s*\r?\n([\s\S]*?)\r?\n---\s*\r?\n?([\s\S]*)$/.exec(raw);
  if (!m) return null;
  const fm = {};
  for (const line of m[1].split(/\r?\n/)) { const mm = /^([A-Za-z_]+):\s*(.*)$/.exec(line); if (mm) fm[mm[1]] = mm[2].trim(); }
  return { path: p, fm, prompt: (m[2] || '').trim() };
}
function recentAssistantText(tpath) {
  if (!tpath) return '';
  let data; try { data = fs.readFileSync(tpath, 'utf8'); } catch (_) { return ''; }
  const blocks = [];
  for (const ln of data.split(/\r?\n/).filter(Boolean).slice(-400)) {
    let o; try { o = JSON.parse(ln); } catch (_) { continue; }
    const msg = o && o.message; if (!msg || msg.role !== 'assistant') continue;
    const c = msg.content;
    if (Array.isArray(c)) { for (const b of c) if (b && b.type === 'text' && typeof b.text === 'string') blocks.push(b.text); }
    else if (typeof c === 'string') blocks.push(c);
  }
  return blocks.join('\n');   // ALL assistant text in the window, not just the last block (fixes the trailing-Files-list false negative)
}
function promiseFound(text, token) {
  if (!token) return false;
  const norm = s => String(s).replace(/\s+/g, ' ').trim();
  const want = norm(token);
  const re = /<promise>([\s\S]*?)<\/promise>/gi;
  let m;                       // scan EVERY tag pair, not just the first, so an echoed example tag can't mask a real one
  while ((m = re.exec(text || '')) !== null) if (norm(m[1]) === want) return true;
  return false;
}

// Shared queue-parsing logic used by both the plain WORK_QUEUE path (R6/R7/R11) and the R14
// completion-promise loop, so "nothing actionable left, only parked [!]/[?] items" is detected
// the same way regardless of which mechanism is driving the session (found live 2026-07-02: a
// /goal loop kept forcing iterations against a BRepNet blocker that needed a human security
// call, because R14 never looked at the WORK_QUEUE's own parked-only state at all).
const MARK = '(?:[-*+]|\\d+[.)])';
const RE_ACT  = new RegExp('^\\s*' + MARK + '\\s*\\[[ ~]\\]');
const RE_PARK = new RegExp('^\\s*' + MARK + '\\s*\\[[!?]\\]');
const RE_DONE = new RegExp('^\\s*' + MARK + '\\s*\\[[xX]\\]');
const RE_CBOX = new RegExp('^\\s*' + MARK + '\\s*\\[.{0,3}\\]');
function queueStatus(input) {
  const files = [];
  for (const c of S.sessionDocCandidates(input, 'WORK_QUEUE')) if (S.exists(c)) { files.push(c); break; }
  for (const c of S.sessionDocCandidates(input, 'CURRENT-TASK')) if (S.exists(c)) { files.push(c); break; }
  if (files.length === 0) return { hasFile: false, actionable: [], parked: [], malformed: [], done: 0, readFailed: false };
  let actionable = [], parked = [], malformed = [], done = 0, readFailed = false;
  for (const f of files) {
    let t; try { t = fs.readFileSync(f, 'utf8'); } catch (_) { readFailed = true; continue; }
    for (const line of t.split(/\r?\n/)) {
      if (RE_ACT.test(line)) actionable.push(line.replace(RE_ACT, '').trim());
      else if (RE_PARK.test(line)) parked.push(line.replace(RE_PARK, '').trim());
      else if (RE_DONE.test(line)) done++;
      else if (RE_CBOX.test(line)) malformed.push(line.trim());
    }
  }
  return { hasFile: true, actionable, parked, malformed, done, readFailed };
}

const STATUS_UPDATE_REMINDER = 'Status-update reminder: state what\'s still pending, any real ' +
  'tradeoffs, and explicit decision options if something is blocked - not just a thin progress note.';

function main() {
  const input = S.readStdin();
  const cwd = S.cwdOf(input);
  const sid = S.sid(input);
  const tpat = S.norm(input.transcript_path || '');

  const proj = S.resolveProject(input);
  const dir = S.stateDirOf(proj);
  const logd = (decision, msg) => {
    try {
      S.ensureDir(dir);
      fs.appendFileSync(dir + '/.keep-going.log',
        new Date().toISOString() + '  proj=' + proj.id + ' via=' + proj.via + ' sid=' + sid +
        ' stop_hook_active=' + String(input.stop_hook_active) + '  ' + decision + '  ' + (msg || '') + '\n');
    } catch (_) {}
  };
  const allow = (msg) => { logd('ALLOW', msg); if (msg) process.stderr.write('keep-going: ' + msg + '\n'); process.exit(0); };
  const rm = (p) => { try { fs.unlinkSync(p); return true; } catch (_) { return false; } };

  // R5 — subagent / Workflow-stage stop: only the top-level interactive session drives blocking
  if (/[\/](subagents|workflows)[\/]/i.test(tpat) || /[\/](subagents|workflows)[\/]/i.test(cwd))
    return allow('subagent/workflow stop; passthrough');

  // R2 — no session_id -> allow (never block unscoped; there is no shared bare-queue fallback any more)
  if (!sid) return allow('no session_id at this Stop event; allowing (no unscoped blocking)');

  // R3 — genuine block / kill switch / opt-out, (project,sid)-scoped. Checked BEFORE R0 and the R14
  // loop so a kill switch can always halt an autonomous run OR a completion-promise loop.
  if (S.firstExisting(S.sessionFlagCandidates(input, '.need-user')))    return allow('.need-user present (Douglas blocking)');
  if (S.firstExisting(S.sessionFlagCandidates(input, '.stop-autorun'))) return allow('.stop-autorun present (kill switch)');
  if (S.firstExisting(S.sessionFlagCandidates(input, '.no-keepgoing'))) return allow('.no-keepgoing present (opt-out)');

  // R14 — COMPLETION-PROMISE LOOP (consolidated from the ralph-loop plugin so keep-going is the SOLE Stop hook).
  // While an armed loop file exists for THIS session, keep going until the agent emits the completion promise
  // or max_iterations is hit. Deliberately runs BEFORE R0 so it survives stop_hook_active (the loop is meant to
  // re-block); it is bounded by max_iterations and halted by the R3 sentinels above or /cancel-ralph. Arm: /ralph-loop.
  {
    const loop = readRalphState(cwd);
    if (loop) {
      const fmSid = (loop.fm.session_id || '').trim();
      if (fmSid && fmSid !== sid) return allow('completion-promise loop owned by another session; passthrough');
      const iter = parseInt(loop.fm.iteration, 10), maxIt = parseInt(loop.fm.max_iterations, 10);
      if (!Number.isFinite(iter) || !Number.isFinite(maxIt)) { rm(loop.path); return allow('loop state corrupted; cleared'); }
      if (maxIt > 0 && iter >= maxIt) { rm(loop.path); return allow('completion-promise loop: max iterations (' + maxIt + ') reached'); }
      // A goal loop must not grind forever against a blocker that structurally needs a human
      // decision: if this session's OWN WORK_QUEUE has nothing actionable left (only [!]/[?]
      // parked items), pause instead of forcing another iteration — the same behavior R11
      // already gives the plain WORK_QUEUE path, now applied to the goal loop too.
      const qsLoop = queueStatus(input);
      if (qsLoop.hasFile && qsLoop.actionable.length === 0 && qsLoop.malformed.length === 0 && qsLoop.parked.length > 0) {
        return allow('goal loop paused: WORK_QUEUE has only parked/blocked item(s) left ([!]/[?]), ' +
          'nothing actionable — this needs your decision, not more looping. First parked item: "' + qsLoop.parked[0] + '"');
      }
      const label = (loop.fm.completion_promise || '').replace(/^"(.*)"$/, '$1').trim();
      // Anti-echo: the completion key is a per-loop NONCE that keep-going generates + persists (the arming command
      // never writes it). The recurring instruction below never prints a ready-to-copy <promise>token</promise>
      // string, so the hook can't self-trigger a false stop by being echoed. The match scans ALL assistant text
      // blocks + ALL tag pairs (recentAssistantText / promiseFound), so a trailing Files-list block can't hide a
      // genuine completion. A loop ends only when the agent deliberately wraps THIS nonce in promise tags.
      let nonce = (loop.fm.nonce || '').trim();
      if (nonce && promiseFound(recentAssistantText(tpat), nonce)) {
        rm(loop.path); return allow('completion-promise loop: completion token detected — done');
      }
      let raw; try { raw = fs.readFileSync(loop.path, 'utf8'); } catch (_) { raw = null; }
      if (!nonce) nonce = crypto.randomBytes(6).toString('hex');   // 12 hex chars, unguessable, stable for the loop's life
      if (raw != null) {
        let next = raw.replace(/^iteration:.*$/m, 'iteration: ' + (iter + 1));
        if (!/^nonce:/m.test(next)) next = next.replace(/^(iteration:.*)$/m, '$1\nnonce: ' + nonce);
        try { fs.writeFileSync(loop.path, next); } catch (_) {}
      }
      const nextIter = iter + 1;
      logd('BLOCK', 'completion-promise loop iter ' + nextIter);
      process.stderr.write(
        'KEEP GOING — completion-promise loop, iteration ' + nextIter + (maxIt > 0 ? ('/' + maxIt) : '') + '. ' +
        'Continue the task; your prior work persists in files and git. ' +
        (label ? 'Loop goal: ' + label + '. ' : '') +
        'To finish, wrap THIS completion token in promise tags as your final output, ONLY when the task is genuinely complete (do not fake it to exit). ' +
        'Completion token: ' + nonce + '  — write it as <promise> then the token then </promise>, with nothing else inside the tags. ' +
        'Halt anytime with /cancel-ralph or .stop-autorun.' + sid + '.\n\n' + loop.prompt + '\n');
      process.exit(2);
    }
  }

  // R0 — honor Claude Code's own re-entrant Stop guard (QUEUE mode): if we already forced a continue once,
  // never block again. The R14 loop above intentionally runs first, bounded by its own max_iterations.
  if (input.stop_hook_active) return allow('stop_hook_active; already continued once — allowing to avoid an unbounded loop');

  // R6/R7 — resolve actionable work from THIS session's own queue + task files (project-scoped)
  const qs = queueStatus(input);
  if (!qs.hasFile) return allow('no queue/task file for this session; nothing to drive');
  const { actionable, parked, malformed, readFailed } = qs;
  if (readFailed && actionable.length === 0 && malformed.length === 0) return allow('queue read failed; failing open');

  const progFile = S.sessionFlagWrite(input, '.keep-going.progress');
  const wcExisting = S.firstExisting(S.sessionFlagCandidates(input, '.work-complete'));

  // R11 — nothing actionable AND nothing malformed: allow with a visible reason; reset the no-progress counter
  if (actionable.length === 0 && malformed.length === 0) {
    rm(progFile);
    if (parked.length) return allow(parked.length + ' parked item(s) ([!]/[?]); nothing actionable: "' + parked[0] + '"');
    return allow('queue empty; work complete');
  }
  // A checkbox-shaped line that doesn't parse (e.g. "- [] x", "- [ x]") is NEVER treated as done: it joins the
  // pending set so a formatting typo can't silently end an autonomous run. Still bounded by the R10 no-progress cap.
  const pending = actionable.concat(malformed.map(m => '[unparsed: fix to "- [ ] ..."] ' + m));

  // R8 — a .work-complete.<sid> that lies while work remains is removed, not honored
  const killedWC = wcExisting ? rm(wcExisting) : false;

  // R10 — no-progress cap: byte-identical pending set N times in a row -> release
  const N_CAP = 3;
  const djb2 = (s) => { let h = 5381; for (let i = 0; i < s.length; i++) h = ((h * 33) ^ s.charCodeAt(i)) >>> 0; return h; };
  const h = djb2(pending.join('\n'));
  let prog = { hash: 0, count: 0 };
  try { prog = JSON.parse(fs.readFileSync(S.firstExisting(S.sessionFlagCandidates(input, '.keep-going.progress')) || progFile, 'utf8')); } catch (_) {}
  const prevDoneCount = typeof prog.doneCount === 'number' ? prog.doneCount : null;
  prog = (prog.hash === h) ? { hash: h, count: (prog.count || 0) + 1 } : { hash: h, count: 1 };
  prog.doneCount = qs.done;   // Dropped #10: a regression signal independent of the stall hash above —
                              // the WORK_QUEUE's own [x] count dropping between turns is real evidence
                              // something was un-done or reverted, worth surfacing without Douglas having
                              // to re-derive it from scrollback (generalized from the sweep's CubeSat
                              // realized-joint-count example into a project-agnostic WORK_QUEUE signal).
  // Persist the no-progress counter. If it CANNOT be persisted, the no-progress release (R10) can never advance,
  // which would trap the session forever — so a write failure must fail OPEN (allow the stop), not block.
  let progPersisted = false;
  try { if (S.ensureDir(dir)) { fs.writeFileSync(progFile, JSON.stringify(prog)); progPersisted = true; } } catch (_) {}
  if (!progPersisted) return allow('cannot persist keep-going progress; failing open to avoid a permanent block');
  if (prog.count > N_CAP) {
    rm(progFile);
    return allow('no progress in ' + N_CAP + ' turns; releasing — mark items [!]/[?] or create .need-user.' + sid + ' to stop cleanly');
  }
  const regression = (prevDoneCount !== null && qs.done < prevDoneCount)
    ? ' ⚠ REGRESSION: done-count dropped ' + prevDoneCount + ' -> ' + qs.done + ' since the last check — something may have been un-done or reverted.'
    : '';
  // Had-to-remind #1 (sweep's single most recurring pattern): "you said continuing but you did
  // not continue." R10's own stall-hash count already detects an IDENTICAL pending set recurring
  // across checks — surface that as an explicit warning instead of a silent counter, so a
  // "continuing" claim with no real underlying change is visibly suspect rather than invisible.
  const noChange = prog.count > 1
    ? ' ⚠ No change detected since the last check — the same pending item(s) as last time. If you claimed "continuing", verify real progress actually happened.'
    : '';

  // R9 — real work (or an unparsed checkbox) remains: BLOCK and name the next item
  const note = malformed.length ? ' (' + malformed.length + ' line(s) look like checkboxes but don\'t parse — fix to "- [ ] ...")' : '';
  logd('BLOCK', pending.length + ' left; next: ' + pending[0] + (regression ? ' [REGRESSION]' : '') + (noChange ? ' [NO-CHANGE]' : ''));
  process.stderr.write(
    'KEEP GOING — ' + pending.length + ' actionable item(s) left for this session (project ' + proj.id + ')' +
    (killedWC ? ' (removed a stale .work-complete)' : '') + note + '. Next: "' + pending[0] + '".' + regression + noChange + ' ' +
    'Work the queue top-down ([ ] -> [x]); add items as you find them. To stop: clear the queue, ' +
    'mark items [!]/[?], or create .need-user.' + sid + '. ' + STATUS_UPDATE_REMINDER + '\n');
  process.exit(2);
}

// R1 — fail OPEN: any uncaught error allows the stop; a broken hook must never trap or abort the turn.
try { main(); } catch (_) { process.exit(0); }
