---
name: frontier
description: "Douglas's open-ended EXPLORE-an-area driver for work where the next move isn't decided yet. It builds the current thing to a good state with a convergence loop, then STOPS at a six-way heading menu and asks which direction to go: explore (recon more options), expand (add features/scope), deepen (double down on capability/performance), sharpen (make what exists more reliable/robust/adaptable), consolidate (remove redundancy), document (bring docs/logs/detective current). Whichever heading Douglas picks, it routes that leg to the EXISTING skill that already does that job (recon / design / hone / spar+probe / simplify/consolidate / detective+docs-update), runs it, then returns to the same menu — cycling indefinitely until Douglas says stop. It ORCHESTRATES a heading-per-cycle loop over his installed skills; it does not reimplement recon/hone/spar/etc. Use when Douglas says 'frontier', '/frontier', 'explore this area', 'I'm not sure what's next, let's just keep going', 'build this and then let me pick the direction', 'take this further, my call each round', or 'keep developing this and ask me the heading each time'."
---

# /frontier [target] [--build-first] [--heading explore|expand|deepen|sharpen|consolidate|document]

Some work has a spec; this is for the work that doesn't. You have a thing, you want it better, and the honest
answer to "what's the next move" is "not sure yet — show me the options." `/frontier` is the driver for exactly
that. It gets the current thing to a good state, then stops at a **six-heading menu** and asks which way to go.
You pick a heading, it runs that leg using the skill that already owns that job, and it comes back to the menu.
That cycle repeats as long as you want it to. The command's whole value is the loop and the routing: it turns
"keep making this better, my call each round" into a repeatable ritual instead of an ad-hoc scramble every time.

Its one real move is that it never invents a fresh implementation of a heading. `explore` IS `/recon`, `deepen`
IS `/hone`, `sharpen` IS the harden pass Douglas already runs. `/frontier` sequences those against one shared
target and hands the wheel back after each leg. It is a conductor of his own skills around a single evolving
thing.

## What this is NOT

- **Not `/tactician`.** `/tactician` does a single read-only scan of the current project, ranks the loose ends,
  maps each to a skill, and stops at one pick-list — a one-shot "what should I do next" detector. `/frontier`
  is the multi-cycle driver: it actually *runs* the chosen leg, then returns to the menu and keeps going. Think
  of `/tactician` as one turn of the wheel and `/frontier` as staying at the wheel. `/frontier` can *open* a cycle
  by borrowing `/tactician`'s scan to populate the menu with concrete, project-specific options — but it doesn't
  stop there.
- **Not `/pathway` or `/trailblaze`.** `/pathway` runs a *fixed, pre-named* chain (harden-tail = solo-review →
  probe → spar → hone) start to finish in one order; `/trailblaze` authors those named chains. `/frontier` has
  no fixed order — the sequence is whatever headings Douglas picks, cycle by cycle, and is not saved as a
  reusable named chain. A `sharpen` leg may itself dispatch the harden-tail `/pathway`; that's composition, not
  duplication.
- **Not `/ultraskill` or `/design`.** Those build ONE new thing (a skill, an app/feature) from a stated intent
  and finish. `/frontier` presumes the thing already exists (or gets built in the first cycle) and then keeps
  developing it open-endedly. An `expand` leg can hand a genuinely new feature to `/design`; `/frontier` owns the
  loop around it, not the feature design itself.
- **Not an autonomous run.** `/frontier` deliberately STOPS at every menu and waits for Douglas's heading. The
  build/convergence *within* a leg may run a loop (optionally `/longrun`), but the direction between legs is
  always his call — that pause is the point of the command, not a limitation.

## The six headings (each routes to the skill that already owns it)

The menu is fixed; each heading is a thin router to an installed skill run against the shared target. `/frontier`
does not reimplement any of them.

| Heading | What it means | Routes to |
|---|---|---|
| **explore** | Find more options; widen the space. | **Outward** (default) → `/recon` (+`/deep-search`), fed the target's current state + any Step-2 `/tactician` scan as its mirror input. **Inward** → `superpowers:brainstorming` and/or parallel spikes via `/parallelize` (`/compare-options`, `/gallery` for UI variants). The leg's job is to WIDEN and hand back a clustered option set to the menu; converging is Douglas's next heading pick. |
| **expand** | Add a feature/surface/scope the thing lacks. | `superpowers:brainstorming` → `/design` for a real new feature; a direct build for a small add. Hand brainstorming/design the current architecture + existing feature list so the addition lands native to the system. One feature per cycle. |
| **deepen** | Raise the capability or performance of what's there. | **Performance** → `/hone`, handed the specific hotspot + a baseline number to beat. **Capability** → `superpowers:brainstorming` → `test-driven-development` / `subagent-driven-development` (direct build only for a trivial add). Ask which fork before routing. |
| **sharpen** | Make existing functionality more reliable, robust, adaptable. | **Reliability / robustness** → `/probe` FIRST (establish a green invariant/behavior baseline), then `/spar` with that baseline as a "must still pass after every fix" regression gate, plus `/solo-review` (the `/pathway harden-tail` trio, reordered probe-first as a regression gate). **Adaptability** → `/solo-review`'s design lens + a `/simplify` or `ponytail:ponytail-debt` decoupling pass; property-test invariants from `/probe` are the design lever that lets the code bend without breaking. |
| **consolidate** | Remove redundancy and unnecessary parts; tighten what's there without adding. Behavior-preserving only. | **Code target** → `/simplify` or `ponytail:ponytail-debt` (behavior-preserving code cleanup). **Folder-of-artifacts target** → `/consolidate` (dedupe/archive stale files). Bound each pass to one small named target; the target's tests/verify must be green before AND after, with the same result required. |
| **document** | Bring docs/logs/status current. | Default (light) → compact LOG into working memory + refresh STATUS/LOG/CURRENT-TASK. Opt-in (heavy) → full `/detective` (+`/docs-update`, `/historian`) tracking stand-up. Pre-step: a cheap doc-vs-reality drift scan to find which STATUS/README/doc claims no longer match current state, so the refresh targets the stale sections. |

If none of the six fits what Douglas wants next, that's a valid answer too — take his free-text heading and route
it to whichever installed skill matches (or run it inline), rather than forcing it into a bucket.

## Procedure

### Step 0 — Resolve the target

Needs one thing: which target — the path/app/repo/area this frontier is about, enough that a routed skill
(`/recon`, `/hone`, `/spar`…) could act on it alone. If ARGUMENTS lacks it and it isn't obvious from the
conversation, ask which target before starting. Seed a `WORK_QUEUE` for the frontier (the standing multi-step
rule) with a structured per-cycle block: chosen heading, the leg's done-bar plus met/not-met, one rationale
line, and a "declined this cycle" list, so a resumed session can see where the frontier has been.

### Step 1 — Build/converge the current thing to "good" (first cycle only, or on `--build-first`)

If the thing doesn't exist yet, or Douglas asked to build first, build it and run a convergence loop until it
holds — the same iterate-until-it-passes discipline his other loops use (drive the real thing, verify
adversarially, not just "the tests I wrote pass"). Use `/longrun` only if the build is genuinely long and
unattended; otherwise iterate inline. If the thing already exists and is in a good state, skip straight to the
menu. Before the convergence loop runs, state one checkable acceptance criterion for "defensible baseline"
(the bar that ends the loop). Cap the convergence attempts; when the cap is hit, return to the menu reporting
"baseline bar met: yes/no" rather than continuing to polish. Refinement is what the headings are for.

### Step 2 — Present the six-heading menu and STOP

Read the frontier `WORK_QUEUE` state block first; drop or deprioritize any direction already declined in a prior
cycle so the menu does not re-surface a rejected suggestion. Show the menu with, for each heading, a **one-line concrete suggestion for THIS target** (not the generic
definition) so the choice is real — e.g. under `sharpen`, "the new `/api/refresh` route has no `/spar` pass
yet"; under `consolidate`, "three near-duplicate test-serve files could merge." Borrow `/tactician`'s scan to
generate those specifics when the target is a live project. Then stop and wait for Douglas's pick. After the
six suggestions, add one advisory line: "Recommended: <heading> because <one-line reason from the frontier scan
or the last leg's not-met bar>." This is advisory only. It never auto-selects, and `--heading` stays the only
override. Never auto-select a heading (except when `--heading` was passed explicitly for this one cycle).

### Step 3 — Run the chosen leg via its owning skill

Invoke the skill the chosen heading routes to, running the specific sub-choice fork named in its table row,
against the shared target, using the Skill tool exactly as normal — let that skill's own procedure and safety
rules drive the leg; do not substitute an ad-hoc version of what it does.

Wrap every leg in a lightweight contract:

1. **State the done-bar** in one line before routing: what clearing this leg looks like (the bar it is trying
   to hit).
2. **Hand the routed skill the Step-2 concrete suggestion as its scoped brief** (the specific surface / hotspot
   / feature + current-state path), so it acts on what the router already knows instead of re-deriving the
   target cold.
3. **For any leg that mutates the target** (expand / deepen-capability / sharpen / consolidate): a cheap
   pre-step confirming the target still runs a basic end-to-end check before the leg changes anything, since
   Step 1's build only ran on the first cycle.
4. **After the leg, report met / not-met against the done-bar.** If not-met, surface "recommend re-running
   <heading>" as an explicit menu option rather than returning to a cold menu.

When the leg finishes, record it in the frontier's `WORK_QUEUE`/`LOG` (heading, skill run, one-line outcome, any
changed paths).

### Step 4 — Return to the menu (repeat indefinitely)

Go back to Step 2 with the target now in its post-leg state, regenerate the per-heading suggestions against the
new state, and wait for the next heading. Keep cycling until Douglas says stop / ends the session. Each cycle is
one heading; the frontier is the whole chain of them.

## Safety constraints

- **The heading is always Douglas's call.** Never pick a heading for him or run a leg he didn't choose (the
  `--heading` flag is a per-cycle explicit override, not a license to auto-drive the whole frontier). The stop-at-
  the-menu pause is a hard rule.
- **Each leg runs at default permissions and inherits its skill's own safety.** `/frontier` loosens nothing —
  `/hone`/`/probe` keep their worktree isolation, `/spar` keeps its scope, `/recon`/`/deep-search` keep the
  NASA web-egress rules. A correct block mid-leg is respected and never routed around; record it and return to
  the menu.
- **Stay scoped to the target.** No touching unrelated processes/files/services; cleanup is each routed skill's
  own responsibility. `/frontier` adds only the frontier `WORK_QUEUE`/`LOG` lines.
- **No commits or pushes** unless Douglas separately asks (the routed skills already hold this line).

## Final report (per cycle, and at frontier end)

- **Per leg**: which heading, which skill ran, a one-line outcome, and any changed paths — then re-present the
  menu. Don't narrate the routed skill's full working-out into the main thread; surface its result and move on.
- **Frontier-health readout**: one derived line: "legs this session: N; last M moved little (outcomes: minor)."
  The stop decision stays Douglas's; the router's duty is to surface a plateau so he is not the only detector of
  over-building.
- **At the target's own state files**: keep STATUS/LOG current as legs land, so the frontier's history survives
  the session (a `document` leg does this in full; other legs append a LOG line).
- **Honest register** — report what each leg actually moved this cycle and what the next menu's options are;
  never claim the thing is "done" or "finished" while the frontier is open. It's open until Douglas stops it.
- Full absolute path(s) of anything a leg changed, per the standing Files-list convention.

---

*Tracked copy: also save this file to `claude-global-config/commands/frontier.md` (per the skills-are-tracked
convention) after a NASA scrub.*
