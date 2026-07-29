#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const HOOK = path.resolve(__dirname, '..', 'hooks', 'continue-dispatch.js');

function makeRepo(task) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'task-hook-continue-'));
  fs.mkdirSync(path.join(dir, '.git'));
  if (task !== null) fs.writeFileSync(path.join(dir, 'TASK.md'), task, 'utf8');
  return dir;
}

function run(cwd, input) {
  return spawnSync(process.execPath, [HOOK, 'Stop'], {
    cwd,
    input: JSON.stringify(Object.assign({ cwd, session_id: 'test-session' }, input || {})),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, { HARNESS_DISABLE_LEGACY_FALLBACK: '1' }),
  });
}

function armLoop(cwd, sessionId, overrides) {
  const dir = path.join(cwd, '.claude');
  fs.mkdirSync(dir, { recursive: true });
  const fields = Object.assign({
    session_id: sessionId,
    iteration: 0,
    max_iterations: 3,
    completion_promise: 'verified completion',
  }, overrides || {});
  const body = Object.entries(fields).map(([key, value]) => `${key}: ${value}`).join('\n');
  const file = path.join(dir, 'ralph-loop.local.md');
  fs.writeFileSync(file, `---\n${body}\n---\nContinue the staged task.\n`, 'utf8');
  return file;
}

{
  const cwd = makeRepo('# Task\n\n## Queue\n\n- [ ] Ship the tested migration\n');
  const result = run(cwd);
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /1 actionable item/);
  assert.match(result.stderr, /Ship the tested migration/);
}

{
  const cwd = makeRepo('# Task\n\n## Blocked\n\n- [!] Waiting for a credential\n');
  const result = run(cwd);
  assert.strictEqual(result.status, 0);
  assert.match(result.stderr, /parked/);
}

{
  const cwd = makeRepo('# Task\n\n## Completed\n\n- [x] Finished\n\n## Migration archive\n\n> - [ ] Historical source line\n');
  const result = run(cwd);
  assert.strictEqual(result.status, 0);
  assert.match(result.stderr, /complete/);
}

{
  const cwd = makeRepo('# Task\n\n## Queue\n\n- [] malformed checkbox\n');
  const result = run(cwd);
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /unparsed/);
}

{
  const cwd = makeRepo('# Task\n\n## Queue\n\n- [ ] Parent\n  - [ ] Required child <!-- agent: codex/test-session -->\n');
  const result = run(cwd);
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /2 actionable item/);
}

{
  const cwd = makeRepo('# Task\n\n## Queue\n\n- [ ] Main-only item\n');
  const result = run(cwd, { transcript_path: path.join(cwd, 'subagents', 'worker.jsonl') });
  assert.strictEqual(result.status, 0);
  assert.match(result.stderr, /subagent/);
}

{
  const cwd = makeRepo('# Task\n\n## Queue\n\n- [ ] Loop-driven item\n');
  const loop = armLoop(cwd, 'test-session');
  const first = run(cwd);
  assert.strictEqual(first.status, 2);
  assert.match(first.stderr, /completion loop iteration 1\/3/);
  const nonce = /^nonce:\s*(\S+)/m.exec(fs.readFileSync(loop, 'utf8'))[1];
  const transcript = path.join(cwd, 'assistant.jsonl');
  fs.writeFileSync(transcript, JSON.stringify({
    message: { role: 'assistant', content: [{ type: 'text', text: `<promise>${nonce}</promise>` }] },
  }) + '\n', 'utf8');
  const completed = run(cwd, { transcript_path: transcript });
  assert.strictEqual(completed.status, 0);
  assert.match(completed.stderr, /completion token detected/);
  assert.strictEqual(fs.existsSync(loop), false);
}

{
  const cwd = makeRepo('# Task\n\n## Blocked\n\n- [!] Human decision\n');
  armLoop(cwd, 'test-session');
  const result = run(cwd);
  assert.strictEqual(result.status, 0);
  assert.match(result.stderr, /only parked items/);
}

{
  const cwd = makeRepo('# Task\n\n## Completed\n\n- [x] Done\n');
  const emptyRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'continue-missing-supplement-'));
  const result = spawnSync(process.execPath, [
    HOOK,
    'Stop',
    '--product=cursor',
    '--legacy=check-session-size.js',
  ], {
    cwd,
    input: JSON.stringify({ cwd, session_id: 'test-session' }),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, {
      HARNESS_LEGACY_HOOKS: emptyRoot,
      HARNESS_DISABLE_LEGACY_FALLBACK: '1',
    }),
  });
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /required supplemental module missing/);
}

{
  const cwd = makeRepo('# Task\n\n## Completed\n\n- [x] Done\n');
  const brokenRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'continue-broken-supplement-'));
  fs.writeFileSync(path.join(brokenRoot, 'check-session-size.js'), 'throw new Error("broken");\n', 'utf8');
  const result = spawnSync(process.execPath, [
    HOOK,
    'Stop',
    '--product=cursor',
    '--legacy=check-session-size.js',
  ], {
    cwd,
    input: JSON.stringify({ cwd, session_id: 'test-session' }),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, {
      HARNESS_LEGACY_HOOKS: brokenRoot,
      HARNESS_DISABLE_LEGACY_FALLBACK: '1',
    }),
  });
  assert.strictEqual(result.status, 2);
}

{
  const cwd = makeRepo('# Task\n\n## Queue\n\n- [ ] Resume after the usage window\n');
  fs.writeFileSync(path.join(cwd, '.longrun'), 'active\n', 'utf8');
  const usage = path.join(cwd, 'usage-state.json');
  fs.writeFileSync(usage, JSON.stringify({
    available: true,
    ts: Math.floor(Date.now() / 1000),
    five_hour: {
      used_percentage: 100,
      resets_at: Math.floor(Date.now() / 1000),
    },
  }), 'utf8');
  const result = spawnSync(process.execPath, [HOOK, 'Stop', '--product=codex'], {
    cwd,
    input: JSON.stringify({ cwd, session_id: 'test-session' }),
    encoding: 'utf8',
    timeout: 5000,
    env: Object.assign({}, process.env, {
      HARNESS_USAGE_STATE: usage,
      HARNESS_USAGE_MAX_SLEEP_MS: '0',
      HARNESS_DISABLE_LEGACY_FALLBACK: '1',
    }),
  });
  assert.strictEqual(result.status, 2);
  assert.match(result.stderr, /usage limit at 100%/);
}

console.log('continue-dispatch tests passed');
