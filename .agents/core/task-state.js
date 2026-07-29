#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const norm = value => String(value || '').replace(/\\/g, '/').replace(/\/+$/, '');
const exists = value => {
  try { return fs.existsSync(value); } catch (_) { return false; }
};
const readJson = value => {
  try { return JSON.parse(fs.readFileSync(value, 'utf8')); } catch (_) { return null; }
};
const fold = value => process.platform === 'win32' || process.platform === 'darwin'
  ? String(value).toLowerCase()
  : String(value);

function readStdin() {
  let raw = '';
  try { raw = fs.readFileSync(0, 'utf8'); } catch (_) {}
  try { return JSON.parse(raw || '{}'); } catch (_) { return {}; }
}

function cwdOf(input) {
  return norm((input && input.cwd) || process.cwd());
}

function sessionId(input) {
  const raw = (input && (input.session_id || input.conversation_id || input.thread_id || input.task_id)) || '';
  return String(raw).replace(/[^A-Za-z0-9_-]/g, '').slice(0, 64);
}

function findRoot(cwd) {
  let directory = cwdOf({ cwd });
  let repositoryRoot = null;
  for (let depth = 0; depth < 32 && directory; depth += 1) {
    if (exists(directory + '/.agents/projects.json') || exists(directory + '/.claude/projects.json')) return directory;
    if (!repositoryRoot && (exists(directory + '/.git') || exists(directory + '/AGENTS.md'))) repositoryRoot = directory;
    const parent = norm(path.dirname(directory));
    if (parent === directory) break;
    directory = parent;
  }
  return repositoryRoot || cwdOf({ cwd });
}

function registry(root) {
  return readJson(root + '/.agents/projects.json') || readJson(root + '/.claude/projects.json');
}

function resolveProject(input) {
  const cwd = cwdOf(input);
  const root = findRoot(cwd);
  const reg = registry(root);
  const sid = sessionId(input);
  const hasGit = exists(root + '/.git');

  if (sid) {
    const binding = readJson(root + '/taskstate/sessions/' + sid + '.json');
    if (binding && binding.project) return { id: String(binding.project), root, reg, via: 'binding', hasGit };
  }

  if (reg && reg.projects) {
    let directory = cwd;
    for (let depth = 0; depth < 32 && directory.length >= root.length; depth += 1) {
      const relative = norm(path.relative(root, directory));
      if (relative) {
        for (const [id, project] of Object.entries(reg.projects)) {
          const dirs = Array.isArray(project.dirs) ? project.dirs : [];
          if (dirs.some(item => {
            const candidate = fold(norm(item));
            const actual = fold(relative);
            return candidate && (actual === candidate || actual.startsWith(candidate + '/'));
          })) return { id, root, reg, via: 'cwd', hasGit };
        }
      }
      const parent = norm(path.dirname(directory));
      if (parent === directory) break;
      directory = parent;
    }
    if (reg.default && cwd === root) return { id: String(reg.default), root, reg, via: 'default', hasGit };
  }

  return { id: fold(path.basename(root)) || 'default', root, reg, via: hasGit ? 'repository' : 'workspace', hasGit };
}

function stateDir(project) {
  return project.root + '/taskstate/' + project.id;
}

function existing(paths) {
  return paths.filter(exists);
}

function sessionDocCandidates(input, base) {
  const project = resolveProject(input);
  const sid = sessionId(input);
  const candidates = [];
  if (sid) candidates.push(stateDir(project) + '/' + base + '.' + sid + '.md');
  if (!sid || project.hasGit) candidates.push(project.root + '/' + base + '.md');
  return existing(candidates);
}

function projectDocCandidates(input, name) {
  const project = resolveProject(input);
  const members = project.reg && project.reg.projects && project.reg.projects[project.id]
    ? project.reg.projects[project.id].dirs || []
    : [];
  return existing([
    stateDir(project) + '/' + name,
    project.root + '/' + name,
    ...members.map(item => project.root + '/' + norm(item) + '/' + name),
  ]);
}

module.exports = {
  norm,
  exists,
  readStdin,
  cwdOf,
  sessionId,
  findRoot,
  registry,
  resolveProject,
  stateDir,
  sessionDocCandidates,
  projectDocCandidates,
};
