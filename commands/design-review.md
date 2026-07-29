---
name: design-review
description: "Design/UX/IA review of an EXISTING, BUILT app or surface (distinct from a code review and from an in-place polish pass). Loads the app's REAL running state (runs/opens it, captures screenshots via the Playwright-headless fallback, reads its component/route structure), evaluates it against a rubric drawn from Douglas's two Learn notes (Dashboard & UI Design + Frontend Design Process & Collaborative Review) plus a Nielsen-heuristic pass, and returns a PRIORITIZED findings list (blocker/major/minor) where each finding = the concrete fix + the design principle it serves. Explicitly willing to recommend STRUCTURAL restructuring or demolition (re-architect this IA, collapse these 4 cards into a hero + grid, delete this whole panel) beyond padding tweaks, with every demolition call traced to a cited design principle rather than taste. Ends by offering the handoff: re-architecture to /design, visual execution to impeccable. Reviews only; never edits the target. Use when Douglas says 'design-review', 'review the design of X', 'critique this app's UX/IA', 'is this app's structure right', 'what's wrong with this dashboard's design', '/design-review'."
---

# /design-review [target] [--scope whole|<surface>]

A polished interface built on the wrong information architecture is a well-lit wrong turn. This command
starts from the built thing — the real app, running, on screen — and asks the question a polish pass never
does: is the STRUCTURE even right? It reviews visual hierarchy, layout, color discipline, typography, chart
and component choices, IA and navigation, and the empty/loading/error states against a rubric drawn straight
from Douglas's own research notes, runs a Nielsen heuristic pass over it, and returns findings ranked by
severity — each one tied to a cited design principle and a concrete fix. Where the structure is wrong it says
so and proposes the re-architecture; a review that only ever suggests padding changes has failed. What it
finds is reported honestly, in the `/spar` register: reviewed this pass, verified live vs inferred, and what
still needs Douglas's call.

## What this is NOT

- **Not `impeccable`.** `impeccable` polishes an interface's VISUAL layer — hierarchy, motion, theming,
  spacing, color — in place, taking the structure as given. `/design-review` questions whether the STRUCTURE
  and IA are even right, and will recommend demolition (re-architect the nav, collapse these panels, delete
  this surface) that impeccable, by design, does not. The two compose: `/design-review` decides WHAT should
  change and whether the bones are sound; impeccable EXECUTES the visual change once the structure is settled.
  When a finding is purely visual-layer (a spacing scale, a motion curve, a token rename), this command names
  it and hands it to impeccable rather than doing it — its own job is the diagnosis and the structural calls.
- **Not `/design`.** `/design` designs NEW apps and major features from a problem statement — it presumes the
  thing does not exist yet. `/design-review` starts from a BUILT app and critiques the real running artifact.
  The two are a loop: when `/design-review` concludes the IA is wrong enough to warrant re-architecture, it
  hands the redesign to `/design` (which owns the problem-definition → concepts → spec arc) rather than
  improvising a new structure inline.
- **Not `/spar`, `/probe`, or `/hone`.** Those harden CODE, tests, and performance: `/spar` breaks running
  behavior and fixes it, `/probe` measures test quality, `/hone` measures speed. `/design-review` is about
  design — UX, visual hierarchy, IA, the interface a person looks at and moves through. A layout that reads as
  amateur, a nav that buries the primary job, an unlabeled chart — none of those are what `/spar`/`/probe`/
  `/hone` are looking for. If the complaint is "it's slow" route to `/hone`; "it's broken" to
  systematic-debugging; "the tests are weak" to `/probe`.
- **Not `superpowers:requesting-code-review` (or `/solo-review`, `panel-ultra-review`).** Those review code
  for correctness, security, and maintainability. `/design-review` never opens the code to judge its
  correctness — it reads structure only to understand the IA, and it judges the DESIGN the user experiences.
  A function can be flawless and its screen still be a design failure; that screen is this command's business.

## Scope of the review (the rubric's spine)

Every finding must land in one of these dimensions and cite the technique behind it. The rubric is drawn from
Douglas's two Learn notes — the Dashboard & UI Design note (the dashboard/visual-craft layer) and the
Frontend Design Process & Collaborative Review note (the process, structure, and critique layer) — plus his
standing anti-pattern memory rules. Each dimension below names its source so a finding is never taste alone:

1. **Visual hierarchy — is there a clear hero?** One element must win via size + weight + color + position;
   a flat surface where everything competes equally leaves the eye nowhere to land. *(Dashboard note §2:
   "give the single most important element real prominence"; §2 "top-left = most important, rank every
   module".)*
2. **Layout & grid.** Everything on an explicit grid, spacing on an 8-pt (÷4) system, equal margins forced by
   the grid not the eye; off-grid values read as sloppy. *(Dashboard note §2, §6.)*
3. **ONE reserved accent color.** ~60/30/10 neutral/secondary/accent, the palette built from tints of one
   hue, color spent to mean status (pass/fail/active) not decoration; dashboards get LESS color latitude than
   a landing page. *(Dashboard note §4; anti-tell reinforced by `feedback_frontend_ai_isms`.)*
4. **Separation by elevation/tone/whitespace, NOT borders.** Regions separated by layered surfaces + soft
   tinted shadow + generous whitespace; a 1px line is the LAST resort, and never a background change + shadow
   + border on the same edge (one separation method per boundary). *(Dashboard note §6 "one separation
   method", "depth via background layering not borders"; standing memory `feedback_design_incidents` — this is
   an explicit Douglas correction, weight it heavily.)*
5. **Typography scale & weight.** ~4 sizes, ~2 weights; hierarchy from size+weight before color; body/label
   not below ~14px (expert-dense tools may tighten, but say so); no monospace used decoratively — mono only
   for literal code or, narrowly, aligned numbers via `tabular-nums`. *(Dashboard note §5; standing memory
   `feedback_design_incidents`.)*
6. **Chart & component choices.** Chart form matched to the data's meaning; axes + numbers labeled, gridlines
   on, bar count = data-point count, no rounded bar tops / curved-faded lines; a written insight beside the
   chart; tables made into tools (right-aligned numerics, chips for bounded categories, truncation, shaded
   dead rows, search/sort). *(Dashboard note §3, §7; for the statistical correctness of an encoding defer to
   the installed `dataviz` skill — that note flags it as the better authority on encoding science.)*
7. **IA & navigation.** The primary job surfaced directly (not one click deep); controls placed by scope
   (global nav top, local filters in-context); progressive disclosure for secondary actions; sidebar hygiene
   (group by relevance, nest into dropdowns as links multiply, demote settings to the bottom, active-state
   indicator); objects and actions/views not intermixed as flat siblings. *(Dashboard note §2, §8; Frontend
   note §1 Stage-4 "stage reviews by concern: IA → interaction → visual → polish" and "reject any iteration
   that doesn't add a capability".)*
8. **Empty / loading / error / success states.** Designed as first-class screens, not blank panels — the
   single most common "unfinished" tell; instant interaction feedback + a completion cue; optimistic UI where
   it fits. *(Dashboard note §9; Frontend note §1 Stage-4 "spec components down to concrete states … a modal
   hides the loading, error, and empty states".)*
9. **The dashboard-specific checklist**, run against any data/analytics surface: label checklist per chart,
   ration the accent, tables-as-tools, explicit empty/loading states, tooltips on icon-only controls, a shell
   depth pass (tinted canvas + raised panel + soft tinted shadow OR a subtle border, not both), a consistency
   sweep (one icon library/weight, one corner-radius language, one shadow light-source, tokens so it doesn't
   drift). *(Dashboard note's own "Concrete changes to apply to my own dashboards" list, §7, §10.)*
10. **Structural / process integrity.** Does the surface read as designed from a problem, or accreted from
    features? Redundant elements showing the same information twice; dead controls wired to nothing; a screen
    whose layout was never signed off before it got styled; scope that grew past the app's actual job.
    *(Frontend note §1 "content-complete before polish", "don't arthack over gaps", the reviewer-app
    redundancy discipline in `feedback_frontend_ai_isms` — "what unique information does this add that isn't
    already on screen?".)*

**Standing anti-pattern rules the review always enforces** (surface every hit, even the ones the target's own
design doc claims as intentional — a stated design language that collides with one of these is itself a
finding worth raising): borders-over-elevation (`feedback_design_incidents`), the AI-ism catalog —
side-stripe borders, gradient text, eyebrow kickers, fake numbering, cream palettes, sole-Inter,
bounce easing, glassmorphism-by-default, redundant on-screen elements (`feedback_frontend_ai_isms`), no UI
commentary/meta-prose text under sections (`feedback_design_incidents`), no decorative monospace
(`feedback_design_incidents`). **Accessibility is deprioritized** per `feedback_design_incidents`:
SURFACE a11y findings (don't suppress them) but don't let unfixed a11y hold up the review or dominate the
priority list — with the ONE exception that **color contrast stays a real bar** (WCAG-style ratios), treated
as a genuine finding same as any other.
**When two rubric dimensions themselves clash** — ration-the-accent (§3) against a genuine need for distinct
pass/fail/warn status hues, or the ≥14px body floor (§5) against a deliberately expert-dense table — resolve
toward the surface's actual job and say which dimension you let win and why, rather than flagging both or
silently picking one; mis-prioritizing clashing guidelines is a documented failure mode of automated design
critique (UICrit), so the report states the tie-break openly and carries its reasoning.

## Procedure

### Step 0 — Resolve the target and scope from ARGUMENTS

Needs enough that the review is unambiguous: which app (the path/URL), and whether the scope is the WHOLE app
or ONE surface (a single tab/panel/route). If ARGUMENTS lacks this and it isn't obvious from the conversation
(e.g. "review the schema editor" right after discussing it), ask which app and how to open it before
proceeding — don't guess at a target. Parse `--scope` (default `whole`); a named surface narrows both the
Capture step and the rubric to that one screen.

### Step 1 — GATE: is there actually a built UI to review? (mandatory, before any capture)

The one stop condition, checked honestly. `/design-review` reviews something that EXISTS and RENDERS. If the
ask is really "design me a new X" / "how should I build Y" / a greenfield with no UI yet — there is nothing
to review. Say so plainly and **route to `/design`** (which owns designing new things), then stop. Two more
gate checks:

- **Wrong-command gate.** "It's slow" → `/hone`; "it's broken / throws" → systematic-debugging; "are the
  tests any good" → `/probe`; "review the code" → `superpowers:requesting-code-review`. If the complaint isn't
  actually about design/UX/IA/visual, name the right command and stop.
- **Nothing-to-review gate.** If the "app" is a single static text page or a CLI with no visual surface, say
  there's no design surface to review rather than manufacturing findings to look useful.

A fired gate IS the complete output — do not follow it with a padded review.

### Step 2 — Load the app's REAL current state (review the thing, never a description of it)

Open/run the app and observe it directly. Three captures, all required for the scoped surface(s):

- **Run/open it.** Serve it if it needs a server (respect any file:// serve-command banner the app itself
  shows); open the real running app, not the source as a proxy for it.
- **Screenshot it — respect the screenshot-fallback rule.** The in-app/preview browser screenshot times out
  on this laptop. Do NOT downgrade to DOM-only checks and claim visual verification is impossible. Fall back
  immediately to **Playwright headless** via the global install at
  `C:/Users/dmcgowa2/tools/nodejs/node_modules/@playwright/test` (require its `.chromium`; a working harness
  pattern lives in `schema-studio/tools/shots.js` and `NASA_GSFC_Vault_1/Berkeley MEng Capstone/_shots/
  shoot.js`), then headless Chrome/Edge, then Claude-in-Chrome — per `feedback_screenshot_fallbacks`. Read the
  PNGs back with the Read tool (it renders images) and REVIEW them. Also capture the states, not just the
  happy path: drive the app to its empty / loading / error / populated states and shoot each, because
  dimension 8 can't be judged from the default screen alone. Two more capture passes, both from the
  OneRedOak design-review workflow (the strongest published Claude Code design-review agent — its
  "Live Environment First" principle is the same review-the-running-thing rule this command already holds):
  - **Breakpoints.** Shoot the scoped surface at desktop **1440×900** (the baseline every other shot uses),
    then **768** and **375** wide; at each, check for horizontal scroll and element overlap. If the target is
    a deliberately desktop-only tool, declare that once in the report and skip the narrow shots.
  - **Interaction states.** Drive the primary controls to their hover / focus / active / disabled states and
    shoot the ones that matter for the scoped job; a button with no visible hover/focus state is a real
    finding (Nielsen "visibility of system status"), and it is invisible in a default-state screenshot.

  DOM *geometry* checks (`scrollHeight` vs
  `innerHeight`, `getBoundingClientRect`) additionally catch overflow that a screenshot might miss — run them
  alongside the visual capture, as a complement to it. While the browser is open, grab the **console** once:
  errors thrown during the review walk fall outside the design rubric, so report them in one line and route
  them to systematic-debugging — a review that watched the console stay silent about a red wall has missed
  something Douglas will hit in the first minute.
- **Read its structure.** The main components, the IA (nav model, routes/tabs/panels, how objects vs
  actions are organized), and how regions are separated — enough to judge dimensions 1, 7, and 10. Prefer a
  code-graph/outline read (Serena `get_symbols_overview`, or a targeted Grep of the render/route code) over a
  blind full-file read, to keep the structure map cheap. Note the app's own stated design language if it has a
  DESIGN.md — so a finding can flag where the built reality drifts from the stated intent, or where the stated
  intent itself collides with a standing anti-pattern rule.

### Step 3 — Evaluate against the rubric (the 10 dimensions above)

Walk the scoped surface(s) through all ten dimensions. For each finding, record: the dimension, the LOCATOR
(which specific element / group / screen, and in which captured state — e.g. "the pass-rate tile in the
populated dashboard" rather than a vague "the cards"), WHAT is wrong (concretely, with the screenshot or structure evidence you
actually observed — not a hypothetical), the DESIGN PRINCIPLE it serves with its Learn-note citation, and the
CONCRETE FIX. The locator is not optional bookkeeping: in the UICrit study un-anchored critiques scored
lowest and a downstream fixer cannot act on "the cards" without being told which cards on which screen
(element-level / group-level / screen-level anchoring — UICrit; the grounding-locator rubric where a critique
is "explicitly grounded" only with a structural reference, weak otherwise). A finding with no cited
principle is taste and does not ship as a finding; a finding with no concrete fix is a complaint. **WHAT
leads with the observed user impact** — problems first, then the fix (the Nielsen/NN-g critique discipline:
a prescribed fix whose underlying problem was never articulated is the classic reviewer failure — it may be
solving the wrong problem entirely). So: "the eye has nowhere to land; every card competes at equal weight"
comes before "make the pass-rate number the hero at 2× size". The fix still ships with every finding — it
just has to trace to a stated problem, the same way it already has to trace to a cited principle. Enforce the
standing anti-pattern rules as you go (borders, AI-isms, mono, UI-commentary, contrast) — surface every hit.

**If the target has a `SPEC.md` produced by `/spec`, evaluate against it too** — its §Product success criteria
(`SC-###`) and §Acceptance oracle (`AC-###`) are the stated goals this surface was built to meet, so a finding
can cite a missed `SC-###`/`AC-###` as its principle (the collaborative-review discipline of reviewing against
stated goals, not taste). A surface that diverges from its own spec's acceptance criteria is a structural
finding, not a cosmetic one.

### Step 4 — Nielsen heuristic pass

Over the same surface, run the classic heuristics as a fast checklist (they're cheap and evidenced): **visibility
of system status** (is the app's state — running/saving/loading/offline — always visible?), **user control &
freedom** (undo, cancel, a clear exit from any state), **recognition over recall** (is what the user needs
visible, or must they remember it — a command palette / labeled controls / active-state indicators help
here), **error prevention** (guardrails before destructive actions, affected-count warnings, confirmations
on irreversible controls). Each heuristic gap is a finding in the same shape as Step 3 (severity + fix +
principle), tagged as a Nielsen finding.

### Step 5 — Produce the PRIORITIZED findings list (and be willing to demolish)

**Open with what works** — 2–3 things the surface genuinely gets right, each tied to the evidence that shows
it (the OneRedOak workflow opens every review this way). This is calibration, doing real work: it proves the
review saw the whole surface, it anchors the severity scale (a "major" next to a named strength reads
differently than a "major" in a wall of red), and it tells the fixer what to preserve through the
restructuring. Then merge Step 3 + Step 4 into one list, each finding = **severity + concrete fix + the
design principle it serves**, ranked. Assign each severity from Nielsen's own three factors instead of gut feel —
**frequency** (how many users hit it, how often), **impact** (how hard to overcome once hit), **persistence**
(a one-time stumble vs a recurring tax) — because severity is the single least-reliable judgment in a
heuristic pass (LLM inter-rater agreement on severity runs near zero even when issue-detection is solid), so
a rating that names which factors drove it is defensible where a bare label is arbitrary (NN/g, "Severity
Ratings for Usability Problems"). Severity tiers (Frontend note §2 "prioritize with severity tiers"):

- **Blocker** — the design actively fails its job: the primary task is buried or unreachable, the IA is wrong
  enough that users can't build the right mental model, an unlabeled chart communicates nothing, a state is
  missing so the app looks broken.
- **Major** — real design failure that degrades the experience but doesn't block the job: accent sprayed
  everywhere, everything boxed in borders, no hero, tables left as raw cells.
- **Minor** — polish-level: an off-grid value, a mono label, a mismatched icon weight, a contrast miss on a
  secondary label.

**This is the crucial part: be explicitly willing to recommend STRUCTURAL restructuring or demolition where
warranted, not just cosmetic tweaks.** "This entire IA is wrong — here is the re-architecture." "These four
equal cards should become one hero number + a 2-column grid." "This whole panel duplicates the header; delete
it." "The left rail intermixes objects you open with actions you invoke — split them: objects stay, the verbs
move to the command palette." A review that only ever suggests padding changes has failed the target. **But
every demolition call must trace to a cited principle; a call resting on taste alone gets dropped** — "collapse these panels"
because Dashboard-note §2 says one element must own prominence and here none does; "re-architect this nav"
because §8's sidebar-hygiene and the Frontend note's "reject any iteration that doesn't add a capability" show
the rail has accreted views that don't belong as tree siblings. If the bones are genuinely sound, say that
plainly too — not every review demolishes, and manufacturing a fake structural finding to look bold is the
same failure as only ever suggesting padding.

### Step 6 — Offer the handoff

Close by naming the next step, not doing it: the redesign can go to **`/design`** (when the finding set is
structural enough to warrant re-architecture — `/design` owns problem-definition → concepts → spec for the
new structure), or to **`impeccable`** (for the purely visual-layer findings — the spacing scale, the token
rename, the motion curve, the color-discipline pass — once the structure is settled). Group the findings by
which handoff they belong to so Douglas can dispatch each stream cleanly. Do NOT start either handoff
unprompted — this command reviews and recommends; execution is a separate, explicitly-requested step.

### Step 7 — The honest final report

In the `/spar` / `/hone` / `/probe` register:
- **What was reviewed** — which app, which scope, which states and breakpoints captured.
- **What works** — the 2–3 named strengths from Step 5, with their evidence.
- **Findings by severity** — blocker → major → minor, each with its concrete fix and cited principle; the
  structural/demolition calls called out distinctly (they need Douglas's judgment most).
- **What was verified LIVE vs inferred** — which findings came from a screenshot/geometry check you actually
  ran, and which from reading structure without seeing that exact state rendered. Never present an inferred
  finding as a seen one (the same honesty bar as `/probe`'s isolation-status rule).
- **The handoff split** — which findings go to `/design`, which to `impeccable`.
- **Banned framings.** No "fully reviewed", "now perfect", "production-ready UX". Report what was reviewed
  THIS pass, what still needs Douglas's call (especially the demolition calls), and what a follow-up pass
  would cover — the way `/spar` says "no new issues across the last 2 rounds", not "flawless".
- Full absolute path(s) of any screenshots captured or notes written, per the standing Files-list convention.

## Safety constraints

- **Never run with elevated/bypass permissions.** A generic "review this" ask does not justify disabling the
  permission system. If a safety layer or the classifier blocks an action mid-review, that is a correct block
  — narrow scope, don't route around it.
- **This command REVIEWS and does not edit the target app.** No edits, no refactors, no "quick fixes" to the
  UI while reviewing — the deliverable is the findings list, and the app itself stays unchanged. If Douglas SEPARATELY asks for
  a trial redesign, that happens only in an **isolated git worktree** off the target's repo (never the
  caller's main tree), proven the way `/hone` and `/probe` prove isolation before assuming it, and reported as
  a diff — the review pass itself never touches the working tree.
- **No commits or pushes**, ever, unless Douglas separately asks.
- **Screenshots and scratch notes only.** Capturing PNGs to a scratch/`_shots` path to review them is fine
  (that's input to the review); writing a durable review brief to the Obsidian vault follows the Briefs →
  Obsidian rule when the review is substantial. Nothing else is written.
- **Research is open-web only for public/personal targets.** For NASA/CUI apps, review from the running
  artifact and the notes already on the machine — no web egress of the app's content (`block-nasa-web-egress`
  enforces; don't test it).

## Workflow script (optional executor when parallel fan-out is safe; otherwise run inline/sequentially)

When subagent fan-out is safe (no active SentinelOne kill pattern), the rubric dimensions can be reviewed
concurrently by separate reviewers and each major finding adversarially re-verified before it ships. When
fan-out isn't safe, run the exact same phases inline and sequentially — Capture once, walk the ten dimensions
+ Nielsen yourself, adversarially re-check your own major/structural findings against the captured evidence,
then synthesize the prioritized list. The process is identical; only the dispatch differs. This is an explicit
skill-triggered Workflow use (per the Workflow tool's own rule) — no separate opt-in.

```js
export const meta = {
  name: 'design-review',
  description: 'Design/UX/IA review of a BUILT app: capture the real running state -> parallel rubric-dimension reviewers -> adversarially verify each major/structural finding against the evidence -> prioritized synthesis with handoff split',
  phases: [
    { title: 'Capture' },
    { title: 'Review' },
    { title: 'Verify' },
    { title: 'Synthesize' },
  ],
}

const TARGET = args.target          // resolved app: what it is + how to open/serve it + path
const SCOPE = args.scope || 'whole' // 'whole' or a named surface (one tab/panel/route)

// The rubric dimensions, each reviewed by its own agent so one lens covers its ground thoroughly.
const DIMENSIONS = [
  { key: 'hierarchy',  focus: 'visual hierarchy: is there ONE clear hero (size+weight+color+position), or does everything compete equally? top-left = most important? (Dashboard note §2)' },
  { key: 'layout-grid', focus: 'layout & grid: explicit grid, 8-pt/÷4 spacing, equal margins forced by the grid not the eye; off-grid values (Dashboard note §2, §6)' },
  { key: 'color',      focus: 'ONE reserved accent, ~60/30/10, palette from tints of one hue, color = status not decoration; dashboards get less color latitude (Dashboard note §4)' },
  { key: 'separation', focus: 'separation by elevation/tone/whitespace NOT borders; one separation method per boundary; 1px line is last resort (Dashboard note §6; feedback_design_incidents — an explicit Douglas correction, weight heavily)' },
  { key: 'typography', focus: '~4 sizes ~2 weights, hierarchy from size+weight, body not <14px (unless deliberately dense), NO decorative monospace — mono only for literal code/aligned-numbers (Dashboard note §5; feedback_design_incidents)' },
  { key: 'charts-components', focus: 'chart form matched to meaning, axes+numbers labeled, gridlines, bar count = data points, no rounded/curved distortion, insight beside chart, tables-as-tools (right-align numerics, chips, truncation, shaded dead rows, search/sort) (Dashboard note §3, §7)' },
  { key: 'ia-nav',     focus: 'IA & navigation: primary job surfaced directly not buried; controls by scope (global top, local in-context); progressive disclosure; sidebar hygiene (nest as links multiply, demote settings, active-state); objects vs actions not intermixed as flat siblings (Dashboard note §2, §8; Frontend note §1 Stage-4)' },
  { key: 'states',     focus: 'empty/loading/error/success designed as first-class screens not blank panels; instant interaction feedback + completion cue (Dashboard note §9; Frontend note Stage-4 component states)' },
  { key: 'structure',  focus: 'structural/process integrity: designed-from-problem vs accreted-from-features; redundant elements showing the same info twice; dead controls wired to nothing; scope grown past the app\'s job; styled-before-layout-signed-off (Frontend note §1; feedback_frontend_ai_isms redundancy discipline)' },
  { key: 'anti-patterns', focus: 'standing anti-tell sweep: side-stripe borders, gradient text, eyebrow kickers, fake numbering, cream palette, sole-Inter, bounce easing, glassmorphism-default, UI-commentary meta-prose, redundant on-screen elements; contrast is a real bar (a11y otherwise deprioritized) (feedback_frontend_ai_isms, feedback_design_incidents, feedback_design_incidents)' },
  { key: 'nielsen',    focus: 'Nielsen heuristics: visibility of system status, user control/undo/cancel/exit, recognition over recall, error prevention (guardrails before destructive actions)' },
]

const FINDING_SCHEMA = {
  type: 'object',
  properties: {
    dimension: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
          locator: { type: 'string' },            // which element/group/screen + which captured state (UICrit anchoring); un-anchored findings don't ship
          what: { type: 'string' },              // the concrete problem, with observed evidence
          principle: { type: 'string' },          // the cited design principle + Learn-note source
          fix: { type: 'string' },                // the concrete change
          structural: { type: 'boolean' },        // true = restructure/demolition call, not cosmetic
          verified_live: { type: 'boolean' },     // observed in a real capture vs inferred from structure
          handoff: { type: 'string', enum: ['design', 'impeccable', 'none'] },
        },
        required: ['id', 'severity', 'locator', 'what', 'principle', 'fix', 'structural', 'verified_live'],
      },
    },
    nothing_wrong: { type: 'boolean' },            // honest: this dimension is genuinely sound
  },
  required: ['dimension', 'findings'],
}

const VERIFY_SCHEMA = {
  type: 'object',
  properties: {
    results: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          holds: { type: 'boolean' },             // does the finding survive scrutiny against the evidence?
          is_taste_not_principle: { type: 'boolean' }, // drop it if it's taste with no real cited principle
          demolition_justified: { type: 'boolean' },   // for structural calls: is it earned by the principle, or bold-for-its-own-sake?
          note: { type: 'string' },
        },
        required: ['id', 'holds'],
      },
    },
  },
  required: ['results'],
}

function capturePrompt(target, scope) {
  return `Load the REAL running state of this app and capture it for a design review — review the running ` +
    `artifact, never a description of it. TARGET: ${target}\nSCOPE: ${scope}\n\n` +
    `1. Open/serve the app (respect any file:// serve-command banner it shows) and reach the ${scope} ` +
    `surface(s).\n` +
    `2. Screenshot it. The in-app/preview screenshot TIMES OUT on this laptop — do NOT claim visual ` +
    `verification is impossible. Fall back to Playwright headless (@playwright/test at ` +
    `C:/Users/dmcgowa2/tools/nodejs/node_modules/, chromium via require) — a working harness pattern is in ` +
    `schema-studio/tools/shots.js — then headless Chrome/Edge, then Claude-in-Chrome. Capture NOT JUST the ` +
    `happy path: drive the app to its empty / loading / error / populated states and shoot each. Shoot at ` +
    `1440x900 desktop baseline plus 768 and 375 wide (skip narrow only if the target is declared ` +
    `desktop-only — say so), checking horizontal scroll / element overlap at each; and drive the primary ` +
    `controls to hover / focus / active / disabled and shoot the ones that matter. Grab the browser console ` +
    `once and report any errors as a one-line routing note to systematic-debugging.\n` +
    `3. Read the STRUCTURE: main components, IA (nav model, routes/tabs/panels, objects vs actions), how ` +
    `regions are separated. Prefer a symbol-outline/targeted-grep read over blind full-file reads. Note the ` +
    `app's own stated design language (DESIGN.md) if present, so drift from intent can be flagged.\n` +
    `4. Run DOM geometry checks (scrollHeight vs innerHeight, getBoundingClientRect) to catch overflow a ` +
    `screenshot might miss.\n\n` +
    `Report the screenshot paths, the captured states, and a concise structure/IA map. Do NOT edit anything.`
}

function reviewPrompt(target, scope, dim, capture) {
  return `You are reviewing ONE dimension of a BUILT app's DESIGN (not its code correctness, not its speed). ` +
    `TARGET: ${target}\nSCOPE: ${scope}\nCAPTURED STATE (screenshots + structure map): ${JSON.stringify(capture)}\n\n` +
    `Your dimension: ${dim.focus}\n\n` +
    `Work through this dimension thoroughly against the ACTUAL captured screenshots and structure — every ` +
    `finding must cite the observed evidence, not a hypothetical. For each finding give: severity ` +
    `(blocker/major/minor), the LOCATOR (which specific element/group/screen + which captured state — e.g. ` +
    `"the pass-rate tile in the populated dashboard" rather than a vague "the cards"; an un-anchored finding is dropped, ` +
    `per UICrit's element/group/screen grounding), WHAT is wrong concretely — leading with the observed USER IMPACT, problems first ` +
    `then fix, so the fix traces to a stated problem — the design PRINCIPLE it serves WITH its Learn-note ` +
    `citation (a finding with no cited principle is taste — don't report it), the concrete FIX, whether it's ` +
    `STRUCTURAL (a restructure/demolition call, not a cosmetic tweak), whether you VERIFIED it live in a real ` +
    `capture vs inferred it from structure, and the handoff (design = re-architecture, impeccable = visual ` +
    `execution, none). BE WILLING to call for demolition/restructuring where the principle warrants it ` +
    `("this IA is wrong — re-architect it thus", "collapse these 4 cards into a hero + grid", "delete this ` +
    `redundant panel") — a review that only ever suggests padding has failed. Every demolition call must ` +
    `trace to its cited principle; a call resting on taste alone should be dropped. If this dimension is ` +
    `genuinely sound, set nothing_wrong=true ` +
    `and say so plainly rather than manufacturing a finding. Do NOT edit the app.`
}

function verifyPrompt(target, findings, capture) {
  return `Adversarially re-verify these design-review findings before they ship, especially the STRUCTURAL / ` +
    `demolition calls. TARGET: ${target}\nCAPTURED EVIDENCE: ${JSON.stringify(capture)}\n` +
    `FINDINGS: ${JSON.stringify(findings)}\n\n` +
    `You are skeptical by default. For each finding decide: does it HOLD against the actual captured ` +
    `evidence, or is it taste dressed up as a principle (is_taste_not_principle)? For every finding marked ` +
    `structural, is the demolition GENUINELY earned by its cited principle, or bold-for-its-own-sake ` +
    `(demolition_justified)? A structural call that can't be tied to a real cited principle is exactly the ` +
    `failure mode to catch — drop it or downgrade it. Do not rubber-stamp. Report per id: holds, ` +
    `is_taste_not_principle, demolition_justified (for structural ones), and a note.`
}

// --- Run ---

log(`Capture: loading the real running state of ${TARGET} (scope: ${SCOPE})`)
const capture = await agent(capturePrompt(TARGET, SCOPE), { phase: 'Capture', label: 'capture', model: 'opus' })

log(`Review: dispatching ${DIMENSIONS.length} parallel rubric-dimension reviewers`)
const dimResults = await parallel(DIMENSIONS.map(dim => () =>
  agent(reviewPrompt(TARGET, SCOPE, dim, capture), { phase: 'Review', schema: FINDING_SCHEMA, label: `review-${dim.key}` })
))

const allFindings = dimResults.flatMap(r => (r && r.findings) || [])
const majorPlus = allFindings.filter(f => f.severity === 'blocker' || f.severity === 'major' || f.structural)

let verify = null
if (majorPlus.length) {
  log(`Verify: adversarially re-checking ${majorPlus.length} major/structural finding(s) against the captured evidence`)
  verify = await agent(verifyPrompt(TARGET, majorPlus, capture), { phase: 'Verify', schema: VERIFY_SCHEMA, label: 'verify' })
}

// Drop findings the verify pass judged taste-not-principle or unjustified demolition.
const dropped = new Set((verify?.results || []).filter(r => r.holds === false || r.is_taste_not_principle === true || r.demolition_justified === false).map(r => r.id))
const kept = allFindings.filter(f => !dropped.has(f.id))

const synth = await agent(
  `Synthesize the final prioritized design-review report from these verified findings. TARGET: ${TARGET}\n` +
  `KEPT FINDINGS: ${JSON.stringify(kept)}\nCAPTURE: ${JSON.stringify(capture)}\n\n` +
  `Open with 2-3 things the surface genuinely gets right, each tied to its evidence (calibrates severity ` +
  `and names what the fixer must preserve). ` +
  `Order by severity (blocker -> major -> minor); call out the structural/demolition findings distinctly ` +
  `(they need Douglas's judgment most). State clearly what was verified LIVE vs inferred. Split the findings ` +
  `by handoff (design = re-architecture, impeccable = visual execution). Honest register: no "fully ` +
  `reviewed" / "now perfect" — report what was reviewed this pass and what still needs Douglas's call.`,
  { phase: 'Synthesize', label: 'synthesize', model: 'opus' })

return {
  target: TARGET,
  scope: SCOPE,
  capture,
  dimensionsReviewed: DIMENSIONS.map(d => d.key),
  totalFindings: allFindings.length,
  droppedInVerify: [...dropped],
  keptFindings: kept,
  structuralCalls: kept.filter(f => f.structural),
  handoff: {
    design: kept.filter(f => f.handoff === 'design'),
    impeccable: kept.filter(f => f.handoff === 'impeccable'),
  },
  report: synth,
}
```

## Final report (what to tell Douglas)

- **What was reviewed** — the app, the scope, and which states were actually captured (empty/loading/error/
  populated), so he knows the review saw the real thing.
- **Findings by severity** — blocker → major → minor, each = concrete fix + cited design principle. The
  **structural/demolition calls flagged distinctly**, since those are the ones this command exists to make and
  the ones needing his judgment most.
- **Verified live vs inferred** — plainly, per finding. Never present an inferred finding as an observed one.
- **The handoff split** — which findings go to `/design` (re-architecture) and which to `impeccable` (visual
  execution), so he can dispatch each stream.
- **Honest close** — no "fully reviewed" / "now perfect". What was reviewed this pass, what still needs his
  call, what a follow-up pass would cover. If the bones are genuinely sound, say so; if they're wrong, say
  that with the cited re-architecture.
- Full absolute path(s) of every screenshot captured and any brief written, per the standing Files-list
  convention.

---

*Tracked copy: also save this file to `claude-global-config/commands/design-review.md` (per the
skills-are-tracked convention) after a NASA scrub.*
