---
name: Render check after CSS layout changes
description: After any CSS positioning change, take a Playwright screenshot to verify layout didn't break
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---
After any CSS positioning change (flexbox, grid, absolute/fixed positioning, z-index), take a Playwright screenshot and verify layout.

**Why:** CSS changes that look correct in code frequently produce invisible overlaps, collapsed containers, or broken mobile layouts.

**How to apply:** Edit CSS → run Playwright screenshot at 1440px and 375px → check both before reporting done.
