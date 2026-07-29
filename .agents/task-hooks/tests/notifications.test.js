#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const HOOK = path.resolve(__dirname, '..', 'hooks', 'task-state-dispatch.js');
const state = fs.mkdtempSync(path.join(os.tmpdir(), 'task-hook-notify-'));
const cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'task-hook-notify-repo-'));
fs.mkdirSync(path.join(cwd, '.git'));
fs.writeFileSync(path.join(cwd, 'TASK.md'), '# Task\n\n## Completed\n\n- [x] Done\n', 'utf8');

function run(event, extra) {
  return spawnSync(process.execPath, [HOOK, event, '--product=cursor'], {
    cwd,
    input: JSON.stringify(Object.assign({
      cwd,
      session_id: 'notify-session',
      hook_event_name: event,
    }, extra || {})),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, {
      HARNESS_STATE_DIR: state,
      HARNESS_NOTIFICATION_DRY_RUN: '1',
      HARNESS_INPUT_TOAST_DELAY_MS: '50',
    }),
  });
}

{
  const result = run('BeforeShellExecution', { command: 'git status --short' });
  assert.strictEqual(result.status, 0);
  const pending = JSON.parse(fs.readFileSync(path.join(state, 'pending-input-toast.json'), 'utf8'));
  assert.strictEqual(pending.reason, 'shell-approval');
  assert.strictEqual(pending.cancelled, false);
}

{
  const result = run('BeforeSubmitPrompt', { prompt: 'Continue.' });
  assert.strictEqual(result.status, 0);
  const pending = JSON.parse(fs.readFileSync(path.join(state, 'pending-input-toast.json'), 'utf8'));
  assert.strictEqual(pending.cancelled, true);
}

{
  const result = run('AfterAgentResponse');
  assert.strictEqual(result.status, 0);
  const pending = JSON.parse(fs.readFileSync(path.join(state, 'pending-input-toast.json'), 'utf8'));
  assert.strictEqual(pending.reason, 'after-agent-response');
}

console.log('notification lifecycle tests passed');
