#!/usr/bin/env node
'use strict';
// PreCompact hook -- added 2026-07-03 after the detective sweep found repeated cases of a goal/task
// getting re-derived from scratch (up to ~20 times in one session) because it lived only in rolling
// compact summaries, never a durable file. This is the deterministic check version: before a MANUAL
// /compact wipes context, make sure THIS session's own CURRENT-TASK/WORK_QUEUE file actually exists.
//
// manual /compact: BLOCK (exit 2) if no durable task file exists for this session AND there's been
//   real multi-turn activity worth saving (>=3 human turns) -- cheap to seed one, so don't let a
//   manual compact erase context nobody wrote down.
// auto compact: NEVER block. Auto-compact fires because context is genuinely full; blocking it could
//   strand the session with nowhere to put more tokens. Log-only -- same fail-open philosophy as
//   every other hook here (a guard must never trap a session, see keep-going.js R1).
// Any self-error fails open (allow) -- this hook must never be the reason a compact can't happen.
const fs = require('fs');
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));

function countHumanTurns(tpath) {
  let data; try { data = fs.readFileSync(tpath, 'utf8'); } catch (_) { return 0; }
  let n = 0;
  for (const ln of data.split(/\r?\n/)) {
    if (!ln) continue;
    let o; try { o = JSON.parse(ln); } catch (_) { continue; }
    if (o && o.type === 'user' && o.message && typeof o.message.content === 'string') n++;
  }
  return n;
}

// Second-manual-/compact-in-a-row override: the first blocked manual /compact drops a timestamped
// marker; if the user re-issues /compact within OVERRIDE_WINDOW_MS (a deliberate "I mean it, compact
// anyway"), the marker is seen and the block is overridden. Any legitimate allow path clears the
// marker so the "in a row" counter resets and a much-later compact re-blocks fresh.
const BLOCK_MARKER = '.precompact-manual-block';
const OVERRIDE_WINDOW_MS = 15 * 60 * 1000;

function markerPath(input, sidv) { try { return path.join(S.stateDir(input), BLOCK_MARKER + '.' + sidv); } catch (_) { return null; } }
function clearMarker(mp) { if (mp) { try { fs.unlinkSync(mp); } catch (_) {} } }
function markerRecent(mp) {
  if (!mp) return false;
  try { return (Date.now() - fs.statSync(mp).mtimeMs) <= OVERRIDE_WINDOW_MS; } catch (_) { return false; }
}
function logLine(input, msg) {
  try {
    const dir = S.stateDir(input); S.ensureDir(dir);
    fs.appendFileSync(dir + '/.precompact.log', new Date().toISOString() + '  ' + msg + '\n');
  } catch (_) {}
}

function main() {
  const input = S.readStdin();
  const sidv = S.sid(input);
  if (!sidv) return; // no session id -> nothing to scope to, allow
  const mp = markerPath(input, sidv);

  const hasTaskFile = !!S.firstExisting(S.sessionDocCandidates(input, 'WORK_QUEUE')) ||
                       !!S.firstExisting(S.sessionDocCandidates(input, 'CURRENT-TASK'));
  if (hasTaskFile) { clearMarker(mp); return; } // already have a durable file -- allow silently

  // Claude Code passes the PreCompact trigger as "manual" or "auto" -- accept either the documented
  // `trigger` field or a `matcher` fallback in case the exact field name drifts across versions.
  const trigger = String((input && (input.trigger || input.matcher)) || '').toLowerCase();
  const turns = countHumanTurns(S.norm((input && input.transcript_path) || ''));

  if (trigger === 'auto') {
    logLine(input, 'AUTO-COMPACT with no durable task file (session ' + sidv + ', ' + turns +
      ' human turns) -- not blocking, context is genuinely full');
    clearMarker(mp);
    return;
  }

  if (turns >= 3) {
    // Second consecutive manual /compact overrides the block.
    if (markerRecent(mp)) {
      clearMarker(mp);
      logLine(input, 'MANUAL-COMPACT override: second /compact in a row for session ' + sidv +
        ' with still no durable task file -- allowing (user re-issued /compact to override)');
      return;
    }
    try { if (mp) { S.ensureDir(S.stateDir(input)); fs.writeFileSync(mp, new Date().toISOString() + '\n'); } } catch (_) {}
    process.stderr.write(
      'PreCompact: no CURRENT-TASK.md / WORK_QUEUE.' + sidv + '.md exists for this session yet, and ' +
      'this manual /compact is about to summarize away ' + turns + ' human turns of context. ' +
      'Write CURRENT-TASK.md (goal, done steps, remaining steps, exact next command) or seed ' +
      'WORK_QUEUE.' + sidv + '.md first, THEN /compact again. (Run /compact once more to override ' +
      'this and compact anyway.)\n');
    process.exit(2);
  }
  // turns < 3: nothing worth guarding -- allow and reset the override counter.
  clearMarker(mp);
}

try { main(); } catch (_) { process.exit(0); }
