#!/usr/bin/env node
'use strict';
// Stop hook — wait out the 5-hour usage limit during an OPT-IN autonomous run, then resume.
// OFF by default: a session is affected ONLY if /longrun set a `.longrun` flag for it (session or project).
// When active AND this session has queued work AND the 5h window is at/over THRESHOLD, the hook reads the window's
// reset time from the usage data and SLEEPS once until then, then blocks (exit 2) so keep-going resumes the run.
// One timer, computed from resets_at — no polling, no arbitrary cap. Fails OPEN on any error. The 5h usage state
// is account-wide, written each render by session-usage-statusline.js. The Stop-hook timeout in settings.json must
// EXCEED MAX_SLEEP_MS (sleep ceiling 18300s = 5h5m) with margin, else Claude Code kills the wait before it can
// re-emit exit 2 to resume — it is set to 18900s (5h15m, ~10m headroom) so a near-edge reset can't lose the resume.
const fs = require('fs');
const path = require('path');
const os = require('os');
const S = require(path.join(__dirname, 'hook-state.js'));

const USAGE = process.env.CLAUDE_USAGE_STATE || path.join(os.homedir(), '.claude', 'usage-state.json');
const THRESHOLD = 97;                                  // % of the 5h window at which we wait
const MAX_SLEEP_MS = 5 * 60 * 60 * 1000 + 5 * 60 * 1000; // 5h5m ceiling: one window can't be further away than this
const STALE_MS = 15 * 60 * 1000;                        // usage data older than this is treated as no-data (not trusted)

function main() {
  const input = S.readStdin();
  const sid = S.sid(input);
  const allow = m => { if (m) process.stderr.write('usage-wait: ' + m + '\n'); process.exit(0); };
  if (!sid) return allow('');

  // OPT-IN: engage only if /longrun activated it (session flag .longrun.<sid>, or project flag .longrun)
  const active = S.firstExisting(S.sessionFlagCandidates(input, '.longrun'))
              || S.firstExisting(S.projectDocCandidates(input, '.longrun'));
  if (!active) return allow('');                                  // not activated -> never wait

  if (S.firstExisting(S.sessionFlagCandidates(input, '.stop-autorun'))) return allow('.stop-autorun present'); // manual abort

  // worth waiting only if there's an active run (queued work) to resume
  let actionable = 0;
  for (const base of ['WORK_QUEUE', 'CURRENT-TASK']) {
    const f = S.firstExisting(S.sessionDocCandidates(input, base));
    if (f) { try { actionable += (fs.readFileSync(f, 'utf8').match(/^\s*-\s*\[[ ~]\]/gm) || []).length; } catch (_) {} }
  }
  if (actionable === 0) return allow('');                         // nothing queued -> let it stop

  // usage data (account-wide, written each render by session-usage-statusline.js). No data -> can't know the reset
  // time -> don't wait. STALE data (statusLine not rendering, e.g. headless) is treated as no-data so we never act
  // on an old resets_at; the external watcher covers headless/dead-session runs.
  let st = null; try { st = JSON.parse(fs.readFileSync(USAGE, 'utf8')); } catch (_) {}
  if (!st || !st.available || !st.five_hour || st.five_hour.used_percentage == null)
    return allow('no usage data (statusLine writer not feeding usage-state.json?)');
  if (st.ts && (Date.now() - st.ts * 1000) > STALE_MS)
    return allow('usage data stale (>' + Math.round(STALE_MS / 60000) + 'm old); not trusting it — use the external watcher');
  const pct = Math.round(st.five_hour.used_percentage);
  if (pct < THRESHOLD) return allow('');                          // under the limit -> let keep-going decide

  // limited: sleep ONCE until the window resets (computed from resets_at), then resume.
  const secs = Math.max(0, (st.five_hour.resets_at || 0) - Math.floor(Date.now() / 1000));
  const sleepMs = Math.min(MAX_SLEEP_MS, secs * 1000);
  const h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60);
  process.stderr.write('USAGE LIMIT — 5h at ' + pct + '%. Waiting ~' + h + 'h' + m + 'm until reset, then resuming. ' +
    '(Ctrl-C to abort, or create .stop-autorun.' + sid + ' in the state dir.)\n');
  if (sleepMs > 0) { try { Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, sleepMs); } catch (_) {} }
  process.exit(2);                                                // window has reset -> keep going
}
try { main(); } catch (_) { process.exit(0); }
