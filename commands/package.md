---
name: package
description: "Turn one of Douglas's systems into a portable, self-contained repo he can clone and run FULLY on another device. Codifies his real cad-forge bundling pattern: fresh-init (or history-preserving filter-repo split) a project out of its parent monorepo into ONE repo = the whole project + the scrubbed harness copied inside (harness/ subdir) + a RESUME.md, gated on a mandatory sensitive-content + already-portable + history-vs-fresh-init classification, then a careful .gitignore ALLOWLIST decided by whether each item is needed to run and cheaply re-obtainable on the target (size alone never decides): exclude only what the app doesn't need to run OR the target can cheaply re-create — caches, venvs, huge intermediates; KEEP anything needed to boot that the target can't easily re-fetch, even when large, shipping it via Git LFS; wheelhouse hinges on whether the target is offline/air-gapped [keep it if so, since uv sync can't re-download], datasets are keepers if the app loads them to run — verified with `git check-ignore` BOTH directions, secret hygiene via git's own --exclude-standard + a post-stage name-scan that must come back CLEAN (metadata-only probes so the secret hooks don't trip), device de-coupling (de-hardcode C:\\Users paths to Path(__file__)/env, pin deps via uv.lock + .python-version, .env.example, .gitattributes, README quickstart whose bootstrap is `uv sync`), a local commit on a clean tree, and a PROOF-of-portability clean-clone-into-a-fresh-temp-dir-and-run — then STOPS at the local commit and hands back a one-command `gh repo create && git push` finish, because the remote push is ALWAYS held for Douglas's explicit NASA-content-to-remote compliance call. Never claims 'fully portable' unless the clean clone actually ran. Has TWO modes decided by the gate: CREATE (no packaged repo yet — the full extraction above) and UPDATE (a previously-packaged standalone repo already exists — audit its packaging for drift since last time [new source files, new bulk the allowlist doesn't catch, new secrets, newly-introduced hardcoded paths, changed deps, stale harness snapshot], sync only the delta into the existing repo, re-verify the allowlist both directions, make an INCREMENTAL commit instead of a fresh init, and re-prove by clean-clone) — so re-running /package on an already-packaged system refreshes it rather than rebuilding it. Use when Douglas says 'package this', 'package it up', 'make this portable', 'turn X into a standalone/self-contained repo', 'bundle X into a portable repo', 'so I can run it on another device/machine', 'make a pullable resume repo', 'update the package', 'refresh the packaged repo', 're-package X', 'the standalone repo already exists, update it', '/package'."
---

# /package [target]

Portability is a claim proven only by cloning the system onto a bare machine and running it. A repo "should run on another machine" until a hardcoded
`C:\Users\dmcgowa2` path, a dependency that was only ever `pip install`ed by hand, a data file that lived
outside the tree, or a secret that never should have shipped proves it doesn't — on the other device, where
fixing it is most expensive. This command does not assume a system is portable because it was tidied. It
extracts the system into ONE self-contained repo, de-couples it from this specific machine, draws a careful
`.gitignore` allowlist and verifies it both directions, keeps secrets out by construction and checks that
they stayed out, and then PROVES the result by cloning it into a fresh directory that has none of this
machine's state and running it. What clones-and-runs is reported as portable this pass; the remote push that
publishes it is always handed back for Douglas to run himself.

## What this is NOT

- **Not `/claude-sync`.** `/claude-sync` reconciles `~/.claude` (the harness itself — hooks, commands,
  memory, settings) with the `claude-global-config` repo, bidirectionally, as ongoing housekeeping across
  devices. `/package` extracts a *project/system* (cad-forge, text-to-truss, top-op, a viewer) into its own
  standalone repo — and the harness only appears here as a *scrubbed snapshot copied INTO* that repo's
  `harness/` subdir so the project can resume on another machine, not as the thing being synced. Different
  subject (a project vs. the harness), different direction (produce a new repo vs. reconcile two existing
  trees).
- **Not `/handoff` or `/save-context`.** Those persist SESSION state (CURRENT-TASK / STATUS / LOG) so the
  *next session* on *this machine* can resume. `/package` produces a clone-and-run REPO so *another device*
  can run the whole system. A RESUME.md is part of `/package`'s output, but it points a fresh harness at a
  self-contained repo, not a session at its own prior context.
- **Not `/consolidate`.** That merges and de-duplicates documentation/notes into one coherent doc. `/package`
  moves runnable code + its minimal data into a repo that boots on a bare machine.
- **Not `/engineer` (+codegraph).** `/engineer` stands up harness tooling (Serena, task-state, hooks) *inside*
  an existing repo to work on it here. `/package` makes an existing project self-contained and proves it runs
  elsewhere.
- **Not `/make-cli` / `/make-mcp`.** Those build a NEW surface (a CLI, an MCP server) for a system. `/package`
  ships the system you already have, as-is, portably — it doesn't add a new interface.
- **Part of `/app-verification-chain`.** `/package` is Step 6 (the final gate) of that whole-app gauntlet, where
  the clean-clone-and-boot proof plus the recoverability check close out an app that has already passed spec,
  build, smoke, independent test, attack, and structural-guard gates. Run `/package` standalone to make one
  project portable; run `/app-verification-chain` when the whole point is shipping an app proven end-to-end.
- **Not a project scaffolder / cookiecutter.** Those start a NEW project from a template. `/package` extracts
  and de-couples code that already exists and is entangled with this machine — the hard part is the removal
  (of coupling, of bulk, of secrets), not the scaffolding.

## Procedure

### Step 0 — Resolve TARGET from ARGUMENTS

Needs enough that a subagent with ZERO conversation context could act alone: WHICH system (the path to the
subfolder/project), WHERE its git boundary is (is it its own repo already, or nested inside a parent repo's
root — cad-forge was nested inside the `Claude NASA Folder` git root, which is why "one repo" meant a fresh
init at the subdir), HOW it is run (the real entry point / command a user on another device would type), and
whether its git HISTORY is worth preserving in the new repo. If ARGUMENTS lacks these and they aren't obvious
from the conversation, ask which system, where it lives, and how it runs — don't guess at a runnable target.

### Step 1 — The classification gate (mandatory, BEFORE any extraction or mutation)

This gate mirrors `/hone`'s and `/probe`'s Step-2 gates: settle the questions that decide whether the
expensive work should run at all, and how, BEFORE doing it. Each is a real fork in the workflow.

0. **CREATE vs. UPDATE — does a packaged repo already exist for this target?** Before deciding how to
   extract, decide whether there's anything to extract at all. If a previously-`/package`d standalone repo for
   this system already exists — Douglas points at it, or the survey finds a sibling/known repo with the
   telltale shape (its own `.git`, **zero remotes**, a `RESUME.md`, and the `.gitignore` allowlist this command
   writes) — the mode is **UPDATE**, not create. In UPDATE mode you do NOT fresh-init or re-extract; you audit
   the existing package for drift against the current source and sync only the delta (see the **Update mode**
   section below). Otherwise the mode is **CREATE** and Steps 2–8 run in full. State which mode fired.
1. **Sensitive-content call — Douglas's to make.** Before anything leaves its current home, establish what
   in this system genuinely cannot be committed to a repo that may later be pushed. Douglas's own framing is
   the anchor: *"I built this whole thing without using NASA data, I just have it connected to my computer —
   what is actually sensitive info that is on there?"* The answer is usually **narrow** (the API-key file, any
   `.env`/`*.local.*`/credential file, any genuinely NASA-internal/CUI/ITAR data or endpoint config) and is
   handled by the allowlist in Step 3 — NOT the whole project. But if the survey turns up anything whose
   sensitivity is a **judgment call** (real NASA data mixed into the tree, an internal dataset, an endpoint
   that shouldn't be documented), STOP and surface it to Douglas with `AskUserQuestion` — do not decide on his
   behalf what is safe to package. This is the one gate condition that can halt the whole run.
2. **Already portable?** If the target is already its own repo with pinned dependencies (a committed lockfile
   or pinned `requirements`), an `.env.example`, a README quickstart, and no hardcoded machine paths — it may
   already be portable. Don't re-package it; jump to Step 7 (clean-clone-and-run) to VERIFY the claim, and
   report either "already portable, verified" or the specific gap that's missing. Re-bundling a repo that
   already boots elsewhere is wasted work.
3. **History-preserving split vs. fresh init.** Two real approaches, pick by whether the commit history
   matters on the other device:
   - **Fresh `git init` + single commit** — Douglas's actual cad-forge practice. Use when the target is
     nested in a parent repo and its standalone history isn't valuable (963 files, one clean commit, done).
     Simplest; no history carried.
   - **History-preserving `git filter-repo --subdirectory-filter <subdir>`** (run on a FRESH throwaway clone,
     never the working tree — it rewrites destructively) — use when the subdir's own commit history is worth
     keeping. Watch the documented pitfall: if the folder was ever renamed/moved, a single
     `--subdirectory-filter` truncates history at the move; pass every historical path + `--path-rename` to
     keep it whole.

State the mode (create/update), which conditions fired, and the chosen approach before proceeding. If the
sensitive-content condition halts the run, that IS the finding — report it and stop.

### Update mode — refresh an existing package instead of rebuilding it

When Step 1's condition 0 fires UPDATE, the packaged repo already exists and the job is to bring it back in
sync with the source, minimally. Steps 2–4 still apply, but as a **drift audit against the existing repo**
rather than a from-scratch extraction, and Step 6 becomes an **incremental commit into the existing repo**
instead of a fresh init:

- **Audit the drift.** Compare the current source project against what's in the packaged repo and find only
  what changed: (a) new/changed source files that should be synced in (respecting the existing allowlist);
  (b) **new bulk** that appeared since last package and the allowlist doesn't yet exclude (a new `runs/` subdir,
  a new dataset — re-survey sizes per Step 2); (c) **new secrets/credential files** introduced since, which the
  allowlist must still catch (re-run the Step 4 name-scan — a secret added after the last package is exactly
  what this catches); (d) **newly-introduced hardcoded `C:\Users\dmcgowa2` paths** in changed code (de-hardcode
  per Step 3); (e) **dependency changes** (re-pin `uv.lock` / `requirements.txt`); (f) a **stale harness
  snapshot** or `RESUME.md` (re-scrub and refresh `harness/` + `RESUME.md` per Step 5).
- **Apply only the delta** into the existing repo — copy the changed keepers in, update `.gitignore` if new
  bulk/secrets appeared, re-pin deps, refresh the harness snapshot. Do not re-init, do not rewrite history,
  do not touch files that didn't change.
- **Re-verify the allowlist both directions** (`git check-ignore --stdin` for the secrets/bulk, `git ls-files
  --others --exclude-standard` for the keepers) exactly as in Step 3 — the allowlist that was right last time
  may be wrong now that the tree grew.
- **Incremental commit** — stage with `git add -A`, run the Step 4 staged-name secret scan (must be CLEAN), and
  make one well-messaged commit describing the delta, on the existing repo, still with **zero remotes**. Then
  Step 7's clean-clone-and-run proof still runs against the updated repo — an update that breaks the boot is as
  much a finding as a create that does. If the audit finds NO drift, that is the result: report "already in
  sync, verified by clean clone," don't make an empty commit.

### Step 2 — Survey & size: what to exclude vs. what to keep (the test is need-to-run + re-obtainability)

The `.gitignore` allowlist in Step 3 is a decision, and this survey is its evidence. Measure the tree's
directory sizes (on this machine, via PowerShell — `du` isn't available: `Get-ChildItem -Recurse | Measure-Object -Sum Length`
per top-level dir) and list what's large. In the cad-forge run this surfaced `runs/` at 1.9 GB,
`ops/wheelhouse` at 342 MB, `datasets` at 158 MB, plus 100 MB+ individual GLBs and a `.parquet`. Size alone
never settles whether an item ships. **The real test for every item is two questions:**

1. **Does the app need it to run?** (Does the dashboard/registry/entry point load it to boot?)
2. **Can the target machine cheaply re-obtain it?** (Does `uv sync` rebuild it, or is there a documented one-line fetch?)

**Exclude an item only if it's NOT needed to run, OR it's needed but the target can cheaply re-create it.**
Anything needed-to-run that the target *cannot* easily re-fetch is a **keeper — even when it's large** (ship
it via **Git LFS** so it rides along without bloating normal git history). Applied to the two items you
flagged:

- **`wheelhouse/` (pre-downloaded `.whl` package files) — hinges on target connectivity.** If the target
  device has internet, `uv sync` re-downloads the exact pinned wheels, so the wheelhouse is redundant there →
  exclude. If the target is **offline / air-gapped** (plausible for a NASA machine), the wheelhouse IS the
  install source and is also the workaround for the "3.14 has no wheels" class of failure → **keep it** (LFS if
  large). This is a genuine judgment call — establish whether the target will be online before excluding it,
  and if unsure, keep it.
- **`datasets/` — keep if the app needs them to run.** If cad-forge loads them to boot and they can't be
  cheaply re-fetched on the target, they are essential → **keep them** (LFS if too big for plain git). Exclude
  only if they're large reference data the target can regenerate or re-download, and then leave a one-line
  fetch instruction in the README.

The output is still two lists — exclude vs. keep — classified by the two questions above (size alone doesn't
decide), plus a note of which keepers need Git LFS and whether the target is offline. A blanket `runs/` ignore that also
drops the JSON the dashboard reads produces a repo that clones but doesn't run; a blanket `wheelhouse`/
`datasets` ignore produces a repo that won't install or won't run on an offline target.

### Step 3 — De-couple from this machine, then draw the allowlist

Two halves: make the code machine-agnostic, and make the repo contents right.

**De-couple the code:**
- **De-hardcode paths.** Replace absolute `C:\Users\dmcgowa2\...` paths and the scoop-python path with
  root-relative resolution: `PROJECT_ROOT = Path(__file__).resolve().parent` (walk up to a `.git`/
  `pyproject.toml` marker if the file is deep), and build every other path off it with `pathlib`'s `/`
  operator (cross-platform, unlike string concat). Machine-specific values (keys, external data dirs, output
  locations) move to env vars loaded from `.env` via `python-dotenv`, never inline strings.
- **Pin dependencies for a bare machine.** The bootstrap on another device has to be one command. Prefer
  `uv`: a committed `uv.lock` (exact cross-platform pins) + a committed `.python-version` (so `uv` fetches
  the right interpreter — this directly defuses this machine's real "3.14 has no wheels" class of failure),
  so `uv sync` on the target machine IS the bootstrap. If the project isn't on `uv`, a pinned
  `requirements.txt` + a stated Python version is the fallback. Add a shell wrapper (`.ps1` + `.sh` twins)
  only if there are non-Python steps.
- **`.env.example`** committed (every env var the code reads, with placeholder values), real `.env`
  gitignored.
- **`.gitattributes`** committed (`* text=auto`, `*.sh text eol=lf`, `*.ps1 text eol=crlf`, binaries marked)
  — the shared, enforced line-ending source of truth, since `core.autocrlf` is per-machine and silently
  inconsistent. This matters specifically because this machine's paths and scripts cross the Windows/Unix
  line.
- **README quickstart** — copy-paste `uv sync && uv run <entry point>`, and a one-line "what this is".

**Draw the `.gitignore` allowlist (the load-bearing craft):** build it from Step 2's exclude/keep lists as an
allowlist that re-includes the keepers — e.g. `/runs/*` ignored, then `!runs/<needed-dir>/` re-included, then inside
it only the needed extensions (`!runs/<dir>/*.json`, `!runs/<dir>/<demo>.glb`). Safe blanket-excludes are the
things nothing needs at runtime: venvs, caches, `__pycache__`, `node_modules`, `*.log`, `.env*`, `*.local.*`,
and the API-key file by name. **Do NOT blanket-exclude by extension the things that might be keepers** — a
bare `*.whl` ignore drops the wheelhouse an offline target needs; a bare `*.parquet`/`*.stl`/`*.step` ignore
may drop data the app loads. Exclude those only where Step 2's test said "not needed to run, or re-obtainable,"
and re-include (or LFS-track) the ones that are keepers.

**Large keepers ride via Git LFS.** For a keeper too big for comfortable plain-git (offline wheelhouse,
essential datasets, a required large model): `git lfs track "<pattern>"` (e.g. `git lfs track "datasets/**"`),
commit the resulting `.gitattributes` LFS lines, and it ships without bloating normal history. Note in the
README that the target needs `git lfs` installed to pull them. (An air-gapped target with no LFS server means
the files travel with the repo copy itself — flag that case rather than assuming a hub is reachable.)

**Verify the allowlist BOTH directions with `git check-ignore`** — this is Douglas's actual verification and it
is not optional:
- Every secret/bulk path IS ignored: `printf '%s\n' "AI Reference.md" ".env" "config.local.json" | git check-ignore --stdin`
  should echo each back (matched).
- Every needed small artifact is NOT ignored: `git ls-files --others --exclude-standard | grep '\.json$'`
  should surface exactly the keepers the app loads.

### Step 4 — Secret hygiene by construction, then prove it

Douglas's key insight is that a correct `.gitignore` makes staging safe by construction: `git add -A`
respects `.gitignore`, and `git ls-files --others --exclude-standard` already filters out ignored (secret)
files — so a normal add won't stage secrets IF Step 3's allowlist is right. Then PROVE it, don't assume it:

- After staging, scan the staged NAMES for sensitive patterns — must come back clean:
  `git diff --cached --name-only | grep -iE 'reference|credential|\.pem$|password|secret|\.env'` → expect no
  matches. (Name-based only — never print file contents or values. The secret hooks on this machine will
  block commands containing the literal string `.env`/`secret`/`OPENAI_API_KEY`; use metadata-only probes and
  `git check-ignore --stdin` rather than commands that echo those tokens, exactly as the cad-forge run had
  to.)
- **When to escalate to `gitleaks` (content scan) — the decision rule.** The name-scan above only sees
  file*names*, so it catches a secret in a file *named* like one, but it's blind to a secret sitting *inside*
  an innocent-looking file (a key pasted into `config.py`, a token in a notebook, a connection string in a
  README). `gitleaks` scans file *contents* for secret-shaped patterns. Reach for it — add a `gitleaks`
  pre-commit hook (`.pre-commit-config.yaml`) and run `pre-commit run --all-files` once — when ANY of these
  hold: (a) the repo will go **public** or to a remote you don't fully control; (b) it's large/old enough that
  you can't eyeball every file for inline secrets; (c) there's **git history** to scan (relevant on the
  history-preserving path — a secret committed earlier then deleted still lives in history, which a
  current-tree name-scan misses); (d) it's higher-stakes NASA-adjacent content where a name-scan alone isn't
  enough assurance. For a quick, stays-on-this-laptop bundle where Douglas wrote every file and the allowlist
  is clean, the name-scan is sufficient and gitleaks is optional overhead. Rule of thumb: **name-scan always;
  gitleaks before anything leaves his control or goes public.**
  This decision is **wired into the Workflow, not left to whoever reads this step.** The commit phase
  evaluates these triggers and records `gitleaks_decision` (`ran_clean` / `ran_found` /
  `recommended_before_push` / `not_needed`) with the reason; a `ran_found` halts the run before commit exactly
  like a failed name-scan (report by rule-id/path, never the value); a missing `gitleaks` binary records
  `recommended_before_push` rather than passing silently. Because "goes public" (trigger a) only happens at the
  push — which is Douglas's call after the run — the **push handoff carries the gate**: whenever the decision
  is anything other than `ran_clean`/`not_needed`, the one-command finish (Step 8) LEADS with
  `gitleaks detect` so the content scan runs at the exact moment content would go public.
- **If a secret was EVER committed in history** (only relevant on the history-preserving path): rotate/revoke
  the credential FIRST (scrubbing history doesn't un-expose it), then scrub with
  `git filter-repo --replace-text` (or BFG) on the throwaway clone. Never carry a known-leaked secret into
  the new repo on the theory that history-rewriting hides it.

### Step 5 — Harness-inside + RESUME.md (so another machine can actually resume)

Douglas's real bundle is the project PLUS everything needed to resume the harness on another machine, in one
repo. Copy a **scrubbed snapshot** of the harness the project depends on — the relevant `CLAUDE.md` / `MAP.md`
/ `DELEGATE.md`, the project's hooks / commands / memory / settings — into a `harness/` subdir inside the new
repo, **run the same secret scan over it** (it must be scrubbed of keys, NASA-internal endpoints, and
machine-specific absolute paths the same as the code), and write a **`RESUME.md`** at the repo root: what the
project is, the one-command bootstrap, how to run it, and what a fresh harness needs to pick up where this
left off. This is what turns "clones and runs" into "I can *work on* it fully from another device."

### Step 6 — Commit locally on a clean tree — and STOP

Commit the project's own pending work first so the repackage happens on a clean tree (the cad-forge run
captured its bundle on a clean commit deliberately). Then commit the bundle: a single, well-messaged commit
with the `Co-Authored-By: Claude` trailer. Then **STOP.**

**The remote is always Douglas's call.** Do NOT `git push`, do NOT `gh repo create`, do NOT add a remote —
this is a hard rule. Two reasons, both real: pushing a NASA-adjacent project to a remote is a
compliance decision only Douglas can make, and remote-creation/push has been guard-blocked on this machine
before. The run ends at a local commit with **zero remotes**, exactly as the cad-forge bundle did.

### Step 7 — Prove portability: clean-clone into a fresh temp dir and run

This is the step that turns "should be portable" into "is portable this pass." Clone the just-committed repo
into a fresh temp directory that has never held this project's `.venv`, caches, or env vars — a real temp
folder, not a sibling of the working copy (a sibling inherits ambient state that masks exactly the bugs this
catches):

```
git clone <local-repo-path> $env:TEMP\package-verify-<name>
cd $env:TEMP\package-verify-<name>
uv sync
uv run <the real entry point>    # or the app's actual boot command
```

Report honestly whether it booted with nothing from the origin: PASS (ran clean), or the specific failure
(missing dep, implicit CWD dependency, a data file that was excluded but needed, a hardcoded path that
survived). A failure here is the most valuable output of the whole run — it's the bug that would otherwise
surface on the other device. If it fails, fix the specific gap (usually the allowlist dropped a needed file,
or a path wasn't de-hardcoded) and re-run this step; don't report "portable" until the clean clone actually
ran. **Cheap upgrade** for cross-OS confidence: run the same clone-and-boot inside a `python:3.x-slim`
container to catch CRLF/path-separator issues a same-OS clone can't — offer it, don't force it.

### Step 8 — The honest final report + the one-command finish

Report in the measured register of `/hone` and `/probe` — no "fully portable," no "guaranteed to run
anywhere":

- **The gate outcome** — the mode (create / update) and which condition fired (sensitive-content halt /
  already-portable / which extraction approach), stated plainly. In update mode, report the drift found (files
  synced, new bulk/secrets excluded, paths de-hardcoded, deps re-pinned) or "already in sync, no commit."
- **The sensitive-content decision** — what was judged sensitive and excluded, and (if it halted) what
  Douglas needs to rule on. Never imply a compliance call was made autonomously.
- **The repo shape** — file count, size, the allowlist's exclude/keep lists, that the tree is clean and has
  zero remotes.
- **The portability proof** — did the clean clone actually run this pass (PASS with the command that booted
  it), or the specific gap that remains. This is the load-bearing claim; state it as a measured result, not
  an assertion.
- **The one-command finish** — the exact `gh repo create <name> --private --source=. --remote=origin --push`
  (or the two-step `gh repo create` + `git push -u origin <branch>`) line for Douglas to run himself when he
  makes the compliance call. Present it as his to run. **When the commit phase's `gitleaks_decision` is
  anything other than `ran_clean`/`not_needed`, this line LEADS with a content scan** —
  `gitleaks detect --no-banner  # must be clean before the push below` — so going-public (the one trigger that
  fires at push time) gets its scan at the exact moment it matters.
- Full absolute path of the new repo and anything written, per the standing Files-list convention.

## Safety constraints (apply every run, no exceptions)

- **Never `git push`, `gh repo create`, or add a remote.** The remote is Douglas's explicit
  NASA-content-to-remote compliance call, every time — hand back the one-command finish, never run it. This
  is the single most important constraint of this command.
- **Never run with elevated/bypass permissions.** A "just package it" ask does not justify disabling the
  permission system. If a secret hook blocks a command containing a literal `.env`/`secret`/key-name string,
  that is a CORRECT block — switch to a metadata-only probe
  (`git check-ignore --stdin`, name-only scans) that never names or prints the value, exactly as the
  cad-forge run did. Never echo, print, or log a secret's value, not even partially.
- **Isolate all destructive/history-rewriting work in a throwaway clone or worktree — never the working
  tree.** `git filter-repo` and history scrubs rewrite destructively; they run on a fresh clone, never
  Douglas's checkout. The clean-clone verification (Step 7) is likewise a fresh temp clone. The original
  working tree and its `git status` are left exactly as found (aside from the deliberate new repo/commit the
  fresh-init path creates at the target subdir, which is the intended product).
- **File-mutating Bash on the NASA trees must use `dangerouslyDisableSandbox: true`** — the sandbox silently
  discards file mutations on these trees, so an un-flagged `.gitignore` write or `git add` can evaporate
  (`[[reference_bash_sandbox_mutations]]`). Verify writes landed.
- **Commit on a clean tree; single well-messaged commit with the `Co-Authored-By: Claude` trailer.** Never
  force-push, never `reset --hard`, never skip hooks. Delete any throwaway branch with `git branch -d` (safe
  delete), not `-D` — this machine's `block-dangerous-bash.js` unconditionally blocks `git branch -D`. Run
  worktree-remove and branch-delete as separate calls, never chained.
- **Scrub the harness snapshot the same as the code.** The `harness/` copy (Step 5) must pass the same secret
  + hardcoded-path + NASA-internal scan before it's committed — a scrubbed snapshot, never a raw copy of
  `~/.claude`.
- **Make only the changes packaging requires** — de-hardcoding, dependency pinning, the allowlist, the
  bundle. No unrelated refactors or drive-by cleanup of the system's own logic. If de-hardcoding surfaces a
  real bug in the code, report it as a finding for Douglas rather than silently fixing it.

## Procedure (how to run it)

1. Resolve TARGET, its git boundary, its run command, and whether history matters per Step 0.
2. **Call the `Workflow` tool** with the script below verbatim, passing
   `args: { target: "<system + path + how it's run + git boundary>", preserveHistory: <true|false>, entryPoint: "<the real boot command>", harnessPaths: "<which harness files to snapshot, or ''>", existingRepo: "<path to a prior /package repo if Douglas names one, else ''>" }`.
   This is an explicit skill-triggered Workflow use — no separate opt-in. Pass `existingRepo` when Douglas is
   asking to UPDATE/refresh an already-packaged system and names the repo; otherwise leave it `''` and the gate
   detects create-vs-update itself.
   - **The classification gate (sensitive-content + already-portable + history-vs-fresh-init) and the
     de-coupling judgment run on `model: 'opus'`** — per Douglas's delegation policy, the load-bearing calls
     (is anything genuinely sensitive, is this already portable, which paths are machine-coupling vs.
     legitimate) are Opus's; the mechanical survey, allowlist writing, staging, and clone-verify stay on the
     default model.
   - If the gate returns `stopReason: 'sensitive_content_needs_ruling'`, do NOT proceed — surface it to
     Douglas with `AskUserQuestion` (what was found, and whether it's safe to package). Only re-invoke after
     he rules.
3. **Report the result** per Step 8 / the Final report. Never claim "fully portable" — report whether the
   clean clone actually ran this pass, the sensitive-content decision, and hand back the one-command push as
   Douglas's to run.

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'package',
  description: 'Portable-repo bundling loop: gate (sensitive-content / already-portable / history-vs-fresh-init) -> survey & size -> de-couple + allowlist -> secret-scan by construction -> harness snapshot + RESUME.md -> local commit (no remote) -> prove by clean-clone-and-run -> honest report + one-command finish',
  phases: [
    { title: 'Gate & Survey', model: 'opus' },
    { title: 'De-couple & Allowlist' },
    { title: 'Bundle & Commit' },
    { title: 'Prove Portability' },
  ],
}

const TARGET = args.target
const PRESERVE_HISTORY = args.preserveHistory === true
const ENTRY = args.entryPoint || ''
const HARNESS = args.harnessPaths || ''
const EXISTING_REPO = args.existingRepo || ''   // path to a prior /package repo, or '' to let the gate detect
const TARGET_OFFLINE = args.targetOffline       // true/false if Douglas knows the target's connectivity, else undefined -> gate infers

// --- Phase schemas (JSON-schema-validated, spar/hone/probe pattern) ---

const GATE_SCHEMA = {
  type: 'object',
  properties: {
    packaging_mode: { type: 'string', enum: ['create', 'update'] },  // update => a prior /package repo already exists
    existing_repo_path: { type: 'string' },                 // in update mode, the path to that repo ('' in create mode)
    sensitive_content_needs_ruling: { type: 'boolean' },   // true => STOP, ask Douglas
    sensitive_findings: { type: 'array', items: { type: 'string' } }, // what looked sensitive (names/paths, NEVER values)
    already_portable: { type: 'boolean' },                  // its own repo + pins + .env.example + README + no hardcoded paths
    portable_gap: { type: 'string' },                       // if already_portable is a near-miss, the one missing piece
    extraction: { type: 'string', enum: ['fresh_init', 'filter_repo_split'] },
    git_boundary: { type: 'string' },                       // own repo / nested-in-parent(where)
    target_offline: { type: 'boolean' },                    // is the target device air-gapped/offline? decides wheelhouse
    bulk_to_exclude: { type: 'array', items: { type: 'string' } },   // items NOT needed to run OR cheaply re-obtainable on target (+ approx size)
    small_keepers: { type: 'array', items: { type: 'string' } },     // small artifacts the app must load to boot
    large_keepers_lfs: { type: 'array', items: { type: 'string' } }, // needed-to-run but LARGE + not re-obtainable on target -> ship via Git LFS (datasets, offline wheelhouse)
    gate_note: { type: 'string' },
  },
  required: ['packaging_mode', 'sensitive_content_needs_ruling', 'already_portable', 'extraction', 'bulk_to_exclude', 'small_keepers', 'gate_note'],
}

const DECOUPLE_SCHEMA = {
  type: 'object',
  properties: {
    hardcoded_paths_fixed: { type: 'array', items: { type: 'string' } },  // file:before -> after (Path(__file__)/env)
    deps_pinned_via: { type: 'string' },                    // 'uv.lock+.python-version' / 'requirements.txt+pyver' / 'none-needed'
    files_added: { type: 'array', items: { type: 'string' } },  // .env.example / .gitattributes / README / uv.lock ...
    gitignore_allowlist: { type: 'string' },                 // the actual allowlist written
    check_ignore_secrets_matched: { type: 'boolean' },        // secrets/bulk confirmed IGNORED (both-direction check)
    check_ignore_keepers_present: { type: 'boolean' },        // needed small artifacts confirmed NOT ignored
    real_bug_surfaced: { type: 'string' },                    // any code bug de-hardcoding exposed (report, don't fix)
  },
  required: ['deps_pinned_via', 'files_added', 'gitignore_allowlist', 'check_ignore_secrets_matched', 'check_ignore_keepers_present'],
}

const COMMIT_SCHEMA = {
  type: 'object',
  properties: {
    staged_count: { type: 'integer' },
    staged_secret_scan_clean: { type: 'boolean' },           // name-scan of staged files came back CLEAN
    gitleaks_decision: { type: 'string', enum: ['ran_clean', 'ran_found', 'recommended_before_push', 'not_needed'] }, // the content-scan call this run
    gitleaks_reason: { type: 'string' },                      // which trigger fired (or why skipped)
    harness_snapshot_scrubbed: { type: 'boolean' },           // harness/ copy passed the same scan (n/a if none requested)
    resume_md_written: { type: 'boolean' },
    committed: { type: 'boolean' },
    commit_sha: { type: 'string' },
    remotes: { type: 'integer' },                             // MUST be 0
    repo_path: { type: 'string' },
    repo_size: { type: 'string' },
  },
  required: ['staged_count', 'staged_secret_scan_clean', 'gitleaks_decision', 'committed', 'remotes', 'repo_path'],
}

const VERIFY_SCHEMA = {
  type: 'object',
  properties: {
    clean_clone_ran: { type: 'boolean' },                     // the load-bearing claim
    boot_command: { type: 'string' },                         // what actually booted it
    failure: { type: 'string' },                              // specific gap if it didn't run
    fixed_and_reran: { type: 'boolean' },
    gitleaks_before_push: { type: 'boolean' },                // does the handoff require a content scan before going public?
    one_command_finish: { type: 'string' },                   // the (gitleaks-first, if public-bound) gh repo create + push line for Douglas
  },
  required: ['clean_clone_ran', 'one_command_finish'],
}

const UPDATE_SCHEMA = {
  type: 'object',
  properties: {
    drift_found: { type: 'boolean' },                        // false => already in sync, no commit made
    files_synced: { type: 'array', items: { type: 'string' } },   // changed keepers copied into the existing repo
    new_bulk_excluded: { type: 'array', items: { type: 'string' } }, // bulk that appeared since + now excluded
    new_secrets_excluded: { type: 'array', items: { type: 'string' } }, // credential files added since (names only)
    hardcoded_paths_fixed: { type: 'array', items: { type: 'string' } }, // newly-introduced C:\Users paths de-hardcoded
    deps_repinned: { type: 'boolean' },                      // uv.lock/requirements refreshed
    harness_refreshed: { type: 'boolean' },                  // harness/ + RESUME.md re-scrubbed (n/a=true)
    check_ignore_secrets_matched: { type: 'boolean' },        // re-verified: secrets/bulk still IGNORED
    check_ignore_keepers_present: { type: 'boolean' },        // re-verified: keepers still NOT ignored
    staged_secret_scan_clean: { type: 'boolean' },            // name-scan of the incremental staged set CLEAN
    gitleaks_decision: { type: 'string', enum: ['ran_clean', 'ran_found', 'recommended_before_push', 'not_needed'] }, // content-scan call on the delta
    gitleaks_reason: { type: 'string' },
    committed: { type: 'boolean' },                           // false + drift_found=false => nothing to do (OK)
    commit_sha: { type: 'string' },
    remotes: { type: 'integer' },                             // MUST be 0
    repo_path: { type: 'string' },
  },
  required: ['drift_found', 'check_ignore_secrets_matched', 'check_ignore_keepers_present', 'staged_secret_scan_clean', 'committed', 'remotes', 'repo_path'],
}

// --- Prompts ---

function gatePrompt(target, preserve) {
  return `You are running the mandatory classification gate + survey for packaging a system into a portable, ` +
    `self-contained repo. TARGET: ${target}\nCaller's preserveHistory hint: ${preserve}\n\n` +
    `Caller's existingRepo hint (path to a prior /package repo, or '' to detect): ${EXISTING_REPO}\n` +
    `Caller's targetOffline hint (${TARGET_OFFLINE === undefined ? 'unknown -- infer, and if still unsure default to keeping the wheelhouse' : TARGET_OFFLINE}): use it for the wheelhouse call in step 4 below.\n\n` +
    `Do NOT mutate anything in this phase -- this is read + measure only.\n\n` +
    `0. CREATE vs UPDATE. Decide first whether a previously-/package'd standalone repo for this system already ` +
    `exists. It's UPDATE if the existingRepo hint is non-empty, OR the survey finds a sibling/known repo with ` +
    `the telltale shape: its own .git, ZERO remotes (git remote -v empty), a RESUME.md at its root, and the ` +
    `.gitignore allowlist this command writes. If so set packaging_mode='update' and existing_repo_path to that ` +
    `repo's path. Otherwise packaging_mode='create' and existing_repo_path=''. In update mode the downstream ` +
    `job is a drift audit + incremental commit into that repo, NOT a fresh extraction -- but still complete the ` +
    `sensitive-content, survey, and bulk/keeper lists below, because the update needs them too.\n` +
    `1. SENSITIVE-CONTENT CALL. Survey the tree for anything that genuinely cannot be committed to a repo that ` +
    `may later be pushed: the API-key file, .env / *.local.* / credential files, and especially any genuinely ` +
    `NASA-internal/CUI/ITAR data or endpoint config. Douglas's own anchor: he built this without NASA data and ` +
    `just has it connected to his computer -- the sensitive set is usually NARROW (a few named files handled by ` +
    `the allowlist), not the project. Report sensitive_findings as NAMES/PATHS ONLY, never values or contents. ` +
    `If ANYTHING is a genuine judgment call (real NASA data in the tree, an internal dataset, an endpoint that ` +
    `shouldn't be documented), set sensitive_content_needs_ruling=true -- this HALTS the run for Douglas to ` +
    `rule. Do not decide on his behalf what is safe to package.\n` +
    `2. ALREADY PORTABLE? If the target is already its own repo with pinned deps (committed lockfile / pinned ` +
    `requirements), an .env.example, a README quickstart, and no hardcoded machine paths, set ` +
    `already_portable=true (and portable_gap='' or the one near-miss). Don't re-package what already boots ` +
    `elsewhere.\n` +
    `3. EXTRACTION APPROACH. Determine the git boundary (is the target its own repo, or nested inside a parent ` +
    `repo's root -- check with git rev-parse/ls-files). Set extraction='fresh_init' (fresh git init + single ` +
    `commit at the subdir -- Douglas's cad-forge practice, use when standalone history isn't valuable) or ` +
    `'filter_repo_split' (history-preserving git filter-repo --subdirectory-filter on a FRESH throwaway clone, ` +
    `use when the subdir's history is worth keeping). Honor the preserveHistory hint unless the boundary makes ` +
    `it impossible.\n` +
    `4. SURVEY & CLASSIFY (the test is need-to-run + re-obtainability; size alone doesn't decide). Measure ` +
    `top-level directory sizes (PowerShell Get-ChildItem ` +
    `-Recurse | Measure-Object -Sum Length -- du is unavailable). Then classify each large item by TWO ` +
    `questions: (a) does the app need it to RUN (does the dashboard/registry/entry point load it to boot)? ` +
    `(b) can the TARGET machine cheaply re-obtain it (does 'uv sync' rebuild it, or is there a one-line fetch)? ` +
    `Put an item in bulk_to_exclude ONLY if it's not-needed-to-run OR needed-but-cheaply-re-obtainable (venvs, ` +
    `caches, __pycache__, node_modules, *.log, pure intermediates). Anything needed-to-run that the target ` +
    `CANNOT easily re-fetch is a KEEPER even if large -> small_keepers if small, large_keepers_lfs if big ` +
    `(ship via Git LFS). Specifically: the WHEELHOUSE (pre-downloaded .whl files) is redundant ONLY if the ` +
    `target has internet (uv sync re-downloads); if the target is offline/air-gapped it's the install source ` +
    `and a keeper -- set target_offline and, if offline, put the wheelhouse in large_keepers_lfs, NOT ` +
    `bulk_to_exclude. DATASETS are keepers if the app loads them to run and they can't be re-fetched on target ` +
    `(large_keepers_lfs); exclude only if re-obtainable, and then note the fetch step. If the target's ` +
    `connectivity is unknown, default target_offline conservatively (assume it may be offline -> keep the ` +
    `wheelhouse). A blanket ignore that drops a keeper makes a repo that clones but won't install or run.\n\n` +
    `Report the full schema. gate_note = plain-language summary of which conditions fired and the chosen ` +
    `extraction approach.`
}

function decouplePrompt(target, gate, entry) {
  return `De-couple this system from this specific machine and draw its .gitignore allowlist, in the target ` +
    `tree. TARGET: ${target}\nENTRY POINT: ${entry}\nBULK TO EXCLUDE: ${JSON.stringify(gate.bulk_to_exclude)}\n` +
    `SMALL KEEPERS: ${JSON.stringify(gate.small_keepers)}\n` +
    `LARGE KEEPERS (ship via Git LFS): ${JSON.stringify(gate.large_keepers_lfs || [])}\n` +
    `TARGET OFFLINE/AIR-GAPPED: ${gate.target_offline === true}\n\n` +
    `File-mutating Bash on these NASA trees MUST use dangerouslyDisableSandbox:true or the writes silently ` +
    `evaporate -- and verify each write landed.\n\n` +
    `DE-COUPLE THE CODE:\n` +
    `- Replace absolute C:\\\\Users\\\\dmcgowa2\\\\... paths and the scoop-python path with root-relative ` +
    `resolution: PROJECT_ROOT = Path(__file__).resolve().parent (walk up to a .git/pyproject marker if deep), ` +
    `all other paths built off it with pathlib's / operator. Machine-specific values (keys, external data ` +
    `dirs, output locations) move to env vars loaded from .env via python-dotenv. Report each fix as ` +
    `file:before->after. If de-hardcoding surfaces a REAL code bug, report it in real_bug_surfaced -- do NOT ` +
    `silently fix it.\n` +
    `- Pin deps for a bare machine: prefer a committed uv.lock + .python-version (so 'uv sync' IS the ` +
    `bootstrap and the right interpreter is fetched -- defuses the '3.14 has no wheels' failure class). If not ` +
    `on uv, a pinned requirements.txt + stated Python version. Set deps_pinned_via.\n` +
    `- Add .env.example (every env var the code reads, placeholder values; real .env gitignored), ` +
    `.gitattributes (* text=auto, *.sh eol=lf, *.ps1 eol=crlf, binaries marked), and a README quickstart ` +
    `(copy-paste 'uv sync && uv run ${entry}' + one line on what it is).\n\n` +
    `DRAW THE ALLOWLIST (the load-bearing craft): build .gitignore as an ALLOWLIST from the lists -- e.g. ` +
    `/runs/* ignored, then !runs/<needed-dir>/ and inside it only !runs/<dir>/*.json etc. Safe blanket-excludes ` +
    `(nothing needs them at runtime): venvs, caches, __pycache__, node_modules, *.log, large images (keep ` +
    `static/img), and the secret files BY NAME. Do NOT blanket-exclude by extension anything on the keeper ` +
    `lists -- a bare *.whl ignore drops an offline target's wheelhouse, a bare *.parquet/*.stl/*.step ignore may ` +
    `drop data the app loads; re-include or LFS-track those. For every LARGE KEEPER above, run ` +
    `'git lfs track "<pattern>"' (e.g. git lfs track "datasets/**"), commit the resulting .gitattributes LFS ` +
    `lines, and note in the README that the target needs git-lfs installed to pull them (if TARGET OFFLINE is ` +
    `true, note the files travel with the repo copy since no LFS server may be reachable). Then VERIFY BOTH ` +
    `DIRECTIONS with git check-ignore (Douglas's actual, ` +
    `non-optional verification): pipe the sensitive/bulk paths through 'git check-ignore --stdin' and confirm ` +
    `each is matched (set check_ignore_secrets_matched); run 'git ls-files --others --exclude-standard' and ` +
    `confirm the small keepers ARE surfaced/not-ignored (set check_ignore_keepers_present). Use metadata-only ` +
    `probes -- the secret hooks block commands containing the literal '.env'/'secret'/key-name strings, so ` +
    `route through check-ignore --stdin rather than echoing those tokens. Report the actual allowlist written.`
}

function commitPrompt(target, gate, harness) {
  const harnessClause = harness
    ? `Copy a SCRUBBED snapshot of these harness files into a harness/ subdir inside the new repo: ${harness}. ` +
      `Run the SAME secret + hardcoded-path + NASA-internal scan over the snapshot before committing -- it must ` +
      `be scrubbed of keys, internal endpoints, and machine-specific absolute paths. Set ` +
      `harness_snapshot_scrubbed. Then write a RESUME.md at the repo root: what the project is, the one-command ` +
      `bootstrap, how to run it, and what a fresh harness needs to resume. Set resume_md_written.`
    : `No harness snapshot requested. Still write a RESUME.md at the repo root (what it is, the one-command ` +
      `bootstrap, how to run it). Set resume_md_written; harness_snapshot_scrubbed = true (n/a).`;
  return `Stage and commit the portable bundle LOCALLY. TARGET: ${target}\nEXTRACTION: ${gate.extraction}\n\n` +
    `File-mutating Bash on these NASA trees MUST use dangerouslyDisableSandbox:true; verify writes landed.\n\n` +
    `1. If extraction is 'fresh_init' and the target is nested in a parent repo, git init a fresh repo rooted ` +
    `at the target subdir. If 'filter_repo_split', do the split on a FRESH throwaway clone (never the working ` +
    `tree), applying the subdirectory filter + any --path-rename for moved history.\n` +
    `2. Commit the project's own pending work first so the repackage happens on a CLEAN tree.\n` +
    `3. ${harnessClause}\n` +
    `4. Stage with git's own ignore-respecting add: 'git add -A' (respects .gitignore; --exclude-standard ` +
    `already filters secrets). Then PROVE secrets stayed out -- name-scan the staged files: ` +
    `git diff --cached --name-only | grep -iE 'reference|credential|\\.pem$|password' -- must be EMPTY. Set ` +
    `staged_secret_scan_clean (false if ANYTHING sensitive slipped in -- then stop and report, do not commit). ` +
    `Never print file contents/values; names only.\n` +
    `4b. GITLEAKS DECISION (content scan, on top of the name-scan above). The name-scan only sees file NAMES; ` +
    `gitleaks scans file CONTENTS for secret-shaped patterns (a key pasted into config.py, a token in a ` +
    `notebook). Decide and RECORD it: set gitleaks_decision to one of -- 'ran_clean' / 'ran_found' / ` +
    `'recommended_before_push' / 'not_needed' -- with gitleaks_reason naming the trigger. RUN gitleaks now ` +
    `('gitleaks detect --no-banner' or 'pre-commit run --all-files' if a .pre-commit-config.yaml exists) BEFORE ` +
    `committing when ANY of these fire: (b) the tree is too big/old to eyeball every file for inline secrets; ` +
    `(c) extraction is 'filter_repo_split' so there's git HISTORY to scan (a secret committed then deleted ` +
    `still lives in history and the name-scan misses it -- scan history, e.g. 'gitleaks detect' over the ` +
    `rewritten clone); (d) higher-stakes NASA-adjacent content where the name-scan alone isn't enough. If ` +
    `gitleaks runs and is clean -> 'ran_clean'. If it FINDS something -> set 'ran_found', STOP, do NOT commit, ` +
    `report it (names/rule-ids only, never the value) -- this blocks exactly like the name-scan. Trigger (a) ` +
    `'goes public' happens at PUSH, which is Douglas's call after this run, so if none of b/c/d fired but the ` +
    `repo could later be pushed public, set 'recommended_before_push' (the handoff will require it). If it's a ` +
    `small stays-local bundle with a clean allowlist and no history, 'not_needed'. If gitleaks isn't installed, ` +
    `set 'recommended_before_push' and say so in the reason -- never treat a missing tool as a clean scan.\n` +
    `5. Commit: a single well-messaged commit with a 'Co-Authored-By: Claude' trailer. Confirm the tree is ` +
    `clean and remotes = 0 (git remote -v empty). Report staged_count, commit_sha, repo_path, repo_size.\n\n` +
    `DO NOT push, DO NOT gh repo create, DO NOT add a remote -- that is Douglas's explicit call, always.`
}

function verifyPrompt(target, repoPath, entry, gate, gitleaksDecision) {
  return `PROVE the just-committed repo is portable by cloning it into a FRESH temp dir with none of this ` +
    `machine's state and running it. REPO: ${repoPath}\nENTRY POINT: ${entry}\nTARGET: ${target}\n` +
    `GITLEAKS DECISION from the commit phase: ${gitleaksDecision || 'unknown'}\n\n` +
    `Clone into a real temp folder (NOT a sibling of the working copy -- a sibling inherits ambient state that ` +
    `masks exactly the bugs this catches): git clone <repoPath> into $env:TEMP\\package-verify-<name>, cd in, ` +
    `run the bootstrap ('uv sync' or the pinned equivalent), then run the real entry point ('uv run ${entry}' ` +
    `or the app's boot command). Report clean_clone_ran = did it boot with NOTHING from the origin machine, and ` +
    `boot_command = what actually booted it. If it FAILED, report the specific gap in 'failure' (missing dep, ` +
    `implicit CWD dependency, an excluded-but-needed data file, a surviving hardcoded path) -- this is the most ` +
    `valuable output. Fix the specific gap (usually the allowlist dropped a keeper, or a path wasn't ` +
    `de-hardcoded), re-run once, set fixed_and_reran. Do NOT report portable until the clean clone actually ` +
    `ran. Remove the temp clone when done.\n\n` +
    `Finally, compose the one_command_finish for Douglas to run HIMSELF when he makes the compliance call -- ` +
    `the exact 'gh repo create <name> --private --source=. --remote=origin --push' (or two-step gh repo create ` +
    `+ git push -u origin <branch>) line. Present it as his to run; never run it here.\n` +
    `PUSH-TIME GITLEAKS GATE: the push is the moment content goes public, which is trigger (a) for a content ` +
    `scan. If the commit-phase GITLEAKS DECISION is anything other than 'ran_clean' or 'not_needed' (i.e. ` +
    `'recommended_before_push', or a public push would newly expose contents), set gitleaks_before_push=true ` +
    `and make one_command_finish LEAD with the scan: a first line 'gitleaks detect --no-banner  # must be clean ` +
    `before the push below' THEN the gh/push line, so the content scan runs at the exact moment it matters. If ` +
    `the decision was 'ran_clean' or 'not_needed', set gitleaks_before_push=false and the plain push line is ` +
    `enough.`
}

function updatePrompt(target, gate, existingRepo, entry, harness) {
  const harnessClause = harness
    ? `Re-scrub the harness snapshot: refresh the harness/ subdir from ${harness}, running the SAME secret + ` +
      `hardcoded-path + NASA-internal scan over it, and refresh RESUME.md. Set harness_refreshed.`
    : `No harness snapshot to refresh. Set harness_refreshed=true (n/a).`;
  return `UPDATE MODE: a previously-/package'd standalone repo for this system already exists. Bring it back in ` +
    `sync with the source, MINIMALLY -- audit drift, sync only the delta, incremental commit. Do NOT re-init, ` +
    `do NOT rewrite history, do NOT touch files that didn't change.\n` +
    `SOURCE (current project): ${target}\nEXISTING PACKAGE REPO: ${existingRepo}\nENTRY POINT: ${entry}\n` +
    `BULK TO EXCLUDE (current survey): ${JSON.stringify(gate.bulk_to_exclude)}\n` +
    `SMALL KEEPERS (current survey): ${JSON.stringify(gate.small_keepers)}\n` +
    `LARGE KEEPERS via LFS (current survey): ${JSON.stringify(gate.large_keepers_lfs || [])} (target offline: ${gate.target_offline === true})\n\n` +
    `File-mutating Bash on these NASA trees MUST use dangerouslyDisableSandbox:true or writes silently ` +
    `evaporate -- verify each write landed.\n\n` +
    `AUDIT THE DRIFT (compare current source against what's in the existing repo, find only what changed):\n` +
    `- (a) New/changed source files that should be synced in (respecting the existing allowlist). Copy them in; ` +
    `report files_synced. If nothing changed at all, set drift_found=false and committed=false and STOP -- ` +
    `report "already in sync", do NOT make an empty commit.\n` +
    `- (b) New BULK that appeared since last package and the allowlist doesn't yet exclude (a new runs/ subdir, ` +
    `a new dataset). Re-survey sizes; extend .gitignore; report new_bulk_excluded.\n` +
    `- (c) New SECRETS/credential files introduced since -- the allowlist must still catch them. Report ` +
    `new_secrets_excluded (NAMES ONLY, never values).\n` +
    `- (d) Newly-introduced hardcoded C:\\\\Users\\\\dmcgowa2 paths in CHANGED code -- de-hardcode to ` +
    `Path(__file__)/env per the create-mode rules. Report hardcoded_paths_fixed as file:before->after.\n` +
    `- (e) Dependency changes -- re-pin uv.lock / requirements.txt if deps moved. Set deps_repinned.\n` +
    `- (f) ${harnessClause}\n\n` +
    `RE-VERIFY THE ALLOWLIST BOTH DIRECTIONS (it was right last time; the grown tree may have broken it): pipe ` +
    `the secrets/bulk paths through 'git check-ignore --stdin' and confirm each is matched ` +
    `(check_ignore_secrets_matched); run 'git ls-files --others --exclude-standard' and confirm the keepers ARE ` +
    `surfaced (check_ignore_keepers_present). Metadata-only probes -- never echo the literal '.env'/'secret'/ ` +
    `key-name tokens; route through check-ignore --stdin.\n\n` +
    `INCREMENTAL COMMIT: in the existing repo, 'git add -A' (respects .gitignore), then PROVE secrets stayed ` +
    `out -- name-scan the staged set: git diff --cached --name-only | grep -iE ` +
    `'reference|credential|\\.pem$|password' -- must be EMPTY (set staged_secret_scan_clean; false => stop, do ` +
    `NOT commit). GITLEAKS DECISION on the delta (content scan, same rule as create mode): RUN gitleaks ` +
    `('gitleaks detect --no-banner') before committing when a NEW secret may sit INSIDE a changed file (audit ` +
    `item c fired), when the changed set is too big to eyeball, or for higher-stakes content; set ` +
    `gitleaks_decision ('ran_clean'/'ran_found'/'recommended_before_push'/'not_needed') + gitleaks_reason. ` +
    `'ran_found' => STOP, do NOT commit, report by rule-id/path only. gitleaks not installed => ` +
    `'recommended_before_push'. Make ONE well-messaged commit describing the delta, with a 'Co-Authored-By: ` +
    `Claude' trailer. Confirm remotes = 0 (git remote -v empty). Report commit_sha, repo_path, staged file ` +
    `count context.\n` +
    `DO NOT push, DO NOT gh repo create, DO NOT add a remote -- Douglas's explicit call, always.`
}

// --- Run ---

log(`Gate + survey for packaging ${TARGET}`)
const gate = await agent(gatePrompt(TARGET, PRESERVE_HISTORY), { phase: 'Gate & Survey', schema: GATE_SCHEMA, label: 'gate-survey', model: 'opus' })

if (!gate) {
  return { target: TARGET, stopReason: 'gate_failed', note: 'The gate agent did not return a usable result.' }
}
if (gate.sensitive_content_needs_ruling) {
  return {
    target: TARGET,
    stopReason: 'sensitive_content_needs_ruling',
    gate,
    note: 'The survey found content whose sensitivity is a judgment call only Douglas can make (' +
      JSON.stringify(gate.sensitive_findings) + '). Packaging is HALTED. Surface this to Douglas with ' +
      'AskUserQuestion -- what was found (names only) and whether it is safe to package -- and only re-run ' +
      'after he rules. Do not decide on his behalf what may leave the machine.',
  }
}
// UPDATE MODE: a prior /package repo exists -> audit drift + incremental commit, no fresh extraction.
if (gate.packaging_mode === 'update') {
  const existingRepo = gate.existing_repo_path || EXISTING_REPO
  if (!existingRepo) {
    return { target: TARGET, stopReason: 'update_repo_not_found', gate,
      note: 'Gate chose update mode but no existing repo path was resolved. Pass args.existingRepo or fall back to create mode.' }
  }
  log(`Update mode: refreshing the existing package at ${existingRepo}`)
  const update = await agent(updatePrompt(TARGET, gate, existingRepo, ENTRY, HARNESS), { phase: 'Bundle & Commit', schema: UPDATE_SCHEMA, label: 'update-package', model: 'opus' })
  if (!update) {
    return { target: TARGET, stopReason: 'update_failed', gate, note: 'The update agent did not return a usable result.' }
  }
  if (update.gitleaks_decision === 'ran_found') {
    return { target: TARGET, stopReason: 'gitleaks_found', gate, update,
      note: 'gitleaks found secret-shaped CONTENT in the update delta (' + (update.gitleaks_reason || '') +
        '). Update STOPPED before commit. Rotate/remove the exposed secret and re-run. Report by rule-id/path only.' }
  }
  if (update.staged_secret_scan_clean === false) {
    return { target: TARGET, stopReason: 'update_blocked', gate, update,
      note: 'A sensitive name slipped into the staged set during update -- the allowlist is wrong for the grown tree. Fix .gitignore and re-run; did NOT commit.' }
  }
  if (!update.drift_found && !update.committed) {
    // Nothing changed since last package. Still prove the existing repo still boots.
    const verifyInSync = await agent(verifyPrompt(TARGET, existingRepo, ENTRY, gate, update.gitleaks_decision), { phase: 'Prove Portability', schema: VERIFY_SCHEMA, label: 'prove-portability' })
    return { target: TARGET, mode: 'update', gate, update, verify: verifyInSync,
      portable_this_pass: !!(verifyInSync && verifyInSync.clean_clone_ran), stopReason: 'already_in_sync' }
  }
  if (update.remotes && update.remotes > 0) {
    log('WARNING: the existing repo has a remote -- packaging ends at zero remotes. Report this; do not push.')
  }
  const verifyUpd = await agent(verifyPrompt(TARGET, existingRepo, ENTRY, gate, update.gitleaks_decision), { phase: 'Prove Portability', schema: VERIFY_SCHEMA, label: 'prove-portability' })
  return { target: TARGET, mode: 'update', gate, update, verify: verifyUpd,
    portable_this_pass: !!(verifyUpd && verifyUpd.clean_clone_ran), stopReason: 'complete' }
}

const alreadyPortable = gate.already_portable && !gate.portable_gap
if (alreadyPortable) {
  log('Target appears already portable -- skipping bundling, verifying the existing repo by clean-clone only')
}

const decouple = alreadyPortable
  ? null
  : await agent(decouplePrompt(TARGET, gate, ENTRY), { phase: 'De-couple & Allowlist', schema: DECOUPLE_SCHEMA, label: 'decouple', model: 'opus' })

let commit = null
if (!alreadyPortable) {
  commit = await agent(commitPrompt(TARGET, gate, HARNESS), { phase: 'Bundle & Commit', schema: COMMIT_SCHEMA, label: 'bundle-commit' })
  if (commit && commit.gitleaks_decision === 'ran_found') {
    return {
      target: TARGET,
      stopReason: 'gitleaks_found',
      gate, decouple, commit,
      note: 'gitleaks found secret-shaped CONTENT inside a committed-would-be file (' + (commit.gitleaks_reason || '') +
        '). Packaging STOPPED before commit. Rotate/remove the exposed secret, fix the source, and re-run. ' +
        'Report the finding by rule-id/path only, never the value.',
    }
  }
  if (!commit || !commit.committed || commit.staged_secret_scan_clean === false) {
    return {
      target: TARGET,
      stopReason: 'commit_blocked',
      gate, decouple, commit,
      note: commit && commit.staged_secret_scan_clean === false
        ? 'A sensitive name slipped into the staged set -- the allowlist is wrong. Fix .gitignore and re-run; did NOT commit.'
        : 'The bundle was not committed. See commit result.',
    }
  }
  if (commit.remotes && commit.remotes > 0) {
    log('WARNING: the new repo has a remote -- packaging must end at zero remotes. Report this; do not push.')
  }
}

// For an already-portable target there is no new commit -- verify its existing repo in place.
const repoToVerify = commit ? commit.repo_path : TARGET
const verify = await agent(verifyPrompt(TARGET, repoToVerify, ENTRY, gate, commit && commit.gitleaks_decision), { phase: 'Prove Portability', schema: VERIFY_SCHEMA, label: 'prove-portability' })

return {
  target: TARGET,
  alreadyPortable,
  gate,
  decouple,
  commit,
  verify,
  portable_this_pass: !!(verify && verify.clean_clone_ran),
  stopReason: 'complete',
}
```

---

*Tracked copy: also save this file to `claude-global-config/commands/package.md` (per the skills-are-tracked
convention) after a NASA scrub.*
