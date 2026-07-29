---
name: Credential storage rules
description: Never store secrets in repo root; always use ~/.config/<project>/; never echo or log
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---
Never store API keys, tokens, or secrets in the repo root or any tracked file. Store in `~/.config/<project>/`. Never echo, log, or print secret values.

**Why:** Secrets committed to repos leak permanently even after deletion from history.

**How to apply:** Any file write involving secrets → check it's in `~/.config/` or `.env` (gitignored). If a secret needs to be passed to a program, use env vars directly without printing.
