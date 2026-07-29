---
name: clean-downloads
description: Sort new files in Doug's Downloads folder into their existing Google Drive folders (mounted locally at G:\My Drive), leave installers alone, quarantine sensitive files, and delete known junk. Tracks a last-run timestamp so each run only looks at files added since the previous run. Use when Doug says "clean up my downloads", "organize downloads", or invokes /clean-downloads.
---

# Clean Downloads

Sorts `C:\Users\dougl\Downloads` into Doug's existing Google Drive folder structure
(`G:\My Drive\...`, a local mount — no API needed, just filesystem `mv`).

## Core rule: use existing folders, don't invent new ones

Before proposing any destination, check whether a matching folder already exists.
**Only exception:** create `G:\My Drive\Actual Documents\Sensitive` if it doesn't exist yet
(it should, after the first run) — that one folder is pre-approved. Also
`G:\My Drive\Actual Documents\People\<Name>` folders may be created per person as needed
(check for an existing same-name folder first — e.g. `Dad` already exists after 2026-07-05).

For anything that doesn't match a known rule below, search before asking:

```bash
find "/g/My Drive" -maxdepth 4 -iname "*<keyword>*" 2>/dev/null
```

Search 2-3 keyword variants (e.g. course name, company name, person name, project name) before
concluding nothing exists. Only propose a brand-new folder as a last resort, and call it out
explicitly to Doug rather than creating it silently.

## Step 1 — check last run time

Read `C:\Users\dougl\.claude\skills\clean-downloads\state.json`:

```json
{ "lastRunCompletedAt": "2026-07-05T00:00:00-07:00" }
```

If the file doesn't exist, this is the first run — consider all files in Downloads.
Otherwise, only consider files whose `LastWriteTime` is after `lastRunCompletedAt`:

```powershell
Get-ChildItem -Path "$env:USERPROFILE\Downloads" -File | Where-Object { $_.LastWriteTime -gt [datetime]"2026-07-05T00:00:00-07:00" }
```

If nothing qualifies, tell Doug Downloads is already clean since the last run and stop —
don't re-litigate files already sorted or already deliberately left in place.

## Step 2 — never touch these

Leave in Downloads, no matter how old: `.exe`, `.msi`, `.msix`, and anything that is clearly
an installer/app update by name. Don't propose moving or deleting these.

## Step 3 — categorization rules (established 2026-07)

Known destination folders under `G:\My Drive\` — check these first, they've been confirmed to exist:

| Category                                                             | Destination                                                                                                         | Notes                                                         |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| Tax documents (W2, 1098-T, combined tax packets)                     | `Actual Documents\Taxes\<year>`                                                                                     | year subfolder already exists back to 2022                    |
| Passwords, 2FA/recovery codes, credential screenshots                | `Actual Documents\Sensitive`                                                                                        | quarantine, don't leave in Downloads                          |
| Estate/legal instruments (will, power of attorney, health directive) | `Actual Documents\Sensitive`                                                                                        |                                                               |
| Berkeley house lease/sublease documents                              | `Obsidian\Metropolis Pt. 1--The Maverick And The Test\Berkeley House`                                               |                                                               |
| AFRL/current internship paperwork                                    | `Summer 2026 Internship` (or whatever the active internship folder is named — check for the current year's version) |                                                               |
| Ebooks (.azw3, .epub, book-length PDFs)                              | `Books`                                                                                                             |                                                               |
| AMAX Elite / Aunt Anna's notary business assets                      | `Aunt Anna's Business Projects`                                                                                     |                                                               |
| Flight/hotel/travel confirmations                                    | `Travel`                                                                                                            | drop at root unless a trip-specific subfolder already matches |
| UC Berkeley coursework, exam materials, class files                  | `UC Berkeley` (check for a course-specific or `Coursework` subfolder first)                                         |                                                               |
| Voice memos / audio recordings meant for transcription               | `Audio for Transcription`                                                                                           |                                                               |
| Official grad school admin docs                                      | `Grad School`                                                                                                       |                                                               |
| Generic personal photos/screenshots not tied to a project            | `Pictures\Camera Roll`                                                                                              |                                                               |
| Gifts / docs for a specific family member                            | `Actual Documents\People\<Name>`                                                                                    | create the person's folder if it doesn't exist                |
| Misc personal admin (voter registration, etc.) with no better fit    | `Actual Documents` (root)                                                                                           |                                                               |

For anything not covered above, search Drive per the Core Rule before guessing.

## Step 4 — known junk (propose deleting, always confirm before deleting)

- Superseded numbered drafts of the same document once a later version exists (e.g. `_v2`, `_v3`
  when `_v4` is the final one being filed) — keep only the latest version filed, delete the rest
- Word/Excel lock files (`~$*.docx`, `~$*.xlsx`)
- Throwaway single-purpose HTML snippets (e.g. a tiny local image-viewer page) that reference
  another file being moved/deleted anyway
- Stale duplicates of a file that lives canonically elsewhere (e.g. a downloaded copy of a guide
  that already lives in the Obsidian vault) — verify it's actually identical/superseded before
  proposing deletion, don't assume from filename alone

## Step 5 — present the plan, then execute

1. Output a table: file → proposed action (move/delete/keep) → destination or reason.
2. Flag anything ambiguous or sensitive-looking with a direct question — batch all questions
   into one message, don't ping-pong.
3. Wait for Doug's go-ahead before moving or deleting anything.
4. Execute via `mv`/`rm` (Bash, not PowerShell — path quoting is simpler). Use `mkdir -p` only
   for the pre-approved exceptions in the Core Rule.
5. `rm -rf` on directories may get blocked by the sandbox even after Doug approves — if so, tell
   him rather than retrying, and let him delete it manually.

## Step 6 — update the log

After executing (even partially — some moves done, some skipped), write the current timestamp
to `state.json`:

```json
{ "lastRunCompletedAt": "<ISO 8601 timestamp of now, with local offset>" }
```

Only update this after actually acting — if Doug hasn't confirmed anything yet, don't stamp the
log, so a re-run still picks up the same unprocessed files.

## Don't

- Don't create new folders beyond the two pre-approved exceptions without flagging it first
- Don't move/delete anything before Doug confirms the plan
- Don't re-scan files older than the last run — trust the log
- Don't touch installer/app files
- Don't guess on sensitive-looking files (credentials, legal/estate docs, SSNs) — when in doubt,
  route to `Actual Documents\Sensitive` and say so, don't leave them loose in Downloads
