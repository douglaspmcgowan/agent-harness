#!/usr/bin/env node
'use strict';
// Tests for session-primer.js harness self-checks: ARMED/INERT report, stale kill-switch sentinel, hook rollback
// (inSync footgun), and ralph-loop re-arm. Spawns the SessionStart hook with synthetic stdin + a temp project, then
// asserts the injected additionalContext. Env seams (CLAUDE_HOOKS_DIR / CLAUDE_RALPH_HOOKS) point checks at fixtures.
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');
const HOOK = path.join(__dirname, 'session-primer.js');
const SID = 'primer-sid';
let pass = 0, total = 0;

function setup() {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'primer-')).replace(/\\/g, '/');
  fs.mkdirSync(path.join(tmp, '.claude', 'state', 'demo'), { recursive: true });
  fs.writeFileSync(path.join(tmp, '.claude', 'projects.json'), JSON.stringify({ default: 'demo', projects: { demo: { dirs: ['.'] } } }));
  return tmp;
}
const sd = tmp => path.join(tmp, '.claude', 'state', 'demo');
function run(tmp, env) {
  const r = cp.spawnSync('node', [HOOK], { input: JSON.stringify({ cwd: tmp, session_id: SID, transcript_path: tmp + '/t.jsonl' }),
    encoding: 'utf8', env: Object.assign({}, process.env, env || {}) });
  let ctx = ''; try { ctx = JSON.parse(r.stdout).hookSpecificOutput.additionalContext; } catch (_) { ctx = r.stdout || ''; }
  return ctx;
}
function check(name, cond) { total++; cond ? (pass++, console.log('  PASS', name)) : console.log('  FAIL', name); }

// 1) ARMED: queue with open items
let tmp = setup();
fs.writeFileSync(sd(tmp) + '/WORK_QUEUE.' + SID + '.md', '- [ ] do a thing\n- [x] done\n');
let ctx = run(tmp);
check('queue with open items -> ARMED', /ARMED/.test(ctx) && /1 actionable/.test(ctx));

// 2) INERT: no queue
tmp = setup();
ctx = run(tmp);
check('no queue -> INERT', /INERT/.test(ctx));

// 3) stale sentinel -> kill switch ACTIVE + INERT even with an open queue
tmp = setup();
fs.writeFileSync(sd(tmp) + '/WORK_QUEUE.' + SID + '.md', '- [ ] do a thing\n');
fs.writeFileSync(sd(tmp) + '/.stop-autorun.' + SID, '');
ctx = run(tmp);
check('stale .stop-autorun -> kill switch ACTIVE warning', /kill switch ACTIVE/.test(ctx));
check('  ...and reported INERT despite an open queue', /INERT/.test(ctx));

// 4) ralph hooks.json re-armed (env seam) -> warning
tmp = setup();
const rp = path.join(tmp, 'ralph-hooks.json');
fs.writeFileSync(rp, JSON.stringify({ hooks: { Stop: [{ hooks: [{ type: 'command', command: 'x' }] }] } }));
ctx = run(tmp, { CLAUDE_RALPH_HOOKS: rp });
check('ralph hooks.json re-armed -> RE-ARMED warning', /RE-ARMED/.test(ctx));

// 5) ralph hooks.json empty -> no re-arm warning
tmp = setup();
const rp2 = path.join(tmp, 'ralph-empty.json');
fs.writeFileSync(rp2, JSON.stringify({ hooks: {} }));
ctx = run(tmp, { CLAUDE_RALPH_HOOKS: rp2 });
check('ralph hooks.json empty -> no warning', !/RE-ARMED/.test(ctx));

// 6) hook rollback: a keep-going.js stub missing the R14 marker (env seam)
tmp = setup();
const hd = path.join(tmp, 'hooks'); fs.mkdirSync(hd, { recursive: true });
fs.writeFileSync(path.join(hd, 'keep-going.js'), '// old version, no markers here\n');
fs.writeFileSync(path.join(hd, 'hook-state.js'), '// resolveProject\n');
fs.writeFileSync(path.join(hd, 'wait-on-usage-limit.js'), '// STALE_MS\n');
ctx = run(tmp, { CLAUDE_HOOKS_DIR: hd });
check('rolled-back keep-going.js -> ROLLED BACK warning', /ROLLED BACK/.test(ctx) && /keep-going\.js/.test(ctx));

// 7) live hooks dir -> no drift warning (positive control)
tmp = setup();
ctx = run(tmp, { CLAUDE_HOOKS_DIR: __dirname });
check('real hooks dir -> no drift warning', !/ROLLED BACK/.test(ctx) && !/hook MISSING/.test(ctx));

// 8) broad settings.json sweep: a security-relevant hook OTHER than the 3 keep-going-family
// files (e.g. check-secret-exposure.js, the exact file the 2026-07-02 sweep found silently
// missing for 6 concurrent sessions during a ~14 min window) must ALSO be flagged if missing -
// not just the 3 hardcoded rollback-marker files.
tmp = setup();
const hd8 = path.join(tmp, 'hooks8'); fs.mkdirSync(hd8, { recursive: true });
fs.writeFileSync(path.join(hd8, 'keep-going.js'), '// R14 recentAssistantText\n');
fs.writeFileSync(path.join(hd8, 'hook-state.js'), '// resolveProject\n');
fs.writeFileSync(path.join(hd8, 'wait-on-usage-limit.js'), '// STALE_MS\n');
// deliberately do NOT create check-secret-exposure.js in hd8
const settings8 = path.join(tmp, 'settings8.json');
fs.writeFileSync(settings8, JSON.stringify({ hooks: { PreToolUse: [{ hooks: [
  { type: 'command', command: 'node ' + path.join(hd8, 'check-secret-exposure.js') },
] }] } }));
ctx = run(tmp, { CLAUDE_HOOKS_DIR: hd8, CLAUDE_SETTINGS_PATHS: settings8 });
check('a non-keep-going-family hook missing (check-secret-exposure.js) -> flagged too',
  /hook MISSING: check-secret-exposure\.js/.test(ctx));

// 8b) allow-list narrowing check (2026-07-02 sweep, Had-to-remind lower-severity bullet):
// "why did you have to ask for permission to create need user? i think you've made that stuff
// before." -> a settings.json permissions.allow snapshot that shrinks between sessions must warn.
tmp = setup();
const snap8b = path.join(tmp, 'perm-snapshot.json');
const settings8b_v1 = path.join(tmp, 'settings-v1.json');
fs.writeFileSync(settings8b_v1, JSON.stringify({ permissions: { allow: ['Read', 'Write', 'Bash(git *)'] } }));
ctx = run(tmp, { CLAUDE_SETTINGS_PATHS: settings8b_v1, CLAUDE_PERMISSIONS_SNAPSHOT: snap8b });
check('allow-list check: first-ever run has nothing to compare against -> no warning yet', !/narrowed/i.test(ctx));
const settings8b_v2 = path.join(tmp, 'settings-v2.json');
fs.writeFileSync(settings8b_v2, JSON.stringify({ permissions: { allow: ['Read', 'Write'] } })); // lost Bash(git *)
ctx = run(tmp, { CLAUDE_SETTINGS_PATHS: settings8b_v2, CLAUDE_PERMISSIONS_SNAPSHOT: snap8b });
check('allow-list check: a rule present last time and now GONE -> narrowing warning',
  /narrowed/i.test(ctx) && /Bash\(git \*\)/.test(ctx));

// 8c) allow-list check: growing (or staying the same) never false-warns
tmp = setup();
const snap8c = path.join(tmp, 'perm-snapshot.json');
const settings8c_v1 = path.join(tmp, 'settings-v1.json');
fs.writeFileSync(settings8c_v1, JSON.stringify({ permissions: { allow: ['Read'] } }));
run(tmp, { CLAUDE_SETTINGS_PATHS: settings8c_v1, CLAUDE_PERMISSIONS_SNAPSHOT: snap8c });
const settings8c_v2 = path.join(tmp, 'settings-v2.json');
fs.writeFileSync(settings8c_v2, JSON.stringify({ permissions: { allow: ['Read', 'Write'] } })); // grew
ctx = run(tmp, { CLAUDE_SETTINGS_PATHS: settings8c_v2, CLAUDE_PERMISSIONS_SNAPSHOT: snap8c });
check('allow-list check: growing (or unchanged) the list never false-warns', !/narrowed/i.test(ctx));

// 9) broad sweep positive control: the same wired hook DOES exist -> no false-positive warning
tmp = setup();
const hd9 = path.join(tmp, 'hooks9'); fs.mkdirSync(hd9, { recursive: true });
fs.writeFileSync(path.join(hd9, 'keep-going.js'), '// R14 recentAssistantText\n');
fs.writeFileSync(path.join(hd9, 'hook-state.js'), '// resolveProject\n');
fs.writeFileSync(path.join(hd9, 'wait-on-usage-limit.js'), '// STALE_MS\n');
fs.writeFileSync(path.join(hd9, 'check-secret-exposure.js'), '// present\n');
const settings9 = path.join(tmp, 'settings9.json');
fs.writeFileSync(settings9, JSON.stringify({ hooks: { PreToolUse: [{ hooks: [
  { type: 'command', command: 'node ' + path.join(hd9, 'check-secret-exposure.js') },
] }] } }));
ctx = run(tmp, { CLAUDE_HOOKS_DIR: hd9, CLAUDE_SETTINGS_PATHS: settings9 });
check('the same wired hook present -> no false-positive MISSING warning', !/hook MISSING/.test(ctx));

console.log('\n' + pass + '/' + total + ' passed');
process.exit(pass === total ? 0 : 1);
