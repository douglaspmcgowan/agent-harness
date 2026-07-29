# Style discovery — show 3 previews, let the user pick

A visual alternative to the name-picking step in SKILL.md's *"Before you author
anything"* section. Instead of asking the user to choose a theme by name from a
list of 75, render one representative slide in three candidate themes, show
them, and let the user react to what they see. Most people can't describe a look
in words; they recognize it instantly on screen.

Use this whenever the user **hasn't named a theme** — or says "you pick", "make
it look good", "you pick", "whatever", or hands you content with no style cue. If the
user already named a theme, skip this and use it; if they named one but seem
unsure, offer it as one of the three.

The library this picks from lives in `assets/themes/` — 75 themes after the
parallel port (the original 36 core themes plus 39 expressive ones). The core
themes are cataloged in [themes.md](themes.md); the expressive half — the
frontend-slides "bold" systems and the bluedusk vibes — is cataloged in
[vibe-presets.md](vibe-presets.md). Pull candidates from both.

## The flow

1. **Read the brief.** Audience, purpose, tone, slide count, content density.
   Infer the mood if the user didn't state one (a board readout reads sober; a
   creator launch reads warm and loud).
2. **Choose 3 candidate themes that span different moods.** Pick a spread, not
   three neighbors. A good default trio covers:
   - one **clean / corporate** (light, restrained, content-first),
   - one **bold / editorial** (committed palette, display type, personality),
   - one **dark / technical** (dark canvas, mono accents, atmosphere).
   Adjust the spread to the audience — see the [trios table](#audience--candidate-trios)
   below. For a high-stakes formal deck, make all three restrained and let them
   differ by warmth and accent rather than by loudness.
3. **Render one representative slide in each theme.** Use the same slide content
   for all three so the user is comparing *look*, not *copy*. Two ways to do it
   — pick whichever fits (see [Building the previews](#building-the-previews)).
4. **Present them.** Open the three preview files (or three `?preview` URLs).
   Name each theme in your message to the user, never on the slide itself.
5. **The user picks one.** The whole deck then adopts that theme — set it once
   on the deck's `<link id="theme-link">` and author every slide against it.

## Preview authenticity (non-negotiable)

The preview must look like a real first slide of the user's deck, not a
diagnostic card. Carry this over from frontend-slides verbatim:

- Never render workflow text on a slide: no "preview", "option A/B/C", "style
  option", theme names, slugs, file names, or paths.
- Never render the user's requirement notes ("safe option", "bold option",
  "audience: execs") as slide content.
- If a slide needs chrome, use **real** deck chrome only — the deck title,
  section title, date, author, a page number, or a genuine phrase from the
  user's material.
- Before showing the previews, read the visible text and revise if any internal
  metadata leaked in.

The theme name belongs in your chat message to the user, not on the pixels.

## Building the previews

You have two mechanisms. Both end with three slides that differ only by theme.

### Option A — `?preview=N` on a scratch deck (preferred)

`runtime.js` supports a single-slide, chrome-free mode: load any deck with
`?preview=N` and it renders only slide N with no header, footer, progress bar,
or slide number. This is the same mechanism the presenter window and the PDF
exporter use, so the preview uses the **same CSS, theme, fonts, and viewport as
the audience view** — what the user sees is exactly what they'll get.

Build it once, swap the theme three times:

1. Scaffold a throwaway deck and author **one** representative slide — a cover or
   a content slide using the user's real title and a line or two of their copy.
   Keep the slide content fixed.
2. Open it three times, each with a different theme, by sending the theme name
   over `postMessage` (the same `preview-theme` channel the presenter uses), or
   simply by editing the one `theme-link` href and reloading. For three side-by-
   side previews, the cleanest path is three iframes pointed at the same deck:

   ```html
   <!-- previews.html — a scratch comparison page, delete after the pick -->
   <iframe src="scratch-deck/index.html?preview=0" data-theme="corporate-clean"></iframe>
   <iframe src="scratch-deck/index.html?preview=0" data-theme="bold-poster"></iframe>
   <iframe src="scratch-deck/index.html?preview=0" data-theme="tokyo-night"></iframe>
   <script>
     // Once each iframe signals ready, tell it which theme to wear.
     window.addEventListener('message', (e) => {
       if (e.data && e.data.type === 'preview-ready') {
         const f = [...document.querySelectorAll('iframe')]
           .find(f => f.contentWindow === e.source);
         if (f) e.source.postMessage(
           { type: 'preview-theme', name: f.dataset.theme }, '*');
       }
     });
   </script>
   ```

   `runtime.js` resolves the theme CSS from the deck's `data-theme-base`
   attribute, so the iframe just needs the theme **name** (no path). Each iframe
   shows the identical slide in its own theme.
3. Render the three to PNG with `scripts/render.sh scratch-deck/index.html` (it
   iterates slides via the deck's deep-links), or open `previews.html` in a
   browser and screenshot. Show the user the three images, label them by theme
   name in your message.

### Option B — three standalone preview files

When you don't want a full scratch deck, write three tiny self-contained HTML
files, each linking `base.css` + `fonts.css` + a different theme, with one
hard-coded `<section class="slide is-active">`:

```html
<!-- preview-1.html (repeat for -2, -3 with a different theme href) -->
<link rel="stylesheet" href="../assets/fonts.css">
<link rel="stylesheet" href="../assets/base.css">
<link rel="stylesheet" id="theme-link" href="../assets/themes/corporate-clean.css">
<body>
  <section class="slide is-active" data-title="Cover">
    <!-- user's real title + one line of their copy, no theme/option labels -->
    <h1 class="title">…</h1>
    <p class="subtitle">…</p>
  </section>
</body>
```

The only line that changes between the three files is the `theme-link` href.
Open all three, or screenshot each, and present.

## Adopting the chosen theme

Once the user picks, the whole deck takes that theme — set it in one place:

```html
<link rel="stylesheet" id="theme-link" href="../assets/themes/<chosen>.css">
```

Author every slide against that theme using tokens (`var(--accent)`,
`var(--text-1)`, …), never literal colors — so the deck stays consistent and
the user can still press **T** to try neighbors later. Delete the scratch deck
and any `preview-*.html` / `previews.html` files when done.

## Audience → candidate trios

Reuse the audience buckets from SKILL.md, now drawing from the full 75-theme
library. Each trio is a starting spread of three different moods — substitute
freely based on the brief. Names map to files in `assets/themes/`.

| Audience | Clean / corporate | Bold / editorial | Dark / technical |
|---|---|---|---|
| **Business / pitch** | `corporate-clean` · `blue-professional` | `pitch-deck-vc` · `emerald-editorial` · `bold-poster` | `signal` · `tokyo-night` |
| **Tech / engineering** | `engineering-whiteprint` · `minimal-white` | `neo-grid-bold` · `blueprint` | `tokyo-night` · `dracula` · `binary-architect` · `terminal-green` |
| **Xiaohongshu (xiaohongshu)** | `xiaohongshu-white` · `soft-pastel` | `capsule` · `magazine-bold` · `playful` | `pink-script` |
| **Academic / report** | `academic-paper` · `minimal-white` | `monochrome` · `editorial-serif` · `cartesian` | `vellum` |
| **Edgy / cyber / launch** | `studio` | `bold-poster` · `peoples-platform` · `sakura-chroma` | `cyberpunk-neon` · `vaporwave` · `8-bit-orbit` |

Pick **one from each of the three columns** for a balanced spread, or skew the
trio toward the column that fits the brief (e.g. three editorial options for a
design studio). For audiences not listed, build the trio from the
clean / bold / dark template above using [themes.md](themes.md) and
[vibe-presets.md](vibe-presets.md).

## When to skip the previews

- The user named a theme → use it.
- The user pasted a brand or a reference look → match it directly; offer the one
  closest theme as a starting point rather than three guesses.
- A full-deck template is the obvious fit (e.g. "product launch" → `product-launch`)
  → propose it and its built-in look, and only fall back to a preview trio if
  the user wants to compare.
