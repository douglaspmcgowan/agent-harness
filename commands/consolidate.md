---
name: consolidate
description: "General-purpose folder/directory consolidation: scans any folder Douglas points it at, detects duplicate/near-duplicate files, stale superseded versions (timestamped _backups/ piling up, .bak/.old/.proposed drafts), and genuinely dead/orphaned files (nothing references them, nothing recent touches them), then either surfaces a concrete PROPOSED PLAN and stops for approval (safe mode, default) or executes an already-approved plan (auto mode). Archive-not-delete by default for anything destructive. Use when Douglas says 'clean up this folder', 'consolidate this directory', 'this folder is over-populated', 'organize my files', 'get rid of old stuff in X', '/consolidate'."
---

# /consolidate [path] [--mode safe|auto] [--plan <path-to-approved-plan>]

Folders accumulate crust: a `_backups/` subfolder that quietly grows a new timestamped copy every session,
`.bak`/`.old`/`.proposed` files nobody circled back to delete, three drafts of the same artifact, and files
nothing has touched or referenced in months. This command scans a folder, builds evidence for each of those
patterns, and either stops with a concrete plan for Douglas to approve (**safe mode**, the default — matching
his own working rule that anything hard-to-reverse gets a human sign-off before it happens) or carries out a
plan he already reviewed (**auto mode**). It never blurs the two: auto mode executes an approval that already
happened, it does not decide on Douglas's behalf that something is safe to skip asking about.

## What this is NOT

- **Not `/docs-update`.** `docs-update` is scoped to a *documentation set* (`.md`/`.html`/`.canvas` notes) and
  reasons about content — is this doc superseded by that one, is the wikilink graph healthy, does the folder
  need an index/MOC. `/consolidate` is scoped to a *directory of arbitrary files* — any type, including
  binaries, screenshots, JSON dumps, tool output trees — and reasons about file-system-level signals: duplicate
  bytes, timestamped backup piles, orphan status by mtime + reference search. If the target folder is purely a
  note collection and the question is "which doc supersedes which," reach for `/docs-update` instead; if it's a
  working folder that has become a dumping ground of mixed file types, `/consolidate` is the fit. The two
  overlap at the edges (a folder can have both crusty backups and superseded docs) — when both apply,
  `/consolidate` still handles the file-level clutter, but defers wikilink-aware doc content judgments to
  `/docs-update`.
- **Not `/hone` or `/probe`.** Those measure and improve a *codebase's* performance or test quality.
  `/consolidate` never touches code behavior, dependencies, or tests — it only reorganizes files sitting in a
  directory.
- **Not `/spar`.** `/spar` is an adversarial attack-and-fix loop against a *running target*. `/consolidate`
  never attacks or executes anything in the folder it scans; it only reads file metadata/content to classify
  files and, once approved, moves/archives/merges them.
- **Not a generic file-deletion tool.** Research for this skill (2026-07) found no existing Claude Code skill
  with a genuine two-invocation safe-mode/auto-mode split for directory consolidation — the closest real
  candidates (`ComposioHQ/awesome-claude-skills`'s `file-organizer`, `smithjoshua`'s PARA-method organizer) both
  fold approval into a single conversational yes/no inside one invocation, and the PARA one is scoped to a
  fixed Projects/Areas/Resources/Archive taxonomy rather than adapting to whatever structure a folder already
  has. `/consolidate` is a from-scratch build informed by, but not copied from, either: it borrows the general
  detection shape (dedupe by hash, staleness by mtime + inbound-reference absence, archive-over-delete) that
  `file-organizer` gets right, and the audit-trail discipline (`smithjoshua`'s manifest) shows up here as the
  mandatory plan-then-log record — but it keeps the two literally separate modes/invocations Douglas asked
  for, and it adapts to the folder's own existing structure instead of forcing PARA onto it.

## Procedure

### Step 0 — Resolve PATH and MODE from ARGUMENTS

Needs: which folder (absolute path — if ARGUMENTS gives a relative or ambiguous one, resolve it and say what
you resolved it to; if no path is given and none is obvious from the conversation, ask rather than guessing at
a target). Parse `--mode safe|auto` (**default `safe`** — this default is load-bearing, never silently treat a
bare `/consolidate <path>` as permission to execute). Parse an optional `--plan <path-to-approved-plan>`.

- **`--mode safe`** (default): analyze the folder fresh and produce a PROPOSED PLAN, then STOP. Nothing is
  moved, archived, merged, renamed, or deleted. This is the only mode that runs when Douglas hasn't already
  reviewed a plan for this folder.
- **`--mode auto`**: execute a plan. Requires either `--plan <path>` pointing at a plan file Douglas already
  reviewed (from a prior `--mode safe` run), or an explicit instruction in the same message that names specific
  approved actions ("just do it", "execute that plan", "go ahead with everything you listed"). **If `--mode
  auto` is invoked with no prior plan and no explicit approval to point to, do not proceed as if approved** —
  fall back to `--mode safe` and say plainly that there was nothing to execute yet, only something to propose.

### Step 1 — Enumerate the folder

Walk the target folder (recursively, but do not descend into `.git/`, `node_modules/`, `.venv/`,
`__pycache__/`, or other tool-managed directories whose contents are regenerable — note them as skipped, don't
silently ignore their existence). For every file record: path, size, content hash (for real duplicate
detection, not just name-matching), mtime, and extension/type. For every subfolder, note whether it looks like
a **curated structure** (has a README/index, consistent naming, cross-references from other files — e.g.
Douglas's own `artifacts/{decisions,signals,tasks}/` pattern with per-folder README contracts) versus an
**unmanaged pile** (a `_backups/`-style folder that only ever grows, dated/numbered filenames with no index).
Curated structures are a signal to leave alone, not a target.

### Step 2 — The already-organized gate (mandatory, before classifying anything as clutter)

Before proposing any action, check whether the folder — or the specific subfolder in question — is already a
deliberately-maintained structure rather than accidental clutter:

- Does it have its own README/index describing its contract (Douglas's `artifacts/*/README.md` pattern)?
- Is it under active, recent write activity consistent with ongoing use, not abandonment?
- Is it a project's tracked working directory (version-controlled, referenced by other live files) rather than
  a scratch/output dump?

If a subfolder passes this gate, exclude it from the clutter analysis entirely and say so in the report (e.g.
"`artifacts/` is a curated, indexed structure — excluded from consolidation candidates") rather than silently
proposing to touch it. This gate exists specifically so a genuinely well-organized area of the folder never
gets caught in the same net as its crusty neighbors.

### Step 3 — Detect, with evidence (never guess)

For everything that survives Step 2's gate, classify against these patterns — every finding must cite the
concrete evidence, not a hunch:

- **Exact duplicate** — two files share an identical content hash. Evidence: the hash match itself, both paths,
  both sizes.
- **Near-duplicate / multiple drafts of one artifact** — same base name with version-ish suffixes (`-v2`,
  `-final`, `-draft`, `(1)`, a trailing date), or files whose content is clearly the same artifact at different
  points in time (e.g. two formats of the same working document, like a paired `.md`/`.html` export of one
  recon note). Evidence: name-stem match + size/mtime pattern, or a direct content comparison showing they
  describe the same subject.
- **Stale/superseded backup pile** — a `_backups/`-style folder (or `.bak`/`.old`/`.proposed`/`CORRUPT`-tagged
  files sitting loose) holding older point-in-time copies of a file that still exists live elsewhere. Evidence:
  the backup's content hash differs from the live file's (a genuine old snapshot) or matches it exactly (a
  redundant copy with zero unique value); the live file's own recency; whether anything references the backup
  by name.
- **Orphaned / dead file** — nothing else in the folder or the wider project references it (grep for the
  filename/title across sibling and parent-project files), and its mtime is old relative to the rest of the
  folder's active work. Evidence: the reference search came back empty, plus the mtime gap. A file can be old
  AND still genuinely referenced — that is NOT orphaned, don't flag it.
- **Redundant nested tool output** — a subfolder whose contents are a byte-identical (or near-identical, stale)
  copy of files already promoted/copied to a parent level, typically a tool's own staging/working directory
  left behind after its real output was copied out. Evidence: hash match against the promoted copy, plus the
  subfolder's own internal markers (cache dirs, dated snapshot subfolders, tool-specific marker files) showing
  it's disposable intermediate state rather than a second independent artifact.

### Step 4 — Build the proposed plan (safe mode's entire deliverable)

For every finding, decide a recommendation using **archive-not-delete as the default for anything destructive**
— matching how `docs-update` already handles this for stale docs (move to an `_archive/` or similarly-named
subfolder with a timestamp, never a hard delete) unless Douglas has explicitly said delete is fine for that
specific case in this conversation:

- **keep** — evidence didn't clear the bar; explain why it was considered and ruled out.
- **archive** — move to a timestamped `_archive/` (or into the existing `_backups/`-style folder if one already
  exists and fits) rather than delete. The default action for stale/superseded/orphaned/redundant-nested-output
  findings.
- **merge-then-archive** — for near-duplicate drafts of one artifact: name which version is canonical, note
  what (if anything) unique in the others needs folding in first, then archive the rest.
- **delete** — proposed ONLY for exact-duplicate byte-for-byte copies with zero unique value (Step 3's first
  bullet) where archiving would add no information an identical sibling doesn't already carry, AND only ever
  as a *proposal* in this plan — never executed without Douglas's explicit per-case sign-off, even in auto
  mode. If in doubt, propose archive instead.
- **rename** — for unclear naming that would benefit from a clearer name, without changing location.

The plan must be **concrete and file-by-file (or evidenced group-by-group for large uniform sets, e.g. "7
backup copies of X, keep newest, archive the rest")** — never a vague "clean up the old stuff" summary. For
each line: the path(s) involved, the finding type, the evidence, the recommended action, and the destination
path if it's a move/archive/merge.

### Step 5 — Act per mode

- **`--mode safe`** (default): write the plan (see Step 4) to a file — `<target-folder>/_consolidate-plan-<date>.md`
  if the target folder itself is a reasonable place for it, otherwise alongside it — AND print it fully in
  chat. **Change nothing.** End by stating plainly that this is a proposal awaiting approval, and how to
  execute it (`--mode auto --plan <path>` once reviewed, or naming the specific approved subset).
- **`--mode auto`**: re-read the approved plan file (or the specific approved actions named in the invoking
  message), execute exactly those actions and no others — no re-deciding, no expanding scope, no "while I'm at
  it" extras. For every move/archive, create the destination folder if needed, preserve the original filename
  (with a timestamp suffix if archiving alongside a same-named file already there), and log the action. If
  ANY item in the plan is ambiguous about destination or was never actually approved (e.g. it appears in the
  plan file but Douglas's approval message excluded it), skip that item, do not guess, and report it as
  skipped-not-approved rather than silently acting on it.

## Safety constraints

- **Safe mode is the default and never silently escalates.** A bare `/consolidate <path>` with no `--mode` flag and
  no prior approved plan MUST run safe mode and stop at the proposal. Auto mode only runs against a plan
  Douglas has actually seen — either from a completed safe-mode run or an explicit in-message approval of
  named actions.
- **Archive, never hard-delete, by default.** Anything destructive defaults to a move into a timestamped
  archive subfolder. A hard delete is proposed only for exact byte-identical duplicates with zero unique
  content, and even then it is never executed without Douglas's explicit per-case sign-off — auto mode does
  not treat "it was in the plan" as sign-off for a delete unless the delete itself was specifically what he
  approved.
- **Never run with elevated/bypass permissions.** Default tool permissions for every step, in both modes.
- **No commits, and no changes outside the target folder**, other than writing the plan file itself. If the
  target folder is inside a git repo, do not stage or commit any moves this skill makes — leave that to
  Douglas.
- **Never act on a folder that failed the Step 2 already-organized gate.** A curated structure is excluded
  entirely, not "moved with extra care."
- **Every plan-mode run is read-only against the target folder.** Enumeration, hashing, and reference-searching
  never write, move, or modify anything in the folder being scanned — only the plan file itself is written, and
  only in safe mode.
- **State evidence for every finding.** If you cannot tell whether a file is safe to archive (unclear whether
  it's still referenced, unclear which draft is canonical), list it in the plan as a flagged item needing
  Douglas's judgment call rather than picking a side.

## Final report (what to tell Douglas)

**If safe mode ran** (the default, and what every first run against a new folder should be):
- State plainly: **nothing was moved, archived, merged, renamed, or deleted** — this is a proposal.
- The full plan, file-by-file or evidenced group-by-group, each with its finding type, evidence, and
  recommended action.
- What was excluded by the Step 2 gate (curated structures left alone), so Douglas can see the boundary was
  respected, not just the clutter found.
- Anything flagged as needing his judgment call rather than a confident recommendation.
- The path of the written plan file, and the exact follow-up (`--mode auto --plan <path>`, or naming the
  approved subset) that would execute it.

**If auto mode ran:**
- Which plan/approval was executed (path or the named actions), and confirmation every action taken matches
  exactly what was approved — nothing expanded in scope.
- Per action: what moved from where to where (or what was merged/renamed), never "cleaned up X" as a summary
  without the concrete before/after paths.
- Anything in the plan that was skipped because it wasn't actually approved, or turned out ambiguous at
  execution time, with why.
- Full absolute path(s) of everything touched, per the standing Files-list convention.

**Never claim "folder is now clean" or "fully organized."** Report what was found and proposed (safe mode) or
what was actually moved (auto mode) — a folder can always accumulate more crust the moment work resumes in it;
this is a point-in-time pass, not a guarantee.

---

*Tracked copy: also save this file to `claude-global-config/commands/consolidate.md` (per the skills-are-tracked
convention) after a NASA scrub.*
