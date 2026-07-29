#!/usr/bin/env node
'use strict';
// Consolidated PreToolUse(Bash|PowerShell) security check -- merges 6 previously-separate hooks into ONE
// node.exe process to cut per-call overhead. Added 2026-07-07 after Douglas reported repeated 14-17s hook
// timeouts under heavy concurrent-session load; investigation (this session) confirmed 9 sequential
// node.exe cold-starts per single Bash/PowerShell call as the structural cost -- each of the 9 independently
// reads stdin, parses JSON, and requires its own deps, on every single tool call.
//
// Merges ONLY the 6 hooks that share a compatible exit-2-or-silent-allow contract, in their EXACT prior
// settings.json wiring order (preserves which reason wins if more than one would have matched):
//   1. block-visible-powershell.js (Bash only -- flashes a console window)
//   2. block-secret-dump.js (env/secret-file dumps)
//   3. block-dangerous-bash.js (rm -rf /, git reset --hard, DROP TABLE, etc. incl. interpreter one-liners)
//   4. guard-env-mutation.js (pip/npm/conda install-uninstall outside an explicit opt-in)
//   5. guard-bulk-delete.js (git rm, rm -rf, Remove-Item -Recurse, etc. outside an explicit opt-in)
//   6. protect-security-config.js's Bash/PowerShell branch (warn-only, NEVER blocks -- runs last, always,
//      even after an earlier block, since its warning is real signal even when the call was already denied
//      for a different reason; its own Write/Edit branch is untouched and still lives in the original file,
//      which stays wired separately for that matcher)
//   7. block-cd-chain-bash.js (added 2026-07-08, handoff from a concurrent session -- Bash only, catches a
//      leading "cd <dir> && ..." which breaks Bash permission-allowlist PREFIX matching since the chained
//      prefix moves the already-approved command text later in the string, causing an already-allowlisted
//      command to re-prompt. Same exit-2-or-silent-allow contract as the other 6.)
//
// Deliberately NOT merged -- each has a genuinely different control-flow contract that a shared exit code
// would silently collapse, which is a real behavior change, not just a speed optimization:
//   - check-secret-exposure.js: emits {decision:"block", reason} so the denied tool call does NOT end the
//     turn -- Claude is meant to pivot to a safer approach in the SAME turn. A bare exit(2) here would
//     instead end the turn via stopReason, losing that "keep going, just differently" semantic.
//   - block-egress-exfil.js: emits {continue:false, stopReason} -- deliberately ends the ENTIRE turn for
//     exfiltration risk, stronger than a single blocked tool call.
//   - protect-authored-docs.js: same {continue:false, stopReason} shape, deliberately stops the turn so a
//     stale-read-then-overwrite can't proceed even one more step.
// These three remain standalone hooks, unchanged, still wired to the same matcher.
//
// Behavior contract (unchanged from every individual merged hook): exit 2 + stderr text = block (first
// match wins, in the order listed above); exit 0 = allow. protect-security-config's warning is appended to
// stderr without forcing exit 2 on its own.
const fs = require('fs');
const path = require('path');
const S = require(path.join(__dirname, 'hook-state.js'));
const { allowsSecret } = require(path.join(__dirname, 'allow-tags'));

// ============================================================================
// 1. block-visible-powershell.js
// ============================================================================
const PS_SEGMENT_SPLIT = /(?:^|[;&|`]|\$\()\s*/;
const PS_INVOKES_POWERSHELL_AT_START = /^(powershell(\.exe)?|pwsh(\.exe)?)\b/i;
const PS_HIDDEN_FLAG = /-w(indow)?s(tyle)?\s+hidden\b/i;
const PS_START_PROCESS = /start-process/i;

function ps_invokesPowershell(cmd) {
  return cmd.split(PS_SEGMENT_SPLIT).some((segment) => PS_INVOKES_POWERSHELL_AT_START.test(segment.trimStart()));
}

function checkVisiblePowershell(input, cmd) {
  if (input.tool_name !== 'Bash') return null;
  if (!ps_invokesPowershell(cmd)) return null;

  const hiddenMatch = PS_HIDDEN_FLAG.exec(cmd);
  const startProcMatch = PS_START_PROCESS.exec(cmd);

  if (!hiddenMatch) {
    return `block-visible-powershell: no -WindowStyle Hidden anywhere in the command -- this will flash a visible console window. ` +
      `Add -WindowStyle Hidden as a top-level argument to the powershell/pwsh invocation. Prefer a ` +
      `native tool (curl/netstat/tasklist/findstr) instead of PowerShell when one of those can do the job.\n` +
      `Command: ${cmd.slice(0, 200)}\n`;
  }
  if (startProcMatch && hiddenMatch.index > startProcMatch.index) {
    return `block-visible-powershell: -WindowStyle Hidden is applied to the Start-Process TARGET, not to this outer powershell.exe ` +
      `process -- Bash still spawns THAT process directly and it will flash its own console window ` +
      `before it ever reaches your Start-Process line. Either (a) call the target directly with ` +
      `-WindowStyle Hidden as this invocation's own argument (Start-Process is usually unnecessary), ` +
      `or (b) if you genuinely need Start-Process semantics, add -WindowStyle Hidden to the OUTER call too.\n` +
      `Command: ${cmd.slice(0, 200)}\n`;
  }
  return null;
}

// ============================================================================
// 2. block-secret-dump.js
// ============================================================================
const SD_SECRET =
  "(?:[A-Z0-9_]*(?:SECRET|TOKEN|API[_-]?KEY|APIKEY|PASSWORD|PASSWD|PRIVATE[_-]?KEY|ACCESS[_-]?KEY|CLIENT[_-]?SECRET|CREDENTIAL|BEARER)[A-Z0-9_]*|[A-Z0-9_]*_PAT\\b|OPENAI[A-Z0-9_]*|ANTHROPIC[A-Z0-9_]*|CLAUDE[A-Z0-9_]*|GITHUB[A-Z0-9_]*|GH_(?:TOKEN|PAT)|AWS_[A-Z0-9_]*|AZURE[A-Z0-9_]*|GOOGLE[A-Z0-9_]*|GCP[A-Z0-9_]*|GCLOUD[A-Z0-9_]*|FIREBASE[A-Z0-9_]*|STRIPE[A-Z0-9_]*|SLACK[A-Z0-9_]*|DISCORD[A-Z0-9_]*|TWILIO[A-Z0-9_]*|SENDGRID[A-Z0-9_]*|MAILGUN[A-Z0-9_]*|RESEND[A-Z0-9_]*|VERCEL[A-Z0-9_]*|NETLIFY[A-Z0-9_]*|SUPABASE[A-Z0-9_]*|FIREWORKS[A-Z0-9_]*|OPENROUTER[A-Z0-9_]*|GROQ[A-Z0-9_]*|REPLICATE[A-Z0-9_]*|HUGGINGFACE[A-Z0-9_]*|HF_[A-Z0-9_]*|COHERE[A-Z0-9_]*|MISTRAL[A-Z0-9_]*|DEEPSEEK[A-Z0-9_]*|NOTION[A-Z0-9_]*|CLOUDFLARE[A-Z0-9_]*|NPM_TOKEN|PYPI[A-Z0-9_]*|DOCKER[A-Z0-9_]*|SENTRY[A-Z0-9_]*|DATADOG[A-Z0-9_]*)";
const SD_READ =
  "(?:cat|bat|tac|nl|head|tail|less|more|view|strings|xxd|od|hexdump|base64|tee|grep|egrep|fgrep|rg|ag|sed|awk|gawk|cut|tr|sort|uniq|jq|yq|Get-Content|gc|type)";
const SD_SECRET_FILE =
  "(?:\\.envrc|credentials(?:\\.[A-Za-z0-9]+)?|secrets?\\.(?:json|ya?ml|env|txt)|id_rsa|id_ed25519|id_dsa|\\.pem|\\.p12|\\.pfx|\\.netrc|\\.npmrc|\\.pgpass|\\.git-credentials|service[_-]?account[A-Za-z0-9._-]*\\.json|\\.ssh[\\/\\\\]id_)";
const SD_TEMPLATE_SEG = new Set(["example", "sample", "template", "tpl", "dist", "default", "defaults", "md"]);

function sd_readsDotenv(cmd) {
  if (!new RegExp("\\b" + SD_READ + "\\b", "i").test(cmd)) return false;
  const re = /\.env(?:\.[A-Za-z0-9_-]+)*/gi;
  let m;
  while ((m = re.exec(cmd))) {
    const after = cmd[m.index + m[0].length] || "";
    if (/[A-Za-z0-9_]/.test(after)) continue;
    const lastSeg = m[0].split(".").pop().toLowerCase();
    if (SD_TEMPLATE_SEG.has(lastSeg)) continue;
    return true;
  }
  return false;
}

const SD_RULES = [
  [/(?:^|[;&|`(]|\bsudo\b)\s*(?:env|printenv)\s*(?:$|[|>&;`)])/i, "dumps all environment variables (env/printenv)"],
  [/\bexport\s+-p\b/i, "prints all exported variables (export -p)"],
  [/(?:^|[;&|`(])\s*export\s*(?:$|[|>`)])/i, "bare export prints all exported variables"],
  [/(?:^|[;&|`(])\s*set\s*(?:$|\|)/i, "bare set dumps all shell variables"],
  [/\bexport\s+["']?\$[({]/i, "export $(...) dynamically exports captured output — leaks if it errors"],
  [new RegExp("(?:\\$\\(|`)[^)`]*\\b(?:printenv|env)\\b", "i"), "command substitution captures the environment"],
  [new RegExp("\\b" + SD_READ + "\\b[^\\n]*(?:^|[\\s/'\"=([:])" + SD_SECRET_FILE, "i"), "reads a secret/.env file — its contents would land in the transcript"],
  [new RegExp("\\b(?:echo|printf|print|Write-Output|Write-Host|Write-Information)\\b[^\\n]*\\$\\{?" + SD_SECRET, "i"), "echoes a secret environment variable"],
  [new RegExp("\\b(?:printenv|env)\\s+\\$?\\{?" + SD_SECRET, "i"), "prints a named secret environment variable"],
  [/\b(?:Get-ChildItem|gci|ls|dir|Get-Item|gi)\b[^\n]*\benv:\s*(?:\*|\$|$|\||>)/i, "enumerates the PowerShell env: drive (all env vars)"],
  [/\[(?:System\.)?Environment\]::GetEnvironmentVariables\b/i, "[Environment]::GetEnvironmentVariables() returns the whole environment"],
  [new RegExp("\\$env:" + SD_SECRET, "i"), "references a secret PowerShell env var on the command line (it prints)"],
];

function checkSecretDump(input, cmd) {
  if (allowsSecret(input)) return null;
  if (sd_readsDotenv(cmd)) {
    return `BLOCKED — this command would leak secrets into the transcript: reads a real .env secret file — its contents would land in the transcript.\n` +
      `Command: ${cmd.slice(0, 160)}\n` +
      `Pass secrets straight to the program that needs them (they inherit the environment); ` +
      `never print, cat, grep, or export the environment or a .env file. ` +
      `To refresh one var without printing: unset VAR && export VAR=$(source-that-emits-only-that-value).`;
  }
  for (const [re, reason] of SD_RULES) {
    if (re.test(cmd)) {
      return `BLOCKED — this command would leak secrets into the transcript: ${reason}.\n` +
        `Command: ${cmd.slice(0, 160)}\n` +
        `Pass secrets straight to the program that needs them (they inherit the environment); ` +
        `never print, cat, grep, or export the environment or a .env file. ` +
        `To refresh one var without printing: unset VAR && export VAR=$(source-that-emits-only-that-value).`;
    }
  }
  return null;
}

// ============================================================================
// 3. block-dangerous-bash.js
// ============================================================================
const DB_dangerous = [
  { pattern: /\brm\s+-rf\s+\/(\s|$)/, label: "rm -rf /" },
  { pattern: /\brm\s+-rf\s+~(\s|$|\/)/, label: "rm -rf ~" },
  { pattern: /\brm\s+-rf\s+\*(\s|$)/, label: "rm -rf *" },
  { pattern: /\brm\s+-[a-z]*r[a-z]*f\s+[\/~]/, label: "rm -rf on root/home" },
  { pattern: /\brm\s+-[a-z]*f[a-z]*r\s+[\/~]/, label: "rm -rf on root/home" },
  { pattern: /:\(\)\s*\{.*\}.*:&/, label: "fork bomb" },
  { pattern: /\bmkfs\./, label: "filesystem format (mkfs)" },
  { pattern: /\bdd\s+[^|]*\bof=\/dev\/(sd|hd|nvme)/, label: "raw disk overwrite (dd)" },
  { pattern: />\s*\/dev\/(sd|hd|nvme)[a-z0-9]*\s*$/, label: "raw disk overwrite" },
  { pattern: /\bshutdown\s+(-[hr]|\/[hrs])/i, label: "system shutdown" },
  { pattern: /\bgit\s+push\b[^\n]*(?:--force\b(?!-with-lease)|\s-f(?:\s|$))/, label: "git push --force" },
  { pattern: /git\s+reset\s+--hard/, label: "git reset --hard" },
  { pattern: /git\s+clean\s+-[a-z]*f/, label: "git clean -f" },
  { pattern: /git\s+checkout\s+--\s+(?:\.|\*)(?:\s|$)/, label: "git checkout -- (discard changes)" },
  { pattern: /git\s+branch\s+-D\s/, label: "git branch -D (force delete)" },
  { pattern: /git\s+rebase\s+-i/, label: "git rebase -i (interactive)" },
  { pattern: /(?<!["'])\b(?:psql|mysql|mysqladmin|sqlite3|mongosh|mongo|sqlcmd|osql|sqlplus)\b[\s\S]*?\bDROP\s+TABLE\b/i, label: "DROP TABLE via DB client" },
  { pattern: /(?<!["'])\b(?:psql|mysql|mysqladmin|sqlite3|mongosh|mongo|sqlcmd|osql|sqlplus)\b[\s\S]*?\bTRUNCATE\s+TABLE\b/i, label: "TRUNCATE TABLE via DB client" },
];
const DB_INTERP = /\b(?:python[0-9.]*|python3?|node|nodejs|ruby|perl|deno|bun)\b/i;
const DB_DANGEROUS_IN_CODE = [
  { pattern: /\brm\s+-[a-z]*r[a-z]*f|\brm\s+-[a-z]*f[a-z]*r/i, label: "rm -rf (in interpreter one-liner)" },
  { pattern: /\bgit\s+reset\s+--hard/i, label: "git reset --hard (in interpreter one-liner)" },
  { pattern: /\bgit\s+checkout\s+--\s+(?:\.|\*)/i, label: "git checkout -- . (in interpreter one-liner)" },
  { pattern: /\bgit\s+clean\s+-[a-z]*f/i, label: "git clean -f (in interpreter one-liner)" },
  { pattern: /\bgit\s+push\b[^\n]*(?:--force\b(?!-with-lease)|\s-f(?:\s|$))/i, label: "git push --force (in interpreter one-liner)" },
  { pattern: /\bmkfs(?:\.[A-Za-z0-9_-]+)?\s+\/dev\//i, label: "mkfs (in interpreter one-liner)" },
  { pattern: /\bdd\b[^\n;&|]*\bof=\/dev\//i, label: "dd of=/dev/ (in interpreter one-liner)" },
  { pattern: /\bshred\b\s+/i, label: "shred (in interpreter one-liner)" },
  { pattern: /\bfind\b[^\n]*\s-delete\b/i, label: "find -delete (in interpreter one-liner)" },
  { pattern: /\bshutil\.rmtree\s*\(/i, label: "shutil.rmtree() (in interpreter one-liner)" },
  { pattern: /\bos\.(?:remove|unlink|removedirs|rmdir)\s*\(/i, label: "os.remove/unlink() (in interpreter one-liner)" },
  { pattern: /\b(?:fs|require\(['"]fs['"]\))\.(?:rmSync|unlinkSync|rmdirSync|rm)\s*\(/i, label: "fs.rmSync/unlinkSync() (in interpreter one-liner)" },
];

function db_tokenize(s) {
  const out = [];
  const re = /"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|(\S+)/g;
  let m;
  while ((m = re.exec(s)) !== null) {
    out.push(m[1] !== undefined ? m[1] : m[2] !== undefined ? m[2] : m[3]);
  }
  return out;
}

function db_extractInterpreterCode(tokens) {
  for (let i = 1; i < tokens.length; i++) {
    const t = tokens[i];
    if (!t) continue;
    if ((t === "-c" || t === "-e") && tokens[i + 1] != null) return tokens[i + 1];
    if (t.startsWith("-") && !t.startsWith("--") && (t.includes("c") || t.includes("e")) && tokens[i + 1] != null) {
      return tokens[i + 1];
    }
  }
  return null;
}

function checkDangerousBash(cmd) {
  for (const { pattern, label } of DB_dangerous) {
    if (pattern.test(cmd)) {
      return `Blocked destructive command (${label}): ${cmd.slice(0, 120)}. ` +
        `If this is intended, ask the user to run it manually or temporarily disable the block-dangerous-bash hook.`;
    }
  }
  if (DB_INTERP.test(cmd)) {
    const code = db_extractInterpreterCode(db_tokenize(cmd));
    if (code) {
      for (const { pattern, label } of DB_DANGEROUS_IN_CODE) {
        if (pattern.test(code)) {
          return `Blocked destructive command (${label}): ${cmd.slice(0, 120)}. ` +
            `A destructive operation was hidden inside a python -c / node -e style one-liner. ` +
            `If this is intended, ask the user to run it manually or temporarily disable the block-dangerous-bash hook.`;
        }
      }
    }
  }
  return null;
}

// ============================================================================
// 4. guard-env-mutation.js
// ============================================================================
const EM_mutations = [
  { p: /\bpip[0-9.]*\s+(install|uninstall)\b/, l: "pip install/uninstall" },
  { p: /\bpython[0-9.]*\s+-m\s+pip\s+(install|uninstall)\b/, l: "python -m pip install/uninstall" },
  { p: /\b(conda|mamba)\s+(install|remove|uninstall|update|upgrade)\b/, l: "conda/mamba env change" },
  { p: /\bscoop\s+(install|uninstall|update)\b/, l: "scoop install/uninstall" },
  { p: /\bnpm\s+(install|uninstall|i|rm|ci)\b[^|;&]*?\s(?:-g|--global)\b/, l: "npm global install" },
  { p: /\b(pipx|uv)\s+(install|uninstall|remove)\b/, l: "pipx/uv install" },
  { p: /\bpoetry\s+(add|remove)\b/, l: "poetry add/remove" },
];

function checkEnvMutation(cmd) {
  if (/\bALLOW_ENV_MUTATION=1\b/.test(cmd)) return null;
  for (const { p, l } of EM_mutations) {
    if (p.test(cmd)) {
      return `Blocked environment mutation (${l}): ${cmd.slice(0, 120)}\n` +
        `Shared Python/Node env changes must be DELIBERATE — an interrupted pip reinstall gutted the VTK install ` +
        `and broke the toolchain (2026-06-26). If this is intended:\n` +
        `  1) git-commit a checkpoint first,\n` +
        `  2) run it in the MAIN session (not an unattended subagent),\n` +
        `  3) re-run prefixed with ALLOW_ENV_MUTATION=1 to proceed,\n` +
        `  4) verify imports afterward.`;
    }
  }
  return null;
}

// ============================================================================
// 5. guard-bulk-delete.js
// ============================================================================
const BD_bulk = [
  { p: /\bgit\s+rm\b/, l: "git rm (removes tracked files)" },
  { p: /\brm\s+(?:-[a-z]*\s+)*[^|;&]*\*/, l: "rm with a wildcard (mass delete)" },
  { p: /\brm\s+-[a-z]*r[a-z]*\b/, l: "rm -r / -rf (recursive delete)" },
  { p: /\bRemove-Item\b[^|;&]*-Recurse/i, l: "Remove-Item -Recurse" },
  { p: /\bRemove-Item\b[^|;&]*-Force/i, l: "Remove-Item -Force" },
  { p: /\bfind\b[^|]*\s-delete\b/, l: "find -delete" },
  { p: /\bfind\b[^|]*-exec\s+rm\b/, l: "find -exec rm" },
  { p: /\bxargs\b[^|]*\brm\b/, l: "xargs rm (bulk delete)" },
];

function checkBulkDelete(cmd) {
  if (/\bALLOW_BULK_DELETE=1\b/.test(cmd)) return null;
  for (const { p, l } of BD_bulk) {
    if (p.test(cmd)) {
      return `Blocked bulk/irrecoverable delete (${l}): ${cmd.slice(0, 120)}\n` +
        `A subagent mass-deleted ~50 source files this way (2026-06-26). Single moves/renames and single-file ` +
        `deletes are fine; mass/recursive deletion must be DELIBERATE. If intended:\n` +
        `  1) make sure git has a clean checkpoint of these files (git commit),\n` +
        `  2) re-run prefixed with ALLOW_BULK_DELETE=1 to proceed.`;
    }
  }
  return null;
}

// ============================================================================
// 6. protect-security-config.js -- Bash/PowerShell branch only (warn, never block)
// ============================================================================
// NOTE: a 7th check (cd-chain handling) briefly lived here as a BLOCK (2026-07-08), then was replaced the
// same day per Douglas: "is the hook blocking the && commands actually the best way? ... i don't want to
// limit my agents". The replacement is allow-cd-chain-bash.js -- a SEPARATE standalone hook, not merged
// here, because its contract is fundamentally different (hookSpecificOutput.permissionDecision:"allow" via
// stdout JSON, not exit-2+stderr) -- it strips a leading "cd X && " prefix and auto-approves the ORIGINAL,
// unmodified command when the stripped form already matches one of Douglas's real permissions.allow Bash
// rules, instead of blocking the pattern outright. See allow-cd-chain-bash.js's own header for the full
// design rationale and the confirmed-safe precedence property (a deny/exit-2 from this file always wins
// over that hook's allow, so it can never weaken any check here).
function psc_isProtectedPath(p) {
  if (!p) return false;
  const s = String(p).replace(/\\/g, '/');
  return /(^|\/)\.claude\/settings(\.[\w]+)*\.json$/i.test(s)
      || /(^|\/)\.claude\/keybindings\.json$/i.test(s)
      || /(^|\/)\.claude\/hooks\//i.test(s)
      || /(^|\/)\.mcp\.json$/i.test(s)
      || /(^|\/)CLAUDE\.md$/i.test(s)
      || /(^|\/)MEMORY\.md$/i.test(s)
      || /\.claude\/.*memory\/.+/i.test(s);
}

function checkSecurityConfigWarn(cmd) {
  let hit = false;
  const redir = cmd.match(/>>?\s*("?)([^\s"';|&]+)\1/);
  if (redir && psc_isProtectedPath(redir[2])) hit = true;
  const teeM = cmd.match(/\btee\b\s+(?:-a\s+)?("?)([^\s"';|&]+)\1/i);
  if (teeM && psc_isProtectedPath(teeM[2])) hit = true;
  if (!hit && /(?:^|[;&|])\s*(?:sudo\s+)?(?:rm|rmdir|del|erase|mv|move|cp|copy|truncate)\b/i.test(cmd)) {
    for (const tok of cmd.split(/[\s"';|&]+/)) {
      if (psc_isProtectedPath(tok)) { hit = true; break; }
    }
  }
  if (!hit) {
    for (const tok of cmd.split(/[\s"';|&]+/)) {
      if (psc_isProtectedPath(tok)) { hit = true; break; }
    }
  }
  if (!hit) return null;
  return '[security-config] ⚠ Action targets a protected security file: ' + cmd.slice(0, 120) + '\n' +
    'Confirm with the user before accepting this change.\n';
}

// ============================================================================
// main
// ============================================================================
function main() {
  const input = S.readStdin();
  if (input.tool_name !== 'Bash' && input.tool_name !== 'PowerShell') return;
  const cmd = ((input.tool_input && input.tool_input.command) || '').toString();
  if (!cmd.trim()) return;

  const block = checkVisiblePowershell(input, cmd)
    || checkSecretDump(input, cmd)
    || checkDangerousBash(cmd)
    || checkEnvMutation(cmd)
    || checkBulkDelete(cmd);

  const warn = checkSecurityConfigWarn(cmd); // runs regardless -- warn-only, never itself blocks

  if (warn) process.stderr.write(warn);
  if (block) {
    process.stderr.write(block + '\n');
    process.exit(2);
  }
  process.exit(0);
}

if (require.main === module) {
  try { main(); } catch (_) { process.exit(0); /* fail open on unexpected error, matches every merged hook's own discipline */ }
}

module.exports = {
  checkVisiblePowershell, checkSecretDump, checkDangerousBash, checkEnvMutation, checkBulkDelete,
  checkSecurityConfigWarn, ps_invokesPowershell, sd_readsDotenv, psc_isProtectedPath,
};
