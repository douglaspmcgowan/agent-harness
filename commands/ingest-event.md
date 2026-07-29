---
name: ingest-event
description: Full documentation pass for a large event or conference — transcript segmentation, deck extraction, web research, and Obsidian note set (presentations + people + topics + base + mindmap + canvas + MOC). Invoke with /ingest-event <"Event Name"> <materials-folder-path>.
---

# /ingest-event

## Purpose

Given a folder containing event materials (transcript PDF, presentation decks, recap text), produce a complete Obsidian documentation set:

- One note per presentation (with cover image, key takeaways, quotes, external links)
- One note per substantive person (bio, role, links)
- One note per topic/theme (definition, context, cross-references)
- Index/MOC, cards base (`.base`), mind map (`.md`), canvas (`.canvas`)
- `_Map.md` updated; source dropbox cleaned

Canonical precedent: `NASA_GSFC_Vault_1/Text-to-Spaceship Symposium/` (January 2026, ~67 notes, 20 talks, 32 people, 12 topics).

---

## Phase 0 — Parse arguments and confirm materials

**Invocation syntax:**
```
/ingest-event "Event Name" C:\path\to\materials\folder
```

- `Event Name` — the canonical name for the Obsidian folder and all wikilinks.
- `materials-folder-path` — folder containing: transcript PDF, deck files (PPTX/PDF), optional summary/recap file.

**Check immediately:**
1. Is there a `~$<name>` lock file on any PPTX? If so — stop and ask Douglas to close it before proceeding.
2. Does any deck contain a U.S. Export Control / ITAR notice on slide 1 or 2? Flag it explicitly. That deck's note must be built from transcript only — do NOT extract or quote technical specifics from ITAR-marked decks.
3. Is the event public? If yes, web research is authorized. If NASA-internal / CUI, flag that before running any web fetches.

State assumptions (event name, folder, ITAR status, public/internal) in one line, then proceed without asking.

---

## Phase 1 — Extract source text

Run all sub-steps in parallel where possible.

### 1a. Transcript → text

```bash
pdftotext -layout "<transcript>.pdf" transcript.txt
```

If no PDF: look for a .docx or .txt transcript. If neither — stop and ask.

Save to `<materials-folder>/_work/transcript.txt`. Record line count.

### 1b. Summary / recap PDF or DOCX (if present)

```bash
pdftotext -layout "<summary>.pdf" summary.txt
```

For DOCX: use python-pptx's sister library or direct XML unzip:
```bash
unzip -p "<file>.docx" word/document.xml | python3 -c "import sys,re; print(re.sub(r'<[^>]+>','',sys.stdin.read()))" > summary.txt
```

### 1c. Deck text extraction (all PPTX and PDF decks)

Create `_work/deck_text/` directory.

**For each PPTX:**
```python
# python3 -c with python-pptx
from pptx import Presentation
prs = Presentation("deck.pptx")
lines = []
for i, slide in enumerate(prs.slides, 1):
    lines.append(f"\n--- SLIDE {i} ---")
    for shape in slide.shapes:
        if shape.has_text_frame:
            for para in shape.text_frame.paragraphs:
                t = para.text.strip()
                if t:
                    lines.append(t)
with open("deck_text/deck.txt","w",encoding="utf-8") as f:
    f.write("\n".join(lines))
```

**For each PDF deck:**
```bash
pdftotext -layout "deck.pdf" "deck_text/deck.txt"
```

**Check title slide text** for each deck — ASR/filenames often misattribute speakers. The title slide XML is authoritative:
```bash
unzip -p "deck.pptx" ppt/slides/slide1.xml | grep -o '<a:t>[^<]*</a:t>' | sed 's/<[^>]*>//g'
```

### 1d. Cover images

Create `_work/covers/` directory.

**PPTX → thumbnail:**
```bash
unzip -p "deck.pptx" docProps/thumbnail.jpeg > "covers/<name>.jpg" 2>/dev/null
```

**PDF deck → first page PNG:**
```bash
pdftoppm -png -r 150 -f 1 -l 1 "deck.pdf" "covers/<name>"
# produces covers/<name>-1.png
```

Copy each cover image into the corresponding presentation note folder once notes are created (Phase 6).

---

## Phase 2 — Transcript segmentation (4 parallel agents)

The transcript is too long for a single analysis. Divide it into 4 roughly-equal chunks with a 25-line overlap at boundaries. Launch 4 background agents simultaneously.

**Each agent's task:** Read its segment line-by-line. Produce `seg_N.md` in `_work/`:
- List every talk / topic segment found (speaker, rough line range, title/theme)
- For each segment: key claims, demos, data points, notable quotes (verbatim), Q&A highlights
- Flag ASR normalization issues (guessed real name → noted)
- Flag ITAR-marked speakers (no technical extraction from their content)
- Write to disk, return a brief summary

**Agent prompt template:**
```
You are analyzing segment N of 4 of a conference transcript (lines X–Y of <total>).
Event: "<Event Name>" — [date], [host].
Your role: read every line, identify talk boundaries (look for "thank you" transitions, new-speaker introductions, applause markers), and write a detailed point-by-point analysis to `_work/seg_N.md`.

For each talk segment, record:
- Speaker name (correct ASR: e.g. "Senera" → Synera, "Celadon" → Celedon — use context to resolve)
- Talk title / theme
- Line range (approximate)
- Key claims with supporting evidence
- Demo descriptions (what was shown, what numbers were stated)
- Verbatim quotes (exact wording, even if awkward)
- Q&A questions + answers
- Any ITAR/export-control language → flag, do NOT extract technical specifics

Overlap note: lines X to X+25 also appear in the previous segment — cross-check for context only.
Write the full analysis to `_work/seg_N.md`. Return only a 3-sentence summary.
```

Collect all 4 summaries. Then synthesize `_work/MAP.md`.

---

## Phase 3 — Synthesize MAP.md

Read all four `seg_N.md` files. Write `_work/MAP.md`:

```markdown
# MAP — <Event Name>

## Talk order (canonical)
| # | Talk title | Speaker | Affiliation | Deck file | Transcript lines | Notes |
|---|-----------|---------|------------|-----------|-----------------|-------|
...

## Name corrections
| ASR / filename | Confirmed name | Source |
|---|---|---|
...

## Open items
- [ ] Unresolved speaker identity (if any)
- [ ] Decks not in set (talks with no matching file)
- [ ] ITAR-flagged talks
...
```

This is the ground truth for all subsequent writing. If a speaker identity is genuinely ambiguous — stop and ask before proceeding.

---

## Phase 4 — Build WRITE_SPEC.md

Write `_work/WRITE_SPEC.md` — the single source of truth passed to every writing agent:

```markdown
# WRITE_SPEC — <Event Name>

## Canonical wikilink names
### Presentations
- [[<Folder name>/<Folder name>]] for each talk

### People
- [[<Full name>]] for each person

### Topics
- [[<Topic name>]] for each theme

## Name corrections (use these everywhere)
...

## ITAR notice
[If applicable: "Ryan Watkins / JPL deck carries U.S. Export Control. Build note from transcript only."]

## Note templates
[See Phase 6 for full templates]

## Verified facts (correct common errors)
- [Any dates, numbers, or attributions confirmed via deck title slides]

## Rules
- Never fabricate URLs
- Never invent numbers not in transcript or deck
- No "X, not Y" antithesis constructions
- One sentence per bullet point; no trailing periods
```

---

## Phase 5 — Web research (3–4 parallel agents)

Only if event is public. Launch in parallel:

**Agent A — People:** For each presenter, find: full name + title, current organization, LinkedIn or professional profile, notable prior work, any publications or patents relevant to the talk. Write to `_work/research_people.md`.

**Agent B — Organizations:** For each company / lab in the talk list, find: what they do, founding date, funding/ownership, notable products or research, relevant news (within 12 months of event). Write to `_work/research_orgs.md`.

**Agent C — Topics:** For each theme identified in Phase 2, find: technical definition, state of the art, key references, any standards or benchmarks. Write to `_work/research_topics.md`.

**Agent D — Event itself (optional):** Any public coverage, announcements, or follow-up news since the event. Write to `_work/research_event.md`.

Research rules:
- State which source each fact came from.
- Hedge unconfirmed numbers as "roughly."
- Never invent URLs — use only those returned by search.
- Mark anything from a single source as "single source."

---

## Phase 6 — Write notes (parallel writing agents)

Create the vault folder structure first:
```
NASA_GSFC_Vault_1/<Event Name>/
  Presentations/
    <Talk folder>/
      <Talk folder>.md
      cover.jpg (or cover.png)
  People/
    <Full name>.md
  Topics/
    <Topic name>.md
  <Event Name>.md          ← index/MOC
  <Event Name>.base        ← cards base
  Symposium Mind Map.md    ← mindmap outline
  <Event Name>.canvas      ← visual canvas
  Recap — <source>.md      ← verbatim source text if preserved
```

Launch 4–6 parallel writing agents, split by note type and volume:
- Agent 1–3: presentation notes (split the talk list roughly equally)
- Agent 4: all people notes
- Agent 5: all topic notes
- Agent 6 (main thread): index/MOC, base, mindmap, canvas (after others complete)

**Pass each agent:** `WRITE_SPEC.md`, the relevant `seg_N.md` excerpts, the relevant `research_*.md` sections, the cover image path.

### Presentation note template

```markdown
---
tags: [<event-tag>, presentation, <domain tags>]
event: "[[<Event Name>]]"
type: presentation
date: <YYYY-MM-DD>
researched: <today>
---

![[<Event Name>/Presentations/<folder>/cover.jpg|450]]
(or > [!note]- No slide-deck cover available for this talk. if none)

# <Talk folder name>

> [!abstract] At a glance
> **Speaker:** [[<Name>]] — <title, org>  ·  **Session:** <AM/PM panel>
> **Deck:** `<filename or "no deck in set">`  ·  **Transcript:** seg_N.md lines ~X–Y

## What it covered

### <Section heading>
<Prose summary, 2–4 paragraphs>

## Key takeaways
- <bullet>

## Notable quotes
> "<verbatim>" — <speaker>

## NASA relevance
<1–2 paragraphs>

## Research & external links
- <verified URLs only>

## See also
- Presenter: [[<Name>]]
- Topics: [[<Topic>]]
- Related: [[<Note>]]
- [[<Event Name>]]
```

### People note template

```markdown
---
tags: [<event-tag>, person, <org tag>]
event: "[[<Event Name>]]"
type: person
researched: <today>
---

# <Full Name>

**<Title>** · <Organization>

<2–3 sentence bio from research>

## Talk at <Event Name>
- [[<Presentation note>]]

## External links
- <LinkedIn / professional profile / publications>

## See also
- [[<Event Name>]]
```

### Topic note template

```markdown
---
tags: [<event-tag>, topic, <domain>]
event: "[[<Event Name>]]"
type: topic
researched: <today>
---

# <Topic Name>

<Definition + state of the art, 1–2 paragraphs>

## At <Event Name>
- <Who discussed it, key claims>

## Key references
- <papers, standards, tools>

## See also
- <Related topic notes>
- [[<Event Name>]]
```

### Frontmatter tag conventions

Every note in the set gets:
- `<event-tag>` — a short kebab-case slug for the event (e.g., `t2s-symposium`)
- `type: presentation | person | topic | source`
- `event: "[[<Event Name>]]"`

---

## Phase 7 — Build root artifacts

### Index/MOC (`<Event Name>.md`)

```markdown
---
tags: [<event-tag>, moc]
type: moc
date: <YYYY-MM-DD>
---

# <Event Name>

> [1-paragraph overview: what the event was, who attended, central themes]

## Agenda / Talks
| # | Talk | Speaker | Org |
|---|------|---------|-----|
...

## NASA-specific updates
<Bullet list of internal directives, status updates, capability announcements>

## External presentations
<Bullet list of industry/lab talks>

## People
[[<Name>]] — <one-line role>

## Topics
[[<Topic>]] — <one-line definition>

## Source files
- [Transcript](<SharePoint or local path>)
- [Decks](<SharePoint or local path>)
- [Recap note]([[Recap — <source>]])

## See also
- [[<Related note>]]
```

### Cards base (`<Event Name>.base`)

```yaml
filters:
  and:
    - file.hasTag("<event-tag>")
    - file.name != "<Event Name>"
    - file.ext == "md"
views:
  - type: cards
    name: 🎤 Presentations
    filters: type == "presentation"
  - type: cards
    name: 👤 People
    filters: type == "person"
  - type: cards
    name: 🧩 Topics
    filters: type == "topic"
  - type: cards
    name: 🗂 Everything
```

### Mind map (`Symposium Mind Map.md` or `<Event Name> Mind Map.md`)

Plain markdown outline — `obsidian-mindmap-nextgen` renders it as a mind map from headings and bullets.

```markdown
---
tags: [<event-tag>]
mindmap-plugin: basic
---

# <Event Name>

## Presentations
### <Talk title>
- <key claim>
- <key claim>
...

## People
### <Name> — <org>
...

## Topics
### <Topic>
- <sub-point>
...
```

### Canvas (`<Event Name>.canvas`)

JSON. Build with these conventions:
- One header text node at `y: -200` (event name + date)
- Groups use colors 3–6 (Obsidian palette). Each group = one thematic band.
- Group stacking: ≥120px vertical gap between rows. Group label renders ~40px above top border — account for this.
- File nodes: `type: "file"`, `file: "<vault-relative path>"`, positioned 10px inside group top border.
- Edges: use `label` for relationship names (e.g., "uses", "multi-agent", "AI physics").
- All file-node `file` values must resolve to actual `.md` files in the vault. Run a validation pass before writing (see Phase 8).

Skeleton:
```json
{
  "nodes": [
    {"id":"header","type":"text","text":"**<Event Name>**\\n<Date>","x":-400,"y":-200,"width":800,"height":60},
    {"id":"g1","type":"group","label":"<Theme>","x":-500,"y":0,"width":1000,"height":250,"color":"3"},
    {"id":"n1","type":"file","file":"<Event Name>/Presentations/<folder>/<folder>.md","x":-490,"y":10,"width":280,"height":160}
  ],
  "edges": [
    {"id":"e1","fromNode":"n1","fromSide":"right","toNode":"n2","toSide":"left","label":"<relationship>"}
  ]
}
```

---

## Phase 8 — Validation

Run before declaring done:

### Wikilink check

```python
import os, re
vault = r"C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1"
# build index of all .md filenames (stems)
index = set()
for root, dirs, files in os.walk(vault):
    for f in files:
        if f.endswith(".md"):
            index.add(os.path.splitext(f)[0])

# scan all new notes for [[wikilinks]]
pattern = re.compile(r'\[\[([^\]|#]+)')
unresolved = []
for root, dirs, files in os.walk(os.path.join(vault, "<Event Name>")):
    for f in files:
        if not f.endswith(".md"): continue
        text = open(os.path.join(root,f),encoding="utf-8").read()
        for m in pattern.finditer(text):
            target = m.group(1).strip().split("/")[-1]  # last path component
            if target not in index:
                unresolved.append((f, target))

print(f"Unresolved: {len(unresolved)}")
for note, target in unresolved:
    print(f"  {note} → [[{target}]]")
```

Acceptable unresolved: image embeds (`[[.../cover.jpg]]`). Confirm those image files exist. Any `.md` target that doesn't resolve → fix the wikilink or create the missing note.

### Canvas file-node check

```python
import json, os
vault = r"C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1"
canvas = json.load(open(os.path.join(vault, "<Event Name>", "<Event Name>.canvas")))
for node in canvas["nodes"]:
    if node.get("type") == "file":
        path = os.path.join(vault, node["file"].replace("/", os.sep))
        if not os.path.exists(path):
            print(f"MISSING: {node['file']}")
```

Zero missing = pass.

---

## Phase 9 — Update vault index and clean source

### Update `NASA Context Dropbox/_Map.md`

Add a row to the Notes index table:
```
| [[<Event Name>]] | <event-tag>, moc | <source files description> | Researched — dedicated folder `<Event Name>/`: N talks, N people, N topics + base/mindmap/canvas |
```

Update `Last updated: YYYY-MM-DD`.

### Clean Random Dropbox (if recap was pasted there)

If the event recap was in `Random Dropbox.md`, truncate the symposium block and replace with a pointer:
```markdown
---
## ✅ Processed → [[<Event Name>]] (<date>)
Full event recap processed into `<Event Name>/` — N talks, N people, N topics, base, mindmap, canvas.
---
```

Preserve any unrelated entries above/below.

### Delete scratch files (optional — ask first)

The `_work/` directory can be large (extracted decks). Ask Douglas before deleting. The lightweight analysis files (`seg_N.md`, `MAP.md`, `WRITE_SPEC.md`, `research_*.md`, `transcript.txt`) are worth keeping. The raw deck binaries are safe to delete once notes are written.

---

## Phase 10 — Done

Output to chat:
1. Folder path in vault
2. Note counts (N presentations, N people, N topics)
3. Any open flags (ITAR notes, ambiguous speakers, unverified claims)
4. Screenshot prompt: "Open `<Event Name>.base` in Obsidian to verify cards render."

---

## Operating constraints

- **Never read or echo API keys, env-var values, or secrets.**
- **ITAR-flagged decks:** note from transcript only; no technical extraction.
- **Never fabricate URLs.** If a URL wasn't returned by search, omit it.
- **Deck identity:** always confirm from title-slide text — filenames and ASR are unreliable.
- **ASR normalization:** treat all company/person names as potentially corrupted; resolve against deck text and web research before writing.
- **No "X, not Y" antithesis** in any output (prose, bullets, notes, commits).
- **Verify before claiming done:** run the wikilink and canvas validation scripts before Phase 9.
- **Cover images for no-deck talks:** use a `> [!note]- No slide-deck cover available for this talk.` callout — do not fabricate images.
