---
name: slides
description: HTML presentation studio plus a disciplined three-mode deck process. Author professional static HTML slides (themes, layouts, CSS + canvas animations, a GSAP cinematic engine), generate an editable PowerPoint (.pptx) in sync, deploy to Vercel, export PDF, and convert in from PowerPoint or other HTML slide frameworks. Runs a phased process: design (lock words and layout in a per-deck SPEC), iterate (generate, lint, render via LibreOffice, inspect every slide in a keep-going loop), fancify (apply themes, motion, and canvas FX last). Use when the user asks for a presentation, PPT, slides, keynote, deck, slideshow, pitch deck, talk slides, technical presentation, or a reveal-style HTML deck, wants to convert a .pptx or existing HTML deck into web slides, or wants to iterate, fix, render, share, deploy, or export a deck. Triggers include presentation, ppt, slides, deck, keynote, reveal, slideshow, pitch deck, convert pptx, powerpoint to html, deploy slides, export pdf, iterate the slides, fix the deck.
---

# slides — HTML PPT Studio + disciplined deck loop

Author professional presentations as static files, then drive them through a
phased process that gets the words and layout right BEFORE any theme, motion, or
canvas effect is applied. One theme file = one look. One layout file = one page
type. One animation class = one entry effect. All pages share a token-based
design system in `assets/base.css`.

The library underneath is the merged **ultra** build: the lewislulu html-ppt base
(31 layouts, 27 CSS + 20 canvas animations) plus **75 themes** (36 core + 39
ported design systems), a **GSAP cinematic-motion engine**, **interactive
components** (flip / expand cards, live Chart.js), **visual style discovery**
(show-3-previews picker), **one-command Vercel deploy**, **PDF export**,
**convert-in** from PowerPoint and other HTML slide frameworks, and
**editable-PPTX output**.

That library is the paint. The three modes below are the order you pick up the
brushes: words and layout first, fancy last. Doing it in that order is what saves
the rework — you never animate or theme a slide whose message or structure is
still going to change.

## The three modes (a phased design process)

The modes are phases, run in order. Each has a gate that must hold before the next
begins. On a returning session, resume at the earliest phase that is not yet
locked.

### 1. design — lock the words and layout FIRST

Author (or, on a returning deck, reconcile) the per-deck **SPEC** before a single
slide gets a theme, an animation, or a canvas effect. This is words and layout
only.

1. **Big idea.** Write the deck's `big_idea` as ONE complete sentence: the point
   of view and what is at stake. A topic phrase does not qualify; it has to be a
   claim.
2. **Ghost deck.** Draft the whole deck as a flat ordered list of per-slide
   `single_point` sentences first — one sentence per slide, at sticky-note level,
   before any slide gets a layout, image, or chart. If a `single_point` needs two
   sentences, it becomes two slides.
3. **Assertion titles.** Each slide's `title` in the SPEC is an assertion — it
   carries a verb or an explicit claim. A bare topic noun does not qualify. The
   assertion drives the slide and lives in the SPEC; the ON-slide title stays
   terse per
   `~/.claude/voice-slides.md` (no full sentence, no comma, no period). The
   assertion is the planning artifact; the rendered title is its short form.
4. **Horizontal-logic readthrough.** Concatenate every `title` in slide order and
   read them ALONE as a paragraph. If the titles-only story does not hold as an
   argument, the deck is not ready — fix the sequence before building.
5. **Pick layout templates.** For each slide, choose a layout from
   `templates/single-page/` (catalog: [references/layouts.md](references/layouts.md))
   or a full-deck scaffold from `templates/full-decks/`. Choose the layout only
   after the `single_point` is fixed.

Per-slide SPEC fields: `id` (stable, never renumbered after a delete), `title`
(assertion), `single_point`, `layout`, `elements` (the words / images / figures /
diagrams the slide will carry, each expected to serve `single_point`),
`non_goals` (content deliberately excluded — the durable home for every "do not
include X"), `source` (the user-provided text or real artifact each label traces
to), `assets` (image filenames the slide references), and `c4_level` (architecture
slides only: exactly one of Context / Container / Component).

**Gate to advance to iterate:** SPEC has a `big_idea` and one entry per slide with
the fields populated; every `title` validates as an assertion; the horizontal
readthrough holds as an argument. No themes, no animations, no canvas FX exist
yet.

### 2. iterate — generate, lint, render, inspect EVERY slide

The disciplined keep-going loop. It does not trust that a deck is right because
the code that generated it "should" be right, does not call a slide done off a
headless load or a clean console, and does not report a voice pass clean off an
eyeball skim. It lints the generated XML, renders the FINAL artifact through
LibreOffice, looks at a PNG of every slide, decides each one complete-or-needs-work
against a concrete checklist, fixes what fails, and re-renders — looping until
every slide passes and the linter is silent.

**The SPEC stays adjustable in this mode.** design authored it, but iterate is
free to revise it: as rendered slides expose a weak `big_idea`, a `single_point`
that splits, or a `title` that stops being an assertion, edit the SPEC and
re-render. The SPEC is the durable contract that survives across sessions — a
returning session reads it as the source of truth for the deck's message, and any
change made while iterating is written back into it, not left only in the slides.
The gate is that the SPEC and the deck stay in sync, in either direction.

**Targets.** iterate drives BOTH targets in sync when a deck has them: the
pptxgenjs PowerPoint generator and the parallel reveal.js HTML deck. The two carry
the same information — nothing invented on one, nothing on one missing from the
other. Every slide label or claim traces to provided text or a real artifact;
never fabricate content, terminology, or fixed labels.

Per pass:

0. **(optional) Scope the pass to dirty slides.** For intermediate passes, keep
   the loop cheap. Refactor the generator so each slide is one function
   `buildSlideN(pres, data)` keyed by the SPEC `id`, and keep a manifest of
   slide-id → function-source-hash. A pass marks a slide DIRTY only when its
   function body or SPEC entry changed. pptxgenjs has no partial save
   (`writeFile()` still writes the whole `.pptx`), so the savings are: only the
   dirty function is edited and reviewed, `pdftoppm -png -r 150 -f N -l N`
   rasterizes ONLY the dirty pages, and unchanged slides reuse a cached
   last-known-good PNG and skip vision inspection while their hash is unchanged.
   Structural edits (add / delete / reorder) run as a distinct phase BEFORE any
   content-only edit; slide ids and filenames are never renumbered after a delete.
   The caveat that ties to the completion gate: the accepting pass still requires a
   per-slide render for EVERY slide — satisfied for an unchanged slide by a
   hash-verified cached PNG, never by skipping a slide whose hash changed.
1. **Generate / edit** both targets from the SPEC.
2. **LINT** (mechanical, fails the build). Run `python lint.py "<deck>.pptx"`. It
   unzips the deck, reads every audience-facing `<a:t>` run and every font
   `typeface`, and exits non-zero on any HARD-rule violation (see
   [The linter](#the-linter)). A non-zero exit is a build failure — fix the
   generator and regenerate; never hand-wave a violation.
3. **RENDER via LibreOffice**, then inspect. Render the FINAL `.pptx` (never the
   HTML deck as a stand-in):
   - `soffice --headless --convert-to pdf --outdir render "<deck>.pptx"`
   - `pdftoppm -png -r 150 render/<deck>.pdf render/slide`
4. **Inspect EVERY slide PNG** — one entry per slide, never a sample. For each
   slide, FIRST state its `single_point` from the SPEC in one sentence, THEN judge
   the slide against it:
   - **Coherence.** Does every element — each word, image, figure, diagram —
     serve that one point? Flag anything that does not.
   - **Over-explanation.** Name what could be CUT without changing what the slide
     communicates. This is the message-level test, above the element-level removal
     test in [House design rules](#house-design-rules-adapted-to-slides).
   - Then the full [inspection checklist](#the-inspection-checklist).
5. **Fix** every needs-work slide in both targets in sync, re-lint, re-render,
   re-inspect. The voice/design check re-runs after every edit pass.

The loop does not stop while any slide privately needs work, any queued directive
(including a negative) is unverified against the current render, or the linter is
non-silent.

**Completion gate.** Do not claim done unless a rendered PNG per slide was captured
THIS turn and every one was inspected, the linter exits 0, and every directive —
including negatives, which live in `non_goals` — is re-verified against the current
render. A headless load, a clean console, or "looks right" does not clear this gate.

### 3. fancify — apply the ultra library LAST

Only after design and iterate lock the content and layout, reach for the paint:
themes, CSS animations, canvas FX, the GSAP cinematic engine, and interactive
components. Applying these last is the whole efficiency win — nothing decorative
was ever spent on a slide whose message or structure still moved.

- **Theme.** Press `T` to cycle, or hard-code
  `<link rel="stylesheet" id="theme-link" href="../assets/themes/aurora.css">`.
  Catalog: [references/themes.md](references/themes.md); by-mood picks in
  [references/vibe-presets.md](references/vibe-presets.md). When no theme is named,
  use the show-3-previews flow rather than guessing
  ([references/style-discovery.md](references/style-discovery.md)).
- **CSS animations.** `data-anim="fade-up"` on any element; `anim-stagger-list` on
  a list or grid. Catalog: [references/animations.md](references/animations.md).
- **Canvas FX.** `<div data-fx="knowledge-graph">…</div>` plus
  `<script src="../assets/animations/fx-runtime.js"></script>`. 20 modules
  including knowledge-graph (force-directed) and neural-net (pulses).
- **GSAP cinematic engine.** Opt a slide in with `data-gsap="cinematic"` after
  adding the CDN + `gsap-engine.js`. Catalog:
  [references/gsap-animations.md](references/gsap-animations.md).
- **Interactive components.** Flip / expand cards, auth flip-compare, live
  Chart.js. Catalog: [references/components.md](references/components.md).

**Re-run the checks after fancify.** Re-lint and re-inspect every slide: motion
and theming must not break voice, fit, or the glance test. A theme that pushes a
title onto two lines, an animation that hides a data point on load, or an FX layer
that lowers contrast is a regression, caught the same way iterate catches
everything else.

## Utilities (available across all modes)

These are not phases; they are tools any mode can reach for.

- **Deploy to Vercel.** `bash scripts/deploy.sh <deck> --yes-publish-public`.
  **Publish-safety gate:** without the flag (or a `y` to the interactive prompt,
  which defaults to NO), the script warns and exits. Vercel deploys are PUBLIC —
  never run this on CUI / ITAR / pre-decisional material.
- **Export PDF.** `bash scripts/export-pdf.sh <deck-html> [output.pdf] [--compact]`.
  Local, offline, Playwright/Chromium. Renders slides in their resting state.
- **Convert in.** `python scripts/extract-pptx.py <input.pptx> [output_dir]` →
  `slides.json` + `images/`. Map each slide per
  [references/conversion-patterns.md](references/conversion-patterns.md), which
  also covers reveal.js, Marp, impress.js, Slidev, Google Slides exports, and
  article HTML. Conversion is content + structure only; the extractor emits a
  per-slide `warnings` list for what needs manual rebuild.
- **Editable-PPTX output.** The output counterpart to convert-in: a native,
  editable `.pptx` (real shapes/text) via the PptxGenJS TypeScript toolchain in
  `scripts/pptx-out/`. Usage in [references/pptx-out.md](references/pptx-out.md).
  Heavier dependency (Node/bun); HTML token themes do not carry over.
- **Render to PNG.** `./scripts/render.sh <deck.html> [N] [out-dir]` wraps headless
  Chrome and iterates `#/N` deep-links. (For the iterate loop's own render, the
  LibreOffice `.pptx` path above is the mechanism, never Chrome.)
- **Scaffold a deck.** `./scripts/new-deck.sh my-talk`.

## What this is NOT

- **Not `/design` (design-taste-frontend / redesign-existing-projects).** Those
  architect an interface's IA from scratch. The design mode here locks a deck's
  message and layout against a SPEC; it does not re-invent an app's information
  architecture. A deck that needs re-conceiving is a `/design` handoff.
- **Not `impeccable`.** Impeccable is the visual-layer taste pass for web UI. This
  skill borrows its judgment and `~/.claude/DESIGN.md`'s house rules (adapted to
  slides below), but the iterate loop renders and inspects a `.pptx`; it does not
  route a deck through impeccable's live-browser UI flow.
- **Not `/design-review`.** That is a read-only IA/UX review that returns findings
  and never edits. iterate edits the deck and re-renders until it passes.
- **Not `superpowers:brainstorming`.** Brainstorming explores intent before
  building. If the deck's message is genuinely undecided, brainstorm first, then
  come here to render it.
- **Not the `anthropic-skills:pptx` plugin.** That reads/writes `.pptx` via
  python-pptx as a general Office tool. This skill uses its own pipeline
  (pptxgenjs + LibreOffice render) with the device file-safety hooks, the voice
  linter, and dual-target sync — none of which the generic plugin knows about.

## Ground truth (paths the iterate loop operates on)

For a deck that keeps a dedicated build folder (the pattern this loop is built
around):

- **Generator:** the pptxgenjs generator (e.g. `_pptx_build/gen.js`) —
  `FH = FB = FM = "Calibri"`, an `IMGDIM` lookup + `pic()` aspect-fit helper,
  refuses to overwrite an existing output path, writes a fresh `vN`.
- **HTML deck:** the parallel reveal.js `index.html`, when the deck has one.
- **Content source of truth:** the author's `.md`. Hand edits there win
  unconditionally.
- **Enforceable spec:** `SPEC.md` in the build folder. It carries BOTH the
  message contract (the `big_idea` + per-slide entries from design mode) AND the
  linted voice subset. The linter enforces only the mechanical subset; the message
  contract is human-authored and gated in design mode.
- **Voice register:** `~/.claude/voice-slides.md` (the full rules; the linted
  subset is a strict subset).
- **Render output:** `render/` (PDF + per-slide PNGs; scratch, never a deliverable
  home).
- **Python for the linter/render helpers:** a Python with wheels (on this device,
  `C:/Users/dmcgowa2/scoop/apps/python313/current/python.exe`).

## The linter

Drop `lint.py` into the deck's build folder. It reads the slide XML inside the
`.pptx` zip and fails (exit 1) on any HARD-rule violation. Node has no builtin
unzip, which is why this is Python. Prove it runs before the first iterate pass:
it must exit 0 on a known-good deck and non-zero on a copy with a planted `·`.

```python
# -*- coding: utf-8 -*-
"""
lint.py — mechanical voice/visual HARD-rule check on a generated .pptx.
Unzips the deck, pulls every audience-facing text run out of ppt/slides/*.xml,
checks each against the hard voice rules from ~/.claude/voice-slides.md.
Text baked into an image is not a text run, so it is never linted.
HARD FAILs (exit 1): middle-dot separator, em-dash, contraction, non-Calibri
font, '@'-leading title, 'The '-leading title, comma inside a title.
WARNs (exit 0): sentence-ending period, lone numbering kicker.
Usage:  python lint.py "<deck>.pptx"   |   python lint.py --strict "<deck>.pptx"
"""
import sys, re, zipfile, html
from xml.etree import ElementTree as ET

A = "{http://schemas.openxmlformats.org/drawingml/2006/main}"

CONTRACTIONS = re.compile(
    r"\b(can't|cannot n|doesn't|don't|isn't|aren't|won't|wouldn't|couldn't|"
    r"shouldn't|didn't|hasn't|haven't|it's|that's|we're|you're|they're|"
    r"i'm|let's|there's|here's|what's|who's|we've|you've|they've|i've|"
    r"we'll|you'll|they'll|i'll|it'll)\b", re.IGNORECASE)
MIDDLE_DOT = "·"
EM_DASH = "—"
FONT_OK = {"Calibri", ""}

PERIOD_SAFE = re.compile(r"""
    (\.\w)              # .md .js .py .json
  | (\d\.\d)            # decimals 0.84
  | (\b[A-Z]\.[A-Z]\b)  # U.S.
""", re.VERBOSE)


def slide_runs(xml_bytes):
    root = ET.fromstring(xml_bytes)
    for pi, p in enumerate(root.iter(f"{A}p")):
        for r in p.iter(f"{A}r"):
            t = r.find(f"{A}t")
            if t is None or t.text is None:
                continue
            face = ""
            rpr = r.find(f"{A}rPr")
            if rpr is not None:
                latin = rpr.find(f"{A}latin")
                if latin is not None:
                    face = latin.get("typeface", "")
            yield pi, html.unescape(t.text), face


def para_text(runs, pi):
    return "".join(t for i, t, _ in runs if i == pi)


def lint_slide(n, xml_bytes, strict):
    runs = list(slide_runs(xml_bytes))
    if not runs:
        return []
    fails, warns = [], []
    paras = sorted({pi for pi, t, _ in runs if t.strip()})
    title = para_text(runs, paras[0]).strip() if paras else ""

    if title.startswith("@"):
        fails.append(f"title starts with '@': {title!r}")
    if re.match(r"^The\s", title):
        fails.append(f"title starts with 'The ': {title!r}")
    if "," in title:
        fails.append(f"comma inside title: {title!r}")

    for pi, text, face in runs:
        if not text.strip():
            continue
        if MIDDLE_DOT in text:
            fails.append(f"middle-dot separator in {text!r}")
        if EM_DASH in text:
            fails.append(f"em-dash in {text!r}")
        m = CONTRACTIONS.search(text)
        if m:
            fails.append(f"contraction '{m.group(0)}' in {text!r}")
        if face not in FONT_OK:
            fails.append(f"non-Calibri font {face!r} in {text!r}")
        stripped = text.rstrip()
        if stripped.endswith(".") and not PERIOD_SAFE.search(stripped[-3:]):
            warns.append(f"trailing period in {text!r}")
        if re.fullmatch(r"0\d", stripped):
            warns.append(f"numbering kicker {stripped!r}")

    out = [("FAIL", n, f) for f in fails] + \
          [(("FAIL" if strict else "WARN"), n, w) for w in warns]
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    strict = "--strict" in sys.argv
    if not args:
        print(__doc__)
        sys.exit(2)
    z = zipfile.ZipFile(args[0])
    names = sorted(
        (nm for nm in z.namelist()
         if re.fullmatch(r"ppt/slides/slide\d+\.xml", nm)),
        key=lambda s: int(re.search(r"(\d+)", s).group(1)))
    results = []
    for nm in names:
        n = int(re.search(r"slide(\d+)", nm).group(1))
        results.extend(lint_slide(n, z.read(nm), strict))
    fails = [r for r in results if r[0] == "FAIL"]
    warns = [r for r in results if r[0] == "WARN"]
    for lvl, n, msg in sorted(results, key=lambda r: (r[1], r[0])):
        print(f"[{lvl}] slide {n}: {msg}")
    print(f"\n{len(names)} slides linted, {len(fails)} FAIL, {len(warns)} WARN")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
```

The linter is a known-ceiling heuristic: it treats the first non-empty paragraph
as the title box (not a placeholder-type lookup), and its contraction/kicker
regexes are pattern-based. It catches the tics that actually ship; the visual
rules (border/frame, distortion, crop, required asset) stay human-QA in the
inspect step because they are not text-run-checkable. Keep the mechanical set
mechanical.

## House design rules (adapted to slides)

`~/.claude/DESIGN.md` and impeccable's tells, translated to a deck. These are
inspection criteria applied during iterate:

- **One font, Calibri** (linted). No monospace for labels/counts/meta; use tabular
  figures within Calibri for aligned numbers.
- **Images aspect-fit** to true pixel dimensions via `pic()` + `IMGDIM`, never
  stretched to a box; and **no frame, border, or card** around any photo or
  screenshot — it sits plain on the background. Crop dead space; never the subject.
- **No AI tells.** No accent line under a title; no decorative color bar / edge
  stripe / single-side card border; one color dominates 60–70% with 1–2 supporting
  tones and one sharp accent; left-align body text, center only titles; vary
  layouts across slides; no cream backgrounds; no text-only slides; never Aptos.
- **Signal-to-noise (element-level removal test).** Every element passes the
  removal test — an ambiguous icon, a decorative line, a redundant element, a
  bullet that restates the headline gets cut. The criterion is whether deleting the
  element changes what the audience UNDERSTANDS (the slide's `single_point`), not
  merely whether the slide looks cleaner.
- **Data slides.** Maximize data-ink; prefer small multiples at one scale over a
  single overloaded chart; numbers stay raw and dense; spend the one accent color,
  via a preattentive cue, on the single data point that is the point. No
  frame-count / edge-count stat callouts.
- **Glance test (message-level).** Every presented slide is graspable in ~3
  seconds. A reader who has NOT seen the SPEC should be able to state the slide's
  `single_point` back after that glance; if not, the slide over-explains or
  under-commits and gets decluttered or rewritten, not restyled.
- **Tables and fragments.** Parallel content is a table, never a paragraph.
  Bullets are fragments (name / number / claim), never commentary, connective
  tissue, or hedging — that belongs in speaker notes.
- **Deliberately-excluded content lives in the SPEC `non_goals`** so a later pass
  does not re-add it mistaking omission for oversight.

## Architecture / harness slides: one C4 level per slide

For multi-tier abstraction content, do not draw generic labeled boxes at equal
weight. Apply C4:

- **One abstraction level per slide.** Pin each slide to exactly one of Context /
  Container / Component. Anchor the ladder with a Context frame first: what is
  outside the system before descending into tiers.
- **Ground each tier in the REAL rendered artifact** — an actual file tree, a real
  dispatch log line, a real query result — freshly re-rendered against the current
  build, never a stale or decorative substitute.
- **Title, legend, labeled connections on every slide.** Each carries a title
  stating its type and scope, a legend mapping shape + color to meaning, and a
  label on EVERY arrow saying what flows. An unlabeled arrow is a rule violation.
  Reuse the same shape family and color key across the set so the ladder reads as
  one system.

## The inspection checklist (per slide, in iterate step 4)

A slide is **complete** only when every line holds; otherwise **needs-work** with
the specific failing lines:

- Single point stated; every element serves it; nothing over-explains the point or
  could be cut without changing the message.
- Linter clean (font, punctuation, kicker, title form, contraction, em-dash,
  middle-dot).
- No period on any title / bullet / table cell (except URL / email / decimal /
  version).
- Title is a short phrase or "Label: name", never a full sentence; no `@`, no
  leading "The", no comma.
- Bullets are fragments; no commentary, connective, hedging, or headline
  restatement.
- Parallel content is a table. Numbers raw and dense.
- Images: aspect-correct, no frame/border/card, cropped tight without clipping the
  subject.
- No AI tells (accent line under title, color bar/edge stripe, equal-weight color,
  centered body, cream bg, Aptos, text-only slide).
- Passes the 3-second glance test.
- Every queued directive that touches this slide, including negatives, is satisfied
  on THIS render.
- Architecture slides only: one C4 level; titled; legend present; every arrow
  labeled; a real artifact shown.

## Safety constraints (apply every pass)

- **Never overwrite a file the author may have open or is editing.** Always
  generate to a fresh `vN`. The content `.md` (and any hand-edited deck) is the
  source of truth — back it up to `_backups/<name>.BACKUP_<yyyyMMdd_HHmmss>.<ext>`
  before any transform, diff to find exactly what changed (text AND any image
  dropped in), and apply those edits INTO the target. An image the author added is
  a deliberate placement instruction; never delete or move it without saying so.
  Confirm the app is fully closed (no `~$` lock, no POWERPNT process) before
  reading a deck to transform it.
- **Render ONLY via LibreOffice headless** (`soffice --headless --convert-to`).
  NEVER PowerPoint COM automation — its `.Quit()` closes the author's open
  PowerPoint app. If a render step cannot run headless, stop and say so.
- **Any trial regeneration runs against a fresh `vN`**, isolated from open files;
  discarded trials are just unused `vN` files.
- **Sensitive content stays local.** For NASA / CUI work, do not route the deck,
  its screenshots, or its text through any web tool or off-machine endpoint. All
  rendering, linting, and inspection is local; never Vercel-deploy such a deck.
- **No commits or pushes** unless separately asked.
- **If a safety hook blocks an action** (the authored-docs overwrite guard, a
  lock-file check), that is a correct block — resolve it the safe way (fresh `vN`,
  ask to close the file) rather than forcing the write.

## Authoring rules (important)

- **Always start from a template.** Copy the closest layout from
  `templates/single-page/` first, then replace content.
- **Use tokens, not literal colors.** Every color, radius, shadow comes from CSS
  variables in `assets/base.css`. Good: `color: var(--text-1)`. Bad: `color: #111`.
- **Do not invent new layout files.** Prefer composing existing ones. Only add a
  new `templates/single-page/*.html` if none of the 31 fit.
- **Respect chrome slots.** `.deck-header`, `.deck-footer`, `.slide-number`, and
  the progress bar come from `assets/base.css` + `runtime.js`.
- **Keyboard-first.** Always include `<script src="../assets/runtime.js"></script>`
  so the deck supports ← → / T / A / F / O / hash deep-links.
- **One `.slide` per logical page.** `runtime.js` makes `.slide.is-active` visible;
  all others are hidden.
- **Speaker notes go in `<div class="notes">`.** Never put presenter-only text as
  visible `<p>` / `<span>` on the slide — `.notes` is `display:none` and only shows
  in the notes overlay. Slides contain only audience-facing content.

## Catalogs (load when needed)

- [references/themes.md](references/themes.md) — the core themes with when-to-use.
- [references/vibe-presets.md](references/vibe-presets.md) — expressive themes by
  mood (the 39 ported design systems mapped to vibes).
- [references/style-discovery.md](references/style-discovery.md) — show-3-previews
  picker when no theme is named.
- [references/layouts.md](references/layouts.md) — all 31 static layout types.
- [references/components.md](references/components.md) — interactive components
  (flip / expand cards, live Chart.js).
- [references/animations.md](references/animations.md) — 27 CSS + 20 canvas FX
  animations.
- [references/gsap-animations.md](references/gsap-animations.md) — GSAP
  cinematic-motion engine (`data-gsap`).
- [references/full-decks.md](references/full-decks.md) — the 11 full-deck
  templates.
- [references/conversion-patterns.md](references/conversion-patterns.md) —
  convert-in: PPTX + reveal.js / Marp / impress.js / Slidev / Google Slides /
  article HTML → deck.
- [references/pptx-out.md](references/pptx-out.md) — editable-PPTX output
  (PptxGenJS toolchain; Node/bun).
- [references/authoring-guide.md](references/authoring-guide.md) — full workflow.

## File structure

```
slides/
├── SKILL.md                 (this file; embeds lint.py above — drop it into a deck build folder)
├── references/              (detailed catalogs, load as needed)
│   ├── vibe-presets.md      (39 ported themes mapped by mood)
│   ├── style-discovery.md   (show-3-previews picker)
│   ├── components.md        (interactive component catalog)
│   ├── gsap-animations.md   (GSAP cinematic engine catalog)
│   ├── conversion-patterns.md (PPTX + HTML-framework → deck)
│   └── pptx-out.md          (editable-PPTX output guide)
├── assets/
│   ├── base.css             (tokens + primitives — do not edit per deck)
│   ├── fonts.css            (webfont imports)
│   ├── runtime.js           (keyboard + overview + theme cycle + notes)
│   ├── themes/*.css         (75 token overrides: 36 core + 39 ported)
│   └── animations/
│       ├── animations.css   (27 named CSS entry animations)
│       ├── fx-runtime.js    (auto-init [data-fx] on slide enter)
│       ├── fx/*.js          (20 canvas FX modules)
│       └── gsap-engine.js   (opt-in GSAP engine via [data-gsap])
├── templates/
│   ├── deck.html                  (minimal starter)
│   ├── theme-showcase.html        (iframe-isolated per theme)
│   ├── layout-showcase.html       (iframe tour of all 31 layouts)
│   ├── animation-showcase.html    (20 FX + 27 CSS animation slides)
│   ├── full-decks-index.html      (gallery of all full-deck templates)
│   ├── full-decks/<name>/         (12 scoped multi-slide deck templates)
│   └── single-page/*.html         (31 static layouts + 4 interactive)
├── scripts/
│   ├── new-deck.sh                (scaffold a deck from deck.html)
│   ├── render.sh                  (headless Chrome → PNG)
│   ├── deploy.sh                  (Vercel deploy, publish-gated)
│   ├── export-pdf.sh              (Playwright → PDF)
│   ├── extract-pptx.py            (PPTX → slides.json + images/)
│   └── pptx-out/*.ts              (deck spec → editable .pptx, Node/bun)
└── examples/demo-deck/            (complete working deck)
```

## Keyboard cheat sheet

```
←  →  Space  PgUp  PgDn  Home  End    navigate
F                                       fullscreen
N                                       quick notes drawer (bottom overlay)
?preview=N                              URL param — preview-only (single slide, no chrome)
O                                       slide overview grid
T                                       cycle themes (reads data-themes attr)
A                                       cycle demo animation on current slide
#/N in URL                              deep-link to slide N
Esc                                     close all overlays
```

## License & author

MIT. Based on the lewislulu html-ppt-skill; ultra build and three-mode process
adapted for Douglas's slide pipeline.
