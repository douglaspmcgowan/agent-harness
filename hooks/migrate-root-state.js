#!/usr/bin/env node
'use strict';
// Idempotent migration: bring legacy cwd-root session files into the canonical taskstate/<project>/ location,
// using the session->project bindings in taskstate/sessions/ (legacy .claude/state/sessions/ read too). COPIES (never deletes the live original) so an
// in-flight session can't lose data; canonical reads win going forward. Run from the workspace root, or pass the
// root as argv[2]. Safe to run repeatedly (skips files already migrated). Used by the harness-keying skill.
const fs = require('fs');
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));

const root = S.norm(process.argv[2] || process.cwd());
const reg = S.registry(root);
if (!reg) { console.error('no .claude/projects.json at ' + root); process.exit(1); }

// bindings may live in the new taskstate/ location or the legacy .claude/state/ one — read both.
const sessDirNew = root + '/' + S.STATE_SUBDIR + '/sessions';
const sessDirLegacy = root + '/' + S.LEGACY_STATE_SUBDIR + '/sessions';
const readBindings = d => { try { return fs.readdirSync(d).filter(f => f.endsWith('.json')).map(f => [d, f]); } catch (_) { return []; } };
const bindingEntries = [...readBindings(sessDirNew), ...readBindings(sessDirLegacy)];
const seen = new Set();
const bindings = bindingEntries.filter(([, f]) => (seen.has(f) ? false : (seen.add(f), true)));

let moved = 0;
for (const [dir, f] of bindings) {
  const sid = f.replace(/\.json$/, '');
  let proj; try { proj = (JSON.parse(fs.readFileSync(dir + '/' + f, 'utf8')) || {}).project; } catch (_) {}
  if (!proj) continue;
  const dst = root + '/' + S.STATE_SUBDIR + '/' + proj;
  S.ensureDir(dst);
  const names = ['CURRENT-TASK.' + sid + '.md', 'WORK_QUEUE.' + sid + '.md',
    '.need-user.' + sid, '.work-complete.' + sid, '.no-keepgoing.' + sid, '.stop-autorun.' + sid, '.keep-going.progress.' + sid];
  for (const n of names) {
    const src = root + '/' + n, out = dst + '/' + n;
    if (S.exists(src) && !S.exists(out)) {
      try { fs.copyFileSync(src, out); moved++; console.log('migrated', n, '->', proj); } catch (e) { console.error('skip', n, e.message); }
    }
  }
}
console.log('migration done; ' + moved + ' file(s) copied into taskstate/<project>/');
