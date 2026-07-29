#!/usr/bin/env node
'use strict';
// keep-going R14 completion-promise loop tests (consolidated ralph-loop behavior, NONCE-hardened 2026-06-29).
// Pattern follows the practitioner consensus: spawn the hook, pipe Stop-event JSON on stdin, assert the EXACT exit
// code (2 = block/keep going, 0 = allow stop) plus side effects. Run alongside keep-going.test.js + hook_guarantee.js.
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');
const HOOK = path.join(__dirname, 'keep-going.js');
const SID = 'kg-loop-sid';
let pass = 0, total = 0;

function setup(opts) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'kgloop-'));
  fs.mkdirSync(path.join(tmp, '.claude'), { recursive: true });
  fs.writeFileSync(path.join(tmp, '.claude', 'projects.json'), JSON.stringify({ default: 'demo', projects: { demo: { dirs: ['.'] } } }));
  if (opts.loop) {
    const fm = ['---', 'iteration: ' + opts.iter, 'max_iterations: ' + opts.max,
      'completion_promise: "' + (opts.promise || '') + '"', 'session_id: ' + (opts.fileSid || SID)];
    if (opts.nonce) fm.push('nonce: ' + opts.nonce);
    fm.push('---', 'DO THE TASK.');
    fs.writeFileSync(path.join(tmp, '.claude', 'ralph-loop.local.md'), fm.join('\n'));
  }
  const tx = path.join(tmp, 't.jsonl');
  const blocks = opts.blocks || [opts.assistantText || 'working'];     // one assistant msg, N text blocks
  fs.writeFileSync(tx, JSON.stringify({ message: { role: 'assistant', content: blocks.map(t => ({ type: 'text', text: t })) } }) + '\n');
  return { tmp, tx };
}
function run(input) {
  const r = cp.spawnSync('node', [HOOK], { input: JSON.stringify(input), encoding: 'utf8' });
  return { code: r.status, err: (r.stderr || '').trim() };
}
function check(name, got, wantCode, extra) {
  total++; let ok = got.code === wantCode; if (ok && extra) ok = extra();
  if (ok) pass++;
  console.log((ok ? 'PASS' : 'FAIL') + '  ' + name + '  (exit ' + got.code + ')');
}
const lf = s => path.join(s.tmp, '.claude', 'ralph-loop.local.md');
const fire = s => run({ session_id: SID, cwd: s.tmp, transcript_path: s.tx, stop_hook_active: false });

// 1) token absent (under max) -> block, iteration++
let s = setup({ loop: true, iter: 0, max: 5, nonce: 'TKN123', blocks: ['still working'] });
check('block when token absent (under max), iteration++', fire(s), 2, () => /iteration: 1/.test(fs.readFileSync(lf(s), 'utf8')));

// 2) survives stop_hook_active (still blocks — the loop is meant to re-block, bounded by max_iterations)
s = setup({ loop: true, iter: 1, max: 5, nonce: 'TKN123', blocks: ['still working'] });
check('survives stop_hook_active (still blocks)', run({ session_id: SID, cwd: s.tmp, transcript_path: s.tx, stop_hook_active: true }), 2);

// 3) completion token present -> allow + state removed
s = setup({ loop: true, iter: 2, max: 5, nonce: 'TKN123', blocks: ['done <promise>TKN123</promise>'] });
check('token detected -> allow + state removed', fire(s), 0, () => !fs.existsSync(lf(s)));

// 4) FALSE-NEGATIVE GUARD (fix #1): token in an EARLIER block, a Files list is the LAST block -> still allow + removed
s = setup({ loop: true, iter: 2, max: 5, nonce: 'TKN123', blocks: ['All done. <promise>TKN123</promise>', '## Files\n- foo.js — updated'] });
check('token in earlier block + trailing Files list -> allow (scan ALL blocks)', fire(s), 0, () => !fs.existsSync(lf(s)));

// 5) FALSE-POSITIVE GUARD (fix #2): echo the hook instruction (token named + example tags, NOT assembled) -> still block
s = setup({ loop: true, iter: 1, max: 5, nonce: 'TKN123',
  blocks: ['I will finish soon. Completion token: TKN123 — write it as <promise> then the token then </promise> when done.'] });
check('echoed instruction (no assembled tag) -> still block', fire(s), 2);

// 6) max iterations -> allow + removed
s = setup({ loop: true, iter: 5, max: 5, nonce: 'TKN123', blocks: ['x'] });
check('max iterations -> allow + removed', fire(s), 0, () => !fs.existsSync(lf(s)));

// 7) other session's loop -> passthrough (preserve file)
s = setup({ loop: true, iter: 0, max: 5, nonce: 'TKN123', fileSid: 'other-sid', blocks: ['x'] });
check('other session loop -> passthrough (preserve file)', fire(s), 0, () => fs.existsSync(lf(s)));

// 8) NONCE AUTO-GEN (fix #2): armed WITHOUT a nonce -> block AND a nonce: line is generated for next turn
s = setup({ loop: true, iter: 0, max: 5, blocks: ['working'] });
check('no nonce -> block AND a nonce: line is generated', fire(s), 2, () => /^nonce: [0-9a-f]{6,}/m.test(fs.readFileSync(lf(s), 'utf8')));

// 9) kill switch (.stop-autorun) halts the loop (R3 before R14)
s = setup({ loop: true, iter: 0, max: 5, nonce: 'TKN123', blocks: ['x'] });
fs.mkdirSync(path.join(s.tmp, '.claude', 'state', 'demo'), { recursive: true });
fs.writeFileSync(path.join(s.tmp, '.claude', 'state', 'demo', '.stop-autorun.' + SID), '');
check('kill switch (.stop-autorun) halts loop', fire(s), 0);

// 10) no loop file -> falls through to queue logic (allow, no queue)
s = setup({ loop: false });
check('no loop file -> falls through to queue logic (allow, no queue)', fire(s), 0);

console.log('\n' + pass + '/' + total + ' loop cases passed');
process.exit(pass === total ? 0 : 1);
