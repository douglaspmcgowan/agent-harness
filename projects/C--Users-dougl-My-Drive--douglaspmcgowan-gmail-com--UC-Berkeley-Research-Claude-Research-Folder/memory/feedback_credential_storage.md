---
name: Credential storage discipline
description: Credentials/keys/secrets go in `~/.config/<project>/` — never in repo root. Verify destination is gitignored before write. Never echo, log, or print secret contents.
type: feedback
originSessionId: d88c6f87-874b-4584-b684-02b172df87fd
---

Credentials, API keys, OAuth secrets, tokens, and passwords:

1. **Storage location.** Default to `~/.config/<project-name>/` (e.g. `~/.config/psych-battery/credentials.json`). Never write to a project root unless the file is **already** in `.gitignore` — verify with `git check-ignore <path>` before writing. If `git check-ignore` returns nothing or non-zero, the file is NOT ignored and you must not write the secret there.

2. **Never echo, print, log, or display contents.** Not partial (no first-3-chars, last-4-chars, length, or prefix). Pass env vars directly to processes that need them. To refresh a cached env var: `unset VAR && export VAR=$(<source>)` without printing the result.

3. **If the user pastes a secret into chat:** do NOT repeat it back. Tell them: "I won't echo that — please rotate it now since it's in the chat history." Treat any leaked secret as compromised regardless of where it appeared.

4. **For OAuth client secrets, GitHub PATs, and API keys discovered in unexpected files:** flag for rotation. Don't move them silently — tell the user the file location, the type of secret detected, and recommend rotation at the issuer (e.g. console.cloud.google.com for GCP OAuth, github.com/settings/tokens for PATs).

**Why:**

- Session `d88c6f87` (2026-04-29): Google Calendar OAuth credentials were saved to `mccomb-talks/` (an unrelated project dir) instead of `~/.config/psych-battery/`. One `git add .` away from leak.
- Session `80a82dfa` (2026-05-01): a GitHub PAT was pasted directly into chat by the user. The token was active and uncovered.
- TECH_DEBT_AUDIT 2026-05-04 finding F01: production OAuth `client_secret` lived at `psych-battery/credentials.json` (since moved). The risk pattern repeats across projects without a rule.

**Trigger:** Any file write involving paths/names matching `*.env`, `credentials*`, `*_token*`, `*_secret*`, `*_key*`, `oauth*`, `service-account*`, `*.pem`, `*.key`. Any chat message containing strings matching common secret prefixes (`sk-`, `gh[ps]_`, `GOCSPX-`, `xoxb-`, `AKIA`, etc.).

**Verification:** After any credential-related change, run `git status` and confirm no credential file is staged. Run `git log --all -p -- <credfile>` to confirm it has never been committed.

**Do not write real secrets in this file or any memory file.** All examples above use synthetic placeholders only.
