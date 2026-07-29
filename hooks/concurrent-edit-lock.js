#!/usr/bin/env node
'use strict';
// PreToolUse — Automatable #5 (Session Detective Sweep, 2026-07-02): "no shared lock between
// concurrent sessions editing the same files... you had to manually track and announce that a
// separate session was already editing the same fix-handoff files."
//
// Detection/warning-ONLY - never blocks. hook_guarantee.js's Invariant 3 guarantees a command
// edit hook never blocks a normal .py/.html edit; this hook respects the same principle for the
// shared coordination files it watches. It writes a short-lived marker naming which session
// touched a shared state file, and warns (via stderr, non-blocking) if a DIFFERENT session's
// marker is still fresh - so a second session finds out automatically instead of Douglas having
// to notice and announce it by hand.
const fs = require('fs');
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));

const FRESH_MS = 5 * 60 * 1000; // 5 min - long enough to catch a genuinely concurrent edit,
                                 // short enough that a stale marker from yesterday doesn't warn

function relevantPath(filePath) {
  // Only the shared, multi-session-coordination files this finding is about - not every edit
  // in the workspace (that would be noisy and outside this fix's scope).
  const p = String(filePath || '').replace(/\\/g, '/');
  return /\/(?:taskstate|\.claude\/state)\/[^/]+\/(WORK_QUEUE|STATUS|CURRENT-TASK)[^/]*\.md$/.test(p)
      || /\/(WORK_QUEUE|STATUS|CURRENT-TASK)\.md$/.test(p);
}

function lockPathFor(filePath) {
  return filePath + '.lock.json';
}

function checkAndMark(filePath, sid, now) {
  const lp = lockPathFor(filePath);
  let prior = null;
  try { prior = JSON.parse(fs.readFileSync(lp, 'utf8')); } catch (_) {}
  let warning = null;
  if (prior && prior.sid && prior.sid !== sid && (now - prior.ts) < FRESH_MS) {
    warning = 'another session (' + prior.sid + ') edited ' + path.basename(filePath) + ' ' +
      Math.round((now - prior.ts) / 1000) + 's ago — possible concurrent-edit conflict, check before overwriting its changes';
  }
  try { fs.writeFileSync(lp, JSON.stringify({ sid: sid, ts: now })); } catch (_) {}
  return warning;
}

function main() {
  const input = S.readStdin();
  const filePath = input.tool_input && input.tool_input.file_path;
  if (!filePath || !relevantPath(filePath)) return;
  const sid = S.sid(input);
  if (!sid) return;
  const warning = checkAndMark(filePath, sid, Date.now());
  if (warning) process.stderr.write('concurrent-edit-lock: ' + warning + '\n');
}

if (require.main === module) {
  try { main(); } catch (_) { /* fail open — never block, never throw */ }
  process.exit(0); // NEVER block a normal edit (matches hook_guarantee.js Invariant 3)
}

module.exports = { relevantPath, checkAndMark, lockPathFor };
