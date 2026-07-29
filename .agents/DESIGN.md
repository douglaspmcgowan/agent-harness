# Universal interface design rules

These rules apply to every interface. A project `DESIGN.md` begins with the managed universal block and adds product-specific visual language, components, and constraints below it. Keep architecture history and product decisions in project records.

## Typography

- Never use IBM Plex Mono.
- Use a proportional body face for prose, navigation, labels, dates, names, and human-readable metadata.
- Reserve monospace for code, commands, identifiers, timestamps, and genuinely tabular numeric data.
- Enable tabular numerals on the proportional face when aligned quantities need stable widths.
- Define explicit body, display, and monospace roles in each interface project. Use a restrained type scale, readable line length, and comfortable leading.
- Preserve hierarchy through size, weight, spacing, and placement before adding decorative treatments.

## Layout and hierarchy

- Give every screen one clear primary action or reading path.
- Use spacing and alignment to show relationships. Avoid decorative containers that do not communicate grouping or interaction.
- Keep content density appropriate to the task. Surface advanced detail progressively.
- Design responsive behavior at narrow, medium, and wide widths.

## Components and states

- Reuse the project's established tokens and components before adding variants.
- Design default, hover, focus, active, disabled, loading, empty, error, and success states where they apply.
- Keep controls recognizable and labels specific to the action.
- Use motion to clarify causality, hierarchy, or state change. Respect reduced-motion preferences.

## Accessibility

- Use semantic structure and native controls when possible.
- Preserve visible keyboard focus, logical tab order, and accessible names.
- Meet current WCAG AA contrast targets for text and essential interface graphics.
- Do not rely on color alone to communicate state.
- Support zoom, text resizing, and touch targets suitable for the device.

## Evidence and verification

- Inspect the existing design system, screenshots, and implementation before proposing a new visual rule or component.
- Verify browser-visible work with the repository's browser or end-to-end test and review responsive, keyboard, loading, empty, and error behavior.
- Record project-specific typefaces, tokens, components, and exceptions in the repository `DESIGN.md`.
