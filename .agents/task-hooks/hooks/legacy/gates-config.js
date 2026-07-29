#!/usr/bin/env node
'use strict';
// gates-config.js — shared OPT-IN resolver for the "always-on gate" hooks (dep-audit, semgrep, test-green).
// A gate hook is a NO-OP unless the project has opted in with a `.claude/gates.json` at (or above) the cwd.
//
// OPT-IN FORMAT — create `<project-root>/.claude/gates.json`:
//   {
//     "dep_audit":  true,                      // warn on install of a package missing from PyPI/npm (slopsquat guard)
//     "semgrep":    true,                      // warn on high-severity Semgrep findings in the staged diff at commit
//     "test_green": true,                      // warn at Stop if the test suite isn't green
//     "test_command": "python -m pytest -q"    // REQUIRED for test_green to activate; run from project root
//   }
// Absent file, unreadable file, or a false/missing key => that gate does nothing. All gates WARN only (never block).
//
// Resolution: walk up from cwd (max 24 levels) to the first ancestor holding `.claude/gates.json`.
const fs = require('fs');
const path = require('path');

const norm = p => String(p || '').replace(/\\/g, '/').replace(/\/+$/, '');

function readStdin() {
  let raw = '';
  try { raw = fs.readFileSync(0, 'utf8'); } catch (_) {}
  try { return JSON.parse(raw || '{}'); } catch (_) { return {}; }
}

// Returns { cfg, root } for the nearest ancestor with .claude/gates.json, or null if none found / unreadable.
function findGates(cwd) {
  let dir = norm(cwd) || norm(process.cwd());
  for (let i = 0; i < 24 && dir; i++) {
    const p = dir + '/.claude/gates.json';
    try {
      if (fs.existsSync(p)) {
        const cfg = JSON.parse(fs.readFileSync(p, 'utf8'));
        return { cfg: (cfg && typeof cfg === 'object') ? cfg : {}, root: dir };
      }
    } catch (_) { return null; }   // present but unparseable => fail open (no-op), don't guess
    const parent = norm(path.dirname(dir));
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

// True iff the named gate is opted in for this cwd. gate e.g. 'dep_audit' | 'semgrep' | 'test_green'.
function gateOn(cwd, gate) {
  const g = findGates(cwd);
  return !!(g && g.cfg && g.cfg[gate] === true);
}

module.exports = { norm, readStdin, findGates, gateOn };
