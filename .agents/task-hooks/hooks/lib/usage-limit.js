'use strict';

// Adapted from the existing wait-on-usage-limit.js Stop hook. The in-process version reads TASK.md
// and keeps the existing opt-in, stale-data, reset-time, and bounded-wait behavior.

const fs = require('fs');
const os = require('os');
const path = require('path');

const DEFAULT_THRESHOLD = 97;
const DEFAULT_STALE_MS = 15 * 60 * 1000;
const DEFAULT_MAX_SLEEP_MS = 5 * 60 * 60 * 1000 + 5 * 60 * 1000;

function usageFile() {
  return process.env.HARNESS_USAGE_STATE ||
    process.env.CLAUDE_USAGE_STATE ||
    path.join(os.homedir(), '.claude', 'usage-state.json');
}

function numericEnv(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) && value >= 0 ? value : fallback;
}

function legacyActionable(input, state) {
  let count = 0;
  for (const base of ['WORK_QUEUE', 'CURRENT-TASK']) {
    const file = state.sessionDocCandidates(input, base)[0];
    if (!file) continue;
    try {
      count += (fs.readFileSync(file, 'utf8').match(/^\s*(?:[-*+]|\d+[.)])\s*\[[ ~]\]/gm) || []).length;
    } catch (_) {}
  }
  return count;
}

function evaluateUsageLimit(input, taskStatus, state) {
  const sid = state.sessionId(input);
  if (!sid) return null;
  const active = state.sessionFlagCandidates(input, '.longrun')[0] ||
    state.projectDocCandidates(input, '.longrun')[0];
  if (!active || state.sessionFlagCandidates(input, '.stop-autorun').length) return null;

  const actionable = taskStatus && (taskStatus.actionable.length || taskStatus.malformed.length)
    ? taskStatus.actionable.length + taskStatus.malformed.length
    : legacyActionable(input, state);
  if (!actionable) return null;

  let usage;
  try { usage = JSON.parse(fs.readFileSync(usageFile(), 'utf8')); } catch (_) { return null; }
  const window = usage && usage.five_hour;
  if (!usage || !usage.available || !window || window.used_percentage == null) return null;

  const staleMs = numericEnv('HARNESS_USAGE_STALE_MS', DEFAULT_STALE_MS);
  if (usage.ts && Date.now() - Number(usage.ts) * 1000 > staleMs) return null;

  const percentage = Math.round(Number(window.used_percentage));
  const threshold = numericEnv('HARNESS_USAGE_THRESHOLD', DEFAULT_THRESHOLD);
  if (!Number.isFinite(percentage) || percentage < threshold) return null;

  const seconds = Math.max(0, Number(window.resets_at || 0) - Math.floor(Date.now() / 1000));
  const maximum = numericEnv('HARNESS_USAGE_MAX_SLEEP_MS', DEFAULT_MAX_SLEEP_MS);
  const sleepMs = Math.min(maximum, seconds * 1000);
  if (sleepMs > 0) {
    try { Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, sleepMs); } catch (_) {}
  }
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return {
    code: 2,
    message: `usage limit at ${percentage}%; waited approximately ${hours}h${minutes}m for reset and will resume`,
  };
}

module.exports = {
  usageFile,
  legacyActionable,
  evaluateUsageLimit,
};
