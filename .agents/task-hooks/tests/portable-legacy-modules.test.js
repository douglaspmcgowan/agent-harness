#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const HOOKS = path.join(ROOT, 'hooks');
const LEGACY = path.join(HOOKS, 'legacy');

delete process.env.HARNESS_LEGACY_HOOKS;
assert.strictEqual(
  process.env.HARNESS_LEGACY_HOOKS,
  undefined,
  'The resolver test must exercise canonical product/shared search order'
);

const securityCommon = [
  'security-checks-fast.js',
  'block-visible-powershell.js',
  'block-secret-dump.js',
  'check-secret-exposure.js',
  'block-dangerous-bash.js',
  'guard-env-mutation.js',
  'guard-bulk-delete.js',
  'protect-security-config.js',
  'protect-authored-docs.js',
  'protect-ai-reference.js',
  'protect-firmware.js',
  'scan-write-for-secrets.js',
  'concurrent-edit-lock.js',
  'block-ai-reference.js',
  'block-sensitive-file-read.js',
  'warn-large-read.js',
  'block-obsidian-delete.js',
  'scan-output-for-secrets.js',
  'audit-bash-log.js',
  'bypass-incident-log.js',
  'format-on-edit.js',
  'auto-schedule-codex-poll.js',
  'impeccable-run-log.js',
];

const requirements = {
  claude: securityCommon.concat([
    'dep-audit-gate.js',
    'keep-going.js',
    'test-green-gate.js',
  ]),
  codex: securityCommon.concat([
    'keep-going.js',
  ]),
  cursor: securityCommon.concat([
    'scrub-secrets-from-output.js',
    'keep-going.js',
    'check-session-size.js',
  ]),
};

const expectedProductOverrides = {
  claude: new Set([
    'dep-audit-gate.js',
    'test-green-gate.js',
  ]),
  codex: new Set(),
  cursor: new Set([
    'check-secret-exposure.js',
    'block-dangerous-bash.js',
    'protect-firmware.js',
    'block-obsidian-delete.js',
    'scrub-secrets-from-output.js',
    'format-on-edit.js',
    'auto-schedule-codex-poll.js',
    'check-session-size.js',
  ]),
};

function resolveLegacy(product, name) {
  for (const candidate of [
    path.join(LEGACY, product, name),
    path.join(LEGACY, name),
  ]) {
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

function moduleNames(source) {
  return new Set(
    Array.from(source.matchAll(/['"`]([A-Za-z0-9_.-]+\.js)['"`]/g), match => match[1])
  );
}

const dispatcherNames = new Set([
  ...moduleNames(fs.readFileSync(path.join(HOOKS, 'security-dispatch.js'), 'utf8')),
  ...moduleNames(fs.readFileSync(path.join(HOOKS, 'continue-dispatch.js'), 'utf8')),
]);
for (const inProcessModule of [
  'task-state.js',
  'completion-loop.js',
  'usage-limit.js',
  'notifications.js',
]) {
  dispatcherNames.delete(inProcessModule);
}

for (const configName of [
  'claude-hooks.example.json',
  'codex-hooks.example.json',
  'cursor-hooks.example.json',
]) {
  const config = fs.readFileSync(path.join(ROOT, 'config', configName), 'utf8');
  for (const match of config.matchAll(/--legacy=([A-Za-z0-9_.-]+\.js)/g)) {
    dispatcherNames.add(match[1]);
  }
}

const applicableNames = new Set(Object.values(requirements).flat());
for (const name of dispatcherNames) {
  assert(
    applicableNames.has(name),
    `Dispatcher/config module is absent from the deployment map: ${name}`
  );
}

for (const [product, names] of Object.entries(requirements)) {
  for (const name of names) {
    const resolved = resolveLegacy(product, name);
    assert(resolved, `${product} cannot resolve required module ${name}`);
    const expectedRoot = expectedProductOverrides[product].has(name)
      ? path.join(LEGACY, product)
      : LEGACY;
    assert.strictEqual(
      path.dirname(resolved),
      expectedRoot,
      `${product}/${name} resolved from the wrong precedence layer`
    );
  }
}

const localDependencies = {
  'security-checks-fast.js': ['hook-state.js', 'allow-tags.js'],
  'block-visible-powershell.js': ['hook-state.js'],
  'block-secret-dump.js': ['allow-tags.js'],
  'check-secret-exposure.js': ['allow-tags.js'],
  'scan-write-for-secrets.js': ['allow-tags.js'],
  'concurrent-edit-lock.js': ['hook-state.js'],
  'warn-large-read.js': ['hook-state.js'],
  'bypass-incident-log.js': ['hook-state.js'],
  'impeccable-run-log.js': ['hook-state.js'],
  'keep-going.js': ['hook-state.js'],
};

for (const [owner, dependencies] of Object.entries(localDependencies)) {
  const ownerPath = path.join(LEGACY, owner);
  assert(fs.existsSync(ownerPath), `Shared dependency owner is missing: ${owner}`);
  for (const dependency of dependencies) {
    assert(
      fs.existsSync(path.join(path.dirname(ownerPath), dependency)),
      `${owner} cannot resolve local dependency ${dependency}`
    );
  }
}

for (const owner of ['dep-audit-gate.js', 'test-green-gate.js']) {
  const ownerPath = path.join(LEGACY, 'claude', owner);
  assert(fs.existsSync(ownerPath), `Claude module is missing: ${owner}`);
  assert(
    fs.existsSync(path.join(path.dirname(ownerPath), 'gates-config.js')),
    `${owner} cannot resolve local dependency gates-config.js`
  );
}

const packagedFiles = [];
function collectJs(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) collectJs(absolute);
    else if (entry.isFile() && entry.name.endsWith('.js')) packagedFiles.push(absolute);
  }
}
collectJs(LEGACY);

for (const file of packagedFiles) {
  const result = spawnSync(process.execPath, ['--check', file], {
    encoding: 'utf8',
    timeout: 5000,
  });
  assert.strictEqual(
    result.status,
    0,
    `Node syntax check failed for ${path.relative(ROOT, file)}:\n${result.stderr || result.stdout}`
  );
}

console.log(
  `portable legacy modules: ${Object.keys(requirements).length} products, ` +
  `${applicableNames.size} applicable modules, ${packagedFiles.length} JavaScript files`
);
