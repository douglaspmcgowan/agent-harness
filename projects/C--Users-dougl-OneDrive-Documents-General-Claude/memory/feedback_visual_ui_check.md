---
name: Visual UI check after any UI change
description: After any UI-affecting change, Playwright screenshot at desktop AND mobile before reporting done
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---

After any UI-affecting change (HTML, CSS, JS behavior, component edits), run Playwright screenshot at desktop (1440px) AND mobile (375px) before reporting done.

**Why:** UI bugs that only appear at specific viewports are common and invisible without a screenshot sweep.

**How to apply:** Use whatever `e2e/` or `playwright.config` exists. If none, write a minimal test. Do not rely on preview screenshots alone — run actual Playwright.

**Tool choice (Doug, 2026-06-06 — reinforced after I broke it):** Default to **headless Playwright** for ALL visual QA — it renders in real Chromium fully off-screen and never touches his display. **Never use `Claude_in_Chrome` (the Chrome extension MCP — `navigate`/`computer`) or computer-use for visual QA** — by design it drives his _visible_ browser ("no headless mode"), which takes over his screen. Only drive the visible browser if he explicitly asks (e.g. to use a logged-in session). The built-in **`Claude_Preview`** MCP is headless but (a) pops an in-app "Launch preview panel" on each edit and (b) its `preview_screenshot` HANGS when the page has external `<link>` resources (e.g. Google Fonts) because it waits for the `load` event — prefer Playwright. Playwright gotcha that fixes the same hang: `page.goto(url, {waitUntil:'domcontentloaded'})` + a short `waitForTimeout`, NOT `'load'`/`'networkidle'`. Playwright browsers are cached at `~/AppData/Local/ms-playwright` (chromium-1223 ↔ playwright@1.60); installing the matching `playwright` npm version reuses them with no download. See [[feedback_render_check_after_layout]].
