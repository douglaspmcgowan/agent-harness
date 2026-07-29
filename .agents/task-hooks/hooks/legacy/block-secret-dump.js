#!/usr/bin/env node
// PreToolUse hook (Bash + PowerShell). HARD-BLOCKS (exit 2) commands that would
// dump environment variables or read secret-bearing files into the transcript.
//
// Why exit 2 and not "ask": an "ask" decision does nothing in an autonomous
// sub-agent / workflow run — which is exactly where a misfired `export $(grep
// ... .env ...)` leaked live secrets on 2026-06-21. A hard block stops the
// command before it runs, for the main loop AND sub-agents alike.
//
// Tune patterns to avoid false positives on everyday dev commands:
//   allowed: `printenv PATH`, `echo $HOME`, `env FOO=bar node`, `grep x src.ts`,
//            `cat package.json`, `export FOO=$(cmd)`, `$env:PATH`
//   blocked: `env`, `printenv`, bare `export`/`set`, `export -p`,
//            `export $(...)`, any read tool on `.env*`/creds/keys,
//            `echo $OPENAI_API_KEY`, `printenv GITHUB_PAT`,
//            `gci env:`, `[Environment]::GetEnvironmentVariables()`,
//            `Get-Content .env`, `Write-Host $env:SUPABASE_ACCESS_TOKEN`

const fs = require("fs");
const path = require("path");
const { allowsSecret } = require(path.join(__dirname, "allow-tags"));

let cmd = "";
let input = null;
try {
  input = JSON.parse(fs.readFileSync(0, "utf8"));
  cmd = (input && input.tool_input && input.tool_input.command) || "";
} catch {
  process.exit(0);
}
if (!cmd) process.exit(0);

// Escape hatch: if the user's current prompt carries [allow-secret] / [allow-all], let this one
// command through (see allow-tags.js). Lets a specific false positive proceed without disabling
// the whole hook. Fails closed — no tag, or any transcript-read error, means the block stands.
if (allowsSecret(input)) process.exit(0);

// Secret-ish env-var name alphabet (used in several patterns).
const SECRET =
  "(?:[A-Z0-9_]*(?:SECRET|TOKEN|API[_-]?KEY|APIKEY|PASSWORD|PASSWD|PRIVATE[_-]?KEY|ACCESS[_-]?KEY|CLIENT[_-]?SECRET|CREDENTIAL|BEARER)[A-Z0-9_]*|[A-Z0-9_]*_PAT\\b|OPENAI[A-Z0-9_]*|ANTHROPIC[A-Z0-9_]*|CLAUDE[A-Z0-9_]*|GITHUB[A-Z0-9_]*|GH_(?:TOKEN|PAT)|AWS_[A-Z0-9_]*|AZURE[A-Z0-9_]*|GOOGLE[A-Z0-9_]*|GCP[A-Z0-9_]*|GCLOUD[A-Z0-9_]*|FIREBASE[A-Z0-9_]*|STRIPE[A-Z0-9_]*|SLACK[A-Z0-9_]*|DISCORD[A-Z0-9_]*|TWILIO[A-Z0-9_]*|SENDGRID[A-Z0-9_]*|MAILGUN[A-Z0-9_]*|RESEND[A-Z0-9_]*|VERCEL[A-Z0-9_]*|NETLIFY[A-Z0-9_]*|SUPABASE[A-Z0-9_]*|FIREWORKS[A-Z0-9_]*|OPENROUTER[A-Z0-9_]*|GROQ[A-Z0-9_]*|REPLICATE[A-Z0-9_]*|HUGGINGFACE[A-Z0-9_]*|HF_[A-Z0-9_]*|COHERE[A-Z0-9_]*|MISTRAL[A-Z0-9_]*|DEEPSEEK[A-Z0-9_]*|NOTION[A-Z0-9_]*|CLOUDFLARE[A-Z0-9_]*|NPM_TOKEN|PYPI[A-Z0-9_]*|DOCKER[A-Z0-9_]*|SENTRY[A-Z0-9_]*|DATADOG[A-Z0-9_]*)";

// Read/dump tools that put a file's contents into output.
const READ =
  "(?:cat|bat|tac|nl|head|tail|less|more|view|strings|xxd|od|hexdump|base64|tee|grep|egrep|fgrep|rg|ag|sed|awk|gawk|cut|tr|sort|uniq|jq|yq|Get-Content|gc|type)";
// Secret-bearing file names (dotenv handled separately by readsDotenv()).
const SECRET_FILE =
  "(?:\\.envrc|credentials(?:\\.[A-Za-z0-9]+)?|secrets?\\.(?:json|ya?ml|env|txt)|id_rsa|id_ed25519|id_dsa|\\.pem|\\.p12|\\.pfx|\\.netrc|\\.npmrc|\\.pgpass|\\.git-credentials|service[_-]?account[A-Za-z0-9._-]*\\.json|\\.ssh[\\/\\\\]id_)";

// True if the command reads a real .env* file (not a committed template like
// .env.example / .env.local.example). Template files hold placeholders, not
// secrets, so they're safe to read.
const TEMPLATE_SEG = new Set([
  "example",
  "sample",
  "template",
  "tpl",
  "dist",
  "default",
  "defaults",
  "md",
]);
function readsDotenv(cmd) {
  if (!new RegExp("\\b" + READ + "\\b", "i").test(cmd)) return false;
  const re = /\.env(?:\.[A-Za-z0-9_-]+)*/gi;
  let m;
  while ((m = re.exec(cmd))) {
    const after = cmd[m.index + m[0].length] || "";
    if (/[A-Za-z0-9_]/.test(after)) continue; // e.g. ".environment" — not a dotenv file
    const lastSeg = m[0].split(".").pop().toLowerCase();
    if (TEMPLATE_SEG.has(lastSeg)) continue; // committed template — safe
    return true;
  }
  return false;
}

const RULES = [
  // ── full environment dumps ──
  [
    /(?:^|[;&|`(]|\bsudo\b)\s*(?:env|printenv)\s*(?:$|[|>&;`)])/i,
    "dumps all environment variables (env/printenv)",
  ],
  [/\bexport\s+-p\b/i, "prints all exported variables (export -p)"],
  [
    /(?:^|[;&|`(])\s*export\s*(?:$|[|>`)])/i,
    "bare export prints all exported variables",
  ],
  [/(?:^|[;&|`(])\s*set\s*(?:$|\|)/i, "bare set dumps all shell variables"],
  // ── dynamic export / substitution of env or secret files ──
  [
    /\bexport\s+["']?\$[({]/i,
    "export $(...) dynamically exports captured output — leaks if it errors",
  ],
  [
    new RegExp("(?:\\$\\(|`)[^)`]*\\b(?:printenv|env)\\b", "i"),
    "command substitution captures the environment",
  ],
  // ── reading secret files with a dump tool ──
  [
    new RegExp(
      "\\b" + READ + "\\b[^\\n]*(?:^|[\\s/'\"=([:])" + SECRET_FILE,
      "i",
    ),
    "reads a secret/.env file — its contents would land in the transcript",
  ],
  // ── echoing / printing a named secret ──
  [
    new RegExp(
      "\\b(?:echo|printf|print|Write-Output|Write-Host|Write-Information)\\b[^\\n]*\\$\\{?" +
        SECRET,
      "i",
    ),
    "echoes a secret environment variable",
  ],
  [
    new RegExp("\\b(?:printenv|env)\\s+\\$?\\{?" + SECRET, "i"),
    "prints a named secret environment variable",
  ],
  // ── PowerShell env exposure ──
  [
    /\b(?:Get-ChildItem|gci|ls|dir|Get-Item|gi)\b[^\n]*\benv:\s*(?:\*|\$|$|\||>)/i,
    "enumerates the PowerShell env: drive (all env vars)",
  ],
  [
    /\[(?:System\.)?Environment\]::GetEnvironmentVariables\b/i,
    "[Environment]::GetEnvironmentVariables() returns the whole environment",
  ],
  [
    new RegExp("\\$env:" + SECRET, "i"),
    "references a secret PowerShell env var on the command line (it prints)",
  ],
];

function block(reason) {
  console.error(
    `BLOCKED — this command would leak secrets into the transcript: ${reason}.\n` +
      `Command: ${cmd.slice(0, 160)}\n` +
      `Pass secrets straight to the program that needs them (they inherit the environment); ` +
      `never print, cat, grep, or export the environment or a .env file. ` +
      `To refresh one var without printing: unset VAR && export VAR=$(source-that-emits-only-that-value).`,
  );
  process.exit(2);
}

if (readsDotenv(cmd)) {
  block(
    "reads a real .env secret file — its contents would land in the transcript",
  );
}
for (const [re, reason] of RULES) {
  if (re.test(cmd)) block(reason);
}
process.exit(0);
