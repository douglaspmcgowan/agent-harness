#!/usr/bin/env node
'use strict';
// statusLine command (wired via settings.json "statusLine"). TWO jobs:
//   1) print a one-line status (model · ctx% · $cost · 5h%) to stdout for the Claude Code status bar;
//   2) SIDE EFFECT: persist the account 5h / 7d usage window to ~/.claude/usage-state.json so the Stop hook
//      wait-on-usage-limit.js can read five_hour.used_percentage + resets_at and sleep out the limit in a /longrun.
// The rate_limits block is Pro/Max-only and only appears AFTER the first API response (Claude Code docs; added
// v1.2.80). When it's absent we persist {available:false} so the wait hook safely no-ops. resets_at is a Unix
// timestamp (seconds). Fails OPEN: any error still prints a minimal line and never throws (a statusLine must be
// fast + harmless; it runs on every render, throttled to ~300ms).
const fs = require('fs');
const os = require('os');
const path = require('path');

function readStdin() { try { return fs.readFileSync(0, 'utf8'); } catch (_) { return ''; } }
function num(x) { return (typeof x === 'number' && isFinite(x)) ? x : null; }

(function () {
  let j = {};
  try { j = JSON.parse(readStdin() || '{}'); } catch (_) { j = {}; }

  const out = process.env.CLAUDE_USAGE_STATE || path.join(os.homedir(), '.claude', 'usage-state.json');
  const rl = j.rate_limits || null;
  const fh = (rl && rl.five_hour) || null;
  const sd = (rl && rl.seven_day) || null;
  const now = Math.floor(Date.now() / 1000);

  // 1) persist usage state for the Stop hook (best-effort; never throws)
  try {
    let state;
    if (fh && num(fh.used_percentage) != null) {
      state = { available: true, ts: now,
        five_hour: { used_percentage: num(fh.used_percentage), resets_at: num(fh.resets_at) } };
      if (sd && num(sd.used_percentage) != null)
        state.seven_day = { used_percentage: num(sd.used_percentage), resets_at: num(sd.resets_at) };
    } else {
      state = { available: false, ts: now };   // no rate_limits (API/enterprise plan, or before first response)
    }
    fs.writeFileSync(out, JSON.stringify(state));
  } catch (_) {}

  // 2) the visible status line (only the first stdout line is used by Claude Code)
  try {
    const model = (j.model && (j.model.display_name || j.model.id)) || 'claude';
    const parts = [model];
    const ctx = j.context_window && num(j.context_window.used_percentage);
    if (ctx != null) parts.push('ctx ' + Math.round(ctx) + '%');
    const cost = j.cost && num(j.cost.total_cost_usd);
    if (cost != null) parts.push('$' + cost.toFixed(2));
    if (fh && num(fh.used_percentage) != null) parts.push('5h ' + Math.round(fh.used_percentage) + '%');
    process.stdout.write(parts.join('  ·  '));
  } catch (_) { process.stdout.write('claude'); }
})();
