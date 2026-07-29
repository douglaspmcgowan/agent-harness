# Full-Deck Templates

Self-contained multi-slide HTML decks under `templates/full-decks/<name>/`. Each folder contains:

- `index.html` — complete multi-slide deck (cover / section / content / code / chart or diagram / CTA / thanks, 7+ slides)
- `style.css` — scoped with `.tpl-<name>` class prefix so multiple templates can coexist
- `README.md` — short rationale, inspiration, and use guidance

All templates pull the shared `assets/fonts.css`, `assets/base.css`, and `assets/runtime.js` from the skill root. Navigate with `← →` / `space`, use `F` for fullscreen, `O` for overview.

Use these when you want a coherent, opinionated look for an entire deck rather than a mix-and-match of layouts. Each template is visually distinctive enough to be identified at a glance.

There are 12 full-deck templates: 6 extracted from real-world decks, and 6 generic scenario scaffolds.

---

## Extracted from real-world decks

## 1. graphify-dark-graph — Dark Knowledge Graph

- **Source inspiration:** `20260413-graphify/ppt/graphify.html`
- **Key visual traits:** `#06060c→#0e1020` deep-night gradient, drifting blur orbs, SVG force-directed graph overlay on cover, rainbow-shift gradient headlines, JetBrains Mono command-line glow, glass-morphism cards (warm/blue/green/purple/danger). Accent palette: amber `#e8a87c`, mint `#7ed3a4`, mist-blue `#7eb8da`, lilac `#b8a4d6`.
- **When to use:** dev-tool / CLI / knowledge-graph / data-viz launches; live-demo decks that want an "AI-native + sci-fi + warm" vibe.
- **Path:** `templates/full-decks/graphify-dark-graph/index.html`

## 2. knowledge-arch-blueprint — Cream Blueprint Architecture

- **Source inspiration:** `20260405-Karpathy-Knowledge Base/20260405 Architecture Diagramv2.html`
- **Key visual traits:** cream paper `#F0EAE0` base, single rust accent `#B5392A`, 48px blueprint grid mask, hard 2px black border cards, pipeline step-boxes with one hero raised, right-side rust insight callout, Playfair serif big numbers, SVG dashed feedback-loop arrows. Zero gradients, zero soft shadows.
- **When to use:** system architecture diagrams, data-flow maps, engineering white-papers; you want a serious, printable, README-friendly feel.
- **Path:** `templates/full-decks/knowledge-arch-blueprint/index.html`

## 3. hermes-cyber-terminal — Dark Terminal honest-review

- **Source inspiration:** `20260414-hermes-agent/ppt/hermes-record.html` + `hermes-vs-openclaw.html`
- **Key visual traits:** `#0a0c10` black, 56px cyber grid + CRT vignette + scanlines, window traffic-light chrome, `$ prompt` command-line headlines, mint-green `#7ed3a4` glow big text, JetBrains Mono throughout, stroke-only bar charts, blinking cursor, amber/green/red tag hierarchy, dark code box.
- **When to use:** reviews of CLI / agent / dev tools with trace, diff, and benchmarks; when you want the "honest technical reviewer" voice.
- **Path:** `templates/full-decks/hermes-cyber-terminal/index.html`

## 4. obsidian-claude-gradient — GitHub Dark Purple Gradient

- **Source inspiration:** `20260406-obsidian-claude/slides.html`
- **Key visual traits:** GitHub-dark `#0d1117`, purple+blue radial ambient plus 60px masked grid, center-aligned layout, purple pill tags, three-stop gradient text `#a855f7→#60a5fa→#34d399`, GitHub-ish code palette (`#010409` bg + purple/blue/orange/green tokens), purple-left-border highlight block.
- **When to use:** developer workflow / MCP / Agent / dev-tool tutorials; feels like GitHub Blog / Linear Changelog; config + steps heavy content.
- **Path:** `templates/full-decks/obsidian-claude-gradient/index.html`

## 5. testing-safety-alert — Red Amber Alert

- **Source inspiration:** `20260412-AITesting & Safety/html/ai-testing-safety-v2.html`
- **Key visual traits:** top and bottom 45° red-black hazard stripes, red strike-through negation headlines, L1/L2/L3 green/amber/red tier cards, alert-box with circular status dot, policy-yaml code block with red left border and `bad` keyword highlighting, red/green checklist, Q1 incident stacked bar chart.
- **When to use:** safety / risk / incident post-mortem / red-team / pre-launch AI review / policy-as-code; when the audience needs to feel "this is serious, do not skim".
- **Path:** `templates/full-decks/testing-safety-alert/index.html`

## 6. dir-key-nav-minimal — Arrow Key 8-Color Minimal

- **Source inspiration:** `20260405-Karpathy-Knowledge Base/20260405 Slides [Arrow-Key Version].html`
- **Key visual traits:** 8 slides each on its own mono background (indigo / cream / crimson / emerald / slate / violet / white / charcoal), each with its own accent color, 160px display headline + 4px stubby accent line divider, arrow `→` prefixed Mono list, bottom-left `← →` kbd hint plus bottom-right page label, huge breathing negative space.
- **When to use:** keynote-style minimalist talk where you have something to say and not much to show; one idea per slide; talks / launches / public presentations.
- **Path:** `templates/full-decks/dir-key-nav-minimal/index.html`

---

## Scenario decks (generic, reusable)

These are generic scaffolds for the most common presentation jobs. Each is visually distinctive and content-rich out of the box.

| # | Name | Slides | Feel | When to use |
|---|---|---|---|---|
| 7  | `pitch-deck`       | 10 | White + blue→purple gradient, YC/VC vibe, big numbers, traction chart | Fundraising, startup pitch, investor meeting |
| 8  | `product-launch`   | 8  | Dark hero + light content, warm orange→peach, feature cards, pricing tiers, CTA | Announcing a product, launch keynote |
| 9  | `tech-sharing`     | 8  | GitHub-dark, JetBrains Mono, terminal code blocks, agenda + Q&A | Tech sharing, internal tech talk, conference talk |
| 10 | `weekly-report`    | 7  | Corporate clarity, 8-cell KPI grid, shipped list, 8-week bar chart, next-week table | Weekly report, team status update, business review |
| 11 | `course-module`    | 7  | Warm paper + Playfair serif, persistent left sidebar of learning objectives, MCQ self-check | Course module, online course, workshop module |

Each folder: `index.html`, scoped `style.css` (prefixed `.tpl-<name>`), `README.md`.

---

## Authoring notes

- Every template scopes its CSS under `.tpl-<name>` so two or more templates can load on the same page without collisions.
- Swap demo content, but keep the structural classes — they are what gives each template its identity.
- The shared runtime (`assets/runtime.js`) provides keyboard nav, fullscreen, overview grid, and theme cycling, so you do not need to add any JS.
- Charts are hand-rolled SVG (no CDN dependency). Feel free to replace with chart.js / echarts if you need interactive data.
