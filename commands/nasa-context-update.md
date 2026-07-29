---
name: nasa-context-update
description: Scan the NASA Context Dropbox for new files and Random Dropbox entries. Research each one, create a note in Notes/, update _Map.md, reformat Random Dropbox.md, and archive processed raw files into organized subfolders. Run whenever Douglas drops new material in the folder.
---

# /nasa-context-update

## Purpose

Detect anything new in the NASA Context Dropbox that isn't tracked yet, research it, document it in `Notes/`, keep `_Map.md` and `Random Dropbox.md` current, and move processed raw files into organized archive subfolders so the dropbox root stays clear for new drops.

Canonical folder: `C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\NASA Context Dropbox\`

---

## Phase 1 — Detect what's new

### 1a. Raw files in dropbox root

List all files directly in the Dropbox root (non-recursive — subdirectory files are already notes or archived):

```powershell
Get-ChildItem "C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\NASA Context Dropbox\" -File
```

Read `_Map.md` and extract every filename already listed in the "Raw files" table. Files present on disk but absent from `_Map.md` are **new** and need processing.

Always skip: `_Map.md`, `Random Dropbox.md` (these are system files that stay in root).

### 1b. Random Dropbox.md entries

Read `Random Dropbox.md`. Any entry block that does NOT contain `**→ Note:**` is unprocessed and needs a note created.

### 1c. Scope decision

If nothing is new in either 1a or 1b, report "Nothing new in the dropbox" and stop.

If there are new items, list them to the user in one line: `"Found N new items: [names]"` — then proceed without waiting for confirmation.

---

## Phase 2 — Process each new item

Run Phase 2–3 for each new item sequentially (shared file writes to `_Map.md` must not race).

### 2a. Read the file

| Format | Action |
|--------|--------|
| `.md`, `.txt` | Read directly with Read tool |
| `.pdf` | Read with Read tool; use `pages` param if >10 pages |
| `.docx`, `.pptx`, `.png`, `.jpg`, `.xlsx`, `.mp4` | Cannot read directly — create a stub note (see Phase 3b) |
| Large `.md` with embedded base64 images | Note it's image-heavy; recommend viewing in Obsidian |

### 2b. Research with WebSearch

For every new item (even unreadable ones — research by name/topic):

1. Search the tool/concept/person name + current year
2. Search at least one human-authored source (Reddit, HN, practitioner blog)
3. Fetch 2–5 of the most relevant URLs
4. Aim for ≥2 independent sources for any factual claims; mark single-source claims with "single source"

Focus on: what it is, why it matters to Douglas's NASA/structural AI work, key people, connections to other items already in the vault.

---

## Phase 3 — Create or update notes in Notes/

File path: `C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\NASA Context Dropbox\Notes\<Descriptive Title>.md`

### 3a. Full note (file was readable OR research found enough)

```markdown
---
tags: [relevant, tags, here]
source: <original filename or URL>
researched: YYYY-MM-DD
---

# Title

## What it is
[1–2 sentence summary]

## Key details
[Specifics: links, people, data, findings. Inline citations as [source](url).]

## Relevance to Douglas's work
[Why this matters for NASA GSFC / structural AI / generative design / research]

## See also
- [[other note titles]]
```

### 3b. Stub note (file unreadable)

```markdown
---
tags: [stub, needs-manual-open]
source: <filename>
researched: YYYY-MM-DD
---

# Title (STUB)

## What it is
[Summary from research/filename alone — 1–2 sentences]

## To do
> Open `<filename>` to capture: [specific things — proposal scope, budget, acronym definition, API endpoints, etc.]

## What to look for
[Guided questions: what sections to read, what data to extract]

## Relevance to Douglas's work
[Best-guess relevance from external research]

## See also
- [[other note titles]]
```

### 3c. Forward links — populate the new note's See also

After drafting the new note, scan the existing vault for notes that the new note should link to:

1. Glob all `.md` files under `NASA_GSFC_Vault_1/` (exclude `Archive/`, `Templates/`, `.obsidian/`)
2. For each existing note whose title or content closely overlaps with the new note's topic (people mentioned, tools named, projects referenced), add a wikilink to the new note's `## See also` section.
3. Use `[[Exact File Name]]` or `[[Exact File Name|Display Text]]` — never invent a filename. Only link to files confirmed to exist.
4. Keep it tight: 2–6 links max. Only links with clear topical overlap — not tangential.

---

## Phase 4 — Update _Map.md

Read the current `_Map.md`. Add new rows to:

1. **Notes index table** — one row per new note:
   `| [[Note Title]] | tags | source filename | status |`

2. **Raw files table** — one row per new raw file (use the archive path after Phase 5 moves it):
   `| filename | type | Archive/<subfolder>/filename |`

3. **Emerging themes** — if a new item fits an existing theme or reveals a new one, update that section.

4. **To Do** — if a stub was created, add a line: `- [ ] Open <filename> → update [[Note Title]]`

Write `_Map.md` once after processing all new items (not per item, to avoid partial writes).

---

## Phase 4b — Backlink stitching (existing notes → new notes)

After all new notes are created and `_Map.md` is updated, check whether any **existing** notes should now link to the new notes.

For each new note created this run:

1. Search the vault for existing notes that mention the new note's subject — by person name, project name, tool name, or key term — but don't yet contain a wikilink to it.
   ```bash
   grep -ril "<key term>" "C:/Users/dmcgowa2/Documents/NASA_GSFC_Vault_1/" --include="*.md"
   ```
2. For each matching existing note: read its `## See also` section (or the equivalent section at the bottom).
3. If the new note is a clear topical match and not already linked, append the wikilink to that section:
   - If a `## See also` section exists: add `- [[New Note Title]]` to it.
   - If no `## See also` section exists: append one at the end of the file.
4. Only stitch links with clear topical overlap. Skip Dashboard++.md, _Map.md, and widget files — those are structural and should be updated manually.
5. Cap at 3 backlinks added per existing note per run to avoid polluting notes with tangential links.

Report all backlinks added in Phase 7.

---

## Phase 5 — Reformat Random Dropbox.md entries

For each entry that was unprocessed (lacked `**→ Note:**`), rewrite it in standard format:

```markdown
---

## <Title>
**Date added:** YYYY-MM-DD (use today if unknown)
**Type:** Tool / Article / Person / Internal doc / Dataset / Meeting notes
**Source:** <URL or filename>

<2–3 sentence description of what it is and why it matters>

**→ Note:** [[Note Title]]
```

Preserve the user's original text where it adds context; don't delete anything, just restructure and append the note link.

Write `Random Dropbox.md` once with all reformatted entries.

---

## Phase 5b — Clear Random Dropbox.md

After the reformatted entries have been written and all notes are created, overwrite `Random Dropbox.md` with just the empty-state header:

```markdown
# Random Dropbox

Drop anything here — links, names, tools, ideas, fragments. No format required. Run /nasa-context-update to process.
```

This leaves the file in place for future drops but clears all processed entries, since every item is now captured in `Notes/` and linked from `_Map.md`.

---

## Phase 6 — Archive processed raw files

After notes are created and `_Map.md` is updated, move each processed raw file from the Dropbox root into an organized archive subfolder. This keeps the Dropbox root clear for new drops.

### Archive subfolder structure

```
NASA Context Dropbox/
  Archive/
    Docs/        — .docx, .doc files
    PDFs/        — .pdf files
    Presentations/ — .pptx, .ppt files
    Media/       — .mp4, .png, .jpg, .gif, .mov files
    Markdown/    — .md, .txt files (NOT Random Dropbox.md or _Map.md — those stay in root)
```

Create any subfolder that doesn't exist yet before moving files into it.

### What to move

Move every raw file that was just processed (newly added to `_Map.md`) AND every file already in `_Map.md` that is still sitting in the Dropbox root (backlog cleanup). Skip: `_Map.md`, `Random Dropbox.md`, `Notes/` directory.

Use the Bash tool to move files:
```bash
mv "C:/Users/dmcgowa2/Documents/NASA_GSFC_Vault_1/NASA Context Dropbox/<filename>" \
   "C:/Users/dmcgowa2/Documents/NASA_GSFC_Vault_1/NASA Context Dropbox/Archive/<subfolder>/<filename>"
```

After moving all files, do a final pass to update `_Map.md`'s "Raw files" table to show the new archive path for each moved file (e.g. `Archive/Docs/filename.docx` instead of just `filename.docx`).

---

## Phase 7 — Report

After all items are processed, output a concise summary:

```
NASA Context Dropbox — update complete

New notes created (N):
  - [[Note Title]] — one line description
  - [[Note Title (STUB)]] — stub, needs: open filename.docx

_Map.md updated: N rows added
Random Dropbox.md: N entries reformatted
Files archived: N files moved to Archive/

Backlinks added (N):
  - [[Existing Note]] ← [[New Note Title]]
  - [other stitched links]

Action needed:
  - Open SpRInT Proposal McClelland 2023_01_20 submitted.docx → update stub
  - [other stubs]

Nothing new: [if no items were found]
```

---

## Operating constraints

- **Do NOT delete raw files** — move them to Archive/ instead; the note in Notes/ is the authoritative record.
- **Do NOT add entries for files already in `_Map.md`** — diff against the map first; only add new entries.
- **Stub-first for unreadables** — always create the stub so it's findable; don't skip unreadable files.
- **No NASA-restricted data to external sources** — WebSearch/WebFetch are fine for public research about tools/people/concepts. Do not paste document contents into external search.
- **Write `_Map.md` and `Random Dropbox.md` once** at the end (Phase 4/5), not per item — avoids partial-write corruption.
- **Run to completion** — don't pause between items to ask permission.
- **`_Map.md` and `Random Dropbox.md` always stay in the Dropbox root** — never move them.
