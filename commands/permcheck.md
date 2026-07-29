---
name: permcheck
description: "Simulates a command (or the last N prompted commands from this session's transcript) against the merged permission layers — user settings.json, project settings.json, .claude/settings.local.json allow/deny/ask lists, plus the built-in read-only fast-path, the wrapper/env-prefix stripping Claude Code applies before matching, the separate runtime autoMode.allow classifier, the workspace-trust gate, and the .claude sensitive-file gate — with real glob and word-boundary matching semantics (each subcommand of a compound matched independently), and reports a layer-aware verdict per command: which rule matched, or exactly why it near-missed (an unmatched subcommand in a compound, a wrapper/env prefix that should have stripped, a word-boundary or arg-shape mismatch, autoMode classifier scope, untrusted workspace, sensitive-file gate). Proposes the minimal correctly-shaped rule plus the canonicalized command form, hands additions to /fewer-permission-prompts to apply, and verifies by replaying the harvested commands through the simulator and asserting zero residual prompts. Use when Douglas says 'permcheck', 'why did this prompt me', 'simulate this permission', 'would this command need approval', '/permcheck <command>'."
---

# /permcheck [command-string] [--last N]

A permission dialog firing is a symptom. `permcheck` answers the actual question — which layer would
fire, on what rule, and what's the smallest correctly-shaped allow entry that closes it — instead of
guessing at a wildcard and hoping.

## The gate stack

Sources: the official permissions reference (`https://code.claude.com/docs/en/permissions`, fetched 2026-07-22 — the
authoritative matcher spec) and `reference_automode_classifier_permission_dialogs.md` (Douglas's local finding — read
it before running if present). A Bash command runs, prompts, or is blocked by walking these in order; a static
`permissions.allow` entry only touches one of them.

0. **Built-in read-only fast-path.** `ls cat echo pwd head tail grep find wc which diff stat du cd` and read-only
   `git` forms run without a prompt in *every* mode — no rule needed. A command that resolves to these is MATCHED
   here and never reaches the rest of the stack. (Unquoted globs are allowed only when every flag is read-only;
   `find`, `sort`, `sed`, and `git` still prompt on a bare glob since it could expand to a flag like `-delete`.)
1. **`permissions.allow`/`deny`/`ask`** — merged across `~/.claude/settings.json` (user), project
   `.claude/settings.json`, and `.claude/settings.local.json` (local overrides project overrides user; a managed
   policy overrides all). Evaluated **deny → ask → allow, first match wins — specificity is irrelevant.** Patterns
   are `*`-globs anchored at the command start, with a word-boundary rule at a trailing space (see step 3).
2. **`autoMode.allow` classifier** — when auto mode is on, a Sonnet-class classifier judges each non-read-only
   command against what was actually asked. Two facts change the fix here: (a) entering auto mode **drops** any
   allow rule that grants arbitrary code execution — blanket `Bash(*)`/`PowerShell(*)`, wildcarded interpreters
   (`python`/`node`/`ruby`), package-manager `run` — so a broad rule is silently inert and the command hits the
   classifier anyway (this is Douglas's live case: his allowlist *is* `Bash(*)`); (b) a repo can't grant itself
   `autoMode` scope through its own committed settings. The fix is a specific plain-language `autoMode.allow`
   exception, never a broader `permissions.allow` wildcard (a sweeping wildcard attempt was itself blocked as
   exceeding what was authorized). Explicit allow/deny resolve *before* the classifier, so a *specific* allow
   short-circuits it while a dropped broad one does not.
3. **Sensitive-file / protected-path gate** — fires on any path containing `.claude/`, runs BEFORE the allowlist
   is consulted, and no allow rule suppresses it. The dialog text says "which is a sensitive file" — that phrase is
   the tell. Fix is relocating the path out of `.claude/`. (Related built-in: `bypassPermissions` mode still guards
   writes into `.git`, `.config/git`, `.vscode`, `.idea`, `.husky`, `.cargo`, `.devcontainer`, `.yarn`, `.mvn` —
   treat any of these as protected too.)
4. **Workspace trust** — a project `.claude/settings.json` `allow` rule is read but *not applied* until the
   workspace-trust dialog is accepted for that repo root. An allow entry that is present yet still prompting often
   means the workspace was never trusted; `deny`/`ask` rules are unaffected.

## Procedure

### 1. Resolve input

- Explicit `[command-string]` → simulate that one command.
- `--last N` (default 10 if neither given) → harvest the last N Bash/PowerShell commands this session
  actually got prompted for or ran, from the visible transcript. Don't invent commands that weren't run.

### 2. Load the merged layers

Read, in precedence order (later overrides earlier on conflicting patterns, both apply on non-conflicting):
`~/.claude/settings.json` → project `.claude/settings.json` → project `.claude/settings.local.json`.
Extract `permissions.allow`/`deny`/`ask` arrays and the top-level `autoMode.allow` array from each.

### 3. Simulate each command against real matching semantics

For each command, in order:

1. **Canonicalize first — strip the wrappers Claude Code strips before matching.** These run their
   argument as the real command, so a rule for the inner command already covers them: `timeout`, `time`,
   `nice`, `nohup`, `stdbuf`, the builtins `command` and `builtin`, zsh's `noglob`, a leading assignment of
   a *known-safe* env var (`NODE_ENV=test npm test` → `npm test`), and flag-less `xargs`. So `timeout 30
   npm test` matches a `Bash(npm test *)` rule. Do NOT strip environment runners — `devbox run`, `npx`,
   `docker exec`, `direnv exec`, `mise exec` execute their tail, so a rule must name runner + inner command
   (`Bash(devbox run npm test)`); a bare `Bash(devbox run *)` is dangerously broad. `xargs` with flags
   (`xargs -n1 grep`) is matched as `xargs`, not stripped. `watch`/`setsid`/`ionice`/`flock` and `find
   -exec`/`-delete` always prompt and can't be prefix-approved — only an exact-match rule covers them. For
   deny/ask matching, a leading assignment of *any* variable is stripped, so `Bash(rm *)` in deny still
   catches `FOO=bar rm -rf tmp/`.
2. **Sensitive-file gate.** Does the raw command touch a path containing `.claude/` (a write, or a
   Read/Grep arg)? If yes: verdict = BLOCKED, layer = sensitive-file-gate, only a path relocation fixes it.
   Stop here for this command.
3. **Read-only fast-path.** After stripping, if every subcommand is in the built-in read-only set
   (`ls cat echo pwd head tail grep find wc which diff stat du cd` + read-only `git`) and any glob is
   flag-safe, verdict = MATCHED (read-only) — no rule needed, in any mode. Stop.
4. **Split into subcommands and match each INDEPENDENTLY.** Separators are `&&`, `||`, `;`, `|`, `|&`,
   `&`, and newlines. Claude Code matches *each* subcommand against the merged rules; the compound is
   allowed only when every subcommand matches (a read-only subcommand qualifies on its own). There is no
   whole-string match and no first-token-only bypass — a chain of one allowed and one unallowed command
   prompts. Per subcommand, evaluate **deny → ask → allow, first match wins**; a deny match is terminal
   (report MATCHED-DENY).
5. **Per-subcommand pattern shape.** Rules are `*`-globs anchored at the command start, not literal
   prefixes. A `*` matches any run of characters including spaces and can sit at any position. A space
   before a trailing `*` (or the equivalent `:*` suffix) forces a word boundary: `Bash(ls *)` matches
   `ls -la` but not `lsof`, while `Bash(ls*)` matches both. `:*` is honored only at the very end;
   `Bash(git:* push)` treats the colon as a literal and matches nothing. A field-form like
   `Bash(command:rm *)` is ignored with a startup warning — Claude Code canonicalizes the command itself.
   Note the near-miss when nothing matches:
   - **unmatched subcommand** — one clause of a compound has no rule; the whole compound prompts even
     though the others are allowed.
   - **word-boundary / arg shape** — right verb, but the pattern's boundary or flag order doesn't line up
     (`Bash(ls *)` vs `lsof`), or an argument-constraining pattern misses a variant (`Bash(curl http://x/ *)`
     won't match `-X` before the URL, `https`, a redirect, `URL=… && curl $URL`, or an extra space).
   - **runner tail uncovered** — `devbox run …`/`npx …` with no runner + inner-command rule.
   - **cd caveats** — `cd` into a working-dir path is read-only, so `cd sub && ls` runs; but `cd` into a
     *different* dir combined with `git` prompts (a new dir's hooks could run), and `cd` plus an output
     redirect prompts unless the only redirect target is `/dev/null`.
6. **`autoMode.allow` check** — if auto mode is active, note whether the command's intent (not just its
   text) falls inside an existing `autoMode.allow` exception, or would trip the classifier as going beyond
   what was asked (out-of-scope files, or a broad code-exec rule that auto mode drops so the command reaches
   the classifier despite the allowlist).

### 4. Verdict per command

For each: **MATCHED** (which layer, which exact rule) / **BLOCKED — sensitive-file-gate** / **NEAR-MISS**
(which layer, which specific reason from the list above) / **NO RULE — would prompt**.

### 5. Propose the minimal fix

For every non-MATCHED command: the smallest correctly-shaped `permissions.allow` entry, one per unmatched
subcommand (canonicalize first — drop stripped wrappers and working-dir `cd` clauses, which need no rule,
then widen to the stable verb + flag prefix rather than the whole literal string) OR, if the real blocker is
`autoMode.allow`, the specific plain-language exception line instead of a wildcard OR, if it's the
sensitive-file gate, the path relocation. Never propose `Bash(*)` or an equivalently broad wildcard as the fix.

### 6. Hand off, don't self-apply broadly

`/fewer-permission-prompts` already scans transcripts and writes a prioritized allowlist to project
`settings.json` — hand the proposed entries to it (or apply them directly to the correct settings file if
Douglas says to) rather than duplicating its write logic here.

### 7. Verify

Re-simulate every harvested command against the settings state INCLUDING the proposed additions. Report
before/after counts: N commands would have prompted before, M would prompt after. Zero residual is the
target; if any remain, say which and why (usually the sensitive-file gate, which no rule closes).

## Report

- Per-command verdict table (command, layer, matched-rule-or-near-miss-reason).
- Proposed rule additions, grouped by which settings file they belong in.
- Before/after prompt count from the replay.
- Full path of any settings file changed, tagged UPDATED with what changed.

## Safety constraints

- **Never propose or apply `Bash(*)`/`PowerShell(*)` or any settings-wide wildcard.** Every proposed rule is
  scoped to the actual verb/prefix observed; a wildcard defeats the purpose of the check.
- **Never edit settings.json to bypass or weaken `deny` entries.** A `deny` match is a deliberate block —
  report it as MATCHED-DENY, never propose removing it.
- **Read-only simulation by default.** Only write to a settings file when Douglas explicitly says to apply
  the fix, or when handing off to `/fewer-permission-prompts` which he separately invokes.
- **Never run with elevated or bypass permissions, and never use `--dangerously-skip-permissions`** to test
  whether a command would prompt — that answers a different question than what the real gate does.
- **Don't harvest or replay commands outside this session's own transcript** — no scanning other users'
  sessions or global logs without being asked.

---

*Tracked copy: also save this file to `claude-global-config/commands/permcheck.md` (per the skills-are-tracked
convention) after a NASA scrub. The matching semantics here are pinned to `https://code.claude.com/docs/en/permissions`
(re-verified 2026-07-22 via `/ultraskill improve permcheck`); re-fetch that page and re-run the improve pass when
Claude Code's matcher or auto-mode classifier behavior changes.*
