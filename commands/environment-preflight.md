---
name: environment-preflight
description: Run a disposable preflight audit for the current project or a specified target folder before setup, debugging, build, or deploy work. Use when you want a cheap first pass that catches tooling, auth, config, and repo-shape problems before they pollute a longer session. Also use when the user says "deploy to Vercel", "ship this", "go from local to production", or "local HTML to Vercel" — in that case run Phase 1 then proceed to Phase 2 (ship workflow).
disable-model-invocation: true
---

# Environment Preflight + Ship

Two modes:

- **Check mode** (default): run the diagnostic, write `preflight_report.md`, stop.
- **Ship mode**: triggered by "deploy to Vercel", "ship this", "go to production", "local HTML to Vercel." Run Phase 1 first; if no FAIL blockers, continue to Phase 2.

Default target:
- If `$ARGUMENTS` is empty, use the current working directory.
- If `$ARGUMENTS` is present, resolve it as a target folder.

---

## Phase 1 — Diagnostic (both modes)

Operating rules:
- Run cheap, disposable checks first.
- Do not expose secrets — presence checks only.
- Record `SKIP` or `UNKNOWN` instead of faking a pass when a check can't run.
- If a repo has both `AGENTS.md` and `CLAUDE.md`, flag drift.

Write `preflight_report.md` at the target root with these sections.

**Report codes:** `PASS` · `WARN` · `FAIL` · `SKIP`

### 1a. Repo identity
- Current path
- Is it a git repo? Branch + dirty-state summary if yes
- Entrypoints present: `package.json`, `pyproject.toml`, `index.html`, `vercel.json`, `server.js`, `.claude/launch.json`

### 1b. Instruction & context files
- `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`
- `.claude/settings.json`, `.claude/settings.local.json`
- `STATUS.md`
- Flag overlapping context files that should be consolidated

### 1c. Tooling
- `git`, `node` (need ≥ 18), `npm`, `gh`, `vercel`, `ffmpeg`, `yt-dlp`
- Any tool clearly required by project files or docs

### 1d. Auth & integrations
- `gh auth status` — flag if not logged in
- `vercel whoami` — flag if not logged in
- Never print tokens

### 1e. Runtime/project
- Identify the likely dev command from project files
- Note any missing generated folders or expected assets
- Flag any obviously occupied ports if the project names them

### 1f. Token-waste flags
- Setup/debug that belongs in a fresh session
- Bulky repo instructions that belong in skills
- Folder scans that should be replaced with a manifest

**Next-step recommendation** (one line):
`Start fresh build session` / `Fix tooling first` / `Auth blocker` / `Ready for implementation` / `Ready to ship`

**Stop here in check mode.** In ship mode: if there are no FAIL entries, proceed to Phase 2.
If there are FAIL entries, list them and stop — fix tooling before shipping.

---

## Phase 2 — Ship (static HTML → GitHub → Vercel)

This phase automates everything learned from the dpm-agent-kit deploy session (2026-06-10).
Run each step in order. Stop and report if any step fails.

### 2a. Secret scrub

Before any git operation:

```bash
git grep -iE "your-name|your-email|your-org|your-private-path|api[_-]?key|secret|password|token" -- . 2>/dev/null
```

Adapt the pattern to the project — replace with actual real values you need to catch.
Also check for `.env` files, `*credential*`, `*secret*`, `AI Reference.md` (never commit this).

If any real secrets found: **STOP**. Tell the user what was found and where. Do not proceed.

### 2b. Contract files — create if missing

**`.gitignore`** — check for node_modules, .env, .vercel, OS junk. Create if absent:
```
.DS_Store
Thumbs.db
.vscode/
node_modules/
.env
.vercel
```

**`LICENSE`** — if absent, create MIT at the repo root:
```
MIT License
Copyright (c) <YEAR> <PROJECT> contributors
[standard MIT body]
```

**`vercel.json`** — for a pure-static site with content under a subdirectory, create a root redirect so `/` lands at the right place:
```json
{ "redirects": [{ "source": "/", "destination": "/<subdir>/", "permanent": false }] }
```
If the HTML is at root, skip the redirect.

### 2c. OG / social meta tags

Check the main HTML file (the one Vercel will serve at `/`) for `og:title`, `og:description`, `og:image`, `twitter:card`.
If absent, add inside `<head>`. Use the live Vercel URL for `og:url` and `og:image` (the image URL can be a screenshot you'll commit in 2d):

```html
<meta name="description" content="…">
<meta property="og:type" content="website">
<meta property="og:url" content="https://<project>.vercel.app/">
<meta property="og:title" content="…">
<meta property="og:description" content="…">
<meta property="og:image" content="https://<project>.vercel.app/<path>/preview.png">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="…">
<meta name="twitter:description" content="…">
<meta name="twitter:image" content="https://<project>.vercel.app/<path>/preview.png">
```

### 2d. Headless contrast audit

Run a Playwright headless pass across all HTML pages in both theme variants (if a theme toggle exists).
Use a `.cjs` script via `require('playwright')` — NOT `import`. Playwright lives in the npx cache:

```bash
# Find the cache dir that has playwright
for d in C:/Users/$USER/AppData/Local/npm-cache/_npx/*/node_modules/playwright; do
  [ -d "$d" ] && echo "$d" && break
done
```

Audit: walk visible text nodes, compute contrast ratio vs effective background.
Flag any element with ratio < 4.5 (AA normal text) or < 3.0 (AA large/bold).

**Known gotcha:** hardcoded hex body colors (`#aeb6df`, `#a9b1d6`) read fine on dark themes but fail on white.
Fix: add a `--body` CSS custom property to `:root` and `[data-theme="light"]`/`[data-theme="brutalist"]` blocks; use `var(--body)` in place of hardcoded values.

**Known gotcha:** dark-interior containers (terminal windows, sidebars) in a light theme inherit light-theme dark text.
Fix: re-scope the CSS variable block on the dark container so descendants get light-on-dark colors:
```css
[data-theme="light"] .dark-container { --text: #e8e8e8; --muted: #9aa0b5; }
```

Do not proceed if contrast audit has failures.

### 2e. README screenshot

Take a Playwright headless screenshot of the main page (1440×900, not full-page):
```js
const pg = await b.newPage({ viewport: { width: 1440, height: 900 } });
await pg.goto('file:///path/to/index.html'); // or live URL if available
await sleep(1500); // wait for web fonts
await pg.screenshot({ path: 'preview.png', fullPage: false });
```

Save as `preview.png` next to the main HTML. Reference it from the README:
```markdown
![preview](path/to/preview.png)
```

Also add badges to the README top:
```markdown
[![Live demo](https://img.shields.io/badge/live%20demo-…)](https://….vercel.app)
[![License: MIT](https://img.shields.io/badge/license-MIT-…)](LICENSE)
```

### 2f. Git — init, commit, push

```bash
git init                                    # skip if already a repo
git add <specific files>                    # prefer explicit over git add -A
git commit -m "Initial commit: <project>"  # gitleaks hook will scan
git push                                    # if remote already exists
```

Or create a new GitHub repo and push in one command:
```bash
gh repo create <name> --public --source=. --remote=origin --push \
  --description "…"
```

After pushing, set the GitHub homepage to the Vercel URL:
```bash
gh repo edit --homepage "https://<name>.vercel.app"
```

### 2g. Deploy to Vercel

```bash
vercel --prod --yes
```

Then verify GitHub auto-deploy is wired (so future pushes redeploy automatically):
```bash
vercel git connect
# should print: "<owner>/<repo> is already connected to your project"
# if not connected, it will connect it now
```

### 2h. Live verification

After deploy, confirm the site is publicly reachable and key interactions work.

**Curl checks:**
```bash
curl -sS -o /dev/null -w "%{http_code}" https://<name>.vercel.app/
# expect 307 (redirect) or 200 (direct)

curl -sS -o /dev/null -w "%{http_code}" https://<name>.vercel.app/<main-path>/
# expect 200
```

**Playwright live test** — check title, no JS errors, key page interactions:
```js
pg.on('pageerror', e => errs.push(e.message));
pg.on('console', m => { if (m.type()==='error') errs.push(m.text()); });
await pg.goto('https://<name>.vercel.app/');
await sleep(1200);
// assert title, key elements present, no errors
```

**No auth wall:** confirm the response body doesn't contain "Vercel login" or similar.

### 2i. Post-deploy — update repo map

Add a row to your `repo-map.md` (wherever it lives):
```
| <nickname> | <local path> | <owner>/<repo> | public; deploys to <name>.vercel.app |
```

### 2j. Report

Write a `ship_report.md` or append to `preflight_report.md`:
```
SHIPPED: https://<name>.vercel.app
GitHub:  https://github.com/<owner>/<repo>
Auto-deploy: confirmed (push to main → redeploy)
OG image: <url>/preview.png
Contrast: 0 failures across N pages × M themes
Secrets:  clean (gitleaks + manual grep)
```

---

## Common errors

| Error | Cause | Fix |
|---|---|---|
| `Cannot find module 'playwright'` | Playwright not in NODE_PATH | Set `NODE_PATH` to the npx cache dir containing playwright: `C:/Users/<user>/AppData/Local/npm-cache/_npx/<hash>/node_modules` |
| Playwright can't load `file://` with spaces | Path encoding | URL-encode spaces as `%20`: `file:///C:/Users/foo/My%20Project/index.html` |
| Contrast audit false-positive: green on green alpha | Auditor treats translucent bg as opaque | Check visually; skip if effective bg is dark and text is light |
| `vercel.json` redirect sends loop | Redirect target and source match | Set `destination` to `/explorable/` (trailing slash) and `source` to `/` only |
| `vercel git connect` says "already connected" but pushes don't redeploy | GitHub App not authorized in Vercel dashboard | Go to vercel.com → project → Settings → Git and click "Authorize" |
| Dark-theme hex color fails contrast on light theme | Hardcoded hex instead of CSS token | Add `--body` token to the light-theme block; replace hex with `var(--body)` |
| Brand text invisible on dark sidebar in light theme | `color` inherits from `body` not from re-scoped variable | Add `color: var(--text)` directly to the container rule, not just its children |

---

## Quality bar

- The secret scrub is mandatory before any git operation. No exceptions.
- The contrast audit is mandatory before shipping a themed site. Visual claims without an audit are unverified.
- Live verification is mandatory — a deploy that passes `vercel --prod` can still fail for CORS, auth-wall, or missing asset reasons that only show up on the live URL.
- Do not claim "shipped and working" without a passing live verification.
