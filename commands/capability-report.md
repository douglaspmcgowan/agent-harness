---
name: capability-report
description: Build a "state of a technical capability" research report in Obsidian with an embedded color-coded canvas pipeline, TRL/maturity landscape, file formats, standards, readiness gates, glossary, and optional per-track implementation plans. Use when the user says "what's the current state of X", "research the landscape for X and lay out the options", "make a capability report", "build a pipeline canvas for X", or asks what it would take to stand up a technical workflow. Mirrors the Text-to-Truss report (NASA_GSFC_Vault_1/Text-to-Truss/).
---

# /capability-report [topic]

Build a structured capability-landscape report in Obsidian with an embedded canvas pipeline. Full method: `claude-research-folder/playbooks/capability-report-with-canvas.md`. Reference build: `NASA_GSFC_Vault_1/Text-to-Truss/`.

## Argument

`[topic]` = the capability/pipeline to research (e.g., "text-to-truss", "automated FEA meshing", "RAG over engineering docs"). If omitted, ask for the topic + the specific questions to answer in ONE message, then proceed.

---

## Phase 1 — Context

1. Confirm the active Obsidian vault (`%APPDATA%\obsidian\obsidian.json` if unsure). Default: `NASA_GSFC_Vault_1`.
2. Glob the vault + working dir for prior files on the topic; read the relevant ones (never read `AI Reference.md`). Note titles for wikilinks.
3. Create the output folder: `Vault/<Topic>/`.

## Phase 2 — Parallel research

Dispatch all research agents in a SINGLE message (one per topic/track). Each gets: objective, exact output format, read-first paths, inline rules (NASA data → route through NMC AI Hub, not commercial cloud; cross-verify with 2+ sources; flag uncertainties), scope boundary. Agents are read-only; you synthesize. Request ~900–1000 words structured markdown + source URLs each.

## Phase 3 — Write the analysis note

`Vault/<Topic>/<Topic> Analysis.md` — Obsidian frontmatter (tags, created, status, `related:` wikilinks) + canonical sections:

1. **What is X?** (definition)
2. **Current state** — TRL landscape table. If two approaches are easily conflated, add a `[!warning]` distinction callout + an "Output Type" column.
3. **Pipeline visual** — `![[<Topic> Pipeline.canvas]]` + a `[!note]` color legend.
4. **File formats & data structures** — with a "Status at org" column.
5. **Standards & directives** — flag policy gaps in `[!warning]`/`[!danger]` callouts.
6. **(Domain/mission context)**.
7. **Readiness gates** — per-track tables, ✅/⚠/❌ + path forward.
8. **Glossary** — term / expansion / meaning.
9. **Sources** — URLs.

## Phase 4 — Build the canvas

Write `Vault/<Topic>/<Topic> Pipeline.canvas` as Canvas JSON. Vertical flow, ~220px row pitch, main nodes ~380 wide. **Color legend (string values):** `1`=red gap, `2`=orange reference/glossary, `3`=yellow medium, `4`=green mature, `5`=cyan process stage, `6`=purple callout/policy. Branch options = parallel nodes converging to the next stage. Edge labels `PASS` / `FAIL → iterate` with a colored feedback edge. Add an orange glossary node and a purple distinction node. Embed in the note.

> Obsidian will re-minify the canvas JSON and add a `metadata` block on save — that's expected; don't revert it. Unicode arrows/emoji may show mojibake in raw diffs but render fine.

## Phase 5 — Implementation plans (if asked)

One file per track: `Track X - <Name> Implementation Plan.md`. Each: status/TRL, required-software table (CUI-safe flags), code architecture + JSON data contracts, LLM/agent setup, **example prompts**, tools to reuse, NASA notes & gaps, phased build sequence, sources. Parent-link to the analysis note.

## Phase 6 — Verify

Confirm the canvas renders and the embed resolves in Obsidian. Screenshot non-trivial canvas content to verify.

---

## Quality bar

- Never blur look-alike categories — name what something is *not*.
- Real `.canvas`, not ASCII/Mermaid.
- "What's needed before this works" (readiness gates) is the highest-value section — be honest with ✅/⚠/❌.
- Flag every uncertainty; cite sources.
