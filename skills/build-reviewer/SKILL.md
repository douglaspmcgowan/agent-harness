---
name: build-reviewer
description: Build a page-by-page reviewer / triage app from a corpus — a flip-through card deck or a list+detail browser where Douglas reviews items one at a time and decides on each (keep / add to knowledge base / archive / core source / out), with a note per item, localStorage persistence, and markdown export. Use when Douglas says "build a reviewer", "make a triage deck/app for X", "flip-through reviewer", "card reviewer", "review these one by one", "let me triage these", "something like the Source Triage deck", or "/build-reviewer". This is a recurring need — he triages corpora (papers, frames, sources, leads, notes) often.
---

# /build-reviewer [corpus description]

Builds a **self-contained, offline HTML reviewer** for a corpus Douglas wants to go through item-by-item and triage. Two proven flavors, same spine (data → template-with-placeholder → inject via Python → one self-contained file → Playwright-verify):

- **Card deck** (flip-through, one item at a time + swipe/keyboard) — best for *deciding* on each item fast. Reference: `NASA_GSFC_Vault_1/Tacit Knowledge Capture/Tacit Knowledge Capture — Source Triage.html`.
- **List + detail** (filter sidebar · list · detail pane) — best for *searching/scanning* a large corpus and dipping into items. Reference: the **Browse** tab of `Claude NASA Folder/frames-workbench/Frames Workbench.html`.

## Argument
The user names a corpus + (optionally) the decisions they want. Minimum useful input:
> "Triage these 80 papers — keep / archive / core, with a note, and a link to each"
> "Let me flip through my saved leads and mark hot / warm / drop"
If they just say `/build-reviewer`, go to Phase 1.

---

## Phase 1 — Clarify (one message, then proceed)
1. **What are the items?** (papers, frames, sources, leads, notes…) and how many (~). <~500 → either flavor; >~1k → list+detail with a render cap.
2. **What does each card show?** title · 1–2 line summary · a "why it matters / how it connects to my work" line · a link · small metadata (type/date/author). Reuse fields that already exist in the data — don't generate what's there.
3. **What are the decisions?** Default set that works: **★ Core · ✓ Keep/Add-to-KB · 📦 Archive · ✕ Out**, plus a free-text **note**. Confirm Core⟹Keep semantics if relevant.
4. **Flavor?** Card deck (decide fast) vs list+detail (scan/search). Pick by the verb — "decide/triage one by one" → deck; "look through/search" → list+detail.
5. **Image per card?** Optional. If the items have no real image and you can't fetch one offline, generate a deterministic per-type SVG cover (gradient + type icon, seeded by title). Say so; don't fake screenshots.

---

## Phase 2 — Read the reference implementation
Read the matching reference before writing code (don't reinvent):
- Card deck: `Claude NASA Folder/ai-for-cad/dfm-explorable/_archive/scratch/_triage_template.html` + `_triage_app.js` + `_inject_triage.py` (paths drift — glob `_triage_*`), and the rendered `… — Source Triage.html`.
- List+detail: `Claude NASA Folder/frames-workbench/_workbench_template.html` + `_workbench_app.js` + `tools/_build_workbench.py`.
Internalize: the IIFE app, the `window.__DATA__ = "__DATA_JSON__"` injection placeholder, localStorage decision model, filter→render→detail loop, catalog/export, clickable counter chips that double as filters.

---

## Phase 3 — Data contract
One JSON the page embeds (injected, so it stays self-contained + offline):
```js
{ items: [ {
    id: "stable-unique-id",
    title: "short heading",
    summary: "1–2 sentence what-it-is",
    connection: "how it connects to my work (the differentiator — keep it applied, not abstract)",
    url: "https://…",            // link to the source
    group: "cluster/category",   // for filtering + color
    meta: { type:"paper", date:"…", author:"…" }  // shown small
  } ],
  groups: [ {title, color} ],    // optional; else derive
  total: 3879, sample: false }   // if showing a subset, set sample + total for the "N of M" note
```
Build this with a small Python script that reads the source data **locally** (so a big corpus never enters the session context) and writes `*_cards.json` — mirror `_tkc_data.py` / `_ingest_*.py`.

---

## Phase 4 — Build (the pipeline)
1. **Data script** → `cards.json` (Python, local). No model generation unless a field is genuinely missing.
2. **Template** (`_reviewer_template.html`): `<head>` design system + markup with `window.__DATA__ = "__DATA_JSON__";` and `/*__APP__*/` placeholders.
3. **App** (`_reviewer_app.js`): vanilla IIFE — render, filters, decisions+notes (localStorage key `<slug>_v1`), export-to-markdown, keyboard (←/→ · X/K/C/A · 0 clear · N note), and (deck) pointer swipe.
4. **Inject** (Python): `template.replace('"__DATA_JSON__"', cards_json.replace('</','<\\/')).replace('/*__APP__*/', app)` → one self-contained HTML. (`</` escape prevents `</script>` breakage.)
5. Render cap for big corpora: show first ~300 filtered, with a "refine to narrow" hint.

---

## Phase 5 — Decisions, persistence, export (the point of the tool)
- Decisions are mutually-exclusive status per item + a note; persist `{id:{status,note}}` in localStorage; survive reload.
- Counter chips in the nav show ★/✓/📦/✕/◌ counts **and** are clickable filters (incl. "untriaged only"). Add an explicit **Untriaged** filter — Douglas asks for this specifically.
- **Export** builds a grouped markdown list (by status, with notes + links) → copy-to-clipboard + a `data:` download. This turns triage into an artifact he can act on.
- Auto-advance on a decision (deck flavor) so triage is fast; "Next untriaged" skip.

---

## Phase 6 — Design system (Douglas's taste — non-negotiable)
- Fonts: **Sora** for everything readable; **IBM Plex Mono ONLY** for IDs and raw counts. Mono-everywhere reads as vibe-coded — he flags it.
- **Tight line-height (~1.4).** Generous but deliberate spacing.
- Dark tokens: bg `#0b1626`, panels `#111e30`/`#0c1726`, line `#1e2d40`, ink `#f3f7fc`, body `#d6e0ee`, muted `#93a6bd`, accent cyan `#22d3ee`; semantic green/amber/coral/purple/steel.
- Cards: full 4-side 1px border, hover = border→cyan only. **Absolute bans:** no left/right side-stripe accents, no gradient text, no glassmorphism-by-default, no tiny uppercase tracked eyebrow on every section, no text overflow.
- Required for the HTML hook: `<meta viewport>`, `clamp()` fonts, `@media (prefers-reduced-motion: reduce)`.
- Covers: if used, crafted per-type SVG (gradient + a clean type icon), deterministic from the title — not procedural noise.

---

## Phase 7 — Verify (always; never claim done without it)
Headless Playwright (`file://` URI). Confirm: **0 JS console/page errors**; items render; click an item → detail/decision works; a decision **persists to localStorage**; a filter (incl. Untriaged) narrows; export builds non-empty markdown. Then screenshot and **look at it** before declaring done (his rule). Mirror `_verify_triage.py` / `_verify_workbench.py`.

## Output contract
Report: flavor chosen + why; item/decision counts; the self-contained HTML path; that it's verified (0 JS errors) with a screenshot; and the regen command. Put the deliverable in a **stable home** (vault folder or the project), never a scratch dir; end with the full absolute path.

## Pitfalls
- Don't embed a multi-MB corpus inline without a render cap — the file gets heavy and the list janks.
- `file://` can't `fetch()` — data must be **embedded** (injected), not loaded.
- Don't generate a `connection`/`summary` that already exists in the data (e.g. a `relation`/`oneliner` field) — reuse it.
- Don't fake images. Generated SVG covers or none.
- Keep all JS in one IIFE; escape `</` in injected JSON; close every tag/bracket.
