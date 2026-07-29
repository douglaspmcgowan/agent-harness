#!/usr/bin/env node
'use strict';

// One tool-event dispatcher. It reuses the existing in-process security composite for the hot
// Bash/PowerShell path and invokes remaining legacy checks in their current order during migration.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

function readInput() {
  let raw = '';
  try { raw = fs.readFileSync(0, 'utf8'); } catch (_) {}
  if (!raw.trim()) return { value: {}, malformed: true };
  try {
    const value = JSON.parse(raw);
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      return { value: {}, malformed: true };
    }
    return { value, malformed: false };
  } catch (_) {
    return { value: {}, malformed: true };
  }
}

function eventName(input) {
  return String(process.argv[2] || input.hook_event_name || input.hookEventName || '').toLowerCase();
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

function securityTimeout() {
  const requested = Number(process.env.HARNESS_SECURITY_TIMEOUT_MS || 120000);
  return Number.isFinite(requested) && requested > 0 ? Math.min(requested, 120000) : 120000;
}

function runLegacy(name, input, critical) {
  const script = findLegacy(name);
  if (!script) {
    return {
      status: critical ? 2 : 0,
      stdout: '',
      stderr: `security-dispatch: ${critical ? 'required' : 'advisory'} module missing: ${name}\n`,
    };
  }
  const result = spawnSync(process.execPath, [script], {
    input: JSON.stringify(input),
    encoding: 'utf8',
    timeout: securityTimeout(),
  });
  if (result.error) {
    return {
      status: critical ? 2 : 0,
      stdout: '',
      stderr: `security-dispatch: ${name} could not run; ${critical ? 'blocking the unchecked action' : 'advisory check skipped'}.\n`,
    };
  }
  if (!Number.isInteger(result.status)) {
    return {
      status: critical ? 2 : 0,
      stdout: '',
      stderr: `security-dispatch: ${name} ended without a result; ${critical ? 'blocking the unchecked action' : 'advisory check skipped'}.\n`,
    };
  }
  if (!critical && result.status !== 0) {
    return {
      status: 0,
      stdout: '',
      stderr: `security-dispatch: advisory module ${name} failed with status ${result.status}; action already completed.\n`,
    };
  }
  if (critical && result.status !== 0 && result.status !== 2) {
    return {
      status: 2,
      stdout: '',
      stderr: `${result.stderr || ''}security-dispatch: required module ${name} failed with status ${result.status}; blocking the unchecked action.\n`,
    };
  }
  return {
    status: result.status,
    stdout: result.stdout || '',
    stderr: result.stderr || '',
  };
}

function finish(result) {
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.status !== 0) process.exit(result.status);
  return Boolean(result.stdout);
}

function runLegacySequence(names, input, stopOnDecision, critical = true) {
  for (const name of names) {
    const result = runLegacy(name, input, critical);
    const decision = finish(result);
    if (decision && stopOnDecision) return true;
  }
  return false;
}

function loadFast() {
  const file = findLegacy('security-checks-fast.js');
  if (!file) return null;
  try { return require(file); } catch (_) { return null; }
}

function validateFast(fast) {
  const required = [
    'checkVisiblePowershell',
    'checkSecretDump',
    'checkDangerousBash',
    'checkEnvMutation',
    'checkBulkDelete',
    'checkSecurityConfigWarn',
  ];
  return fast && required.every(name => typeof fast[name] === 'function');
}

function block(message) {
  if (!message) return false;
  process.stderr.write(message.endsWith('\n') ? message : message + '\n');
  process.exit(2);
}

function runShellPreTool(input) {
  const command = String((input.tool_input && input.tool_input.command) || input.command || '');
  const fast = loadFast();
  const fastOnly = process.env.HARNESS_SECURITY_FAST_ONLY === '1';

  if (validateFast(fast)) {
    block(fast.checkVisiblePowershell(input, command));
    block(fast.checkSecretDump(input, command));
  } else if (fastOnly) {
    process.stderr.write('security-dispatch: required fast security composite is missing or invalid; blocking the unchecked action.\n');
    process.exit(2);
  } else {
    if (runLegacySequence(['block-visible-powershell.js', 'block-secret-dump.js'], input, true, true)) return;
  }

  if (runLegacySequence(['check-secret-exposure.js'], input, true, true)) return;

  if (validateFast(fast)) {
    block(fast.checkDangerousBash(command));
    block(fast.checkEnvMutation(command));
    block(fast.checkBulkDelete(command));
    const warning = fast.checkSecurityConfigWarn(command);
    if (warning) process.stderr.write(warning);
  } else if (!fastOnly) {
    if (runLegacySequence([
      'block-dangerous-bash.js',
      'guard-env-mutation.js',
      'guard-bulk-delete.js',
    ], input, true, true)) return;
    runLegacySequence(['protect-security-config.js'], input, false, false);
  }

  const required = [
    'protect-authored-docs.js',
    'protect-ai-reference.js',
  ];
  if (productName() === 'claude' || !productName()) required.push('dep-audit-gate.js');
  runLegacySequence(required, input, true, true);
}

function runPreTool(input) {
  const tool = String(input.tool_name || input.tool || '');
  if (/^(Bash|PowerShell|Shell)$/i.test(tool)) return runShellPreTool(input);
  if (/^(Write|Edit|MultiEdit|apply_patch)$/i.test(tool)) {
    return runLegacySequence([
      'protect-firmware.js',
      'protect-security-config.js',
      'scan-write-for-secrets.js',
      'protect-authored-docs.js',
      'concurrent-edit-lock.js',
      'protect-ai-reference.js',
    ], input, true, true);
  }
  if (/^(Read|Grep|Glob)$/i.test(tool)) {
    const decision = runLegacySequence([
      'block-ai-reference.js',
      'block-sensitive-file-read.js',
      'protect-ai-reference.js',
    ], input, true, true);
    if (!decision) runLegacySequence(['warn-large-read.js'], input, false, false);
    return decision;
  }
  if (/^mcp__obsidian__/i.test(tool) || /^MCP:/i.test(tool)) {
    return runLegacySequence(['protect-ai-reference.js', 'block-obsidian-delete.js'], input, true, true);
  }
}

function runPostTool(input) {
  const tool = String(input.tool_name || input.tool || '');
  if (productName() === 'cursor') {
    runLegacySequence(['scrub-secrets-from-output.js'], input, false, false);
  }
  if (/^(Bash|PowerShell|Shell)$/i.test(tool)) {
    return runLegacySequence([
      'scan-output-for-secrets.js',
      'audit-bash-log.js',
      'bypass-incident-log.js',
    ], input, false, false);
  }
  if (/^(Write|Edit|MultiEdit|apply_patch)$/i.test(tool)) {
    return runLegacySequence(['format-on-edit.js'], input, false, false);
  }
  if (/^(Agent|Task)$/i.test(tool)) {
    return runLegacySequence(['auto-schedule-codex-poll.js', 'bypass-incident-log.js'], input, false, false);
  }
  if (/^Skill$/i.test(tool)) return runLegacySequence(['impeccable-run-log.js'], input, false, false);
}

let activeEvent = '';

function main() {
  const parsed = readInput();
  const input = parsed.value;
  const event = eventName(input);
  activeEvent = event;
  const preflight = ['pretooluse', 'beforeshellexecution', 'beforemcpexecution'].includes(event);
  if (parsed.malformed && (preflight || !event)) {
    process.stderr.write('security-dispatch: malformed preflight input; blocking the unchecked action.\n');
    process.exit(2);
  }
  if (parsed.malformed) {
    process.stderr.write('security-dispatch: malformed postflight input; advisory checks skipped.\n');
    return;
  }
  if (preflight) {
    runPreTool(input);
  } else if (event === 'posttooluse') {
    runPostTool(input);
  }
}

try {
  main();
} catch (error) {
  if (activeEvent !== 'posttooluse') {
    process.stderr.write('security-dispatch: preflight dispatcher failed; blocking the unchecked action.\n');
    process.exit(2);
  }
  process.stderr.write('security-dispatch: postflight dispatcher failed; advisory checks skipped.\n');
  process.exit(0);
}

module.exports = {
  readInput,
  eventName,
  productName,
  legacyRoots,
  findLegacy,
  securityTimeout,
  runLegacy,
  runPreTool,
  runPostTool,
};
