#!/usr/bin/env node
'use strict';
// Harness keying maintainer — ONE command to "update all this stuff when something changes": re-sync the canonical
// hooks to the tracked mirror, migrate stray legacy root state into taskstate/<project>/, validate the project
// registry, list bound sessions, and run the invariant guarantee. Run: node harness-keying.js [workspaceRoot]
// Exit 0 = everything consistent; exit 1 = issues found (see the ⚠ lines). Used by the /harness-keying skill.
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const S = require(path.join(__dirname, 'hook-state.js'));

const HOME = path.join(process.env.USERPROFILE || process.env.HOME || '', '.claude').replace(/\\/g, '/');
const NODE = process.execPath;
const root = S.norm(process.argv[2] || process.cwd());
let problems = 0;
const warn = m => { problems++; console.log('  ! ' + m); };
const okline = m => console.log('  + ' + m);

console.log('HARNESS KEYING  —  ' + root + '\n');

// 1) re-sync the canonical keying hooks: home (active) -> tracked mirror (so a change propagates to sync)
const CANON = ['keep-going.js', 'hook-state.js', 'task-state-reminder.js', 'session-primer.js', 'keep-going.test.js', 'migrate-root-state.js', 'harness-keying.js', 'wait-on-usage-limit.js', 'hook_guarantee.js'];
const tracked = root + '/claude-global-config/hooks';
if (fs.existsSync(tracked)) {
  let n = 0;
  for (const f of CANON) { try { fs.copyFileSync(HOME + '/hooks/' + f, tracked + '/' + f); n++; } catch (e) { warn('sync ' + f + ': ' + e.message); } }
  okline('synced ' + n + ' canonical hooks  home -> tracked mirror');
} else warn('no tracked hooks dir at ' + tracked);

// 2) leftover Stop-hook scripts (clutter that should be removed — only keep-going[.test] belongs)
let stale = [];
const STOP_OK = new Set(['keep-going.js', 'keep-going.test.js', 'wait-on-usage-limit.js']); // the sanctioned Stop scripts
try { stale = fs.readdirSync(HOME + '/hooks').filter(f => /(stop|double-shot|wait-on-usage|toast)/i.test(f) && !STOP_OK.has(f)); } catch (_) {}
if (stale.length) warn('leftover Stop-hook scripts in ~/.claude/hooks (remove if stale): ' + stale.join(', '));
else okline('no leftover Stop-hook scripts (keep-going + wait-on-usage-limit only)');

// 3) migrate stray legacy root state into taskstate/<project>/
const mig = spawnSync(NODE, [HOME + '/hooks/migrate-root-state.js', root], { encoding: 'utf8' });
process.stdout.write((mig.stdout || '').split('\n').filter(Boolean).map(l => '    ' + l).join('\n') + '\n');

// 4) validate the registry: dirs exist, no dir owned by two projects, default valid
const reg = S.registry(root);
if (!reg) warn('no .claude/projects.json at ' + root);
else {
  const owner = {};
  for (const [id, p] of Object.entries(reg.projects || {})) {
    for (const d of S.cleanDirs(p)) {
      if (!fs.existsSync(root + '/' + d)) warn('project "' + id + '": folder "' + d + '" does not exist');
      if (owner[d]) warn('folder "' + d + '" is claimed by BOTH "' + owner[d] + '" and "' + id + '"'); else owner[d] = id;
    }
  }
  if (reg.default && !(reg.projects || {})[reg.default]) warn('default "' + reg.default + '" is not a defined project');
  okline('registry: ' + Object.keys(reg.projects || {}).length + ' projects, default = ' + reg.default);
}

// 5) bound sessions -> project
// bindings may live in taskstate/sessions (new) or .claude/state/sessions (legacy) — list both, de-duped by filename
const readBinds = d => { try { return fs.readdirSync(d).filter(f => f.endsWith('.json')).map(f => [d, f]); } catch (_) { return []; } };
const seenBind = new Set();
const binds = [...readBinds(root + '/' + S.STATE_SUBDIR + '/sessions'), ...readBinds(root + '/' + S.LEGACY_STATE_SUBDIR + '/sessions')]
  .filter(([, f]) => (seenBind.has(f) ? false : (seenBind.add(f), true)));
console.log('  bound sessions: ' + binds.length);
for (const [dir, f] of binds) {
  let proj; try { proj = (JSON.parse(fs.readFileSync(dir + '/' + f, 'utf8')) || {}).project; } catch (_) {}
  console.log('      ' + f.replace('.json', '').slice(0, 8) + '  ->  ' + proj);
}

// 6) the invariant guarantee (one Stop hook, isolation, fail-open, copies identical, ...)
const guard = HOME + '/hooks/hook_guarantee.js';
if (fs.existsSync(guard)) {
  const g = spawnSync(NODE, [guard, root], { encoding: 'utf8' });
  const lines = (g.stdout || '').trim().split('\n');
  const tally = lines.filter(l => /passed,.*failed/.test(l)).pop() || '';
  if (g.status === 0) okline('guarantee: ' + tally.trim());
  else { warn('guarantee FAILED: ' + tally.trim()); process.stdout.write(lines.filter(l => /FAIL/.test(l)).map(l => '      ' + l.trim()).join('\n') + '\n'); }
} else warn('guarantee script not found at ' + guard);

console.log(problems ? ('\nKEYING: ' + problems + ' issue(s) — see ! lines above.') : '\nKEYING OK — hooks synced, registry valid, one Stop hook, isolation holds.');
process.exit(problems ? 1 : 0);
