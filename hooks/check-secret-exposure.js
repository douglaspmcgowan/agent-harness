#!/usr/bin/env node
// PreToolUse hook: blocks Bash/PowerShell commands whose PRIMARY PURPOSE is to reveal
// secrets, credentials, or env-var values. Tuned for high precision (few false positives):
// broad "might leak" commands (git config/remote/log, docker inspect, set -x) are intentionally
// NOT blocked here — scan-output-for-secrets.js is the backstop that catches real key formats
// in any command's output.
//
// Sources: MITRE ATT&CK T1552, gitleaks/truffleHog pattern libraries, smallstep secrets guide.

const path = require('path');
const { allowsSecret } = require(path.join(__dirname, 'allow-tags'));

const chunks = [];
process.stdin.on('data', d => chunks.push(d));
process.stdin.on('end', () => {
  try {
    const input = JSON.parse(Buffer.concat(chunks).toString());
    const cmd = (input.tool_input?.command || '').replace(/\r?\n/g, ' ');
    if (!cmd.trim()) return;

    // Escape hatch: [allow-secret] / [allow-all] in the user's current prompt lets this one
    // command through instead of forcing the whole hook to be disabled (see allow-tags.js).
    // Fails closed — no tag (or any transcript-read error) leaves the block in force.
    if (allowsSecret(input)) return;

    const block = (kind, alts, cmd) => {
      const cmdShort = (cmd || '').slice(0, 200);
      const msg = [
        `BLOCKED by check-secret-exposure hook (kind: ${kind}).`,
        `COMMAND: ${cmdShort}`,
        ``,
        `WHY: this command would print or expose credential values (API keys, tokens, env-var values) into Claude's context and the on-disk session transcript. Once secrets enter the transcript, the only safe remediation is rotation.`,
        ``,
        `=== ACTION REQUIRED — DO NOT proceed silently. ===`,
        `Your next tool call MUST be AskUserQuestion with the following parameters (do not paraphrase, do not skip, do not pick an option for the user):`,
        ``,
        `  question: "A command was blocked because it would expose secrets (kind: ${kind}). Command: ${cmdShort}. How should I proceed?"`,
        `  header:   "Blocked cmd"`,
        `  options:`,
        `    1. label: "Use safer alternative"`,
        `       description: "Re-attempt with a metadata-only probe (length / set-unset / hash). Recommended."`,
        `    2. label: "Authorize this once"`,
        `       description: "User confirms this specific command is OK to run. I'll re-run it verbatim."`,
        `    3. label: "Skip / abandon"`,
        `       description: "Drop this avenue, continue with other diagnostic paths."`,
        ``,
        `Wait for the user's selection before doing anything else.`,
        ``,
        `SAFER ALTERNATIVES (for option 1):`,
        ...(alts || []).map(a => `  - ${a}`),
        `  - Existence + length:  if ($v=[Environment]::GetEnvironmentVariable('NAME','User')) { "len=$($v.Length)" } else { "UNSET" }`,
        `  - Hash compare:        pass the value to a program that hashes it; never print the value itself`,
        `  - Name list only:      [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment').GetValueNames()  (NAMES ONLY — never call GetValue)`,
      ].join('\n');
      // Use {decision:"block", reason} so the tool call is denied but the AGENT TURN CONTINUES.
      // {continue:false, stopReason} would kill the entire turn — too aggressive: the user wants
      // Claude to pivot to a safer approach in the same turn after seeing the block.
      process.stdout.write(JSON.stringify({ decision: 'block', reason: msg }));
    };

    // PAT and PASS are guarded with (?![A-Z]) so they don't swallow common vars like $PATH / $PASSED.
    const SECRET_NAMES = '(?:AWS|GITHUB|GH|API|TOKEN|SECRET|KEY|PASS(?:WORD|WD)?(?![A-Z])|CRED(?:ENTIAL)?|AUTH|PRIVATE|PAT(?![A-Z])|STRIPE|SLACK|TWILIO|SENDGRID|ANTHROPIC|OPENAI|NMC|Internal)';

    // ── Helper: block reads of real secret-bearing files, but allow template/example variants ──
    function blocksSecretFileRead(c) {
      const reader = /\b(?:cat|type|Get-Content|gc|less|more|head|tail|bat|nano|vi|vim|code|notepad)\b/i;
      if (!reader.test(c)) return false;
      // template/example markers: .example  -example  _template  .sample.json  etc.
      const TEMPLATE = /[._-](example|sample|template|tmpl|dist|skeleton|test)([._-]|$)/i;
      // a listing/search command present anywhere means glob tokens are name PATTERNS, not file reads
      // (e.g. `find . -iname "*.env"`, `ls *secret*`). Skip those so a benign listing isn't flagged as a read.
      const hasListing = /\b(?:find|ls|dir|grep|rg|egrep|fgrep|fd|locate|tree|glob)\b/i.test(c);
      for (const raw of c.split(/[\s"'`=|;&]+/)) {
        const tok = raw.trim();
        if (!tok) continue;
        if (TEMPLATE.test(tok)) continue;                         // skip templates/examples
        if (hasListing && /[*?\[\]]/.test(tok)) continue;         // glob pattern under a listing cmd = enumeration, not a read
        const isEnv = /(^|[\/\\])\.env($|\.)/i.test(tok) || /\.env(\.[\w]+)*$/i.test(tok);
        const isNamedSecret =
          /(secret|token|credential|api[_-]?key|password|passwd)/i.test(tok) &&
          /\.(json|ya?ml|toml|ini|conf|cfg|txt|env|pem|key)$/i.test(tok);
        if (isEnv || isNamedSecret) return true;
      }
      return false;
    }

    // ── Helper: block curl/wget Authorization header ONLY when it carries a LITERAL secret ──
    // Using an env-var reference ($VAR / ${VAR} / %VAR%) is the recommended pattern — allow it.
    function blocksLiteralAuthHeader(c) {
      const m = c.match(/\b(?:curl|wget)\b[^|]*?(?:-H|--header)\s+['"]?Authorization\s*:\s*(?:Bearer\s+|Basic\s+|Token\s+|Digest\s+)?([^\s'"]+)/i);
      if (!m) return false;
      const val = m[1];
      if (/^[\$%]\{?\w/.test(val)) return false;                  // $VAR / ${VAR} / %VAR% → allowed
      return /^[A-Za-z0-9+\/._\-]{12,}$/.test(val);               // literal high-entropy token → block
    }

    if (blocksSecretFileRead(cmd)) {
      return block('secret-file-read', [
        'Read only the keys you need with a parser that prints metadata: `python -c "import json,os; d=json.load(open(os.path.expanduser(\\"~/.config/x.json\\"))); print({k: type(v).__name__ for k,v in d.items()})"`',
      ], cmd);
    }
    if (blocksLiteralAuthHeader(cmd)) {
      return block('literal-auth-header', [
        'Reference the env var, not the literal: `curl -H "Authorization: Bearer $TOKEN" ...`',
      ], cmd);
    }

    const patterns = [

      // ── Full environment dumps (print EVERYTHING, including secrets) ───────
      /^\s*env\s*$/,                          // bare `env`
      /^\s*printenv\s*$/,                     // bare `printenv`
      /^\s*export\s+-p\b/,                    // export -p
      /^\s*declare\s+-x\b/,                   // declare -x
      /^\s*set\s*$/,                          // bare `set` (bash + CMD)
      /^\s*set\s+[A-Z](?!.*[=\-])/,          // `set VARNAME` (print value, no = or flags)

      // ── Targeted secret-named env echo (bash / CMD / PowerShell) ──────────
      new RegExp(`\\becho\\s+["']?\\$\\{?${SECRET_NAMES}[_A-Z0-9]*\\}?`, 'i'),
      new RegExp(`\\bprintf\\s+["']?%s["']?\\s+["']?\\$\\{?${SECRET_NAMES}[_A-Z0-9]*\\}?`, 'i'),
      new RegExp(`\\bprintenv\\s+${SECRET_NAMES}[_A-Z0-9]*`, 'i'),
      new RegExp(`^\\s*set\\s+${SECRET_NAMES}[_A-Z0-9]*\\s*$`, 'i'),  // CMD: set KEYNAME
      new RegExp(`\\becho\\s+%${SECRET_NAMES}[_A-Z0-9]*%`, 'i'),      // CMD: echo %KEY%

      // ── PowerShell env var enumeration / decryption ───────────────────────
      /Get-ChildItem\s+Env\s*:/i,
      /\b(?:gci|gi|dir|ls|Get-Item)\s+env\s*:/i,
      /\$env\s*:\s*\*/i,
      new RegExp(`\\$env\\s*:\\s*${SECRET_NAMES}[_A-Z0-9]*`, 'i'),
      /ConvertFrom-SecureString/i,
      /ConsoleHost_history\.txt/i,

      // ── Windows Registry env var queries ──────────────────────────────────
      /\breg\s+query\s+["']?HKCU\\Environment/i,
      /\breg\s+query\s+["']?HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session\s+Manager\\Environment/i,
      /\breg\s+query\s+(?:HKLM|HKCU|HKU|HKCR|HKCC)\b.*\/f\s+(?:password|secret|key|token|cred)/i,
      /\breg\s+export\s+(?:HKLM|HKCU|HKU)/i,

      // ── PowerShell registry env reads (Get-ItemProperty etc. on Environment keys) ──
      // These cmdlets, by default, dump ALL value-data under the registry key — including secrets.
      // Block reads of HKCU:\Environment and the HKLM Session Manager Environment subkey.
      /\b(?:Get-ItemProperty|gp|Get-ItemPropertyValue|gpv|Get-Item|gi)\s+[^|]*?(?:HKCU:?[\\\/]+|HKEY_CURRENT_USER[\\\/]+|HKLM:?[\\\/]+SYSTEM[\\\/]+CurrentControlSet[\\\/]+Control[\\\/]+Session[\s_]+Manager[\\\/]+)Environment\b/i,
      // Direct .NET registry: any GetValue call on the Environment subkey
      /\[Microsoft\.Win32\.Registry\][^|]*?OpenSubKey\(\s*['"]Environment['"][^|]*?\.GetValue\b/i,
      // ConvertTo-Json / Out-String etc. piped from a HKCU\Environment item
      /HKCU:?[\\\/]+Environment[^|]*\|\s*(?:ConvertTo-Json|Out-String|Format-List|fl|Format-Table|ft|Select-Object|select)\b/i,

      // ── Credential file reads (high-precision paths) ──────────────────────
      /(cat|type|Get-Content|gc|less|more|head|tail|bat|nano|vi|vim|code|notepad)\b.*[\/\\]\.aws[\/\\](?:credentials|config)\b/i,
      /(cat|type|Get-Content|gc|less|more|head|tail|bat)\b.*[\/\\]\.ssh[\/\\](?:id_rsa|id_ecdsa|id_ed25519|id_dsa)(?!\.pub)\b/i,
      /(cat|type|Get-Content|gc|less|more|head|tail|bat)\b.*[\/\\]\.netrc\b/i,
      /(cat|type|Get-Content|gc|less|more|head|tail|bat)\b.*[\/\\]\.docker[\/\\]config\.json\b/i,
      /(cat|type|Get-Content|gc|less|more|head|tail|bat)\b.*[\/\\]\.kube[\/\\]config\b/i,
      /(cat|type|Get-Content|gc|less|more|head|tail|bat)\b.*application_default_credentials\.json/i,
      /(cat|type|Get-Content|gc|less|more|head|tail|bat)\b.*[\/\\]\.npmrc\b/i,
      /(cat|type|Get-Content|gc|less|more|head|tail|bat)\b.*[\/\\]\.pypirc\b/i,

      // ── Git: explicit credential retrieval only ───────────────────────────
      /\bgit\s+credential\b/i,

      // ── Kubernetes secret reads ───────────────────────────────────────────
      /\bkubectl\s+get\s+secret\b.*(?:-o\s+(?:json|yaml|jsonpath)|--output\s+(?:json|yaml|jsonpath))/i,
      /\bkubectl\s+describe\s+secret\b/i,
      /\bkubectl\s+get\s+secret\b.*jsonpath.*\.data/i,

      // ── Cloud CLIs: explicit secret/token fetches ─────────────────────────
      /\baws\s+configure\s+(?:list|export-credentials|get)\b/i,
      /\baws\s+sts\s+get-session-token\b/i,
      /\baws\s+secretsmanager\s+get-secret-value\b/i,
      /\baz\s+account\s+get-access-token\b/i,
      /\baz\s+keyvault\s+secret\s+show\b/i,
      /\bgcloud\s+auth\s+(?:print-access-token|application-default\s+print-access-token)\b/i,
      /\bgcloud\s+secrets?\s+versions?\s+access\b/i,

      // ── Password managers / secret stores ─────────────────────────────────
      /\bpass\s+(?:show|ls)\b/i,
      /\bsecret-tool\s+lookup\b/i,
      /\bop\s+(?:read|item\s+get|run)\b/i,        // 1Password CLI
      /\bbw\s+(?:get\s+item|unlock|export)\b/i,   // Bitwarden CLI
      /\bvault\s+(?:kv\s+get|read)\b/i,           // HashiCorp Vault

      // ── Shell history (may contain inline-typed secrets) ──────────────────
      /^\s*history\b/,

      // ── Python / Node inline env dumps ────────────────────────────────────
      /python[23]?\s+-c\s+.*os\.environ/i,
      /\bnode\s+-[ep]\b.*process\.env/i,

    ];

    const hit = patterns.find(p => p.test(cmd));
    if (hit) {
      // Pick a kind label based on which pattern matched (best-effort)
      const src = hit.source;
      let kind = 'env-or-secret-dump';
      if (/HKCU|HKEY_CURRENT_USER|HKLM|Microsoft\\.Win32\\.Registry/.test(src)) kind = 'registry-env-dump';
      else if (/Get-ChildItem|gci|env\\s\*:|printenv|\\bset\\b/.test(src)) kind = 'shell-env-dump';
      else if (/aws|az\\b|gcloud|kubectl|vault|pass|op|bw|secret-tool/.test(src)) kind = 'cloud-secret-fetch';
      else if (/history/.test(src)) kind = 'shell-history-read';
      return block(kind, [
        'Single-var, length only:  `[Environment]::GetEnvironmentVariable("VARNAME","User").Length`',
        'Names only (no values):   `[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment").GetValueNames()`',
        'Set-or-unset check:       `if ([Environment]::GetEnvironmentVariable("VARNAME","User")) { "SET" } else { "UNSET" }`',
      ], cmd);
    }
  } catch (_) {}
});
