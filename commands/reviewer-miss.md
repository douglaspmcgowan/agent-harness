---
name: reviewer-miss
description: When Douglas shows a defect the reviewer/gate MISSED (floating part, oversized/ wrong component, partial hole, bolt overlap, etc.), run this four-step loop to isolate it, explain the blind spot, fix it, and land a DURABLE regression test so the same class of miss can never pass silently again. Feeds EVOLVE.md "never again".
---

# /reviewer-miss — turn a caught miss into a permanent gate improvement

Trigger: Douglas points at something in a render/viewer that is wrong but the build still PASSED
the gate. A passing gate that ships a visible defect is a **blind spot in the checker**, not a
one-off — treat every miss as a class of misses.

The whole point: a sentence like "I'll be more careful" is NOT the fix (see CLAUDE.md "make the fix
real"). The fix is a durable artifact — a new/tightened check plus a test that FAILS on the miss and
PASSES after — wired so the class can never recur silently.

## The four steps (do all four, in order, and report each explicitly)

### 1. Isolate WHAT it is
- Name the exact part / feature / defect, with evidence: part id(s) from `geometry_map.json` /
  `connections.json`, world coordinates, dimensions, and the render that shows it.
- Reproduce it numerically, not just visually — measure the offending quantity (washer OD, hole
  through-fraction, bolt-vs-bore clearance, realized-joint count). If you can't measure it, you
  can't test it.
- One-line statement: "Part X's feature Y has measured value Z; correct value is Z'."

### 2. Isolate HOW the reviewer missed it
- Find the check that *should* have caught it. Read the gate/audit code and cite `file:line`.
- State precisely why it passed: the check doesn't exist, the threshold is too loose, the check
  looks at the wrong quantity (proxy instead of physical truth), or the defect is of a kind the
  gate never inspects (e.g. gate only validates *declared* joints, never asks "should this part be
  connected at all").
- One-line statement: "gate.py:NNN checks A but the defect is in B, so it passed."

### 3. Isolate HOW you're going to change it
- The minimal change that closes the class. Usually BOTH:
  - **Geometry fix** — correct the actual part (surgical; every changed line traces to the defect).
  - **Checker fix** — a new check or a tightened/re-pointed existing one that measures the *physical
    truth*, never a proxy. NEVER loosen a threshold to force a pass.
- State the scope boundary: what you will and won't touch.

### 4. Pick a superpower skill that makes it robust + a durable test
Choose by the nature of the change and say why:
- **`test-driven-development`** — new/tightened check. Write the FAILING test first (asserts the gate
  REJECTS the current miss / flags the defective part), watch it fail, then implement until it passes
  AND the honest build still passes. This is the default for a reviewer-miss.
- **`systematic-debugging`** — the miss is a symptom and you need the root cause before you can test it.
- **`verification-before-completion`** — before claiming fixed, regenerate geometry fresh and re-run
  gate + the new test; confirm both green and the two verifiers agree.
- **`requesting-code-review`** — the fix touches load-bearing gate logic and wants a second pass.

The regression test MUST:
- live in the repo's test suite (`test_*.py`) and run in the build/gate path, not by memory;
- fail on the pre-fix geometry (prove it catches the miss) and pass on the fixed geometry;
- assert the *physical* condition, so a future geometry regression re-trips it;
- draw its expected value from an INDEPENDENT source of truth — a measured/known-correct number, a
  hand-computed bound, the spec — never recomputed the same way the code under test derives it. A test
  whose assertion re-runs the code's own math (the tautological-test tell, from Matt Pocock's `tdd`)
  passes even when both are wrong, so it guards nothing.

## Then: record the never-again
Append an entry to `EVOLVE.md` (the cad-forge never-again log): what was missed, the blind-spot root
cause, the check + test that now guards it, and the date. If the miss reveals a harness-level pattern
(not just a CubeSat geometry issue), also add a memory entry so future sessions inherit it.

## Output format (report all of this back to Douglas)
```
MISS: <one line — what + measured vs correct>
WHY MISSED: <one line — check + file:line + proxy/absent/loose/wrong-quantity>
FIX: geometry <what> + checker <new/tightened check, measuring what>
SKILL: <which superpower skill + why>
TEST: <test name> — fails pre-fix, passes post-fix, asserts <physical condition>
GATE: <before → after, honest numbers>
EVOLVE: <the never-again line added>
```

## Hard rules (from CLAUDE.md / cad-forge)
- The honest gate (point-in-solid through-hole, VOL_TOL current) is the SOLE accept oracle. Never
  loosen a threshold to pass.
- "held/PASS" must mean a real modeled fastener with material both sides — never proximity/bbox.
- Surgical changes only; flag unrelated dead code, don't fix it.
- Don't declare done until the failing test is green on freshly regenerated geometry.
