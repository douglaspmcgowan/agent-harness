---
name: harness-review
description: "Adversarially review the harness loops/hooks (or any code target) to FIND EDGE CASES before they bite — read each file rule-by-rule, then run skeptical lenses that try to BREAK it and check it against Douglas's own rules. Use when Douglas says 'review the harness', 'find edge cases', 'red-team this', 'what could break', 'harness-review', '/harness-review', or proactively after any non-trivial hook/loop/safety change BEFORE claiming it's done."
---

# /harness-review [target]  —  adversarial edge-case review

Finds the edge cases that happy-path tests miss. This is the repeatable version of the 2026-06-29 pass that caught the R14 promise defects, the queue-regex silent-stop, and the dead `/longrun` writer. Default target = the harness loops + hooks; a target arg points it elsewhere (a hook, a file, a recent diff).

**Why this exists:** "my tests pass" is not "done". Tests confirm the design you had in mind; this tries to *falsify* it and checks it against the user's own constraints. Run it BEFORE declaring a hook/loop/safety change complete — don't wait to be re-prompted. Complements Superpowers `requesting-code-review` (reviewer subagent on a diff) and `verification-before-completion` (no claim without evidence); reach for those too.

## Default target — the harness loops
keep-going.js (queue-drive + R14), wait-on-usage-limit.js, session-usage-statusline.js, session-primer.js, mirror-tasks-to-current.js, hook-state.js, tools/longrun-watcher.py, plus settings.json wiring. Reference: `NASA_GSFC_Vault_1/Claude/Engineer/Harness loops — full reference + edge cases.md`.

## Procedure — run a Workflow (this is an explicit opt-in to the Workflow tool)
1. **Read phase (parallel).** One reader per file → a STRUCTURED description: every rule in order, trigger, action, exit code, kill switches, and any edge case the source itself implies. Reader rule: read the actual file, cite file:line, never guess.
2. **Adversarial phase (parallel, grounded in phase 1).** Run distinct skeptical lenses — at minimum:
   - **correctness/concurrency** — re-entrancy, races on state files, off-by-one, parsing-window limits, false-positive / false-negative of any signal.
   - **collision-with-Douglas's-own-rules** — does any behavior fight a CLAUDE.md hard rule? (e.g. "always end with a Files list" defeated R14's last-block-only promise check — that class of bug.)
   - **durability/ops** — inSync/OneDrive rollback or mid-run deletion, plugin update re-arming a hook, stale sentinels, timeout vs sleep-ceiling margins, headless vs interactive, a stalled background task.
   Each finding: scenario → what actually happens → severity → concrete fix → `isRealRisk` (true only if Douglas could really hit it).
3. **Verify phase.** For each `isRealRisk` finding, a skeptic tries to REFUTE it (default to refuted unless the source supports it) so plausible-but-wrong findings die.
4. **Report.** Group by severity; lead with real defects; for each give the file:line, the trigger, and the fix. Then ASK which to fix (or, if invoked under `/goal` or "fix them", fix + add a test that reproduces each defect first, then re-run the suites).

## After any fix
Re-run the full proof: `keep-going.test.js`, `keep-going.loop.test.js`, `session-primer.test.js`, `session-usage-statusline.test.js`, `longrun-watcher.py --self-test`, and `hook_guarantee.js "<workspace-root>"` (must be 46/46). Tests must assert the EXACT exit code (2=block / 0=allow); exit 1 is the silent-failure trap. Sync live→mirror + commit (no push). Update the reference brief + `reference_keepgoing_and_longrun.md`.

## Targeting other code
`/harness-review <path-or-"the diff I just made">` — same Read→Adversarial→Verify→Report shape on that target, dropping the harness-specific reference. For a committed diff, prefer Superpowers `requesting-code-review` (reviewer subagent on BASE..HEAD).
