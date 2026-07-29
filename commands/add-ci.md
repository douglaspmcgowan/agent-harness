---
name: add-ci
description: "Scaffolds a correct, hardened GitHub Actions CI (and, only where genuinely needed, CD) pipeline onto an existing repo — the safety net that makes a codebase safe to edit freely, because every push re-runs the whole test suite and reports red/green in minutes instead of leaving breakage to surface live. Detects the stack (Python/pytest, Node, static site) from the repo's own manifests, checks whether a Git-native deploy (Vercel) is already linked so it never scaffolds a duplicate deploy job, and writes a `.github/workflows/ci.yml` that covers the staff-engineer hardening surface by default: least-privilege `permissions: contents: read`, `concurrency` with cancel-in-progress, `timeout-minutes`, current-major action versions with built-in dependency caching, `pull_request`-safe triggers, and branch/path filters. Writes the workflow into the target repo for review and never commits or pushes it. Gates hard on repo suitability first — public GitHub Actions is for repos Douglas controls on personal GitHub, never NASA-internal code (which uses local's own CI). Use when Douglas says 'add CI to X', 'set up CI/CD on X', 'scaffold a GitHub Actions pipeline for X', 'wire up continuous integration', 'add-ci', '/add-ci'. Invoked as the `+ci` toggle from /engineer; a natural ship-phase step after /design builds an app; the apply-route when /modernize surfaces a repo that has no CI."
---

# /add-ci [repo] [--ci-only | --with-cd]

Continuous integration is a robot that re-runs your whole test suite on every push and tells you red or
green in minutes. Its real value to a solo developer is not ceremony — it is that you stop being the test
runner. You edit freely, push, and find out immediately if something three files over broke, instead of
discovering it live. This command scaffolds that robot correctly the first time, so the pipeline is a safety
net rather than a new thing to debug. It writes the workflow into the repo for Douglas to read; it never
commits or pushes — arming the pipeline is his call.

## Deviation clause

The staged procedure below is the well-reasoned default, not a straitjacket. When a specific situation
genuinely calls for a different move than these steps prescribe, surface the divergence and the reason to
Douglas for his call, rather than silently complying or silently going your own way.

## What this is NOT

- **Not `/engineer`.** `/engineer` stands up a whole autonomous loop + harness for a task and owns its
  toggle menu (`+dev-local`, `+e2e`, `+pr`, `+codegraph`); CI is one specific capability in that menu.
  `/engineer +ci` invokes THIS command for the CI piece. Run `/add-ci` directly when the only thing wanted
  is a CI/CD pipeline on an existing repo, not a full loop.
- **Not the `+pr` toggle / `/verification-before-completion`.** Those run a fresh verifier sub-agent that
  DRIVES the app before a PR is shipped — an in-session judgment gate. `/add-ci` sets up the objective,
  automated leg (the tests/lint/build a robot re-runs on GitHub after every push). The two are
  complementary: `+pr` is the human-in-the-loop verifier, `/add-ci` is the always-on machine one.
- **Not `superpowers:test-driven-development`.** TDD is how tests get WRITTEN; `/add-ci` assumes tests exist
  and makes GitHub re-run them automatically. It does not author tests — if the repo has none, it says so
  and the pipeline it writes will pass trivially until real tests land.
- **Not `/modernize`.** `/modernize` SURFACES that a repo lacks CI (among other newer-than-the-codebase
  gaps) and stops at the shortlist. `/add-ci` is the apply-route it hands off to once Douglas picks "add
  CI". Surface vs. do.
- **Not `/finishing-a-development-branch`.** That merges/ships a completed branch. `/add-ci` installs the
  standing pipeline that guards every future branch; it runs once, early, not per-merge.

## Procedure

### Step 0 — Resolve the target repo and the intent

Resolve which repo (a path from ARGUMENTS or the conversation; if absent and not obvious, ask which folder
in one line). Read the intent flag: `--ci-only` (default — just run tests/lint/build on push) vs
`--with-cd` (also set up deployment). If unflagged, default to `--ci-only` and note it — CD is the part
most likely to be already handled (Vercel) or to need irreversible-action care, so it is opt-in.

**Completion criterion:** you have an absolute repo path and know whether CD is in scope.

### Step 1 — The suitability gate (mandatory, before generating anything)

Public GitHub Actions is the right CI **only** for repos Douglas controls on personal GitHub. Check, and
stop or redirect if any fails:

1. **Does the repo have a Git remote, and is it a personal GitHub remote?** Run
   `git -C <repo> remote get-url origin`. No remote → GitHub Actions has nothing to run on; say so and stop
   (offer to help him create + link a GitHub repo first, which is his action to take). A non-GitHub remote
   (GitLab, an internal host) → GitHub Actions does not apply; name the platform's own CI instead.
2. **Is this NASA-internal / CUI / ITAR code?** GitHub Actions runs on public GitHub infrastructure. NASA
   code never goes there — local runs its own internal CI (likely GitLab CI). If the remote, the path, or the
   content indicates NASA-internal work, STOP and say plainly that this needs local's internal CI, which is a
   different setup. Do not scaffold a public workflow for internal code.
3. **Are there tests (or a build) worth running?** Glob for `test_*.py` / `*_test.py` / `tests/`, a
   `package.json` with a `test`/`build`/`lint` script, or a buildable static site. If there is genuinely
   nothing to run, a CI file is theater — say so and offer to wire it anyway as a stub that will start
   catching regressions the moment the first test lands (a valid choice, stated as such).

**Completion criterion:** the repo is confirmed a personal GitHub repo with something worth running, OR the
run stopped/redirected with the reason stated. Never generate a workflow past a failed gate.

### Step 2 — Detect the stack and any existing CI/CD

Read the repo's OWN manifests — do not assume:

- **Python** — `requirements.txt` / `pyproject.toml` / `setup.py` present, plus a test runner (`pytest` in
  deps or `test_*.py` files). Note the Python version if pinned (`python-requires`, a `.python-version`).
- **Node** — `package.json`; read its `scripts` for the real `test` / `lint` / `build` names (never invent
  script names — use the ones defined). Note the package manager from the lockfile (`package-lock.json` →
  npm, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn).
- **Already-linked Git-native CD** — check for `vercel.json`, a `.vercel/` dir, or a Netlify config. **A
  Vercel-linked repo auto-deploys on every push with no GitHub Actions needed** — in that case scaffold
  CI ONLY (lint/test/build) and explicitly do NOT generate a deploy job; note that Vercel already owns
  deploy. (Confirmed: Vercel's native Git integration creates preview deploys on branch push and production
  deploys on merge, out of the box — Actions is only needed for data-residency or custom-control cases.)
- **Existing workflows** — if `.github/workflows/*.yml` already exist, READ them; do not clobber. Report
  what's there and either extend it or write a distinctly-named new file, asking which if it's ambiguous.

**Completion criterion:** the stack (python / node / static), the real script/command names, the Python or
Node version, whether a Git-native CD is already linked, and any existing workflow — all determined from the
repo's own files.

### Step 3 — Generate the workflow, covering the hardening surface by default

Write `.github/workflows/ci.yml` (or an agreed name if one exists) using the template for the detected
stack. **Every generated workflow carries the full default hardening** — these are not optional extras:

- `permissions:` block at workflow top set to `contents: read` (escalate per-job only if a job genuinely
  needs more — the default `GITHUB_TOKEN` is otherwise broad, and a compromised dependency inherits it).
- `concurrency:` with `group: ${{ github.workflow }}-${{ github.ref }}` and `cancel-in-progress: true` for
  the CI/test workflow, so a new push kills the superseded run. **Never** set `cancel-in-progress: true` on
  a deploy/release job — those serialize (`false`).
- `timeout-minutes` at job level (default 15 for a small repo) so a hung job can't burn to the 6-hour ceiling.
- Triggers: `push` to the main branch + `pull_request` (default `pull_request`, **never**
  `pull_request_target` — that runs with base-repo secrets even for fork code, the "pwn request" hole). Add
  `paths-ignore` for pure-docs paths so doc-only changes don't spin up full CI.
- Current-major action versions with BUILT-IN dependency caching (see the version note below).

**Action versions (as-researched, 2026-07):** `actions/checkout@v7`, `actions/setup-python@v6`,
`actions/setup-node@v6`, `actions/cache@v5`, `actions/upload-artifact@v7`. These majors move faster than
most — **when web access is available (this is a public topic, tools work), verify the current major against
each action's live releases page before writing**, and always add a `.github/dependabot.yml` (or note it)
for the GitHub Actions ecosystem so pins auto-update. For a solo personal repo, major-tag pinning + Dependabot
is the reasonable default; offer SHA-pinning (immune to a tag being rewritten, the tj-actions/changed-files
2025 incident) as the harder-line option if Douglas wants it, rather than silently picking one.

**Python template** (adapt versions/commands to what Step 2 found):
```yaml
name: CI
on:
  push:
    branches: [main]
    paths-ignore: ['**.md', 'docs/**']
  pull_request:
permissions:
  contents: read
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v6
        with:
          python-version: '3.13'   # match the repo's pin
          cache: 'pip'             # built-in; do NOT hand-roll actions/cache for the standard case
      - run: pip install -r requirements.txt
      - run: pytest
```

**Node template** (use the repo's REAL script names + package manager from Step 2):
```yaml
name: CI
on:
  push:
    branches: [main]
    paths-ignore: ['**.md', 'docs/**']
  pull_request:
permissions:
  contents: read
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v6
        with:
          node-version: '22'   # match the repo / .nvmrc
          cache: 'npm'          # or 'pnpm' / 'yarn' per the lockfile
      - run: npm ci
      - run: npm run lint --if-present
      - run: npm run build --if-present
      - run: npm test --if-present
```

**CD (only under `--with-cd`, and only when NOT Vercel-linked):** add a deploy job that `needs: [test]` (or
`build`) so deploy never runs on red, and — for any irreversible target — wrap it in a GitHub `environment:`
with required reviewers, so the run pauses for a human approval before deploying. Surface the plan-tier
caveat: required-reviewer environments are public-repo-only on Free/Pro; a private repo needs an
issue-based approval action instead. If the repo is Vercel-linked, there is no deploy job — say so.

**Completion criterion:** `ci.yml` exists in the repo with every default-hardening item present (or an item
explicitly scoped-out with a reason), stack-correct commands, and a Dependabot pin-updater written or
recommended — and no `.md`-only path triggers full CI.

### Step 4 — Verify the workflow, and stop before pushing

- **Validate the YAML.** If `actionlint` is available, run it; otherwise parse the YAML to confirm it's
  structurally valid (case-sensitive keys like `branches:` vs `branch:` parse as valid YAML but silently
  no-op — check them). State which check ran.
- **Read it back against the rubric** — confirm each hardening item is actually present in the written file,
  not just intended.
- **Do NOT commit or push.** Show Douglas the written file and explain, in plain language, exactly what will
  happen the first time HE pushes it: which events trigger it, what it runs, roughly how long, and that the
  first run may surface environment gaps (a test that passes locally but needs a system dep the runner
  lacks) — normal, and the point of running it. Arming the pipeline (the push) is his action.

**Completion criterion:** the YAML validated, every rubric item verified present in the actual file, and the
push explicitly left to Douglas with a plain-language account of what it will do.

### Step 5 — Report

- The repo, the detected stack, and the suitability-gate result.
- The exact file(s) written (full absolute path), and whether a deploy job was included or deliberately
  omitted (Vercel-linked / `--ci-only`).
- The **rubric coverage** — each hardening item present or scoped-out with a reason — so the report proves
  the pipeline is hardened, not just that a file exists.
- Any version that a live check would confirm but couldn't be verified this pass, named plainly.
- The exact command Douglas runs to arm it (`git add .github && git commit && git push`, in his shell's
  syntax), stated as his action — never claim the pipeline is "live" or "passing" before he has pushed and a
  run has gone green.

## Safety constraints

- **Writes only into the target repo's `.github/`, and never commits or pushes.** The workflow file is the
  deliverable; arming it (the push) is always Douglas's action. No `git commit`, no `git push`, no branch
  creation unless he separately asks.
- **Never clobber an existing workflow.** If `.github/workflows/` already has files, read them and extend or
  write a distinctly-named file; ask if ambiguous. Back up before overwriting only on his explicit go.
- **Never embed secrets.** Reference `secrets.*` and GitHub Environments; never write a token/key into the
  YAML, and never emit a step that echoes a secret to the log. Fork PRs don't receive secrets by design —
  don't write a workflow that assumes they will.
- **The NASA gate is load-bearing.** Public GitHub Actions is never scaffolded for NASA-internal / CUI /
  ITAR code (Step 1). That code uses local's own internal CI — a different, out-of-scope setup.
- **No elevated/bypass permissions.** If a safety layer blocks an action mid-run, that's a correct block —
  narrow scope, don't route around it.

## Notes on scope (authoring_checklist)

Satisfies the authoring rules: front-loaded description leading with the core capability (scaffold correct,
hardened CI/CD onto an existing repo) with triggers collapsed to one phrase per branch and the cross-skill
reach (`/engineer +ci`, `/design` ship-phase, `/modernize` apply-route) named; user-facing slash command
keeping model triggers deliberately so it's reachable by name and by intent and by the `+ci` toggle; each
step ends on a checkable completion criterion; the hardening surface stated once in Step 3 as the single
source of truth; safety of the produced artifact designed in (the workflow's own least-privilege /
concurrency / trigger-safety hardening, separate from the write-into-repo safety); a deviation clause once
near the top. Deliberate exception: NO embedded multi-agent Workflow script — like `/onboard` and
`/modernize`, this is a single coherent detect-then-write pass with no independent parts to fan out, so a
Workflow would add ceremony without parallelism. Self-contained single-file skill by design (Douglas's
family convention). The action-version list is a v1 default anchored to the 2026-07 research pass; fold any
version drift or new hardening lesson found in real use back into the templates and the rubric.

---

*Tracked copy: also save this file to `claude-global-config/commands/add-ci.md` (per the skills-are-tracked
convention) after a NASA scrub.*
