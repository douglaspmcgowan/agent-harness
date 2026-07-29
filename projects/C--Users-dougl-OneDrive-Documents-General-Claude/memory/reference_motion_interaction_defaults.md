---
name: reference_motion_interaction_defaults
description: "Concrete motion/button/interaction numbers for Doug's web apps — icon-button hover-reveal, easings, durations, radii, focus, reduced-motion"
metadata:
  node_type: memory
  type: reference
  originSessionId: b05b66b3-fcc9-4eb1-bc72-1b1bf1a0aec7
---

Doug's app-polish defaults, gathered from practitioner research (Emil Kowalski animations.dev, Rauno Freiberg interfaces.rauno.me, Josh Comeau, Apple HIG/Material motion) and applied in the REDLINE IDE. Fuller treatment lives in the **impeccable skill** (`reference/animate.md`, `reference/interaction-design.md`) — read those for the why; this is the cheat sheet.

**Icon buttons (Cursor/Linear/Raycast toolbar pattern):** icon-only at rest (transparent bg, muted glyph), faint chrome appears on hover. Dark UIs: hover bg `rgba(255,255,255,.06)`, active `.10`. Lock every toolbar control to ONE box height on a baseline (REDLINE: 28px box, 16px glyph, 6px radius). Press = `transform: scale(.96)`. Icon-only buttons MUST have `title`/`aria-label` (tooltip). Gate hover with `@media (hover:hover)`.

**Motion:** enter/appear → `ease-out` (`cubic-bezier(.16,1,.3,1)`); moving something already on screen → `ease-in-out`; plain `ease` is fine for a hover bg color. Durations: hover/press feedback 80–150ms; state changes (menu, tooltip, toggle) 200–300ms; layout 300–500ms; anything >400ms for feedback feels laggy. Exit ≈75% of enter. Only animate `transform`/`opacity` (compositor, 60fps) — never width/height/top/left. No bounce/elastic. The `<200ms feels instant` rule.

**Number alignment:** `font-variant-numeric: tabular-nums` on the sans font, NOT a mono font. (See [[feedback_ai_isms]] rule 7 — mono is only for code/IDs/kbd/paths/tokens.)

**Corner radius:** nested rule — inner = `max(0, outer − padding)`. Real values: buttons/inputs 6–8px, cards/panels 8–12px, app shell/modal 10–14px. Keep one scale.

**Every interactive element needs all states:** default/hover/focus/active/disabled (+loading/error/success for inputs). Hover ≠ focus — keyboard users never see hover. Focus ring via `:focus-visible` + `box-shadow` (respects border-radius), not `outline`; `box-shadow:0 0 0 2px var(--bg),0 0 0 3px var(--accent)`. Always ship `@media (prefers-reduced-motion: reduce)` killing transitions/transforms.

Related: [[feedback_ai_isms]], [[reference_toolkit_map]].
