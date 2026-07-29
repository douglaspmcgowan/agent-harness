---
name: docs-update
description: Audit a doc set for duplicates, superseded/stale versions, and unclear organization, then either surface a decision table (babysit) or reorganize safely (auto). Use when Douglas says "docs update", "clean up the docs", "find duplicate/outdated notes", "audit the docs", "/docs-update", or after a stretch of sessions that spawned new docs on top of old ones.
---

# /docs-update — keep a doc set current, deduped, and self-explanatory

Claude sessions routinely spawn a NEW doc that supersedes an old one without deleting the original. This skill finds those, plus near-duplicates and unclear structure, and either surfaces them for Douglas (babysit) or reorganizes safely on its own (auto).

## Inputs
- **Scope** (required): `project` (the repo/folder the current work lives in), `folder <path>` (one folder), or `overall` (the whole vault, or a named root). If unstated, infer from the conversation and say which you chose.
- **Mode**: `babysit` (default — surface everything, change nothing) or `auto` (reorganize safely without asking).

## Step 1 — Enumerate
Glob the scope for `*.md`, `*.html`, `*.canvas`. Skip `_backups/`, `_archive/`, `.smart-env/`, `.obsidian/`, `.trash/`, `node_modules/`, `.venv/`. For each doc record: path, title (H1 or filename), `created`/`updated` (frontmatter or mtime), word count, and outbound `[[wikilinks]]`. Build the inbound-link map (who links to whom) — it is the main signal for "is anything still using this?".

## Step 2 — Detect (gather EVIDENCE, never guess)
Classify each doc against the others:
- **Duplicate** — two docs cover the same subject with heavy overlap. Evidence: shared title stem; large fraction of overlapping headings/claims.
- **Superseded** — a newer doc replaces an older one. Signals: a "v2 / — What I Built / — Final / (date)" successor on the same topic; one is a *plan/proposal* and another is the *built/result*; the newer one contradicts or completes the older. Record WHERE the up-to-date content now lives.
- **Stale** — old `updated`, no inbound links, and content contradicted by a newer doc.
- **Orphan** — no inbound links and not an index/entry point.
- **Unclear org** — names that don't say what's inside; a folder of many notes with no index/MOC; inconsistent naming; multiple concerns mashed into one file.

## Step 3 — Decide per finding
For each finding give: the type, the EVIDENCE (dates, inbound-link counts, overlap %, the contradicting doc), and a recommendation — **keep · rename · merge-into `<X>` · archive · delete · split · add-index**. For superseded/duplicate, name the canonical doc the content should live in. Recommend **delete** ONLY when the doc's unique content is zero (everything already lives in the canonical doc) AND inbound links can be repointed; otherwise recommend **merge-then-archive**.

## Step 4 — Act per mode
- **babysit** (default): write a report note (project folder, or `Claude/Briefs/docs-audit-<scope>-<date>.md`) with a decision TABLE — `doc · finding · evidence · recommendation · canonical home` — plus a short org-structure assessment and a proposed cleaner layout. Change NOTHING. Surface the table in chat and ask which to apply.
- **auto**: apply the SAFE reorganizations without asking — rename for clarity (and fix inbound links), create/refresh a folder index/MOC, move superseded/duplicate docs into `_archive/` (NOT hard-delete), repoint links to moved docs. **Hard delete still needs explicit confirmation even in auto** — archive is the auto default because it is reversible. Report exactly what changed and what was left for Douglas.

## Hard rules
- Never hard-delete a doc that has unique content or inbound links without explicit confirmation. Archiving (move to `_archive/`) is the reversible default.
- Before any move/rename, fix every inbound `[[wikilink]]` so nothing breaks.
- Office docs (.pptx/.docx/.xlsx): back up + write a new version per the file-safety rule; never overwrite in place.
- State the evidence for every call. If you cannot tell whether a doc is superseded, surface it in babysit rather than acting on it.
- Match the doc set's existing naming/structure conventions. The goal: structure a newcomer can navigate without anyone explaining it.
