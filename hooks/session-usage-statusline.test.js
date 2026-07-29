#!/usr/bin/env node
'use strict';
// Tests for session-usage-statusline.js — pipe sample statusLine JSON on stdin (the practitioner pattern), assert it
// persists usage-state.json in the EXACT shape wait-on-usage-limit.js reads, and prints a status line. Uses a temp
// CLAUDE_USAGE_STATE so it never touches the real file.
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');
const HOOK = path.join(__dirname, 'session-usage-statusline.js');
let pass = 0, total = 0;
function run(payload) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'usg-'));
  const out = path.join(tmp, 'usage-state.json');
  const r = cp.spawnSync('node', [HOOK], { input: JSON.stringify(payload), encoding: 'utf8',
    env: Object.assign({}, process.env, { CLAUDE_USAGE_STATE: out }) });
  let st = null; try { st = JSON.parse(fs.readFileSync(out, 'utf8')); } catch (_) {}
  return { stdout: r.stdout || '', st };
}
function check(name, cond) { total++; cond ? (pass++, console.log('  PASS', name)) : console.log('  FAIL', name); }

const now = Math.floor(Date.now() / 1000);

// 1) rate_limits present -> available:true + five_hour mapped exactly as the Stop hook expects
let r = run({ model: { display_name: 'Opus' }, context_window: { used_percentage: 33 }, cost: { total_cost_usd: 0.4 },
  rate_limits: { five_hour: { used_percentage: 42, resets_at: now + 3600 }, seven_day: { used_percentage: 18, resets_at: now + 86400 } } });
check('rate_limits -> available:true', r.st && r.st.available === true);
check('  five_hour.used_percentage mapped', r.st && r.st.five_hour && r.st.five_hour.used_percentage === 42);
check('  five_hour.resets_at mapped', r.st && r.st.five_hour && r.st.five_hour.resets_at === now + 3600);
check('  seven_day mapped', r.st && r.st.seven_day && r.st.seven_day.used_percentage === 18);
check('  status line prints model + 5h%', /Opus/.test(r.stdout) && /5h 42%/.test(r.stdout));

// 2) no rate_limits (API/enterprise plan, or before the first response) -> available:false, no crash
r = run({ model: { id: 'claude' }, context_window: { used_percentage: 10 } });
check('no rate_limits -> available:false', r.st && r.st.available === false);
check('  still prints a status line', r.stdout.length > 0);

// 3) empty payload -> available:false, no throw
r = run({});
check('empty payload -> available:false (no throw)', r.st && r.st.available === false);

console.log('\n' + pass + '/' + total + ' passed');
process.exit(pass === total ? 0 : 1);
