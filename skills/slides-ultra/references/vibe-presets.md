# Vibe presets — the expressive theme catalog

The creative, auto-styled half of the theme library. Where [themes.md](themes.md)
catalogs the **core** themes (the calm/bold/dark/effect-heavy base set), this doc
catalogs the **expressive** themes ported in from frontend-slides' "bold" design
systems and bluedusk's Vibe presets. Reach for these when the deck should have a
committed visual point of view — a distinctive face, a single hard accent, a
texture, an atmosphere — rather than disappearing behind the content.

A **vibe** is a mood, not a single theme. Each vibe below names the feeling, when
to use it, and which themes in `assets/themes/` best realize it. Several themes
appear under more than one vibe — that's expected; a theme can serve more than
one mood. Every theme named here is a real file in `assets/themes/`.

Use this together with [style-discovery.md](style-discovery.md): when the user
wants a look but can't name it, pick one vibe per preview slot and render the
named themes so they can react visually.

## How to read an entry

- **Vibe** — the feeling, in two or three words.
- **When to use** — the occasion and audience it fits, and where it backfires.
- **Realized by** — the `assets/themes/` files that hit this vibe, strongest
  first. Apply one via `<link id="theme-link" href="../assets/themes/<name>.css">`.

---

## Confident / high-impact

**When to use:** founder vision decks, brand manifestos, conference keynotes,
launches — anywhere a few words should land like a poster and the speaker wants
to read as bold rather than buttoned-up. Backfires in quiet institutional or
regulated contexts.

**Realized by:** `bold-poster` · `studio` · `coral` · `neo-grid-bold` ·
`sharp-mono` · `news-broadcast`

`bold-poster` is the magazine-cover statement (massive display serif, single fire
accent); `studio` is the loudest in the library (black canvas, electric-yellow
type); `neo-grid-bold` brings editorial neo-brutalism with one neon-yellow accent.

---

## Creative / expressive

**When to use:** creative-agency pitches, design-studio credentials, art-direction
reviews, brand creative work — or any tech/research/business deck where the
speaker wants to lead with taste. The saturated, multi-accent palettes read as
expressive, so avoid them where institutional restraint is the point.

**Realized by:** `creative-mode` · `studio` · `memphis-pop` · `bauhaus` ·
`block-frame` · `raw-grid`

`creative-mode` is confident multi-color on cream paper; `block-frame` and
`raw-grid` are the neobrutalist color-block / offset-shadow systems; `memphis-pop`
and `bauhaus` carry the design-history energy.

---

## Editorial / literary

**When to use:** quarterly reviews, longform brand stories, studio updates,
editorial features, founder essays — decks that should read like a considered
magazine spread rather than a corporate template. The serif-led, warm palettes
are intentionally quiet; avoid them where you need heat or urgency.

**Realized by:** `emerald-editorial` · `editorial-tri-tone` · `editorial-forest` ·
`soft-editorial` · `editorial-serif` · `magazine-bold` · `broadside` · `cobalt-grid`

`emerald-editorial` is a magazine-cover business deck (emerald + navy + masthead
ornaments); `editorial-tri-tone` runs a disciplined three-color system;
`editorial-forest` and `soft-editorial` are the warm, unhurried quarterly-review
looks; `broadside` is the dark newspaper-headline variant; `cobalt-grid` is the
graph-paper design-research bulletin.

---

## Quiet / considered

**When to use:** investment theses, white papers, advisory deliverables, board
readouts, policy briefs — decks where restraint is itself the message and the
words should carry the page. Avoid where the deck needs visual personality or
color-led storytelling.

**Realized by:** `cartesian` · `monochrome` · `signal` · `vellum` · `grove` ·
`minimal-white`

`cartesian` is warm-neutral with classical Playfair serifs; `monochrome` is an
ivory ledger with no color at all; `signal` is navy + muted-gold institutional
weight; `vellum` is the navy + warm-yellow scholarly look; `grove` is the
forest-green classical canvas.

---

## Warm / approachable

**When to use:** creator portfolios, indie launches, lifestyle and wellness
brands, community workshops, hospitality and small-business pitches, educational
content — anywhere warmth and a human, friendly register matter more than polish.
Avoid where the audience explicitly expects authority and precision.

**Realized by:** `playful` · `capsule` · `daisy-days` · `long-table` ·
`pin-and-paper` · `soft-pastel` · `sunset-warm`

`playful` is the sun-warm peach indie-launch deck; `capsule` is modular pastel-pop
pill cards; `daisy-days` is cheerful hand-drawn pastel; `long-table` is the warm
supper-club hospitality look; `pin-and-paper` is the hand-crafted literary
paper-grain aesthetic.

---

## Crafted / handmade

**When to use:** qualitative research findings, workshop debriefs, brainstorms,
indie zines, craft and small-batch brands, founder reflections — decks that should
feel like in-progress thinking or a printed object rather than polished
conclusions. Avoid where digital-native polish or rigorous data-driven precision
is expected.

**Realized by:** `scatterbrain` · `retro-zine` · `pin-and-paper` · `excalidraw` ·
`excalidraw-dark` · `stencil-tablet`

`scatterbrain` is the post-it / Caveat-handwriting whiteboard; `retro-zine` is a
riso-printed zine in HTML; `excalidraw` / `excalidraw-dark` are the hand-drawn
hachure-fill sketch themes (light and dark); `stencil-tablet` is the archival
stencil-cut earth-tone field-manual look.

---

## Retro / nostalgic

**When to use:** retro gaming, Y2K-aesthetic brands, tech-history talks,
analog-studio retrospectives, music-label decks, deliberately tongue-in-cheek
presentations — anywhere a knowing period reference is the point. Avoid where the
deck needs to read as modern, elegant, or institutionally credible.

**Realized by:** `8-bit-orbit` · `retro-windows` · `sakura-chroma` · `retro-tv` ·
`y2k-chrome` · `vaporwave`

`8-bit-orbit` is pixel-art neon arcade on deep navy; `retro-windows` is full
Windows-95 chrome; `sakura-chroma` is the vintage Japanese cassette-package look
(rainbow ribbons, condensed type); `retro-tv` carries CRT scan-lines.

---

## Dark / technical

**When to use:** developer talks, security and infosec presentations, CLI demos,
infrastructure and architecture overviews — anywhere a dark canvas with mono
accents fits the content. The dark neon palettes work against quiet
patient-facing or traditional-luxury messages.

**Realized by:** `binary-architect` · `dark-interactive` · `tokyo-night` ·
`dracula` · `cyberpunk-neon` · `terminal-green` · `8-bit-orbit`

`binary-architect` is the void-black "command center" with a 24px grid overlay,
zero border-radius, and neon-signal accents; `dark-interactive` is the
interactive dark technical theme; the rest are the core cool-and-dark IDE themes
from [themes.md](themes.md).

---

## Luminous / tech-forward minimal

**When to use:** product launches, investor decks, design-forward technical
presentations — any context where editorial polish on a light canvas matters.
The "no-line rule" (boundaries via tonal shift and ghost borders rather than 1px
solid lines) and ambient soft shadows give it a luminous, gallery-like calm.

**Realized by:** `editorial-light` · `blue-professional` · `minimal-white` ·
`corporate-clean`

`editorial-light` is the bluedusk "Lucid Gallery" airy light-mode look;
`blue-professional` is cream paper with electric-cobalt restraint;
`corporate-clean` and `minimal-white` are the restrained core light themes.

---

## Activist / loud-graphic

**When to use:** cultural commentary, manifestos, civic and community decks,
campaign pitches, mission statements — anywhere protest-poster energy beats
corporate polish. The saturated political-poster palettes commit hard to
expressive energy; avoid where restraint is the actual goal.

**Realized by:** `peoples-platform` · `bold-poster` · `broadside` · `studio` ·
`neo-brutalism`

`peoples-platform` is the activist blue/orange/red poster on cream (Alfa Slab +
Caveat Brush); `broadside` is the dramatic dark single-accent newspaper variant.

---

## Mid-century / tactile

**When to use:** design-studio credentials, architecture and interior brands,
ceramics / craft / furniture, advisory decks with an analog feel — anywhere a
considered, tactile, slightly-warm modernism fits. Avoid where you need fast tech
energy or institutional restraint.

**Realized by:** `mat` · `midcentury` · `grove` · `stencil-tablet`

`mat` is the dark-sage + bone + burnt-orange mid-century look with wood
undertones; `midcentury` carries the mustard/teal/burnt-orange sharp-geometry
palette from the core set.

---

## Nocturnal / luxe

**When to use:** fashion and creator personal brands, after-hours / nightlife /
spirits launches, luxury product reveals, editorial features — anywhere the deck
should land with magnetic, late-night confidence. Reads as too styled for daytime
corporate B2B.

**Realized by:** `pink-script` · `broadside` · `vellum`

`pink-script` is the black-canvas hot-pink "After Hours" editorial-luxury look
(Instrument Serif headlines, pearl-cream paper).

---

## Cultural / poster-atmospheric

**When to use:** exhibition decks, arts-institution announcements, museum and
gallery programmes, curatorial pitches, design-conference brochures — anywhere a
single-color signature and atmospheric, poster-like calm fits. Intentionally
quiet; avoid where you need saturated multi-color punch.

**Realized by:** `biennale-yellow` · `cobalt-grid` · `stencil-tablet` · `grove`

`biennale-yellow` is solar-yellow on warm parchment with deep-indigo serif and
sun-glow gradients — an art-biennale poster in deck form.

---

## Picking from this catalog

- For a single deck, commit to **one** theme and author every slide against it
  with tokens. Don't mix two vibes in one deck.
- For [style-discovery](style-discovery.md), assign **one vibe per preview slot**
  and render the strongest theme from each — that gives the user three genuinely
  different reactions to choose between.
- When in doubt between two themes in the same vibe, the one listed first is the
  stronger / more representative pick.
