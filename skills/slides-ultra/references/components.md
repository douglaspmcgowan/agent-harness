# Interactive components catalog

These are the **interactive / JS-driven** slide components, merged in from the
bluedusk component set. They complement the 31 static layouts in
[`layouts.md`](layouts.md) — reach for one of these only when the slide needs
*behavior* (a flip, an expand, a chart that builds on entry). For everything
else, a static layout is lighter and prints cleanly.

Each component lives in `templates/single-page/<name>.html` as a fully
functional standalone page with realistic demo data, built on the same
lewislulu tokens (`--accent`, `--surface`, `--text-1`, `--radius`, `--shadow`,
…), keyboard nav, and zero-build philosophy as the static layouts. Open any
file directly in Chrome to see it working.

To compose into a deck: copy the `<section class="slide">…</section>` block
into your deck HTML and replace the demo data. Any required JS is inline and
scoped to that one slide, so it travels with the block.

## How interactive init is wired to slide-enter

Static layouts need nothing — `runtime.js` toggles `.is-active`, replays
`data-anim`, and runs `.counter` count-ups. But it does **not** emit a generic
slide-enter event, so a Chart.js canvas or any "build on show" component has to
watch for activation itself.

`chart-live.html` mirrors the exact trigger `assets/animations/fx-runtime.js`
uses: a `MutationObserver` on its own `.slide`, filtered to the `class`
attribute. When `is-active` is added the chart builds; when it is removed the
chart is destroyed. If the slide is already active on load (single-page mode,
or the deck's first slide) it builds immediately. Every access is guarded —
if Chart.js failed to load from CDN, or the slide is never shown, nothing
throws. Use the same pattern for any future build-on-enter component.

The flip / expand components are pure CSS-transform + a one-line
`onclick="this.classList.toggle(...)"`; they have no lifecycle and work the
moment the markup is on the page.

## Components

| file | purpose |
|---|---|
| `flip-cards.html` | 2×2 grid of click-to-flip cards. Front = title + one-liner, back = the detail. |
| `expand-cards.html` | 2×2 grid of click-to-expand cards. Short summary up top, hidden detail slides open on click. |
| `auth-flip.html` | Two big flip cards split by a `vs`. Bad vs good / before vs after; each flips to reveal *why*. |
| `chart-live.html` | A real Chart.js canvas that builds on slide-enter and tears down on leave (deck-safe, theme-aware). |

## When to use which

- **4 concepts, each with a short label + a detail** → `flip-cards.html`
  (the detail is the *same kind of thing* as the front, just longer) or
  `expand-cards.html` (the detail is *how-to / deeper* and you want both visible
  in sequence). Flip hides the front; expand keeps it.
- **A two-sided judgment** (bad vs good, old vs new, myth vs reality) where the
  payoff is the reasoning → `auth-flip.html`. For a *static* two-panel compare
  with no reveal, use `comparison.html` / `pros-cons.html` / `diff.html` instead.
- **A chart inside a long deck, or any chart you want lazy-built** →
  `chart-live.html`. The existing `chart-bar/line/pie/radar.html` build on
  `DOMContentLoaded`, which is fine for a one-chart page but builds every chart
  up front in a multi-chart deck. `chart-live` defers the work to the moment its
  slide shows.

## Usage snippets

### flip-cards.html — click to flip

Each card is a `.flip-card` with two stacked faces; the click toggles `flipped`,
which rotates it 180° on the Y axis. The accent stripe cycles
`--accent → --accent-2 → --good → --accent-3` by cell position.

```html
<div class="flip-cell"><div class="flip-card" onclick="this.classList.toggle('flipped')">
  <div class="flip-face flip-front">
    <div class="flip-icon">🎨</div>
    <div class="flip-title">[FRONT TITLE]</div>
    <div class="flip-sub">[FRONT ONE-LINER]</div>
    <div class="flip-hint">click</div>
  </div>
  <div class="flip-face flip-back">
    <p class="flip-detail">[BACK DETAIL with <strong>bold keywords</strong>]</p>
  </div>
</div></div>
```

### expand-cards.html — click to expand

The hidden block (`.exp-more`) animates from `max-height:0` to open on the
`.open` class. Chevron rotates 180° when open.

```html
<div class="exp-card" onclick="this.classList.toggle('open')">
  <div class="ic">📋</div>
  <h4>[TITLE]</h4>
  <p class="desc">[ONE-LINE SUMMARY]</p>
  <div class="exp-more"><div class="exp-more-in">[DETAIL with inline <code>code</code>]</div></div>
  <span class="exp-chevron">▼</span>
</div>
```

### auth-flip.html — flip compare

Two `.fc-cell` columns separated by a `.fc-vs` divider. Mark the bad card
`fc-front bad` (red stripe) and the good card `fc-front good` (green stripe).

```html
<div class="fc-cell anim-fade-left" data-anim="fade-left">
  <div class="fc-card" onclick="this.classList.toggle('flipped')">
    <div class="fc-face fc-front bad">
      <div class="fc-icon">🧱</div>
      <div class="fc-name">[BAD NAME]</div>
      <div class="fc-mark">✕</div>
      <div class="fc-tag">[BAD CODE/TAG]</div>
      <div class="fc-hint">click to flip</div>
    </div>
    <div class="fc-face fc-back">
      <p class="fc-why">[WHY, with <strong class="bad">red emphasis</strong>]</p>
    </div>
  </div>
</div>
<div class="fc-vs">vs</div>
<!-- right cell: swap `bad`→`good`, ✕→✓, anim-fade-left→anim-fade-right,
     and use <strong class="good"> in the back -->
```

### chart-live.html — Chart.js built on slide-enter

Load Chart.js once in `<head>`:

```html
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.3/dist/chart.umd.min.js"></script>
```

The slide holds a `<canvas>` and an inline IIFE that reads theme tokens
(`--accent`, `--accent-2`, `--text-2`, `--border`) at build time, then builds
on `is-active` and destroys on leave via a `MutationObserver`:

```html
<div class="card mt-l" style="height:500px;padding:28px"><canvas id="chart-live"></canvas></div>
<script>
(function(){
  var canvas = document.getElementById('chart-live');
  if (!canvas) return;
  var slide = canvas.closest('.slide'); if (!slide) return;
  var instance = null;
  function build(){
    if (instance || typeof Chart === 'undefined') return;
    var css = getComputedStyle(document.documentElement);
    var accent = css.getPropertyValue('--accent').trim() || '#3b6cff';
    // …read other tokens, then `instance = new Chart(canvas, { … })` in a try/catch
  }
  function teardown(){ if (instance){ try{ instance.destroy(); }catch(e){} instance = null; } }
  if (slide.classList.contains('is-active')) build();
  new MutationObserver(function(m){
    for (var i=0;i<m.length;i++) if (m[i].attributeName==='class'){
      slide.classList.contains('is-active') ? build() : teardown();
    }
  }).observe(slide, { attributes:true, attributeFilter:['class'] });
})();
</script>
```

When changing the data, keep the build inside `try { … } catch {}` and keep the
`if (typeof Chart === 'undefined') return;` guard — that is what keeps the slide
from throwing if the CDN is blocked.

## Conventions (same as the static layouts)

- Each slide is `<section class="slide" data-title="…">`; the standalone file
  marks it `is-active` and the body `class="single"`.
- All colors / radius / shadow come from tokens — no hard-coded hex. Bad/good
  states use `--bad` / `--good`; accents cycle `--accent → --accent-2 → --accent-3`.
- Header pills use `.kicker`; titles use `.h2`; supporting text uses `.dim`.
- Entrance motion uses the named classes from `animations.css`
  (`anim-stagger-list`, `anim-fade-left`, `anim-fade-right`).
- Speaker notes go in a per-slide `<div class="notes">…</div>`.
- Inline interaction JS stays scoped to its own slide so the copied
  `<section>` block is self-contained.
