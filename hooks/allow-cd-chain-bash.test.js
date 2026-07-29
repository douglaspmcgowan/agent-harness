#!/usr/bin/env node
'use strict';
// Regression harness for allow-cd-chain-bash.js -- the auto-allow redesign replacing the earlier
// block-cd-chain-bash.js (2026-07-08, Douglas: "i don't want to limit my agents"). Tests both the pure
// matching logic (via require()) and the full subprocess stdin/stdout contract.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const { extractPostCdCommand, matchesAllowPattern, bashRulePattern } = require('./allow-cd-chain-bash.js');

const HOOK = path.join(__dirname, 'allow-cd-chain-bash.js');
let pass = 0, fail = 0;
function check(name, cond, extra) { cond ? (pass++, console.log('  PASS', name)) : (fail++, console.log('  FAIL', name, JSON.stringify(extra))); }

console.log('=== allow-cd-chain-bash.js battery ===\n');

// ---- pure logic: extractPostCdCommand ----
console.log('-- extractPostCdCommand --');
check('strips "cd X && Y" -> "Y"', extractPostCdCommand('cd "C:/some/path" && "python.exe" -m pytest foo.py') === '"python.exe" -m pytest foo.py');
check('strips "cd X ; Y" -> "Y"', extractPostCdCommand('cd /tmp ; ls -la') === 'ls -la');
check('strips "cd X | Y" -> "Y"', extractPostCdCommand('cd /tmp | grep x') === 'grep x');
check('standalone "cd X" (no chain) -> null', extractPostCdCommand('cd "C:/some/path"') === null);
check('&& only inside quotes -> null (no real chain)', extractPostCdCommand('cd "C:/a && b"') === null);
check('not a cd command at all -> null', extractPostCdCommand('git status') === null);
check('"cd" mentioned mid-string, not leading -> null', extractPostCdCommand('echo "please cd into it" && ls') === null);

// ---- pure logic: matchesAllowPattern (Claude Code's own documented prefix-match semantics) ----
console.log('\n-- matchesAllowPattern --');
check('bare "*" matches anything', matchesAllowPattern('literally anything', '*') === true);
check('"git *" matches "git status"', matchesAllowPattern('git status', 'git *') === true);
check('"git *" matches bare "git"', matchesAllowPattern('git', 'git *') === true);
check('"git *" does NOT match "github-cli"', matchesAllowPattern('github-cli', 'git *') === false);
check('exact pattern (no trailing *) requires exact match', matchesAllowPattern('python foo.py', 'python foo.py') === true);
check('exact pattern does NOT match a longer command', matchesAllowPattern('python foo.py extra', 'python foo.py') === false);
check('quoted-path pattern matches its own prefix', matchesAllowPattern('"C:/x/python.exe" -m pytest foo.py', '"C:/x/python.exe" -m pytest *') === true);

// ---- pure logic: bashRulePattern ----
console.log('\n-- bashRulePattern --');
check('extracts inner pattern from "Bash(git *)"', bashRulePattern('Bash(git *)') === 'git *');
check('returns null for a non-Bash rule', bashRulePattern('Read(**/*.md)') === null);

// ---- full subprocess: stdin/stdout contract ----
console.log('\n-- subprocess contract --');
function run(toolName, command) {
  const payload = JSON.stringify({ tool_name: toolName, tool_input: { command } });
  const r = spawnSync('node', [HOOK], { input: payload, encoding: 'utf8', timeout: 5000 });
  let parsed = null; try { parsed = JSON.parse(r.stdout || '{}'); } catch (_) {}
  return { code: r.status, stdout: r.stdout || '', stderr: r.stderr || '', parsed };
}

{
  // git is a real allowed pattern in this machine's settings.json ("Bash(git *)")
  const r = run('Bash', 'cd "C:/some/path" && git status');
  const decision = r.parsed && r.parsed.hookSpecificOutput && r.parsed.hookSpecificOutput.permissionDecision;
  check('cd-chained "git status" (matches real Bash(git *) rule) -> permissionDecision:allow', r.code === 0 && decision === 'allow', r);
}
{
  const r = run('Bash', 'cd "C:/some/path"');
  check('standalone cd (no chain) -> no output at all, exit 0', r.code === 0 && r.stdout === '', r);
}
{
  const r = run('PowerShell', 'cd /tmp && git status');
  check('tool_name=PowerShell (this hook is Bash-only) -> no output', r.code === 0 && r.stdout === '', r);
}
{
  const r = run('Bash', 'git status'); // no cd prefix at all
  check('bare command, no cd chain -> no output (nothing to do)', r.code === 0 && r.stdout === '', r);
}
{
  const r = spawnSync('node', [HOOK], { input: 'not json', encoding: 'utf8', timeout: 5000 });
  check('malformed JSON stdin -> exit 0, no throw', r.status === 0, { status: r.status, stderr: r.stderr });
}
{
  const r = spawnSync('node', [HOOK], { input: '', encoding: 'utf8', timeout: 5000 });
  check('empty stdin -> exit 0, no throw', r.status === 0, { status: r.status });
}

// ---- critical: NEVER blocks (exit code must always be 0/null-equivalent success, never 2) ----
console.log('\n-- never blocks --');
{
  // even a cd-chained DANGEROUS-looking command should never get BLOCKED by this hook specifically --
  // that's security-checks-fast.js's job; this hook only ever allows or stays silent.
  const r = run('Bash', 'cd /tmp && rm -rf /');
  check('this hook never emits a block decision, even for a dangerous-looking stripped command', r.code === 0 && !/"decision":"block"/.test(r.stdout) && r.code !== 2, r);
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
