---
name: daily-activity
description: Combined daily report — what Douglas built + debugging arcs + playbook auto-edits + automation candidates. Writes to NASA_GSFC_Vault_1/Daily Reports/YYYY-MM-DD.md. Invoked manually with /daily-activity (yesterday), /daily-activity YYYY-MM-DD (one day), or /daily-activity catch-up (backfill every missing day from the last report through today), or by the Windows scheduled task ClaudeDailyActivityReport (daily 09:30, StartWhenAvailable).
---

# /daily-activity

## Purpose

Every morning, produce a single combined report covering two lenses:

1. **Activity** — what was built and where it lives. Agent-pack rewrites, slide decks, new vault notes, project pivots. Readable in 60 seconds.
2. **Review** — what debugging patterns emerged, what playbook edits to auto-apply, what automation candidates to flag for Douglas's review.

Single output file: `NASA_GSFC_Vault_1/Daily Reports/YYYY-MM-DD.md`.

The activity sections read like the existing `2026-06-04.md` entry — concrete, terse, weight on artifacts. The review appendix sits below a horizontal rule and is skimmable separately.

---

## Phase 0 — Determine the target date(s)

Three modes, decided by the argument:

- **No argument** → target = yesterday (today's local date − 1). One date.
- **Explicit date** (`/daily-activity 2026-06-03`) → that single date.
- **Catch-up** (`/daily-activity catch-up`; also accept `catchup` / `catch up`) → backfill every missing day:
  1. List the existing `YYYY-MM-DD.md` files in `NASA_GSFC_Vault_1/Daily Reports/` (ignore `.vN` variants) and find the most recent date with a report.
  2. Build the target list = every date from (most-recent-report + 1) through **today**, inclusive, in chronological order (oldest first).
  3. If that list is empty (most recent report is already today) → output "Already current through today (YYYY-MM-DD); nothing to catch up." and stop.
  4. If the list has > 14 dates → print the list and confirm with Douglas before proceeding (avoids a runaway multi-week scan).
  5. Otherwise run Phases 1–5 once per date, oldest first, each writing/appending its own `YYYY-MM-DD.md`.
  6. **Today is expected to be partial** — when the target date == today, add "(partial — same-day run)" to that report's overview line. A later same-day or next-day run appends an addendum per Phase 4 rather than duplicating.

Compute each `YYYY-MM-DD` and use it consistently for that day's scanning and output filename.

---

## Phase 1 — Collect raw signal

Run all of these. Parallelize where possible.

### 1a. Claude session JSONLs modified on the target date

Scan these directories for `.jsonl` files whose mtime falls on the target date:

- `C:\Users\dmcgowa2\.claude\projects\C--Users-dmcgowa2-Documents-Claude-GSFC-Folder\`
- `C:\Users\dmcgowa2\.claude\projects\C--Users-dmcgowa2-Documents-Claude-NASA-Folder\`
- `C:\Users\dmcgowa2\.claude\projects\C--Users-dmcgowa2-Documents-Codex-NASA-Folder\`
- `C:\Users\dmcgowa2\.claude\projects\C--Users-dmcgowa2\` (legacy)

**Per-file read strategy (size-gated):**

- `< 2 MB` → read the whole file
- `2–10 MB` → read first 400 lines + last 300 lines
- `> 10 MB` → read first 200 lines + last 200 lines; also run the grep below

**Debugging arc extraction (run on every file, grep first for large ones):**

```bash
grep -in '"text"' <session.jsonl> \
  | grep -iE "(error|failed|not working|broken|can't|doesn't|exception|traceback|exit code [^0]|unexpected|fix|resolved|workaround)" \
  | head -120
```

Parse the matched lines as JSON fragments to reconstruct message text.

**Per-session, record:**
- First user prompt (skip `<system-reminder>` and continuation blocks) — identifies the thread topic
- Approximate time span (first → last timestamp in file)
- Any debugging arcs (see Phase 2b for arc definition)

### 1b. Files modified on the target date

Walk these roots, exclude `_backups`, `.git`, `node_modules`, `.obsidian`, `.smart-env`, `.smart-chat-conversations`:

- `C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\`
- `C:\Users\dmcgowa2\Documents\Claude GSFC Folder\`

Record file path + mtime for everything where `date(mtime) == target_date`.

### 1c. Git activity (last 25h across all repos)

```
C:\Users\dmcgowa2\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\psych-battery-app
C:\Users\dmcgowa2\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\ai-in-design-map
C:\Users\dmcgowa2\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\dfm-graph-explorer
C:\Users\dmcgowa2\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\dpm-sites
C:\Users\dmcgowa2\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\ai-schools-of-thought-explorer
C:\Users\dmcgowa2\dpm-research-hub
```

For each repo with git: `git log --since="25 hours ago" --oneline --stat`. Skip repos with no activity in one line.

### 1d. Codex run outputs

If `Claude GSFC Folder/.codex-runs/` has files with the target date in the filename or mtime, list them.

### 1e. Memory writes

Check `C:\Users\dmcgowa2\.claude\projects\C--Users-dmcgowa2-Documents-Claude-GSFC-Folder\memory\` for files modified on the target date — captured durable lessons.

### 1f. Existing playbooks + hooks/skills inventory

Read all `Claude Research Folder/playbooks/*.md` headings (H1 and H2 only) — this is the baseline for Phase 2b.
Read `C:\Users\dmcgowa2\.claude\settings.json` hooks section — note what's currently registered.

---

## Phase 2 — Group and analyze

### 2a. Group sessions + files into activity threads

Cluster by topic across session files, file mtimes, Codex outputs, and git commits. Common thread patterns:

- **TTC agent pack** — `NASA Ignition/flat/`, `davinci-ttc-context.zip`, sessions about "personas" / "phases" / "rules" / "core-rules" / "TURN-CHECK"
- **IDETC paper deck** — `Presentations/IDETC 2026*.pptx`, sessions about "slides" / "deck" / "v3" / "v4"
- **Text-to-Structure / <project-codename>** — `Text-to-Structure/`, sessions about "<project-codename>" / "bolt locations" / "drone bracket" / "IDA agent"
- **Text-to-Truss** — `Text-to-Truss/`, sessions about "MYSTRAN" / "Track A/B/C" / "truss optimization"
- **DaVinci API / SDK** — `DaVinci/API/`, `DAVINCI_PAT`, sessions about API health, endpoint metadata, schema
- **Security hooks / wmux** — `~/.claude/hooks/`, `Claude/AI Security Pack/`, sessions about "401" / "INVALID_API_KEY" / "env-dump"
- **Daily-review / inventory / setup** — `System Inventory.md`, sessions about reviewing the previous day or installing tools

For each thread, find:
- Time span (earliest → latest mtime across sessions and files)
- 1-paragraph description using Douglas's own phrasing from session prompts
- 3–6 bullet artifacts (file paths, vault links, backup names)
- Pull-quote if there's a sharp one (*"…"* — em-dash attribution)
- Loose ends only if the session ended unresolved

Threads smaller than 30 min with a single session → one-line bullet in a "One-liners" section.

### 2b. Identify debugging arcs

A debugging arc = a problem statement followed by ≥2 back-and-forth turns before resolution.

Signs of an arc in extracted lines:
- User message describing a problem or unexpected result
- Tool result with non-zero exit code or stderr
- Repeated Bash commands with small variations (trial-and-error)
- Assistant message containing "the fix", "the issue was", "this resolves"
- A tool call that finally succeeds after previous failures

For each arc, record: **What broke** / **Turns to fix** / **What fixed it** / **Playbook match** (existing playbook that covers this, or "none").

### 2c. Playbook improvement candidates

Cross-reference git log and session arcs:

- Arc with `Playbook match = none` AND ≥3 turns → new "Common errors" row in the most relevant playbook, or a new playbook if the pattern is general
- Arc with `Playbook match = [existing]` → verify the existing entry is still accurate, update if not
- Commit touching deploy/config files → check whether the deploy playbook covers it
- Multiple commits to fix one thing → highest-confidence candidate; extract the full arc

Only create a new playbook if: 3+ distinct steps, will clearly recur, and not already covered.

### 2d. Automation candidates (for report only — do not auto-apply)

Look for:
- A manual step done twice in git log or session metadata → hook or script candidate
- A file pattern that's always the same boilerplate → template candidate
- A check that failed and could have been caught earlier → PreToolUse hook candidate
- A session that ran very long on a single repo → rollover reminder hook candidate

Rate each: **High / Medium / Low** by time wasted or saved.

### 2e — Adversarial gap check

Before moving to Phase 3, challenge your own findings. This catches the most common miss: sessions that started on an earlier date but have target-date content because they ran long or were resumed.

1. **Unread session files** — go back to the raw file list from 1a. For every file with target-date mtime that you haven't yet read a first prompt from, check the tail (last 200 lines or `tail -c 2000`) for target-date timestamps. Any file whose tail has target-date content is a live session that ran on the target date — treat it as a thread.
2. **Mtime ≠ start date** — for each session you classified as "started earlier, compacted on target date," confirm by checking the FIRST timestamp in the file. If `first_timestamp.date < target_date` and `last_timestamp.date == target_date`, it's an ongoing session: read the tail and add any target-date work as a thread.
3. **Vault file orphans** — count vault files from 1b. If that count is higher than the number of artifact bullets in your thread write-ups, name the delta. Go find which session wrote the unaccounted files.
4. **Output Dropbox already has it** — scan the Output Dropbox now (before Phase 5) for any artifacts dated the target date. If something is there that isn't in your thread write-ups, it belongs in the report.
5. **Long-running sessions** — any session file > 5 MB with target-date mtime is likely a multi-day runner. Read its tail before dismissing it.

If any of these checks surface new material, add it as a thread or one-liner before writing the report.

---

## Phase 3 — Auto-apply playbook edits

For each improvement from Phase 2c:

1. Read the target playbook file.
2. Make the minimal edit: add a "Common errors" row, add a step, update a "Decisions log" entry, or add a "Gotcha" callout.
3. Write the updated file.
4. Record the edit in the report under "Auto-applied today."

For new playbooks (Phase 2c, new-playbook case): invoke the `/make-playbook` procedure.

**Do NOT** auto-apply changes to `.claude/settings.json`, hooks, or skills. Propose those in the report only.

---

## Phase 4 — Write the combined report

Output path: `C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\Daily Reports\YYYY-MM-DD.md`

If that file already exists, **append** to it — do not create a v2 file. Add a `---` separator followed by `## Addendum — [HH:MM] run` and include only the threads and findings not already in the file. Duplicate nothing from the existing content.

If there were no sessions and no file changes, output "No activity on YYYY-MM-DD" to chat and skip the file.

Structure:

```markdown
# Daily Report — YYYY-MM-DD

[1-paragraph overview: number of activity threads, dominant arcs, anything unusual.]

## [Thread name] (~HH:MM–HH:MM) [— optional descriptor]
[1-paragraph what + why, in Douglas's voice.]
- Artifact / file path / wikilink.
- Artifact.
- Memory written: `name.md`.
- Quote: *"…"* — if there's a sharp one.

## [Next thread] (~HH:MM–HH:MM)
…

## One-liners
- Small thread / single-session item (<30 min).

## Loose ends going into [next-day date]
- Specific, actionable. One bullet per item.

---

## Review

### Auto-applied today
- **[playbook name]** — added "[what]" to [section]
- (none) if nothing was improved

### Automation candidates

**High priority**
- **[Pattern]** — [1–2 sentences]. Proposed: [hook / script / skill]. Time saved: [estimate].

**Medium / Low priority**
- …

### Debugging arcs

#### [Project name] — session [first 8 chars], [size]
| # | What broke | Turns | What fixed it |
|---|-----------|-------|--------------|
| 1 | … | N | … |

**Longest arc:** [which one, why]
**Playbook gap:** [yes/no — if yes, what was added]

[If no arcs: "No debugging arcs — clean session."]

### Commit summary
| Repo | Commits | Files changed | Theme |
|------|---------|--------------|-------|
| … | … | … | … |
```

Formatting rules:
- **Obsidian wikilinks** (`[[Folder/Filename]]` or `[[Filename]]`) for vault notes.
- Backtick-quoted relative paths for non-vault files (e.g., `` `.codex-runs/review-….md` ``).
- 24-hour times, rounded to nearest 5 min for thread spans.
- Pull-quotes in italics with em-dash: *"the security hooks should not fully stop your turn"*.
- Match Douglas's voice — concrete, terse, weight on artifacts. No editorializing.
- **Never the "X, not Y" antithesis.** State the positive claim and stop.
- Name failures and pivots plainly. Don't smooth over them.
- Activity threads readable in ~60 seconds; review appendix skimmable in ~30 more.

---

## Phase 5 — Update Output Dropbox

Always run this phase. Read `NASA_GSFC_Vault_1/Output Dropbox.md` and check whether any artifact from the target date (or discovered during this run) is missing from it.

**What belongs in the Output Dropbox:**
- New Obsidian notes in any `Claude/`, `Research/`, `AI for CAD/`, `Text-to-*/`, `NASA Ignition/`, or project subfolder
- New or updated presentations, HTML tools, agent packs, canvases, or zip distributables
- New reference docs imported into the vault (even large ones — just a 1-line pointer)
- New deployed sites / Vercel links
- Updated skill or hook files worth cross-referencing

**What does NOT belong:**
- `Task Planner.md`, `To-Do.md`, `_backups/`, `.obsidian/` internals, `.smart-env/`
- Tiny edits to existing entries (word changes, typo fixes)

**How to update:** Use `Edit` for surgical changes — never overwrite the whole file. Add a bullet under the relevant existing entry, or a new top-level entry with 2–4 bullets. Match the existing flat-list-with-bullets format. Update stale version numbers (e.g., "v7" → "v12") in place. Don't restructure.

---

## Phase 6 — Done

Output to chat: report path + 2-line summary (number of threads, biggest thread, number of playbook edits auto-applied). Nothing else.

If invoked from the scheduled task (non-interactive), no chat output needed — exit 0.

---

## Operating constraints

- **Never read API keys or env-var values** (CLAUDE.md hard rule).
- **Never overwrite Douglas's authored files.** Daily Reports files are generated content — overwriting a prior report with the same date is fine; overwriting Output Dropbox or any vault note Douglas authored is not. Use Edit for surgical changes.
- JSONL sessions >16 MB: note in "Session notes" under the review appendix — these are rollover candidates.
- Skip repos with no activity in one line: "No activity."
- Keep the report SHORT and SCANNABLE.
