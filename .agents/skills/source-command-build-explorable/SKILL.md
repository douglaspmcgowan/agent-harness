---
name: "source-command-build-explorable"
description: "Build a self-contained interactive HTML explorable with format/depth selection, chart guidance, diagrams, and Douglas's design rules. Use for explorable explanations, interactive dashboards, concept maps, data explorers, and annotated diagrams."
---

# source-command-build-explorable

Use this skill when the user asks to run the migrated source command `build-explorable`.

## Command Template

# /build-explorable [topic]

## What this uses

Use an installed web-artifact or site-building skill when one is available. Otherwise initialize the repository’s existing frontend stack or a minimal React + TypeScript + Vite project. Keep the output self-contained when the request requires a single HTML artifact.

---

## Phase 0 â€” Four upfront questions (ask all at once, one message)

Ask these before touching any code:

**1. Format mode** â€” pick one:
- `long-page` â€” scroll-driven, sections revealed as you read; best for a narrative with one clear path
- `dashboard` â€” multiple panels visible at once, no scroll; best for comparison/monitoring views
- `concept-map` â€” node + edge graph layout; best for relationships between entities
- `data-explorer` â€” filter/sort/drill-down table or chart; best for a dataset the reader navigates
- `slideshow` â€” step-through panels with a Next button; best for a guided walkthrough

**2. Depth mode** â€” quick or deep-dive?
- `quick` â€” one or two interactive elements, minimal prose, loads fast; good for a single insight or a single parameter to explore
- `deep-dive` â€” full reader-driven exploration with layered context, multiple controls, expandable detail panels; good for a paper section, a system explainer, or a portfolio piece

**3. Does this involve data?**
If yes: what shape is the data (flat table? nested JSON? graph nodes+edges? time series?). This determines which chart package to install.

**4. Does this involve a flow, architecture, or process diagram?**
If yes: embed a Mermaid diagram rather than building it in SVG/Canvas by hand. Answer determines whether to `pnpm install mermaid`.

---

## Phase 1 â€” Package additions beyond the base stack

Install these ON TOP of the base web-artifacts-builder setup, depending on format:

| Need | Package | Install command |
|------|---------|-----------------|
| Bar / line / pie charts | recharts | `pnpm install recharts` |
| Sankey / funnel | d3-sankey (from D3) | `pnpm install d3-sankey @types/d3-sankey` |
| Force-directed graph (small, <500 nodes) | react-force-graph-2d | `pnpm install react-force-graph-2d` |
| Large graph (>500 nodes â€” IDETC scale) | Use `/build-graph-explorer` instead; D3 force with WebWorker is better than a React wrapper at 7k+ nodes |
| Mermaid diagrams | mermaid | `pnpm install mermaid` |
| Timeline / Gantt | vis-timeline | `pnpm install vis-timeline` |
| 3D (Fusion / DFM shapes) | Use `/three-webgpu` or Three.js directly â€” don't bundle inside a React artifact, file size blows up |

---

## Phase 2 â€” Chart type guidance (if data is involved)

Match data structure to chart type before writing any code:

| Data | Chart | shadcn / recharts component |
|------|-------|----------------------------|
| Single value vs threshold (e.g. AC1 score) | Gauge or horizontal bar | `<Progress>` or `<RadialBarChart>` |
| Distribution (e.g. field-type counts) | Histogram or bar | `<BarChart>` with bin buckets |
| Two annotators, many items | Scatter plot, color = agreement | `<ScatterChart>` |
| Papers through filter stages (funnel) | Sankey or stacked bar | `d3-sankey` |
| Metric over time | Line | `<LineChart>` |
| Part-to-whole (e.g. schema field coverage) | Treemap or stacked bar â€” NOT pie | `<Treemap>` |
| Network nodes + edges | Force graph â€” see above | `react-force-graph-2d` |
| Feature co-occurrence | Heatmap matrix | `<ResponsiveContainer>` + custom SVG cells |

**Rule:** if the reader needs to compare magnitudes, use a bar. If they need to see relationships, use a graph or scatter. Never use pie unless there are exactly 2 slices. Never use radar charts â€” they hide the actual values.

---

## Phase 3 â€” Design rules

These override defaults from the web-artifacts-builder SKILL.md. The skill already says "avoid AI slop" â€” here's what that means for Douglas's work specifically:

- **Full outlines, no left-accent bars.** A card has a border on all four sides or no border at all. Never `border-left: 4px solid accent`.
- **One dominant accent color.** Pick one: a muted blue, a deep green, a warm amber. Not purple. Not a gradient.
- **Font pair.** Use a proportional display and body pair. Options: `Bricolage Grotesque + Outfit`, `DM Sans + Source Serif 4`, or `system-ui + Geist Mono` with monospace reserved for code and numeric evidence.
- **Dark mode via `[data-theme]` attribute.** One CSS custom-property swap, not a separate stylesheet. Build this from the start.
- **Row-hover only when rows are real pairs.** A table of paper titles and author counts: row-hover makes sense. A table that's really two independent lists side-by-side: make them two lists.
- **Muted backgrounds.** `hsl(220, 14%, 96%)` light / `hsl(220, 14%, 11%)` dark. Not pure white / pure black.

---

## Phase 4 â€” Build sequence

1. Read the repository contract and select the installed site/artifact skill that matches the request.
2. Reuse the repository’s frontend stack. Initialize a minimal Vite project only when no stack exists.
3. Install only the packages selected in Phase 1.
4. Build the interface and produce the requested artifact.
5. Run the repository’s build command.
6. Verify the built artifact with Playwright before delivery.

---

## Phase 5 â€” Verify before delivering

Run Playwright against the built artifact before saying it is done. Use the repository’s Playwright configuration when present. Exercise the primary interaction path and inspect the rendered result for missing CSS, broken assets, overflow, and console errors.

---

## Quick-reference: what each format mode looks like in shadcn components

**long-page:** `<ScrollArea>` wrapping `<section>` blocks; each section has a `useIntersectionObserver` hook that triggers when it enters viewport. Accordion for collapsible detail.

**dashboard:** `<ResizablePanelGroup>` with 2â€“3 panels. Left panel = controls/filters (Slider, Select, Checkbox). Right panel(s) = chart output. No scroll.

**concept-map:** `react-force-graph-2d` or a custom SVG with `useRef` for D3 force. Node click â†’ `<Sheet>` slides in with detail. shadcn `<Badge>` for node type labels.

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

