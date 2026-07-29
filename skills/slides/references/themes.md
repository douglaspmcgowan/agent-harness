# Themes catalog

Every theme is a short CSS file in `assets/themes/` that overrides tokens
defined in `assets/base.css`. Switch themes by changing the `href` of
`<link id="theme-link">` or by pressing **T** if the deck has a
`data-themes="a,b,c"` attribute on `<body>` or `<html>`.

All themes define the same variables: `--bg`, `--bg-soft`, `--surface`,
`--surface-2`, `--border`, `--text-1/2/3`, `--accent`, `--accent-2/3`,
`--good`, `--warn`, `--bad`, `--grad`, `--grad-soft`, `--radius*`, `--shadow*`,
`--font-sans`, `--font-display`.

## Light & calm

| name | description | when to use |
|---|---|---|
| `minimal-white` | Minimal white, restrained and refined.Inter. Strong type hierarchy, minimal shadow. | Internal reviews, 1:1 tech reviews, serious content-first topics |
| `editorial-serif` | magazine style Playfair serif + cream base. | Brand stories, text-heavy long talks |
| `soft-pastel` | Soft macaron tri-color gradient. | Product launches, consumer-facing, casual topics |
| `xiaohongshu-white` | Xiaohongshu white + warm red accent + serif headings. | Xiaohongshu posts, lifestyle/aesthetics content |
| `solarized-light` | Classic low-glare palette. | Long workshops, teaching |
| `catppuccin-latte` | catppuccin light. | Developer, geek-friendly tech talks |

## Bold & statement

| name | description | when to use |
|---|---|---|
| `sharp-mono` | pure black-and-white + Archivo Black + hard shadows. | Manifestos, high-impact visuals |
| `neo-brutalism` | Thick strokes, hard shadows, bright yellow accent. | Startup pitches, bold and daring tone |
| `bauhaus` | geometry + red-yellow-blue primaries. | design talk, art history/product aesthetics topics |
| `swiss-grid` | Swiss grid + Helvetica feel + 12 column texture. | Serious typography, design industry |
| `memphis-pop` | Memphis pop background dots + big-type headlines. | Young, trendy, brand collabs |

## Cool & dark

| name | description | when to use |
|---|---|---|
| `catppuccin-mocha` | catppuccin dark. | Developer internal talks, long viewing |
| `dracula` | classic Dracula purple-red primary. | Code-heavy tech talks |
| `tokyo-night` | Tokyo Night blue night. | Cool-toned tech talks, infrastructure |
| `nord` | Nordic cool blue-white. | Infrastructure, cloud products |
| `gruvbox-dark` | Warm retro dark. | Terminal / vim / *nix communities |
| `rose-pine` | Rosé Pine, soft dark. | design+design-dev crossover, aesthetic-leaning tech |
| `arctic-cool` | blue/teal/slate gray light version. | Business analysis, finance, calm and rational |

## Warm & vibrant

| name | description | when to use |
|---|---|---|
| `sunset-warm` | orange / coral / amber tri-color gradient. | Lifestyle, award ceremonies, upbeat mood |

## Effect-heavy

| name | description | when to use |
|---|---|---|
| `glassmorphism` | frosted glass + Multi-color glow background. | Apple -style keynotes, product feature showcases |
| `aurora` | aurora gradient + blur + saturate. | cover / CTA / closing pages |
| `rainbow-gradient` | white base + rainbow flowing gradient accent. | Joyful, festive, celebration pages |
| `blueprint` | engineering blueprint + grid texture + montage typeface. | System architecture, engineering blueprints |
| `terminal-green` | green-screen terminal + monospace + glowing text. | CLI/black-hat/retro punk |

## v2 additions

### Light & professional

| name | description | when to use |
|---|---|---|
| `corporate-clean` | pure white + navy blue accent + Inter + conservative borders. | Boardroom reports, B2B sales, finance and insurance |
| `pitch-deck-vc` | YC -style white + blue-purple gradient accent + generous whitespace. | Fundraising pitches, seed rounds, VC meeting |
| `academic-paper` | paper white + serif body text + black ink + blue links. | Academic reports, research talks, conference papers |
| `japanese-minimal` | ivory white + vermilion accent + vast whitespace + Noto Serif. | Brand refresh, artisan stories, zen narratives |
| `engineering-whiteprint` | white base + graph-paper grid + navy ink lines + monospace font. | System design, API docs, architecture whitepapers |

### Bold & editorial

| name | description | when to use |
|---|---|---|
| `magazine-bold` | cream base + oversized Playfair serif + orange spot. | Columns, cover stories, brand monthlies |
| `news-broadcast` | white base + red vertical bar + Oswald uppercase + hard shadows. | Breaking news, press releases, data broadcasts |
| `midcentury` | cream base + mustard/teal/burnt orange + sharp geometry. | Design history, home aesthetics, retro brands |
| `retro-tv` | warm cream + CRT scanlines + amber orange accent. | Nostalgic narratives, 80s/90s themes |

### Effect-heavy / dramatic

| name | description | when to use |
|---|---|---|
| `cyberpunk-neon` | pure black + neon pink-cyan-yellow + glow + JetBrains Mono. | Hackers, underground culture, cyber talk |
| `vaporwave` | deep purple + pink-cyan-blue gradient + soft glow blobs. | Music, trend art, A E S T H E T I C |
| `y2k-chrome` | silver chrome gradient + rainbow accent + large rounded corners + Space Grotesk. | Millennial nostalgia, fashion brands, Gen-Z |

## How to apply

```html
<link rel="stylesheet" id="theme-link" href="../assets/themes/aurora.css">
```

Or enable `T`-cycling by listing themes on the body:

```html
<body data-themes="minimal-white,aurora,catppuccin-mocha" data-theme-base="../assets/themes/">
```

## How to extend

Copy an existing theme, rename it, and override only the variables you want to
change. Keep each theme under ~200 lines. Prefer adjusting tokens to adding
new selectors.
