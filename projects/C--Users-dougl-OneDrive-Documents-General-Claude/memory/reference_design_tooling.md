---
name: reference_design_tooling
description: "Curated design/UI-quality tooling to install or reference — Claude Code skills, design MCPs, component/style packs, color+type tools, practitioner refs — beyond what Doug already uses (impeccable/taste/shadcn)"
metadata:
  node_type: memory
  type: reference
  originSessionId: b05b66b3-fcc9-4eb1-bc72-1b1bf1a0aec7
---

Researched 2026-06-14 for Doug (builds single-file HTML apps + Next.js, allergic to AI-slop; already has impeccable + design-taste/taste skills, shadcn/Radix/Tailwind, animations.dev, interfaces.rauno.me, Comeau, HIG). Below = NEW/complementary, not those. Verify each before installing; installing a skill/MCP is persistent config (ask Doug first). Complements [[reference_motion_interaction_defaults]] and [[feedback_ai_isms]].

## Top picks to install (ranked, for this exact workflow)

1. **Vercel Web Interface Guidelines skill** — objective anti-slop _linter_ (100+ rules: focus states, labeled inputs, touch targets, reduced-motion, semantic HTML, heading order), returns `file:line` findings. The closest thing to "is this AI-slop?" as a hard checklist. Install: `curl -fsSL https://vercel.com/design/guidelines/install | bash` (inspect first) or `npx skills add https://github.com/vercel-labs/agent-skills --skill web-design-guidelines`. Rules repo: github.com/vercel-labs/web-interface-guidelines.
2. **shadcn registry MCP** (official) — Claude installs real accessible components (incl. Origin UI / Kibo UI / tweakcn themes) by name instead of hand-rolling divs. `npx shadcn@latest mcp init --client claude`. Biggest anti-slop lever for the Next/shadcn sites.
3. **tweakcn** (tweakcn.com) + **Realtime Colors** (realtimecolors.com) — bespoke shadcn palette in minutes (tweakcn exports CSS vars + registry URL); Realtime Colors previews palette+type on a real page (catches "fine as swatches, awful as a page"). Kills the default-palette/purple tell.
4. **Anthropic `frontend-design` skill** — Anthropic's own anti-generic skill (bans overused fonts, forces deliberate type/color/motion). `npx skills add https://github.com/anthropics/skills --skill frontend-design`. Good-taste defaults; complements impeccable.
5. **Emil Kowalski `emil-design-eng` skill** — a real design engineer's taste (built Sonner/Vaul/animations.dev, now Linear) as an installable skill. github.com/emilkowalski/skill.
6. **OneRedOak `design-review` subagent + Playwright MCP** — `/design-review` drives a browser, screenshots the diff, grades vs Stripe/Linear-grade heuristics. github.com/OneRedOak/claude-code-workflows + `claude mcp add playwright -- npx @playwright/mcp@latest`. Automates the "render it, critique it" loop.
7. **Open Props** (open-props.style) + **Modern Font Stacks** (modernfontstacks.com) — tasteful CSS-var tokens + zero-weight distinctive system-font stacks for the _single-file HTML_ apps where Tailwind config isn't in play.
8. **Devouring Details** (devouringdetails.com, Rauno's 23-ch interaction book) to read + **Godly** (godly.website) gallery to steal taste from.

## Other design MCPs

- **Framelink Figma MCP** (free, any account) `npx figma-developer-mcp --figma-api-key=…` — design→code; USE ≥v0.6.3 (CVE-2025-53967 RCE). Official **Figma Dev Mode MCP** (paid seat, desktop app, `127.0.0.1:3845/sse`) for tokens + Code Connect.
- **21st.dev Magic MCP** `npx -y @21st-dev/magic@latest` — NL→React component (review, leans marketing-flashy).
- **Chrome DevTools MCP** `claude mcp add chrome-devtools npx chrome-devtools-mcp@latest` — perf/a11y-tree/Core-Web-Vitals debugging. Rule (S. Kinney): Playwright = _driving_, Chrome DevTools = _debugging_; install both.
- **Claude Preview MCP** (`preview_*`, already in Doug's tools) — lightweight in-loop visual check for single-file apps.

## Component / style packs (beyond shadcn/Radix/Tailwind)

Tasteful: **Park UI** (Ark UI primitives + Panda/Tailwind), **Origin UI** + **Kibo UI** (shadcn-registry-installable — pull via the shadcn MCP), **Catalyst** (Tailwind Labs paid, by Refactoring-UI authors), **Base UI** (MUI/Radix successor primitives), **daisyUI** (pure-CSS, lightest for single-file), **Untitled UI React** (React Aria + Figma parity), **Tremor** (dashboards; verify packaging post-acquisition).
Slop-prone — **spice, not the meal**: **Aceternity UI**, **Magic UI**, **Inspira UI** (glow/beam/3D/particle effects = themselves an AI-landing-page tell). One effect deliberately, never the whole kit. **HyperUI/Flowbite** = generic, must restyle. Browse registries: registry.directory, github.com/birobirobiro/awesome-shadcn-ui.

## Color / type / token resources

- **Radix Colors** (12-step auto-accessible, OKLCH/P3) = best "don't pick bad colors" default. **Open Props** tokens. **Reasonable Colors** (WCAG-AA).
- OKLCH palette gens (avoid sRGB purple-midpoint): **uicolors.app**, **tints.dev**, **oklch.com** + Evil Martians **Harmony**, **UiHue**. **Leonardo** (Adobe), **Huemint** (AI palettes).
- Type (avoid Inter-default): **Geist**, **Fontshare** (Satoshi/Clash), **Fontsource** (self-host), **Modern Font Stacks** (system-only). Pairing: **Typewolf** (practitioner favorite), Fontjoy, FontPair.
- W3C **Design Tokens** format hit v1 (Oct 2025) w/ OKLCH/P3 — if standardizing tokens across tools.

## Practitioner references to learn from

- **designengineering.arun.is** = canonical curated index. **Devouring Details** (Rauno). **Build UI** (buildui.com, Selikoff/Toronto). **emilkowal.ski** + **index.how**. **paco.me** (Paco Coursey, cmdk). **ui.land** interviews. **easing.dev**, **svg-animations.how**. Books: **Refactoring UI** (Wathan/Schoger — still #1) + **Practical UI** (Dannaway). Galleries engineers actually cite: **Godly**, **Mobbin** (+ free: Screenlane, Lapa Ninja, UI Sources).
- Browse more CC skills/plugins: claude.com/plugins, buildwithclaude.com, claudedirectory.org/for/frontend, claudemarketplaces.com.

**Skip (hype/low-value):** generic "Senior Frontend / React Component / Landing Page (PAS/AIDA copy) generator" skills on the directories — scaffolding wrappers that don't improve taste; copy-framework landing-page gens are slop-prone. The durable anti-slop core = impeccable/frontend-design + Vercel guidelines + real-component-via-MCP.

---

## Round 2 — deeper net-new (Jun 14, 2026; 3 parallel research agents)

### More CC skills/plugins (net-new beyond round 1)

- **addyosmani/web-quality-skills** — 6-skill audit pack (web-quality-audit, performance, core-web-vitals, accessibility WCAG2.2, seo, best-practices) by Addy Osmani (Chrome team), distilled from 150+ Lighthouse audits. `npx skills add addyosmani/web-quality-skills` (Claude/Codex/Gemini). Highest-credibility add; catches the perf/a11y tells. ~2.3k★.
- **`ui-skills` cleanup pipeline** — post-generation de-slop passes: `baseline-ui` → `fixing-accessibility` → `fixing-motion-performance`. `npx ui-skills add baseline-ui` (then the other two). The "clean up AFTER generating" step most people skip; vet SKILL.md (lightly sourced).
- **dammyjay93/interface-design** — persists chosen tokens/patterns to `.interface-design/system.md`, auto-reloaded next session → kills cross-session design _drift_ (3 button styles problem). ~5.1k★, MIT, very active. `npx skills add https://github.com/dammyjay93/interface-design --skill interface-design --agent claude-code -g`.
- **Vercel agent-skills siblings** (same repo as the guidelines skill): `vercel-react-best-practices` (57 perf rules) + `composition-patterns` (kills boolean-prop sprawl) — the structural half of "not janky."
- **rohitg00/awesome-claude-design** — 30+ paste-ready `DESIGN.md` aesthetic specs (Editorial Minimalism, Terminal-Core, Cinematic Dark…) + an anti-slop "model fingerprint" catalog. Reference, not a packaged skill. ~729★.
- **LovroPodobnik/refactoring-ui-skill** — Refactoring UI (spacing/type/HSL/shadow scales) as an auditable skill; thin packaging (~26★) → adapt into own skill. Underlying principles gold.
- **Already-have overlap — don't double-install:** Leonxlnx/taste-skill (43.8k★, installs as `design-taste-frontend`) ≈ Doug's installed **design-taste**; OKLCH "one-var palette" token skills ≈ Doug's installed **hue**. Skip both.
- **Skeptical:** nextlevelbuilder/ui-ux-pro-max (substantive content but 29.6k–91.7k★ claims reek of inflation); giant 60+/97-skill "designer process" megapacks (Owl-Listener/designer-skills) = token-hungry, UX-strategy not visual polish → cherry-pick at most.

### More QA / token MCPs (net-new)

- **Lighthouse MCP — `@danielsogl/lighthouse-mcp`** (free, 🟢, in MCP Registry) — ONE server returns machine `get_accessibility_score` + Core Web Vitals + SEO + best-practices + perf budgets on any URL/HTML. Highest-ROI single add; gives the agent numeric self-check targets. `npx @danielsogl/lighthouse-mcp@latest`.
- **a11y-mcp-server (ronantakizawa)** (free, 🟢, axe-core) — `test_accessibility`, `check_color_contrast`, `check_aria_attributes`, and **`test_html_string`** (scan raw HTML w/o a server → perfect for single-file apps). Alt: `mcp-accessibility-scanner` (JustasMonkev, Playwright+axe, live localhost routes).
- **Visual regression = mostly CLI, not MCP.** Use Playwright's own **`toHaveScreenshot()`** (pixelmatch) as the self-check (already have Playwright MCP — it's a workflow, not an install). For ad-hoc "diff these two PNGs" add **mcp-image-compare-server (leky90)**. OSS VRT (Lost Pixel, BackstopJS, reg-suit) = Bash-driven, no MCP; only paid SaaS (LambdaTest SmartUI, BrowserStack/Percy, Chromatic, Argos) wrap MCP.
- **Tokens (W3C DTCG 2025.10 stable):** **Style Dictionary** v4/v5 or **Terrazzo** (ex-Cobalt) — DTCG-native, agent drives `npx` over Bash, no MCP needed. `design-token-bridge-mcp` (kenneives) translates CSS↔Tailwind↔Material3↔SwiftUI as a tool call but 🟡 unproven (2★). **Specify is DEAD** (sunset Nov 2024).
- **OSS design-tool MCPs to track:** **Penpot MCP** (official, OSS, no Figma seat — merged into penpot/penpot core Feb 2026) = the one to watch; **Storybook MCP** `@storybook/addon-mcp` (React-only preview, self-runs a11y+test fix loop, makes agent reuse real components); **freema/mcp-design-system-extractor** (pull tokens+components from a running Storybook, any framework).
- **Screenshot-so-the-agent-can-see (single-file apps):** **screenshot-mcp (bradydouthit)** captures a localhost dev server cheaply (Doug already has Claude Preview MCP, so optional).
- **Paid, team-scale only:** Deque Axe MCP, Supernova MCP, LambdaTest SmartUI, BrowserStack/Percy, Chromatic.

### More component packs (net-new tasteful)

- **Cult UI** (`@nolly-studio`) — restrained, design-engineer taste, purposeful Framer Motion; shadcn registry. Near-GOLD.
- **Motion Primitives** (ibelick) — minimal _motion primitives_ you compose yourself (using sparingly is the taste signal).
- **Supabase UI Library** — real product blocks (auth flows, dropzone, realtime cursors), 100% shadcn-registry, zero decorative cruft. GOLD for product UI.
- **MynaUI** — clean Tailwind+shadcn kit w/ Figma parity, no gimmicks → good default base. **Animate UI** — tasteful animation layer on top of base shadcn.
- **Full-library (not shadcn-registry) alternatives:** **HeroUI v3** (ex-NextUI, React Aria, premium a11y defaults) · **Mantine** (120+ components, best for dashboards/internal tools).
- **Registry discovery (vet new packs here):** shadcn **Registry Directory** (ui.shadcn.com/docs/directory), shadcnregistry.com, shadcn.io/awesome/registries.
- **Caution/cherry-pick:** 21st.dev (quality varies wildly + AI-gen = slop vector), Shadcnblocks/Tailark (template farms), Skiper/Kokonut (novel pieces good, showpieces = effect-slop), Neobrutalism Components (STALE → use RetroUI).

### More references/tools (the high-signal anti-slop set)

- **Anthony Hobday "Visual design rules"** (anthonyhobday.com/sideprojects/saferules) = THE "why does this look off?" checklist (near-black/white not #000/#fff, optical alignment, consistent measure). Plus his container-colour-combinations + visual/interaction-concepts pages. GOLD.
- **Refero** (refero.design, 60k real shipped product screens) + **Component Gallery** (component.gallery — correct component _anatomy_ from real design systems) + **UI Patterns** (ui-patterns.com — pattern + rationale). Copy from reality, not other generated showcases.
- **Utopia.fyi** — fluid type+space `clamp()` scales → kills the rigid/uniform-spacing tell. GOLD.
- **fffuel** (fffuel.co) — grain/noise/mesh-gradient SVG generators → defeats the flat sterile "AI gradient" surface. GOLD.
- **Josh Comeau free posts** — "Designing Beautiful Shadows in CSS" + "The Engineering Behind Useful Color Palettes" directly fix the two biggest generated tells (flat shadows, evenly-rotated HSL).
- **Modern CSS done right:** Adam Argyle **GUI Challenges** (web.dev) + nerdy.dev; **Every Layout** (Heydon Pickering + Andy Bell — layout primitives, no media-query spaghetti); **Inclusive Components** (Heydon); **Practical Typography** (Butterick).
- **Color/type (net-new):** **Huetone** (LCH + APCA/WCAG live) & **Accessible Palette** (perceptual ramps, no muddy mid-tones); **APCA / apcacontrast.com** (WCAG-3 perceptual contrast — what practitioners now check on dark UI); **Wakamai Fondue** (2026 rewrite — unlock variable-font axes + OpenType features); **Polypane** (multi-viewport + a11y dev browser); type scales: type-scale.com, modularscale.com, fluid-type-scale.com.
- **Galleries (net-new):** Land-book, Lapa Ninja, siteinspire (best taxonomy/filtering), Httpster (type-led restraint), One Page Love (single-page → matches single-file builds), Web Design Museum. **Awwwards = mine for _technique_, not patterns to ship** (winners run heavy/slow).
- **Meta GitHub repos:** goabstract/Awesome-Design-Tools, klaufel/awesome-design-systems, Addy Osmani's toolkit.addy.codes.

### Round-2 verdict — install these 5 now (net-new, beyond Doug's design-taste/impeccable/hue/theme-factory)

1. **Lighthouse MCP** (`@danielsogl/lighthouse-mcp`) — numeric a11y/perf/SEO self-check.
2. **A free axe a11y MCP** (`a11y-mcp-server`, has `test_html_string` for single-file apps).
3. **addyosmani/web-quality-skills** — authority-grade audit pack.
4. **dammyjay93/interface-design** — stops cross-session design drift.
5. **shadcn registry MCP** (round 1) — pull real components (Cult UI / Supabase UI / MynaUI) by name.
   Bookmarks: Anthony Hobday's rules · Refero + Component Gallery · Utopia.fyi · fffuel · Josh Comeau's shadow/color posts.
