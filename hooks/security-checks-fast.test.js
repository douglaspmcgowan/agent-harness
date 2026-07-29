#!/usr/bin/env node
'use strict';
// Regression harness for security-checks-fast.js -- the 6-hook consolidation (block-visible-powershell,
// block-secret-dump, block-dangerous-bash, guard-env-mutation, guard-bulk-delete,
// protect-security-config's Bash/PowerShell branch). Every case here is either lifted directly from, or
// modeled closely on, the ORIGINAL standalone hook's own documented trigger/non-trigger examples, so a
// pass here is real evidence of zero-regression, not just "the merged script runs."
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const HOOK = path.join(__dirname, 'security-checks-fast.js');
let pass = 0, fail = 0;
function check(name, cond, extra) { cond ? (pass++, console.log('  PASS', name)) : (fail++, console.log('  FAIL', name, extra !== undefined ? JSON.stringify(extra) : '')); }

function run(toolName, command, opts) {
  const payload = Object.assign({ tool_name: toolName, tool_input: { command } }, opts || {});
  const r = spawnSync('node', [HOOK], { input: JSON.stringify(payload), encoding: 'utf8', timeout: 5000 });
  return { code: r.status, stderr: r.stderr || '', stdout: r.stdout || '', timedOut: r.error && r.error.code === 'ETIMEDOUT' };
}

console.log('=== security-checks-fast.js battery ===\n');

// ---- 1. block-visible-powershell ----
console.log('-- block-visible-powershell --');
{
  const r = run('Bash', 'powershell.exe -Command "Get-Process"');
  check('1a) powershell without -WindowStyle Hidden -> blocked', r.code === 2 && /visible console window/.test(r.stderr), r);
}
{
  const r = run('Bash', 'powershell.exe -WindowStyle Hidden -Command "Get-Process"');
  check('1b) powershell WITH top-level -WindowStyle Hidden -> allowed', r.code === 0, r);
}
{
  const r = run('Bash', 'powershell.exe -Command "Start-Process foo.exe -WindowStyle Hidden"');
  check('1c) -WindowStyle Hidden on Start-Process TARGET only -> still blocked (outer process flashes)', r.code === 2 && /Start-Process TARGET/.test(r.stderr), r);
}
{
  const r = run('Bash', 'grep -i powershell notes.txt');
  check('1d) "powershell" as a grep ARGUMENT, not invoked -> allowed', r.code === 0, r);
}
{
  const r = run('PowerShell', 'powershell.exe -Command "Get-Process"');
  check('1e) tool_name=PowerShell (not Bash) -> this specific check skips (matches original tool_name===Bash guard)', r.code === 0, r);
}

// ---- 2. block-secret-dump ----
console.log('\n-- block-secret-dump --');
{
  const r = run('Bash', 'env');
  check('2a) bare env -> blocked', r.code === 2 && /leak secrets/.test(r.stderr), r);
}
{
  const r = run('Bash', 'echo $ANTHROPIC_API_KEY');
  check('2b) echoing a secret env var -> blocked', r.code === 2, r);
}
{
  const r = run('Bash', 'cat .env');
  check('2c) cat .env -> blocked', r.code === 2, r);
}
{
  const r = run('Bash', 'cat .env.example');
  check('2d) cat .env.example (template) -> allowed', r.code === 0, r);
}
{
  const r = run('Bash', 'printenv PATH');
  check('2e) printenv PATH (non-secret name) -> allowed', r.code === 0, r);
}
{
  const r = run('Bash', 'cat package.json');
  check('2f) ordinary file read -> allowed', r.code === 0, r);
}

// ---- 3. block-dangerous-bash ----
console.log('\n-- block-dangerous-bash --');
{
  const r = run('Bash', 'rm -rf /');
  check('3a) rm -rf / -> blocked', r.code === 2 && /rm -rf \//.test(r.stderr), r);
}
{
  const r = run('Bash', 'git reset --hard');
  check('3b) git reset --hard -> blocked', r.code === 2, r);
}
{
  const r = run('Bash', 'git push --force-with-lease');
  check('3c) git push --force-with-lease (safe variant) -> allowed', r.code === 0, r);
}
{
  const r = run('Bash', 'git checkout -- src/x.py');
  check('3d) single-file git checkout -- -> allowed', r.code === 0, r);
}
{
  const r = run('Bash', 'git checkout -- .');
  check('3e) bulk git checkout -- . -> blocked', r.code === 2, r);
}
{
  // shutil.rmtree(...) only matches the interpreter-specific DANGEROUS_IN_CODE path, not the outer
  // dangerous[] array (which has no shutil.rmtree pattern) -- isolates the one-liner-extraction logic
  // specifically, unlike a bare "rm -rf" which the outer array would also catch on its own.
  const r = run('Bash', 'python -c "import shutil; shutil.rmtree(\'/tmp/x\')"');
  check('3f) shutil.rmtree() disguised in python -c one-liner -> blocked via interpreter-code path', r.code === 2 && /interpreter one-liner/.test(r.stderr), r);
}
{
  const r = run('Bash', 'echo "DROP TABLE users"');
  check('3g) DROP TABLE inside an echo (not a real DB client call) -> allowed', r.code === 0, r);
}
{
  const r = run('Bash', 'ls -la');
  check('3h) ordinary benign command -> allowed', r.code === 0, r);
}

// ---- 4. guard-env-mutation ----
console.log('\n-- guard-env-mutation --');
{
  const r = run('Bash', 'pip install requests');
  check('4a) pip install -> blocked', r.code === 2 && /environment mutation/.test(r.stderr), r);
}
{
  const r = run('Bash', 'ALLOW_ENV_MUTATION=1 pip install requests');
  check('4b) pip install with explicit opt-in -> allowed', r.code === 0, r);
}
{
  const r = run('Bash', 'pip list');
  check('4c) pip list (not install/uninstall) -> allowed', r.code === 0, r);
}
{
  const r = run('PowerShell', 'pip install requests');
  check('4d) fires for PowerShell tool_name too (not just Bash)', r.code === 2, r);
}

// ---- 5. guard-bulk-delete ----
console.log('\n-- guard-bulk-delete --');
{
  const r = run('Bash', 'git rm old_file.py');
  check('5a) git rm -> blocked', r.code === 2 && /bulk\/irrecoverable delete/.test(r.stderr), r);
}
{
  const r = run('Bash', 'rm -rf node_modules');
  check('5b) rm -rf on a single named dir -> blocked (recursive delete pattern)', r.code === 2, r);
}
{
  const r = run('Bash', 'ALLOW_BULK_DELETE=1 git rm old_file.py');
  check('5c) git rm with explicit opt-in -> allowed', r.code === 0, r);
}
{
  const r = run('Bash', 'rm single_file.txt');
  check('5d) single-file rm (no -r, no wildcard) -> allowed', r.code === 0, r);
}
{
  const r = run('Bash', 'mv old_name.py new_name.py');
  check('5e) rename (mv, not rm) -> allowed', r.code === 0, r);
}

// ---- 6. protect-security-config (warn-only, never blocks on its own) ----
console.log('\n-- protect-security-config (warn-only) --');
{
  const r = run('Bash', 'cat C:/Users/dmcgowa2/.claude/hooks/keep-going.js');
  check('6a) reading a hook file (not rm/mv/cp/redirect) -> allowed, no warning (read-only isn\'t in the verb list)', r.code === 0, r);
}
{
  const r = run('Bash', 'rm C:/Users/dmcgowa2/.claude/hooks/keep-going.js');
  check('6b) rm targeting a hook path -> warns via stderr (does NOT itself force exit 2 -- but guard-bulk-delete\'s recursive-rm pattern wouldn\'t catch a single-file rm, so this should be exit 0 with a warning)', r.code === 0 && /protected security file/.test(r.stderr), r);
}
{
  const r = run('Bash', 'ls C:/Users/dmcgowa2/Documents/');
  check('6c) ordinary command touching no protected path -> allowed, no warning', r.code === 0 && !/protected security file/.test(r.stderr), r);
}

// ---- ordering: when multiple checks would fire, the FIRST one in the merge order wins (matches prior array order) ----
console.log('\n-- ordering / interaction --');
{
  // "rm -rf /" matches block-dangerous-bash (3rd in order); should NOT also need guard-bulk-delete's message
  const r = run('Bash', 'rm -rf /');
  check('7a) rm -rf / -> block-dangerous-bash\'s message wins (checked before guard-bulk-delete)', r.code === 2 && /rm -rf \//.test(r.stderr) && !/bulk\/irrecoverable/.test(r.stderr), r);
}

// NOTE: cd-chain handling used to be tested here as a 7th merged check. It's now a separate standalone
// hook (allow-cd-chain-bash.js, own test file allow-cd-chain-bash.test.js) -- see security-checks-fast.js's
// own header note for why (different output contract: permissionDecision:"allow", not exit-2+stderr).

// ---- malformed / edge-case input -- never throws, never hangs ----
console.log('\n-- malformed input --');
{
  const r = spawnSync('node', [HOOK], { input: 'not json', encoding: 'utf8', timeout: 5000 });
  check('8a) malformed JSON stdin -> exit 0, no throw', r.status === 0, { status: r.status, stderr: r.stderr });
}
{
  const r = spawnSync('node', [HOOK], { input: '', encoding: 'utf8', timeout: 5000 });
  check('8b) empty stdin -> exit 0, no throw', r.status === 0, { status: r.status, stderr: r.stderr });
}
{
  const r = run('Bash', '');
  check('8c) empty command string -> exit 0, no throw', r.code === 0, r);
}
{
  const r = run('Read', 'rm -rf /'); // wrong tool_name entirely
  check('8d) tool_name that is not Bash/PowerShell -> exit 0 (early return)', r.code === 0, r);
}
{
  const payload = { tool_name: 'Bash', tool_input: { command: null } };
  const r = spawnSync('node', [HOOK], { input: JSON.stringify(payload), encoding: 'utf8', timeout: 5000 });
  check('8e) tool_input.command is null -> exit 0, no throw', r.status === 0, { status: r.status, stderr: r.stderr });
}

// ---- [allow-secret] escape hatch (block-secret-dump's own tag mechanism, via transcript_path) ----
console.log('\n-- allow-tags escape hatch --');
{
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'scf-'));
  const tpath = path.join(d, 'transcript.jsonl');
  fs.writeFileSync(tpath, JSON.stringify({ message: { role: 'user', content: [{ type: 'text', text: 'run this [allow-secret]' }] } }) + '\n');
  const r = run('Bash', 'env', { transcript_path: tpath });
  check('9a) [allow-secret] tag in last user message -> env dump allowed through', r.code === 0, r);
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
