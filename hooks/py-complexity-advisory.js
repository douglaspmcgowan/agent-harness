#!/usr/bin/env node
'use strict';
// PostToolUse(Edit|Write) — after a real edit to a cad-forge Python file, runs `radon cc` (a plain
// subprocess, no LLM/API call of any kind) against JUST that file and surfaces an advisory ONLY when a
// function's complexity grade crosses C or worse (radon grades: A best .. F worst). Never blocks --
// always exits 0. Modeled directly on warn-large-read.js's shape: detection-only, fail-open, cheap.
//
// WHY: Douglas has /tech-debt-audit (pip-audit/ruff/vulture/pydeps/mypy) already, but nothing gives a
// numeric complexity score on his most-patched cad-forge files (gate.py, accept.py, review_flaws.py,
// build_structure_1u.py). He said he doesn't have time to invoke skills manually -- this makes the
// py-complexity skill's own tool (radon) fire automatically after an edit, instead of waiting to be asked.
//
// COST: zero LLM/API tokens from this hook itself. It shells out to a local `radon` binary and parses
// its JSON. The ONLY thing that ever reaches the model is the short advisory string below, and only when
// a real threshold is crossed -- most edits produce no output at all.
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

// Start scoped to cad-forge per Douglas's instruction; widen later by adding more prefixes here.
const SCOPED_PREFIXES = ['cad-forge/', 'cad-forge\\'];

// radon cc grade bands (cyclomatic complexity): A 1-5, B 6-10, C 11-20, D 21-30, E 31-40, F 41+.
// "Crosses a real threshold" per Douglas's instruction = C or worse only (A/B never reported).
const ADVISORY_GRADES = new Set(['C', 'D', 'E', 'F']);

// Prefer a python.exe living next to a `radon` console-script in the same Scripts/ dir as the known-good
// interpreter, so this works even though `python`/`python3` on PATH resolve to a broken 3.14 with no wheels.
const PYTHON_CANDIDATES = [
  'C:/Users/dmcgowa2/scoop/apps/python313/current/python.exe',
];

function readStdin() {
  let raw = '';
  try { raw = fs.readFileSync(0, 'utf8'); } catch (_) {}
  try { return JSON.parse(raw || '{}'); } catch (_) { return {}; }
}

function isScoped(filePath) {
  const norm = filePath.replace(/\\/g, '/');
  return SCOPED_PREFIXES.some(p => norm.includes(p.replace(/\\/g, '/')));
}

// Windows quirk: spawnSync can't exec a .cmd/.bat directly without going through the shell (EINVAL) --
// shell:true is required there. POSIX doesn't need it. Applied to every spawnSync of a *found* radon
// binary (not to `where`/`which` themselves, which are always real executables).
const SPAWN_OPTS = { encoding: 'utf8', shell: process.platform === 'win32' };

function findRadon() {
  // 1) a `radon` executable on PATH (works if it was pip-installed with scripts on PATH). `where` on
  // Windows can return multiple candidates (e.g. a shell-script shim with no extension alongside the
  // real .exe/.cmd) -- try each candidate in order and keep the first one that actually runs, rather
  // than blindly trusting the first line.
  const which = spawnSync(process.platform === 'win32' ? 'where' : 'which', ['radon'], { encoding: 'utf8' });
  if (which.status === 0 && which.stdout.trim()) {
    const candidates = which.stdout.trim().split(/\r?\n/).map(s => s.trim()).filter(Boolean);
    for (const c of candidates) {
      const probe = spawnSync(c, ['--version'], SPAWN_OPTS);
      if (probe.status === 0) return { cmd: c, args: [] };
    }
  }
  // 2) fall back to `python -m radon` using the known-good 3.13 interpreter
  for (const py of PYTHON_CANDIDATES) {
    if (fs.existsSync(py)) {
      const probe = spawnSync(py, ['-m', 'radon', '--version'], SPAWN_OPTS);
      if (probe.status === 0) return { cmd: py, args: ['-m', 'radon'] };
    }
  }
  return null;
}

function main() {
  const input = readStdin();
  const toolName = input.tool_name;
  if (toolName !== 'Edit' && toolName !== 'Write' && toolName !== 'MultiEdit') return;

  const ti = input.tool_input || {};
  const filePath = ti.file_path;
  if (!filePath || !filePath.endsWith('.py')) return;
  if (!isScoped(filePath)) return; // out of scope for now (cad-forge/** only)

  let stat;
  try { stat = fs.statSync(filePath); } catch (_) { return; } // file gone / not readable -- nothing to say
  if (!stat.isFile()) return;

  const radon = findRadon();
  if (!radon) return; // tool not installed -- fail open silently, this is advisory-only

  const result = spawnSync(radon.cmd, [...radon.args, 'cc', '-j', filePath], {
    ...SPAWN_OPTS,
    timeout: 8000,
  });
  if (result.status !== 0 || !result.stdout) return; // radon errored on this file -- fail open

  let parsed;
  try { parsed = JSON.parse(result.stdout); } catch (_) { return; }

  const fileKey = Object.keys(parsed)[0];
  const entries = fileKey ? parsed[fileKey] : null;
  if (!Array.isArray(entries)) return;

  const flagged = entries.filter(e => e && ADVISORY_GRADES.has(e.rank));
  if (flagged.length === 0) return; // the common case -- nothing crossed the threshold, stay silent

  flagged.sort((a, b) => (b.complexity || 0) - (a.complexity || 0));
  const lines = flagged.slice(0, 5).map(e =>
    `  ${e.rank}  cc=${e.complexity}  ${e.name}  (line ${e.lineno})`);
  const more = flagged.length > 5 ? `\n  ...and ${flagged.length - 5} more` : '';

  process.stderr.write(
    `py-complexity-advisory: ${path.basename(filePath)} has ${flagged.length} function(s) at radon ` +
    `grade C+ (advisory only, not a block):\n${lines.join('\n')}${more}\n` +
    `Consider the py-complexity skill's refactoring patterns (extract function, guard clauses, lookup ` +
    `tables) if this keeps growing. Full scan: radon cc "${filePath}" -s\n`);
}

try { main(); } catch (_) { /* fail open -- never block or throw on an Edit/Write */ }
process.exit(0);
