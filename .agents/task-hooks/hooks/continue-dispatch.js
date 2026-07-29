#!/usr/bin/env node
'use strict';

// Sole Stop dispatcher. TASK.md is authoritative after migration; the existing keep-going hook
// remains a transition fallback when TASK.md has not been created yet.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const S = require(path.join(__dirname, 'lib', 'task-state.js'));
const { evaluateCompletionLoop } = require(path.join(__dirname, 'lib', 'completion-loop.js'));
const { evaluateUsageLimit } = require(path.join(__dirname, 'lib', 'usage-limit.js'));
const N = require(path.join(__dirname, 'lib', 'notifications.js'));

function first(paths) {
  return Array.isArray(paths) && paths.length ? paths[0] : null;
}

function productName() {
  const argument = process.argv.find(value => value.startsWith('--product='));
  return argument ? argument.slice('--product='.length).toLowerCase() : '';
}

function legacyRoots() {
  if (process.env.HARNESS_LEGACY_HOOKS) return [process.env.HARNESS_LEGACY_HOOKS];
  const canonical = path.join(os.homedir(), '.agents', 'hooks', 'legacy');
  const product = productName();
  return [
    product && path.join(canonical, product),
    canonical,
    product && path.join(os.homedir(), `.${product}`, 'hooks'),
    path.join(os.homedir(), '.claude', 'hooks'),
  ].filter(Boolean);
}

function findLegacy(name) {
  for (const root of legacyRoots()) {
    const candidate = path.join(root, name);
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

function supplementalLegacyModules() {
  return process.argv
    .slice(3)
    .filter(value => value.startsWith('--legacy='))
    .map(value => path.basename(value.slice('--legacy='.length)))
    .filter(value => /^[A-Za-z0-9_.-]+\.js$/.test(value) && value !== 'keep-going.js');
}

function runSupplementalLegacy(input) {
  for (const name of supplementalLegacyModules()) {
    const script = findLegacy(name);
    if (!script) {
      process.stderr.write(`continue-dispatch: required supplemental module missing: ${name}\n`);
      process.exit(2);
    }
    const result = spawnSync(process.execPath, [script], {
      input: JSON.stringify(input),
      encoding: 'utf8',
      timeout: 18900000,
    });
    if (result.error || !Number.isInteger(result.status)) {
      process.stderr.write(`continue-dispatch: supplemental module failed to run: ${name}\n`);
      process.exit(2);
    }
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.status !== 0) process.exit(2);
  }
}

function legacyFallback(input) {
  if (process.env.HARNESS_DISABLE_LEGACY_FALLBACK === '1') return false;
  const script = findLegacy('keep-going.js');
  if (!script) return false;
  const result = spawnSync(process.execPath, [script], {
    input: JSON.stringify(input),
    encoding: 'utf8',
    timeout: 120000,
  });
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.stdout) process.stdout.write(result.stdout);
  process.exit(Number.isInteger(result.status) ? result.status : 0);
}

function allow(message) {
  if (activeInput) N.handleAllowedStop(activeInput);
  if (message) process.stderr.write('continue-dispatch: ' + message + '\n');
  process.exit(0);
}

let activeInput = null;

function main() {
  const input = S.readStdin();
  activeInput = input;
  const cwd = S.cwdOf(input);
  const sid = S.sessionId(input);
  const transcript = S.norm(input.transcript_path || '');

  if (/[\/](subagents|workflows)[\/]/i.test(transcript) || /[\/](subagents|workflows)[\/]/i.test(cwd)) {
    return allow('subagent/workflow stop; passthrough');
  }
  if (!sid) return allow('no session id; allowing an unscoped stop');

  for (const flag of ['.need-user', '.stop-autorun', '.no-keepgoing']) {
    if (first(S.sessionFlagCandidates(input, flag))) return allow(`${flag} present`);
  }

  const earlyTaskFile = first(S.sessionDocCandidates(input, 'TASK'));
  let earlyStatus = S.parseTaskDocument('');
  if (earlyTaskFile) {
    try { earlyStatus = S.parseTaskDocument(fs.readFileSync(earlyTaskFile, 'utf8')); } catch (_) {}
  }
  if (['claude', 'codex'].includes(productName())) {
    const usage = evaluateUsageLimit(input, earlyStatus, S);
    if (usage) {
      if (usage.message) process.stderr.write('continue-dispatch: ' + usage.message + '\n');
      process.exit(usage.code);
    }
  }
  const completion = evaluateCompletionLoop(input, earlyStatus);
  if (completion) {
    if (completion.message) process.stderr.write('continue-dispatch: ' + completion.message + '\n');
    process.exit(completion.code);
  }

  if (input.stop_hook_active) return allow('stop_hook_active; allowing to prevent an unbounded loop');

  runSupplementalLegacy(input);

  const taskFile = first(S.sessionDocCandidates(input, 'TASK'));
  if (!taskFile) return legacyFallback(input) || allow('TASK.md absent and no legacy fallback handled the stop');

  let content = '';
  try { content = fs.readFileSync(taskFile, 'utf8'); } catch (_) {
    return allow('TASK.md could not be read; failing open');
  }
  const state = S.parseTaskDocument(content);
  const pending = state.actionable.concat(
    state.malformed.map(item => `[unparsed: fix to "- [ ] ..."] ${item}`)
  );

  if (!pending.length) {
    if (state.parked.length) return allow(`${state.parked.length} parked item(s); nothing actionable`);
    return allow('TASK.md complete');
  }

  const project = S.resolveProject(input);
  const progressFile = S.sessionFlagWrite(input, '.continue-progress');
  const signature = pending.join('\n');
  let previous = { signature: '', count: 0 };
  try { previous = JSON.parse(fs.readFileSync(progressFile, 'utf8')); } catch (_) {}
  const progress = {
    signature,
    count: previous.signature === signature ? Number(previous.count || 0) + 1 : 1,
  };

  if (!S.ensureDir(path.dirname(progressFile))) return allow('progress state cannot be persisted; failing open');
  try { fs.writeFileSync(progressFile, JSON.stringify(progress), 'utf8'); } catch (_) {
    return allow('progress state cannot be persisted; failing open');
  }
  if (progress.count > 3) {
    try { fs.unlinkSync(progressFile); } catch (_) {}
    return allow('no progress across three continuation checks; park the item or surface the blocker');
  }

  process.stderr.write(
    `KEEP GOING — ${pending.length} actionable item(s) remain in TASK.md for project ${project.id}. ` +
    `Next: "${pending[0]}". Work top-down, update evidence, and keep the next verifier current.\n`
  );
  process.exit(2);
}

try { main(); } catch (_) { process.exit(0); }

module.exports = {
  productName,
  legacyRoots,
  findLegacy,
  supplementalLegacyModules,
  runSupplementalLegacy,
  legacyFallback,
};
