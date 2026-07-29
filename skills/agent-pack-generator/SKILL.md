---
name: agent-pack-generator
description: Build a self-contained agent context pack from an existing corpus (Obsidian folder, papers, transcripts, deck text) — flat layer + AGENTS.md auto-start + prefix-tagged files + top-level zip. Distilled from the DaVinci Text-to-Concept pack iteration. Use when Douglas says "make this an agent pack", "turn X into a context pack like the DaVinci one", "generate an agent pack from this folder", or "/agent-pack-generator".
---

# Agent Pack Generator

Turns a corpus (Obsidian vault folder, paper bundle, transcript set, deck-text dump) into a deployable **agent context pack** — a self-contained set of markdown files plus a top-level zip — modeled on the DaVinci TTC pack at `C:/Users/dmcgowa2/Documents/NASA_GSFC_Vault_1/NASA Ignition/`. The MBSE symposium pack at `…/Text-to-Spaceship Digital Engineering and MBSE Symposium May 2026/agent-pack/` is a reference-only example.

## Two pack shapes

Pick one — they share most of the structure but differ on what AGENTS.md tells the agent to do.

| Shape | Use when | Phase files? | Status object? |
|---|---|---|---|
| **Reference advisor** | The corpus is informational — papers, a symposium, a research dump, an FAQ. The agent's job is to answer / route / quote with provenance. | No | No |
| **Phase pipeline** | The agent runs a multi-step workflow on top of the corpus (concept → estimate → review → document, or interview → assess → recommend → plan). Phase transitions happen in chat, not via a UI dropdown. | Yes (`phase-N-*.md` per phase) | Yes (`status-object-spec.md` + a runtime model object) |

Default to **Reference advisor** unless Douglas explicitly names phases / a workflow. He's burned by over-engineered packs — phases without a real workflow turn into ceremony.

## Deliverable layout

Every pack ships these top-level files inside `<pack-root>/flat/`. Edit `flat/`, deploy a zip whose contents are at the **top level of the archive** (no `flat/` prefix inside).

```
<pack-root>/
  README.md                              human-facing — what this is, how to deploy, how to regenerate
  _flatten.py            (optional)      Obsidian → flat/ converter, if the source is wikilinked vault notes
  flat/
    AGENTS.md                            entry point — auto-start protocol
    core-rules.md                        standing rules + TURN-CHECK template
    core-overview.md                     what the corpus is, key threads, headline numbers
    core-memory-map.md                   question shape → which file(s) to load
    core-glossary.md                     acronyms + terms (lazy-loaded)
    <prefix>-*.md                        domain content (talk-, person-, topic-, paper-, detail-, strategy-, …)
    [phase-N-*.md]       (pipeline)      one file per phase
    [phase-guide.md]     (pipeline)      orchestration + chat-driven handoff lines
    [status-object-spec.md] (pipeline)   schema of the runtime status object the agent writes each turn
    [playbook-<runner>-ops.md] (pipeline) operating manual for the target runner (DaVinci, Claude Project, …)
    <bundled source files>               PDFs / images the agent might need to open verbatim
  <pack-name>.zip                        deployable archive — files at top level
```

Filename prefixes are not decoration. The agent uses them to decide when to load:

| Prefix | Meaning |
|---|---|
| `core-` | Always load on session start |
| `detail-` | Load when the memory map points to it |
| `talk-` / `person-` / `topic-` / `paper-` | Domain content; load on demand |
| `strategy-` | High-level plans / roadmaps; load when strategic question fires |
| `reference-` | Big monoliths kept as fallback (don't load by default) |
| `playbook-` | Operating manual for a runner (DaVinci, target tool) |
| `phase-` | One pipeline phase (only for the pipeline shape) |

## Process

### 1. Confirm intent (one round, batched)

Before building, batch these into a single message to Douglas (per his global "1–3 ambiguities batched" rule):

1. **Pack shape**: reference advisor or phase pipeline? (If phase, what are the phases?)
2. **Source corpus location**: which folder? Are wikilinks present?
3. **Pack root**: where should it live? (Default: a sibling `agent-pack/` folder next to the source.)
4. **Target runner**: DaVinci, generic Claude Project, or other? (Affects whether `playbook-<runner>-ops.md` is needed.)

If the answers are obvious from context, state them in one assumption line and proceed — don't re-ask.

### 2. Inventory the source corpus

Read the source folder structure. Read 2–3 sample files at different levels (a top-level MOC, a leaf note, a long file) to see frontmatter, wikilink density, and length distribution. Don't try to read everything.

### 3. Plan the prefix scheme

Map source folders → file prefixes. For an Obsidian event vault: `People/` → `person-`, `Topics/` → `topic-`, `Presentations/<name>/<name>.md` → `talk-`. For a paper bundle: `papers/` → `paper-`, plus hand-authored `detail-` synthesis files. For a research dump: `notes/` → `note-` or `detail-`.

### 4. Flatten the corpus

If the source is Obsidian or any wikilinked vault, write `_flatten.py` (or reuse the one in the MBSE pack — see `playbook-flatten-script.md` in this skill). Key requirements:

- Slugify filenames (`lowercase-kebab-case`).
- Strip `[[wikilinks]]` — `[[X|Y]]` → `Y`, `[[X]]` → `X`. **Pack-shipped files do not have wikilinks.** Wikilinks point outside the pack and break agent context.
- Apply the Windows long-path fix (`\\?\` prefix) — paths under a deep vault folder routinely exceed `MAX_PATH` (260 chars).
- Preserve frontmatter as-is. The agent ignores it but it carries provenance.

### 5. Hand-author the core files

These five are not auto-generated. They're what makes the pack a pack instead of a folder dump.

- **`AGENTS.md`** — entry point. Every agent pack has the same skeleton: an *Auto-start protocol* numbered list (read these files in this order, then announce yourself, then wait), a *What this pack covers* paragraph, a *File map* table, *Common multi-file bundles* table, *Provenance & confidence* section. See `template-agents.md` in this skill folder for the full skeleton.
- **`core-rules.md`** — the standing rules + TURN-CHECK template. See `template-core-rules.md`.
- **`core-overview.md`** — TL;DR of the corpus + agenda / index + headline numbers + open flags. The agent reads this on every session.
- **`core-memory-map.md`** — routing table from question shape → which file(s) to load. The agent reads this on every session and uses it to *not* load files it doesn't need.
- **`core-glossary.md`** — acronyms + terms. **Lazy-loaded** (only when an unfamiliar term shows up).

### 6. (Pipeline shape only) Author phase files + status object spec

If Douglas asked for a pipeline:

- One `phase-N-<name>.md` per phase. Each phase file documents: deliverables, exit criteria, a literal handoff line, the per-turn checklist for that phase.
- `phase-guide.md` orchestrates: read order, "which phase am I in?" decision tree, handoff lines, where the active phase lives in the runtime status object.
- `status-object-spec.md` defines the schema for the runtime state the agent writes each turn (phase, last action, open user questions, scope, invariants, takeaways, residual risks). **The status object is the only mutable state.** Pack files are static reference material.

Phases are **chat-driven** ("the user types 'phase 2'"). Never tie phase transitions to a runner-specific UI control like a persona dropdown — that's been observed to confuse the model. (DaVinci pack iteration log, 2026-06-04.)

### 7. Bundle source files

Copy the original PDFs / decks / transcripts the agent should be able to open verbatim into `flat/`. Don't re-name them — the agent needs to find the source by its real name when a `talk-*.md` flags a gap.

### 8. Write the README

Human-facing. What the pack is, how to deploy (the `cd flat && zip ../zip .` command), how to regenerate, where the source vault is, any caveats (long-path warnings, wikilink stripping notes). The MBSE pack's README is a good model.

### 9. Zip with files at the top level of the archive

```bash
cd <pack-root> && \
[ -f <pack-name>.zip ] && mv <pack-name>.zip "<pack-name>.zip.bak-$(date +%Y%m%d-%H%M%S)" ; \
cd flat && zip -rq ../<pack-name>.zip .
```

The `cd flat && zip ../zip .` pattern (NOT `zip -r flat/`) puts files at the top level. DaVinci, Claude Projects, and most agent runners flatten on import — if you ship `flat/<file>`, the runner re-nests as `flat/flat/<file>` or fails the import. Top-level is the correct shape.

### 10. Verify

After zipping:

- `unzip -l <pack-name>.zip` — confirm files are at top level (no `flat/` prefix in the listing).
- Spot-check one talk file in the zip to confirm wikilinks are stripped.
- Open `AGENTS.md` from the zip and trace the auto-start protocol — every file it tells the agent to load should exist in the listing.

## The standing rules (use these as `core-rules.md` defaults)

The DaVinci pack converged on these after iteration. Adopt them verbatim for new packs unless the corpus genuinely needs different ones.

1. **PROVENANCE** — every load-bearing claim cites a pack file or talk number.
2. **NO-FABRICATION** — if a fact isn't in the pack, the answer is "not in pack — want me to web-search or flag as open?", not a guess.
3. **ESCAPE HATCH** — every forking question to the user closes with "or tell me something else" / explicit out.
4. **STEP-BY-STEP** — ≤5 new objects per turn. The user steers; the agent doesn't dump.
5. **ASK-BEFORE-BUILD** — "yes detail those" doesn't mean build six things; ask which + how before going.
6. **VERIFY-AFTER-WRITE** *(pipeline only)* — re-read every edit. Broken state ≠ display issue.
7. **STATUS-FIRST / STATUS-UPDATE** *(pipeline only)* — load the status object at turn start; write before reply ends.
8. **STICKY-QUESTIONS** *(pipeline only)* — re-ask open user-input questions on resume; don't silently answer.
9. **BULK-IN-OBJECT** *(pipeline only)* — long output → model object / external doc, not chat.
10. **NATIVE-VIEW-FIRST** *(DaVinci runner only)* — point users at the runner's native views; don't build a parallel dashboard.

For a reference advisor pack: rules 1–5 only. For a pipeline pack: 1–9 minimum, plus 10 if the runner is DaVinci.

## TURN-CHECK template

Print at the top of every assistant reply. The block is short on purpose — its job is *proof you read core-rules.md*, not a summary of state.

```
─── TURN-CHECK ────────────────────────────────────────────
mode      : <reference-advisor | phase-N-<name>>
user-Qs   : <list any user-input questions still open, or "—">
load-plan : <which pack files this turn will read>
rules     : R1 R2 R3 R4 R5 [R6 R7 R8 R9]   <strike any not in scope>
───────────────────────────────────────────────────────────
```

## Things that fail (DaVinci pack iteration log)

These are the failure modes the iteration on the TTC pack actually hit. Don't repeat them.

- **Wikilinks in pack-shipped files.** Imported into a runner that doesn't resolve `[[wikilinks]]`, the agent treats them as broken refs. Strip them.
- **Persona dropdown for phase switching.** The model loses track of which persona is active. Use chat-driven phases instead — "the user types 'phase 2'."
- **Bulk output dumped in chat.** Long tables / documents in chat get truncated or paged out. Put bulk output in a model object (DaVinci) or an external doc the agent points to. Chat is for the pointer + reasoning summary + next forking question.
- **Status object as a markdown file.** Markdown files don't survive across sessions in DaVinci. Use a runtime model object (DaVinci `_TTC_Status` Package, or runner-specific equivalent). Pack files are static.
- **`status.md` updates skipped after action.** A 2026-06-03 incident — Phase 1 deliverables built but `status.md` never updated → next session had no recovery state. Solution: STATUS-UPDATE rule fires every turn, even pure-Q&A turns.
- **Closed-list forking questions.** "A or B or C?" with no escape hatch boxes the user in. Always offer "or tell me something else."
- **Zip with `flat/` prefix inside.** `zip -r flat/` produces an archive with `flat/<file>` paths. DaVinci re-nests on import. Use `cd flat && zip ../zip .` instead.
- **Persona N+1 doing the work of persona N.** When two phases overlap, merge them (Personas 4 + 5 → Document Developer on 2026-06-03).
- **Pre-summarizing the pack on load.** Auto-start protocol says "don't summarize — start working." A 2-paragraph self-introduction wastes the user's first turn.

## Iteration discipline

After deploying a pack, run a real session. Watch for:

- The agent failing to load a file the memory map should have pointed at.
- The agent fabricating a number (PROVENANCE fails) or paraphrasing instead of quoting.
- The agent running past the ≤5-object ceiling.
- The agent answering a forking question silently after a session resume (sticky-questions failure).
- Long-path or import failures on the deploy side.

Each failure mode is a candidate edit to `core-rules.md` or the relevant phase file. **Do not over-edit AGENTS.md** — it should stay tight. New rules go in `core-rules.md`; new operating norms go in the playbook.

## Skill invocation contract

When invoked, the skill should:

1. Confirm pack shape + source corpus + pack root + runner (one batched message).
2. Inventory the corpus.
3. Author the five core files from the templates.
4. (Pipeline only) Author phase files + status spec + playbook.
5. Run the flatten script (or hand-write the prefixed files if the source isn't an Obsidian vault).
6. Bundle source PDFs.
7. Zip with files at top level.
8. Verify with `unzip -l` + spot-check.
9. Report: pack root path, zip path, file count, any open flags or warnings.

## Reference packs

- **DaVinci TTC** — `C:/Users/dmcgowa2/Documents/NASA_GSFC_Vault_1/NASA Ignition/flat/`. Phase pipeline (4 phases). Runner: DaVinci. Has `_TTC_Status` runtime object. Iteration history is preserved in the global memory under `[[project-ttc-pipeline-shape]]` + `[[project-ttc-pack-layout]]` + `[[project-ttc-rules-architecture]]`.
- **MBSE Symposium** — `C:/Users/dmcgowa2/Documents/NASA_GSFC_Vault_1/Text-to-Spaceship Digital Engineering and MBSE Symposium May 2026/agent-pack/`. Reference advisor. 49 markdown + 1 PDF, top-level zip. Built 2026-06-12 by this skill.

When in doubt, open the DaVinci `flat/` and copy structure verbatim. The patterns there are battle-tested.
