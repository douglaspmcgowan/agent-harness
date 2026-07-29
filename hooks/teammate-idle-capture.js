#!/usr/bin/env node
'use strict';
// TeammateIdle diagnostic capture -- added 2026-07-07. Zero real TeammateIdle payloads exist anywhere in
// this machine's session history (confirmed via exhaustive transcript search across every project) despite
// CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 being enabled -- no hook has ever been wired to this event, so its
// real field shape (session_id? cwd? a teammate identifier? a status/reason field?) is unknown. Per
// CLAUDE.md's "don't fabricate" rule, this does NOT attempt real robustness logic yet -- guessing field
// names now would risk silently doing nothing (checking a field that doesn't exist) while looking like real
// coverage. This hook does exactly one thing: log the RAW stdin payload the next time a teammate actually
// goes idle, so a real robustness fix (matching Douglas's "make the keep going hook robust" ask) can be
// built off real data instead of a guess. Always exits 0 -- diagnostic-only, never prevents the teammate
// from going idle, matches the fail-open discipline of every other Stop-adjacent hook in this harness.
const fs = require('fs');
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));

const LOG_PATH = path.join(__dirname, 'teammate-idle-capture.log');

function main() {
  const input = S.readStdin();
  const entry = { capturedAt: new Date().toISOString(), payload: input };
  fs.appendFileSync(LOG_PATH, JSON.stringify(entry) + '\n');
}

if (require.main === module) {
  try { main(); } catch (_) { /* fail open -- never block a teammate over a logging failure */ }
  process.exit(0); // diagnostic-only -- never prevents idle, never wakes/blocks anything
}

module.exports = { main, LOG_PATH };
