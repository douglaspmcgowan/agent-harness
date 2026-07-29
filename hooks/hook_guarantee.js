#!/usr/bin/env node
'use strict';
// HOOK GUARANTEE v3 — asserts the contamination invariants after the project+session keying rework (2026-06-22).
// v2 proved "exactly one Stop hook + no PostToolUse-on-edit + no command hook blocks a normal edit". v3 adds:
//   (4) PROJECT+SESSION isolation: in a synthetic workspace, one session's open work NEVER blocks another
//       session's stop, and project is resolved by binding > cwd-walk-up > registry default.
//   (5) the state hooks route through hook-state.js and read NO bare-cwd / machine-global task file.
//   (6) the canonical hooks (keep-going.js, hook-state.js) are byte-identical across home, project-local, tracked.
//   (7) every WIRED command-hook script path actually exists on this machine (no ENOENT no-ops).
// Run: node hook_guarantee.js   (exit 0 = guarantee holds)
const { spawnSync } = require('child_process');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const HOME = path.join(os.homedir(), '.claude').replace(/\\/g, '/');
const PROJECT = (process.argv[2] || process.env.CLAUDE_PROJECT_DIR || process.cwd()).replace(/\\/g, '/');
const NODE = process.execPath;
const SETTINGS = [HOME + '/settings.json', HOME + '/settings.local.json', PROJECT + '/.claude/settings.local.json'];

function walk(dir, hits) {
  let ents; try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    const p = dir + '/' + e.name;
    if (e.isDirectory()) { if (e.name !== 'node_modules') walk(p, hits); }
    else if (e.name === 'hooks.json') hits.push(p);
  }
}
const HOOKFILES = [];
walk(HOME + '/skills', HOOKFILES);
walk(HOME + '/plugins/cache', HOOKFILES);

const resolveCmd = (cmd, root) => cmd.replace(/\$\{CLAUDE_PROJECT_DIR\}/g, PROJECT).replace(/\$\{CLAUDE_PLUGIN_ROOT\}/g, root || '');
function load(file, root) {
  let j; try { j = JSON.parse(fs.readFileSync(file, 'utf8')); } catch { return []; }
  const out = [];
  for (const [event, groups] of Object.entries(j.hooks || {}))
    for (const g of groups || [])
      for (const h of g.hooks || [])
        out.push({ event, matcher: g.matcher || '', type: h.type, cmd: h.command ? resolveCmd(h.command, root) : null,
          prompt: !!h.prompt, src: file.replace(HOME + '/', '').replace(PROJECT + '/', 'project/') });
  return out;
}
let HOOKS = [];
for (const s of SETTINGS) HOOKS = HOOKS.concat(load(s));
for (const f of HOOKFILES) HOOKS = HOOKS.concat(load(f, f.replace(/\/hooks\/hooks\.json$/, '')));

let pass = 0, fail = 0;
const ok = (c, m) => { console.log(`  ${c ? 'PASS' : 'FAIL'}  ${m}`); c ? pass++ : fail++; };

console.log(`Discovered ${HOOKS.length} hooks across ${SETTINGS.length} settings + ${HOOKFILES.length} skill/plugin hooks.json:`);
for (const h of HOOKS) console.log(`   [${h.event}${h.matcher ? ' ' + h.matcher : ''}] type=${h.type}  ${h.cmd ? h.cmd.split(/[\\/]/).pop() : '(prompt)'}  (${h.src})`);

// helper: fire a command hook, return true if it voted to BLOCK
const fire = (cmd, input, env) => {
  const r = spawnSync(cmd, { shell: true, input: JSON.stringify(input), encoding: 'utf8', timeout: 60000, env: env ? { ...process.env, ...env } : process.env });
  return r.status === 2 || /"decision"\s*:\s*"block"|"continue"\s*:\s*false|"permissionDecision"\s*:\s*"deny"/.test(r.stdout || '');
};

// ---- INVARIANT 1: exactly one Stop hook = keep-going; no other Stop hook may vote. ----
const stops = HOOKS.filter(h => h.event === 'Stop');
const keepGoing = stops.filter(h => h.cmd && /keep-going\.js/.test(h.cmd));
const usageWait = stops.filter(h => h.cmd && /wait-on-usage-limit\.js/.test(h.cmd));
const allowedStop = new Set([...keepGoing, ...usageWait]);
const otherStops = stops.filter(h => !allowedStop.has(h));
console.log('\n(1) Stop-hook control (allowed set: keep-going + wait-on-usage-limit, which cooperate):');
ok(keepGoing.length === 1, `exactly one keep-going Stop hook present (found ${keepGoing.length})`);
ok(usageWait.length <= 1, `at most one usage-limit Stop hook (found ${usageWait.length})`);
ok(otherStops.length === 0, `no OTHER (rogue) Stop hook can vote (found ${otherStops.length}${otherStops.length ? ': ' + otherStops.map(h => h.type + '@' + h.src).join(', ') : ''})`);

// ---- INVARIANT 2: no PostToolUse hook fires on Write/Edit. ----
const ptuEdit = HOOKS.filter(h => h.event === 'PostToolUse' && (!h.matcher || /Write|Edit/.test(h.matcher)));
console.log('\n(2) no PostToolUse hook on Write/Edit:');
ok(ptuEdit.length === 0, `no PostToolUse Write/Edit hook (found ${ptuEdit.length}${ptuEdit.length ? ': ' + ptuEdit.map(h => h.type + '@' + h.src).join(', ') : ''})`);

// ---- INVARIANT 3: command Pre/PostToolUse hooks never block a normal .py/.html edit. ----
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'hg-')).replace(/\\/g, '/');
fs.writeFileSync(tmp + '/probe.py', 'print(1)\n');
fs.writeFileSync(tmp + '/probe.html', '<!doctype html><meta name=viewport content="width=device-width"><h1>x</h1>');
console.log('\n(3) command edit hooks never block a normal edit:');
for (const ev of ['PreToolUse', 'PostToolUse']) for (const tool of ['Write', 'Edit']) for (const fp of [tmp + '/probe.py', tmp + '/probe.html'])
  for (const h of HOOKS.filter(h => h.event === ev && h.cmd && (!h.matcher || new RegExp(h.matcher).test(tool)))) {
    const blocked = fire(h.cmd, { hook_event_name: ev, tool_name: tool, tool_input: { file_path: fp, content: 'print(1)' }, cwd: tmp, session_id: 'guar-sid-1' });
    ok(!blocked, `${ev}:${tool} ${fp.endsWith('.py') ? '.py' : '.html'} -> ${h.cmd.split(/[\\/]/).pop()} ${blocked ? 'BLOCKED' : 'allowed'}`);
  }

// ---- INVARIANT 4: PROJECT + SESSION isolation in a synthetic workspace. ----
console.log('\n(4) project + session isolation (keep-going):');
const kg = keepGoing[0] && keepGoing[0].cmd;
function makeWorkspace() {
  const w = fs.mkdtempSync(path.join(os.tmpdir(), 'ws-')).replace(/\\/g, '/');
  fs.mkdirSync(w + '/.claude/state/sessions', { recursive: true });
  fs.mkdirSync(w + '/alpha', { recursive: true }); fs.mkdirSync(w + '/beta', { recursive: true });
  fs.writeFileSync(w + '/.claude/projects.json', JSON.stringify({
    version: 1, default: 'aproj',
    projects: { aproj: { dirs: ['alpha'] }, bproj: { dirs: ['beta'] } },
  }));
  return w;
}
function fireKG(w, sid, cwd) {
  if (!kg) return null;
  return fire(kg, { hook_event_name: 'Stop', cwd: cwd || w, session_id: sid, transcript_path: w + '/t/' + sid + '.jsonl' });
}
if (!kg) { ok(false, 'no keep-going hook to test'); }
else {
  const w = makeWorkspace();
  // sidA bound to aproj, has open work in the canonical state dir
  fs.writeFileSync(w + '/.claude/state/sessions/sidA.json', JSON.stringify({ project: 'aproj' }));
  fs.mkdirSync(w + '/.claude/state/aproj', { recursive: true });
  fs.writeFileSync(w + '/.claude/state/aproj/WORK_QUEUE.sidA.md', '- [ ] do the thing\n');
  // sidB bound to bproj, NO work
  fs.writeFileSync(w + '/.claude/state/sessions/sidB.json', JSON.stringify({ project: 'bproj' }));

  ok(fireKG(w, 'sidA') === true,  'sidA WITH open work -> keep going (block)');
  ok(fireKG(w, 'sidB') === false, "sidB (other session, no work) -> allow stop, NOT blocked by sidA's work  [cross-session isolation]");
  ok(fireKG(w, 'sidUnbound') === false, 'unbound session, no work -> allow stop  [no shared bare-queue fallback]');

  // a session launched in a SUBDIR drives off a CURRENT-TASK.<sid>.md in that subdir (cwd candidate)
  fs.writeFileSync(w + '/alpha/CURRENT-TASK.sidSub.md', '- [ ] subdir item\n');
  ok(fireKG(w, 'sidSub', w + '/alpha') === true, 'subdir-launched session: cwd CURRENT-TASK.<sid>.md drives keep-going');
  // migration: a legacy ROOT sid file is copied into the project state dir by migrate-root-state.js, then drives
  fs.writeFileSync(w + '/.claude/state/sessions/sidMig.json', JSON.stringify({ project: 'aproj' }));
  fs.writeFileSync(w + '/CURRENT-TASK.sidMig.md', '- [ ] migrated item\n');
  spawnSync(NODE, [HOME + '/hooks/migrate-root-state.js', w], { encoding: 'utf8' });
  ok(fireKG(w, 'sidMig') === true, 'legacy ROOT sid file -> migrate-root-state -> drives keep-going  [migration, no project-less read]');

  // project resolution: binding > cwd-walk-up > default
  const S = require(HOME + '/hooks/hook-state.js');
  const pid = (sid, cwd) => S.resolveProject({ session_id: sid, cwd }).id;
  ok(pid('sidA', w + '/beta') === 'aproj', 'binding wins over cwd (sidA in beta/ still resolves aproj)');
  ok(pid('fresh', w + '/alpha') === 'aproj', 'cwd walk-up: unbound session in alpha/ -> aproj');
  ok(pid('fresh', w + '/beta') === 'bproj', 'cwd walk-up: unbound session in beta/ -> bproj');
  ok(pid('fresh', w) === 'aproj', 'ambiguous root, unbound -> registry default (aproj)');
}

// ---- INVARIANT 5: state hooks route through hook-state.js, no bare-cwd / machine-global task reads. ----
console.log('\n(5) state hooks are project/session keyed (source check):');
const SRC = f => { try { return fs.readFileSync(f, 'utf8'); } catch { return ''; } };
for (const name of ['keep-going.js', 'task-state-reminder.js', 'session-primer.js']) {
  const s = SRC(HOME + '/hooks/' + name);
  ok(/require\(.*hook-state\.js.*\)/.test(s), `${name} requires hook-state.js`);
}
const tsr = SRC(HOME + '/hooks/task-state-reminder.js');
ok(!/cwd\s*,\s*['"]CURRENT-TASK\.md['"]/.test(tsr) && !/BACKGROUND-TASKS/.test(tsr), 'task-state-reminder reads no bare cwd / global file');
const sp = SRC(HOME + '/hooks/session-primer.js');
ok(!/\.claude\/BACKGROUND-TASKS\.md/.test(sp) && !/claudeDir.*CURRENT-TASK/.test(sp), 'session-primer dumps no machine-global CURRENT-TASK/BACKGROUND-TASKS');

// ---- INVARIANT 6: canonical hooks byte-identical across home (active) and tracked (sync mirror). ----
console.log('\n(6) canonical hook copies are identical home==tracked (no divergence to revert):');
const md5 = f => { try { return crypto.createHash('md5').update(fs.readFileSync(f)).digest('hex'); } catch { return 'MISSING:' + f; } };
for (const name of ['keep-going.js', 'hook-state.js', 'task-state-reminder.js', 'session-primer.js']) {
  const a = md5(HOME + '/hooks/' + name);
  const c = md5(PROJECT + '/claude-global-config/hooks/' + name);
  ok(a === c, `${name} identical: home == tracked (${a.slice(0, 8)} / ${c.slice(0, 8)})`);
}

// ---- INVARIANT 7: every WIRED command-hook script path exists (no ENOENT no-ops). ----
console.log('\n(7) every wired command-hook script resolves on this machine:');
const scriptOf = (cmd) => {
  const q = cmd.match(/"([^"]+\.js)"/);            // quoted path (may contain spaces)
  if (q) return q[1];
  const toks = cmd.split(/\s+/).filter(t => /\.js$/i.test(t)); // else last unquoted .js token
  return toks.length ? toks[toks.length - 1] : null;
};
const scriptPaths = HOOKS.filter(h => h.cmd && /\.js\b/.test(h.cmd)).map(h => scriptOf(h.cmd)).filter(Boolean);
const missing = [...new Set(scriptPaths)].filter(p => !fs.existsSync(p));
ok(missing.length === 0, `no wired hook points at a missing path (missing: ${missing.length ? missing.join(', ') : 'none'})`);

// ---- INVARIANT 8: keep-going can NEVER permanently trap a session (fail OPEN on every backstop). ----
console.log('\n(8) keep-going fails OPEN, never traps:');
if (kg) {
  const Sg = require(HOME + '/hooks/hook-state.js');
  // 8a: unwritable canonical state dir (a FILE planted where the dir must be) -> allow, not a trap
  const w8 = fs.mkdtempSync(path.join(os.tmpdir(), 'ws8-')).replace(/\\/g, '/');
  fs.mkdirSync(w8 + '/.claude/state/sessions', { recursive: true });
  fs.mkdirSync(w8 + '/taskstate', { recursive: true });
  fs.mkdirSync(w8 + '/alpha', { recursive: true });
  fs.writeFileSync(w8 + '/.claude/projects.json', JSON.stringify({ version: 1, default: 'aproj', projects: { aproj: { dirs: ['alpha'] } } }));
  fs.writeFileSync(w8 + '/.claude/state/sessions/sidT.json', JSON.stringify({ project: 'aproj' }));
  fs.writeFileSync(w8 + '/alpha/WORK_QUEUE.sidT.md', '- [ ] do x\n');   // readable via the cwd=alpha candidate
  fs.writeFileSync(w8 + '/taskstate/aproj', 'BLOCKER FILE');             // canonical state dir (now taskstate/) cannot be created
  const trapped = fire(kg, { hook_event_name: 'Stop', cwd: w8 + '/alpha', session_id: 'sidT', transcript_path: w8 + '/t/sidT.jsonl' });
  ok(trapped === false, 'unwritable state dir + open work -> allow stop (fail OPEN, no permanent trap)');
  // 8b: stop_hook_active=true with open work -> allow (Claude Code re-entrant Stop ceiling honored)
  const w8b = fs.mkdtempSync(path.join(os.tmpdir(), 'ws8b-')).replace(/\\/g, '/');
  fs.mkdirSync(w8b + '/.claude/state/sessions', { recursive: true });
  fs.mkdirSync(w8b + '/.claude/state/aproj', { recursive: true });
  fs.writeFileSync(w8b + '/.claude/projects.json', JSON.stringify({ version: 1, default: 'aproj', projects: { aproj: { dirs: ['alpha'] } } }));
  fs.writeFileSync(w8b + '/.claude/state/sessions/sidH.json', JSON.stringify({ project: 'aproj' }));
  fs.writeFileSync(w8b + '/.claude/state/aproj/WORK_QUEUE.sidH.md', '- [ ] do x\n');
  const blockedActive = fire(kg, { hook_event_name: 'Stop', cwd: w8b, session_id: 'sidH', stop_hook_active: true, transcript_path: w8b + '/t/sidH.jsonl' });
  ok(blockedActive === false, 'stop_hook_active=true + open work -> allow stop (loop ceiling)');
  const blockedNormal = fire(kg, { hook_event_name: 'Stop', cwd: w8b, session_id: 'sidH', transcript_path: w8b + '/t/sidH.jsonl' });
  ok(blockedNormal === true, '...same session WITHOUT stop_hook_active -> keep going (block) [control]');
} else { ok(false, 'no keep-going hook to test'); }

// ---- INVARIANT 9: case-insensitive project resolution on a case-insensitive FS (no split state). ----
console.log('\n(9) case-insensitive project resolution:');
if (process.platform !== 'win32' && process.platform !== 'darwin') { ok(true, 'skipped (case-sensitive FS)'); }
else {
  const Sg = require(HOME + '/hooks/hook-state.js');
  const w9 = fs.mkdtempSync(path.join(os.tmpdir(), 'ws9-')).replace(/\\/g, '/');
  fs.mkdirSync(w9 + '/.claude', { recursive: true });
  fs.mkdirSync(w9 + '/demo-proj', { recursive: true });
  fs.writeFileSync(w9 + '/.claude/projects.json', JSON.stringify({ version: 1, default: 'dp', projects: { dp: { dirs: ['demo-proj'] } } }));
  const lo = Sg.resolveProject({ session_id: 'c', cwd: w9 + '/demo-proj' }).id;
  const up = Sg.resolveProject({ session_id: 'c', cwd: w9 + '/DEMO-PROJ' }).id;
  ok(lo === 'dp' && up === 'dp', `case-variant cwd resolves the SAME project (${lo} / ${up})`);
}

// ---- INVARIANT 10: usage-limit Stop hook is OPT-IN (.longrun), waits only with queued work, fails OPEN. ----
console.log('\n(10) usage-limit Stop hook opt-in + fails open:');
if (usageWait.length === 1) {
  const uw = usageWait[0].cmd;
  const wU = makeWorkspace();
  fs.writeFileSync(wU + '/.claude/state/sessions/sidU.json', JSON.stringify({ project: 'aproj' }));
  fs.mkdirSync(wU + '/.claude/state/aproj', { recursive: true });
  fs.writeFileSync(wU + '/.claude/state/aproj/WORK_QUEUE.sidU.md', '- [ ] x\n');
  const usageFile = wU + '/usage.json';
  fs.writeFileSync(usageFile, JSON.stringify({ available: true, ts: Date.now(), five_hour: { used_percentage: 99, resets_at: Math.floor(Date.now() / 1000) } }));
  const stop = { hook_event_name: 'Stop', cwd: wU, session_id: 'sidU', transcript_path: wU + '/t/sidU.jsonl' };
  ok(fire(uw, stop, { CLAUDE_USAGE_STATE: usageFile }) === false, 'limited + queued but NOT activated -> allow stop (off by default)');
  fs.writeFileSync(wU + '/.claude/state/aproj/.longrun', '');   // /longrun activates it for the project
  ok(fire(uw, stop, { CLAUDE_USAGE_STATE: wU + '/missing.json' }) === false, 'activated + no usage data -> allow stop (fail open)');
  ok(fire(uw, stop, { CLAUDE_USAGE_STATE: usageFile }) === true, 'activated + queued + 5h limit hit -> wait until reset then resume (block)');
} else { ok(true, 'no usage-limit Stop hook wired (skipped)'); }

// ---- INVARIANT 11: every SessionStart command hook actually runs clean (exit 0, no shell-tokenizing error). ----
// Added 2026-07-02 after the superpowers run-hook.cmd PowerShell-quoting bug ran broken, silently, all day —
// invariant 7 only checked the script PATH existed; it never fired the command, so a quoting/tokenizing bug in
// a hook that resolves fine on disk but explodes at shell-parse-time went undetected.
console.log('\n(11) every SessionStart command hook fires clean (exit 0, no shell-parse error):');
const ERR_PAT = /Unexpected token|is not recognized as an internal or external command|Cannot find module|CommandNotFoundException|SyntaxError/i;
const sessionStartHooks = HOOKS.filter(h => h.event === 'SessionStart' && h.cmd);
// Self-reference guard, added 2026-07-07 when hook_guarantee.js itself got wired into SessionStart: without
// this, invariant 11 spawns a live copy of THIS script to test it, whose own invariant 11 spawns another
// copy of itself, and so on -- bounded only by each level's 15s timeout eventually killing the deepest
// recursion and cascading a signal-killed (exit null, not exit 0) result back up through every parent. Skip
// actually executing anything that resolves to this file; invariant 7 already confirms its path resolves.
for (const h of sessionStartHooks) {
  const label = h.cmd.split(/[\\/]/).pop() + '  (' + h.src + ')';
  if (/hook_guarantee\.js/.test(h.cmd)) {
    ok(true, `${label} -> skipped (self-reference; spawning this script recursively would spawn it again, unbounded until a timeout kills the deepest copy)`);
    continue;
  }
  const r = spawnSync(h.cmd, { shell: true, input: JSON.stringify({ hook_event_name: 'SessionStart', session_id: 'guar-sid-ss', cwd: PROJECT }), encoding: 'utf8', timeout: 15000 });
  ok(r.status === 0 && !ERR_PAT.test(r.stderr || ''), `${label} -> exit ${r.status}${r.stderr ? ', stderr: ' + r.stderr.split('\n')[0].slice(0, 120) : ''}`);
}
if (sessionStartHooks.length === 0) ok(false, 'no SessionStart command hooks discovered to test (walk() may be broken)');

console.log(`\n${pass} passed, ${fail} failed`);
console.log(fail === 0
  ? 'GUARANTEE v3 HOLDS: Stop set = keep-going (+ optional usage-wait), no edit-blocking, project+session isolated, keyed via hook-state, copies identical (home==tracked), all paths resolve, fails-open (never traps), case-insensitive resolution, usage-wait gated.'
  : 'GUARANTEE v3 VIOLATED — see FAIL lines.');
process.exit(fail ? 1 : 0);
