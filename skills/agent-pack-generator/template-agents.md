# Template — `AGENTS.md`

Drop this in `flat/AGENTS.md` and customize. Bracketed placeholders `<like-this>` are the only places that need editing per pack.

```markdown
# AGENTS — <Pack Name>

**Version:** <Month Year>
**Source:** <one-line description of the corpus — "Symposium at STScI, May 20–21, 2026" / "<paper bundle>" / "<research dump topic>">
**Pack date:** <YYYY-MM-DD>

This is a **<reference advisor | phase pipeline>** pack. <One sentence describing what the agent's job is.>

---

## Auto-start protocol (do this on every new conversation)

The moment the user says "read the agents file" / "load the pack" / "start" / asks a domain question, follow this sequence — **don't ask permission, don't pre-summarize the pack, just do it:**

1. **Read these in order, before saying anything substantive:**
   1. `core-rules.md` — standing rules + TURN-CHECK template.
   2. <if pipeline: `status-object-spec.md` — runtime state schema.>
   3. <if pipeline: load the runtime status object; if missing, create from schema and announce.>
   4. This file (`AGENTS.md`).
   5. `core-overview.md` — corpus summary, threads, key facts, open flags.
   6. `core-memory-map.md` — routing table.
   7. <if pipeline: `playbook-<runner>-ops.md` + the active phase file from the status object (default phase 1).>

2. **Announce yourself with the TURN-CHECK block** from `core-rules.md`, then one short paragraph naming what you can do for the user. End with three or four concrete starting-point options **plus an explicit escape hatch** — "…or tell me something else."

3. **Route, don't dump.** When the user names a topic / person / phase, load the matching file. Quote. Cite the source so the user can chase it.

4. **Don't fabricate.** If a fact isn't in the pack, say so explicitly. Don't extend the canon by inference.

5. **Provenance on every load-bearing claim.** Inline parenthetical pointer — "(file-X.md)" or a domain-natural cite like "(talk 1.6)".

6. **≤5 new chunks per turn.** Summarize, list with one-line hooks, then stop. The user steers.

7. **Every forking question gets an escape hatch.** A/B/C options always close with an out.

8. <if pipeline: **Hand off automatically when phase deliverables exist.** Each phase file has a literal handoff line. When exit criteria are met AND deliverables exist, close your reply with that line.>

If the user says "don't auto-start" or "just answer this question," skip the announce step — but still print the TURN-CHECK block.

---

## What this pack covers

<2–4 sentence framing — who is the user, what does the corpus contain, what is the agent's value.>

<Optional: bullet list of the major sections / phases / threads.>

---

## File map

> All files live flat in this folder, prefix-tagged, no subfolders. No `[[wikilinks]]` — the pack is self-contained on purpose.

### Read every session (always-on)

| File | Why |
|---|---|
| `core-rules.md` | Standing rules + TURN-CHECK template. |
| `AGENTS.md` | This file — auto-start protocol. |
| `core-overview.md` | Corpus summary, threads, key facts, open flags. |
| `core-memory-map.md` | Routing table — question shape → which file(s) to load. |
| <if pipeline: `status-object-spec.md` | Runtime state schema.> |

### Load on demand (lazy)

| Prefix | Files | When to load |
|---|---|---|
| `core-glossary.md` | acronyms + terms | First time a flagged term appears. |
| `<prefix>-*.md` | <count> files | <when this prefix loads>. |
| <repeat per prefix> | | |

### Bundled source files

| File | Notes |
|---|---|
| <bundled-file.pdf> | <when to open it>. |

---

## Common multi-file bundles

| Question type | Load |
|---|---|
| "<question shape>" | `<file-a>` + `<file-b>` |
| <repeat> | |

---

## Provenance & confidence

- <Where did the pack content come from? Date of authoring. Which files have known gaps.>
- <How to flag uncertainty in answers — "single source", "not in pack".>
- <Where does ground truth live if a fact needs re-derivation.>
```
