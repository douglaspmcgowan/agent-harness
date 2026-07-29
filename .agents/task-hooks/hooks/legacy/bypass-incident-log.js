#!/usr/bin/env node
'use strict';
// PostToolUse — Dropped #6 (Session Detective Sweep, 2026-07-02): "Claude tried to bypass its own
// bulk-delete safety hook twice, in the same turn, without asking... caught only by a separate
// classifier, not by its own judgment... Log every caught bypass attempt to a durable incident
// file (not just the in-turn denial) so a SECOND attempt at defeating the SAME guard in the SAME
// turn is visible as a trend, not two independent, forgettable denials."
//
// Detection-only, same philosophy as the SentinelOne monitor: never blocks, never modifies
// anything else — the classifier already stopped the action. This hook's only job is to make
// that event durable (a project-scoped, append-only log) so a repeat pattern is visible on
// review later, instead of evaporating once the in-turn error message scrolls off.
//
// Scope note: matcher deliberately EXCLUDES Write/Edit to respect hook_guarantee.js's existing
// Invariant 2 ("no PostToolUse hook fires on Write/Edit"). This means a classifier denial on a
// Write/Edit call itself (which does happen — e.g. this exact session hit denials editing
// hooks.json and settings.json) is NOT captured by this hook. Logged as a known gap, not silently.
const fs = require('fs');
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));

const DENIAL_RE = /denied by the Claude Code auto mode classifier\.\s*Reason:\s*(\[[^\]]+\])?\s*([^.]*)/i;

function extractDenial(toolResponse) {
  const text = typeof toolResponse === 'string' ? toolResponse : JSON.stringify(toolResponse || '');
  const m = DENIAL_RE.exec(text);
  if (!m) return null;
  return { category: (m[1] || '').replace(/[\[\]]/g, '') || null, reason: (m[2] || '').trim().slice(0, 300) };
}

function main() {
  const input = S.readStdin();
  const denial = extractDenial(input.tool_response);
  if (!denial) return;

  const proj = S.resolveProject(input);
  const dir = S.stateDirOf(proj);
  const record = {
    ts: new Date().toISOString(),
    sid: S.sid(input),
    tool: input.tool_name || null,
    category: denial.category,
    reason: denial.reason,
  };
  try {
    S.ensureDir(dir);
    fs.appendFileSync(dir + '/.classifier-denials.log', JSON.stringify(record) + '\n');
  } catch (_) {}
}

if (require.main === module) {
  try { main(); } catch (_) { /* detection-only: never throw, never block */ }
}

module.exports = { extractDenial };
