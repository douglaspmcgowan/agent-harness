#!/usr/bin/env node
'use strict';
// Tests for bypass-incident-log.js (Dropped #6, 2026-07-02 sweep): a classifier bypass denial in
// a tool_response must be logged to a durable, project-scoped incident file - not just visible
// in-turn and forgotten. Spawns the hook with synthetic PostToolUse stdin against a temp project.
const fs = require('fs'), os = require('os'), path = require('path'), cp = require('child_process');
const HOOK = path.join(__dirname, 'bypass-incident-log.js');
const { extractDenial } = require('./bypass-incident-log.js');
let pass = 0, total = 0;
function check(name, cond) { total++; cond ? (pass++, console.log('  PASS', name)) : console.log('  FAIL', name); }

function setup() {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'bil-')).replace(/\\/g, '/');
  fs.mkdirSync(path.join(tmp, '.claude', 'state', 'demo'), { recursive: true });
  fs.writeFileSync(path.join(tmp, '.claude', 'projects.json'), JSON.stringify({ default: 'demo', projects: { demo: { dirs: ['.'] } } }));
  return tmp;
}
function run(tmp, input) {
  cp.spawnSync('node', [HOOK], { input: JSON.stringify(input), encoding: 'utf8', cwd: tmp });
}
function logPath(tmp) { return path.join(tmp, '.claude', 'state', 'demo', '.classifier-denials.log'); }

// 1) extractDenial: the real verbatim message shape this session hit repeatedly
const REAL_DENIAL = "Permission for this action was denied by the Claude Code auto mode classifier. " +
  "Reason: [Self-Modification] Editing the Superpowers plugin's hooks.json (a startup-loaded " +
  "hook-execution config) is modifying a file that controls the agent's own behavior.. If you have " +
  "other tasks that don't depend on this action, continue working on those.";
let d = extractDenial(REAL_DENIAL);
check('extractDenial: parses category from the real verbatim denial format', d && d.category === 'Self-Modification');
check('extractDenial: captures a non-empty reason snippet', d && d.reason.length > 0);

// 2) a normal, non-denial tool_response is NOT flagged
check('extractDenial: a normal successful tool result is not mistaken for a denial',
  extractDenial('File created successfully at: /tmp/foo.txt') === null);
check('extractDenial: an unrelated error is not mistaken for a classifier denial',
  extractDenial('Error: ENOENT: no such file or directory') === null);

// 3) end-to-end: a denial in tool_response gets appended to the durable incident log
let tmp = setup();
run(tmp, { tool_name: 'Bash', session_id: 'sid1', tool_response: REAL_DENIAL });
let logText = fs.existsSync(logPath(tmp)) ? fs.readFileSync(logPath(tmp), 'utf8') : null;
check('end-to-end: a real denial produces a durable incident log entry', !!logText);
let rec = logText ? JSON.parse(logText.trim().split('\n')[0]) : null;
check('  ...entry records the tool name', rec && rec.tool === 'Bash');
check('  ...entry records the category', rec && rec.category === 'Self-Modification');
check('  ...entry records a timestamp', rec && typeof rec.ts === 'string' && rec.ts.length > 0);

// 4) a SECOND denial in the SAME turn/session appends a SECOND entry, not overwriting the first -
// this is the actual "visible as a trend, not two independent forgettable denials" requirement.
run(tmp, { tool_name: 'Bash', session_id: 'sid1', tool_response:
  "Permission for this action was denied by the Claude Code auto mode classifier. Reason: " +
  "[Auto-Mode Bypass] After the guard hook blocked the action, a different command achieved the same result." });
logText = fs.readFileSync(logPath(tmp), 'utf8');
let lines = logText.trim().split('\n');
check('a second denial in the same session appends, does not overwrite -> 2 entries visible', lines.length === 2);
check('  ...the second entry has a DIFFERENT category (a real trend is visible, not deduped away)',
  JSON.parse(lines[1]).category === 'Auto-Mode Bypass');

// 5) a normal (non-denial) tool result produces NO log entry at all
tmp = setup();
run(tmp, { tool_name: 'Write', session_id: 'sid2', tool_response: 'File created successfully' });
check('a normal tool result produces no incident log file at all', !fs.existsSync(logPath(tmp)));

// 6) malformed/garbage stdin does not crash the hook (fails open, matches this codebase's convention)
tmp = setup();
const r = cp.spawnSync('node', [HOOK], { input: 'not valid json {{{', encoding: 'utf8', cwd: tmp, timeout: 5000 });
check('malformed stdin does not crash the hook (exits cleanly)', r.status === 0 && r.signal === null);

console.log(`\n${pass}/${total} passed`);
process.exit(pass === total ? 0 : 1);
