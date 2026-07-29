---
name: research-asset-manifest
description: Build or refresh a machine-readable research asset manifest for the current folder or a specified target folder. Use when a research directory contains papers, figures, archives, extracted assets, notes, decks, or app folders and you want future sessions to stop re-scanning from scratch.
disable-model-invocation: true
---

# Research Asset Manifest

Use this skill only when the user explicitly asks for a manifest, inventory, asset index, folder audit, or a reusable research-folder inventory.

Default target:
- If `$ARGUMENTS` is empty, use the current working directory.
- If `$ARGUMENTS` is present, resolve it as a target folder relative to the current working directory unless it is already absolute.

Primary goal:
- Write or refresh `research_manifest.json` at the target root so later deck, report, recap, and research tasks can start from a concise inventory instead of a cold recursive scan.

Operating rules:
- Prefer a curated scan over an indiscriminate crawl.
- Skip obvious noise unless the user explicitly asks otherwise:
  - `.git/`
  - `.claude/`
  - `.venv/`
  - `venv/`
  - `node_modules/`
  - `.next/`
  - `dist/`
  - `build/`
  - `coverage/`
  - `__pycache__/`
  - `.DS_Store`
- Do not read or expose secrets.
- Do not guess titles, provenance, or relationships when the evidence is weak. Use `"unknown"` instead.
- Reuse an existing `research_manifest.json` if present. Preserve stable `id` values when possible instead of renaming everything on each refresh.

What to inventory:
- Papers and PDFs
- Figures and images
- Zip archives and extracted folders
- Slide decks and presentation assets
- Notes, briefs, and synthesis docs
- Data files and spreadsheets
- App/demo folders when they are part of the research package
- Derived assets such as screenshots, crops, exports, or extracted frames

Output contract:
- Write exactly one primary artifact: `research_manifest.json`
- Optionally update an existing manifest in place instead of rewriting it from scratch
- Do not create extra summary files unless the user asks

Required JSON shape:

```json
{
  "manifest_version": 1,
  "generated_at": "ISO-8601",
  "root": "relative-or-absolute-path",
  "summary": {
    "total_assets": 0,
    "by_category": {
      "paper": 0,
      "figure": 0,
      "archive": 0,
      "deck": 0,
      "note": 0,
      "data": 0,
      "app": 0,
      "other": 0
    }
  },
  "assets": [
    {
      "id": "stable-short-id",
      "path": "relative/path/from/root",
      "category": "paper",
      "kind": "pdf",
      "title": "unknown",
      "canonical_name": "paper-name.pdf",
      "source_archive": "unknown",
      "derived_from": [],
      "description": "short factual description or unknown",
      "status": "raw",
      "notes": ""
    }
  ],
  "relationships": [
    {
      "from": "figures/example.png",
      "to": "papers/example.pdf",
      "type": "derived_from"
    }
  ],
  "issues": [
    "Duplicate-looking filenames under figures/ and exports/",
    "Archive present with no extracted folder",
    "Extracted folder present but source archive missing"
  ]
}
```

Category guidance:
- `paper`: PDF or paper-source document
- `figure`: image, screenshot, chart, diagram, extracted frame
- `archive`: zip, tar, 7z, or similar bundle
- `deck`: PowerPoint, PDF deck, key slide export set
- `note`: markdown, docs, briefs, text notes, memos
- `data`: csv, tsv, xlsx, json datasets
- `app`: runnable demo or app folder that is part of the research deliverable
- `other`: anything important that does not fit above

Recommended workflow:
1. Resolve the target directory.
2. Check whether `research_manifest.json` already exists and read it first.
3. Identify the likely content-bearing top-level directories and files.
4. Build a concise asset inventory with stable ids and terse descriptions.
5. Add relationships only when they are visible from names, folder structure, or nearby docs.
6. Add an `issues` list for duplicates, missing sources, unclear provenance, or dead artifacts.
7. Write `research_manifest.json`.
8. Report only the high-signal summary in chat:
   - target path
   - total asset count
   - counts by category
   - most important issues

Quality bar:
- This manifest is meant to reduce future token spend.
- Keep entries concise, factual, and machine-friendly.
- Favor consistency over cleverness.

