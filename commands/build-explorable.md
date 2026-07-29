---
name: build-explorable
description: "Build a self-contained interactive HTML explorable using the web-artifacts-builder stack (React+TS+Tailwind+shadcn). Enhanced with: format-mode selection, depth mode (quick vs deep-dive), chart type guidance, Mermaid diagram support, and Douglas's design rules. Use when the output is an explorable explanation, interactive dashboard, concept map, data explorer, or annotated diagram."
---

# /build-explorable [topic]

## What this uses

The `anthropic-skills:web-artifacts-builder` stack — React 18 + TypeScript + Vite + Tailwind 3.4.1 + shadcn/ui (40+ components pre-installed: Slider, Tabs, Accordion, Dialog, Progress, Table, resizable panels, cmdk). Bundles to a single self-contained `.html` file via Parcel.

Run the skill first: `anthropic-skills:web-artifacts-builder` gives the init and bundle scripts. This command wraps it with upfront decisions and additional package guidance.

---

## Phase 0 — Four upfront questions (ask all at once, one message)

Ask these before touching any code:

**1. Format mode** — pick one:
- `long-page` — scroll-driven, sections revealed as you read; best for a narrative with one clear path
- `dashboard` — multiple panels visible at once, no scroll; best for comparison/monitoring views
- `concept-map` — node + edge graph layout; best for relationships between entities
- `data-explorer` — filter/sort/drill-down table or chart; best for a dataset the reader navigates
- `slideshow` — step-through panels with a Next button; best for a guided walkthrough

**2. Depth mode** — quick or deep-dive?
- `quick` — one or two interactive elements, minimal prose, loads fast; good for a single insight or a single parameter to explore
- `deep-dive` — full reader-driven exploration with layered context, multiple controls, expandable detail panels; good for a paper section, a system explainer, or a portfolio piece

**3. Does this involve data?**
If yes: what shape is the data (flat table? nested JSON? graph nodes+edges? time series?). This determines which chart package to install.

**4. Does this involve a flow, architecture, or process diagram?**
If yes: embed a Mermaid diagram rather than building it in SVG/Canvas by hand. Answer determines whether to `pnpm install mermaid`.

---

## Phase 1 — Package additions beyond the base stack

Install these ON TOP of the base web-artifacts-builder setup, depending on format:

| Need | Package | Install command |
|------|---------|-----------------|
| Bar / line / pie charts | recharts | `pnpm install recharts` |
| Sankey / funnel | d3-sankey (from D3) | `pnpm install d3-sankey @types/d3-sankey` |
| Force-directed graph (small, <500 nodes) | react-force-graph-2d | `pnpm install react-force-graph-2d` |
| Large graph (>500 nodes — IDETC scale) | Use `/build-graph-explorer` instead; D3 force with WebWorker is better than a React wrapper at 7k+ nodes |
| Mermaid diagrams | mermaid | `pnpm install mermaid` |
| Timeline / Gantt | vis-timeline | `pnpm install vis-timeline` |
| 3D (Fusion / DFM shapes) | Use `/three-webgpu` or Three.js directly — don't bundle inside a React artifact, file size blows up |

---

## Phase 2 — Chart type guidance (if data is involved)

Match data structure to chart type before writing any code:

| Data | Chart | shadcn / recharts component |
|------|-------|----------------------------|
| Single value vs threshold (e.g. AC1 score) | Gauge or horizontal bar | `<Progress>` or `<RadialBarChart>` |
| Distribution (e.g. field-type counts) | Histogram or bar | `<BarChart>` with bin buckets |
| Two annotators, many items | Scatter plot, color = agreement | `<ScatterChart>` |
| Papers through filter stages (funnel) | Sankey or stacked bar | `d3-sankey` |
| Metric over time | Line | `<LineChart>` |
| Part-to-whole (e.g. schema field coverage) | Treemap or stacked bar — NOT pie | `<Treemap>` |
| Network nodes + edges | Force graph — see above | `react-force-graph-2d` |
| Feature co-occurrence | Heatmap matrix | `<ResponsiveContainer>` + custom SVG cells |

**Rule:** if the reader needs to compare magnitudes, use a bar. If they need to see relationships, use a graph or scatter. Never use pie unless there are exactly 2 slices. Never use radar charts — they hide the actual values.

---

## Phase 3 — Design rules

These override defaults from the web-artifacts-builder SKILL.md. The skill already says "avoid AI slop" — here's what that means for Douglas's work specifically:

- **Full outlines, no left-accent bars.** A card has a border on all four sides or no border at all. Never `border-left: 4px solid accent`.
- **One dominant accent color.** Pick one: a muted blue, a deep green, a warm amber. Not purple. Not a gradient.
- **Font pair.** Display heading + body text. Options: `Sora + IBM Plex Mono` (existing dpm-agent-kit style), `DM Sans + Source Serif 4` (editorial), `system-ui + JetBrains Mono` (technical). Never Inter + JetBrains Mono for everything.
- **Dark mode via `[data-theme]` attribute.** One CSS custom-property swap, not a separate stylesheet. Build this from the start.
- **Row-hover only when rows are real pairs.** A table of paper titles and author counts: row-hover makes sense. A table that's really two independent lists side-by-side: make them two lists.
- **Muted backgrounds.** `hsl(220, 14%, 96%)` light / `hsl(220, 14%, 11%)` dark. Not pure white / pure black.

---

## Phase 4 — Build sequence

```
1. Run:  anthropic-skills:web-artifacts-builder  (gives init-artifact.sh and bundle-artifact.sh)
2. Run:  bash scripts/init-artifact.sh <project-name>
3. cd    <project-name>
4. Run:  pnpm install <additional packages from Phase 1>
5. Edit  src/App.tsx  (and add component files as needed)
6. Run:  bash scripts/bundle-artifact.sh  →  produces bundle.html
7. Playwright screenshot  bundle.html  to verify before handing to Douglas
```

---

## Phase 5 — Verify before delivering

Take a Playwright headless screenshot of `bundle.html` before saying it's done. Read `~/.claude/memory/feedback_headless_html_testing.md` for the exact CLI command. Do NOT hand over a file and call it done without a visual check — the bundle step sometimes drops CSS or inlines assets incorrectly.

---

## Quick-reference: what each format mode looks like in shadcn components

**long-page:** `<ScrollArea>` wrapping `<section>` blocks; each section has a `useIntersectionObserver` hook that triggers when it enters viewport. Accordion for collapsible detail.

**dashboard:** `<ResizablePanelGroup>` with 2–3 panels. Left panel = controls/filters (Slider, Select, Checkbox). Right panel(s) = chart output. No scroll.

**concept-map:** `react-force-graph-2d` or a custom SVG with `useRef` for D3 force. Node click → `<Sheet>` slides in with detail. shadcn `<Badge>` for node type labels.

**data-explorer:** `<Table>` with column sort headers, `<Input>` filter, `<Select>` for category filter. Pagination via shadcn `<Pagination>`. `<Dialog>` for row detail.

**slideshow:** `<Tabs>` with manual `value` state and a `<Button onClick={() => setStep(s+1)}>Next</Button>`. Progress bar at top via `<Progress value={(step/total)*100}`.

---

## Output contract

When done, report:
1. Format mode chosen and why it fits the content
2. Packages installed beyond the base stack
3. Chart type(s) used and what data they encode
4. Path to `bundle.html`
5. Playwright screenshot attached (or explicit note if screenshot failed and why)
