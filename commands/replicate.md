---
name: replicate
description: "Faithfully replicate/match an existing reference artifact (a UI, page, chart, doc, API surface) feature-for-feature. Converts a vague 'match X' into an EXHAUSTIVE enumerated parity checklist BEFORE building, then verifies every item against the build with real evidence, and reports every gap. Use when Douglas says 'match X', 'replicate X', 'copy their approach', 'make it like Y', 'clone this interface', 'feature parity with Z', or '/replicate'. Exists because a prior 'match deepswe' build captured the reference's controls but never carried three of them into the build — no written checklist means 'match everything' silently collapses to 'match the look'."
---

# /replicate [reference] → [target]

Replicate an existing thing faithfully. The reference is what you're matching (a live URL, a screenshot, a file, an API, a doc). The target is what you're building or changing to match it.

**Why this exists (the failure it prevents):** In the deepswe build, the reference's full control set (`Cost / Output tokens / Agent steps` switch, `Best / All` toggle, `Pick models` filter) was captured into the session transcript by `read_page` — and three controls still never reached the build. Observing the reference is not the hard part. The step that silently drops is **observed → enumerated → implemented → verified**. Without a written checklist, "match everything" degrades to "match the obvious visual stuff," and the missing pieces are invisible because there's nothing to check them against. This skill forces the checklist to exist and to be verified item-by-item. Companion rule: `~/.claude/memory/feedback_verification_discipline.md` and `~/.claude/memory/feedback_match_means_enumerate_parity.md`.

---

## Gate (do this first — stop if it fails)

1. **Is there a concrete, reachable reference?** A URL, file, screenshot, or spec you can actually inspect. If the reference is only described from memory or is unreachable, STOP and say so — do not replicate from a mental model.
2. **Is "match" really the ask?** If Douglas wants *inspired-by* or *better-than*, this skill's exhaustive-parity discipline is the wrong tool; say so and offer `impeccable` or `redesign-existing-projects` instead.

If both pass, proceed. Restate the literal ask in one line: *"Match everything" = the parity checklist I am about to build. Anything not on it is out of scope; anything on it must end ✅ or a justified N/A.*

---

## Phase 1 — Inventory the reference EXHAUSTIVELY (before touching the target)

Build the parity checklist FIRST. This is the whole point — do not start building the target until the checklist exists.

**For a UI / page / chart** — actually open the reference and read its real structure, don't eyeball a screenshot:
- Open it (in-app browser `read_page` interactive tree, or Playwright). Enumerate **every interactive element**: every button, toggle, segmented control, dropdown, filter, sort, tab, version switch, legend-as-filter, hover tooltip, drawer, keyboard affordance.
- Enumerate **every axis option** and what each does (e.g. an x-axis metric switch is a *different control* from a y-axis metric switch — list both).
- Enumerate **layout / content regions** (hero tiles, tables + their columns, cards, sections).
- Enumerate **states**: default view, empty, hover, selected, filtered, collapsed/expanded, light/dark.

**For a doc / API / schema** — enumerate every section, field, endpoint, parameter, error, example.

**Write the checklist to a file immediately** (`parity-checklist.md` in the working dir) as `- [ ] <item> — <what it does in the reference>`. Anti-amnesia: compaction must not be able to erase the enumerated set. One line per item.

**Mark items that legitimately don't apply to the target as `N/A — <reason>` right in Phase 1** (e.g. deepswe's "Agent steps" axis has no analog in a single-turn model eval). Naming them now stops them from looking like silent omissions later.

---

## Phase 2 — Build the target against the checklist

Implement to the checklist, matching the reference's existing idioms in the target's own design system (reuse the target's tokens/components; don't import the reference's CSS wholesale). Every checklist item is a work item. Do not add un-asked features; do not drop asked ones.

---

## Phase 3 — Verify EVERY checklist item against the build (falsification, not green-reading)

For each `- [ ]` item, produce **evidence**, then mark `[x]`, `[!]` (missing/broken), or leave the `N/A` from Phase 1:

- **Interactive items must be DRIVEN, not just found.** Clicking the control must change observable state. Assert the change: "clicked `Output tokens` → x-axis label became `average output tokens…`" beats "the button exists." Use Playwright headless (`@playwright/test` is global at `C:/Users/dmcgowa2/tools/nodejs/node_modules`; resolve via `createRequire`) or the in-app browser. Screenshot capture times out on this laptop — drive + assert DOM, per `feedback_screenshot_fallbacks`.
- **Static items** — confirm by reading the built source, not the template you edited.
- **A found element is not a passed check.** The check passes only when its *behavior* matches the reference's.

Any `[!]` goes back to Phase 2. Loop until every item is `[x]` or a justified `N/A`.

---

## Phase 4 — Report the checklist honestly

1. Restate the literal ask and show the **full checklist** with ✅ / ❌ / N/A-with-reason per line. The checklist IS the deliverable's proof.
2. Call out every item that is **N/A** and why (so "not matched" reads as a decision, not a miss).
3. Name what was **verified live** vs **only read in source** vs **not verified** — never claim a control works if it wasn't driven.
4. If anything remains `[!]`, say so plainly; do not report "matched" over an open gap.

---

## Operating constraints

- **Enumerate before building.** If you're editing the target before the checklist file exists, you've already reproduced the original failure. Checklist first.
- **Capturing ≠ implementing.** Having the reference's structure in context (a `read_page` dump, a screenshot) does not mean it's built. Only the checked-off checklist proves that.
- **Drive interactive controls to verify.** Existence is not behavior.
- **No antithesis framing** ("X, not Y") — state the positive claim (per global CLAUDE.md).
- **Say N/A out loud.** A reference feature that genuinely doesn't map to the target is a justified N/A on the checklist, never a silent omission.
