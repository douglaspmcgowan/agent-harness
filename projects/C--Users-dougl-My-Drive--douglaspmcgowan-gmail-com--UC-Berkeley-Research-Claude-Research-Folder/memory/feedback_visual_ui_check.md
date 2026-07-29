---
name: Visual UI check after every UI change
description: After Playwright passes on a UI change, take screenshots at desktop AND mobile, look for overlapping fixed-position elements, z-index conflicts, contrast issues, off-screen content, and clipping. Don't declare done on functional pass alone.
type: feedback
originSessionId: 3e7644c5-ae92-4dd3-984b-a34b89820eef
---

After **any** change touching HTML structure, CSS, layout, or new visible elements — even when Playwright tests pass:

1. Take a screenshot at **1440×900 desktop** and **375×667 mobile (iPhone SE)**. Both. Always.
2. Look for, and explicitly report on:
   - **Overlapping fixed-position elements** — two `position: fixed` items in the same corner (especially `top:` + `right:`). The classic case is theme-toggle + help button.
   - **Z-index conflicts** — modals under tooltips, dropdowns under headers, popovers under sticky elements.
   - **Contrast** — text legible against the background in BOTH light and dark modes.
   - **Off-screen content / clipping** — text cut off, controls extending beyond viewport, scroll bars on elements that shouldn't have them.
   - **Mobile-specific** — buttons too small (<44×44px), tap targets overlapping, horizontal scroll on mobile, content reflowing badly.
   - **New element placement** — does the new thing visually conflict with anything that was already there?
3. If any of the above is found, fix and re-screenshot. Don't declare done until both screenshots are clean.

**Why this exists in addition to `feedback_render_check_after_layout`:**
The render-check rule fires on explicit CSS positioning changes. This rule fires on _any_ UI-affecting change — including additions of new elements, layout changes that aren't strictly "positioning," and tests that pass functionally but break visually. Playwright passing means _clickable_, not _visible_.

**Why:**

- Session `3e7644c5` (2026-04-29): "did you catch that the color switch button is overlapping the keyboard shortcuts button? or that there's no clear indication where to learn more about the analysis... so why didn't you find that?"
- TECH_DEBT_AUDIT 2026-05-04 finding F10: theme picker and `?` help button stacked at desktop width — flagged but not fixed because no rule caught it.
- Session `504d357c` (2026-05-05/06): "did you test and verify that these things are fixed?" / "still there. it looks exactly the same. you were wrong. you need to look at every figure. EVERY ONE."

**Trigger:** Any tool call that modifies HTML, CSS, or adds rendered elements. Especially after Playwright tests report green.

**Verification approach (preferred order):**

1. Playwright `page.screenshot()` at both viewports (most reliable, scriptable).
2. If Playwright isn't set up, use computer-use to screenshot the rendered page.
3. If neither is available, ask the user for a screenshot before declaring done.

**Don't put any real screenshot URLs, test credentials, or app-specific selectors in this file.** Examples here are illustrative only.
