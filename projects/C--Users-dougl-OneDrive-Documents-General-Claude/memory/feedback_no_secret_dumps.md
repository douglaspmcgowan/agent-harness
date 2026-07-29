---
name: feedback-no-secret-dumps
description: Never dump env vars or read .env/secret files into the transcript; enforced by the block-secret-dump hook
metadata:
  node_type: memory
  type: feedback
  originSessionId: f349200a-6aec-4821-a203-becf0bc73a59
---

NEVER run commands that print the environment or read secret files — `env`,
`printenv`, bare `export`/`set`, `export $(...)`, `cat/grep/sed .env*`,
`gci env:`, `[Environment]::GetEnvironmentVariables()`, `echo $SECRET`,
`$env:SECRET`. Pass secrets straight to the program that needs them (it inherits
the environment). Refresh one var without printing: `unset VAR && export VAR=$(source-that-emits-only-that-value)`.

**Why:** On 2026-06-21 a security-audit sub-agent's misfired `export $(grep ... .env ...)`
dumped live secrets (GITHUB_PAT, OPENAI_API_KEY, GOOGLE_OAUTH_CLIENT_SECRET,
AMAX_ELITE_PASSWORD, SUPABASE_ACCESS_TOKEN) into its transcript. Douglas was
(rightly) furious — a memory _rule_ existed but nothing _enforced_ it.

**How to apply:** This is now enforced by a hook, not just a rule —
`hooks/block-secret-dump.js` hard-blocks (exit 2, works in sub-agents) these
patterns for Bash AND PowerShell, wired in `settings.json` PreToolUse; the
PostToolUse `scan-output-for-secrets.js` scrubber is the backstop (now also
runs on PowerShell). 46/46 block/allow unit cases pass; templates like
`.env.example` are allowed. Do NOT disable these hooks. Tell sub-agents the same.
Committed to claude-global-config (commit 9beba53). See [[feedback-credential-storage]].
