#!/usr/bin/env node
'use strict';
// Tests for concurrent-edit-lock.js (Automatable #5, 2026-07-02 sweep).
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');
const HOOK = path.join(__dirname, 'concurrent-edit-lock.js');
const { relevantPath, checkAndMark, lockPathFor } = require('./concurrent-edit-lock.js');
let pass = 0, total = 0;
function check(name, cond) { total++; cond ? (pass++, console.log('  PASS', name)) : console.log('  FAIL', name); }

// 1) relevantPath: matches the shared coordination files this finding is about
check('relevantPath: matches a session-scoped WORK_QUEUE under .claude/state/<project>/',
  relevantPath('/root/.claude/state/demo/WORK_QUEUE.sid123.md'));
check('relevantPath: matches a plain-convention STATUS.md at a project root',
  relevantPath('/root/myproject/STATUS.md'));
check('relevantPath: does NOT match an unrelated source file (out of scope, avoid noise)',
  !relevantPath('/root/myproject/retrieval_agent.py'));
check('relevantPath: does NOT match an unrelated .md doc', !relevantPath('/root/myproject/README.md'));

// 2) checkAndMark: same session touching the same file twice -> never warns (it's not a conflict)
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'cel-')).replace(/\\/g, '/');
const f1 = path.join(tmp, 'WORK_QUEUE.md');
let now = 1000000;
let w = checkAndMark(f1, 'sidA', now);
check('checkAndMark: first-ever touch has nothing to compare against -> no warning', w === null);
w = checkAndMark(f1, 'sidA', now + 1000);
check('checkAndMark: the SAME session touching it again -> never a conflict warning', w === null);

// 3) a DIFFERENT session touching the SAME file shortly after -> warns
w = checkAndMark(f1, 'sidB', now + 2000);
check('checkAndMark: a DIFFERENT session touching it shortly after -> warns', w !== null && /sidA/.test(w));

// 4) a DIFFERENT session touching it after the marker has gone STALE (past FRESH_MS) -> no warning
const f2 = path.join(tmp, 'STATUS.md');
checkAndMark(f2, 'sidA', now);
w = checkAndMark(f2, 'sidC', now + 6 * 60 * 1000); // 6 min later, past the 5-min freshness window
check('checkAndMark: a stale marker (past the freshness window) does not false-warn', w === null);

// 5) end-to-end via the real hook process: two different sessions editing the same WORK_QUEUE
// in quick succession -> the SECOND invocation's stderr carries the warning; the hook NEVER
// blocks (always exits 0), matching hook_guarantee.js's Invariant 3.
const projDir = path.join(tmp, 'proj');
fs.mkdirSync(path.join(projDir, '.claude', 'state', 'demo'), { recursive: true });
fs.writeFileSync(path.join(projDir, '.claude', 'projects.json'), JSON.stringify({ default: 'demo', projects: { demo: { dirs: ['.'] } } }));
const wqPath = path.join(projDir, '.claude', 'state', 'demo', 'WORK_QUEUE.md');
function runHook(sid) {
  return cp.spawnSync('node', [HOOK], {
    input: JSON.stringify({ session_id: sid, cwd: projDir, tool_name: 'Edit', tool_input: { file_path: wqPath } }),
    encoding: 'utf8',
  });
}
const r1 = runHook('sidX');
check('end-to-end: first session editing the shared queue -> exits 0 (never blocks)', r1.status === 0);
const r2 = runHook('sidY');
check('end-to-end: a second, DIFFERENT session editing it right after -> exits 0 (still never blocks)', r2.status === 0);
check('  ...but stderr carries a concurrent-edit warning naming the other session',
  /concurrent-edit-lock/.test(r2.stderr) && /sidX/.test(r2.stderr));
const r3 = runHook('sidY');
check('  ...the SAME session (sidY) editing it again right after -> no warning (not a conflict)',
  !/concurrent-edit-lock/.test(r3.stderr));

// 6) malformed stdin does not crash, always exits 0 (fail open)
const rBad = cp.spawnSync('node', [HOOK], { input: 'not valid json {{{', encoding: 'utf8', timeout: 5000 });
check('malformed stdin -> exits 0 cleanly, never crashes', rBad.status === 0 && rBad.signal === null);

// 7) a normal edit OUTSIDE the watched file set -> no lock file created, no warning
const otherFile = path.join(tmp, 'not_relevant.py');
const rOther = cp.spawnSync('node', [HOOK], {
  input: JSON.stringify({ session_id: 'sidZ', cwd: projDir, tool_name: 'Edit', tool_input: { file_path: otherFile } }),
  encoding: 'utf8',
});
check('an edit to an unrelated file -> exits 0, no warning, no lock file created',
  rOther.status === 0 && !rOther.stderr && !fs.existsSync(lockPathFor(otherFile)));

console.log(`\n${pass}/${total} passed`);
process.exit(pass === total ? 0 : 1);
