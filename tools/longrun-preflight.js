#!/usr/bin/env node
'use strict';
// /longrun preflight — fail LOUDLY before a long unattended run if the in-session usage-limit safety net isn't live.
// Checks: (1) settings.json wires the statusLine writer; (2) the writer file exists; (3) usage-state.json exists,
// available:true, and fresh (<15m). Exits nonzero on any WARN so the /longrun skill (and Douglas) get a clear
// go/no-go instead of arming a sentinel that silently does nothing. Read-only; never mutates anything.
const fs = require('fs');
const os = require('os');
const path = require('path');
const home = os.homedir();
const STALE_MS = 15 * 60 * 1000;
let warn = 0;
const ok = m => console.log('  PASS  ' + m);
const no = m => { warn++; console.log('  WARN  ' + m); };

let settings = {};
try { settings = JSON.parse(fs.readFileSync(path.join(home, '.claude', 'settings.json'), 'utf8')); } catch (_) {}
const sl = (settings.statusLine && settings.statusLine.command) || '';
if (/session-usage-statusline\.js/.test(sl)) ok('statusLine writer wired in settings.json');
else no('settings.json has NO statusLine running session-usage-statusline.js — usage-state.json will never update');

const writer = path.join(home, '.claude', 'hooks', 'session-usage-statusline.js');
if (fs.existsSync(writer)) ok('writer present: ' + writer);
else no('writer MISSING: ' + writer);

const usagePath = process.env.CLAUDE_USAGE_STATE || path.join(home, '.claude', 'usage-state.json');
let st = null; try { st = JSON.parse(fs.readFileSync(usagePath, 'utf8')); } catch (_) {}
if (!st) no('usage-state.json missing/unreadable: ' + usagePath);
else if (!st.available) no('usage-state.json available:false — rate_limits not seen yet (Pro/Max only, after the 1st API turn). Run one turn, then re-check.');
else if (st.ts && (Date.now() - st.ts * 1000) > STALE_MS) no('usage-state.json is STALE (>' + Math.round(STALE_MS / 60000) + 'm) — statusLine may not be rendering (e.g. headless). In-session wait will no-op; rely on the external watcher.');
else ok('usage-state.json fresh + available (5h ' + (st.five_hour && Math.round(st.five_hour.used_percentage)) + '%)');

console.log(warn
  ? '\nPREFLIGHT: ' + warn + ' warning(s) — the in-session usage-limit wait is NOT guaranteed. Use the external watcher for a hands-off run.'
  : '\nPREFLIGHT: OK — in-session usage-limit wait is live.');
process.exit(warn ? 1 : 0);
