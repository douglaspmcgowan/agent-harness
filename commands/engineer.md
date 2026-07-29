---
name: engineer
description: "Design and stand up a loop + harness for a task — the ultraskill. Researches the best approach, builds the loop (trigger + file structure + tools + verifier) and any harness pieces it needs, then either arms it (auto) or presents the design for Douglas's approval first (pause). Optional toggles pull in harness add-ons: repo scaffolding, a one-command dev script, an e2e gate, a verify-before-ship PR loop, and a local code-graph MCP. Use when Douglas says 'engineer a loop for X', 'set up a loop/harness for X', 'automate X with a loop', '/engineer', or wants a recurring/autonomous agent for a task."
---

# /engineer [task] [--auto | --pause] [+harness-init] [+dev-local] [+e2e] [+pr] [+ci] [+codegraph]

Turn a task into a running (or ready-to-run) loop + harness, and optionally pull in any harness capability via toggles. The reference for all of this is the vault note `Claude/Engineer/ENGINEER.md` (the legible / executable / verifiable model, the loop model, the file structure) and `Claude/Engineer/Loop types — a field catalog.md` (the loop bestiary).

## Arguments
- **`task`** — what should happen autonomously/recurrently. e.g. "keep the AI-tricks gatherer surfacing new cards", "harden a pipeline toward arbitrary inputs", "triage my inbox every morning".
- **mode** — `--auto` (build it and arm it) or `--pause` (build it and present for approval before arming). **Default: pause.** Infer from phrasing if unflagged ("just set it up and go" → auto; "show me first" → pause).
- **toggles** — zero or more `+module` flags (all **default OFF**). They **compose** — combine any set. Each is defined in "Optional toggles" below. A flag scaffolds and arms what it can with tooling present, and **flags what to install** when a dependency is missing — it never claims a capability that isn't there.

## Phase 0 — Frame (1–2 lines)
State the task, the mode, the active toggles, and whether it's work (vs personal) + needs internet (decides GEN vs main per `DELEGATE.md`).

## Phase 1 — Research the approach
Pick the right loop shape before building. Read `Claude/Engineer/Loop types — a field catalog.md`; if the task is novel or you're unsure, run `/recon` (or a quick `/deep-search`) on how others automate this. Choose: the **loop type** (heartbeat / cron / hook / goal / Ralph / plan-execute-verify / reflexion / generator-verifier / map-reduce — see the catalog), the **trigger**, and the **stop-condition**.

## Phase 2 — Design the loop + harness
Specify, concretely:
1. **Trigger** — cron (`/schedule` or a Windows task), a hook, another agent, or manual `/loop`.
2. **File structure** — the artifacts it reads/writes, a `domains/<loop>/README.md` **contract** (Goal · Workflow · Backlog · Timeline), and the project `LOG.md`. Reuse the model in `ENGINEER.md` §4.
3. **Tools/connectors** — which skills/MCPs it needs.
4. **Harness** — what must be legible/executable/verifiable for it to run unattended (per `ENGINEER.md` §2). Build the missing pieces (e.g. a run script) or flag them. **The toggles below are the menu of harness add-ons** — turn on the ones this loop needs.
5. **Verifier** — the independent check (no self-verify, per `VERIFY.md`). Name it.
6. **Stop-condition + bound** — when it halts; max rounds; cost ceiling.

## Phase 3 — Mode gate
- **Pause (default):** write the loop contract + harness files + any toggled modules, do ONE manual test run (the calibration run — run once with the agent, confirm the workflow is right), then PRESENT: the design, the test-run result, and the exact command that would arm it. STOP for Douglas's go.
- **Auto:** build it, run the toggled modules, do the calibration run, then arm the loop (the trigger), and report once. Keep it bounded by the stop-condition.

## Phase 4 — Record
Append a `LOG.md` line; add the loop to its project's `STATUS.md`. If it's recurring, note the trigger in `BACKBURNER.md`/`STATUS.md` so it's discoverable.

---

## Optional toggles (harness add-on modules)

Each is **default OFF**, invoked as a `+flag`, and composes with the others. A module scaffolds what it can with tooling present and **flags what to install** otherwise — it states "scaffolded / flagged" rather than claiming a tool is set up when it isn't.

### `+harness-init` — adapt the base harness into a repo
This **adapts Douglas's current main setup as much as it starts a new one**: a new repo inherits the working norms + main patterns of the base harness, then specializes them. Read the base harness first (`~/.claude/CLAUDE.md`, `VERIFY.md`, the vault `FILE-MODEL.md` + `ENGINEER.md`) and carry the load-bearing parts in. Scaffolds:
- **Behavioral norms** carried over into the repo's `AGENTS.md` golden-rules section: no "X, not Y" antithesis · evidence-before-claims + no self-verify (`VERIFY.md`) · surgical changes · plan-means-plan · the task-state model. Adapt the wording to the repo; keep the rules.
- **Main patterns** seeded from the base harness: the task/backlog/status/worklog files; the artifact file-model (`FILE-MODEL.md` — `signals/` / `tasks/` / `decisions/` + the kind-lint) when the repo will accumulate artifacts; the loop model (`domains/<loop>/` contracts) when it will run loops.
- An **`AGENTS.md`** map kept to a ≤100-line table of contents: overview · project tree · golden rules (the norms above) · a "where to look" table · build/run command · verify command. Push depth into `docs/`, don't inline it. If a `CLAUDE.md` already exists, point `AGENTS.md` at it rather than duplicating.
- The **task files**: `CURRENT-TASK.md` (active) · `BACKBURNER.md` (backlog) · `STATUS.md` (durable) · `LOG.md` (append-only worklog), using Douglas's checkbox markers (`[ ] [~] [x] [!] [?]`).
- A **`docs/`** stub with a `docs/index.md` so deeper documentation has a home.
The intent: a fresh repo behaves like the rest of Douglas's harness from turn one. This module absorbs the would-be `/harness-init` skill — there's no separate skill to call.

### `+dev-local` — one-command dev script
Generate **`scripts/dev-local.sh`** with `up` / `down` / `status` / `logs` subcommands (the "executable" pillar — the agent boots the stack with no thought). First **investigate the repo**: read the package manager (`package.json` / `pyproject.toml` / `Makefile` / `docker-compose.yml`), the services, and the ports actually in use; generate the script from what's there. Make it worktree-friendly (no hardcoded port collisions) where the stack allows. **Never invent secrets** — read required env vars from the existing `.env`/`.env.example` and reference them; if a needed value is absent, the script prints what to set rather than embedding anything.

### `+e2e` — a small Playwright e2e gate
Set up a **Playwright** gate over the 1–3 critical flows that must never break (e.g. a data-export flow, an explorable render). Record **video + trace** on each run as PR proof (the "verifiable" pillar). Lean on the existing **`/playwright-setup`** skill for install + config + base specs rather than re-rolling; this module's job is to pick the critical flows and wire them as the gate. If Playwright isn't installed, it flags the install step.

### `+pr` — the verify-before-ship loop
Wire a PR gate that runs **before** shipping (per `VERIFY.md`, no self-verify):
- A **fresh, read-only verifier sub-agent** drives the running app and returns works/broken + expected/observed/evidence — it does not grade its own work.
- **Objective checks run separately**: type-check, lint, unit/integration tests, the e2e gate above.
- Branch → PR only after the feature is verified by the independent check; a green suite with an unverified feature is unfinished. The verify→fix loop caps at ~3 rounds, then escalates.
Anchors on Douglas's existing `/verification-before-completion` and `/requesting-code-review`.

### `+ci` — scaffold a GitHub Actions CI/CD pipeline
Invoke **`/add-ci`** for the repo: the always-on machine verifier that re-runs the test suite on every push,
the objective counterpart to `+pr`'s in-session human-verifier gate. It detects the stack from the repo's
own manifests, skips a deploy job when a Git-native CD (Vercel) is already linked, and writes a hardened
`.github/workflows/ci.yml` (least-privilege `permissions`, `concurrency` cancel-in-progress, `timeout-minutes`,
current-major actions with built-in caching, `pull_request`-safe triggers) into the repo for review — it
never commits or pushes. Gates hard first: public GitHub Actions is only for personal GitHub repos, never
NASA-internal code (which uses GSFC's own CI). See `/add-ci` for the full procedure and templates.

### `+codegraph` — connect a local code-graph MCP for big repos
**Connect to an existing local-first MCP; don't build one.** These expose a repo's symbol/call/dependency graph over MCP for live "who calls X / what breaks if I change Y" queries, cutting token burn vs reading files one-by-one on a large repo:
- **Serena** (`oraios/serena`) — LSP-based, 40+ languages, one-line `claude mcp add`. The **default pick**.
- **codanna** (`bartolli/codanna`) — small auditable Rust + tree-sitter binary, offline-capable; **Windows support is experimental — test first**.
- **Avoid Graphify** (`safishamsi/graphify`) on sensitive repos: it's a knowledge-graph *snapshot* skill that sends docs + inferred relationships to the Claude API (no offline mode = egress). Fine for a public repo's one-shot diagram; wrong default for a sensitive repo.

**Sensitive-repo gate:** any MCP is third-party code — confirm it runs **fully local with no egress** (run offline / network-monitored) before enabling on a sensitive repo; neither Serena nor codanna publishes an explicit zero-egress guarantee, so verify. This module connects/flags the MCP; it does not claim an index exists until one is built. Detail: `_research/codegraph.md`.

---

## Operating constraints
- Default **pause**; never arm an autonomous loop in auto mode without a stop-condition and an independent verifier.
- Honor `DELEGATE.md`: on this device, heavy build work runs on **GEN** when the task is work (vs personal) **and** needs no internet; internet/personal work stays in the main session. Orchestrate bulk generation on GEN; keep judgment/verification in main.
- No self-verification (`VERIFY.md`). No "X, not Y" antithesis framing. Don't fabricate capabilities — a toggle scaffolds or flags what to install; it never claims a tool is set up when it isn't.
- Calibrate with one manual run before arming (the single most important reliability step).
- Toggles **compose**; only build the modules whose flags are set (each is OFF by default).
- `+codegraph` on a sensitive repo requires the local-only + no-egress vet before it's enabled.

## Output contract
1. Frame + mode + active toggles. 2. Chosen loop type + trigger + stop-condition (Phase 1). 3. The built files (contract, harness pieces, each toggled module) with paths, marking each as built vs flagged-to-install. 4. Calibration-run result. 5. Pause: the arm-command + the ask. Auto: confirmation it's armed. 6. LOG.md/STATUS.md updated.
