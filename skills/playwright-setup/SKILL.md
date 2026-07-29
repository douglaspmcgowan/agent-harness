---
name: playwright-setup
description: Set up or audit Playwright on any web project — install, config, four base test files (smoke, buttons, visual, a11y), npm test wired. Distilled from `Claude Research Folder/playwright-playbook.md`.
when: Starting a new web project that needs UI testing; auditing an existing web project where `npm test` doesn't work or coverage is unclear; user says "set up Playwright" / "wire up tests" / "I need testing on this site".
---

# Playwright setup skill

Reference: `~/My Drive (douglaspmcgowan@gmail.com)/UC Berkeley/Research/Claude Research Folder/playwright-playbook.md` (full playbook, including phases 3+ for project-specific extensions).

## Quick decision tree

- **Project has no `playwright.config.*`** → run Phase 1 + 2.
- **Project has Playwright but `npm test` fails** → diagnose first; usually `package.json scripts.test` not wired.
- **Project has Playwright, tests pass, but coverage is thin** → run Phase 2 to add the 4 base files.
- **Project has component-heavy SPA with state** → Phase 1 + 2 + Phase 3A (state reset).
- **Project has auth flow** → Phase 1 + 2 + Phase 3B (storageState).

## Phase 1 — Minimum viable setup

```bash
npm i -D @playwright/test
npx playwright install chromium
```

Create `playwright.config.mjs`:

```js
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  timeout: 30_000,
  retries: process.env.CI ? 2 : 0,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL: "http://localhost:3000", // CHANGE per project
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium-desktop",
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1440, height: 900 },
      },
    },
    { name: "mobile-iphone", use: { ...devices["iPhone SE"] } },
  ],
});
```

Add to `package.json`:

```json
"scripts": {
  "test": "playwright test",
  "test:smoke": "playwright test e2e/smoke.spec.mjs",
  "test:visual": "playwright test e2e/visual.spec.mjs",
  "test:buttons": "playwright test e2e/buttons.spec.mjs",
  "test:a11y": "playwright test e2e/a11y.spec.mjs"
}
```

## Phase 2 — Four base test files

Write all four. The full source is in `Claude Research Folder/playwright-playbook.md` Phase 2:

1. **`e2e/smoke.spec.mjs`** — does the home page load with no console errors?
2. **`e2e/buttons.spec.mjs`** — every clickable element ≥44×44 px, clicks without console errors
3. **`e2e/visual.spec.mjs`** — screenshot diff at desktop + mobile across known routes
4. **`e2e/a11y.spec.mjs`** — `@axe-core/playwright` integration; fail on critical/serious violations

Install axe-core for the a11y file:

```bash
npm i -D @axe-core/playwright
```

## Phase 3 — Project-specific extensions (when needed)

**Phase 3A — SPAs with state:** Reset state between tests. `await page.evaluate(() => localStorage.clear())` in `beforeEach`. For React/Vue, consider component testing via `@playwright/experimental-ct-react`.

**Phase 3B — Auth flows:** Capture once via `npx playwright codegen --save-storage=auth.json`, reuse via `use: { storageState: 'auth.json' }`.

**Phase 3C — Charts/canvas:** Visual diff is unreliable (anti-aliasing, GPU). Use `maxDiffPixelRatio: 0.05` and mask the canvas, OR test the underlying SVG/data instead.

**Phase 3D — WebSocket / long-poll sites:** `networkidle` never settles. Use `waitForSelector` instead.

**Phase 3E — Multi-page sites:** Pull routes from sitemap.xml or a routes JSON; loop the four file patterns.

## Phase 4 — Wire to existing workflows

- **`npm test`** runs the suite (already done in Phase 1).
- **`/walmart-ultrareview`** uses the suite as part of pre-merge review.
- **`feedback_visual_ui_check.md`** memory rule requires the multi-viewport screenshot pattern after any UI change — `e2e/visual.spec.mjs` is what backs that rule.
- **CI (if configured):** GitHub Actions runs Playwright on PR.

## Common pitfalls (from playbook)

- Network idle never settles → `waitForSelector`
- Buttons that navigate → harness must reset between iterations
- Hidden modal-trapped buttons → filter with `await el.isVisible()`
- Flaky animation timing → disable transitions in test mode via `addInitScript`
- Visual baselines must be committed (`*.png` snapshots are versioned UI state)

## Verifier

After running this skill end-to-end, `npm test` should exit 0. If it doesn't, the failures are real bugs (not setup gaps) — fix them and re-run.

## Cross-references

- Master playbook: `Claude Research Folder/playwright-playbook.md`
- Frontend rules: `~/.claude/CLAUDE-frontend-testing.md`
- Memory rules: `feedback_visual_ui_check.md`
- Reference impl: `psych-battery/e2e/` (23+ test files; `editorial-full.mjs` is the gold standard scripted scenario)
- Smoke-test brief: `psych-battery/e2e/SMOKE-TEST-PLAN.md`
