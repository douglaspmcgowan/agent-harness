---
name: claude-sync
description: Reconcile the shared cross-agent harness, Claude skill projections, ~/.claude global config, sites hub, and sync health. Use when the user says "sync", "claude-sync", "Claude sync", "sync harness", "sync skills", "sync my config", "sync everything", "update my sites hub", "housekeeping", or "check the sync".
---

# /claude-sync — sync & housekeeping

Reconcile the shared harness, Claude projection, product config, and sites hub, then health-check that they agree. Multi-machine setup: a **personal desktop** (user `dougl`, OneDrive cwds, Google Drive at `G:\My Drive`, Berkeley/Metropolis identity) and a **work laptop** (user `<work-user>`, its own vault + working folders). They share selected portable files while machine and product state have separate owners.

## Modes — run ALL parts, or just one

- "sync harness" / "sync skills" / "Claude sync" → **Part 0** only.
- "sync config" / "merge my claude setup" → **Part 1** only.
- "update my sites hub" → **Part 2** only.
- "sync" / "sync everything" / "housekeeping" / "check the sync" → **all parts + Part 3** health check.

State which parts you're running at the start. Each part is independent; do read-only scans first, report, then write.

---

## Part 0 — shared harness and Claude skill projection

### Authority

- Canonical cross-product contracts and personal skills: `C:\Users\dougl\.agents`.
- Claude personal projection: `C:\Users\dougl\.claude\skills`.
- Repository bindings: `<repository>\skills-manifest.json` and `<repository>\.agents\skills`.
- Product settings, hook wiring, sessions, and permissions remain under `.claude`.

Read `C:\Users\dougl\.agents\HARNESS-MAP.md` and `C:\Users\dougl\.agents\SKILL-PORTABILITY-CONTRACT.md`.

1. Enumerate canonical and Claude `SKILL.md` files and reconcile the unique count.
2. Run `skill-audit` over both roots and inspect new or changed packages fully.
3. Run `C:\Users\dougl\.agents\tools\Sync-ClaudeSkills.ps1`. It projects canonical non-`source-command-*` skills by default and writes `C:\Users\dougl\.claude\skill-projection-manifest.json`.
4. Preserve Claude-owned adapters whose content intentionally translates paths, slash-command syntax, tools, or permissions. Record their source and target hashes as reviewed adapters.
5. Never copy a Claude adapter back over the canonical `.agents` workflow.
6. Refresh project bindings with `Sync-ProjectSkills.ps1`, regenerate the Skills Docket outbox, update Setup briefs and the integrity stamp, then run `Test-HarnessSetup.ps1`.

## Machines have diverged — the load-bearing correction (read first)

An earlier model of this skill assumed the machines were symmetric and everything but a short machine-specific list should be unioned. **That is wrong.** Two nominally-"neutral" tracked files are in fact **machine-specific** and must **NEVER be cross-clobbered in either direction**:

- **`settings.json`** — hardcodes **absolute** hook paths per user (`C:/Users/<work-user>/tools/nodejs/node.exe …` on the laptop vs `C:/PROGRA~1/nodejs/node.exe C:/Users/dougl/.claude/hooks/…` on the desktop), and references work-machine-only hooks that are gitignored/absent elsewhere. Importing the other machine's copy **breaks every hook**. Treat it like `mcp.json`.
- **`CLAUDE.md`** — has diverged into two per-machine identities. On the desktop the tracked copy is the laptop's lineage and the personal version rides on top as a **permanent uncommitted working-tree override** (it always shows as `M` — expected, never "drift to fix"). Never push the desktop's up, never pull the repo's down over the override.

**Consequence:** there is **NO wholesale `git merge origin/master`**. The safe automatic move is a **selective, additive push-up via a clone**. Pulling the other machine's improvements DOWN is valuable and is a **separate, flagged pass** (Part 1 step 7) — it needs path rewriting, so get a go-ahead first.

Genuinely machine-**neutral** (safe to share as files): `skills/`, `commands/`, `hooks/*.js` (the code, never its wiring), `keybindings.json`, `scheduled-tasks/`, `projects/*/memory/*.md`, the `CLAUDE-*.md` helper docs, `VERIFY.md`, `reference/`, `tools/`.

---

## Part 1 — Claude config (`~/.claude` ↔ `claude-global-config`)

**Canonical repo:** `github.com/douglaspmcgowan/claude-global-config` (branch **`master`**). `~/.claude` tracks it. Old `claude-config` is **DEPRECATED** — never push there.

1. **Orient precisely.** `git -C ~/.claude remote -v`, `branch --show-current`, `fetch origin`. Then establish position:
   - `git -C ~/.claude rev-list --count HEAD..origin/master` — how far behind
   - `git -C ~/.claude log --oneline origin/master..HEAD` — local-only commits
   - `git -C ~/.claude merge-base --is-ancestor HEAD origin/master` — clean-ancestor test

   A desktop can sit **60+ commits behind with zero local commits**. When that is true, almost every "difference" is staleness rather than divergence — say so before proposing a merge.

2. **Clone the repo fresh** — to a **SHORT base path**, never the session scratchpad. The scratchpad path is ~140 chars; the repo's project-memory dirs add ~150 more, blowing past Windows MAX_PATH (260) and **corrupting the checkout** (git then reports every file as deleted+untracked). Use `~/cgc-sync`:

   ```bash
   cd ~ && git -c core.longpaths=true clone --depth 1 https://github.com/douglaspmcgowan/claude-global-config.git cgc-sync
   cd ~/cgc-sync && git config core.longpaths true
   git status --short | wc -l    # must be 0 before you trust the clone
   ```

   (`gh repo clone` can't pass `-c core.longpaths=true`; use `git clone`. Don't `rm -rf` temp dirs — it prompts; use a fresh unique name.)

3. **Compare filesystem-to-clone, never through the git index.** `git diff origin/master` on `~/.claude` is **misleading**: files present on disk but untracked (pulled down by copy in a past sync) are reported as `D`/deleted. Walk both trees and diff file-by-file instead. Classify:
   - **Machine-NEUTRAL (shareable as files):** `hooks/*.js` (code only), `skills/`, `commands/`, `keybindings.json`, `scheduled-tasks/`, `projects/*/memory/*.md`, `CLAUDE-*.md` helpers, `CODEX-DELEGATION-LOG.md`, `VERIFY.md`, `reference/`, `tools/`.
   - **Machine-SPECIFIC (NEVER cross-clobber):** `settings.json`, `CLAUDE.md`, `mcp.json`, `plugins/installed_plugins.json`, `launch.json`.
   - **Direction test for anything that differs:** `git -C ~/.claude log HEAD..origin/master -- <file>`. Non-empty ⇒ origin moved it since your HEAD ⇒ origin is newer. Empty ⇒ your working copy is the newer superset.

4. **Check for local-only supersets before letting anything be overwritten — especially safety hooks.** A file can be *older* in commit terms and still hold rules the repo lacks, because a later sync from the other machine clobbered them. Verified case: the desktop's `protect-ai-reference.js` carries four off-limits rules where origin's carries two; blindly taking origin would silently delete two protections. Diff every security/guard hook by hand and keep the union. Same for `block-dangerous-bash` (keep **ALL** patterns — OS-catastrophe + git/SQL union, settled 2026-05-23) and secret-name token lists (union them).

5. **Build the additive push-up in the clone.** Copy INTO `~/cgc-sync` only machine-neutral content this machine has that the repo lacks or that is a verified local superset. **Never copy `settings.json` or `CLAUDE.md`.** Then `cd ~/cgc-sync && git status --short` — the delta must be exactly what you intend. Validate any JSON you touched.

   Before adding a local-only file, check it wasn't **deliberately removed or renamed upstream**: `git -C ~/.claude log --oneline --all -- <path>`. Real cases — `commands/tsa.md` was renamed to `docket.md`, and a whole set of files was intentionally scrubbed in `ed86302`. Re-pushing either resurrects deleted content.

6. **Scrub gate (machine-local, before commit):**
   - Read `.claude-sync-exclude` in the repo root — patterns that must NEVER be pushed. Confirm nothing staged matches.
   - Grep your additive content for work-machine tokens (`<work-user>`, agency names, private network hostnames) → must be clean.
   - If `~/.claude/claude-sync-scrub.ps1` exists, run it against the clone **synchronously, never backgrounded** — `& "$HOME/.claude/claude-sync-scrub.ps1" -Repo "$HOME/cgc-sync"`; on nonzero, do **not** commit. On machines without it this is a no-op and the manual grep is the gate. (A backgrounded scrub once raced the foreground run and truncated ~120 files to empty, which shipped in a commit.)

7. **Commit + push.** Set identity in the fresh clone first (it won't inherit global): `git config user.name "$(git -C ~/.claude config user.name)"` and the same for `user.email`. Verify remote+branch, quote them back, `git add -A`, commit, `git push origin master`, confirm with `git ls-remote origin -h refs/heads/master`.

8. **Pull-down (the flagged pass — surface it, get a go-ahead, never automatic).** To bring the other machine's neutral additions here, copy them in additively and **rewrite its absolute paths to this machine's**. Resolve each target on the live machine rather than assuming. The verified desktop table:

   | Laptop path | Desktop equivalent |
   |---|---|
   | `C:/Users/<work-user>/tools/nodejs/node.exe` | `C:/PROGRA~1/nodejs/node.exe` |
   | `C:/Users/<work-user>/tools/nodejs/node_modules` | `C:/Program Files/nodejs/node_modules` |
   | `…/scoop/apps/python313/current/python.exe` | `C:/Users/dougl/AppData/Local/Programs/Python/Python312/python.exe` |
   | `C:/Users/<work-user>/tools/ffmpeg` | the WinGet `Gyan.FFmpeg` package bin |
   | `…/Documents/<vault name>` | the vault with `"open":true` in `%APPDATA%\obsidian\obsidian.json` |
   | `…/Documents/Claude <Org> Folder` (and `Claude <Org2> Folder`) | `C:/Users/dougl/OneDrive/Documents/General Claude` |
   | `…/Documents/Codex <Org> Folder` | `C:/Users/dougl/Documents/Codex` |
   | `C:/Users/<work-user>` (fallback) | `C:/Users/dougl` |

   The concrete, resolved table for this desktop lives in `~/.claude/tools/sync-pulldown-rewrite.js` (dry-run by default, `--apply` to write, `--sample <file>` to preview one rewrite). It is listed in `.claude-sync-exclude` because it holds literal work-machine paths.

   **Order the table most-specific-first and make the separator match the source** (`/`, `\`, `\\`, `\\\\` all occur). The laptop has **no plain `Documents/Claude`** — a naive `Documents/Claude` rule mangles `Documents\Claude <Org> Folder` into a path that doesn't exist. Back up `hooks/`, `commands/`, `skills/`, `tools/` and `settings.json` first, then after copying: grep the result for residual laptop tokens (must be 0), `node --check` every hook, and smoke-test the guard hooks with synthetic payloads. New hooks need a wiring entry in **this** machine's `settings.json` using **this** machine's paths — check first whether they're opt-in gates that are intentionally unwired upstream.

---

## Part 2 — Sites hub (`dpm-sites`)

**Hub:** `dpm-sites.vercel.app` · GitHub `douglaspmcgowan/dpm-sites` (branch **`main`**) · local clone often at `~/dpm-sites`. It holds **no work content**, so this part is safe from any machine. If the clone is absent: `git clone --depth 1 https://github.com/douglaspmcgowan/dpm-sites.git ~/dpm-sites`.

The hub has two halves, and only one of them is mechanical:

1. **`data/project-status.json` — data-driven, safe to refresh.** `scripts/update-project-status.ps1` refreshes each tracked repo's `lastCommit` from GitHub's `pushed_at`, then commits + pushes. **Caveat:** it uses the *unauthenticated* GitHub API, which 404s on private repos. For those, fetch `pushed_at` via authenticated `gh api repos/douglaspmcgowan/<repo> --jq .pushed_at` and edit the JSON directly. Leave `lastCommit: null` for anything that 404s even under `gh`, and say so. Bump `generated` to today. Validate the JSON, then push to `main` (Vercel auto-deploys).

2. **`index.html` + `profile/` — hand-curated editorial copy.** `index.html` carries prose cards and **spelled-out counts** of the harness ("Twenty skills", "Nineteen hooks", "Forty-seven tools", "Seven playbooks"). Those counts drift as the harness grows, and re-spelling them means deciding *which* inventory the hub should feature (desktop / laptop / union) and rewriting cards to match. **Report the drift; do not unilaterally rewrite it during a plain sync.** Offer the editorial refresh as its own task.

Always check `git fetch && git status` first — the clone is often a few commits behind another machine's push, and a fast-forward may be all that's needed.

---

## Part 3 — Sync health check (report-only, PASS/WARN/FAIL)

- **Harness:** `Test-HarnessSetup.ps1` passes; canonical and Claude skill counts reconcile; managed projections match recorded hashes; reviewed Claude adapters have current source and target hashes.
- **Config:** origin = `claude-global-config`, branch = `master`. **Expect a "dirty" working tree and treat it as OK** — the `CLAUDE.md` override (permanent `M`) plus already-pushed-but-locally-untracked files are the known state. FAIL only if origin/branch are wrong or a *neutral* file was clobbered. On machines where `~/.claude` isn't a repo, confirm the last sync's tip via `git ls-remote`.
- **Sites hub:** `main` tip pushed; `data/project-status.json` valid with a current `generated`. Count drift in `index.html` is **WARN** (editorial), never FAIL.
- **Obsidian (optional):** the vault with `"open":true` in `%APPDATA%\obsidian\obsidian.json` matches `CLAUDE.md`; no stray empty dirs (`find "<vault>" -type d -empty -not -path '*/.obsidian*'`).
- Output a checklist; offer to fix any FAIL by running the relevant Part.

---

## Environment gotchas (Windows / Git-Bash)

- **`grep -i` is broken** in this Git-Bash build — it returns empty or aborts, so a case-insensitive scan silently reports "everything is missing." Use case-sensitive matching in scan scripts.
- Long paths need `core.longpaths` on **both** the clone command and the resulting repo config.
- Guard hooks match on **command text**, so a scan script that merely *mentions* a protected string gets blocked. Put test payloads and substitution tables in a script file and run the file.

## Runtime junk to EXCLUDE (the master `.gitignore`)

`.credentials.json`, `mcp-needs-auth-cache.json`, `.last-update-result.json`, `history.jsonl`, `stats-cache.json`, `sessions-map.md`, `.last-cleanup`, `chrome/`, `cache/`, `paste-cache/`, `shell-snapshots/`, `file-history/`, `telemetry/`, `debug/`, `backups/`, `_backups/`, `sessions/`, `session-env/`, `tasks/`, `todos/`, `plans/`, `ide/`, `plugins/{cache,data,marketplaces}/`, `plugins/install-counts-cache.json`, `plugins/known_marketplaces.json`, `projects/**/*.jsonl`, `projects/*/<uuid>/`. Machine-specific (per-machine): `mcp.json`, `plugins/installed_plugins.json`, `launch.json`. The repo also carries `.gitleaks.toml` + `.claude-sync-exclude` — read the latter before every push.

## Safety

- **No wholesale `git merge origin/master` on `~/.claude`** — it imports the other machine's `settings.json`/`CLAUDE.md` and breaks hooks. Push additively via the clone; pull down only via the flagged pass.
- Never `git reset --hard` / blind `git checkout -- .` on the live `~/.claude`. (Also blocked by `block-dangerous-bash.js`.)
- Never echo/commit secrets — `mcp.json`/`settings.json` may hold an `env` block; inspect masked.
- **Scrub gate runs synchronously**, never backgrounded.
- Read-only scan + report before any write. Report resolved deltas at the end so the user can object.
