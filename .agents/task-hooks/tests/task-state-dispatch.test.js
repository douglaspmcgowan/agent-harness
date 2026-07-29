#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const HOOK = path.resolve(__dirname, '..', 'hooks', 'task-state-dispatch.js');

function makeRepo(task) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'task-hook-state-'));
  fs.mkdirSync(path.join(dir, '.git'));
  if (task !== null) fs.writeFileSync(path.join(dir, 'TASK.md'), task, 'utf8');
  fs.writeFileSync(path.join(dir, 'STATUS.md'), '# Status\n\nHarness staged.\n', 'utf8');
  fs.writeFileSync(path.join(dir, 'LOG.md'), '# Log\n\n2026-07-29 | staged\n', 'utf8');
  return dir;
}

function run(event, cwd, extra, env) {
  return spawnSync(process.execPath, [HOOK, event], {
    cwd,
    input: JSON.stringify(Object.assign({
      cwd,
      session_id: 'test-session',
      hook_event_name: event,
    }, extra || {})),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, env || {}),
  });
}

{
  const cwd = makeRepo('# Task\n\n## Goal\n\nConsolidate state.\n\n## Queue\n\n- [ ] Verify migration\n');
  const result = run('SessionStart', cwd);
  assert.strictEqual(result.status, 0);
  const output = JSON.parse(result.stdout);
  assert.match(output.hookSpecificOutput.additionalContext, /TASK\.md/);
  assert.match(output.hookSpecificOutput.additionalContext, /Verify migration/);
  assert.match(output.hookSpecificOutput.additionalContext, /STATUS\.md/);
}

{
  const cwd = makeRepo('# Task\n\n## Queue\n\n- [ ] Existing task\n');
  const rawSentinel = 'TELEMETRY_RAW_SENTINEL';
  const secretValue = 'ghp_exampleSecretValue123456789';
  const result = run('UserPromptSubmit', cwd, {
    prompt: `Please verify the hooks, then update the task file, then run tests. ${rawSentinel} api_key=${secretValue} Bearer bearer-example`,
  });
  assert.strictEqual(result.status, 0);
  const output = JSON.parse(result.stdout);
  assert.match(output.hookSpecificOutput.additionalContext, /reconcile/i);
  assert.match(output.hookSpecificOutput.additionalContext, /every direct and embedded question/i);
  assert.match(output.hookSpecificOutput.additionalContext, /Do not create an Answers section/i);
  assert.match(output.hookSpecificOutput.additionalContext, /nested checkbox/i);
  assert.match(output.hookSpecificOutput.additionalContext, /parallel/i);
  const logs = fs.readdirSync(path.join(cwd, 'taskstate'), { recursive: true })
    .filter(file => String(file).includes('PROMPT_TELEMETRY.test-session.md'));
  assert.strictEqual(logs.length, 1);
  const telemetry = fs.readFileSync(path.join(cwd, 'taskstate', logs[0]), 'utf8');
  assert.doesNotMatch(telemetry, new RegExp(rawSentinel));
  assert.doesNotMatch(telemetry, new RegExp(secretValue));
  assert.doesNotMatch(telemetry, /bearer-example/);
  assert.doesNotMatch(telemetry, /characters:|lines:|sha256:|list-signals:|sequence-signals:/);
  assert.match(telemetry, /skill-route: source-command-verification-before-completion/);
  assert.match(telemetry, /task-reconciliation-required: true/);
}

{
  const cwd = makeRepo('# Task\n\n## Queue\n');
  const secretOnly = 'single-token-secret-value';
  const result = run('UserPromptSubmit', cwd, { prompt: secretOnly });
  assert.strictEqual(result.status, 0);
  const logs = fs.readdirSync(path.join(cwd, 'taskstate'), { recursive: true })
    .filter(file => String(file).includes('PROMPT_TELEMETRY.test-session.md'));
  assert.strictEqual(logs.length, 1);
  const telemetry = fs.readFileSync(path.join(cwd, 'taskstate', logs[0]), 'utf8');
  assert.doesNotMatch(telemetry, new RegExp(secretOnly));
  assert.doesNotMatch(telemetry, /characters:|lines:|sha256:/);
}

{
  const cwd = makeRepo(null);
  const transcript = path.join(cwd, 'transcript.jsonl');
  fs.writeFileSync(transcript, [1, 2, 3].map(index => JSON.stringify({
    type: 'user',
    message: { content: `turn ${index}` },
  })).join('\n'), 'utf8');
  const result = run('PreCompact', cwd, { transcript_path: transcript, trigger: 'manual' });
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /TASK\.md/);
}

{
  const cwd = makeRepo(null);
  const result = run('PreCompact', cwd, { trigger: 'auto' });
  assert.strictEqual(result.status, 0);
}

{
  const cwd = makeRepo('# Task\n\n## Completed\n\n- [x] Done\n');
  const result = run('PreCompact', cwd);
  assert.strictEqual(result.status, 0);
}

{
  const large = `# Task\n\n## Queue\n\n- [ ] First item\n\n${'detail '.repeat(8000)}`;
  const cwd = makeRepo(large);
  fs.writeFileSync(path.join(cwd, 'AGENTS.md'), 'global rule\n'.repeat(5000), 'utf8');
  const result = run('SessionStart', cwd, null, { HARNESS_STARTUP_MAX_CHARS: '1200' });
  assert.strictEqual(result.status, 0);
  const output = JSON.parse(result.stdout);
  const context = output.hookSpecificOutput.additionalContext;
  assert.ok(context.length <= 1200, `startup context exceeded bound: ${context.length}`);
  assert.match(context, /First item/);
  assert.doesNotMatch(context, /global rule/);
  assert.match(context, /clipped/);
}

{
  const cwd = makeRepo('# Task\n\n## Queue\n\n- [ ] Verify config diagnostics\n');
  const config = path.join(cwd, 'broken-hooks.json');
  fs.writeFileSync(config, '{ invalid json', 'utf8');
  const result = run('SessionStart', cwd, null, {
    HARNESS_PRODUCT_CONFIGS: config,
    HARNESS_STATE_DIR: path.join(cwd, 'state'),
  });
  assert.strictEqual(result.status, 0);
  const output = JSON.parse(result.stdout);
  assert.match(output.hookSpecificOutput.additionalContext, /product hook config could not be parsed/);
}

console.log('task-state-dispatch tests passed');
