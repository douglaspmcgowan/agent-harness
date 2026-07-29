---
name: daily-review
description: Daily analysis of work done across all repos and sessions. Identifies debugging patterns, learned lessons, and automation candidates. Directly edits playbooks for patterns it can improve. Writes a report of things worth automating but not auto-applied. Invoked by the daily scheduled task or manually with /daily-review.
---

# /daily-review

## Purpose

Every day, look at what actually happened — the git commits, the session patterns, the repeated manual steps — and turn the useful signal into:

1. **Direct playbook edits**: If yesterday's work revealed a fix, a pattern, or a lesson that fits an existing playbook, add it now. Don't wait for the user to invoke `/make-playbook`.
2. **New playbook**: If a new repeatable pattern emerged with enough steps to be useful, generate a new playbook.
3. **Daily report**: For automation candidates that need user judgment (new hooks, new skills, config changes), write a scannable report. Don't auto-apply these — propose them.

---

## Phase 1 — Collect context

Run all of these before analyzing:

### 1a. Git activity (last 24h across all repos)

```bash
$repos = @(
  "C:\Users\dougl\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\psych-battery-app",
  "C:\Users\dougl\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\ai-in-design-map",
  "C:\Users\dougl\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\dfm-graph-explorer",
  "C:\Users\dougl\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\dpm-sites",
  "C:\Users\dougl\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\ai-schools-of-thought-explorer",
  "C:\Users\dougl\dpm-research-hub"
)
```

For each repo with git: `git log --since="25 hours ago" --oneline --stat` (25h for overlap safety).
For non-git dirs: find files with mtime < 24h using Glob.

### 1b. Session JSONL — extract debugging arcs

Scan `C:\Users\dougl\.claude\projects\` — find all `.jsonl` files modified in the last 24h.

For each file found:

**Step 1 — size-based read strategy:**

- `< 2 MB` → read the whole file
- `2–10 MB` → read first 400 lines + last 300 lines (session start + recent work)
- `> 10 MB` → read first 200 lines + last 200 lines; also grep for error-signal lines (see Step 2)

**Step 2 — extract signal lines with Bash:**

```bash
# Find lines containing error/fix signals. Adjust path per session file.
grep -in '"text"' <session.jsonl> | grep -iE "(error|failed|not working|broken|can't|doesn't|exception|traceback|exit code [^0]|unexpected|fix|resolved|workaround)" | head -120
```

Parse these lines as JSON fragments to reconstruct the message text.

**Step 3 — identify debugging arcs:**
A debugging arc = a problem statement followed by ≥2 back-and-forth turns before resolution.
Look for these patterns in the extracted lines:

- User message describing a problem or unexpected result
- Tool result showing a non-zero exit code or stderr output
- Repeated Bash commands with small variations (sign of trial-and-error)
- An assistant message containing "the fix", "the issue was", "this resolves", or similar
- A tool call that finally succeeds after previous failures

For each arc, record:

- **What broke**: one-line description of the error or symptom
- **How many turns**: rough count of exchanges before resolution
- **What fixed it**: the actual fix or root cause
- **Playbook match**: does this error appear in any existing playbook's "Common errors" table?

**Step 4 — map session to project:**
The JSONL path is `~/.claude/projects/<encoded-path>/<session-id>.jsonl`.
The `<encoded-path>` is the working directory with path separators replaced by `-`.
Decode it to identify which project the session was in.

### 1c. Existing playbooks

Read all `Claude Research Folder/playbooks/*.md` headings (H1 and H2 only).
Read the PLAYBOOK.md index sections from project folders.
This is the "what already exists" baseline for Phase 2.

### 1d. Hooks and skills inventory

Read `C:\Users\dougl\.claude\settings.json` hooks section — note what's currently registered.
Glob `C:\Users\dougl\.claude\skills\*/SKILL.md` — note what skills exist.

---

## Phase 2 — Analyze

With the collected context, identify:

### A. Playbook improvement candidates

Cross-reference **both** the git log and the session arcs:

- Session arc where `Playbook match = none` AND took ≥3 turns → new "Common errors" row in the most relevant playbook, or a new playbook if the pattern is general
- Session arc where `Playbook match = [existing playbook]` → the fix is already documented; verify the existing entry is accurate, update if not
- A commit message that describes fixing the same error as a previous commit → the playbook entry is missing or unclear; strengthen it
- Multiple git commits to fix one thing (arc visible in both session + git) → highest-confidence playbook candidate; extract the full arc
- A commit touching deploy/config files → check whether the deploy playbook or preflight skill covers it
- A session working in a repo that has a PLAYBOOK.md but the arc wasn't covered → add to that project's playbook directly

For each candidate: decide whether to **edit an existing playbook** (prefer) or **create a new one**.

### B. New playbook candidates

Only create if ALL are true:

- 3+ distinct steps required
- Will clearly happen again (not project-specific one-off)
- Not already covered by an existing playbook

### C. Automation candidates (for report only, do not auto-apply)

Look for:

- A manual step done twice in git log or session metadata → candidate for a hook or script
- A file pattern that's always the same boilerplate → candidate for a template
- A check that failed and could have been caught earlier → candidate for a PreToolUse hook
- A session that ran very long on a single repo → candidate for a rollover reminder hook
- A deploy that needed debugging → candidate for adding a step to the deploy playbook or preflight

Rate each: **High / Medium / Low** based on how much time it wasted or would save.

---

## Phase 3 — Apply playbook updates

For each playbook improvement identified in Phase 2A:

1. Read the target playbook file.
2. Make the specific, minimal edit:
   - Add a row to the "Common errors" table
   - Add a step to the process
   - Update a "Decisions log" entry
   - Add a "Gotcha" callout
3. Write the updated file.
4. Note the edit in the report (Phase 4) under "Auto-applied today."

For new playbooks (Phase 2B): invoke the `/make-playbook` procedure (Phase 3–4 of that skill).

---

## Phase 4 — Write the daily report

Write to: `C:\Users\dougl\My Drive (douglaspmcgowan@gmail.com)\UC Berkeley\Research\Claude Research Folder\codex-outputs\daily-reports\YYYY-MM-DD.md`

Use this structure:

```markdown
# Daily Review — [YYYY-MM-DD]

Generated: [timestamp]
Repos scanned: [N] Sessions active: [N] Commits in window: [N]

---

## Auto-applied today

[List of playbook edits made directly. Format:]

- **[playbook name]** — added "[what was added]" to [section]
- (none) if nothing was improved

---

## New playbooks created

- **[name]** → saved to `[path]`
- (none)

---

## Automation candidates (your review needed)

### High priority

- **[Pattern observed]**
  What happened: [1–2 sentences]
  Proposed fix: [hook / script / skill / playbook addition]
  Estimated time saved: [rough estimate]

### Medium priority

- ...

### Low priority

- ...

---

## Session debugging arcs

[One block per session file that had activity. Format:]

### [Project name] — session [first 8 chars of session ID], [file size]

| #   | What broke                   | Turns to fix | What fixed it              |
| --- | ---------------------------- | ------------ | -------------------------- |
| 1   | [error or symptom, one line] | [N turns]    | [actual fix or root cause] |
| 2   | ...                          |              |                            |

**Longest arc:** [which one, why it took so long]
**Playbook gap:** [yes/no — if yes, which playbook and what row was added]

[If no arcs detected: "No debugging arcs — clean session."]

---

## Commit summary

[Repo-by-repo table:]
| Repo | Commits | Files changed | Theme |
|------|---------|--------------|-------|
| psych-battery-app | 3 | 12 | Bug fixes in demo mode |
| ... | | | |

---

## Session notes

[Any notable patterns from JSONL metadata — e.g., large session on X repo, multiple compactions, etc.]

---

_Next review: tomorrow at 7am via Windows Scheduled Task `dpm-daily-review`_
_To skip: `Disable-ScheduledTask -TaskName dpm-daily-review`_
```

---

## Phase 5 — Notify

After writing the report:

```powershell
powershell.exe -NoProfile -WindowStyle Hidden -Command "
  (New-Object -ComObject Wscript.Shell).Popup(
    'Daily review complete. Report written to codex-outputs/daily-reports/',
    8, 'Claude Daily Review', 64
  ) | Out-Null
"
```

---

## Operating constraints

- **Do NOT** auto-apply changes to `.claude/settings.json`, hooks, or skills. Only PROPOSE these in the report. The user reviews and approves.
- **DO** auto-apply edits to markdown playbooks (they're cheap to undo, high value to capture).
- If a repo has no commits in the window and no file changes, skip it in one line: "No activity."
- If a JSONL session is >16 MB, note it in the report under "Session notes" — this is a rollover candidate.
- Keep the report SHORT and SCANNABLE. The user should be able to read it in 90 seconds.
- If there is genuinely nothing to report (no commits, no sessions, small day), write a minimal report: just the commit summary and "No automation candidates today."
