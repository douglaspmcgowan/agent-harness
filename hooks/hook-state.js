#!/usr/bin/env node
'use strict';
// hook-state.js — shared PROJECT + SESSION keying for every state hook (keep-going, task-state-reminder,
// session-primer, ...). A project can span multiple folders, and multiple projects can live in one workspace
// folder, so state is keyed by (project, session) — never by bare cwd and never by a machine-global file.
//
// Resolution of a session's project (see resolveProject):
//   1) explicit binding   <root>/taskstate/sessions/<sid>.json  -> { "project": "<id>" }  (legacy .claude/state/ read too)
//   2) walk up from cwd, match an ancestor (relative to root, CASE-folded on Windows) against a project's "dirs"
//   3) launched at the ambiguous workspace root with no binding -> registry "default"
//   4) unregistered folder -> isolate by cwd basename (so it still can't collide with another project)
//
// State lives under  <root>/taskstate/<project>/  (relocated from <root>/.claude/state/<project>/) :
//   session-scoped : WORK_QUEUE.<sid>.md, CURRENT-TASK.<sid>.md, .need-user.<sid>, .work-complete.<sid>,
//                    .keep-going.progress.<sid>, .no-keepgoing.<sid>, .stop-autorun.<sid>
//   project-scoped : STATUS.md, LOG.md, BACKGROUND-TASKS.md   (shared across that project's sessions)
//
// READER getters return ONLY project-identified candidates: the canonical state dir, and (when cwd is a
// SUBDIR, never the bare root) the cwd-scoped path. There is NO project-less bare-root candidate — that was a
// cross-project leak (a session could read a file carrying no project identity). Legacy root files are brought
// into the scheme by a migration (see migrate-root-state / the harness-keying skill), not by a fallback read.
const fs = require('fs');
const path = require('path');

const norm = p => String(p || '').replace(/\\/g, '/').replace(/\/+$/, '');
const exists = p => { try { return fs.existsSync(p); } catch (_) { return false; } };
const readJSON = p => { try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (_) { return null; } };
// Windows + macOS default FS are case-insensitive: fold case so a case-variant cwd resolves the same project.
const fold = s => (process.platform === 'win32' || process.platform === 'darwin') ? String(s).toLowerCase() : String(s);

// State was relocated OUT of .claude/ (was '.claude/state') into a plain top-level 'taskstate/' dir, because
// Claude Code's built-in "sensitive file" write gate fires on ANY path containing .claude/ — independent of
// permissions.allow, and its "always allow" doesn't persist (upstream bug #43001). That made every hand-edit of
// a WORK_QUEUE/CURRENT-TASK under .claude/state/ prompt, every session. WRITERS now target taskstate/; READERS
// still fall back to the legacy .claude/state/ location so in-flight sessions (and un-migrated files) keep working.
const STATE_SUBDIR = 'taskstate';
const LEGACY_STATE_SUBDIR = '.claude/state';
const stateDirOf = proj => proj.root + '/' + STATE_SUBDIR + '/' + proj.id;
const legacyStateDirOf = proj => proj.root + '/' + LEGACY_STATE_SUBDIR + '/' + proj.id;

function readStdin() {
  let raw = '';
  try { raw = fs.readFileSync(0, 'utf8'); } catch (_) {}
  try { return JSON.parse(raw || '{}'); } catch (_) { return {}; }
}

function sid(input) {
  return String((input && input.session_id) || '').replace(/[^A-Za-z0-9_-]/g, '').slice(0, 64);
}

function cwdOf(input) { return norm((input && input.cwd) || process.cwd()); }

// nearest ancestor (incl. cwd) containing .claude/projects.json
function workspaceRoot(cwd) {
  let dir = norm(cwd) || norm(process.cwd());
  for (let i = 0; i < 24 && dir; i++) {
    if (exists(dir + '/.claude/projects.json')) return dir;
    const parent = norm(path.dirname(dir));
    if (parent === dir) break;
    dir = parent;
  }
  return norm(cwd) || norm(process.cwd());
}

function registry(root) { return readJSON(root + '/.claude/projects.json'); }
const cleanDirs = p => (p && p.dirs || []).map(norm).filter(d => d && d !== '.'); // never let '' or '.' expand to root

function resolveProject(input) {
  const cwd = cwdOf(input);
  const root = workspaceRoot(cwd);
  const reg = registry(root);
  const s = sid(input);

  // 1) explicit session -> project binding
  if (s) {
    const b = readJSON(root + '/' + STATE_SUBDIR + '/sessions/' + s + '.json')
           || readJSON(root + '/' + LEGACY_STATE_SUBDIR + '/sessions/' + s + '.json');
    if (b && b.project) return { id: String(b.project), root, reg, via: 'binding' };
  }
  // 2) walk up from cwd; match an ancestor against a project's dirs (case-folded on case-insensitive FS)
  if (reg && reg.projects) {
    let dir = cwd;
    for (let i = 0; i < 24 && dir && dir.length >= root.length; i++) {
      const rel = (dir === root) ? '' : norm(path.relative(root, dir));
      if (rel) {
        const relF = fold(rel);
        for (const [id, p] of Object.entries(reg.projects)) {
          if (cleanDirs(p).some(d => { const df = fold(d); return relF === df || relF.startsWith(df + '/'); }))
            return { id, root, reg, via: 'cwd' };
        }
      }
      const parent = norm(path.dirname(dir));
      if (parent === dir) break;
      dir = parent;
    }
  }
  // 3) ambiguous workspace root with no binding -> registry default
  if (reg && reg.default && cwd === root) return { id: String(reg.default), root, reg, via: 'default' };
  // 4) unregistered folder -> isolate by basename (case-folded so a case-variant cwd maps to one id)
  return { id: fold(path.basename(cwd)) || 'default', root, reg, via: 'basename' };
}

function projectId(input) { return resolveProject(input).id; }

function stateDir(input) {
  return stateDirOf(resolveProject(input));
}

// returns true iff the directory exists (created or already present) — callers use this to fail OPEN on failure
function ensureDir(d) { try { fs.mkdirSync(d, { recursive: true }); return true; } catch (_) { return exists(d); } }

// ---- path builders ----
// READER candidates: canonical state dir, plus cwd-scoped ONLY when cwd is a subdir (never the bare root).
function sessionDocCandidates(input, base) { // base e.g. 'WORK_QUEUE' -> <base>.<sid>.md
  const s = sid(input); if (!s) return [];
  const r = resolveProject(input), cwd = cwdOf(input), name = base + '.' + s + '.md';
  const out = [stateDirOf(r) + '/' + name, legacyStateDirOf(r) + '/' + name];
  if (cwd !== r.root) out.push(cwd + '/' + name);
  return orderByFreshness(dedupe(out));
}
function sessionFlagCandidates(input, base) { // base e.g. '.need-user' -> <base>.<sid>
  const s = sid(input); if (!s) return [];
  const r = resolveProject(input), cwd = cwdOf(input), name = base + '.' + s;
  const out = [stateDirOf(r) + '/' + name, legacyStateDirOf(r) + '/' + name];
  if (cwd !== r.root) out.push(cwd + '/' + name);
  return dedupe(out);
}
function projectDocCandidates(input, name) {
  const r = resolveProject(input);
  return orderByFreshness(dedupe([stateDirOf(r) + '/' + name, legacyStateDirOf(r) + '/' + name]));
}
// WRITER paths: always the canonical state-dir location.
function sessionDocWrite(input, base) { return stateDir(input) + '/' + base + '.' + sid(input) + '.md'; }
function sessionFlagWrite(input, base) { return stateDir(input) + '/' + base + '.' + sid(input); }
function projectDocWrite(input, name) { return stateDir(input) + '/' + name; }

function firstExisting(cands) { for (const c of (cands || [])) if (exists(c)) return c; return null; }
function dedupe(a) { return a.filter((v, i) => a.indexOf(v) === i); }
// During the .claude/state -> taskstate transition a pre-relocation session can still be writing the LEGACY
// copy while the new canonical copy sits frozen at migration time. Reading strictly canonical-first would then
// serve stale content, so among candidates that actually exist prefer the most-recently modified; non-existent
// candidates keep their original (priority) order at the tail. Used for the doc readers (WORK_QUEUE/CURRENT-TASK/
// STATUS/LOG), not the flag readers (existence, not freshness, is what those care about).
function orderByFreshness(paths) {
  const stamped = (paths || []).map(p => { let m = -1; try { m = fs.statSync(p).mtimeMs; } catch (_) {} return { p, m }; });
  const live = stamped.filter(x => x.m >= 0).sort((a, b) => b.m - a.m).map(x => x.p);
  const missing = stamped.filter(x => x.m < 0).map(x => x.p);
  return [...live, ...missing];
}

module.exports = {
  norm, exists, fold, readStdin, sid, cwdOf, workspaceRoot, registry, cleanDirs, resolveProject, projectId,
  stateDir, stateDirOf, legacyStateDirOf, STATE_SUBDIR, LEGACY_STATE_SUBDIR,
  ensureDir, sessionDocCandidates, sessionFlagCandidates, projectDocCandidates,
  sessionDocWrite, sessionFlagWrite, projectDocWrite, firstExisting,
};

// CLI (used by skills like /autowait): `node hook-state.js statedir|project [cwd] [session_id]`
if (require.main === module) {
  const cmd = process.argv[2];
  const input = { cwd: process.argv[3] || process.cwd(), session_id: process.argv[4] || '' };
  if (cmd === 'statedir') process.stdout.write(stateDir(input) + '\n');
  else if (cmd === 'project') process.stdout.write(resolveProject(input).id + '\n');
  else process.stderr.write('usage: node hook-state.js statedir|project [cwd] [session_id]\n');
}
