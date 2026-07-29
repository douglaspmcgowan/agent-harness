# Conversion Patterns

How to turn an existing presentation — a `.pptx` file or an HTML deck built in
some other framework — into a deck in **this** skill's format.

## The output contract (what every conversion must produce)

Whatever the source, the result is a single `index.html` shaped like
`templates/deck.html`:

- One `<div class="deck">` wrapping all slides.
- Each slide is `<section class="slide" data-title="...">`. The **first** slide
  also carries `class="slide is-active"` (the runtime promotes it on load, but
  set it explicitly so the file is correct when opened statically or printed).
- Center-anchored slides add `center tc` → `<section class="slide center tc">`.
- Speaker notes go in `<div class="notes">…</div>` at the end of each slide.
  They are hidden by default and shown in presenter mode (`S`) / notes overlay (`N`).
- **No hardcoded colors or hex.** Use the CSS tokens from `assets/base.css`:
  `--text-1/-2/-3`, `--surface`, `--surface-2`, `--border`, `--accent/-2/-3`,
  `--good/-warn/-bad`, `--radius`, `--shadow`, `--grad`. Use the helper classes
  (`.h1 .h2 .h3 .kicker .lede .dim .card .grid .g2/.g3 .pill .gradient-text …`).
- Head links, in this order:
  ```html
  <link rel="stylesheet" href="../assets/fonts.css">
  <link rel="stylesheet" href="../assets/base.css">
  <link rel="stylesheet" id="theme-link" href="../assets/themes/<name>.css">
  <link rel="stylesheet" href="../assets/animations/animations.css">
  ```
  Pick `<name>` from `assets/themes/` (e.g. `minimal-white`, `aurora`,
  `tokyo-night`). Set `data-theme="<name>"` on `<html>` and the theme list on
  `<body data-themes="..." data-theme-base="../assets/themes/">`.
- Navigation comes from one script tag — **no** framework JS:
  ```html
  <script src="../assets/runtime.js"></script>
  ```
  It provides: `←/→`/space/PageUp/Down nav, `T` theme, `A` animation, `F`
  fullscreen, `O` overview, `N` notes, `S` presenter window.
- **Relative depth:** `templates/deck.html` uses `../assets/...` (deck one level
  below the skill root). A deck under `examples/<name>/index.html` is two levels
  down, so it uses `../../assets/...`. The `scripts/new-deck.sh` scaffolder does
  this rewrite for you — start from it, then fill slides.

Start from `templates/deck.html` (or run `scripts/new-deck.sh <name>`) and
replace the placeholder slides with converted content. Never invent numbers or
text the source didn't contain.

---

## PPTX → deck

PowerPoint is a binary format — extract first, then map the JSON to slides.

1. **Extract** with the bundled script:
   ```
   python scripts/extract-pptx.py <input.pptx> [output_dir]
   ```
   It writes `<output_dir>/slides.json` plus `<output_dir>/images/`. Each slide
   in the JSON has: `title`, `body` (a list of `{text, level}` paragraphs where
   `level` is the bullet indent depth), `tables`, `images` (with px sizes),
   `notes`, and `warnings`.
   (python-pptx required; a venv with it lives at
   `C:\Users\dougl\Documents\Claude Folder\.venv-slides`.)

2. **Map each JSON slide → one `<section class="slide">`:**

   | JSON field | → deck output |
   |---|---|
   | `title` | `<h2 class="h2">…</h2>` (use `.h1` for the first/cover slide) |
   | `body` paragraphs | a `<ul>`; nest by `level` (level 0 = top `<li>`, level 1 = nested `<ul><li>`) |
   | a body para with no siblings & a title | consider `.lede` instead of a one-item list |
   | `tables[].rows` | a `<table>` (header row = first row); keep ≤ 5 cols × 6 rows, summarize if larger |
   | `images[]` | `<img src="images/…">` constrained per **Image handling** below |
   | `notes` | `<div class="notes">…</div>` (escape `&`, `<`, `>`) |
   | `warnings` | not rendered — they tell you what to rebuild by hand |

3. **Copy the images folder** next to the generated `index.html` so
   `src="images/slideNN_imgN.ext"` resolves.

4. **Pick layouts, don't transcribe.** A title + 3 bullets is often better as a
   3-card grid (`.grid.g3` with `.card`) than a literal `<ul>`. A single big
   number reads better as a stat slide (`.slide.center.tc` + `.counter`). Match
   the intent; keep the words.

The extractor flags what it cannot carry over in `warnings` (charts, embedded
media, grouped/positioned shapes). See **Fidelity limits** at the bottom.

---

## HTML deck → deck (framework detection)

Check the source HTML for these signatures, then apply the matching extraction.
In every case the **output** is the contract at the top of this file.

### reveal.js

**Detect:** `<div class="reveal">` container; `<section>` slides (may be nested
for vertical stacks); `Reveal.initialize()` / `new Reveal()`; a CDN link to
`reveal.js`.

**Extract → deck:**
- Each top-level `<section>` → one `<section class="slide">`.
- Nested `<section>` (vertical slides) → flatten into sequential slides.
- `<aside class="notes">` → `<div class="notes">` on that slide.
- `class="fragment"` content → keep all of it; drop the fragment stepping (the
  runtime animates whole slides, not fragments).
- `<pre><code>` → keep inside a `.card`; preserve the language class if any.
- `data-background` color/image → set as an inline `background` on the slide
  using a token where possible (e.g. `style="background:var(--surface-2)"`).

**Strip:** all reveal.js JS (`Reveal.initialize()`, plugins), `reveal.css` and
its theme CSS, plugin scripts (markdown/highlight/notes/math).

### Marp

**Detect:** `<!-- marp: true -->`; `class="marpit"`; Marp-specific `<style>`
targeting `section`; `data-marpit-*` attributes.

**Extract → deck:**
- Each `<section>` → one `<section class="slide">`.
- Headings/paragraphs/lists map directly to `.h2`/`.lede`/`<ul>`.
- Marp image sizing (`w:` / `h:`) → drop it; apply the standard image
  constraints below.
- `<!-- _notes: … -->` comments → `<div class="notes">`.
- `![bg](url)` backgrounds → inline `background` on the slide.

**Strip:** Marp engine JS, Marp theme CSS (replaced by base/theme tokens),
`data-marpit-*`.

### impress.js

**Detect:** `<div id="impress">`; `class="step"` elements; `impress().init()`;
`data-x`/`data-y`/`data-z` positioning.

**Extract → deck:**
- Each `.step` → one `<section class="slide">`, in document order.
- Discard 3D positioning (`data-x/y/z/rotate/scale`) — slides are sequential.
- Pull text, images, and code from each step into token-styled blocks.

**Strip:** impress.js core + plugins, 3D-transform CSS, all positioning attrs.

### Slidev

**Detect:** `class="slidev-layout"` / `class="slidev-page"`; `<div id="app">`
with Slidev structure; Vue component artifacts.

**Extract → deck:**
- Each `.slidev-page` (or `<section>`) → one `<section class="slide">`.
- Markdown-rendered headings/lists/code map to the helper classes.
- Component blocks → keep their text content; drop Vue interactivity.
- `<!-- notes -->` blocks → `<div class="notes">`.

**Strip:** Vue/Slidev runtime, Slidev layout CSS, component interactivity.

### Google Slides export

**Detect:** deeply nested `<div>`s with auto-generated class names (`.c0`,
`.c1`, …); `<svg>` for shapes/text; `<style>` full of `.cN {}` selectors;
sometimes `punch-viewer-content`.

**Extract → deck:**
- Each top-level container div ≈ one slide → `<section class="slide">`.
- Text usually sits in `<span>`s with inline styles — take plain text only.
- Images may be base64 or external refs (see **Image handling**).
- Layout is absolute-positioned — ignore positions and reflow into normal flow
  (a heading + list, or a `.grid` of `.card`s).

**Strip:** all Google-generated CSS (meaningless class names), SVG shape
decorations (keep an SVG only if it *is* the content), inline positioning. If a
Google Fonts `<link>` is present you may keep it.

### Already a deck of this skill (partially compliant)

**Detect:** has `<div class="deck">` and `<section class="slide">` but is
missing pieces (no `is-active` on slide 1, wrong asset paths, no `runtime.js`,
hardcoded colors).

**Fix — minimal, do not restructure:**
- Add `is-active` to the first slide.
- Repair the head links to the five-line block above and fix `../` depth.
- Add `<script src="../assets/runtime.js"></script>` if absent; remove any other
  nav JS.
- Replace hardcoded hex with the nearest token.
- Add `<div class="notes">` wrappers if notes are sitting as loose text.

### Article / blog HTML

**Detect:** `<article>`, or `<main>` with heading-structured content; sequential
`h1 → h2 → h3` with paragraphs; no slide-framework signatures.

**Extract → deck:**
- First `<h1>` → cover slide (`.slide` + `.h1`, often `center tc`).
- Each `<h2>` → a new `<section class="slide">` with `.h2`.
- `<h3>` inside an h2 section → sub-heading; keep on the same slide if it fits
  the density limits below, else split to a new slide.
- `<p>` → `.lede` text or bullet points (summarize over-long paragraphs).
- `<ul>`/`<ol>` → `<ul>` (split if > 6 items).
- `<pre><code>` → code block inside a `.card`.
- `<table>` → a table slide.
- `<blockquote>` → a quote slide (`.serif` `<blockquote>`, centered).
- `<img>`/`<figure>` → image slide, caption in `.dim`.
- Strip `<nav>`, `<header>`, `<footer>`, `<aside>` — chrome, not content.

**Density limits:** ≤ 4–6 bullets/slide; ≤ 2 short paragraphs/slide; code ≤ 8–10
lines (truncate with `// …`); tables ≤ 5 cols × 6 rows.

### Generic / unknown HTML

**Detect:** none of the above.

**Fallback:** treat `<main>`/`<article>`/`<body>` as the root, strip nav/header/
footer/aside, then apply the article rules. With no heading structure, start a
new slide roughly every ~200 words.

---

## CSS strategy

The deck's look comes entirely from `base.css` + the chosen theme file. So:

1. **Discard framework and reset CSS** (reveal.css, Marp themes, normalize/reset)
   — base.css supplies the reset and the theme supplies the palette.
2. **Do not fetch CDN CSS.** Keep only a Google-Fonts / Fontshare `<link>` if the
   source relied on one and you want that face; otherwise `fonts.css` covers it.
3. **Map source colors to tokens** instead of inlining hex. A brand blue →
   `var(--accent)`; muted body text → `var(--text-2)`; panel backgrounds →
   `var(--surface-2)`. Never paste raw hex into the converted slides.
4. **After converting, confirm** no `<link rel="stylesheet">` remains except the
   four skill stylesheets (+ an optional font link).

## JS strategy

Framework navigation is **replaced**, not merged.

1. **Strip** all framework init (`Reveal.initialize()`, `impress().init()`, …),
   their event handlers, plugins, transitions, and keyboard handlers.
2. **Keep** genuine data/chart logic — e.g. a Chart.js config. Add the Chart.js
   CDN `<script>` in `<head>` and render into a `<canvas>` inside a `.card`, as
   in `examples/demo-deck/index.html`. Read theme tokens via
   `getComputedStyle(document.documentElement).getPropertyValue('--accent')` so
   the chart recolors when the user presses `T`.
3. **Add** exactly one nav script: `<script src="../assets/runtime.js"></script>`.

## Image handling

- **Relative URLs** — keep as-is and copy the files next to `index.html`.
- **Absolute URLs** — keep, but warn that the deck won't render offline.
- **Base64** — keep if < ~500 KB; if larger, save to an `images/` file and
  reference it.
- **Inline SVG** — keep as-is.
- Constrain every image so it never overflows a slide:
  ```html
  <img src="images/…" alt=""
       style="max-height:min(50vh,400px);width:auto;object-fit:contain">
  ```
  For an image + text slide, drop it into a `.grid.g2` (image one column, text
  the other). For a full-bleed image, a single centered `<img>` on a
  `.slide.center` works.

---

## Fidelity limits (what is lost in conversion)

Be honest with the user about these — none of them survive a faithful, static,
zero-build conversion:

- **Animations & transitions.** PPTX entrance/exit/motion paths, reveal.js
  fragments, impress.js 3D camera moves, Slidev click-steps — all dropped. The
  runtime animates whole slides; re-add emphasis manually with the `data-anim`
  classes from `references/animations.md` if wanted.
- **Charts.** PPTX native charts are **not** extracted (flagged as a warning) —
  rebuild as a Chart.js block or export a static image. HTML-framework charts
  survive only if they were already Chart.js/canvas-driven.
- **Complex / absolute layouts.** Grouped and absolutely-positioned shapes
  (PPTX groups, Google Slides exports, impress.js positions) are flattened into
  normal document flow. Overlaps, precise alignment, and z-ordering are lost;
  you reflow into grids/cards.
- **SmartArt, WordArt, icons-as-shapes, embedded media (video/audio).** Not
  extracted. Text inside SmartArt may come through as plain paragraphs; the
  diagram shape does not.
- **Theme fonts & exact colors.** The deck re-skins to a chosen theme's tokens,
  so the source's exact palette and typefaces are intentionally replaced, not
  reproduced.
- **Tables** carry text only — merged cells, cell fills, and borders are lost.
- **Slide masters / templates, footers, page numbers, transitions metadata** are
  dropped; the deck supplies its own chrome (`.deck-footer`, `.slide-number`).
