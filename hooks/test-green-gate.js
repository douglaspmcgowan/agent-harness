#!/usr/bin/env node
'use strict';
// test-green-gate.js — Stop hook. WARN-ONLY opt-in gate. Follows the keep-going/hook-state Stop conventions:
// exit 0 = allow the stop (ALWAYS — this gate never blocks), stderr text only, fail OPEN on any error.
// When a project opts in, it runs the project's own test command at Stop and WARNS (stderr) if the suite
// isn't green — so "done" starts to mean "tests pass", without ever trapping a session.
//
// OPT-IN: no-op unless `.claude/gates.json` (at or above cwd) has BOTH:
//     "test_green": true
//     "test_command": "<cmd run from the gates.json project root>"   e.g. "python -m pytest -q"
//   (test_command is REQUIRED — this gate never guesses a test entry point.)
// NEVER BLOCKS: always exits 0. Fail-open on any error. Subagent/Workflow stops pass through untouched.
const { execSync } = require('child_process');
const path = require('path');
const { findGates } = require(path.join(__dirname, 'gates-config.js'));

function readStdin() {
  const fs = require('fs');
  let raw = ''; try { raw = fs.readFileSync(0, 'utf8'); } catch (_) {}
  try { return JSON.parse(raw || '{}'); } catch (_) { return {}; }
}

function main() {
  const input = readStdin();
  const cwd = (input && input.cwd) || process.cwd();
  const tpat = String((input && input.transcript_path) || '').replace(/\\/g, '/');

  // Don't fire on subagent / Workflow-stage stops — only the top-level session (mirrors keep-going R5).
  if (/[\/](subagents|workflows)[\/]/i.test(tpat) || /[\/](subagents|workflows)[\/]/i.test(cwd.replace(/\\/g, '/'))) return;
  if (input && input.stop_hook_active) return;                 // already re-entered; don't re-run the suite

  const g = findGates(cwd);
  if (!g || !g.cfg || g.cfg.test_green !== true) return;        // not opted in
  const testCmd = typeof g.cfg.test_command === 'string' ? g.cfg.test_command.trim() : '';
  if (!testCmd) {
    process.stderr.write('test-green gate: "test_green" is on but no "test_command" set in .claude/gates.json — skipped.\n');
    return;
  }

  let green = true, tail = '';
  try {
    execSync(testCmd, { cwd: g.root, timeout: 180000, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true });
  } catch (e) {
    green = false;
    const buf = (e && (e.stdout || e.stderr)) ? String(e.stdout || '') + String(e.stderr || '') : '';
    tail = buf.split(/\r?\n/).filter(Boolean).slice(-3).join(' | ').slice(0, 300);
  }
  if (!green) {
    process.stderr.write('⚠ test-green gate: `' + testCmd + '` is NOT green at stop (project ' + g.root + '). ' +
      'Last output: ' + (tail || '(none)') + '. This is a warning only — the stop is allowed.\n');
  }
}

// Fail OPEN: any uncaught error allows the stop. A broken gate must never trap a session. Always exit 0.
try { main(); } catch (_) {}
process.exit(0);
