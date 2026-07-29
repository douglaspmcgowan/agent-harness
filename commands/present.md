---
name: present
description: "Comprehension test for a visual interface (HTML page, dashboard, chart, app screen): does the interface ACTUALLY COMMUNICATE what it's supposed to, graded along TWO axes that must BOTH pass — (A) DISCRETE-DATA (can a fresh viewer correctly read the concrete facts: axis labels, units, what a number means, which series is which, extract a specific datum) and (B) ABSTRACT-CONCEPTUAL (does the viewer grasp the intended takeaway / mental model: what is this arguing, what am I meant to conclude, why does this section exist). Rubric-first (enumerate what a user SHOULD understand before testing), then a fresh-eyes vision probe (Playwright headless per-section screenshots -> GEN gpt-5.5 vision as a first-time viewer, per rubric item), plus interactive control-driving to confirm a claimed datum is actually reachable. Reports per-axis verdicts, the rubric with pass/confused/fail per item, the SPECIFIC confusions surfaced, and concrete fixes — never 'communicates perfectly'. Use when Douglas says 'does this communicate', 'test if my dashboard is clear', 'present-test this page', 'will a stranger understand this', 'present', '/present'."
---

# /present [target]

A page can be beautiful, pass every heuristic, and still not land its point. `/present` is the comprehension
test: it authors an explicit list of everything a viewer is supposed to *understand* from the interface, then
puts a genuine first-time viewer in front of it and checks, item by item, what actually got through. It grades
two independent axes — can they read the concrete DATA, and do they grasp the intended TAKEAWAY — because a
chart routinely passes one and fails the other. Nothing here is a felt claim ("looks clear to me"); every
verdict traces to a fresh viewer who either could or could not extract the specific thing the rubric named.

The motivating incident (2026-07-14, Douglas's `model-eval` dashboard): GEN gpt-5.5 vision got each chart's
rough gist but consistently flagged unlabeled/reversed axes, undefined terms, and a title/metric mismatch
("Cost vs. success" over a score/pass toggle), and kept saying "I can't tell if these differences are noise."
Those are real communication gaps a rubric + fresh-eyes test catches and a builder staring at their own page
never will — because the builder already knows what the axis means. `/present` is built to catch exactly that
class.

## What this is NOT

- **Not `impeccable`'s critique/audit.** impeccable does heuristic, aesthetic, and usability review — visual
  hierarchy, spacing, type, contrast, anti-patterns — reasoning about whether a design is *good*. `/present`
  asks only one question: does the intended message *land* in a naive viewer's head? A page can score well on
  impeccable and still fail `/present` (pretty, well-spaced, and its axis is still unlabeled), and vice-versa.
  If Douglas wants the design improved, that's impeccable; if he wants to know whether it *communicates*,
  that's this.
- **Not `/spar`.** `/spar` attacks a runnable *code* target to break its behavior and fix it. `/present`
  attacks a viewer's *understanding* of a rendered interface and reports the gaps — it changes nothing about
  the target, and it's about a human reading a screen, not code failing under adversarial input.
- **Not `/probe`.** `/probe` measures whether a *test suite* catches real bugs (property/mutation/coverage).
  `/present` measures whether an *interface* conveys meaning. Different target entirely — one interrogates
  tests, the other interrogates comprehension.
- **Not `/replicate`.** `/replicate` checks feature-parity of a build against a reference implementation (does
  mine do what theirs does). `/present` has no reference; it checks the interface against its *own* intended
  message, which the rubric enumerates.

## The two axes (the core — both are graded, separately, every run)

Every rubric item and every verdict is tagged with which axis it tests. A page's final report carries **two
independent verdicts**; a page can pass one and fail the other, and that split is the most useful thing
`/present` produces.

- **(A) DISCRETE-DATA axis** — can a viewer correctly read the concrete facts? Axis labels and their units,
  what a given number *means*, which series/color is which, whether a value is a count vs a rate vs a score,
  and can they extract a *specific* datum on request ("what was model X's score on task Y?"). Failure here is
  a *legibility/decoding* failure — the information is present but unreadable or ambiguous.
- **(B) ABSTRACT-CONCEPTUAL axis** — does the viewer grasp the intended TAKEAWAY and mental model? What is this
  chart *arguing*, what am I supposed to *conclude*, why does this section exist, what's the one sentence I
  should walk away with. Failure here is a *meaning* failure — the viewer can read every label and still not
  know what the page wants them to think. This is the decode-vs-comprehend gap: someone can read every word
  and miss the point (content-design's core caution; see NN/g "legibility, readability, comprehension").

Grade each rubric item **pass / confused / fail** on its axis. "Confused" is a real, distinct outcome — the
viewer half-got it, or got it but flagged an ambiguity — and it's reported, not rounded to pass or fail.

## Procedure

### Step 0 — Resolve TARGET from ARGUMENTS

Needs enough that the run can act alone: what the interface is, how to render it (a file path to an `.html`, a
`localhost` URL, or the exact command that serves it), and — if Douglas said what the page is *for* — its
intended purpose/audience. If the interface needs a local server (many dashboards read JSON over `fetch` and
break on `file://`), note the serve command. If ARGUMENTS lacks a renderable surface and it isn't obvious from
the conversation, ask which page and how to render it — don't guess. If the project has SEVERAL servers,
confirm the one you pick actually exposes THIS page's routes (grep its route table, or hit a known endpoint) —
a sibling server can look right and 404 every `fetch` (a cad-forge dry-run mistook the vault static-server for
the app server).

### Step 1 — GATE: is there a reachable RENDERED interface at all? (mandatory, before anything else)

`/present` tests what a viewer *sees*. If there's nothing to see, stop here — don't manufacture a comprehension
report for something with no visual surface.

- **Code file, script, API, or data blob with no visual surface → STOP.** "Present-test my `t2s_map.py`" has
  no rendered interface; say so plainly and stop. If Douglas meant the *output* that code produces, ask for the
  rendered artifact instead.
- **Interface won't render / won't reach a visible state** (blank page, server won't start, hard error before
  first paint, requires auth/data you don't have) → STOP and report *that* as the finding. A page that can't be
  seen can't be comprehension-tested; report the render blocker, not a fabricated verdict.
- Only if a real, viewable interface renders do you proceed. Confirm it's the **right** page, not merely
  non-blank — check the `<title>` or a known selector/route. A wrong app on a collided port (something else
  already holding the default port) paints fine and can answer `/` with 200 while 404-ing the real routes;
  "not a white screen" won't catch that.

### Step 2 — Author the RUBRIC first (mandatory GATE: no probing before the rubric exists)

**This is the falsifiable target, and it must exist in writing BEFORE any screenshot is judged.** Enumerate,
per section of the interface, the concrete things a viewer *should* be able to understand — split across both
axes. This is the same "enumerate the target first" discipline that `feedback_verification_discipline.md`
and `feedback_match_means_enumerate_parity.md` are built on: without the list written first, a fresh-eyes probe
degrades into "the AI said nice things about my page," which verifies nothing and is exactly the self-green
trap Douglas has been bitten by.

For each section/chart/panel, write rubric items like:
- **(A) data:** "The viewer can state what the x-axis measures and its unit." · "The viewer can tell which line
  is the baseline vs the treatment." · "The viewer can read model X's value for metric Y."
- **(B) concept:** "The viewer can state the one takeaway this chart is arguing." · "The viewer understands why
  this panel exists / what decision it supports." · "The viewer knows whether higher is better."

Rules for the rubric:
- Derive items from the interface's *stated or evident purpose*, not from what's easy to check. If Douglas gave
  a purpose ("this dashboard is for comparing model cost vs accuracy"), the rubric's (B) items come straight
  from it.
- Each item must be **falsifiable** — a fresh viewer can concretely succeed or fail it. "The page looks
  professional" is not a rubric item; "the viewer can name the unit on the y-axis" is.
- Every item is tagged **(A)** or **(B)**. If a section has zero (B) items, that itself is a flag — a panel
  with no intended takeaway may not need to exist (report it, don't invent a fake takeaway).
- **Large / data-inlined pages: do NOT raw-`Read` the HTML.** A dashboard with megabytes of inlined data blows
  the Read cap (256KB) and a full dump floods context — model-eval is 4.7MB, so the skill's own motivating
  target hits this. Derive the rubric from `Grep` over the source (section `id="..."`, `<h2>`/heading text,
  `.sec-sub`/label text) plus the Step-3 screenshots, never a whole-file read of the markup.

If the interface has no discernible intended message and Douglas gave no purpose, say so and ask what it's
*supposed* to communicate rather than inventing a rubric — a comprehension test against a made-up goal is a
tautology.

### Step 3 — Render and capture per-section screenshots (Playwright headless)

Render the live interface and capture **per-section** screenshots (one per chart/panel/region the rubric
names), plus one full-page shot for the overall-takeaway items.

- **Use Playwright headless — this is the proven capture path on this laptop.** The in-app/preview-browser
  screenshot **times out here**; Playwright headless is the established fallback (see
  `~/.claude/memory/feedback_screenshot_fallbacks.md`). `@playwright/test` is installed globally at
  `C:/Users/dmcgowa2/tools/nodejs/node_modules`; resolve it from a script outside that tree with `createRequire`
  (e.g. `const require = createRequire('C:/Users/dmcgowa2/tools/nodejs/node_modules/')`), launch chromium
  headless, `page.goto` the file/URL, wait for the content to actually paint, and screenshot each section by
  its selector (`element.screenshot(...)`) and the full page.
- If the page needs a local server, start it **backgrounded** (see Safety), serve, then point Playwright at the
  `localhost` URL — don't try to comprehension-test a `fetch`-driven dashboard over `file://` where the data
  never loads.
- **Discover the section selectors by `Grep`, not by reading the whole page** (same large-page constraint as
  Step 2): grep the source for `id="..."` and the rubric's section names to get the `#id` selectors to shoot.
- **"Wait for paint" concretely:** a static `file://` page is fine with `waitUntil:'networkidle'` + a short
  fixed settle; a JS/`fetch` dashboard must wait on a real rendered content selector (e.g. a chart node) — a
  fixed timeout will screenshot an empty shell.
- Save the shots to a scratch dir under the target's project and keep the paths for the report.

### Step 4 — Fresh-eyes vision probe, per rubric item (the first-time-viewer test)

Feed each section screenshot to a **vision LLM playing a genuine first-time viewer** and ask, per rubric item,
what they can and cannot get. This is the mechanism that surfaced the real gaps on `model-eval`.

- **Proven probe: `C:/Users/dmcgowa2/Documents/Claude NASA Folder/model-eval/scratch/gen_vision.py`** — sends
  an image + question to **GEN gpt-5.5 (vision)** via the NMC proxy and never prints the key. Use it as the
  reference implementation (image path + question as argv; it reads `GEN_API_KEY`/`GEN_BASE_URL` from env, POSTs
  base64 image + text). gpt-5.5 reasons by default and vision works through the proxy (verified 2026-07-14). Per
  DELEGATE.md this is a NASA-work, no-web-tools task, so GEN is the right workhorse; the probe is a plain
  `curl`-equivalent POST to a known endpoint, allowed even on-machine.
- **The prompt frames a naive viewer, NOT a critic.** Give the model *only* the image (and, per the research,
  the target-user/purpose context, which sharply improves the signal — see "add user/flow context, don't rely
  on the bare screenshot" in the VLM-critique practitioner findings). Do **not** hand it the rubric answers.
  Ask, per section: *"You're seeing this for the first time. (1) In one sentence, what is this telling you /
  what's it arguing? (2) What specific values or labels can you read — x-axis, y-axis, units, which series is
  which? (3) What's confusing or ambiguous? (4) What can you NOT determine from this?"* Then, for each rubric
  item, decide from the viewer's own words whether it's **pass / confused / fail** — you are scoring the
  viewer's response against the pre-written rubric, not asking the model to grade itself.
- **Capture the confusions verbatim-ish.** The specific things the viewer flagged ("I can't tell if higher is
  better", "the axis has no unit", "the title says Cost but the toggle says pass/fail") are the deliverable —
  quote them.
- **Score the prose into a per-item table yourself.** `gen_vision.py` returns free prose, not a verdict — turn
  it into the rubric result: one row per rubric item = `item · axis (A/B) · pass/confused/fail · the viewer's
  own words that decided it`. The prose is evidence; the table is the deliverable.
- **Look at the screenshots yourself, too.** The harness renders the PNGs — `Read` them and form your own read
  alongside the VLM's. Your own reliability caveat (below) argues for corroboration: a second set of eyes
  (yours) catches both the VLM's false positives and what it missed.

Named comprehension techniques to fold into the probe where they fit (each earns its place, none is filler):

- **5-second / first-impression test** (NN/g) — for the full-page and each hero panel, ask the takeaway
  question as a *snap* first-impression before the detailed read: "at a glance, what's the one thing this is
  telling you?" Best not to over-prime the viewer. Directly tests axis (B) at a glance; valid only for a
  limited amount of information, so use it for the headline takeaway, not detailed data.
- **Self-explanation / comprehension check** — for (A), don't accept "yes I understand"; make the viewer
  *state the fact back* ("what does the y-axis measure, in what unit?"). Recognition is not comprehension; a
  recall answer is. (Content-design comprehension testing; dscout/Intuit content-testing, NN/g.)
- **Squint / blur test for hierarchy** — before or alongside the data read, ask the vision model (or blur the
  screenshot) "with detail removed, what stands out most?" and check whether the elements that dominate are the
  ones that *should* (the key datum, the takeaway, the primary control). If a border or background out-shouts
  the primary content, that's a (B)-axis hierarchy failure the fresh viewer will feel as "I don't know where to
  look." (Polypane/NN/g squint test; a dashboard-vetting staple.)
- **Fresh-eyes data-viz read** (Storytelling with Data) — "I have a graph" is necessary, not sufficient; the
  real test is showing it to someone unfamiliar and asking what they notice and what questions they have. That's
  exactly what the probe does per chart; treat unprompted *questions* the viewer raises as (A)/(B) gaps.

Reliability caveat, stated plainly per the research: VLM/LLM-as-viewer judgments are a strong, cheap *early*
signal but not ground truth — benchmarks put single-model agreement with human experts anywhere from ~21% to
~77%, and models can invent issues (false positives) and get *less* useful as the design gets better. So: an
LLM viewer flagging a confusion is a lead to verify, not a certified defect; and a clean pass from one model
is "this model got it," not "anyone would." Where a call is load-bearing, corroborate (a second read, or the
interactive check in Step 5) rather than trusting one pass.

### Step 5 — Drive the interactive controls to confirm the DATA axis is real (not just readable)

Reading a value off a static screenshot proves it's *legible*; it doesn't prove the page can actually *deliver*
it. For the (A) items that claim a specific datum is reachable, **drive the real control** with Playwright —
click the toggle, pick the dropdown option, hover the tooltip, filter the table — and confirm the value the
page *claims* is actually there and correct. A dashboard whose "select model X" path shows stale or wrong
numbers fails (A) even if every label reads perfectly. This is the behavioral leg of the say/do gap:
performance (what the page actually does) over preference/appearance (what it looks like it does).

### Step 6 — Grade both axes and assemble the report

For each axis independently, roll the per-item pass/confused/fail into an **axis verdict**: does the interface,
as a whole, let a fresh viewer read the data (A) and grasp the takeaway (B)? Report them **separately** — "(A)
DATA: mostly passes, two ambiguous units; (B) CONCEPT: fails — no viewer could state the takeaway of the main
panel" is the shape of a real result. Then turn every confused/fail into a **concrete fix** ("label the y-axis
'success rate (%)'", "add a one-line subtitle stating the takeaway", "the title says Cost but the control is a
pass/fail toggle — reconcile them").

## Safety constraints (apply every run, no exceptions)

- **`/present` INSPECTS; it does not mutate the target.** Read-only against the interface — render it, screenshot
  it, drive its controls to *read* values, and report. It does not edit the page, the data, or the code. (Fixes
  are *recommended* in the report; applying them is a separate, explicit ask — hand them to impeccable or a
  normal edit.)
- **Never run with elevated/bypass permissions.** A "test if my page is clear" ask does not justify disabling
  the permission system; run at default tool permissions. If a safety layer or the classifier blocks an action,
  that's a correct block — narrow scope, don't route around it.
- **Any server used to render runs BACKGROUNDED and is STOPPED at the end.** If the interface needs a local
  server, start it as a background task, use it, and stop it via its real stop handle when done (never leave a
  stray server or guess at PIDs to kill — `feedback_background_tasks.md`). Confirm it's
  stopped before finishing. Use `-WindowStyle Hidden` on any direct PowerShell invocation per
  `feedback_no_visible_powershell_windows.md`.
- **Never print, echo, or log the GEN key.** `gen_vision.py` already reads `GEN_API_KEY`/`GEN_BASE_URL` straight
  from env and never prints them — call it as-is; don't add a debug line that surfaces the key, and don't paste
  the key into any prompt or screenshot. To test whether GEN is *reachable*, call `gen_vision.py` on a throwaway
  image (or read the app's own `/health` if it reports GEN status) — never probe with `echo $GEN_API_KEY` or any
  env-presence check; the secret hooks correctly block that and it's the wrong test anyway.
- **Scratch artifacts (screenshots, probe JSON) go under the target's project scratch dir**, not a random temp
  path, and their full paths are reported. Stay scoped to the target — no touching unrelated files, processes,
  or services.

## Final report (what to tell Douglas)

- **Two axis verdicts, separately and up front** — (A) DISCRETE-DATA and (B) ABSTRACT-CONCEPTUAL, each with its
  own honest verdict. Lead with them.
- **The rubric, with pass / confused / fail per item**, tagged by axis — the enumerated target and how each
  item actually landed. This is the falsifiable record; a report without the pre-written rubric is just an
  opinion.
- **The specific confusions the fresh viewer surfaced, quoted** — the actual "I can't tell if higher is
  better" / "the axis has no unit" / "title says Cost, toggle says pass/fail" observations, per section. These
  are the point of the whole exercise.
- **Concrete fixes** — one per confused/fail item, specific enough to act on.
- **Reachability results** from Step 5 — which claimed data was confirmed live and which wasn't.
- **Honest register — banned framings.** Never "communicates perfectly", "fully clear", "anyone would
  understand", or "the message lands for everyone." Report, in the shape of `/spar`'s "no new issues across the
  last 2 rounds" and `/probe`'s "verified this pass, not fully tested": **what a fresh viewer could and could
  not get this pass**, with which model viewed it and the caveat that an LLM viewer is a strong early signal,
  not proof of universal comprehension. A clean axis means "the viewer(s) tested got it," never "it's
  unambiguous."
- Full absolute path(s) of the screenshots, probe outputs, and any scratch artifacts, per the standing
  Files-list convention. Confirm any render server was stopped and nothing was left mutated in the target.

---

*Tracked copy: also save this file to `claude-global-config/commands/present.md` (per the skills-are-tracked
convention) after a NASA scrub.*
