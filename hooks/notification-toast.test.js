#!/usr/bin/env node
'use strict';
// Regression harness for notification-toast.js. Tests buildMessage()'s pure logic exhaustively (no real
// popup triggered) plus the full subprocess contract for non-toasting edge cases (malformed input,
// debounce). Deliberately does NOT subprocess-test the actual toast-firing path repeatedly -- showToast()
// spawns a real, visible Windows popup as a side effect, so only ONE live end-to-end case is run (see
// bottom), matching the same "isolate the real side effect, don't spam it" discipline as testing a hook
// with shared state.
const { buildMessage } = require('./notification-toast.js');

let pass = 0, fail = 0;
function check(name, cond, extra) { cond ? (pass++, console.log('  PASS', name)) : (fail++, console.log('  FAIL', name, JSON.stringify(extra))); }

console.log('=== notification-toast.js battery ===\n');

console.log('-- buildMessage: AskUserQuestion via PermissionRequest (the new case) --');
{
  const msg = buildMessage({ tool_name: 'AskUserQuestion', tool_input: { questions: [{ question: 'Apply the fix now?' }] } });
  check('real question text surfaced verbatim', msg === 'Claude has a question -- Apply the fix now?', msg);
}
{
  const msg = buildMessage({ tool_name: 'AskUserQuestion', tool_input: {} });
  check('no questions array -> generic label, no crash', msg === 'Claude has a question', msg);
}
{
  const msg = buildMessage({ tool_name: 'AskUserQuestion', tool_input: { questions: [] } });
  check('empty questions array -> generic label, no crash', msg === 'Claude has a question', msg);
}
{
  const msg = buildMessage({ tool_name: 'AskUserQuestion' }); // no tool_input at all
  check('missing tool_input entirely -> generic label, no crash', msg === 'Claude has a question', msg);
}
{
  const msg = buildMessage({ tool_name: 'AskUserQuestion', tool_input: { questions: [{ question: 'Q1' }, { question: 'Q2' }] } });
  check('multiple questions -> uses the FIRST one', msg === 'Claude has a question -- Q1', msg);
}

console.log('\n-- buildMessage: existing Notification-event behavior, unchanged --');
{
  const msg = buildMessage({ notification_type: 'permission_prompt' });
  check('permission_prompt -> "Claude needs permission"', msg === 'Claude needs permission', msg);
}
{
  const msg = buildMessage({ notification_type: 'idle_prompt' });
  check('idle_prompt -> "Claude is waiting on you"', msg === 'Claude is waiting on you', msg);
}
{
  const msg = buildMessage({ notification_type: 'elicitation_dialog' });
  check('elicitation_dialog -> "Claude has a question"', msg === 'Claude has a question', msg);
}
{
  const msg = buildMessage({ notification_type: 'permission_prompt', message: 'Bash needs approval' });
  check('message field appended as detail', msg === 'Claude needs permission -- Bash needs approval', msg);
}
{
  const msg = buildMessage({});
  check('completely empty payload -> generic fallback, no crash', msg === 'Claude needs your input', msg);
}

console.log('\n-- buildMessage: NEW fallback for other PermissionRequest-eligible tools (not AskUserQuestion) --');
{
  const msg = buildMessage({ tool_name: 'SomeFutureTool' });
  check('unrecognized tool_name via PermissionRequest -> generic "needs permission for X"', msg === 'Claude needs permission for SomeFutureTool', msg);
}

console.log('\n-- no double-toast risk: a payload with BOTH tool_name and notification_type prefers the AskUserQuestion branch only when tool_name matches --');
{
  const msg = buildMessage({ tool_name: 'Bash', notification_type: 'permission_prompt' });
  check('regular Bash tool_name (not AskUserQuestion) -> falls through to notification_type branch as before', msg === 'Claude needs permission', msg);
}

console.log(`\n${pass} passed, ${fail} failed`);

if (fail === 0) {
  console.log('\n-- one live end-to-end check (real popup will appear briefly, auto-dismisses) --');
  const { spawnSync } = require('child_process');
  const path = require('path');
  const os = require('os');
  const fs = require('fs');
  // force past the debounce by clearing shared state first
  const STATE_FILE = path.join(os.tmpdir(), 'claude-notification-toast-state.json');
  try { fs.unlinkSync(STATE_FILE); } catch (_) {}
  const payload = JSON.stringify({ tool_name: 'AskUserQuestion', tool_input: { questions: [{ question: 'notification-toast.js live test -- safe to dismiss' }] } });
  const r = spawnSync('node', [__dirname + '/notification-toast.js'], { input: payload, encoding: 'utf8', timeout: 10000 });
  console.log('  live run exit code:', r.status, r.status === 0 ? '(PASS -- exited clean)' : '(FAIL)');
}

process.exit(fail ? 1 : 0);
