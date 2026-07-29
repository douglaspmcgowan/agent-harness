# pptx-out — editable PowerPoint OUTPUT toolchain

A TypeScript (PptxGenJS) toolchain that generates **native, editable `.pptx` files** from
deck content. This is the OUTPUT counterpart to `scripts/extract-pptx.py`.

| Direction | Script | Flow |
|-----------|--------|------|
| **IN**  | `scripts/extract-pptx.py` | `.pptx` → `slides.json` → HTML deck (lewislulu format) |
| **OUT** | `scripts/pptx-out/` (this) | deck/content outline → native editable `.pptx` |

The output is real PowerPoint shapes and text boxes — click-to-edit, not a screenshot or an
image-flattened slide. Recipients can open it in PowerPoint / Keynote / Google Slides and edit
every element directly.

---

## Honest limitations — read before you reach for this

- **Heavier dependency than the rest of this skill.** Everything else in slides-ultra is a
  zero-build HTML/CSS/JS + Python toolchain. This path needs a **Node/TypeScript runtime** and
  pulls native npm packages (`pptxgenjs` plus `skia-canvas`, `fontkit`, `linebreak`, `prismjs`).
  `skia-canvas` ships prebuilt native binaries, so first run downloads a platform-specific build.
- **The HTML token themes do NOT carry over.** The lewislulu CSS variables / token themes that
  drive the HTML decks are unrelated to the `.pptx` output. PptxGenJS has its **own** theme
  system in `scripts/pptx-out/theme.ts` (12 presets: darkMonospace, swissModern, boldSignal,
  darkBotanical, cleanCorporate, neonCyber, warmMinimal, vintageEditorial, terminalGreen,
  gradientWave, midnightBlue, paperInk). To match a deck's look you re-express the colors and
  fonts as a PptxGenJS theme — there is no automatic bridge from HTML to PPTX.
- **No PNG/PDF render of the `.pptx` is built in.** This toolchain emits the `.pptx` file only.
  Use PowerPoint, LibreOffice, or the existing `scripts/export-pdf.sh` path on a separate HTML
  deck if you need a rendered preview.

Use this when the user explicitly wants an **editable PowerPoint file**. For a web/HTML deck,
stay on the main slides-ultra HTML path.

---

## Setup

The toolchain runs on **`bun`**, which executes TypeScript directly with no build step and
auto-installs the npm dependencies on first run:

```bash
# from scripts/pptx-out/
npx -y bun main.ts theme list
```

On first run, bun resolves and installs `pptxgenjs`, `skia-canvas`, `fontkit`, `linebreak`, and
`prismjs` automatically (a `node_modules/` appears; `.gitignore` already excludes it). No manual
`npm install` step is required when using bun.

If you prefer to run with `tsx` / `ts-node` instead of bun, install the deps explicitly first:

```bash
cd scripts/pptx-out
npm init -y
npm install pptxgenjs skia-canvas fontkit linebreak prismjs
npm install -D tsx          # or: npm install -D ts-node typescript
npx tsx main.ts theme list  # or: npx ts-node main.ts theme list
```

Note: the helper modules import each other with `./types.js` style specifiers (ESM `.js`
extensions that resolve to the `.ts` sources). `bun` and `tsx` handle this out of the box;
a plain `ts-node` setup may need `moduleResolution` aligned with the bundled `tsconfig.json`.

---

## Generating a deck — the end-to-end command

`main.ts` is **not** a deck generator. It is a library re-export hub plus a small CLI that only
exposes `theme list`, `theme show <name>`, and a `validate` stub:

```bash
npx -y bun main.ts theme list           # list the 12 theme presets
npx -y bun main.ts theme show swissModern
```

To actually produce a `.pptx`, you **author a TypeScript script** that imports the helpers from
`main.ts`, builds slides with PptxGenJS, validates, and writes the file. The "slide-spec" is this
script — there is no JSON deck format consumed by a built-in generator.

A minimal `build-deck.ts` placed next to the helpers:

```typescript
import pptxgen from 'pptxgenjs';
import * as h from './main.js';   // re-exports every helper module

const pptx = new pptxgen();
pptx.layout = 'LAYOUT_16x9';      // 10" × 5.625"

const theme = h.createTheme(h.PRESETS.swissModern);

// Title slide
const s1 = pptx.addSlide();
s1.background = { color: theme.bg.primary };
s1.addText('Deck Title', {
  x: 0.5, y: 1.2, w: 9, h: 1.8,
  fontSize: 44, fontFace: h.resolveFont(theme, 'heading'),
  color: theme.text.primary, bold: true, align: 'center',
});
s1.addNotes('Speaker notes for the title slide.');

// Content slide using a high-level builder
const s2 = pptx.addSlide();
h.addFeatureGrid(s2, {
  x: 0.5, y: 1.2, w: 9, h: 3.8, cols: 3, rows: 2, theme,
  features: [
    { title: 'Fast',     description: 'Lightning quick' },
    { title: 'Reliable', description: 'Production-tested' },
    { title: 'Simple',   description: 'Easy to use' },
  ],
});
s2.addNotes('Talk through each feature.');

// Validate, then write
const report = h.validateDeck(pptx);
report.issues.forEach((i) => console.error(`[issue] ${i.message}`));
report.warnings.forEach((w) => console.warn(`[warn] ${w.message}`));

await pptx.writeFile({ fileName: 'deck.pptx' });
console.log('wrote deck.pptx');
```

Run it:

```bash
npx -y bun build-deck.ts        # → deck.pptx in the working directory
# or, with tsx:  npx tsx build-deck.ts
```

The whole workflow: **write a `build-deck.ts` → import `* as h` from `main.ts` → add slides with
helpers → `h.validateDeck(pptx)` → `await pptx.writeFile(...)`.**

---

## Slide-spec / authoring model

There is no declarative deck schema; the "spec" is the imperative PptxGenJS script. The pieces
you compose with:

- **Slide primitives** (PptxGenJS): `pptx.addSlide()`, then `slide.addText()`, `slide.addShape()`,
  `slide.addImage()`, `slide.addTable()`, `slide.addNotes()`, and `slide.background = { color }`.
  Canvas is 16:9 at 10" × 5.625"; safe margin 0.5" on all edges.
- **Theme tokens** (`theme.ts`): `h.createTheme(overrides?)` → a frozen `SlideTheme` with
  `bg.{primary,secondary}`, `text.{primary,secondary}`, `accent`, `accentSecondary`, plus `font`,
  `size`, `spacing`, `radius`, and `shadow` blocks. Use `h.PRESETS.<name>` for the 12 presets and
  `h.resolveFont(theme, 'heading'|'body'|'mono')` for fallback chains. Never hardcode colors.
- **Adaptive sizing** (`text.ts`): `h.scale(min, max, { bullets, textLength })` for clamp-style
  font sizing, and `h.autoFontSize(text, fontFace, { w, h, mode })` for binary-search box fitting
  (skia-canvas font measurement).
- **High-level builders** (`layout_builders.ts`): `addFeatureGrid`, `addCardRow`,
  `addImageTextCard`, `addTimeline`, `addMetricsRow`, `addComparisonTable`, `addThreeLevelTree` —
  each takes a region `{ x, y, w, h }`, a `theme`, and a data array.
- **Decorative elements** (`decorative.ts`): `addStaircase`, `addSectionBadge`, `addProgressBar`,
  `addSectionDivider`, `addSlideNumber`.
- **Layout utilities** (`layout.ts`): `alignSlideElements`, `distributeSlideElements`,
  `warnIfSlideHasOverlaps`, `warnIfSlideElementsOutOfBounds`, `getSlideDimensions`.
- **Media helpers**: `image.ts` (`getImageDimensions`, `imageSizingCrop`, `imageSizingContain`),
  `svg.ts` (`svgToDataUri`), `code.ts` (`codeToRuns` for Prism syntax highlighting).
- **Validation** (`validation.ts`): `h.validateDeck(pptx)` → `{ passed, issues, warnings, stats }`.
  Checks: font size ≥ 14pt, ≤ 6 bullets/slide, elements in bounds, speaker notes present.

The full type surface lives in `scripts/pptx-out/types.ts`.

### Design rules carried over from the source skill

- Body text ≥ 18pt (24–28 preferred); titles 36–44pt; captions ≥ 14pt floor.
- ≤ 6 bullets per slide; target 40–50% whitespace.
- Use theme tokens and `scale()` / `autoFontSize()` instead of hardcoded colors and sizes.
- Add `slide.addNotes(...)` to every content slide.
- Run `validateDeck()` before writing; keep native text boxes editable (never flatten to images).

---

## Where the detail lives

- **`references/pptx-out-helpers.md`** — full API reference for every helper module (signatures,
  return types, examples).
- **`references/pptx-out-patterns.md`** — copy-paste slide patterns (title, bullets, two-column,
  card row, quote, timeline, feature grid, code, section divider, comparison, tree, metrics) with
  exact dimensions and positioning.
- **`scripts/pptx-out/*.ts`** — the toolchain source. `main.ts` is the import hub and CLI;
  `tsconfig.json` is the bundled bun/TS config.

> Note: the source skill's docs reference helpers via a `${CLAUDE_PLUGIN_ROOT}/skills/pptx-slides/
> scripts/main.ts` path token. Inside slides-ultra the equivalent path is
> `scripts/pptx-out/main.ts` — adjust the import specifier accordingly when copying a pattern.
