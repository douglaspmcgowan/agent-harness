#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const CONFIG = path.join(ROOT, 'config');
const allowed = new Set([
  'security-dispatch.js',
  'task-state-dispatch.js',
  'continue-dispatch.js',
]);
const taskState = require(path.join(ROOT, 'hooks', 'lib', 'task-state.js'));

function commands(config) {
  const found = [];
  for (const groups of Object.values(config.hooks || {})) {
    for (const group of Array.isArray(groups) ? groups : []) {
      if (group.command) found.push(String(group.command));
      for (const hook of Array.isArray(group.hooks) ? group.hooks : []) {
        if (hook.command) found.push(String(hook.command));
      }
    }
  }
  return found;
}

for (const name of ['claude', 'codex', 'cursor']) {
  const file = path.join(CONFIG, `${name}-hooks.example.json`);
  const config = JSON.parse(fs.readFileSync(file, 'utf8'));
  const all = commands(config);
  assert.ok(all.length > 0, `${name} config has no hook commands`);
  for (const command of all) {
    const matches = [...command.matchAll(/([A-Za-z0-9_.-]+-dispatch\.js)\b/g)].map(match => match[1]);
    assert.ok(matches.length > 0, `${name} command bypasses the three dispatchers: ${command}`);
    for (const dispatcher of matches) {
      assert.ok(allowed.has(dispatcher), `${name} wires unexpected dispatcher ${dispatcher}`);
    }
    assert.match(command, new RegExp(`--product=${name}\\b`), `${name} command lacks product routing`);
  }
}

const claude = JSON.parse(fs.readFileSync(path.join(CONFIG, 'claude-hooks.example.json'), 'utf8'));
assert.ok(claude.hooks.Notification, 'Claude notification parity is not wired');

const cursor = JSON.parse(fs.readFileSync(path.join(CONFIG, 'cursor-hooks.example.json'), 'utf8'));
for (const event of ['beforeShellExecution', 'beforeMCPExecution', 'afterAgentResponse']) {
  assert.ok(cursor.hooks[event], `Cursor ${event} toast lifecycle is not wired`);
}
const cursorStop = commands({ hooks: { stop: cursor.hooks.stop } }).join('\n');
assert.doesNotMatch(cursorStop, /stop-toast-gate/, 'retired Cursor toast gate remains wired');
assert.match(cursorStop, /check-session-size/, 'Cursor session-size advisory was lost');

const template = fs.readFileSync(path.join(ROOT, 'templates', 'TASK.md'), 'utf8');
const templateState = taskState.parseTaskDocument(template);
assert.deepStrictEqual(templateState.actionable, [], 'fresh TASK.md template contains actionable placeholders');
assert.deepStrictEqual(templateState.malformed, [], 'fresh TASK.md template contains malformed placeholders');
assert.doesNotMatch(template, /^\s*(?:[-*+]|\d+[.)])\s*\[[ ~]\]/m, 'fresh TASK.md template arms continuation');

console.log('hook configuration contract tests passed');
