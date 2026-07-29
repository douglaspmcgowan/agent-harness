---
name: make-mcp
description: "Build a Model Context Protocol server end to end: resolve what to expose (tools/resources/prompts), classify local-vs-remote and pick a scaffolding track (Python/FastMCP or TypeScript/official SDK) behind an early GATE that sends you to install an existing server if one already covers the need, design the protocol surface language-agnostically (right primitive, right transport, capability negotiation), scaffold the server, register it (`claude mcp add`, Claude Desktop config), and test it live with the MCP Inspector before reporting what was verified this pass and what remains. Use when Douglas says 'build an MCP server', 'make an MCP', 'expose X as MCP tools', 'wrap my code as an MCP server', '/make-mcp'."
---

# /make-mcp [target] [--track python|ts] [--transport stdio|http]

Building an MCP server is a wire-protocol job before it is a coding job. A server that imports cleanly and
"looks right" proves nothing — the host talks to it over JSON-RPC, negotiates capabilities at `initialize`,
and calls tools with schema the client has to be able to parse. This command classifies what you're exposing,
picks the track, designs the protocol surface deliberately, scaffolds it, registers it, and then actually
attaches the MCP Inspector and calls a tool to confirm the wire works — reporting what that live check verified
this pass and what still needs a hardening pass.

**Deviate out loud.** This staged process is the well-reasoned default. When you genuinely judge that a
specific situation calls for a different move than this command prescribes, surface the divergence and your
reasoning to Douglas and let him decide, instead of silently complying or silently going your own way.

## What this is NOT

- **Not `/make-cli`.** A CLI is a user-facing command a human runs in a terminal. An MCP server is a background
  process that exposes tools/resources/prompts to a *host* application (Claude Desktop, Claude Code) over a wire
  protocol; the host embeds a client per server connection and the model invokes the tools. If Douglas wants a
  command he types himself, that's `/make-cli`, a different shape entirely.
- **Not installing an existing community MCP server.** This builds a NEW server. The Step-1 gate exists
  precisely to catch the case where a server already exposes what he needs — when it does, the right move is to
  install that one (`claude mcp add`) and stop, rather than reimplementing it. This command reaches for a
  scaffold only after the gate confirms there's a genuinely new server to build.
- **Not the MCP spec or docs themselves.** This is a build → register → test procedure. It cites the spec's
  mechanisms (three primitives, two transports, capability negotiation) and points at the official quickstart
  for the canonical examples; it does not restate the specification.

## Procedure

### Step 0 — Resolve TARGET from ARGUMENTS

Needs enough that a subagent with ZERO conversation context could act alone. Establish four things and ask only
what isn't already obvious from the conversation:

- **What to expose**, and as which primitive — model-invoked functions (tools), client-read file-like data
  (resources), or user-selected templates (prompts). The primitive choice is load-bearing and gets decided
  properly in Step 2, but Step 0 needs at least the rough shape of what the server offers.
- **Local vs remote** — a subprocess the host spawns on this machine (stdio), or a service reached over the
  network (Streamable HTTP).
- **Who consumes it** — Claude Desktop, Claude Code, or another host — since registration differs.
- **Language preference**, if any. Parse `--track python|ts` and `--transport stdio|http` if given; otherwise
  the Step-1 gate picks the track from what's being wrapped.

If ARGUMENTS lacks what's needed and it isn't obvious from the conversation, ask what to expose, whether it's
local or remote, and what will consume it before proceeding — don't guess at a server surface.

### Step 1 — GATE: classify, and avoid building what already exists (mandatory, before any scaffold)

This gate mirrors the already-optimized gate in `/hone` and the no-tests gate in `/probe`: check the condition
that makes the whole build pointless BEFORE spending time on it.

1. **Does an existing MCP server already expose this?** Before scaffolding anything, check whether a
   community/official server already covers the need (the well-known ones: filesystem, git, fetch, database
   connectors, etc., plus whatever the target domain already has). If one does, the finding IS the answer:
   report it plainly — *"an existing server (`<name>`) already exposes this; install it with `claude mcp add`
   rather than building a new one"* — and STOP. Do not manufacture a thin new server to look useful when the
   real work is a one-line install.
2. **If it's genuinely new, pick the track** from what's being wrapped:
   - **Wrapping your own Python / data / CAD code** → **Python / FastMCP**. The decorators derive schema from
     the type hints and docstrings already on your functions, so the wrapping is thin.
   - **A server meant for wide public distribution via `npx`** → **TypeScript / official SDK**, because the
     `bin`-entry + built-JS pattern is what makes `npx <package>` work for other people.
   - **A simple local personal tool** with no strong preference → **Python stdio**, the least-ceremony default.

   An explicit `--track` always wins over this heuristic if Douglas passed one.

Report which branch fired. A fired install-instead gate is a complete answer on its own; do not follow it with a
half-built scaffold.

### Step 2 — Protocol design (language-agnostic, before touching either track)

Design the wire surface before writing framework code. Three decisions:

- **Pick the right primitive.** The spec has exactly three, and the terminology maps to exactly these:
  - **tools** — model-invoked functions; the model calls them and each call needs user approval. Anything with
    a side effect or a computation belongs here.
  - **resources** — client-read, file-like data addressed by URI; the client reads them, the model does not
    invoke them. Read-only context (a file, a record, a rendered view) belongs here.
  - **prompts** — user-selected templates the user picks from, not something the model triggers.
  Choosing tool-where-it-should-be-resource (or the reverse) is the most common design error; decide per thing
  exposed, not once for the whole server.
- **Pick the transport.**
  - **stdio** — local, single-client, the host spawns the server as a subprocess. Simplest, no auth. This is
    the default for a local personal tool.
  - **Streamable HTTP** — remote, a single `/mcp` endpoint handling POST and GET with optional SSE streaming,
    session carried in the `Mcp-Session-Id` header. A remote server needs auth (bearer/OAuth); stdio does not.
  - The older two-endpoint HTTP+SSE transport (2024-11-05 spec) is deprecated as of the 2025-03-26 revision.
    Use Streamable HTTP for anything new; only touch the old transport for back-compat with an existing client
    that requires it.
  - **Stateful vs stateless HTTP — decide before you wire it.** A `Mcp-Session-Id` should exist only when the
    server actually carries per-connection state between calls (a subscription, an in-progress elicitation, a
    server-held cursor). If every tool call is self-contained, run **stateless**: no session id, each POST is
    handled in isolation. A stateful server pins a client to one process, so horizontal scaling forces
    session-affinity (sticky routing) or a shared session store behind the endpoints — pick the stateless mode
    unless a feature genuinely needs the session, and note the scaling constraint in the design when it does.
- **Know the JSON-RPC envelope.** MCP is JSON-RPC 2.0 over the transport. Three message shapes: a **request**
  (has `id`, expects a response), a **response** (matching `id`, carries `result` or `error`), and a
  **notification** (no `id`, no reply — used for progress and `resources/updated`). The connection opens with an
  `initialize` request that negotiates the protocol version and exchanges capabilities, answered by the client's
  `initialized` notification; a version the server can't speak is a negotiation failure at that handshake, before
  any tool runs. Protocol-level failures are JSON-RPC **error objects** with `code` / `message` / optional
  `data` (method-not-found, invalid-params, parse-error). Knowing this is what lets you read the Inspector's raw
  frames when a call fails.
- **Annotate every tool.** Each tool carries a human-readable `title` and behavior hints the host uses to gate
  approval: `readOnlyHint` (no side effects), `destructiveHint` (mutates/deletes irreversibly),
  `idempotentHint` (repeat calls are safe), `openWorldHint` (reaches external systems — network, filesystem
  beyond a fixed scope). Set them honestly per tool; a side-effecting or destructive tool that reports itself
  read-only defeats the host's guard. These hints are advisory metadata for the host, so they inform approval;
  they do not enforce anything server-side — the server still validates (see the security step). A host may
  retry a call that failed or timed out, so a mutating tool marked `idempotentHint: true` must actually be safe
  under repeat — a dedup key on the request or an upsert on the write — so the label matches real behavior.
- **Newer primitives — reach past the core three only when a feature needs them.**
  - **roots** — the client tells the server which filesystem/URI boundaries it may operate within; a
    filesystem-touching server reads the roots list to stay inside sanctioned directories.
  - **elicitation** — the server asks the *user* for a value mid-tool-call (a missing parameter, a confirmation)
    and resumes with the answer. Use it instead of failing a call for one missing input; needs a session, so
    stateful HTTP or stdio.
  - **progress notifications** — a long tool call streams `notifications/progress` against a `progressToken` so
    the host can show a bar. Add it to any tool that runs more than a couple of seconds.
  - **resource subscriptions** — a client sends `resources/subscribe` and the server pushes
    `notifications/resources/updated` when the underlying data changes. Declare it in capabilities only if the
    server can actually detect changes; otherwise leave resources poll-only.
  - **server-initiated sampling** — the server asks the *host's* model to complete a prompt on its behalf
    (`sampling/createMessage`). Powerful and rarely needed; declare the `sampling` capability only when a tool
    genuinely calls back into the model, and never as a way to smuggle instructions past the user.
- **Tool error model — expected failures live inside the result.** A recoverable, model-visible failure (bad
  argument, not-found, upstream 4xx) returns a normal tool result with `isError: true` and model-actionable text
  ("no record for id X; check the id") so the model can retry or adjust. Reserve protocol-level JSON-RPC errors
  for genuine protocol faults (unknown method, malformed request). Never leak a stack trace, internal path, or
  secret in either channel — error text is model-visible and, through it, injection-adjacent.
- **Explain capability negotiation.** The server declares which of tools/resources/prompts/sampling it supports
  once, at `initialize`. A client should not assume a capability without checking, so the server must declare
  exactly what it offers and no more. Get this list right at design time rather than discovering a missing
  declaration during Inspector testing.

### Step 2b — Server attack surface (MCP-specific security)

The **"Safety constraints"** section below governs the BUILD harness — how this command scaffolds, isolates, and
registers. THIS step governs the produced server's OWN attack surface once a host connects to it. Design it in,
per tool, before scaffolding.

- **Tool descriptions are an injection surface.** Tool names, descriptions, and per-argument docs are read by
  the host model on every turn, so a description is prompt text the model trusts. Keep them plain factual
  statements of what the tool does. No hidden instructions, no invisible/encoded text, no over-eager
  "always call this tool first" / "ignore other tools" phrasing — that is tool-poisoning, and it steers the host
  model exactly the way an injected web page would. Write descriptions as if an adversary will read them for
  leverage, because the model does read them.
- **Least-privilege tool scoping.** Expose the narrowest capability that does the job, never a raw `shell` /
  `eval` / "run arbitrary SQL" / "read any path" tool. A `read_invoice(id)` tool is a scoped capability; a
  `run_query(sql)` tool hands the model the whole database. If the underlying power is broad, wrap the specific
  operations you actually need as separate scoped tools and expose those.
- **Validate/sanitize every argument at the boundary**, before it reaches real code — tool args arrive from the
  model and are attacker-influenceable through injection. Guard: path traversal (`../`, absolute paths escaping a
  root — enforce the client's `roots` where relevant), command and SQL injection (parameterize, never string-
  concatenate into a shell or query), and SSRF from any URL/host argument (deny internal/link-local/metadata
  addresses). The schema constrains *shape*; this is the *value* check the schema can't do.
- **The confused-deputy problem on remote/OAuth HTTP servers.** A remote server authenticates the caller, so it
  can be tricked into acting with its own privileges on an attacker's behalf. Validate the access token's
  **audience** (it was minted for THIS server, not passed through from elsewhere), pin exact **redirect URIs** in
  the OAuth flow, and never forward the host's credentials to a third-party API downstream — mint or use the
  server's own scoped credential. Stdio servers skip this; any HTTP/OAuth server must handle it.
- **Never embed secrets in the protocol surface.** No API keys, tokens, or connection strings in tool schemas,
  descriptions, resource contents, or error text — all of it is model-visible and crosses the wire. Secrets come
  from the server's environment (env vars, a secrets store), never from anything the schema or a response
  carries.

### Step 3 — Python track (FastMCP)

The official SDK package is `mcp` (import `mcp.server.fastmcp.FastMCP`). Install with `uv add "mcp[cli]"` or
`pip install "mcp[cli]"`.

- **Pin the version deliberately.** The stable production line is v1.x (currently 1.28.x). The digest flags v2
  as pre-release (`mcp[cli]==2.0.0b1`, targeting the 2026-07-28 spec) and NOT production-recommended, so the
  scaffold pins **`mcp>=1,<2`** unless Douglas explicitly asks for v2. Because the exact current version is a
  moving target, confirm the latest 1.x on PyPI at scaffold time rather than hardcoding a patch version blindly.
- **Decorators auto-derive schema — no manual JSON Schema authoring.** `@mcp.tool()` over a type-hinted
  function derives its input schema from the parameter types plus the docstring `Args`; `@mcp.resource("scheme://{param}")`
  for URI-templated resources; `@mcp.prompt()` for prompts. Write real type hints and a real docstring; that IS
  the schema.
- **The CARDINAL stdio rule: never write to stdout in a stdio server.** Anything on stdout corrupts the
  JSON-RPC stream and breaks the server silently. Log to stderr or a file. This applies to stray `print()`
  calls, debug output, and any library that prints. (HTTP transport has no such restriction.)
- **Set tool annotations and validate args.** Pass the Step-2 hints and title through `@mcp.tool(annotations=...)`
  (`title`, `readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`), and validate/sanitize each
  argument at the top of the function per Step 2b before it reaches real code.
- **Error model:** for an expected, recoverable failure return a result the model can act on (FastMCP surfaces a
  raised `ToolError` / a returned error result as `isError` content); reserve exceptions that become protocol
  errors for real protocol faults. Never put a stack trace, path, or secret in the message.
- **Run** with `mcp.run(transport="stdio")` (or `transport="streamable-http"` for the remote case).
- **Dev loop:** `uv run mcp dev server.py` launches the server pre-wired into the Inspector — use that for the
  live check in Step 5.

### Step 4 — TypeScript track (official SDK)

The official SDK package is `@modelcontextprotocol/sdk` (install `npm install @modelcontextprotocol/sdk zod`).
Do not confuse it with the pre-release `@modelcontextprotocol/server` v2 beta. The stable import paths are
`@modelcontextprotocol/sdk/server/mcp.js` and `.../server/stdio.js`. The digest could not directly confirm the
exact current version (npm fetch 403'd), so confirm the latest `@modelcontextprotocol/sdk` on npm at scaffold
time rather than hardcoding a version.

- **Pattern:** `new McpServer({ name, version })`, then
  `server.registerTool(name, { description, inputSchema: { <zod fields> } }, async (args) => ({ content: [{ type: "text", text: ... }] }))`.
  Zod v3 or v4 works; Standard Schema support means valibot/arktype drop in as alternatives.
- **Annotations, args, errors:** pass the Step-2 hints in the tool config (`annotations: { title, readOnlyHint,
  destructiveHint, idempotentHint, openWorldHint }`), validate/sanitize each arg per Step 2b, and for a
  recoverable failure return `{ isError: true, content: [{ type: "text", text: "<model-actionable message>" }] }`
  rather than throwing — reserve throws for real protocol faults, and never surface a stack trace or secret.
- **stdio wiring:** `new StdioServerTransport()` then `await server.connect(transport)`.
- **`console.log` is forbidden** in a stdio server for the same reason as Python's stdout rule — it pollutes the
  JSON-RPC stream. Use `console.error`.
- **Distribution plumbing:** the project needs `"type": "module"` in `package.json`, a `tsc` build step, and a
  `bin` entry pointing at the built JS. Those three together are what make `npx <package>` work for other
  people. A server that runs from source but has no build step and no `bin` will not distribute over npx.

### Step 5 — Register and test live

**Registration.**

- **Claude Code:** `claude mcp add <name> -- <command> <args...>`. Scopes: **local** (default, private to the
  current project, written to `~/.claude.json`), **user** (global), **project** (writes a git-committable
  `.mcp.json` at the repo root). Remote/HTTP uses `claude mcp add <name> --transport http <url>`.
- **Claude Desktop:** a separate JSON config (`claude_desktop_config.json`) with an `mcpServers` map of
  `{ command, args }` entries; there is no scope concept there. Paths: macOS
  `~/Library/Application Support/Claude/claude_desktop_config.json`, Windows
  `%APPDATA%\Claude\claude_desktop_config.json`.
- **The digest marks the exact `claude mcp add` flag syntax and scope names as secondary-source-only (not a
  direct fetch of the official mcp-quickstart doc).** Before hardcoding the flags into a registration command,
  DIRECT-FETCH the official quickstart/mcp-add documentation and confirm the current flag syntax and scope
  names against it. Treat the values above as high-confidence-but-verify, not settled.

**Testing with the MCP Inspector.** `npx @modelcontextprotocol/inspector <server-launch-command>` opens a
browser UI (localhost:6274) plus a proxy (6277) with zero install. For a scripted, automatable check, use the
CLI mode: `npx @modelcontextprotocol/inspector --cli <cmd> --method tools/list`, then
`... --method tools/call --tool-name <X> --tool-arg k=v` to actually invoke a tool and read the result. The CLI
call is the verifiable evidence that the wire works — a passing `tools/call` this pass, not "it should connect."
**Exercise every primitive the server declares, not just tools.** If it exposes resources, run
`... --method resources/list` then `... --method resources/read --uri <uri>` and read what came back; if it
exposes prompts, run `... --method prompts/list` then `... --method prompts/get --prompt-name <P> --prompt-arg k=v`.
A declared capability that was never round-tripped is unverified, the same standard the `tools/call` holds to.

**Bake in the pitfalls checklist** (each is a real, common way an MCP server silently fails):

1. **stdout pollution** breaking the stdio JSON-RPC stream (Python `print`, TS `console.log`, chatty libraries).
2. **Schema mistakes** — loose/`Any` types, missing parameter descriptions, and `$ref`/union types that some
   clients cannot parse. Keep schema flat and described.
3. **Forgetting the TS rebuild** before pointing the host config at `build/` — the host runs stale JS.
4. **Remote/HTTP auth** — a Streamable HTTP server needs bearer/OAuth that a stdio server does not.
5. **Absolute-path requirements in host config args** — relative paths silently fail; use absolute paths in the
   registered command/args.
6. **Attack-surface gaps (Step 2b)** — unvalidated tool args (path traversal / injection / SSRF), a raw
   shell/eval/arbitrary-path tool where a scoped one belongs, poisoning-friendly tool descriptions, a secret in a
   schema or error string, or (HTTP/OAuth) an unvalidated token audience or redirect URI.

### Step 6 — Verify and report

Report per "Final report" below: what was built and registered, what the live Inspector call actually verified
this pass, and what remains. For adversarial hardening of the running server (input fuzzing, state/ordering,
resource exhaustion against the live tools), point Douglas at `/spar` against the registered server — that's the
break-fix loop, distinct from this build-and-confirm-the-wire pass.

## Procedure (how to run it)

1. Resolve TARGET, track, and transport per Step 0.
2. **Run the Step-1 gate FIRST, before the Workflow.** Checking whether an existing server already covers the
   need is cheap and short-circuits the whole build. If the install-instead branch fires, report it and STOP —
   do not call the Workflow.
3. Otherwise **call the `Workflow` tool** with the script below verbatim, passing
   `args: { target: "<what to expose + local/remote + who consumes it>", track: "<python|ts>", transport: "<stdio|http>", allowUnisolated: false }`.
   This is an explicit skill-triggered Workflow use (per the Workflow tool's own rule) — no separate opt-in.
   - **The Design & Build and Adversarial-verify phases run on `model: 'opus'`** — Douglas's delegation policy
     reserves Opus for the load-bearing judgment (which primitive each thing should be, whether the schema is
     client-parseable, whether the Inspector result actually proves the wire works). The mechanical Scaffold +
     Inspector-test phase stays on the default model.
   - The Workflow's first phase runs a **Preflight** that actually creates (and removes) a scratch worktree to
     PROVE isolation is possible rather than assuming it. If `stopReason` comes back `no_isolation_available`,
     this is Douglas's call, not yours: AskUserQuestion — commit the target first and re-run for full isolation
     (recommended), or proceed unisolated (the scaffold is written directly to the real files, no worktree, no
     diff to hand back). Only re-invoke with `allowUnisolated: true` after he answers.
4. **Report the result** per "Final report" below. Never claim the server is "fully tested," "production-ready,"
   or "complete" — report what the Inspector call verified this pass and what remains (auth, more tools, a
   `/spar` hardening pass).

## Safety constraints (apply every run, no exceptions)

- **Never run with elevated/bypass permissions.** A generic "build me an MCP server" ask does not justify
  disabling the permission system; run at default tool permissions. If the classifier or a safety layer blocks
  an action mid-run, that is a correct block — narrow scope and try a different angle, don't route around it.
- **Isolate the trial scaffold in a git worktree; never touch the caller's main tree — and PROVE isolation is
  possible before claiming it, never assume it.** `git worktree add` only carries COMMITTED content; an
  untracked file or an un-gitted directory does not exist in a fresh worktree at all, so a run that assumes
  isolation can silently write the scaffold into the real tree while reporting "worktree removed." The
  Preflight phase actually creates and proves a worktree before any write happens, and refuses to silently
  degrade. If preflight finds isolation is impossible, STOP and ask Douglas (commit the target first —
  recommended — or proceed unisolated, in which case the scaffold is written directly to the real files and the
  report must say so plainly, never "worktree removed"/"diff handed back" when that isn't what happened).
- **Stay strictly scoped to the target.** Build and register only the server under construction. No touching
  unrelated processes, files, services, or shared state; no destructive or irreversible action on anything
  shared. Stop any Inspector/dev process the run started, and confirm it's stopped, before finishing.
- **Registration writes real config — treat it deliberately.** `claude mcp add` and the Claude Desktop config
  edit change files outside the worktree by design. Default to **local** scope (`~/.claude.json`) unless Douglas
  asked for user/project; a `--scope project` write to a git-committable `.mcp.json` is a change he should see,
  so report it explicitly. Never edit the Claude Desktop config to point at a build directory that hasn't been
  built yet (TS rebuild pitfall).
- **Clean up when done.** Remove any trial worktree (`git worktree remove --force`) and prune, and confirm
  `git status` on the main tree shows nothing unexpected before finishing. **Delete a throwaway branch with
  `git branch -d` (safe delete), not `-D`** — this machine's `block-dangerous-bash.js` hook unconditionally
  blocks `git branch -D`. Run worktree-remove and branch-delete as two separate calls, never chained in one
  command. If a branch genuinely can't be `-d`-deleted, leave it and note the dangling pointer in the report
  rather than routing around the block.
- **No commits.** Building means scaffolding, registering, and testing — never `git commit` / `git push`,
  unless Douglas separately asked for that.
- **Make only the change the build requires** — the server scaffold, its registration, and its test. No
  unrelated refactors, no drive-by cleanup, no speculative extra tools beyond what was asked.
- **If the target keeps a tracked mirror elsewhere in this repo's convention** (e.g. this harness's
  `~/.claude` ↔ `claude-global-config` split), note it and leave the mirror sync to Douglas.

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'make-mcp',
  description: 'Build an MCP server: preflight (prove isolation) -> Opus designs the protocol surface + scaffolds a plan -> scaffold + Inspector live-test the track -> Opus adversarially verifies the wire actually works',
  phases: [
    { title: 'Preflight' },
    { title: 'Design & Build' },
    { title: 'Scaffold & Test' },
    { title: 'Verify' },
  ],
}

const TARGET = args.target
const TRACK = args.track === 'ts' ? 'ts' : 'python'   // default python (least-ceremony local tool)
const TRANSPORT = args.transport === 'http' ? 'http' : 'stdio'
const ALLOW_UNISOLATED = args.allowUnisolated === true

// --- Phase schemas (JSON-schema-validated agent output, spar/hone/probe pattern) ---

const PREFLIGHT_SCHEMA = {
  type: 'object',
  properties: {
    is_git_repo: { type: 'boolean' },
    target_tracked: { type: 'boolean' },
    can_isolate: { type: 'boolean' },   // true ONLY if a real worktree was created and PROVEN to contain the target's content, then removed
    reason: { type: 'string' },
  },
  required: ['is_git_repo', 'target_tracked', 'can_isolate', 'reason'],
}

const DESIGN_SCHEMA = {
  type: 'object',
  properties: {
    primitives: {                                       // per thing exposed: which of the three, and why
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          primitive: { type: 'string', enum: ['tool', 'resource', 'prompt'] },
          rationale: { type: 'string' },
          annotations: {                                // per tool: title + behavior hints the host gates approval on
            type: 'object',
            properties: {
              title: { type: 'string' },                // human-readable title
              readOnlyHint: { type: 'boolean' },        // no side effects
              destructiveHint: { type: 'boolean' },     // mutates/deletes irreversibly -- flag explicitly
              idempotentHint: { type: 'boolean' },      // repeat calls are safe -- must hold under a host retry (dedup key or upsert), not just in the happy path
              openWorldHint: { type: 'boolean' },       // reaches external systems (network/fs beyond a fixed scope)
            },
          },
          arg_validation: { type: 'string' },           // how args are sanitized at the boundary (traversal/injection/SSRF)
        },
        required: ['name', 'primitive', 'rationale'],
      },
    },
    transport: { type: 'string', enum: ['stdio', 'streamable-http'] },
    stateful: { type: 'boolean' },                      // HTTP: does the server carry per-connection state (Mcp-Session-Id) at all
    session_rationale: { type: 'string' },              // why a session exists (or why stateless), + scaling/affinity note if stateful
    needs_auth: { type: 'boolean' },                    // true for remote/HTTP
    confused_deputy_handling: { type: 'string' },       // HTTP/OAuth: token-audience + redirect-URI validation, no credential forwarding
    newer_primitives: { type: 'array', items: { type: 'string' } }, // roots/elicitation/progress/resource-subscriptions/sampling used, with why
    error_model: { type: 'string' },                    // isError-in-result (recoverable) vs protocol error; no secrets/traces in error text
    declared_capabilities: { type: 'array', items: { type: 'string' } }, // what initialize will declare
    version_pin: { type: 'string' },                    // e.g. "mcp>=1,<2" or the confirmed @modelcontextprotocol/sdk range
    version_confirmed_live: { type: 'boolean' },        // true if the latest stable was checked at scaffold time, not hardcoded
    build_plan: { type: 'string' },                     // the scaffold plan, language-appropriate
  },
  required: ['primitives', 'transport', 'declared_capabilities', 'version_pin', 'build_plan'],
}

const SCAFFOLD_SCHEMA = {
  type: 'object',
  properties: {
    track: { type: 'string', enum: ['python', 'ts'] },
    files_written: { type: 'array', items: { type: 'string' } },       // absolute paths in the worktree (or real tree if unisolated)
    stdout_clean: { type: 'boolean' },                  // no print/console.log on stdout for a stdio server
    build_ran: { type: 'boolean' },                     // TS: tsc build ran; Python: n/a -> true
    inspector_cmd: { type: 'string' },                  // the exact CLI-mode command used
    tools_list_result: { type: 'string' },              // what tools/list returned via the Inspector CLI
    tools_call_result: { type: 'string' },              // what a real tools/call returned via the Inspector CLI
    call_succeeded: { type: 'boolean' },                // the tool actually responded over the wire this pass
    resources_read_result: { type: 'string' },          // what resources/read returned, if resources are declared (else "n/a")
    prompts_get_result: { type: 'string' },             // what prompts/get returned, if prompts are declared (else "n/a")
    annotations_set: { type: 'boolean' },               // per-tool title + hints wired into the tool registration
    args_validated: { type: 'boolean' },                // boundary validation/sanitization implemented per Step 2b
    error_model_wired: { type: 'boolean' },             // recoverable failures return isError-in-result, not a leaked exception
    no_secrets_in_surface: { type: 'boolean' },         // no secret in any schema/description/resource/error text
    registration_cmd: { type: 'string' },               // the claude mcp add / desktop-config change (flags direct-fetch-verified)
    flags_verified_live: { type: 'boolean' },           // true if claude mcp add flags were direct-fetched, not hardcoded from the digest
    worktree_removed: { type: 'boolean' },              // meaningful when isolated; false/n-a when unisolated
    applied_directly_to_main_tree: { type: 'boolean' }, // honest disclosure flag for the unisolated path
  },
  required: ['track', 'files_written', 'stdout_clean', 'call_succeeded', 'worktree_removed', 'applied_directly_to_main_tree'],
}

const VERIFY_SCHEMA = {
  type: 'object',
  properties: {
    wire_verified: { type: 'boolean' },                 // a real tools/call round-tripped this pass
    primitives_verified: { type: 'array', items: { type: 'string' } }, // which declared primitives were round-tripped (tools/call, resources/read, prompts/get)
    stdout_hazard_checked: { type: 'boolean' },         // confirmed nothing writes to stdout in a stdio server
    schema_client_parseable: { type: 'boolean' },       // no $ref/union/loose-type hazards, descriptions present
    security_boundary_checked: { type: 'boolean' },     // Step 2b: args validated, least-privilege scoping, no poisoning/secrets, confused-deputy for HTTP
    annotations_present: { type: 'boolean' },           // per-tool title + hints set, destructive tools flagged honestly
    pitfalls_checked: { type: 'array', items: { type: 'string' } }, // which of the 6 pitfalls were actively checked
    open_items: { type: 'array', items: { type: 'string' } },       // auth, more tools, hardening -- what remains
    verdict: { type: 'string', enum: ['wire_confirmed', 'needs_work'] },
    reason: { type: 'string' },
  },
  required: ['wire_verified', 'stdout_hazard_checked', 'schema_client_parseable', 'verdict', 'reason'],
}

// --- Prompts ---

function preflightPrompt(target) {
  return `Before any scaffold is written, PROVE whether git-worktree isolation is actually possible for this ` +
    `target -- the build's whole safety guarantee depends on it, and assuming it works instead of proving it ` +
    `is exactly how a prior run silently edited a real main tree while claiming isolation. TARGET: ${target}\n\n` +
    `Run real commands, don't infer: (1) is the target path inside a git working tree at all (\`git -C <dir> ` +
    `rev-parse --is-inside-work-tree\`)? (2) is the target's OWN content actually tracked/committed, not just ` +
    `some ancestor directory (\`git -C <dir> ls-files -- <path>\`)? (3) ACTUALLY attempt \`git worktree add ` +
    `<scratch> HEAD\` and confirm with your own eyes that the target's real files are present in it, then ` +
    `remove it (\`git worktree remove --force\`, then prune) so this check leaves no trace. Report ` +
    `is_git_repo, target_tracked, can_isolate (true ONLY if step 3 actually proved it), and reason in plain ` +
    `language if can_isolate is false.`
}

function designPrompt(target, track, transport) {
  return `You are designing the wire surface of a new MCP (Model Context Protocol) server BEFORE any framework ` +
    `code is written. TARGET: ${target}\nTRACK: ${track}\nREQUESTED TRANSPORT: ${transport}\n\n` +
    `Design decisions, in order:\n` +
    `1. PRIMITIVE per thing exposed -- the spec has exactly three and the terminology maps to exactly these: ` +
    `TOOL (model-invoked function, each call needs user approval; anything with a side effect or computation), ` +
    `RESOURCE (client-read, file-like data addressed by URI; read-only context the model does not invoke), ` +
    `PROMPT (user-selected template). Decide per thing, not once for the whole server; state the rationale. ` +
    `For each TOOL also set annotations -- a human-readable title plus behavior hints the host gates approval ` +
    `on: readOnlyHint (no side effects), destructiveHint (mutates/deletes irreversibly -- flag it explicitly), ` +
    `idempotentHint (repeat calls safe -- a host may retry a failed/timed-out call, so a mutating tool marked ` +
    `idempotentHint:true must actually be safe under repeat via a dedup key or an upsert), openWorldHint ` +
    `(reaches network/fs beyond a fixed scope). Set them honestly; a destructive tool marked read-only defeats ` +
    `the host's guard.\n` +
    `2. TRANSPORT: stdio (local, single-client, host spawns a subprocess, no auth -- the simple default) or ` +
    `streamable-http (remote, single /mcp endpoint POST+GET, session via Mcp-Session-Id header, needs ` +
    `bearer/OAuth auth). The old two-endpoint HTTP+SSE transport is deprecated -- do not use it for anything ` +
    `new. Set needs_auth true for the HTTP case. For HTTP, also decide STATEFUL vs STATELESS: a Mcp-Session-Id ` +
    `should exist ONLY if the server carries per-connection state between calls (a subscription, an in-progress ` +
    `elicitation, a server-held cursor) -- otherwise run stateless (no session, each POST isolated). A stateful ` +
    `server pins a client to one process, so horizontal scaling forces session-affinity or a shared session ` +
    `store; set stateful and explain the choice (+ the scaling note if stateful) in session_rationale.\n` +
    `3. CAPABILITY NEGOTIATION: list exactly which capabilities the server will declare at initialize ` +
    `(tools/resources/prompts/sampling) -- declare exactly what it offers and no more; a client should not ` +
    `assume a capability it wasn't told about.\n` +
    `4. NEWER PRIMITIVES -- reach past the core three only when a feature needs them; list which you use and why ` +
    `in newer_primitives: roots (client-declared fs/URI boundaries a fs-touching server stays within), ` +
    `elicitation (server asks the USER for a value mid-call; needs a session), progress notifications ` +
    `(notifications/progress against a progressToken for any tool >~2s), resource subscriptions ` +
    `(resources/subscribe -> notifications/resources/updated; declare only if the server can actually detect ` +
    `changes), server-initiated sampling (sampling/createMessage back into the host model; declare 'sampling' ` +
    `only when a tool genuinely needs it, never to smuggle instructions past the user).\n` +
    `5. SECURITY (the produced server's OWN attack surface -- distinct from the build harness): tool ` +
    `descriptions/names/arg-docs are read by the host model, so treat them as an injection surface -- plain ` +
    `factual text, no hidden instructions, no over-eager "always call me" phrasing (tool-poisoning). Scope each ` +
    `tool to the NARROWEST capability (never a raw shell/eval/arbitrary-SQL/any-path tool). State per-tool ` +
    `arg_validation: how each arg is sanitized at the boundary (path traversal, command/SQL injection, SSRF ` +
    `from URL args) BEFORE it reaches real code. Never put a secret in a schema, description, resource content, ` +
    `or error text. For HTTP/OAuth set confused_deputy_handling: validate the token AUDIENCE (minted for THIS ` +
    `server, not forwarded through), pin exact redirect URIs, and never forward the host's credentials to a ` +
    `third party.\n` +
    `6. ERROR MODEL (error_model): an expected/recoverable failure (bad arg, not-found, upstream 4xx) returns a ` +
    `normal result with isError:true and MODEL-ACTIONABLE text; reserve protocol-level JSON-RPC errors ` +
    `(code/message/data) for genuine protocol faults (unknown method, malformed request). No stack traces, ` +
    `paths, or secrets in either channel -- error text is model-visible.\n\n` +
    `VERSION PIN -- confirm the current stable version LIVE, do not hardcode blindly:\n` +
    `- Python/FastMCP: the stable production line is v1.x; v2 is pre-release (mcp[cli]==2.0.0b1, targets the ` +
    `2026-07-28 spec) and NOT production-recommended. Pin mcp>=1,<2 unless Douglas asked for v2, and confirm ` +
    `the latest 1.x on PyPI at scaffold time.\n` +
    `- TypeScript: package @modelcontextprotocol/sdk (NOT the pre-release @modelcontextprotocol/server v2 ` +
    `beta); the exact current version could not be confirmed from secondary sources, so confirm the latest ` +
    `stable on npm live. Set version_confirmed_live true only if you actually checked.\n\n` +
    `Produce a language-appropriate build_plan (what files, what decorators/registerTool calls, the run/wiring ` +
    `code). Do NOT write files yet; this is the design pass. Report primitives, transport, needs_auth, ` +
    `declared_capabilities, version_pin, version_confirmed_live, and build_plan.`
}

function scaffoldPrompt(target, track, transport, design, isolated) {
  const isolationClause = isolated
    ? `Do all of this in a THROWAWAY GIT WORKTREE off the target's repo (git worktree add <tmp> HEAD) -- never ` +
      `the caller's main tree. Remove the worktree (git worktree remove --force) and prune when done; set ` +
      `worktree_removed=true only after confirming it's gone and the main tree's git status is unchanged. Set ` +
      `applied_directly_to_main_tree=false.`
    : `NO GIT ISOLATION IS AVAILABLE for this target (preflight proved it and Douglas explicitly authorized ` +
      `proceeding anyway). Write the scaffold DIRECTLY to the real target files -- there is no worktree and no ` +
      `diff-handback mechanism possible without one. State plainly which real files you wrote. Do NOT claim a ` +
      `worktree was used. Set worktree_removed=false and applied_directly_to_main_tree=true.`
  const trackClause = track === 'python'
    ? `PYTHON / FastMCP track:\n` +
      `- Package mcp (import mcp.server.fastmcp.FastMCP); install uv add "mcp[cli]" pinned per the design's ` +
      `version_pin (mcp>=1,<2). Decorators auto-derive schema: @mcp.tool() over a TYPE-HINTED function with a ` +
      `real docstring Args block (that IS the schema -- no manual JSON Schema), @mcp.resource("scheme://{param}") ` +
      `for URI-templated resources, @mcp.prompt() for prompts.\n` +
      `- CARDINAL STDIO RULE: never write to stdout in a stdio server -- any print()/stray output corrupts the ` +
      `JSON-RPC stream. Log to stderr or a file. Confirm nothing prints to stdout and set stdout_clean.\n` +
      `- Run with mcp.run(transport="${transport === 'http' ? 'streamable-http' : 'stdio'}"). set build_ran=true (no build step for Python).`
    : `TYPESCRIPT track:\n` +
      `- Package @modelcontextprotocol/sdk (npm install @modelcontextprotocol/sdk zod); import from ` +
      `@modelcontextprotocol/sdk/server/mcp.js and .../server/stdio.js. Pattern: new McpServer({name,version}) ` +
      `then server.registerTool(name, {description, inputSchema:{<zod fields>}}, async(args)=>({content:[{type:"text",text:...}]})).\n` +
      `- stdio wiring: new StdioServerTransport() then await server.connect(transport). console.log is FORBIDDEN ` +
      `(pollutes the JSON-RPC stream) -- use console.error. Confirm no console.log and set stdout_clean.\n` +
      `- Distribution plumbing: "type":"module" in package.json, a tsc build step, and a bin entry pointing at ` +
      `the BUILT js -- these three make npx <package> work. RUN the tsc build (set build_ran) before any ` +
      `Inspector test, so the Inspector runs the built JS, not stale/absent output.`
  return `Scaffold and LIVE-TEST an MCP server. TARGET: ${target}\nDESIGN: ${JSON.stringify(design)}\n\n` +
    `${isolationClause}\n\n${trackClause}\n\n` +
    `IMPLEMENT THE DESIGN'S SECURITY + METADATA, not just the happy path: wire each tool's annotations (title + ` +
    `readOnlyHint/destructiveHint/idempotentHint/openWorldHint) into the registration and set annotations_set; ` +
    `validate/sanitize every tool argument at the top of the handler per the design's arg_validation (path ` +
    `traversal, command/SQL injection, SSRF from URL args) and set args_validated; return recoverable failures ` +
    `as isError-in-result with model-actionable text (never a leaked exception/trace) and set error_model_wired; ` +
    `keep every secret out of schemas/descriptions/resource contents/error text (env only) and set ` +
    `no_secrets_in_surface. Keep tool descriptions plain and factual -- no hidden or "always call me" phrasing.\n\n` +
    `Then TEST IT LIVE with the MCP Inspector in CLI mode (this is the verifiable evidence the wire works, not ` +
    `"it should connect"): run \`npx @modelcontextprotocol/inspector --cli <server-launch-command> --method ` +
    `tools/list\` to confirm the tool is listed, then \`... --method tools/call --tool-name <X> --tool-arg ` +
    `k=v\` to actually invoke a tool and read what came back. Record the exact inspector_cmd, the ` +
    `tools_list_result, the tools_call_result, and set call_succeeded true only if a real tools/call actually ` +
    `round-tripped this pass. EXERCISE EVERY DECLARED PRIMITIVE: if the design declares resources, also run ` +
    `\`... --method resources/read --uri <uri>\` and record resources_read_result; if it declares prompts, run ` +
    `\`... --method prompts/get --prompt-name <P> --prompt-arg k=v\` and record prompts_get_result (use "n/a" ` +
    `for a primitive the server does not declare). Stop any Inspector/dev process you started.\n\n` +
    `REGISTRATION: prepare the claude mcp add command (Claude Code: \`claude mcp add <name> -- <cmd> <args...>\`, ` +
    `default LOCAL scope ~/.claude.json, or --scope user/project, or --transport http <url> for remote; Claude ` +
    `Desktop: the mcpServers {command,args} map in claude_desktop_config.json). The exact flag syntax/scope ` +
    `names are secondary-source-only in the digest -- DIRECT-FETCH the official mcp-quickstart doc and confirm ` +
    `the flags against it before finalizing the command; set flags_verified_live true only if you actually ` +
    `fetched and confirmed. Use ABSOLUTE paths in the registered args (relative paths silently fail). Report ` +
    `the registration_cmd. Do not commit.`
}

function verifyPrompt(target, track, scaffold) {
  return `Adversarially verify that this MCP server's WIRE actually works before it's reported as confirmed. ` +
    `You are skeptical by default. TARGET: ${target}\nTRACK: ${track}\nSCAFFOLD RESULT: ${JSON.stringify(scaffold)}\n\n` +
    `Confirm, or the verdict is 'needs_work':\n` +
    `1. WIRE VERIFIED -- a real tools/call round-tripped over the Inspector this pass (re-run the Inspector CLI ` +
    `tools/call yourself if the evidence is thin; do not take "call_succeeded" on faith). Set wire_verified.\n` +
    `Also RE-EXERCISE every non-tool primitive the server declares: resources/read for declared resources, ` +
    `prompts/get for declared prompts -- a declared capability that never round-tripped is unverified. Record ` +
    `which primitives you actually round-tripped in primitives_verified.\n` +
    `2. STDOUT HAZARD -- for a stdio server, confirm NOTHING writes to stdout (no stray print/console.log, no ` +
    `chatty library) -- this is the single most common silent-break. Set stdout_hazard_checked.\n` +
    `3. SCHEMA CLIENT-PARSEABLE -- the tool schema has parameter descriptions and avoids loose/Any types and ` +
    `$ref/union constructs some clients cannot parse. Set schema_client_parseable.\n` +
    `4. SECURITY BOUNDARY (Step 2b, the produced server's OWN attack surface) -- confirm tool args are ` +
    `validated/sanitized at the boundary (path traversal, command/SQL injection, SSRF), tools are least-` +
    `privilege (no raw shell/eval/arbitrary-path/arbitrary-SQL tool), tool descriptions are plain and ` +
    `poisoning-free (no hidden or "always call me" instructions), NO secret sits in any schema/description/` +
    `resource/error text, and (HTTP/OAuth only) token audience + redirect URIs are validated with no credential ` +
    `forwarding. Set security_boundary_checked. Also confirm per-tool annotations are present with destructive ` +
    `tools flagged honestly and set annotations_present.\n` +
    `Also actively walk the pitfalls checklist and record which you checked: stdout pollution, schema mistakes, ` +
    `forgetting the TS rebuild before pointing the host at build/, remote/HTTP auth, absolute-path args in host ` +
    `config, and the Step-2b attack-surface gaps. List open_items honestly -- auth not yet wired, more tools to ` +
    `add, a /spar hardening pass -- rather ` +
    `than claiming completeness. Do this read-only / in a throwaway worktree; never the main tree; leave git ` +
    `status clean; do not commit. Report verdict ('wire_confirmed' only if 1-4 all hold) and reason.`
}

// --- Run ---

log(`Preflight: proving whether git-worktree isolation is actually possible for ${TARGET}`)
const preflight = await agent(preflightPrompt(TARGET), { phase: 'Preflight', schema: PREFLIGHT_SCHEMA, label: 'preflight' })
const isolated = !!(preflight && preflight.can_isolate)

if (!isolated && !ALLOW_UNISOLATED) {
  return {
    target: TARGET,
    track: TRACK,
    isolated: false,
    preflight,
    stopReason: 'no_isolation_available',
    note: 'This target cannot be isolated in a git worktree (' +
      (preflight ? preflight.reason : 'the preflight agent did not return a usable result') + '). make-mcp ' +
      'refuses to silently fall back to writing the scaffold into the real tree. This needs Douglas\'s call: ' +
      'commit the target first and re-run for full isolation (recommended), or re-run with ' +
      'args.allowUnisolated=true to proceed without it (the scaffold gets written directly to the real files, ' +
      'no worktree and no diff to hand back).',
  }
}
if (!isolated && ALLOW_UNISOLATED) {
  log('No isolation available -- proceeding UNISOLATED per explicit allowUnisolated=true. The scaffold will be written directly to the real target, not handed back as a diff.')
}

log(`Design & Build: designing the MCP protocol surface for ${TARGET} (track=${TRACK}, transport=${TRANSPORT})`)
const design = await agent(designPrompt(TARGET, TRACK, TRANSPORT), { phase: 'Design & Build', schema: DESIGN_SCHEMA, label: 'design', model: 'opus' })

log(`Scaffold & Test: scaffolding the ${TRACK} server and live-testing it with the MCP Inspector`)
const scaffold = await agent(scaffoldPrompt(TARGET, TRACK, TRANSPORT, design, isolated), { phase: 'Scaffold & Test', schema: SCAFFOLD_SCHEMA, label: `scaffold-${TRACK}` })

log('Verify: adversarially confirming the wire actually works this pass')
const verify = await agent(verifyPrompt(TARGET, TRACK, scaffold), { phase: 'Verify', schema: VERIFY_SCHEMA, label: 'verify', model: 'opus' })

return {
  target: TARGET,
  track: TRACK,
  transport: TRANSPORT,
  isolated,
  preflight,
  design,
  scaffold,
  verify,
  wireConfirmed: !!(verify && verify.verdict === 'wire_confirmed'),
  stopReason: 'complete',
}
```

## Final report (what to tell Douglas)

- **Gate outcome first.** If the Step-1 gate fired install-instead, that IS the report: *"an existing server
  (`<name>`) already exposes this — install it with `claude mcp add`, no new build needed."* Do not follow a
  fired gate with a half-built scaffold.
- **What was built** — the track (Python/FastMCP or TS/official SDK), the transport (stdio or Streamable HTTP),
  the primitives chosen per thing exposed (tool/resource/prompt, with the rationale), the version actually
  pinned, and whether that version was confirmed live or taken from the digest.
- **What was registered** — the exact `claude mcp add` (or Claude Desktop config) command, the scope used
  (local/user/project), and **whether the flag syntax was direct-fetch-confirmed against the official
  mcp-quickstart doc** or is still carrying the digest's secondary-source values. A `--scope project` write to a
  git-committable `.mcp.json` is a change Douglas should see — call it out.
- **What was verified this pass** — the Inspector call results: `tools/list` showed the tool, and a real
  `tools/call` round-tripped (or did not). This is the measured evidence the wire works; report the actual
  result, not "it should connect."
- **Pitfalls checked** — which of the six (stdout pollution, schema client-parseability, TS rebuild, HTTP auth,
  absolute-path args, Step-2b server attack-surface gaps) were actively verified this pass.
- **What remains** — never "fully tested," "production-ready," or "complete." Mirror `/spar`'s "no new issues
  across the last 2 rounds" and `/probe`'s "verified this pass": report the open items honestly (auth not yet
  wired, more tools to add, schema hardening), and point at **`/spar` against the registered server** for the
  adversarial break-fix hardening pass, which is a different mechanism from this build-and-confirm-the-wire run.
- **Isolation status, stated plainly, every time — never assumed.** State whether the run was isolated (worktree
  proven, nothing touched the main tree) or unisolated (no repo / target untracked, Douglas explicitly
  authorized proceeding, scaffold written directly to the real files). Never say "worktree removed" unless
  isolation was actually proven this run.
- Full absolute path(s) of everything written or registered, per the standing Files-list convention. Confirm any
  trial worktree was removed and the main tree's `git status` is clean, and that any Inspector/dev process the
  run started was stopped.

---

*Tracked copy: also save this file to `claude-global-config/commands/make-mcp.md` (per the skills-are-tracked
convention) after a NASA scrub.*