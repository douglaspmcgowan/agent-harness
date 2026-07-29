# refactoring.mini — Fowler code-smell baseline

Sourced from Martin Fowler, *Refactoring* (2nd ed.) smell catalog. A versioned baseline for the **standards
axis** of code review (`/solo-review`, `/tech-debt-audit`, `/simplify`) — sweep a diff against these instead of
recalling smells from memory. A smell is a *prompt to look*, never proof of a defect.

- **Mysterious Name** — a name that doesn't say what the thing does. Rename until it does.
- **Duplicated Code** — same structure in more than one place; extract and share.
- **Long Function** — does too much; decompose by intent, not by length alone.
- **Long Parameter List** — pass an object, or query for what can be derived.
- **Global / Mutable Data** — shared mutable state; encapsulate behind accessors.
- **Divergent Change** — one module changes for many unrelated reasons; split it.
- **Shotgun Surgery** — one change forces edits across many modules; consolidate.
- **Feature Envy** — a function more interested in another module's data than its own; move it.
- **Data Clumps** — the same few fields travel together everywhere; make them an object.
- **Primitive Obsession** — primitives standing in for domain concepts; introduce types.
- **Repeated Switches** — the same switch/if-cascade in many places; polymorphism or a lookup table.
- **Message Chains** — `a.b().c().d()`; hide the navigation behind one method.
- **Middle Man** — a class that only delegates; cut out the go-between.
- **Speculative Generality** — machinery for a need that never came. Deletion test: would removing it
  *concentrate* complexity or just *relocate* it? "Concentrate" is the signal to delete.
- **Refused Bequest** — a subclass that ignores most of what it inherits; rethink the hierarchy.

**Tautological-test tell** (from Matt Pocock's `tdd`): a test whose assertion recomputes the expected value the
same way the code derives it (`expect(add(a,b)).toBe(a+b)`) proves nothing — expected values must come from an
independent source of truth.

Other sourced pulls worth adding when a skill needs them (Matt Pocock's `agent-rules-books` distillations):
`a-philosophy-of-software-design` (deep modules, complexity — backs simplicity-first), `working-effectively-
with-legacy-code` (seams — backs the TDD/plan seam discipline), `the-pragmatic-programmer` (broad hygiene).
