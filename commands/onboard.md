---
name: onboard
description: "Makes a codebase legible to a HUMAN by reading the real source and generating a visual explainer — for code Claude wrote that has outgrown your understanding, or for an app's own users. Two modes. --dev: a self-contained HTML explainer for Douglas the developer, with five views — (1) what it is in plain language, (2) THE MAP: a real directed flow chart of how the parts wire together (not a force-directed node blob), (3) how each part works, per-component, (4) how data flows through it (a logical data-flow diagram), (5) a step-by-step walkthrough tracing ONE real feature end-to-end through the actual files. --user: an in-app help surface — a question-mark icon fixed top-right that opens an overlay explaining to the END USER what the app does and how to use it, conforming to the app's existing design. Its signature rule, both modes: never avoid a technical term because the reader isn't a coder — USE the real term, then define it in plain language inline on first use, plus a glossary. Everything is grounded in the actual repo (reads and cites real file:line), refuses to invent structure, and is honest about what static reading can't show (runtime behavior). Human-facing only — no Serena/LSP, repo-map/PageRank, context packagers, or embedding/RAG, because the point is for a person to READ it. Use when Douglas says 'onboard me to this codebase', 'explain how this whole app works', 'I don't understand this code Claude built', 'make me an explainer for X', 'add a help/? explainer to this app for users', 'onboard', '/onboard'. Also invoked by /design to add the in-app ? help to a built app."
---

# /onboard [target] [--dev|--user]

A codebase you didn't write, or wrote through an agent and stopped tracking, is opaque in a specific way: every
individual file is readable, but nothing tells you how they add up. This command fixes that for a HUMAN reader.
It reads the real source, builds an honest mental model of the whole, and renders it as something you can look
at and understand — a map of how the parts connect, what each one does, how data moves through it, and a
step-by-step trace of one real feature from the outside in. It teaches the vocabulary instead of hiding it:
every technical term is used AND defined in plain language, so you come out able to read the code, not just
nod at a summary.

## The signature rule (both modes) — name the term, then explain it

Douglas is not a coder, and the wrong fix is to strip out the technical words. The right one is to teach them.
**Every technical term is USED and then immediately defined in plain language on first use**, and collected in
a glossary at the end. The pattern:

> The server exposes an **endpoint** (a specific web address the app listens on, like `/api/parts`, that other
> code calls to ask for something) that returns the part list as **JSON** (a plain-text way of writing
> structured data — lists and labelled fields — that both the browser and the server can read).

Never write "the thing that stores data" when the word is **database**. Write "**database** (the program that
stores the app's data on disk so it survives a restart)". The reader should finish able to say the real word
and know what it means. This rule outranks brevity — a glossed term is never "too technical."

## What this is NOT

- **Not impeccable's `onboard` command.** impeccable's `onboard` designs an app's FIRST-RUN and EMPTY states
  (the "you have no data yet, here's how to start" screens) — a visual-design pass on a blank app. This
  `/onboard` EXPLAINS an already-built system: its `--dev` mode is a comprehension artifact for the developer,
  and its `--user` mode is a persistent "how does this app work" help surface, not a first-run wizard. When
  `/design` names both, they are different tools; this one is always written `/onboard` (the slash command).
- **Not `/recon`.** `/recon` maps an external landscape to help Douglas DECIDE what to adopt. `/onboard`
  explains a specific codebase that already exists in front of him.
- **Not `/design-review` or `/tech-debt-audit`.** Those judge a system — is the UX sound, is the code healthy,
  what's wrong. `/onboard` does not evaluate; it EXPLAINS how the thing works so a human can hold it in their
  head. A finding of "this is badly structured" belongs to those; "here is the structure" belongs here.
- **Not a code-navigation/agent tool.** Deliberately no Serena/LSP, no Aider repo-map/PageRank, no Repomix/
  Gitingest packagers, no embedding/RAG search. Those exist to feed an AGENT context or answer "where is X"
  for a machine. The deliverable here is for a PERSON to read and understand, so it is prose, diagrams, and a
  glossary — not a symbol index. (If Claude needs symbol navigation to BUILD the explainer faster, that's an
  internal means; it never appears in the output and is never the deliverable.)
- **Not `/design`.** `/design` decides what an app IS and builds it. `/onboard` explains an app that's already
  built. `/design` INVOKES this command (Step 9) to add the `--user` help to what it shipped.

## Modes

Two independent surfaces over the same comprehension work:

- **`--dev`** (default when the target is a repo/folder to understand) — a **standalone, self-contained HTML
  explainer** for Douglas the developer. Audience: someone who will read and maintain the code. Carries all
  five views below at full depth, with real `file:line` citations.
- **`--user`** (default when invoked by `/design`, or when the target is a running app with an end user) — an
  **in-app help surface**: a question-mark icon fixed top-right of the app that opens an overlay explaining, to
  the app's END USER, what the app does and how to use it. Audience: a non-developer using the app. Shallower
  on internals, heavier on "what can I do here"; still glosses every term; conforms to the app's existing design.

If the target is ambiguous (a repo that's also a deployable app, no flag given), ask which mode in one line
rather than guessing — the two produce different artifacts in different places.

## Procedure

### Step 0 — Resolve target and mode

Needs: which codebase/app (a path), and the mode. If the flag is absent, infer per the Modes section and state
the inference in one line. For `--user`, also establish where the app's UI entry point is (the main HTML file
or root component the `?` icon will attach to) — discover it from the repo, don't ask what you can find.

### Step 1 — Read the real codebase and build the model (the human reading discipline)

Read the ACTUAL source — entry points first, then follow the real imports/calls outward. This is the
trace-one-thing-end-to-end discipline, done by reading, not by a symbol tool. Produce an internal model before
rendering anything:

- **Entry points** — where execution actually starts (the `main`, the server's route table, the app's root
  component, the CLI's arg parser).
- **Major parts** — the handful of components/modules the system decomposes into (aim for the ~5–12 boxes that
  will become THE MAP, not every file). Name each by what it DOES.
- **Data flow** — where data enters, each step that transforms it, where it's stored, where it leaves.
- **One real feature** — pick a single concrete user-facing thing the app does and note the exact path it takes
  through the files, top to bottom. This becomes the walkthrough.
- **The terms** — list the technical words a reader will hit that need glossing.

Ground every claim in a real path. If you can't find how something works, say so in the artifact — never invent
a component or a connection to make the diagram tidy. **Completion criterion:** you can name the entry point,
the major parts, the data path, and one end-to-end feature trace, each tied to a real file — or you've recorded
explicitly what the code didn't reveal.

### Step 2 — The gate (mandatory, before rendering)

Check honestly, and stop or narrow if any holds:

1. **Is there enough to explain?** A single 40-line script needs a paragraph and a glossary, not a five-view
   HTML explainer — produce the right-sized thing and say so. The full treatment is for a real multi-part app.
2. **`--user` on something with no user-facing UI?** A library, a CLI, or a batch script has no screen to pin a
   `?` icon to. Say the `--user` surface doesn't apply and offer `--dev` instead, rather than fabricating a UI.
3. **Is the picture accurate?** If a STATUS.md/README claims a structure the code contradicts, trust the CODE
   and note the discrepancy — explaining an app from a stale doc is the core failure mode.

### Step 3 — `--dev`: the standalone HTML explainer (the five views)

One self-contained `.html` file, in this order. This is the deliverable contract — all five always present:

1. **What it is** — 3–5 plain sentences: this app takes X and turns it into Y, for whom, why. No jargon yet;
   this is the sentence Douglas could say to someone else.
2. **THE MAP** — a real **directed flow chart**: every major part as a labelled box, arrows showing who calls
   or sends data to whom, laid out so the whole system fits on one screen. This is the C4 "container" zoom —
   the major building blocks and their wiring, not every class. It must be a FLOW CHART (boxes + directed,
   labelled arrows), never a force-directed knowledge-graph blob. Author it as inline SVG or HTML/CSS so it
   renders offline on `file://` with no CDN; if the graph is complex, vendor `mermaid.min.js` locally rather
   than hot-linking a CDN.
3. **How each part works** — one card per box in THE MAP: what it does, its key file(s) cited as `path:line`,
   and the term-with-gloss for anything technical. This is the C4 "component" zoom for the parts that warrant it.
4. **How data flows** — a **logical data-flow diagram**: input → each processing step → storage → output, with
   every arrow LABELLED with what's actually moving ("raw CAD text", "parsed part list", "GLB mesh"). Logical,
   not physical — what the data IS and where it goes, not which server hosts it. Use the four data-flow element
   kinds and name them once for the reader: **external source/sink** (where data comes from or ends up),
   **process** (a step that transforms it), **data store** (where it's held), **data flow** (a labelled arrow).
5. **Walkthrough** — the ONE feature from Step 1, traced end to end as numbered steps, each naming the real
   file and what happens there, so Douglas can watch a single request travel all the way through.

Then: a **glossary** of every glossed term, and an **honesty note** — one short paragraph stating that this map
is built from reading the static code, so it shows the designed structure and cannot show runtime behavior
(what actually happens under load, timing, or live data); anything the reading couldn't determine is flagged
in place. Follow `~/.claude/DESIGN.md` house rules (separate regions by elevation/tone + whitespace, hairline
borders only as last resort; monospace ONLY for code and file paths; no gradient text, no kicker labels, no
fake numbered eyebrows), the HTML presentation rules (viewport meta, `clamp()` fonts, `prefers-reduced-motion`),
and keep it a single self-contained file that opens on `file://`.

### Step 3.5 — `--dev`: auto-route the explainer into the Briefs queue (do this every `--dev` run)

The `--dev` explainer is a standing reference Douglas will want to re-open, so route it into the **Briefs**
side of the Workbench automatically — never leave it as a loose file he has to remember the path to. After the
HTML is written and verified (Step 5), enqueue it as an **html brief** via the Workbench CLI. The brief carries
the file by reference (`src`), so the single self-contained HTML stays where it is and the Briefs app renders it
in a sandboxed iframe:

```
echo {"title":"Onboarding: <app name>","format":"html","src":"<ABSOLUTE path to the .html>","source":"onboard","tags":[{"text":"onboarding","tone":"green"}]} | node "C:\Users\dmcgowa2\Documents\Claude NASA Folder\workbench\bin\workbench.js" brief add --stdin
```

(Build the JSON with a real tool/heredoc, not a fragile inline echo, and use the file's absolute path.) One
constraint: the Briefs app only reads a `src` that lives inside its allowed roots — the vault
`Claude/{Briefs,Detective,Engineer,Learn}` folders or the `Claude NASA Folder` code root. If the explainer was
written **outside** those (a repo living elsewhere), also write a copy into the vault `Claude/Briefs/` folder and
route that copy's path instead, so the brief always opens. Enqueue succeeds whether or not the Workbench server
is running (the poller ingests it on next start); note in the Step-6 report that it was routed to Briefs.

This step is `--dev` only — a `--user` run edits the app in place and produces no standalone artifact to route.

### Step 4 — `--user`: the in-app `?` help surface

Add a help surface to the app itself, conforming to the app's existing design (this is a brownfield insertion —
match the app's tokens, type, and spacing; reuse its components before adding new ones). It has two pieces:

- **The trigger** — a question-mark icon button fixed to the top-right of the app viewport (`position: fixed`,
  clear of existing top-right chrome — check for collisions and offset if needed). Real button semantics:
  `aria-label="How this app works"`, keyboard-focusable, visible focus ring.
- **The overlay** — opens a dismissible panel (modal or side drawer, whichever fits the app) containing, for the
  END USER: **what this app does** (plain, one short paragraph), **what you can do here** (the main jobs, as a
  short list), **a light "how it works" peek** (a simplified version of THE MAP / data flow, for the curious
  user — one or two sentences plus a small diagram, not the full developer view), and **how to use the key
  features** (short how-to steps for the top one or two actions). The signature term-and-gloss rule still holds:
  a user-facing term like **export** or **render** gets the plain-language gloss on first use.

Accessibility and non-disruption are load-bearing here (it's live UI, not a static file): the overlay traps
focus while open, closes on `Esc` and on a visible close control and on backdrop click, returns focus to the
`?` button on close, and must not mutate the app's own state or data. Wire the trigger into the app's real UI
entry point found in Step 0, following the standing file-safety rules (add new files; for an edit to an authored
source file, keep the insertion surgical and backed up per the file-safety hook — never an in-place overwrite of
an authored doc).

### Step 5 — Verify against the rubric (render it, don't just write it)

Open the artifact for real (`--dev`: load the HTML on `file://` via Playwright/preview; `--user`: run the app
and open the overlay) and check, honestly:

- **`--dev`:** all five views render and are non-empty; THE MAP is a directed flow chart (boxes + arrows), not a
  node blob; the data-flow arrows are labelled; every glossed term is defined; spot-check 2–3 `file:line`
  citations against the real repo so they're accurate, not hallucinated; the honesty note is present.
- **`--user`:** the `?` icon is visible top-right and doesn't overlap existing chrome; it opens and closes
  (button, `Esc`, backdrop) with focus returning correctly; the four content pieces are present; the app's own
  state is untouched; the styling matches the app.

Report what was verified this pass and what wasn't — never certify "fully explained."

### Step 6 — Report

- The exact path of the artifact (`--dev` HTML file) or the files touched (`--user` trigger + overlay + the
  entry-point edit), per the standing Files-list convention (bold title + purpose + full path, tagged NEW/UPDATED).
- Which views/pieces were verified live and how, and any part of the codebase the static read could not resolve.
- For `--user`, confirmation the app's existing behavior is intact.

## Safety constraints

- **Human-facing output only, and no agent-nav machinery in the deliverable** — no Serena/LSP, repo-map/PageRank,
  packagers, or embedding/RAG in what's produced (Douglas's explicit exclusion: the point is for a person to read
  it). Such tools may be used internally to speed the read, but never appear in or become the output.
- **`--dev` is read-only on the codebase** — it produces a NEW standalone HTML file and never edits the source
  it explains.
- **`--user` edits the app surgically** — new files for the help component, and at most a minimal insertion at
  the UI entry point to mount the `?` trigger; follow the file-safety hook (backups, no in-place overwrite of
  authored docs), match the app's design, and leave all existing behavior working.
- **Ground everything in the real repo; never invent structure** to make a diagram look complete — a gap the
  reading couldn't resolve is stated, not filled with a plausible guess.
- Never run with elevated/bypass permissions. No commits/pushes unless Douglas separately asks.
- Self-contained and offline: the `--dev` HTML opens on `file://` with no network dependency; NASA/CUI content
  stays on the machine (open-web egress is blocked for sensitive topics — don't test it).

## Notes on scope (authoring_checklist)

Satisfies the authoring rules: front-loaded description leading with the core concept + both modes; triggers
collapsed to one phrase per branch; model-invocable deliberately (because `/design` calls it); each step ends on
a checkable completion criterion; the term-and-gloss rule stated once as the single source of truth; safety of
the produced artifact designed in (a11y + non-disruption for `--user`, offline + no-fabrication for `--dev`).
Deliberate exception: NO embedded multi-agent Workflow script — unlike the sibling build skills, `/onboard` is a
single coherent read-then-render pass with no independent parts to fan out, so a Workflow would add ceremony
without parallelism; it runs inline. Self-contained single-file skill by design (Douglas's family convention).

---

*Tracked copy: also save this file to `claude-global-config/commands/onboard.md` (per the skills-are-tracked
convention) after a NASA scrub.*
