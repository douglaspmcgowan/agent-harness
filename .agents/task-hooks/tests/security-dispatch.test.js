#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const HOOK = path.resolve(__dirname, '..', 'hooks', 'security-dispatch.js');
const LEGACY = 'C:\\Users\\dougl\\.claude\\hooks';

function run(tool, command, fastOnly = true) {
  const env = Object.assign({}, process.env, {
    HARNESS_LEGACY_HOOKS: LEGACY,
  });
  if (fastOnly) env.HARNESS_SECURITY_FAST_ONLY = '1';
  return spawnSync(process.execPath, [HOOK, 'PreToolUse'], {
    input: JSON.stringify({
      hook_event_name: 'PreToolUse',
      tool_name: tool,
      tool_input: { command },
    }),
    encoding: 'utf8',
    timeout: 10000,
    env,
  });
}

{
  const result = run('Bash', 'git reset --hard');
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /destructive command/);
}

{
  const result = run('Bash', 'cat .env.example');
  assert.strictEqual(result.status, 0);
}

{
  const result = run('Bash', 'echo $ANTHROPIC_API_KEY');
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /leak secrets/);
}

{
  const result = run('PowerShell', 'Get-ChildItem');
  assert.strictEqual(result.status, 0);
}

{
  const result = run('Bash', 'git reset --hard', false);
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /destructive command/);
}

{
  const result = run('Bash', 'git status --short', false);
  assert.strictEqual(result.status, 0);
}

{
  const result = spawnSync(process.execPath, [HOOK, 'PreToolUse'], {
    input: 'not json',
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, {
      HARNESS_LEGACY_HOOKS: LEGACY,
      HARNESS_SECURITY_FAST_ONLY: '1',
    }),
  });
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /malformed preflight input/);
}

for (const input of ['', 'null', '"text"', '[]']) {
  const result = spawnSync(process.execPath, [HOOK, 'PreToolUse'], {
    input,
    encoding: 'utf8',
    timeout: 5000,
  });
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /malformed preflight input/);
}

{
  const emptyRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'security-missing-'));
  const result = spawnSync(process.execPath, [HOOK, 'PreToolUse'], {
    input: JSON.stringify({
      tool_name: 'Read',
      tool_input: { file_path: 'C:\\Users\\dougl\\example\\26_Sensitive\\record.md' },
    }),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, { HARNESS_LEGACY_HOOKS: emptyRoot }),
  });
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /required module missing: block-ai-reference\.js/);
}

{
  const emptyRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'security-fast-missing-'));
  const result = spawnSync(process.execPath, [HOOK, 'PreToolUse'], {
    input: JSON.stringify({ tool_name: 'Shell', tool_input: { command: 'git status --short' } }),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, {
      HARNESS_LEGACY_HOOKS: emptyRoot,
      HARNESS_SECURITY_FAST_ONLY: '1',
    }),
  });
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /fast security composite is missing or invalid/);
}

{
  const corruptRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'security-corrupt-'));
  fs.writeFileSync(path.join(corruptRoot, 'block-ai-reference.js'), 'throw new Error("broken module");\n');
  const result = spawnSync(process.execPath, [HOOK, 'PreToolUse'], {
    input: JSON.stringify({ tool_name: 'Read', tool_input: { file_path: 'C:\\protected\\record.md' } }),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, { HARNESS_LEGACY_HOOKS: corruptRoot }),
  });
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /required module block-ai-reference\.js failed/);
}

{
  const timeoutRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'security-timeout-'));
  fs.writeFileSync(path.join(timeoutRoot, 'block-ai-reference.js'), 'setInterval(() => {}, 1000);\n');
  const result = spawnSync(process.execPath, [HOOK, 'PreToolUse'], {
    input: JSON.stringify({ tool_name: 'Read', tool_input: { file_path: 'C:\\protected\\record.md' } }),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, {
      HARNESS_LEGACY_HOOKS: timeoutRoot,
      HARNESS_SECURITY_TIMEOUT_MS: '50',
    }),
  });
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /could not run.*blocking the unchecked action/);
}

{
  const throwingRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'security-throwing-fast-'));
  fs.writeFileSync(path.join(throwingRoot, 'security-checks-fast.js'), `
    const noop = () => null;
    module.exports = {
      checkVisiblePowershell() { throw new Error('boom'); },
      checkSecretDump: noop,
      checkDangerousBash: noop,
      checkEnvMutation: noop,
      checkBulkDelete: noop,
      checkSecurityConfigWarn: noop
    };
  `);
  const result = spawnSync(process.execPath, [HOOK, 'PreToolUse'], {
    input: JSON.stringify({ tool_name: 'Shell', tool_input: { command: 'git status --short' } }),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, {
      HARNESS_LEGACY_HOOKS: throwingRoot,
      HARNESS_SECURITY_FAST_ONLY: '1',
    }),
  });
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /preflight dispatcher failed/);
}

{
  const emptyRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'security-advisory-'));
  const result = spawnSync(process.execPath, [HOOK, 'PostToolUse', '--product=codex'], {
    input: JSON.stringify({ tool_name: 'Shell', tool_input: { command: 'git status --short' } }),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, { HARNESS_LEGACY_HOOKS: emptyRoot }),
  });
  assert.strictEqual(result.status, 0);
  assert.match(result.stderr, /advisory module missing/);
}

{
  const result = spawnSync(process.execPath, [HOOK, 'PostToolUse'], {
    input: 'not json',
    encoding: 'utf8',
    timeout: 5000,
  });
  assert.strictEqual(result.status, 0);
  assert.match(result.stderr, /malformed postflight input/);
}

console.log('security-dispatch tests passed');
