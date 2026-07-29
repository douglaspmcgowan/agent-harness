---
name: make-api
description: "Build a networked HTTP API service end to end, across two tracks (Python/FastAPI or TypeScript/Hono) and two styles (REST or GraphQL): design the contract FIRST (resource model, versioning, cursor pagination, RFC 9457 error envelope, auth off the URL, idempotency, an OpenAPI 3.1 spec as a deliverable), pick the framework from a decision table keyed on language + workload, scaffold the service, then LIVE-TEST it by starting the server on a loopback ephemeral port and making real HTTP calls that assert status codes + response shape + spec-conformance, behind an early GATE that refuses to build a network service where a library import or a CLI would do and that installs/points-at an existing API when one already covers the need. Adversarially re-checks the claims against the real files and reports what was verified this pass and what remains (auth hardening, a /spar security pass) rather than claiming production-ready. Use when Douglas says 'build an API', 'make a REST API', 'expose X over HTTP', 'stand up a web service for X', 'GraphQL API for X', '/make-api'."
---

# /make-api [target] [--track python|ts] [--style rest|graphql]

Building an HTTP API well is a contract decision before it is a coding job. A service that imports cleanly and
returns `200` for the happy path proves almost nothing — a caller depends on the URL shape, the status codes,
the error envelope, the pagination contract, and the auth scheme, and every one of those is a promise that
breaks integrations when it drifts. This command designs the contract on purpose (resources, versioning,
pagination, errors, auth), picks the framework the language and workload call for, scaffolds the service, then
actually starts it and makes real HTTP calls that assert the wire contract — reporting what that live check
verified this pass and what still needs a hardening pass.

**Deviate out loud.** This staged process is the well-reasoned default. When you genuinely judge that a
specific situation calls for a different move than this command prescribes, surface the divergence and your
reasoning to Douglas and let him decide, instead of silently complying or silently going your own way.

## What this is NOT

- **Not `/make-cli`.** A CLI is a command a human or a script runs in a terminal on the same machine. An API is
  a long-running network service other programs reach over HTTP from anywhere. If the only consumer is a human
  at a shell or a local script, a CLI is simpler and the Step-1 gate says so — reach for `/make-cli` instead of
  standing up a server nobody connects to remotely.
- **Not `/make-mcp`.** An MCP server exposes tools/resources/prompts to an AI *host* (Claude Desktop, Claude
  Code) over JSON-RPC, and the model invokes them. An API exposes endpoints to *any* HTTP client and a human or
  program calls them. They can coexist (an MCP server can call an API under the hood), but they are different
  wire contracts for different consumers. If the consumer is an AI host, that's `/make-mcp`.
- **Not `/connect`.** `/connect` is the orchestrator that looks at an app's whole scope, decides *which* of
  CLI / MCP / API it needs (possibly several, possibly none), and wires the results into the machine, the
  harness, and a data layer. This command builds ONE API when that decision has already been made — `/connect`
  calls it, not the reverse. If Douglas hasn't yet decided that an API is the right surface, start at
  `/connect`.
- **Not `/package`.** `/package` makes an existing system portable (a self-contained clonable repo). This
  builds a network surface onto a system. Different job.
- **Not `/hone`, `/probe`, or `/spar`.** Those harden, measure, or attack an *existing* target. This *creates*
  a new API and ends by handing off to them — a freshly scaffolded API with auth and untrusted input is exactly
  what `/spar` should attack next, and this command says so plainly rather than claiming the new service is
  already hardened.

## Procedure

### Step 0 — Resolve TARGET from ARGUMENTS

Needs enough that a subagent with ZERO conversation context could act alone. Establish four things and ask only
what isn't already obvious from the conversation:

- **What to expose** — which operations/resources of the underlying app become endpoints, and which are
  read-only (GET) versus mutating (POST/PUT/PATCH/DELETE). Rough shape is enough here; the contract gets
  designed properly in Step 2.
- **Who consumes it** — a first-party frontend, third-party developers, internal services, or another agent.
  This drives auth, versioning strictness, and whether the OpenAPI spec is a public deliverable.
- **The workload shape** — mostly I/O-bound (waiting on a DB, an LLM, other services) versus CPU-bound;
  request volume; whether it needs streaming. This drives the framework pick in Steps 3-4.
- **Language preference**, if any. Parse `--track python|ts` and `--style rest|graphql` if given; otherwise the
  Step-1 gate and the design pass choose from what's being wrapped and who consumes it.

If ARGUMENTS lacks what's needed and it isn't obvious from the conversation, ask what to expose, who consumes
it, and whether it's really a network service before proceeding — don't guess at an API surface.

### Step 1 — GATE: does this even need to be a network API, and does one already exist? (mandatory, before any scaffold)

This gate mirrors `/make-mcp`'s install-instead gate and `/make-cli`'s track classification: make the decision
that makes the whole build pointless-or-not BEFORE spending it.

1. **Does the consumer actually need HTTP over a network?** A network service adds a process to run, a port to
   secure, auth to get right, and an ops surface. If the only consumer is same-process code, a **library/module
   import** is the honest answer. If it's a human or a local script, a **CLI** (`/make-cli`) is. A network API
   is justified when there are *remote* clients, *multiple heterogeneous* clients, or a *language boundary* to
   cross over the wire. If none of those hold, the finding IS the answer: say so plainly — *"this doesn't need
   a network API; a library import (or `/make-cli`) covers every real consumer"* — and STOP. Do not stand up a
   server nobody connects to remotely just because "API" was the word used.
2. **Does an existing API/service already expose this?** If a maintained service already covers the need, point
   at it (configure a client against it) rather than reimplementing it, and STOP.
3. **If it's genuinely a new API, classify the style:**
   - **REST** — resource-oriented CRUD over HTTP verbs, wide client compatibility, cacheable, trivially
     debuggable with `curl`. The default for a public or heterogeneous-client API.
   - **GraphQL** — one endpoint, client-specified field selection; justified when clients need to shape widely
     varying responses and over-/under-fetching on a REST surface is a real, demonstrated pain. Don't reach for
     it by default — it trades caching simplicity and debuggability for query flexibility.
   - **RPC / typed-client (tRPC, Hono RPC)** — when the client is a first-party TypeScript frontend in the same
     repo and end-to-end type sharing is the actual goal, note it as an option; it is not a public-API shape.

   An explicit `--style` always wins over this heuristic if Douglas passed one.

Report which branch fired. A fired "doesn't need an API" or "already exists" gate is a complete answer on its
own; do not follow it with a half-built scaffold.

### Step 2 — API contract design (language-agnostic, before touching either track)

Design the wire contract before writing framework code. This is the load-bearing pass — every item below is a
promise a caller will depend on, and most of REST design in 2026 is no longer a matter of taste:

- **Resource model.** Plural, lowercase, hyphenated nouns (`/purchase-orders`, not `/getPurchaseOrders`); model
  the domain, not the database table names (coupling the URL to storage widens the attack surface and locks the
  schema). Keep nesting shallow — beyond ~3 levels is fragile. HTTP verbs carry the action; the URL names the
  thing.
- **Status codes that mean what they say.** `200/201/204` for success by shape, `400` malformed, `401`
  unauthenticated, `403` unauthorized, `404` absent, `409` conflict, `422` semantic-validation, `429`
  rate-limited, `5xx` server-side only. A caller decides retry/abort/escalate from the code — never return `200`
  with an error body.
- **Error envelope: RFC 9457 `application/problem+json`.** One consistent structured error shape, not ad-hoc
  strings. The five base fields — `type` (stable URI a client can branch on), `title`, `status`, `detail`,
  `instance` — served with `Content-Type: application/problem+json`, plus field-level validation errors naming
  which parameters failed so the caller fixes everything in one iteration. (RFC 9457 superseded RFC 7807 and is
  backward compatible.)
- **Versioning, decided up front.** URL-path `/v1/...` is easiest to route, cache, and debug and is the default;
  header/content-negotiation is an alternative when the audience needs it. Whichever: version from day one, and
  when a version deprecates, send deprecation + `Sunset` headers rather than breaking consumers silently.
- **Pagination: cursor by default at any real scale.** Opaque `next_cursor` tokens over indexed keys, not
  `OFFSET` (offset scans-and-discards and drifts under concurrent writes). Always **cap the page size**
  (`limit = min(requested, 100)`) and fetch one extra row to detect a next page. Reserve offset for small,
  bounded, random-access admin views.
- **Auth mechanism, chosen deliberately — and never on the URL.** Pick the scheme from who calls and how much
  assurance the boundary needs:

  | Scheme | Fits |
  |---|---|
  | **API key** (header) | Server-to-server, coarse-grained; simple, carries no user identity |
  | **OAuth2 / OIDC bearer + scopes** | Delegated user access or third-party apps acting for a user; scope-gated per endpoint |
  | **mTLS** | Service-to-service, high assurance; the client certificate is the identity |
  | **First-party session cookie** (`SameSite`) | A same-site browser frontend you own |

  Whichever fits: the credential rides the `Authorization` header (or the cookie for the session case), and a
  secret **never** appears in a query string or path segment (it leaks into logs, history, and referrers). State
  the scheme in the design; the scaffold wires the middleware, and the Verify pass confirms no secret rides the
  URL.
- **Idempotency for unsafe retries.** For POST/PUT that a client may retry, accept an `Idempotency-Key` header
  and de-dupe so a retry can't double-apply a side effect. Advertise retry semantics; honor `Retry-After` on
  `429/503`.
- **Concurrency & caching.** For updates that can collide, return an `ETag` on the GET and require `If-Match` on
  the write, rejecting a stale one with `412 Precondition Failed` (optimistic locking, so a slow client can't
  clobber a newer version). Set `Cache-Control` on cacheable GETs, and support conditional revalidation via the
  `ETag`, so clients and proxies skip re-fetching unchanged resources.
- **Async & long-running work.** An operation that outlives a normal request returns `202 Accepted` with a
  job-status resource (`/jobs/{id}`) the client polls for state and the eventual result. Offer webhooks as the
  push alternative when the client can receive callbacks — polling is simpler and firewall-friendly, webhooks
  cut latency and standing load. For a response produced incrementally, stream it over SSE or chunked transfer
  with the matching content type. Design this in whenever "streaming" or a slow upstream (an LLM, a batch job)
  is in scope.
- **Observability & resource limits.** Assign a correlation/request ID to every request (accept an inbound
  `X-Request-Id`, generate one when absent) and stamp it on every log line and the error `instance` so a
  caller's report is traceable. Expose a liveness `/healthz` and a readiness `/readyz` (readiness checks
  dependencies), and emit basic metrics. Cap request body size and set a per-request timeout so one caller can't
  exhaust the service (unrestricted-resource-consumption defense). Return `RateLimit-*` quota headers alongside
  the existing `429` + `Retry-After` so a client can self-throttle before it's rejected.
- **Boundary validation + CORS + rate limiting.** Validate and coerce every input at the edge (Pydantic /
  Zod / schema), not deep in handlers. Use parameterized/prepared statements and ORM binding for every
  data-store access; never assemble SQL/NoSQL/OS-command strings from request input. Set CORS deliberately
  (explicit origins, not `*`, for a credentialed API). Plan a rate-limit strategy: a token-bucket limiter
  (allows a burst up to bucket size, then refills at a steady rate) fits bursty client traffic; a
  sliding-window limiter fits a hard smooth-average cap. Pick from the traffic shape, even if the first cut
  is coarse.
- **The OpenAPI 3.1 spec is a deliverable, not a byproduct.** REST APIs ship a spec the design conforms to
  (FastAPI generates it; a TS track uses a schema-first or generated spec). GraphQL ships its SDL schema. The
  spec is what the live test asserts conformance against in Step 5.

### Step 2A — Authorization (distinct from authentication)

Authentication proves *who* is calling; authorization decides *what this caller may do to this specific
resource*. This is OWASP API Security's top three risks and the most common way a scaffolded API leaks data, so
design it explicitly and assume a valid token alone is never enough:

- **Object-level authorization (BOLA / IDOR).** Every request that names a resource by ID re-checks, on the
  server and from the session, that the authenticated caller actually owns or may access *that* object — an ID
  from the client is an untrusted claim. `GET /orders/123` returns the order only when it belongs to the caller,
  otherwise `404` (hiding existence) or `403`. Treat an ID the client supplies as an input to authorize, never
  as proof of ownership.
- **Function-level authorization.** Gate each endpoint by the role/scope it requires (an admin-only route
  refuses a normal token), enforced in one place every route passes through, so a newly added endpoint can't
  ship ungated by accident.
- **Mass-assignment defense.** Bind a request body through an explicit allowlist of writable fields; a DB model
  is never hydrated straight from client JSON, or a caller sets `role`, `owner_id`, or `is_admin` by adding a
  key. The Pydantic/Zod input model lists exactly the accepted fields; internal fields are set server-side.
- **SSRF defense.** Any outbound URL the API fetches or delivers to on the caller's behalf — a webhook callback
  target, a user-supplied upstream/fetch URL, an import-from-URL field — is validated against an allowlist of
  permitted hosts/schemes before the request goes out. Block private, link-local, and cloud-metadata IP ranges
  (`169.254.169.254`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `127.0.0.0/8`), and re-resolve/re-check
  on redirect rather than trusting the first-hop host.

The scaffold enforces all four; the Verify pass proves a cross-owner request (caller A asking for caller B's
resource) returns `403`/`404`, that an unexpected field in a request body is ignored rather than persisted, and
that a webhook/fetch URL pointed at a private or metadata address is rejected.

### Step 2B — GraphQL operational hardening (`--style graphql` only)

A GraphQL endpoint hands the client the query language, which moves several hazards server-side. On the GraphQL
branch, design these in from the start (they have no REST equivalent):

- **N+1 resolution.** Batch nested field resolution through a dataloader (per-request batching + caching) so a
  list-of-N query issues one backing query per level instead of N.
- **Query depth + complexity limiting.** Reject a query past a max depth and a max cost score *before*
  execution, so a deeply nested or expensive query can't exhaust the server.
- **Persisted / allowlisted queries.** In production, accept only pre-registered query hashes (or an explicit
  allowlist) so clients can't submit arbitrary expensive queries.
- **Introspection off in production.** Disable the introspection endpoint outside dev so the full schema isn't
  handed to every caller.

### Step 3 — Python track (FastAPI)

FastAPI is the 2026 greenfield default for a new Python API — async-first, Pydantic v2 models that ARE the
validation and the OpenAPI schema, first-class OpenAPI 3.1. Install with `uv add fastapi` (or
`pip install fastapi`); confirm the current version at scaffold time rather than hardcoding a patch.

- **Pydantic v2 models are the contract.** Request/response models derive validation AND the OpenAPI schema from
  one type-hinted class — write the model, that IS the spec. Use `response_model=` so responses are shaped and
  documented.
- **Async where it pays.** `async def` handlers for I/O-bound work (DB, LLM, upstream services); plain `def`
  (run in a threadpool) for CPU-bound. SQLAlchemy 2.x async or SQLModel for the data layer if one is needed.
- **RFC 9457 errors.** Return `application/problem+json` bodies (a custom exception handler mapping to the
  five-field shape), not FastAPI's default `{"detail": ...}` for anything a client branches on.
- **Serve it** with `uvicorn` for the dev/live-test run; note `gunicorn` + `UvicornWorker` (or Granian) as the
  production process manager — but the scaffold's job is the app, not the deploy.
- **Alternatives, only on a demonstrated reason:** Django/DRF when the app is admin-heavy with complex
  relational modeling and wants the ORM+admin+auth batteries; Litestar when FastAPI's dependency-injection
  overhead is a measured bottleneck. Default stays FastAPI unless the target argues otherwise.

### Step 4 — TypeScript track (Hono / decision table)

**Pick the framework from the table**, keyed on runtime target + workload + who the client is:

| Situation | Framework |
|---|---|
| Greenfield, edge/serverless or multi-runtime (Node/Bun/Deno/Workers), lean | **Hono** (Fetch-API-native, ~14kB, typed `hc` client) |
| Node, throughput/schema-validation-critical | **Fastify** (JSON-schema routes, TypeBox-typed handlers) |
| Existing Express codebase, or you need the widest middleware ecosystem | **Express** (v5) |
| Large app wanting an opinionated batteries-included structure (DI, modules) | **NestJS** |
| First-party TS frontend in the same repo, end-to-end type sharing is the goal | **tRPC** or **Hono RPC** (not a public-API shape) |

Hono is the 2026 greenfield default; don't migrate an existing Express app for a throughput gain that a DB
call erases. Then, on top of the framework:

- **Zod at the boundary** for request validation and inferred types; a schema-first setup (or a generator) so an
  OpenAPI spec exists for a REST surface.
- **RFC 9457 error middleware** — one error handler emitting `application/problem+json`, not per-route ad-hoc
  JSON.
- **The clig-equivalent HTTP hygiene** from Step 2 applies here identically: status codes, cursor pagination
  (capped), auth off the URL, CORS, idempotency headers.
- **`console.log` is fine here** (unlike the stdio-MCP rule) — but route logs through a structured logger to
  stderr/a sink, and never log secrets or full auth headers.

### Step 5 — Scaffold, start, and test live

**Start the server on loopback, an ephemeral port** (`127.0.0.1:0` or a high fixed port), never `0.0.0.0`
during the test — a test server must not be reachable off-box. Then make **real HTTP calls** (httpx / `curl` /
fetch) that assert the contract, because a compiling server proves nothing about the wire:

1. **Happy path** — a real request to a real endpoint returns the expected status and a body matching the
   response model/schema.
2. **Error path** — a malformed/unauthorized request returns the right status AND an `application/problem+json`
   body with the five fields (not a `200`, not an ad-hoc string).
3. **Contract conformance** — validate at least one response against the OpenAPI 3.1 spec (or run the GraphQL
   query against the SDL). The generated/authored spec and the running server must agree.
4. **Auth off the URL** — confirm the auth path takes the credential from the header, and that no endpoint
   accepts a secret via query string.

The passing HTTP calls are the verifiable evidence the contract holds this pass — an actual `2xx`/`4xx`
round-trip with an asserted body, not "it should serve." Stop the server process the test started and confirm
it's stopped before finishing.

### Step 6 — Verify and report

Re-check the claims against the real files (see the Workflow's adversarial verify phase), then report per
"Final report" below. Point Douglas at **`/spar` against the running API** for the adversarial break-fix
hardening pass — an API with auth, untrusted input, rate limits, and pagination is a rich target for
input-fuzzing, authz-bypass, and resource-exhaustion lenses, and that is a different mechanism from this
build-and-confirm-the-contract pass. Point at **`/probe`** for a measured test-quality pass on the scaffolded
tests.

## Procedure (how to run it)

1. Resolve TARGET, track, and style per Step 0.
2. **Run the Step-1 GATE FIRST, before the Workflow.** Deciding whether this even needs a network API (vs a
   library/CLI) and whether one already exists is cheap and short-circuits the whole build. If the
   "doesn't-need-an-API" or "already-exists" branch fires, report it and STOP — do not call the Workflow.
3. Otherwise **call the `Workflow` tool** with the script below verbatim, passing
   `args: { target: "<what to expose + consumers + workload>", track: "<python|ts>", style: "<rest|graphql>", allowUnisolated: false }`.
   This is an explicit skill-triggered Workflow use (per the Workflow tool's own rule) — no separate opt-in.
   - **The Design and adversarial Verify phases run on `model: 'opus'`** — Douglas's delegation policy reserves
     Opus for the load-bearing judgment (the contract design, whether the framework fits the workload, whether
     the live HTTP result actually proves the wire contract). The mechanical Scaffold + live-test phase stays on
     the default model.
   - The Workflow's first phase runs a **Preflight** that actually creates (and removes) a scratch worktree to
     PROVE isolation is possible rather than assuming it. If `stopReason` comes back `no_isolation_available`,
     this is Douglas's call, not yours: AskUserQuestion — commit the target first and re-run for full isolation
     (recommended), or proceed unisolated (the scaffold is written directly to the real files, no worktree, no
     diff to hand back). Only re-invoke with `allowUnisolated: true` after he answers.
4. **Report the result** per "Final report" below. Never say the API is "production-ready," "fully tested," or
   "secure" — report what the live HTTP calls verified this pass and what remains (auth hardening, rate-limit
   tuning, a `/spar` security pass).

## Safety constraints (apply every run, no exceptions)

- **Never run with elevated/bypass permissions.** A generic "build me an API" ask does not justify disabling the
  permission system; run at default tool permissions. If a safety layer or the classifier blocks an action
  mid-run, that is a correct block — narrow scope and try a different angle, don't route around it.
- **Bind the live-test server to loopback only, on an ephemeral/high port, and STOP it when done.** Never bind
  `0.0.0.0` (or any externally reachable interface) during the test — a scaffolded, unhardened API must not be
  reachable off-box. Confirm the process is stopped and the port is free before finishing.
- **Isolate the trial scaffold in a git worktree; never touch the caller's main tree — and PROVE isolation is
  possible before claiming it, never assume it.** `git worktree add` only carries COMMITTED content; an
  untracked or un-gitted target does not exist in a fresh worktree at all, so a run that assumes isolation can
  silently write the scaffold into the real tree while reporting "worktree removed." (Same class of bug found
  and fixed in `/probe`, `/hone`, `/make-cli`, and `/make-mcp`.) The Preflight phase creates and proves a
  worktree before any write; if isolation is impossible it STOPS and asks Douglas (commit the target first —
  recommended — or proceed unisolated, in which case the scaffold is written directly to the real files and the
  report must say so plainly, never "worktree removed"/"diff handed back" when that isn't what happened).
- **Never emit a secret via URL, flag, or committed default in the generated code.** The scaffolded API must
  take credentials from the `Authorization` header (or a secrets manager / env at runtime), never a query
  string, path segment, or a hardcoded key — a property of the output, checked in the Verify pass.
- **No real external side effects during the live test.** Point the test at a local/in-memory/ephemeral data
  store, never a shared production database or a third-party endpoint that mutates real state. Stay strictly
  scoped to the target: build only the API under construction, no touching unrelated processes, services, or
  shared state.
- **No commits.** Building means scaffolding, serving, and testing — never `git commit` / `git push`, unless
  Douglas separately asked.
- **Clean up when done.** Remove any trial worktree (`git worktree remove --force`) and prune, and confirm
  `git status` on the main tree shows nothing unexpected. **Delete a throwaway branch with `git branch -d`
  (safe delete), not `-D`** — this machine's `block-dangerous-bash.js` hook unconditionally blocks
  `git branch -D`. Run worktree-remove and branch-delete as two separate calls, never chained. If a branch
  genuinely can't be `-d`-deleted, leave it and note the dangling pointer rather than routing around the block.
- **Make only the change the build requires** — the API scaffold, its spec, and its tests. No unrelated
  refactors, no drive-by cleanup, no speculative extra endpoints beyond what was asked.
- **If the target keeps a tracked mirror elsewhere in this repo's convention** (e.g. this harness's `~/.claude`
  ↔ `claude-global-config` split), note it and leave the mirror sync to Douglas.

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'make-api',
  description: 'Build an HTTP API: preflight (prove isolation) -> Opus designs the wire contract (resources/versioning/pagination/RFC-9457 errors/auth/OpenAPI) -> scaffold the framework + live-test via real loopback HTTP calls -> Opus adversarially verifies the contract actually holds',
  phases: [
    { title: 'Preflight' },
    { title: 'Design' },
    { title: 'Scaffold & Test' },
    { title: 'Verify' },
  ],
}

const TARGET = args.target
const TRACK = args.track === 'ts' ? 'ts' : 'python'   // default python/FastAPI (2026 greenfield default)
const STYLE = args.style === 'graphql' ? 'graphql' : 'rest'
const ALLOW_UNISOLATED = args.allowUnisolated === true

// --- Phase schemas (JSON-schema-validated agent output, spar/hone/probe pattern) ---

const PREFLIGHT_SCHEMA = {
  type: 'object',
  properties: {
    is_git_repo: { type: 'boolean' },
    target_tracked: { type: 'boolean' },
    can_isolate: { type: 'boolean' },   // true ONLY if a real worktree was created and PROVEN, then removed
    reason: { type: 'string' },
  },
  required: ['is_git_repo', 'target_tracked', 'can_isolate', 'reason'],
}

const DESIGN_SCHEMA = {
  type: 'object',
  properties: {
    style: { type: 'string', enum: ['rest', 'graphql'] },
    resources: {                                        // per resource/operation: path + verb + rough purpose
      type: 'array',
      items: {
        type: 'object',
        properties: {
          path: { type: 'string' },
          method: { type: 'string' },
          purpose: { type: 'string' },
        },
        required: ['path', 'method', 'purpose'],
      },
    },
    versioning: { type: 'string' },                     // e.g. "url /v1" | "header negotiation"
    pagination: { type: 'string', enum: ['cursor', 'offset', 'none'] },
    page_size_capped: { type: 'boolean' },              // limit = min(requested, N)
    error_format: { type: 'string' },                   // must be "rfc9457 application/problem+json"
    auth_scheme: { type: 'string' },                    // "api-key-header"|"oauth2-bearer-scopes"|"mtls"|"session-cookie"|"none" -- chosen from caller+assurance, NEVER on the URL
    auth_off_url: { type: 'boolean' },                  // design keeps every credential off the URL
    authz_object_level: { type: 'boolean' },            // BOLA/IDOR: every by-ID request re-checks ownership server-side; client ID is never trusted
    authz_function_level: { type: 'boolean' },          // role/scope gate per endpoint, enforced in one shared place
    mass_assignment_guarded: { type: 'boolean' },       // request bodies bound through an explicit writable-field allowlist, never straight onto a DB model
    ssrf_guarded: { type: 'boolean' },                  // outbound webhook/fetch URLs allowlisted; private/link-local/metadata IP ranges blocked
    concurrency_control: { type: 'string' },            // ETag + If-Match optimistic locking (412 on stale write), or "n/a"
    caching: { type: 'string' },                        // Cache-Control on cacheable GETs + ETag revalidation, or "n/a"
    async_handling: { type: 'string' },                 // 202 + job-status resource / webhooks / SSE-chunked streaming, or "n/a"
    observability: { type: 'string' },                  // correlation/request IDs on every request+log line, health + readiness endpoints, basic metrics
    resource_limits: { type: 'string' },                // request body-size cap, per-request timeout, RateLimit-* quota headers
    graphql_hardening: { type: 'string' },              // dataloader/N+1, depth+complexity limit, persisted/allowlisted queries, introspection off in prod -- or "n/a" for rest
    idempotency: { type: 'string' },                    // how unsafe retries are de-duped, or "n/a"
    framework: { type: 'string' },                      // FastAPI | Hono | Fastify | Express | NestJS | ...
    framework_rationale: { type: 'string' },
    version_confirmed_live: { type: 'boolean' },        // framework version checked at scaffold time, not hardcoded
    spec_deliverable: { type: 'string' },               // "openapi 3.1" (rest) | "graphql sdl"
    build_plan: { type: 'string' },
  },
  required: ['style', 'resources', 'versioning', 'pagination', 'error_format', 'auth_scheme', 'auth_off_url', 'authz_object_level', 'authz_function_level', 'mass_assignment_guarded', 'framework', 'spec_deliverable', 'build_plan'],
}

const SCAFFOLD_SCHEMA = {
  type: 'object',
  properties: {
    track: { type: 'string', enum: ['python', 'ts'] },
    framework: { type: 'string' },
    files_written: { type: 'array', items: { type: 'string' } },   // absolute paths in the worktree (or real tree if unisolated)
    spec_written: { type: 'string' },                   // path to the generated/authored OpenAPI/SDL spec
    server_start_cmd: { type: 'string' },               // how the live-test started the server (loopback, ephemeral port)
    bound_loopback_only: { type: 'boolean' },           // confirmed NOT 0.0.0.0 during the test
    happy_path_result: { type: 'string' },              // the real HTTP call + status + body shape observed
    error_path_result: { type: 'string' },              // the real error call + status + problem+json body observed
    spec_conformance_result: { type: 'string' },        // response validated against the spec (or SDL query result)
    calls_succeeded: { type: 'boolean' },               // real HTTP round-trips actually happened this pass
    no_secret_on_url: { type: 'boolean' },              // confirmed no endpoint accepts a credential via query/path
    server_stopped: { type: 'boolean' },                // the test server process was stopped + port freed
    worktree_removed: { type: 'boolean' },              // meaningful when isolated; false/n-a when unisolated
    applied_directly_to_main_tree: { type: 'boolean' }, // honest disclosure flag for the unisolated path
  },
  required: ['track', 'files_written', 'bound_loopback_only', 'calls_succeeded', 'no_secret_on_url', 'server_stopped', 'worktree_removed', 'applied_directly_to_main_tree'],
}

const VERIFY_SCHEMA = {
  type: 'object',
  properties: {
    contract_verified: { type: 'boolean' },             // a real happy + error HTTP round-trip held this pass
    error_envelope_ok: { type: 'boolean' },             // error path returned RFC 9457 problem+json, not a 200/ad-hoc string
    spec_matches_server: { type: 'boolean' },            // the OpenAPI/SDL spec agrees with what the server actually returns
    auth_off_url_confirmed: { type: 'boolean' },         // re-checked: no credential rides a query string or path
    authz_enforced: { type: 'boolean' },                 // a cross-owner request (caller A -> caller B's resource) returned 403/404, not the object
    mass_assignment_blocked: { type: 'boolean' },        // an unexpected/privileged field in a request body was ignored, not persisted
    ssrf_guarded: { type: 'boolean' },                   // a webhook/fetch URL pointed at a private or metadata address was rejected, or "n/a" if no outbound calls
    pagination_capped: { type: 'boolean' },              // page size is bounded, not unbounded
    status_codes_meaningful: { type: 'boolean' },        // errors are 4xx/5xx by cause, not 200-with-error-body
    pitfalls_checked: { type: 'array', items: { type: 'string' } },
    open_items: { type: 'array', items: { type: 'string' } },   // auth hardening, rate limits, more endpoints, /spar
    verdict: { type: 'string', enum: ['contract_confirmed', 'needs_work'] },
    reason: { type: 'string' },
  },
  required: ['contract_verified', 'error_envelope_ok', 'auth_off_url_confirmed', 'authz_enforced', 'verdict', 'reason'],
}

// --- Prompts ---

function preflightPrompt(target) {
  return `Before any scaffold is written, PROVE whether git-worktree isolation is actually possible for this ` +
    `target -- the build's whole safety guarantee depends on it, and assuming it works instead of proving it ` +
    `is exactly how prior runs silently edited a real main tree while claiming isolation. TARGET: ${target}\n\n` +
    `Run real commands, don't infer: (1) is the target path inside a git working tree at all (\`git -C <dir> ` +
    `rev-parse --is-inside-work-tree\`)? (2) is the target's OWN content actually tracked/committed, not just ` +
    `some ancestor directory (\`git -C <dir> ls-files -- <path>\`)? (3) ACTUALLY attempt \`git worktree add ` +
    `<scratch> HEAD\` and confirm with your own eyes that the target's real files are present in it, then ` +
    `remove it (\`git worktree remove --force\`, then prune) so this check leaves no trace. Report ` +
    `is_git_repo, target_tracked, can_isolate (true ONLY if step 3 actually proved it), and reason in plain ` +
    `language if can_isolate is false.`
}

function designPrompt(target, track, style) {
  return `You are designing the WIRE CONTRACT of a new HTTP API BEFORE any framework code is written -- most of ` +
    `this is no longer a matter of taste in 2026. TARGET: ${target}\nTRACK: ${track}\nSTYLE: ${style}\n\n` +
    `Design decisions, in order:\n` +
    `1. RESOURCE MODEL: plural lowercase hyphenated nouns; model the domain not DB table names; nesting <=3 ` +
    `levels; HTTP verb carries the action. List each resource/operation as path + method + purpose.\n` +
    `2. STATUS CODES that mean what they say (2xx by shape, 400/401/403/404/409/422/429, 5xx server-only). ` +
    `NEVER 200-with-error-body.\n` +
    `3. ERROR ENVELOPE: RFC 9457 application/problem+json with the five fields (type as a stable branchable ` +
    `URI, title, status, detail, instance), Content-Type application/problem+json, plus field-level validation ` +
    `errors. Set error_format to exactly that.\n` +
    `4. VERSIONING: URL /v1 is the default (easiest to route/cache/debug); header negotiation is the ` +
    `alternative. Version from day one; deprecation + Sunset headers when a version retires.\n` +
    `5. PAGINATION: cursor by default at any real scale (opaque next_cursor over indexed keys, NOT offset which ` +
    `scans-and-discards and drifts under concurrent writes); ALWAYS cap page size (limit = min(requested,100)) ` +
    `and fetch one extra row to detect a next page. Set pagination + page_size_capped.\n` +
    `6. AUTH MECHANISM: choose from who calls + assurance needed -- API key header (server-to-server, coarse); ` +
    `OAuth2/OIDC bearer + scopes (delegated user or third-party access); mTLS (service-to-service high ` +
    `assurance, the client cert is the identity); first-party SameSite session cookie (same-site browser ` +
    `frontend you own). The credential rides the Authorization header (or the cookie); a secret NEVER appears in ` +
    `a query string or path (it leaks to logs/history/referrers). Set auth_scheme and auth_off_url=true.\n` +
    `7. AUTHORIZATION -- distinct from authentication, OWASP API Security #1-#3, the biggest miss: (a) ` +
    `OBJECT-LEVEL (BOLA/IDOR): every by-ID request re-checks server-side, from the session, that the caller owns ` +
    `or may access THAT object -- an ID from the client is an untrusted claim; a cross-owner access returns ` +
    `404/403. Set authz_object_level. (b) FUNCTION-LEVEL: role/scope gate per endpoint, enforced in one shared ` +
    `place so a new endpoint can't ship ungated. Set authz_function_level. (c) MASS-ASSIGNMENT: bind request ` +
    `bodies through an explicit writable-field allowlist (the Pydantic/Zod input model lists exactly the ` +
    `accepted fields); a DB model is never hydrated straight from client JSON, or a caller sets role/owner_id/` +
    `is_admin by adding a key. Set mass_assignment_guarded. (d) SSRF: any outbound URL the API fetches or ` +
    `delivers to on the caller's behalf (a webhook callback target, a user-supplied upstream/fetch URL) is ` +
    `checked against an allowlist of permitted hosts/schemes before the request goes out, and private/link-` +
    `local/cloud-metadata IP ranges (169.254.169.254, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8) ` +
    `are blocked, re-checked on redirect. Set ssrf_guarded (true, false, or "n/a" if the API makes no outbound ` +
    `calls on a caller's behalf).\n` +
    `8. IDEMPOTENCY: for POST/PUT a client may retry, accept an Idempotency-Key and de-dupe; honor Retry-After ` +
    `on 429/503.\n` +
    `9. CONCURRENCY & CACHING: for updates that can collide, return an ETag on GET and require If-Match on the ` +
    `write, rejecting a stale one with 412 Precondition Failed (optimistic locking); set Cache-Control on ` +
    `cacheable GETs + ETag revalidation. Set concurrency_control and caching.\n` +
    `10. ASYNC / LONG-RUNNING: an operation that outlives a normal request returns 202 Accepted + a job-status ` +
    `resource (/jobs/{id}) the client polls; webhooks are the push alternative when the client can receive ` +
    `callbacks (polling is simpler/firewall-friendly, webhooks cut latency+load); stream an incremental response ` +
    `over SSE or chunked transfer. Design this in whenever streaming or a slow upstream (LLM, batch job) is in ` +
    `scope. Set async_handling.\n` +
    `11. OBSERVABILITY & RESOURCE LIMITS: a correlation/request ID on every request (accept inbound ` +
    `X-Request-Id, generate when absent) stamped on every log line + the error instance; liveness /healthz + ` +
    `readiness /readyz + basic metrics; a request body-size cap + per-request timeout (unrestricted-resource-` +
    `consumption defense); RateLimit-* quota headers alongside 429 + Retry-After. Set observability and ` +
    `resource_limits.\n` +
    `12. BOUNDARY VALIDATION + CORS (explicit origins, not * for a credentialed API) + a rate-limit strategy.\n` +
    `13. IF STYLE IS GRAPHQL: design the operational hardening REST doesn't need -- dataloader batching against ` +
    `N+1, query depth + complexity limiting before execution, persisted/allowlisted queries in production, and ` +
    `introspection disabled in production. Set graphql_hardening (use "n/a" for a REST surface).\n\n` +
    `FRAMEWORK -- pick from the workload + track, and confirm the current version LIVE (do not hardcode a patch):\n` +
    `- Python: FastAPI is the 2026 greenfield default (async, Pydantic v2 models ARE the validation AND the ` +
    `OpenAPI 3.1 schema). Django/DRF only for admin-heavy relational apps; Litestar only if FastAPI DI is a ` +
    `MEASURED bottleneck.\n` +
    `- TypeScript: Hono is the greenfield default (Fetch-API-native, multi-runtime, typed hc client); Fastify ` +
    `for Node throughput/schema-validation; Express for an existing codebase / widest middleware; NestJS for a ` +
    `large opinionated app; tRPC/Hono-RPC ONLY for a first-party same-repo TS frontend (not a public API).\n` +
    `Give framework_rationale and set version_confirmed_live only if you actually checked.\n\n` +
    `SPEC DELIVERABLE: an OpenAPI 3.1 spec (REST) or the GraphQL SDL -- the design conforms to it and the live ` +
    `test asserts against it. Produce a language-appropriate build_plan (files, models/schemas, the error ` +
    `handler, the auth middleware, the run wiring). Do NOT write files yet. Report every schema field.`
}

function scaffoldPrompt(target, track, style, design, isolated) {
  const isolationClause = isolated
    ? `Do all of this in a THROWAWAY GIT WORKTREE off the target's repo (git worktree add <tmp> HEAD) -- never ` +
      `the caller's main tree. Remove the worktree (git worktree remove --force) and prune when done; set ` +
      `worktree_removed=true only after confirming it's gone and the main tree's git status is unchanged. Set ` +
      `applied_directly_to_main_tree=false.`
    : `NO GIT ISOLATION IS AVAILABLE (preflight proved it and Douglas explicitly authorized proceeding anyway). ` +
      `Write the scaffold DIRECTLY to the real target files -- there is no worktree and no diff-handback ` +
      `possible without one. State plainly which real files you wrote. Do NOT claim a worktree was used. Set ` +
      `worktree_removed=false and applied_directly_to_main_tree=true.`
  const trackClause = track === 'python'
    ? `PYTHON / FastAPI track: install fastapi (uv add fastapi) at a live-confirmed current version; Pydantic ` +
      `v2 request/response models that ARE the validation and OpenAPI schema (use response_model=); async def ` +
      `for I/O-bound handlers; a custom exception handler returning application/problem+json (the five RFC 9457 ` +
      `fields), NOT FastAPI's default {"detail":...}, for anything a client branches on. Serve with uvicorn on ` +
      `127.0.0.1 + an ephemeral/high port for the live test.`
    : `TYPESCRIPT track: use the framework the design picked (Hono is the greenfield default). Zod at the ` +
      `boundary for validation + inferred types; a schema-first / generated OpenAPI spec for a REST surface; ONE ` +
      `error middleware emitting application/problem+json (never per-route ad-hoc JSON). Route logs to a ` +
      `structured logger; never log secrets or full auth headers. Serve on 127.0.0.1 + an ephemeral/high port ` +
      `for the live test.`
  return `Scaffold and LIVE-TEST an HTTP API to this confirmed contract. TARGET: ${target}\nSTYLE: ${style}\n` +
    `DESIGN: ${JSON.stringify(design)}\n\n${isolationClause}\n\n${trackClause}\n\n` +
    `Build ONLY what the design specifies -- every resource/operation, the RFC 9457 error envelope, the auth ` +
    `middleware (credential from the Authorization header, NEVER a query string/path), cursor pagination capped ` +
    `at the design's limit, and the ${style === 'graphql' ? 'GraphQL SDL' : 'OpenAPI 3.1'} spec. Enforce ` +
    `AUTHORIZATION as designed: object-level ownership re-checked server-side on every by-ID request (a caller ` +
    `never reaches another owner's resource), function-level role/scope gating per endpoint, mass-assignment ` +
    `defense (bind bodies through the input model's writable-field allowlist, never straight onto a DB model), ` +
    `and SSRF defense on any outbound webhook/fetch URL (allowlist permitted hosts/schemes, block private/link-` +
    `local/cloud-metadata IP ranges). ` +
    `Wire the designed concurrency/caching (ETag + If-Match -> 412 on stale write, Cache-Control on cacheable ` +
    `GETs), async handling (202 + job-status / SSE) where in scope, and observability + resource limits ` +
    `(correlation ID on every request+log line, /healthz + /readyz, body-size cap, per-request timeout, ` +
    `RateLimit-* headers).${style === 'graphql' ? ' Apply the GraphQL hardening: dataloader batching, depth + complexity limits, persisted/allowlisted queries, introspection off in prod.' : ''} No speculative extra ` +
    `endpoints. Never emit a secret via URL/flag/hardcoded default.\n\n` +
    `Then TEST IT LIVE (a compiling server proves nothing): START the server on 127.0.0.1 + an ephemeral/high ` +
    `port (NEVER 0.0.0.0), set bound_loopback_only, and make REAL HTTP calls -- (a) a happy-path request ` +
    `returning the expected status + a body matching the response model (record happy_path_result), (b) a ` +
    `malformed/unauthorized request returning the right 4xx AND an application/problem+json body with the five ` +
    `fields, not a 200 or ad-hoc string (record error_path_result), (c) validate at least one response against ` +
    `the ${style === 'graphql' ? 'SDL' : 'OpenAPI'} spec (record spec_conformance_result), (d) confirm no ` +
    `endpoint accepts a credential via query/path (set no_secret_on_url), (e) an AUTHZ probe -- as caller A, ` +
    `request caller B's resource by ID and confirm it returns 403/404 (not the object), and POST a body with an ` +
    `unexpected privileged field (role/owner_id/is_admin) and confirm it is ignored, not persisted. Set ` +
    `calls_succeeded true only if real ` +
    `round-trips happened this pass. Point the API at a local/in-memory/ephemeral store -- NEVER a shared prod ` +
    `DB or a mutating third-party endpoint. STOP the server process and free the port (set server_stopped). Do ` +
    `not commit. Report every schema field.`
}

function verifyPrompt(target, track, scaffold) {
  return `Adversarially verify that this API's WIRE CONTRACT actually holds before it's reported as confirmed. ` +
    `You are skeptical by default -- a claim in the scaffold report is not evidence; a real HTTP round-trip is. ` +
    `TARGET: ${target}\nTRACK: ${track}\nSCAFFOLD RESULT: ${JSON.stringify(scaffold)}\n\n` +
    `Confirm, or the verdict is 'needs_work':\n` +
    `1. CONTRACT VERIFIED -- re-issue a real happy-path AND a real error-path HTTP call yourself (start the ` +
    `server on loopback if needed; do not take calls_succeeded on faith). Set contract_verified.\n` +
    `2. ERROR ENVELOPE -- the error path returned RFC 9457 application/problem+json with the five fields and a ` +
    `4xx/5xx status, NOT a 200-with-error-body or an ad-hoc string. Set error_envelope_ok.\n` +
    `3. SPEC MATCHES SERVER -- the OpenAPI 3.1 / GraphQL SDL spec agrees with what the server actually returns ` +
    `(a spec that lies is worse than none). Set spec_matches_server.\n` +
    `4. AUTH OFF THE URL -- re-check that NO endpoint accepts a credential via query string or path segment, ` +
    `and no secret is hardcoded in the source. Set auth_off_url_confirmed.\n` +
    `5. AUTHORIZATION (OWASP API #1-#3, prove it yourself) -- authenticate as caller A and request caller B's ` +
    `resource by ID: it MUST return 403/404, never B's object (object-level / BOLA); confirm role/scope gating ` +
    `refuses an under-privileged token on a gated endpoint; and POST a body carrying an unexpected privileged ` +
    `field (role/owner_id/is_admin) and confirm it is IGNORED, not persisted (mass-assignment). Set ` +
    `authz_enforced (true only if the cross-owner request was rejected) and mass_assignment_blocked. If the API ` +
    `takes a webhook/fetch URL from a caller, submit one pointed at a private or cloud-metadata address ` +
    `(169.254.169.254, 127.0.0.1, an internal RFC1918 host) and confirm it is rejected, not fetched. Set ` +
    `ssrf_guarded (or "n/a" if the API makes no outbound calls on a caller's behalf).\n` +
    `Also actively check: any data-store access uses parameterized/prepared statements or ORM binding rather ` +
    `than assembled query strings, pagination page size is bounded (pagination_capped), status codes are ` +
    `meaningful by cause (status_codes_meaningful), and record which pitfalls you walked (200-with-error-body, ` +
    `secret on the URL, BOLA/cross-owner access, mass-assignment via a spare body field, SSRF via a webhook/` +
    `fetch URL, SQL/NoSQL/command injection via unparameterized queries, unbounded pagination, spec/server ` +
    `drift, CORS wildcard on a credentialed API, offset-pagination drift, missing correlation ID, no body-size ` +
    `cap or request timeout, GraphQL introspection left on / no depth limit). List open_items HONESTLY -- auth ` +
    `hardening, rate limits not yet enforced, more endpoints, a /spar ` +
    `security pass -- rather than claiming completeness. Do this read-only / in a throwaway worktree; never the ` +
    `main tree; leave git status clean; stop any server you started; do not commit. Report verdict ` +
    `('contract_confirmed' only if 1-4 all hold) and reason.`
}

// --- Run ---

log(`Preflight: proving whether git-worktree isolation is actually possible for ${TARGET}`)
const preflight = await agent(preflightPrompt(TARGET), { phase: 'Preflight', schema: PREFLIGHT_SCHEMA, label: 'preflight' })
const isolated = !!(preflight && preflight.can_isolate)

if (!isolated && !ALLOW_UNISOLATED) {
  return {
    target: TARGET,
    track: TRACK,
    style: STYLE,
    isolated: false,
    preflight,
    stopReason: 'no_isolation_available',
    note: 'This target cannot be isolated in a git worktree (' +
      (preflight ? preflight.reason : 'the preflight agent did not return a usable result') + '). make-api ' +
      'refuses to silently fall back to writing the scaffold into the real tree. This needs Douglas\'s call: ' +
      'commit the target first and re-run for full isolation (recommended), or re-run with ' +
      'args.allowUnisolated=true to proceed without it (the scaffold gets written directly to the real files, ' +
      'no worktree and no diff to hand back).',
  }
}
if (!isolated && ALLOW_UNISOLATED) {
  log('No isolation available -- proceeding UNISOLATED per explicit allowUnisolated=true. The scaffold will be written directly to the real target, not handed back as a diff.')
}

log(`Design: designing the API wire contract for ${TARGET} (track=${TRACK}, style=${STYLE})`)
const design = await agent(designPrompt(TARGET, TRACK, STYLE), { phase: 'Design', schema: DESIGN_SCHEMA, label: 'design', model: 'opus' })

log(`Scaffold & Test: scaffolding the ${TRACK} API and live-testing it with real loopback HTTP calls`)
const scaffold = await agent(scaffoldPrompt(TARGET, TRACK, STYLE, design, isolated), { phase: 'Scaffold & Test', schema: SCAFFOLD_SCHEMA, label: `scaffold-${TRACK}` })

log('Verify: adversarially confirming the wire contract actually holds this pass')
const verify = await agent(verifyPrompt(TARGET, TRACK, scaffold), { phase: 'Verify', schema: VERIFY_SCHEMA, label: 'verify', model: 'opus' })

return {
  target: TARGET,
  track: TRACK,
  style: STYLE,
  isolated,
  preflight,
  design,
  scaffold,
  verify,
  contractConfirmed: !!(verify && verify.verdict === 'contract_confirmed'),
  stopReason: 'complete',
}
```

## Final report (what to tell Douglas)

- **Gate outcome first.** If the Step-1 gate fired "doesn't need a network API" (a library import or `/make-cli`
  covers every real consumer) or "an existing API already covers this," that IS the report — do not follow a
  fired gate with a half-built scaffold.
- **What was built** — the track (Python/FastAPI or TS/Hono/…), the style (REST/GraphQL), the framework and why
  it fit the workload, and whether its version was confirmed live or taken from memory.
- **The contract designed** — the resource model, versioning scheme, pagination (cursor, capped), the RFC 9457
  error envelope, and the auth scheme (confirmed off the URL).
- **What was verified this pass** — the actual HTTP calls: a happy-path `2xx` with the right body shape, an
  error-path `4xx` with an `application/problem+json` body, and a response validated against the OpenAPI/SDL
  spec. This is the measured evidence the contract holds; report the real results, not "it should serve."
- **Pitfalls checked** — which were actively verified (no 200-with-error-body, no secret on the URL, bounded
  pagination, spec/server agreement, CORS not wildcard on a credentialed API).
- **What remains** — never "production-ready," "fully tested," or "secure." Report the open items honestly (auth
  hardening, rate limits not yet enforced, more endpoints, observability), and point at **`/spar` against the
  running API** for the adversarial security break-fix pass (input-fuzzing, authz-bypass, resource-exhaustion
  lenses) and **`/probe`** for a measured test-quality pass — both different mechanisms from this
  build-and-confirm-the-contract run.
- **Isolation status, stated plainly, every time — never assumed.** Whether the run was isolated (worktree
  proven, nothing touched the main tree) or unisolated (no repo / target untracked, Douglas explicitly
  authorized proceeding, scaffold written directly to the real files). Never say "worktree removed" unless
  isolation was actually proven this run.
- Full absolute path(s) of everything written (including the OpenAPI/SDL spec), per the standing Files-list
  convention. Confirm any trial worktree was removed, the main tree's `git status` is clean, and the live-test
  server process was stopped and its port freed.

---

*Tracked copy: also save this file to `claude-global-config/commands/make-api.md` (per the skills-are-tracked
convention) after a NASA scrub.*
