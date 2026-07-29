---
name: modernize
description: "Finds what has appeared in Douglas's harness and ecosystem SINCE an existing codebase was built, and surfaces the applicable ones for him to (optionally) adopt. Dates the codebase from its git history (or newest source mtime if un-gitted), then enumerates candidates that are genuinely NEWER than that date — new skills (~/.claude/commands/*.md, ~/.claude/skills/**/SKILL.md), new/changed rule files (CLAUDE.md, DESIGN.md, DESIGN-dashboards.md, VERIFY.md, and siblings), and dependencies with materially newer majors or better-established replacements (offline/lockfile-checkable only) — FILTERS to what plausibly applies to THIS codebase, and describes each as {what it is + plain gloss, why it's newer, how it'd apply here, rough effort}. Groups related candidates into single decision items, ranks them by impact (security/EOL first), and suppresses anything a prior pass already declined (via the MODERNIZE.md ledger). Routes the results by count: 4 or fewer applicable items -> AskUserQuestion for a pick; 5 or more -> enqueue into the Workbench reviewer app (:8471) with the `review` schema via /docket. Read-only on the target: it SURFACES improvements, it never applies them (applying is a separate, later, user-approved step), and every item traces to a real file/version it actually read — nothing invented. Use when Douglas says 'modernize this', 'what's new since I built X', 'has anything appeared that applies to this codebase', 'bring this up to date with my current setup', 'modernize', '/modernize'."
---

# /modernize [target]

A codebase captures the harness as it was the day it was written. Months later, new skills exist, rules
changed, libraries moved — and none of that reaches the old code unless someone looks. This command does the
looking. It dates the codebase, finds everything in Douglas's own harness and ecosystem that post-dates it,
keeps only what plausibly applies to THIS code, and hands the shortlist back for him to decide on. It surfaces;
it does not apply. Every candidate it names traces to a real file or version it actually read — a "new skill"
it can't point at is not reported.

## Deviation clause

The staged procedure below is the well-reasoned default, not a straitjacket. When a specific situation
genuinely calls for a different move than these steps prescribe, surface the divergence and the reason to
Douglas for his call, rather than silently complying or silently going your own way.

## What this is NOT

- **Not `/onboard`.** `/onboard` makes an existing codebase LEGIBLE — it explains how the parts wire together
  so a human can hold it in their head. `/modernize` assumes the code is already understood and asks a forward
  question: what has appeared SINCE it was built that could improve it. Comprehension vs. upgrade candidates.
- **Not `/recon`.** `/recon` maps an EXTERNAL landscape (the whole field, the wider ecosystem) to help Douglas
  decide what to adopt in general. `/modernize` scopes to ONE existing codebase and to Douglas's OWN harness +
  its declared dependencies — "what that I already have, or already changed, is newer than this specific repo."
- **Not `/tech-debt-audit`.** That judges a codebase's internal health across nine dimensions on its own terms
  (is this code healthy). `/modernize` doesn't grade the code; it compares the code's as-of date against what's
  newer outside it. Debt is "this is wrong on its own"; a modernize item is "something better than this now
  exists that didn't when you wrote it."
- **Not `/design-review`.** That reviews a built app's UX/IA/structure. `/modernize` isn't a design pass and
  isn't UI-scoped — a new rule file or a dependency bump is squarely in scope; a critique of the app's layout
  is not.
- **Not the apply step.** `/modernize` produces a decided-on shortlist and stops. Actually applying an accepted
  item (installing the new skill's pattern, adopting the rule, bumping the dependency) is a separate, later,
  explicitly-approved piece of work — routed to whatever skill fits (`/design`, impeccable, `/add-ci` when
  the surfaced gap is "this repo has no CI", a plain edit), after Douglas picks.

## Procedure

### Step 0 — Resolve the target and its as-of date

Resolve which codebase (a path from ARGUMENTS or the conversation; if absent and not obvious, ask which folder
in one line). Then establish its **as-of date** — the point in time the code represents:

- If it's inside a git working tree, use git history for that folder: the LAST commit that touched it
  (`git -C <dir> log -1 --format=%cs -- <path>`) is the "as built as of" date; note the FIRST commit date too
  (`git -C <dir> log --diff-filter=A --format=%cs -- <path> | tail -1` or `git log --reverse`) as the build-start
  bound, so a candidate that pre-dates the whole project can be excluded.
- If it's NOT a git repo (or the folder is untracked), fall back to the newest source-file mtime in the target
  as the as-of date, and say plainly in the report that the date is mtime-derived (less precise than git).

**Completion criterion:** you have a concrete as-of date (ISO `YYYY-MM-DD`) and know which method produced it.

### Step 1 — The gate (mandatory, before enumerating)

Check honestly, and narrow or stop if either holds:

1. **Is the codebase recent enough that little could have changed?** If the as-of date is within the last week
   or two, say so — the harness barely moved in that window; run a quick pass and expect few or zero items
   rather than manufacturing a list to look busy. A modernize pass that honestly finds nothing newer-and-
   applicable is a valid outcome, not a failure.
2. **Is the target actually a codebase you can scope to?** A single scratch file or a folder of pure data/notes
   has no dependencies and no design surface for most harness skills to apply to — narrow the enumeration to
   what could plausibly matter (rules maybe; skills/deps probably not) instead of forcing all three lanes.

**Completion criterion:** you've decided the pass is worth running at full scope, at narrowed scope, or that
it should report "too recent / not applicable" and stop.

### Step 2 — Enumerate candidates that are genuinely NEWER than the as-of date

Gather across three lanes. In every lane, a candidate qualifies ONLY if you can show it post-dates the as-of
date with a real signal (a commit date, a file mtime, a version number) — never on a hunch that it "feels
new." Record the dated evidence for each so Step 4 can cite it.

**First, read the ledger.** If a prior pass left `MODERNIZE.md` at the target's root (the decision ledger
Step 5 writes), load it: an item Douglas already DECLINED is suppressed — carry it as a one-line suppressed
count in the report, and re-surface it only if it has materially changed since the decline (a newer version,
a substantive edit to the skill/rule, with dated evidence as usual). A decline is a decision; re-asking it
every run trains the reader to skim past the whole report. (Same mechanism as Dependabot's ignore-conditions.)

- **New skills** — scan `~/.claude/commands/*.md` and `~/.claude/skills/**/SKILL.md`. A skill is a candidate if
  its git-history creation date (or mtime, if that tree isn't git-tracked) is later than the target's as-of
  date. (Note: `~/.claude` is untracked on this machine per MAP.md, so mtime is usually the available signal
  there; the tracked mirror at `claude-global-config/commands/` HAS git history and is the better date source
  when a skill exists in both — prefer the mirror's `git log` date.)
- **New / changed rule files** — check `~/.claude/CLAUDE.md`, `DESIGN.md`, `DESIGN-dashboards.md`, `VERIFY.md`,
  and the other rule/convention files, for content CHANGED since the as-of date (mtime, or the mirror's git
  history where tracked). A rule that tightened after the code was written (a new house design rule, a new
  verification mode, a new voice constraint) is a candidate the code may predate.
- **Dependencies** — from the target's OWN lockfiles/manifests (`package.json`/`package-lock.json`,
  `pyproject.toml`/`uv.lock`/`requirements.txt`, etc.), identify dependencies that have a materially newer
  major version or a better-established replacement. Check this OFFLINE only — from the lockfile's own pins and
  anything already on disk. Do NOT require web. Where an authoritative "is there a newer major" answer would
  need a live registry/web check, list the dependency as a candidate flagged **"web check would confirm"**
  rather than asserting a version you can't verify locally (NASA egress is blocked for sensitive topics — don't
  route dependency lookups through anything that touches internal content).
  - **Runtime end-of-life is its own check, separate from version currency.** A dependency (or the language
    runtime) can be on its latest pinned major and STILL be end-of-life — "newer major exists" and "this is
    EOL" are different signals, and version-bump tooling misses EOL because EOL dates live outside the
    registry. So read the target's pinned runtime — `.python-version` / `requires-python`,
    `engines.node` / `.nvmrc`, and the equivalent — as a FIRST-CLASS candidate, since the runtime is the
    highest-risk tier (an EOL runtime accepts unpatched CVEs with no vendor fix path). Runtime EOL dates
    (Python 3.x, Node LTS lines, etc.) are stable public facts from `endoflife.date`; state a known one when
    you're sure of it, and flag it **"web check would confirm (EOL date)"** when you are not, consistent with
    the offline-deps doctrine above. An EOL or near-EOL runtime is an impact-class-1 item in Step 3.

**Completion criterion:** a raw candidate list across the three lanes, each entry carrying the dated evidence
(commit/mtime/version) proving it post-dates the as-of date — or the lane explicitly reported empty.

### Step 3 — Filter to what plausibly APPLIES to THIS codebase

A candidate being newer is necessary, not sufficient — it must plausibly apply to this specific code. A
frontend/UI skill is irrelevant to a headless CLI; a dashboard rule doesn't touch a solver library; a Python
dependency bump is meaningless in a JS repo. Read enough of the target to judge fit (its language, whether it
has a UI, what it's for), and drop candidates that don't apply, stating in one line WHY each was dropped so the
filtering is auditable rather than silent.

For each SURVIVING item, produce the four fields:

- **What it is** — the real name (the skill's command, the rule file, the dependency) plus a plain-language
  gloss of what it does, so the item is legible without opening it.
- **Why it's newer** — the dated evidence from Step 2 (this skill was created 2026-07-10; this codebase is
  as-of 2026-05; therefore it didn't exist when you built this).
- **How it'd apply here** — the concrete connection to THIS codebase (e.g. "this repo has a dashboard that
  predates `DESIGN-dashboards.md`, so the hero/density rules would restructure its KPI row").
- **Rough effort** — a coarse sense of the work to adopt it (trivial / moderate / substantial), so Douglas can
  weigh it.

**Then group and rank.** Related survivors that would be accepted or declined together collapse into ONE
decision item (three minor bumps in the same ecosystem → one "routine dep refresh" item; several changes to
one rule file → one item) — Step 4's count counts DECISIONS, and fifteen fragments of one decision is the
update-fatigue failure mode dependency bots learned to group their way out of. Then order the final list by
impact class: (1) security- or end-of-life-relevant dependency items, (2) rule changes the code now visibly
violates, (3) new skills/capabilities that would change how the code is built or verified, (4) routine
freshness. Both Step 4 routes present items in this order.

**Completion criterion:** a grouped, impact-ordered list where every item has all four fields and every
dropped candidate has a stated reason — and every surviving item still traces to a real file/version read in
Step 2 (nothing invented to pad the list).

### Step 4 — Route the results by count (the unmissable branch)

Count the applicable items from Step 3 (grouped decision items, in their impact order). This branch is
explicit and is the whole point of the routing:

- **4 OR FEWER applicable items → use the `AskUserQuestion` tool.** Present them as clickable options for
  Douglas to pick which (if any) to pursue — one option per item, each carrying its four-field summary, plus a
  "none of these" path. Do NOT bury the choices in chat prose; the decision is discrete and small, which is
  exactly what AskUserQuestion is for (per the use-askuserquestion rule).

- **5 OR MORE (more than 4) applicable items → enqueue them into the Workbench reviewer app (:8471) with the
  `review` schema, via the `/docket` skill.** This is a genuine batch, which is exactly what the auto-route-to-
  Workbench directive covers — one `review` item per independently-decidable improvement (title = the item,
  description = its four fields), so Douglas can approve/reject each in the app rather than in a long chat turn.
  Invoke `/docket` to shape and enqueue; if assembling the payload is heavy (many items, long descriptions),
  offload the JSON-building + enqueue to a **haiku or sonnet low-effort subagent** per the Workbench directive,
  giving it the item list, the `review` schema, and the absolute node/CLI command. Report the enqueued id(s)
  and the URL (http://127.0.0.1:8471/review).

**Completion criterion:** the count was taken, the correct branch fired (AskUserQuestion for ≤4, Workbench-via-
`/docket` for 5+), and the route completed (the question was posed, or the items returned real enqueue ids).

### Step 5 — Report, and write the ledger

- Lead with the **drift headline**: the target, its **as-of date** (and which method produced it — git
  last-commit vs. mtime fallback), and the gap between the as-of date and today in months — one libyear-style
  number that says at a glance how far this codebase has drifted from the current harness.
- The **candidate → applicable** funnel: how many were found newer per lane, how many survived the apply-filter,
  the one-line reason each dropped candidate was dropped, and the count of items suppressed by the ledger.
- The **applicable items** with their four fields each (or a pointer to where they went — the AskUserQuestion
  options, or the Workbench review ids + URL).
- **Any lane that needed a web check** it couldn't do offline, named plainly (e.g. "3 npm deps may have newer
  majors — a live registry check would confirm"), so Douglas knows what the offline pass couldn't settle.
- Never claim the codebase is "fully modernized" or "up to date" — report what was surfaced this pass against
  the harness as it stands now; new skills/rules will keep appearing.
- **Write the ledger.** Record this pass in `MODERNIZE.md` at the target's root: pass date, as-of date, and
  each surfaced item with its decision (adopted / declined / deferred / pending-in-Workbench) once the route
  resolves. Each entry MUST also carry the item's stable identity plus the dated evidence it was surfaced on
  (the skill/rule path, or the dependency at its exact version/mtime/commit) — that recorded baseline is what
  Step 2's "re-surface only if it has materially changed since the decline" diffs against, so a bare "declined"
  with no version pin is a decline that can't be cleanly re-evaluated later (the immortal-PR failure mode a
  version-keyed identity exists to prevent). This is the file Step 2 reads next time; without it every pass
  re-litigates old declines.
- Full absolute path(s) of anything written (the ledger, a temp payload file for the Workbench route), per the
  standing Files-list convention.

## Safety constraints

- **Read-only on the target's code.** `/modernize` reads the target and reads the harness; it does not edit,
  refactor, or apply anything to the target's code. Applying an accepted item is a separate, later,
  explicitly-approved step. The only writes this command makes are transient payload files for the Workbench
  enqueue route (Step 4) and the `MODERNIZE.md` decision ledger at the target's root (Step 5) — never a change
  to the code it's evaluating.
- **Ground every item in a real file/version it actually read — never invent.** A "new skill," "changed rule,"
  or "newer dependency" that can't be pointed at with a real path and a real date is not reported. Padding the
  list with plausible-sounding items is the core failure mode this bans.
- **Offline dependency checks only; no required web.** Judge dependencies from the target's own lockfiles and
  what's on disk. Where a live check would help, FLAG it as unconfirmed rather than asserting a version — and
  never route a dependency lookup through anything touching NASA/CUI content (egress is blocked for sensitive
  topics; don't test it). NASA content stays local.
- **Never run with elevated/bypass permissions.** No commits or pushes. If a safety layer blocks an action
  mid-run, that's a correct block — narrow scope, don't route around it.

## Notes on scope (authoring_checklist)

Satisfies the authoring rules: front-loaded description leading with the core capability (find what's newer
since a codebase was built, surface the applicable, route by count) with triggers collapsed to one phrase per
branch; user-facing slash command that keeps model triggers deliberately (so it's reachable by name and by
intent); each step ends on a checkable completion criterion; the ≤4/5+ routing stated once as the single
source of truth in Step 4; safety of the produced behavior designed in (read-only on the target's code, no
invention, offline-only deps, NASA-local, the ledger as the one named write); a deviation clause stated once
near the top. Deliberate exception: NO embedded
multi-agent Workflow script — like `/onboard`, this is a single coherent read-then-route pass with no
independent parts to fan out (the ONE optional fan-out, a cheap subagent for a heavy Workbench payload, is a
delegation the procedure names inline, not a Workflow), so a Workflow would add ceremony without parallelism.
Self-contained single-file skill by design (Douglas's family convention).

---

*Tracked copy: also save this file to `claude-global-config/commands/modernize.md` (per the skills-are-tracked
convention) after a NASA scrub.*
