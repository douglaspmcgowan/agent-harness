# Frontend & browser testing — full rules

> Referenced from global CLAUDE.md. Read this when any frontend / browser-visible / UI work is in scope. The summary in CLAUDE.md is just a pointer.

## Default tool: Playwright

Use Playwright for any frontend or browser-visible change. Don't ask — just run it.

- The test suite to use is whatever `e2e/` or `playwright.config.{js,ts,mjs}` exists in the project. If none exists, write one.
- Don't rely on preview screenshots alone to verify UI correctness — Playwright captures both function and visual.
- If `npm test` is wired up, that's the canonical entry point. If not (TECH_DEBT_AUDIT F05 was an instance of this in psych-battery), wire it.

## Never use computer-use for visual QA

Computer-use (mouse/keyboard takeover) is slow, takes over your screen, and risks side effects. Playwright is faster, headless, scriptable, and non-disruptive. Reach for computer-use only when the task **genuinely cannot** be done another way:

- Native desktop app (Maps, Notes, Photos, System Settings)
- A UI Playwright physically can't reach (login flows requiring 2FA, Electron-app-specific quirks)
- Cross-app workflow

For everything browser-based, Playwright wins.

## What to verify, in order

1. **Functional pass/fail.** Click → expected state? Form submit → API fired with right body? Navigation → URL match?
2. **Multi-viewport sweep.** Run scripted scenarios at desktop (1440×900) AND mobile (375×667). UI breaks asymmetrically; one viewport rarely catches both.
3. **Smoke-test all interactives.** Iterate every `button`, `[role="button"]`, `a[href]`, `[tabindex="0"]`. Each should be: tappable at ≥44×44 px, click-without-console-error, no infinite-nav-loop. See `psych-battery/e2e/SMOKE-TEST-PLAN.md` for the brief.
4. **Visual regression.** Screenshot at known viewports → compare to baseline with `pixelmatch` or Playwright's `toMatchSnapshot`. Catches "I broke pixels somewhere."
5. **Console capture.** Errors thrown silently during a click are real bugs. `page.on('console', msg => msg.type() === 'error' && fail())`.
6. **Network capture.** Did the API call I expected actually fire? With the right body? `page.on('request', req => log.push(req))`.
7. **A11y.** `@axe-core/playwright` integration: contrast, aria, keyboard nav.

## Mobile-first defaults (from global CLAUDE.md)

- Touch targets ≥ 44×44 px (48 preferred for primary actions)
- `env(safe-area-inset-*)` for spacing on iOS (especially bottom — home indicator)
- Test 375×667 (iPhone SE) before declaring done — it's the smallest realistic viewport
- No horizontal scroll on mobile
- Tap targets shouldn't overlap (audit Pattern 4 was this exactly)

## When Playwright passes but the UI is still broken

Playwright tests verify _function_. They miss _layout_ problems where everything is technically clickable but visually wrong. The `feedback_visual_ui_check.md` memory rule covers this: after Playwright passes, screenshot at desktop AND mobile, then explicitly check for:

- Overlapping fixed-position elements (especially `top:` + `right:` corners — theme-toggle + help button is the canonical example)
- Z-index conflicts (modals under tooltips, dropdowns under headers)
- Contrast issues in light AND dark modes
- Off-screen content / clipping
- Mobile breakage (horizontal scroll, content reflow, tap target overlap)

If any are found, fix and re-screenshot. Don't declare done until both screenshots are clean.

## Existing tooling on this machine

- **psych-battery:** `e2e/` has 23+ test files, including `editorial-full.mjs` (80-step scripted walkthrough). Smoke-test plan written to `e2e/SMOKE-TEST-PLAN.md` — implementation pending.
- **`/walmart-ultrareview`:** custom slash command for deep pre-merge review. Worktree sandbox + live render + verification pass. Auto-deep-mode for diffs ≥4 files.
- **General playbook:** see `Claude Research Folder/playwright-playbook.md` (master testing playbook).

## Pointer / cross-references

- Memory rules: `feedback_render_check_after_layout.md` (CSS positioning), `feedback_visual_ui_check.md` (any UI change, broader), `feedback_codex_avoidance_rules.md` rule #5 (don't dispatch Codex against single files >5k lines for UI work)
- Skill: `/walmart-ultrareview` for pre-merge review
- Repo-specific: `psych-battery/e2e/SMOKE-TEST-PLAN.md`, `psych-battery/e2e/editorial-full.mjs`

When in doubt: screenshot both viewports, check for overlap, check console, check the mobile experience. Functional pass ≠ done.
