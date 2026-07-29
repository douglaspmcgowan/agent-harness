# GSAP cinematic engine

A third, opt-in animation engine for scripted, choreographed motion. It runs
GSAP timelines on slide-enter, driven by a single **mood** preset per slide.

This is the heavyweight option. The skill has three independent engines, and a
slide can use any combination:

| engine | file | how you opt in | character |
|---|---|---|---|
| CSS animations | `assets/animations/animations.css` | `data-anim="fade-up"` | lightweight fire-and-forget entry effects |
| Canvas FX | `assets/animations/fx-runtime.js` | `data-fx="matrix-rain"` | ambient, continuously-running background effects |
| **GSAP** | `assets/animations/gsap-engine.js` | `data-gsap="cinematic"` | **scripted, choreographed timeline entrances** |

Use GSAP when you want one slide's content to arrive as a single directed
sequence — title rises, then items stagger in underneath with a chosen physical
feel. For a plain entry effect, reach for `data-anim` first; it needs no CDN.

## CDN includes required

GSAP loads from CDN. Add both lines to your deck `<head>` (or before
`</body>`), with the core GSAP script FIRST:

```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.12.5/gsap.min.js"></script>
<script src="../assets/animations/gsap-engine.js"></script>
```

Only core `gsap` is needed — no ScrollTrigger, SplitText, or other plugins. If
the GSAP script is missing, the engine fails safe: it shows every targeted
element immediately and logs one warning. Nothing breaks.

## Opting a slide in

Put `data-gsap="<mood>"` on the `.slide`. That is the entire contract — a slide
without `data-gsap` is never touched.

```html
<section class="slide" data-gsap="cinematic">
  <h1 class="title">The reveal</h1>
  <p data-gsap-item>First line arrives after the title.</p>
  <p data-gsap-item>Then this one staggers in.</p>
</section>
```

The timeline re-fires every time you navigate onto the slide (it resets on
leave), so the entrance replays cleanly on every visit — same lifecycle as the
`data-fx` canvas effects.

## The four moods

Each mood is a timing + easing preset adapted from the spring-physics table
below. Pick by the feel you want, not by content type.

| mood | duration | stagger | easing | feel |
|---|---|---|---|---|
| `professional` | 0.5s | 0.06s | `power2.out` | Settled, no overshoot. The default. |
| `playful` | 0.7s | 0.10s | `back.out(1.7)` | Slight overshoot, bouncy arrival. |
| `cinematic` | 1.2s | 0.15s | `power1.inOut` | Slow, deliberate, weighty. |
| `energetic` | 0.4s | 0.08s | `back.out(2)` | Fast and punchy with snap. |

The title always animates first (`y` offset + fade), then marked items stagger
in beginning slightly before the title finishes, so the motion overlaps rather
than waiting step-by-step.

## Spring-physics easing reference

The moods are derived from Remotion-style spring configs translated to GSAP
easing. Use this table to pick a custom `ease` if you fork the engine:

| spring config | GSAP equivalent | duration | character |
|---|---|---|---|
| smooth (damping: 200) | `power3.out` | 0.6–0.8s | Settled, no bounce |
| snappy (damping: 20) | `back.out(1.2)` | 0.4–0.6s | Quick with overshoot |
| bouncy (damping: 8) | `elastic.out(1, 0.4)` | 0.8–1.2s | Playful oscillation |
| heavy (mass: 5) | `power2.inOut` (2× duration) | 1.5–2.0s | Deliberate, weighty |

## Marking individual elements

By default the engine animates the slide's heading (`h1, h2, .title, .h1, .h2`)
plus a sensible content set. To control exactly what staggers in, mark each
element with `data-gsap-item`:

```html
<section class="slide" data-gsap="energetic">
  <h2 class="title">Three metrics</h2>
  <div class="grid">
    <div class="card" data-gsap-item>42%</div>
    <div class="card" data-gsap-item>1,248</div>
    <div class="card" data-gsap-item>3.1×</div>
  </div>
</section>
```

If no element carries `data-gsap-item`, the engine falls back to animating
`li`, `.card`, `.grid > *`, and `[data-anim]` elements on the slide (the title
is always excluded from the stagger set). Mark items explicitly whenever you
want precise control or want to skip the fallback.

## Reduced motion

When `prefers-reduced-motion: reduce` is set, the engine runs no timeline. Every
targeted element is made visible immediately and the slide reads instantly. This
matches the CSS engine's behavior — do not override it.

## How it does NOT conflict

The engine reads only `data-gsap` and `data-gsap-item`. It never touches
`data-anim` (CSS) or `data-fx` (canvas) elements, and it tracks its timelines in
its own `window.__hpxGsap` registry, separate from FX's `window.__hpxActive`.
You can stack all three on one slide — a `data-fx` canvas background, a
`data-gsap` scripted entrance for the foreground content, and `data-anim` on a
one-off badge — and they run independently.

## Examples

### Cinematic cover

```html
<section class="slide" data-gsap="cinematic">
  <p class="eyebrow">2026 Annual Review</p>
  <h1 class="title">A year in motion</h1>
  <p class="lede" data-gsap-item>Everything we shipped, one slow reveal.</p>
</section>
```

### Energetic stat grid (paired with a canvas FX background)

```html
<section class="slide" data-gsap="energetic">
  <div data-fx="gradient-blob" style="position:absolute;inset:0;"></div>
  <h2 class="title">By the numbers</h2>
  <div class="grid">
    <div class="card" data-gsap-item><span class="h1">98%</span> uptime</div>
    <div class="card" data-gsap-item><span class="h1">12ms</span> p50</div>
    <div class="card" data-gsap-item><span class="h1">0</span> incidents</div>
  </div>
</section>
```

### Playful list

```html
<section class="slide" data-gsap="playful">
  <h2 class="title">What's next</h2>
  <ul>
    <li data-gsap-item>Ship the new pipeline</li>
    <li data-gsap-item>Cut latency in half</li>
    <li data-gsap-item>Open the beta</li>
  </ul>
</section>
```

## Tips

- One mood per slide. The mood is the whole stylistic decision — you do not mix
  easings within a slide.
- `cinematic` (1.2s) is long; use it on covers and section breaks, not on dense
  content slides where the audience is reading.
- Reach for `data-anim` first for ordinary entrances — it needs no CDN and is
  cheaper. Use `data-gsap` when the choreography itself is the point.
- To re-trigger manually (e.g. after swapping content), call
  `window.__hpxGsapReplay(slideEl)`.

## What was lost adapting the scroll recipes

The source recipes assumed a ScrollTrigger / pinned-scroll model with
`.reveal` / `.slide-title` classes. Three things did not carry over to the
keyboard-nav `.is-active` model:

- **ScrollTrigger pinning and `onEnterBack`** — there is no scroll position, so
  pinning is meaningless. Slide-enter is detected by the `.is-active` class
  toggle instead, and "scroll back up" simply becomes "navigate back onto the
  slide," which replays the same entrance.
- **`gsap.matchMedia` desktop/mobile branching** — decks render at a fixed
  16:9 design resolution and scale to fit, so there is no responsive viewport to
  branch on. Only the reduced-motion condition was kept.
- **Scroll-progress-driven tweens (parallax, scrub)** — any effect tied to
  scroll fraction has no analog under one-slide-at-a-time navigation and is not
  supported.
