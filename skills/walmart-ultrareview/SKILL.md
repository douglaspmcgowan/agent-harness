---
name: walmart-ultrareview
model: opus
description: Deep pre-merge code review that closes the gap with /ultrareview using subscription tokens + isolated worktree sandbox + live app rendering + independent verification. Two modes — quick (sequential, small diffs) and deep (parallel agents, worktree sandbox, live render, verification pass). Accepts an optional commit range and mode flag: /walmart-ultrareview [git-ref] [--quick|--deep]. Defaults to HEAD~1..HEAD. Auto-selects deep mode for diffs touching 4+ files.
---

# /walmart-ultrareview

Full-spectrum pre-merge review. Matches /ultrareview's coverage — bug hunting, regression detection, security, performance, live execution, visual rendering, independent verification — using subscription tokens and local tooling instead of a paid remote sandbox.

---

## Step 0 — Parse arguments

`$ARGUMENTS` may contain: a git ref, `--quick`, `--deep`, or any combination.

- Strip `--quick` and `--deep` from the ref string before passing to `git diff`.
- Default git ref if none provided: `HEAD~1..HEAD`.
- Default mode: **auto** (see mode detection below).

Examples:

- `/walmart-ultrareview` → `git diff HEAD~1..HEAD`, auto mode
- `/walmart-ultrareview main...HEAD` → `git diff main...HEAD`, auto mode
- `/walmart-ultrareview HEAD~5 --deep` → `git diff HEAD~5..HEAD`, force deep mode
- `/walmart-ultrareview --quick` → `git diff HEAD~1..HEAD`, force quick mode

---

## Step 1 — Orient (run in parallel, always)

Run ALL of these simultaneously before touching any code:

- `git diff [ref] --stat` — count changed files
- `git diff [ref]` — full diff content
- `git log --oneline -10` — recent commit context
- Read `CURRENT-TASK.md` if it exists
- Read `CLAUDE.md` if it exists

Report one line: **what changed, in how many files, against what base**.

---

## Step 2 — Select mode

| Condition              | Mode         |
| ---------------------- | ------------ |
| `--quick` flag         | Quick        |
| `--deep` flag          | Deep         |
| Diff touches ≤ 3 files | Quick (auto) |
| Diff touches 4+ files  | Deep (auto)  |

Tell the user which mode was selected and why.

---

## QUICK MODE (sequential, in-conversation)

Use when: `--quick` flag, or ≤ 3 files changed.

Run Phases Q1 through Q8 sequentially in the main conversation. No sub-agents. Then run the verification pass before delivering.

### Phase Q1 — Blast radius

For every file in the diff, one line:
`filename → what changed → what it affects (callers, shared state, other components)`

Flag anything touching shared state, globally-called functions, or global CSS.

### Phase Q2 — Run the test suite

Find and run tests in this order:

1. `CLAUDE.md` or `README` — documented test command
2. `e2e/` directory — `node e2e/*.mjs` or equivalent
3. `package.json` → `scripts.test`
4. Any `*.test.*` or `*.spec.*` files

Report: **X pass / Y fail / Z skipped**. Flag new failures. No tests = a finding.

### Phase Q3 — Bug hunt 🐛

Read each changed function with fresh eyes:

**Logic errors**

- Off-by-one in loops, indices, slice/splice bounds
- Wrong comparison (`=` vs `===`, `<` vs `<=`, `||` vs `&&`)
- Conditions that are always true or always false
- Short-circuit surprises with falsy values (0, `""`, `null`, `NaN`)
- Missing `await`; unhandled promise rejections
- Function called for side effect when return value is expected (or vice versa)

**Edge cases**

- Input is `null`, `undefined`, `0`, `""`, `[]`, `{}`
- Array empty or single-element
- First run vs. subsequent (localStorage empty, state uninitialized)
- API/server offline — does the fallback work?
- Double-click or rapid double-fire

**State / concurrency**

- Shared state mutated directly instead of through setter
- Async operations that can interleave and corrupt state
- `setInterval`/`setTimeout` callbacks referencing stale closures
- Event listeners added but never removed (leak on re-render)

Each finding: `FILE:LINE — what's wrong — severity: critical/high/medium/low`.

### Phase Q4 — Regression check 🔁

For every `-` line in the diff:

- What did the old code do?
- Does the replacement preserve that for **all callers**?
- Grep the changed function/variable name — any other call sites that relied on old behavior?

Specific regressions:

- Renamed or removed export used elsewhere
- Default argument changed or removed
- Return type or shape changed
- CSS selector scoping changed (now misses or hits too many elements)
- localStorage key renamed — old data silently ignored

Flag any behavior change not described in the commit message as a **potential regression**.

### Phase Q5 — Security scan 🔒

- User-controlled input written to `innerHTML`, `outerHTML`, `document.write`, or `eval()`? (XSS)
- Credentials, API keys, tokens in the diff? (secret leak)
- `fetch()` to a URL influenced by user input? (SSRF / open redirect)
- `localStorage` or URL params used without validation?
- New third-party `<script>` tags or external resources?

### Phase Q6 — Performance check ⚡

- DOM query inside a loop or animation frame?
- Unbounded `setInterval`/`rAF` not cancelled on unmount?
- Large array op (`sort`, `filter`, `map`, `reduce`) on every render or keystroke?
- Synchronous `localStorage` on a hot path?
- New image/asset without size constraints (layout shift)?

### Phase Q7 — CSS / layout check 🎨

Skip if no CSS changed.

- Affects other themes? Check `body[data-theme=...]` overrides.
- Breaks mobile? Check `@media` queries.
- `z-index` change that buries or exposes something?
- `position: absolute/fixed` without positioned ancestor?
- `overflow: hidden` clipping a pseudo-element?
- `clip-path`/`filter` creating unexpected stacking context?

### Phase Q8 — Verification pass ✅

**Before reporting anything**, re-read each flagged file:line cold and ask:

- Is the issue real, or was it a misread from context?
- Does the surrounding code handle the edge case elsewhere?
- Is the "regression" actually intentional per the commit message?

Downgrade findings that don't hold up. Drop false positives entirely. Mark confirmed findings as **Verified**.

Then deliver using the report format at the end of this document.

---

## DEEP MODE (parallel agents + worktree sandbox + live render)

Use when: `--deep` flag, or 4+ files changed.

### Phase D1 — Blast radius (main conversation)

Same as Q1. Do this first so you know what to tell the agents.

### Phase D2 — Launch parallel agents

Send ALL of the following in a **single message** so they run concurrently. Do not wait for one before starting the next.

---

#### Agent A — Worktree Sandbox (isolation: "worktree")

Spawn with `subagent_type: "general-purpose"` and `isolation: "worktree"`.

Prompt must include:

- The full `git diff [ref]` output
- The blast radius map from Phase D1
- The project's test command (from CLAUDE.md / package.json)
- Instructions below

**Agent A instructions:**

1. Run the full test suite in the isolated worktree. Report: X pass / Y fail / Z skipped.
2. For each file in the diff, try to execute or exercise the changed code path:
   - If there's a CLI entrypoint, call it with edge-case inputs
   - If there's a test you can write in <10 lines to cover the change, write and run it (temporary — worktree is discarded)
   - If the change is frontend-only, note it and skip execution
3. Check for runtime errors that static analysis misses: unhandled rejections, missing module imports, broken asset paths
4. Report all findings as: `FILE:LINE — runtime finding — severity`
5. Do NOT make changes that persist (worktree is cleaned up automatically)

---

#### Agent B — Live App Render

Spawn with `subagent_type: "general-purpose"` (no isolation needed).

Prompt must include:

- What changed (from the diff)
- Which UI areas are affected (from blast radius)

**Agent B instructions:**

Try to render the app in this order:

**Option 1 — Claude Preview MCP** (preferred):

- Check if `mcp__Claude_Preview__preview_list` is available
- If yes: call `mcp__Claude_Preview__preview_start` with the project root
- Call `mcp__Claude_Preview__preview_screenshot` on the main app URL
- Navigate to any UI area mentioned in the diff and screenshot it
- Call `mcp__Claude_Preview__preview_snapshot` to get the accessibility tree for the changed area
- Report screenshots + any visual anomalies (wrong layout, clipped elements, z-index issues, broken styles)

**Option 2 — Local dev server** (fallback if Preview MCP unavailable):

- Try `npm start`, `npm run dev`, `python -m http.server 8080`, or `npx serve .` — whichever fits the project
- Use `mcp__computer-use__screenshot` after 3s to capture the running app
- Report what you see

**Option 3 — Static file** (fallback if no server):

- If the app is a single HTML file, note it can be opened directly
- Read the relevant CSS/HTML sections and describe expected rendering vs. what the diff changed

Report: screenshot paths or descriptions + any visual regressions found.

---

#### Agent C — Static Analysis

Spawn with `subagent_type: "general-purpose"` (no isolation).

Prompt must include:

- The full `git diff [ref]` output
- The blast radius map
- The CLAUDE.md content if it exists

**Agent C instructions:**

Run Phases Q3 through Q7 (bug hunt, regression, security, perf, CSS) against the diff. Do NOT run tests — Agent A handles execution. Focus entirely on static analysis of the changed code.

Return all findings as: `FILE:LINE — what's wrong — severity: critical/high/medium/low — one-line fix`

---

### Phase D3 — Collect and merge results

Wait for all three agents (A, B, C) to return. Merge their findings into a single deduplicated list. Note the source of each finding (Runtime / Visual / Static).

### Phase D4 — Independent verification pass

Spawn one final agent with `subagent_type: "general-purpose"`. This agent must have **no knowledge of how the findings were generated** — give it only:

- The merged findings list (file:line, description, severity)
- The exact code at each flagged location (read fresh)
- No diff, no blast radius, no context about what changed

**Verification agent instructions:**
For each finding, read only the flagged file:line and 10 lines of surrounding context. Answer:

- **Confirmed** — the issue is real, severity stands
- **Downgrade** — the issue exists but surrounding code mitigates it; suggest lower severity
- **False positive** — the code is correct; explain why

Return the verified findings list only. Drop false positives.

### Phase D5 — Deliver

Use the report format below, with the additional deep-mode fields.

---

## Report format

Output in this exact format:

---

### 🛒 Walmart Ultrareview — `[branch or commit short-sha]` _(Quick | Deep)_

**Tests:** X pass / Y fail _(list new failures)_
**Files reviewed:** N
**Mode:** Quick (sequential) | Deep (parallel agents + sandbox + live render)
**Blast radius:** _(one line per changed file)_

> **Deep mode only:**
> **Sandbox:** _(runtime findings summary from Agent A)_
> **Live render:** _(visual findings summary from Agent B, include screenshot paths if any)_
> **Verification:** _(X of Y static findings confirmed; Z dropped as false positives)_

---

#### 🔴 Critical — ship blockers

_(bugs that will definitely cause failures, data loss, or broken deployments)_

#### 🟠 High — fix before merge

_(regressions, near-certain bugs, security issues)_

#### 🟡 Medium — fix soon

_(edge cases that will bite eventually, minor regressions, perf issues)_

#### 🟢 Low / nits

_(style, optional improvements, things worth knowing)_

#### ✅ Looks good

_(specific things done well — never skip this section)_

---

**Rules for every finding:**

- `FILE:LINE — what's wrong — why it matters — one-line suggested fix`
- Tag source in deep mode: `[Runtime]`, `[Visual]`, `[Static]`, `[Verified]`
- Vague findings ("this could be cleaner") are not allowed
- If uncertain: prefix with `⚠️ Unverified —` and say what to check
- Do NOT rewrite code unless the user asks; describe the fix, let them apply it
- Cap at 20 findings total; if more exist, keep only highest severity
- If zero findings: say so clearly — a clean bill of health is a valid output
