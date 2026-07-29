---
name: connect
description: "Orchestrator that gives an app its connective surfaces. Looks at the WHOLE scope of an app, enumerates who and what will consume it, and decides via a mandatory surface-matrix GATE which of a CLI (/make-cli), an MCP server (/make-mcp), and/or an HTTP API (/make-api) it actually needs -- possibly several, possibly one, possibly none (a library import is a valid answer) -- refusing to build a surface no consumer needs, and applying the shell-bearing-agent rule (a good CLI with --json often serves Claude Code at near-zero context cost; MCP reserved for OAuth/per-user auth, stateful sessions, or shell-less hosts). Then it builds each needed surface by delegating to the matching make-* skill (each self-isolates and self-tests), recommends a right-sized data layer matched to the app's data shape (sqlite vs Postgres vs Redis vs a vector store vs none), and produces an integration map: exactly where to wire the app into the computer (PATH, launchers, config dirs, env), the system (service/daemon, port, autostart), and the harness (claude mcp add, a slash command, settings.json/hooks via /update-config, Claude Desktop). Recommends system/computer wiring rather than performing it; only the harness registration the sub-skills do actually writes. Reports what was built + verified this pass and what's recommended-but-Douglas's-call. Use when Douglas says 'connect this app', 'wire this up', 'what surfaces does this app need', 'hook this into my system/harness', 'how do I connect X to the rest of my setup', '/connect'."
---

# /connect [app] [--surfaces cli,mcp,api] [--plan]

An app is only as useful as the ways things can reach it. The same underlying code wants a different connective
surface for each consumer — a human at a terminal wants a CLI, an AI host wants an MCP server, a remote or
heterogeneous program wants an HTTP API, and same-process code wants nothing but an import. This command looks
at the app's whole scope, decides which of those surfaces it genuinely needs (and just as importantly, which it
does not), builds the needed ones by delegating to the specialist skills, recommends a right-sized place to
keep its data, and hands back a concrete map of where to wire it into the machine, the system, and the harness —
distinguishing what it built and verified this pass from what it recommends but leaves for Douglas to execute.

**Deviate out loud.** This staged process is the well-reasoned default. When you genuinely judge that a
specific situation calls for a different move than this command prescribes, surface the divergence and your
reasoning to Douglas and let him decide, instead of silently complying or silently going your own way.

## What this is NOT

- **Not `/make-cli`, `/make-mcp`, or `/make-api` individually.** Those each build ONE surface once the decision
  to build it has been made. This command sits above them: it *decides* which of the three an app needs (zero,
  one, or several) and *calls* them. If Douglas already knows he wants exactly a CLI (or exactly an MCP server,
  or exactly an API), skip the matrix and go straight to that skill — reach for `/connect` when the question is
  *which* surfaces, not *how* to build a known one.
- **Not `/package`.** `/package` makes an existing system portable — a self-contained repo he can clone and run
  on another machine. This command adds connective surfaces onto a system and wires it into *this* environment.
  Portability out; connectivity in. Different job.
- **Not `/update-config`.** `/update-config` edits `settings.json`/`settings.local.json` — permissions, env
  vars, hooks — the harness's automated behavior. This command *recommends* those harness edits as part of the
  integration map and points the actual settings/permission/hook writes at `/update-config`; it does not edit
  settings itself.
- **Not `/engineer` or the generic Superpowers implementation skills.** Those implement arbitrary features.
  This is surface-and-wiring orchestration specifically — the surface matrix, the data-layer sizing table, the
  computer/system/harness integration map — carrying knowledge those general skills do not.
- **Not `/spar`, `/hone`, or `/probe`.** Those harden, measure, or attack existing targets. This creates and
  wires surfaces; each newly built surface is exactly the kind of thing to `/spar` afterward, and this command
  says so rather than claiming the wired-up app is already hardened.

## Procedure

### Step 0 — Resolve APP from ARGUMENTS

Needs enough that the surface decision can be made without guessing. Establish four things and ask only what
isn't already obvious from the conversation:

- **What the app does** — the core capability being exposed, and roughly which operations are read-only vs
  mutating.
- **Who and what will consume it** — humans at a terminal, an AI host (Claude Desktop/Code), a first-party
  frontend, third-party developers, other internal services, same-process code, a scheduler/cron. This is the
  single most load-bearing input; the matrix is built directly from it.
- **Its data shape** — does it hold state at all, and if so: single-user or concurrent, relational or
  key-value, transient or durable, blobs, embeddings/semantic search. This sizes the data-layer recommendation.
- **Where it runs** — this laptop, a server, an edge/serverless target, air-gapped. This shapes the wiring map.
- **How consumers authenticate** — nothing/local trust, a pre-configured API key or env var, or OAuth/per-user
  tokens. This axis breaks CLI-vs-MCP ties: with a pre-configured key, a CLI hitting the same backend is
  functionally equivalent to an MCP server; OAuth flows, per-user tokens, and audit trails are what justify the
  heavier surface.

If ARGUMENTS lacks what's needed and it isn't obvious from the conversation, ask who the consumers are and
whether the app holds state before proceeding — the whole decision hangs on the consumer list. Parse
`--surfaces cli,mcp,api` (an explicit override of the matrix) and `--plan` (recommend only; build nothing —
same as plan-mode) if given.

### Step 1 — GATE: the surface matrix (mandatory, load-bearing, before building anything)

This is the decision the whole command exists to make, and it mirrors the classification gates in `/make-cli`,
`/hone`, and `/probe`: decide before spending the build. Enumerate every consumer from Step 0 and map each to
the surface that fits it:

| Consumer | Right surface |
|---|---|
| A human running commands in a terminal, or a shell script | **CLI** (`/make-cli`) |
| An AI host — Claude Desktop, Claude Code — where the model invokes tools | **MCP server** (`/make-mcp`) — subject to rule 4 below |
| A remote client, multiple heterogeneous clients, or a cross-language caller over the network | **HTTP API** (`/make-api`) |
| A human using a **browser / GUI** frontend | The **HTTP API** the frontend calls — building the frontend itself is out of scope (`impeccable` / `/design`) |
| Same-process / same-language code in the same repo | **A library import — no surface at all** |
| A scheduler/cron on this machine | Usually the **CLI** (a scheduled command), not a new surface |

Then collapse to the set of surfaces actually needed. Four rules:

1. **A surface with no consumer does not get built.** This is the ponytail rung and the whole point of the
   gate — do not add an MCP server "in case an agent wants it later" or an API "for future remote clients" when
   no such consumer exists today. Speculative surfaces are the most common form of connective over-building.
2. **Zero surfaces is a valid, honest answer.** If every real consumer is same-process code, the finding IS the
   answer: *"this needs a library import, not a CLI/MCP/API — here's the data layer and the import point"* —
   report that (plus the Step 3 data recommendation) and STOP. Do not manufacture a surface to look useful.
3. **Several surfaces is common and fine** when the consumer list genuinely spans terminals, agents, and remote
   clients — build each needed one; they compose (a shared core the CLI, MCP tools, and API handlers all call).
4. **A shell-bearing AI host may already be served by the CLI.** Claude Code (and any agent with a Bash tool)
   drives a good CLI with `--json` output at near-zero context cost, and practitioners consistently measure
   CLIs beating equivalent MCP servers on tokens and speed (Ronacher's `gh`-vs-GitHub-MCP test is the canonical
   example — the MCP burns tens of thousands of schema tokens before the first call). "The consumer is an AI
   host" alone no longer auto-justifies MCP. Build the MCP server when something the CLI genuinely can't do is
   in play: OAuth/per-user token flows, long-lived stateful sessions or subscriptions, or a shell-less host
   (Claude Desktop, remote MCP clients). If a CLI is already NEEDED for other consumers, default the
   shell-bearing agent onto it and record the ruled-out MCP in `not_needed` with this reason. And when the
   shell-bearing agent needs multi-step *procedural guidance* to drive that CLI well (non-obvious sequencing,
   a workflow it can't infer from `--help`), the highest-leverage artifact is often a **Skill** teaching it to
   drive the CLI — a Skill loads no tool definition (the agent's tools stay bash and the CLI itself), so it
   carries the workflow at near-zero standing context cost where an MCP would pay the schema tax every session
   (Ronacher, *Skills vs MCP*, Dec 2025; Anthropic's Skills guidance: MCP is for data access, a Skill teaches a
   procedure). The Skill rides on top of the CLI, so it belongs in the Step-4 harness map as a wiring
   recommendation — `/connect` builds CLI/MCP/API and recommends the Skill layered on top.

Output the NEEDED set AND the explicitly-NOT-needed surfaces with the reason each was ruled out — the negative
space is as much the deliverable as the positive. An explicit `--surfaces` list wins over the matrix, but if it
asks for a surface with no consumer, flag the mismatch and get Douglas's call before building it rather than
silently building a surface nobody uses.

### Step 2 — Build each needed surface (delegate; don't reimplement)

For every surface the matrix marked NEEDED, invoke the matching specialist skill with the resolved app as the
target — **let each one run its own gate, its own isolated-worktree build, and its own live test**; do not
re-implement their logic here:

- CLI needed → **`/make-cli`** (it classifies deterministic-vs-agentic, picks the framework, scaffolds against
  the clig.dev checklist, tests, self-isolates).
- MCP needed → **`/make-mcp`** (it picks tool/resource/prompt per thing, scaffolds Python/TS, tests live with
  the Inspector, self-isolates, and registers with `claude mcp add`).
- API needed → **`/make-api`** (it designs the wire contract, picks the framework, scaffolds, live-tests real
  HTTP calls against the OpenAPI/SDL spec, self-isolates).

Each sub-skill's own gate can still fire "install-instead" / "doesn't-need-this" and short-circuit — honor that;
a fired sub-gate correctly removes a surface from the built set. When several surfaces are needed, note the
**shared core** they should all call (the app's existing library functions) so the CLI, the MCP tools, and the
API handlers stay thin adapters over one implementation rather than three divergent copies.

**Build in order when several are needed:** shared core first (usually it already exists as the app's library),
then the CLI and/or API over it, the MCP server LAST — a thin wrapper over a surface that already works and is
already tested, per the practitioner ship-order (the MCP layer is cheapest when it wraps a proven one). When
invoking `/make-mcp`, pass the tool-consolidation directive down: consolidate related operations into a FEW
high-level, namespaced workflow tools (Anthropic's tool-writing guidance — fewer, more capable tools cut the
agent's selection ambiguity and context cost); a 1:1 wrap of every operation or CLI subcommand fails that bar.
Pass down the destructive-operation signal too — this is the one place Step 0's read-only-vs-mutating axis is
consumed: any tool wrapping a mutating or irreversible operation must be annotated as such and gated behind a
human-in-the-loop checkpoint enforced in the server's own code, never by tool-description prose alone. That
prose is reviewed once at connect time, but tool *invocations* land in the model's context unchecked at
runtime — the connect-time-vs-runtime trust gap that OWASP names as the root of MCP tool-poisoning, where an
injected instruction drives a legitimate destructive tool with no re-review.

### Step 3 — Recommend a right-sized data layer (don't over-provision, don't provision at all)

Match persistence to the data shape from Step 0 — the ponytail ladder applies to storage as hard as to code:

| Data shape | Recommendation |
|---|---|
| No state / stateless request-response | **None** — say so explicitly |
| Single-user, local, embedded, low-concurrency | **SQLite** (a file; zero ops surface) |
| Concurrent writers, relational, multi-client, durable | **PostgreSQL** |
| Cache, queue, rate-limit counters, ephemeral/expiring | **Redis** (alongside the primary store, not instead of it) |
| Embeddings / semantic search | A **vector store** — `sqlite-vec`/`pgvector` (piggyback the primary DB) before a standalone vector service |
| Large blobs / files | An **object store** (local dir → S3-class) — keep blobs out of the row store |

Do not reach for Postgres for a single-user local tool, or a standalone vector database when `pgvector`/
`sqlite-vec` rides the DB the app already has. **Recommend the data layer; do not provision it** — creating real
databases, cloud resources, or persistent services is Douglas's call (and outside this command's safe scope).
State the recommendation, the one-line reason, and the cheapest thing that satisfies it.

### Step 4 — Produce the integration map (computer / system / harness)

For each built surface, and for the data layer, give a concrete map of where it wires into the environment.
Every entry is tagged **DONE** (the sub-skills actually did it this pass — essentially only harness
registration) or **RECOMMENDED** (Douglas's call to execute):

- **Computer** — where a human/script reaches it on this machine: a `PATH` entry or a shell-profile alias for a
  CLI; the config directory (XDG on POSIX, `%APPDATA%` on Windows) for its settings; env vars it reads; a
  launcher for scheduled/background runs (**Windows Task Scheduler** here, `launchd`/systemd-user elsewhere).
- **System** — for a long-running API/service: the port, whether it runs as a service/daemon and how it
  autostarts, a reverse proxy if it needs one, and where its logs go. (For this laptop, keep it loopback and
  local unless Douglas asks for exposure — never recommend binding a fresh unhardened service to a public
  interface.)
- **Harness** — how Claude reaches it: `claude mcp add <name>` for an MCP surface (the sub-skill does this;
  report the scope, default local); whether the app should also become a **slash command** in
  `~/.claude/commands/` (and its `claude-global-config` tracked mirror); for a shell-bearing-agent consumer
  served by the CLI, whether to author a **Skill** (in `~/.claude/skills/` or `~/.claude/commands/`) that
  teaches the agent to drive that CLI through the app's multi-step workflow — recommended over an MCP wrapper
  when the need is procedural guidance rather than a new tool, since a Skill loads no tool schema and so adds no
  standing context cost; any `settings.json` permission/hook
  wiring, handed to **`/update-config`**; and a Claude Desktop `mcpServers` entry if that's a consumer. When the
  MCP surface exposes MANY tools, or the app is joining a harness that already runs several heavy MCP servers,
  note the context cost and recommend on-demand consumption — progressive tool disclosure (load a tool's schema
  only when it is used) or routing calls through a code-executor — over loading every tool schema upfront;
  roughly 3+ heavy servers can burn tens of thousands of tokens before the first turn. This is a recommendation
  about how the harness *consumes* the surface, so it stays RECOMMENDED (Douglas's call), never auto-applied.

Give the specific path/command for each recommendation (the `PATH` edit, the Task Scheduler command, the
`claude mcp add` line, the `/update-config` ask) so Douglas can execute it directly — a map he has to
reconstruct is not a map. Manual commands he runs himself go in **his shell's syntax** (PowerShell/cmd on this
machine), not Bash.

### Step 5 — Verify and report

Assemble the results the sub-skills reported (each already adversarially verified its own surface), plus the
data + wiring recommendations, into one integration map. When two or more surfaces were built over one shared
core, run ONE identical operation through each (the CLI invocation, the MCP `tools/call`, the HTTP request) and
compare the results — the parity check turns the thin-adapter claim into an observation; divergent outputs mean
a surface grew its own logic and that goes in the report as a finding. Report per "Final report" below. Point at **`/spar`**
against each newly built surface for the adversarial hardening pass — a freshly wired CLI/MCP/API is exactly its
kind of target — and note that anything tagged RECOMMENDED (PATH edits, service registration, data-layer
provisioning) is unexecuted and awaits Douglas's go.

## Procedure (how to run it)

1. Resolve APP per Step 0.
2. **Run the Step-1 surface-matrix GATE FIRST** — it is a cheap judgment that decides everything downstream. If
   it collapses to zero surfaces, report the library-import + data-layer finding and STOP (do not build a
   surface nobody consumes). If `--plan` was passed, produce the full matrix + data + wiring recommendation and
   STOP without building.
3. Otherwise **call the `Workflow` tool** with the script below verbatim, passing
   `args: { app: "<what it does + consumers + data shape + where it runs>", surfacesOverride: "<cli,mcp,api or empty>" }`.
   This is an explicit skill-triggered Workflow use — no separate opt-in. Both phases run on **`model: 'opus'`**
   (the surface matrix and the data/wiring plan are the load-bearing judgments this command exists for). The
   Workflow produces the decision + the recommendation map; it does **not** build the surfaces itself.
4. **For each surface the returned matrix marks NEEDED, invoke the matching skill** (`/make-cli`, `/make-mcp`,
   `/make-api`) with the resolved app as the target, in Step-2 build order (shared core → CLI/API → MCP last).
   Each self-isolates and self-tests; let it. Collect what each built and verified.
5. **Assemble and report** the integration map per "Final report" below — what was built + verified, the
   data-layer recommendation, and the computer/system/harness wiring tagged DONE vs RECOMMENDED. Never claim the
   app is "fully connected" or "production-ready"; report what this pass built and verified and what remains for
   Douglas to execute.

## Safety constraints (apply every run, no exceptions)

- **Never run with elevated/bypass permissions.** A generic "connect this" ask does not justify disabling the
  permission system. If a safety layer blocks an action mid-run, that is a correct block — narrow scope, don't
  route around it.
- **`/connect` writes nothing to the target itself.** All actual building is delegated to `/make-cli` /
  `/make-mcp` / `/make-api`, each of which isolates its scaffold in a throwaway git worktree and self-tests per
  its own safety constraints. This command's own output is a decision and a recommendation map — it does not
  scaffold, edit, or serve the target directly.
- **Recommend computer/system wiring; do not execute it.** `PATH` edits, shell-profile changes, service/daemon
  registration, autostart entries, reverse proxies, and data-layer provisioning are Douglas's call — several are
  "explicit-permission-required" or "prohibited-without-the-user" actions (modifying system settings, standing
  configuration). Present each as a concrete, copy-pasteable RECOMMENDED step in his shell's syntax; never
  perform it as part of this run.
- **The only writes are harness registration the sub-skills perform** — chiefly `/make-mcp`'s `claude mcp add`,
  defaulting to **local** scope. Surface every such write explicitly (name, scope, file touched); a
  `--scope project`/`user` write is a change Douglas should see. Hand any `settings.json`/hook edits to
  `/update-config` rather than editing settings here.
- **Do not provision real data stores or cloud resources.** Recommend the data layer (Step 3); creating a real
  database, bucket, or persistent service is out of scope and Douglas's decision.
- **Never bind a freshly built, unhardened service to a public interface** in any recommendation for this
  machine — loopback + local by default; recommend exposure only if Douglas explicitly asks, and flag the
  hardening gap when he does.
- **Stay strictly scoped to the app.** Decide, delegate, and recommend for the target app only; no touching
  unrelated processes, services, or shared state; no destructive or irreversible action on anything shared. No
  `git commit`/`push` unless Douglas separately asks.
- **If the app keeps a tracked mirror elsewhere in this repo's convention** (e.g. this harness's `~/.claude` ↔
  `claude-global-config` split), note it and leave the mirror sync to Douglas.

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'connect',
  description: 'Decide an app\'s connective surfaces and wiring: Opus builds the surface matrix (which of CLI/MCP/API a consumer list actually needs, refusing surfaces with no consumer) -> Opus produces the right-sized data-layer recommendation + the computer/system/harness integration map. Does NOT build the surfaces (the caller invokes /make-cli, /make-mcp, /make-api for the NEEDED ones).',
  phases: [
    { title: 'Surface Matrix' },
    { title: 'Data & Wiring Plan' },
  ],
}

const APP = args.app
const SURFACES_OVERRIDE = (args.surfacesOverride || '').trim()

// --- Phase schemas (JSON-schema-validated agent output, spar/hone/probe pattern) ---

const MATRIX_SCHEMA = {
  type: 'object',
  properties: {
    consumers: {                                        // every consumer, mapped to the surface that fits it
      type: 'array',
      items: {
        type: 'object',
        properties: {
          consumer: { type: 'string' },
          surface: { type: 'string', enum: ['cli', 'mcp', 'api', 'library'] },
          rationale: { type: 'string' },
        },
        required: ['consumer', 'surface', 'rationale'],
      },
    },
    needed: { type: 'array', items: { type: 'string', enum: ['cli', 'mcp', 'api'] } },   // surfaces to build
    not_needed: {                                       // surfaces ruled out + why -- the negative space matters
      type: 'array',
      items: {
        type: 'object',
        properties: {
          surface: { type: 'string', enum: ['cli', 'mcp', 'api'] },
          reason: { type: 'string' },
        },
        required: ['surface', 'reason'],
      },
    },
    zero_surface: { type: 'boolean' },                  // true if every consumer is same-process (library import)
    shared_core: { type: 'string' },                    // the app fns all built surfaces should call, or 'n/a'
    override_conflict: { type: 'string' },              // if --surfaces asked for a consumer-less surface, the flag
  },
  required: ['consumers', 'needed', 'not_needed', 'zero_surface'],
}

const WIRING_SCHEMA = {
  type: 'object',
  properties: {
    data_layer: {
      type: 'object',
      properties: {
        choice: { type: 'string', enum: ['none', 'sqlite', 'postgres', 'redis', 'vector', 'object-store', 'mixed'] },
        detail: { type: 'string' },                     // e.g. "sqlite + sqlite-vec for embeddings"
        reason: { type: 'string' },
        cheapest_satisfying: { type: 'string' },        // the least-ops thing that meets the need
      },
      required: ['choice', 'reason'],
    },
    computer: {                                         // PATH / config dir / env / launcher recommendations
      type: 'array',
      items: {
        type: 'object',
        properties: {
          what: { type: 'string' },
          command_or_path: { type: 'string' },           // concrete, in Douglas's shell syntax where a command
          status: { type: 'string', enum: ['done', 'recommended'] },
        },
        required: ['what', 'status'],
      },
    },
    system: {                                           // service/port/autostart/logs recommendations
      type: 'array',
      items: {
        type: 'object',
        properties: {
          what: { type: 'string' },
          command_or_path: { type: 'string' },
          status: { type: 'string', enum: ['done', 'recommended'] },
        },
        required: ['what', 'status'],
      },
    },
    harness: {                                          // claude mcp add / slash command / settings / desktop
      type: 'array',
      items: {
        type: 'object',
        properties: {
          what: { type: 'string' },
          command_or_path: { type: 'string' },
          status: { type: 'string', enum: ['done', 'recommended'] },
        },
        required: ['what', 'status'],
      },
    },
  },
  required: ['data_layer', 'computer', 'system', 'harness'],
}

// --- Prompts ---

function matrixPrompt(app, override) {
  return `Decide the CONNECTIVE SURFACES a new app needs -- this is the load-bearing decision and the whole ` +
    `point of the pass. APP: ${app}\n` +
    (override ? `EXPLICIT --surfaces OVERRIDE requested: ${override}. Honor it, BUT if it asks for a surface ` +
      `with no real consumer, record that mismatch in override_conflict rather than silently endorsing it.\n` : '') +
    `\nEnumerate EVERY consumer of this app and map each to the ONE surface that fits it:\n` +
    `- a human at a terminal, or a shell script -> CLI\n` +
    `- an AI host (Claude Desktop/Code) where the model invokes tools -> MCP server -- UNLESS the host has a ` +
    `shell (Claude Code, any agent with a Bash tool): a good CLI with --json output serves a shell-bearing ` +
    `agent at near-zero context cost and measurably beats an equivalent MCP server on tokens and speed ` +
    `(Ronacher's gh-vs-GitHub-MCP test). Reserve MCP for OAuth/per-user token flows, long-lived stateful ` +
    `sessions/subscriptions, or shell-less hosts (Claude Desktop, remote MCP clients); if a CLI is already ` +
    `needed for other consumers, default the shell-bearing agent onto it and record the ruled-out MCP in ` +
    `not_needed with this reason\n` +
    `- a remote client, multiple heterogeneous clients, or a cross-language caller over the network -> HTTP API\n` +
    `- a human using a browser/GUI frontend -> the HTTP API the frontend calls (building the frontend itself is ` +
    `OUT OF SCOPE -> impeccable / /design)\n` +
    `- same-process / same-language code in the same repo -> a LIBRARY import (NO surface)\n` +
    `- a scheduler/cron on this machine -> usually the CLI (a scheduled command), not a new surface\n\n` +
    `Then collapse to the surfaces actually NEEDED, under three hard rules:\n` +
    `1. A surface with NO consumer does NOT get built -- do not add an MCP server "in case an agent wants it ` +
    `later" or an API "for future remote clients" when no such consumer exists today. Speculative surfaces are ` +
    `the most common connective over-build; refuse them.\n` +
    `2. ZERO surfaces is a valid honest answer: if every real consumer is same-process code, set ` +
    `zero_surface=true, needed=[], and the finding is "a library import, not a CLI/MCP/API".\n` +
    `3. SEVERAL surfaces is fine when the consumer list genuinely spans terminals, agents, and remote clients -- ` +
    `each needed one gets built and they should all call ONE shared core (name it in shared_core) so they stay ` +
    `thin adapters over the app's real functions, not three divergent copies.\n\n` +
    `Also weigh HOW consumers authenticate: with a pre-configured API key/env var, a CLI hitting the same ` +
    `backend is functionally equivalent to an MCP server; OAuth flows, per-user tokens, and audit requirements ` +
    `are what justify the heavier surface.\n\n` +
    `Report consumers (each with surface + rationale), needed (surfaces to build), not_needed (each ruled-out ` +
    `surface WITH the reason -- the negative space is part of the deliverable), zero_surface, shared_core, and ` +
    `override_conflict if any.`
}

function wiringPrompt(app, matrix) {
  return `Given the surface decision, produce a RIGHT-SIZED data-layer recommendation and a concrete ` +
    `computer/system/harness integration map. APP: ${app}\nSURFACE MATRIX: ${JSON.stringify(matrix)}\n\n` +
    `DATA LAYER -- match persistence to the app's data shape; the ponytail ladder applies to storage as hard as ` +
    `to code. none (stateless) | sqlite (single-user/local/embedded, low concurrency -- a file, zero ops) | ` +
    `postgres (concurrent writers, relational, multi-client, durable) | redis (cache/queue/rate-limit/ephemeral, ` +
    `ALONGSIDE the primary store) | vector (embeddings/semantic -- prefer sqlite-vec/pgvector piggybacking the ` +
    `primary DB over a standalone vector service) | object-store (large blobs, kept out of the row store). Do ` +
    `NOT reach for postgres for a single-user local tool or a standalone vector DB when pgvector/sqlite-vec ` +
    `rides the existing DB. RECOMMEND ONLY -- do not provision anything. Give choice, detail, reason, and the ` +
    `cheapest thing that satisfies the need.\n\n` +
    `INTEGRATION MAP -- for each built surface + the data layer, give WHERE it wires in, each tagged 'done' ` +
    `(a sub-skill actually did it this pass -- essentially only harness registration) or 'recommended' ` +
    `(Douglas executes it):\n` +
    `- COMPUTER: PATH entry / shell-profile alias for a CLI; config dir (XDG on POSIX, %APPDATA% on Windows); ` +
    `env vars it reads; a launcher for scheduled/background runs (Windows Task Scheduler on this machine, ` +
    `launchd/systemd-user elsewhere).\n` +
    `- SYSTEM (for a long-running API/service): port, service/daemon + autostart, reverse proxy if needed, log ` +
    `sink. Keep it loopback+local by default for this laptop; NEVER recommend binding a fresh unhardened ` +
    `service to a public interface unless explicitly asked, and flag the hardening gap if so.\n` +
    `- HARNESS: claude mcp add <name> for an MCP surface (report scope, default local); whether it should also ` +
    `be a slash command in ~/.claude/commands/ (+ its claude-global-config tracked mirror); for a ` +
    `shell-bearing-agent consumer served by the CLI, whether to author a Skill (~/.claude/skills/ or ` +
    `~/.claude/commands/) that teaches the agent the app's multi-step CLI workflow -- recommended over an MCP ` +
    `wrapper when the need is procedural guidance rather than a new tool, since a Skill loads no tool schema ` +
    `and adds no standing context cost; any settings.json ` +
    `permission/hook wiring (hand to /update-config, do not edit settings here); a Claude Desktop mcpServers ` +
    `entry if that's a consumer. If the MCP surface exposes MANY tools, or the app is joining a harness already ` +
    `running several heavy MCP servers, note the context cost and recommend on-demand consumption (progressive ` +
    `tool disclosure -- load a tool schema only when used -- or routing calls through a code-executor) over ` +
    `loading every tool schema upfront; ~3+ heavy servers can burn tens of thousands of tokens before the first ` +
    `turn, and this stays a RECOMMENDED consumption choice, never auto-applied.\n\n` +
    `Make each command_or_path concrete and copy-pasteable, and any command Douglas runs himself in his shell's ` +
    `syntax (PowerShell/cmd on this machine), NOT Bash. Report data_layer, computer, system, harness.`
}

// --- Run ---

log(`Surface Matrix: deciding which of CLI/MCP/API ${APP} actually needs`)
const matrix = await agent(matrixPrompt(APP, SURFACES_OVERRIDE), { phase: 'Surface Matrix', schema: MATRIX_SCHEMA, label: 'surface-matrix', model: 'opus' })

if (matrix && matrix.zero_surface) {
  log('Surface matrix collapsed to ZERO surfaces -- this app needs a library import, not a CLI/MCP/API. Still producing the data + wiring recommendation.')
}

log(`Data & Wiring Plan: right-sizing the data layer and mapping computer/system/harness wiring for ${APP}`)
const wiring = await agent(wiringPrompt(APP, matrix), { phase: 'Data & Wiring Plan', schema: WIRING_SCHEMA, label: 'data-wiring', model: 'opus' })

return {
  app: APP,
  matrix,
  wiring,
  needed: matrix ? (matrix.needed || []) : [],
  zeroSurface: !!(matrix && matrix.zero_surface),
  note: 'Decision + recommendation only. The caller must now invoke /make-cli, /make-mcp, and/or /make-api for ' +
    'each surface in matrix.needed; each self-isolates and self-tests. Everything in wiring tagged "recommended" ' +
    'is unexecuted and awaits Douglas.',
  stopReason: 'complete',
}
```

## Final report (what to tell Douglas)

- **The surface matrix first.** Which surfaces were built (CLI/MCP/API) and, just as important, which were
  ruled out and why — the negative space is part of the answer. If it collapsed to zero surfaces, say so plainly:
  *"this needs a library import, not a network/terminal/host surface"* — plus the data-layer recommendation.
- **What each built surface is and what its sub-skill verified this pass** — carried up from `/make-cli` /
  `/make-mcp` / `/make-api` (the live CLI exit-code matrix, the Inspector `tools/call`, the API's real HTTP
  round-trip against the spec). Note the shared core they all call, if several were built.
- **The data-layer recommendation** — the choice, the one-line reason, and the cheapest thing that satisfies it,
  stated as a recommendation (not provisioned).
- **The integration map** — computer, system, and harness wiring, each entry tagged **DONE** (what the
  sub-skills actually wrote — chiefly `claude mcp add`, with its scope) or **RECOMMENDED** (the concrete
  `PATH`/Task-Scheduler/`/update-config`/`claude mcp add` step for Douglas to execute, in his shell's syntax).
- **What remains** — never "fully connected," "wired up," or "production-ready." Report what this pass built and
  verified and what is recommended-but-unexecuted, and point at **`/spar` against each new surface** for the
  adversarial hardening pass. Anything touching `PATH`, system services, or a real data store is unexecuted and
  Douglas's call — say so.
- Full absolute path(s) of everything the sub-skills wrote, per the standing Files-list convention, and the
  exact registration commands run (with scope) versus recommended.

---

*Tracked copy: also save this file to `claude-global-config/commands/connect.md` (per the skills-are-tracked
convention) after a NASA scrub.*
