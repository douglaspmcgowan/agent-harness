---
name: review-lenses
description: "Two review lenses for the failure categories nothing else covers — OBS/CONFIG (config-validation-at-boundary, config drift, secrets-in-logs-not-just-files, structured logging, failure instrumentation, unsafe defaults) and CONCURRENCY (lost-update read-modify-write, idempotency under at-least-once/retries, TOCTOU/write-skew, ordering, shared mutable state). Each lens is a ready-to-run prompt grounded in the domain canon (Google SRE, Charity Majors/Honeycomb, OWASP; Kleppmann DDIA, Stripe idempotency, the DB-concurrency-defects catalogue, ThreadSanitizer) — with a severity rubric, per-finding evidence requirement (repro or code-path trace, no vibes), a false-positive rule-out-the-guard discipline, and per-lens exit criteria. Point it at a repo or a diff. Meant to run on a SCHEDULE for load-bearing repos (weekly), since these are steady-state review concerns rather than per-diff ones — scheduling is one `scheduled-tasks` MCP call away (see bottom). Use when Douglas says 'run the review lenses', 'obs/config review', 'concurrency review', 'race-condition review', 'review-lenses', '/review-lenses'."
---

# /review-lenses [repo path] [--lens obs|concurrency|both]

The failure atlas found two categories with ZERO coverage in the harness — not manual-only, absent: observability
/ config validation, and concurrency / idempotency. They're steady-state properties of a codebase, so the right
cadence is a scheduled sweep of load-bearing repos, not a per-diff gate. This command holds the two lens prompts;
run them directly, or schedule them (bottom).

The lens prompts below are the deliverable — paste one at the model reviewing the target. Each is grounded in the
practitioner canon for its domain (cited at the bottom) so the review checks the mechanisms that actually catch
these bugs, not a generic once-over. Both lenses share the reporting discipline in the next section; read it first.

Adjacent skills: `/solo-review` and `panel-ultra-review` do open-ended per-target/per-diff review and read past
these two steady-state categories — `/solo-review` points here for exactly that reason. `/spar` attacks a target
adversarially and has its own `state-ordering` breaker lens for concurrency; these lenses are the scheduled,
non-adversarial counterpart — run them on a cadence, not as a one-time break-fix.

## How to report — the discipline both lenses run under
Every finding carries four fields and clears two gates. State this to the reviewing model verbatim; a finding
missing any of it is not a finding.

**Every finding:** `severity · file:line · the concrete fix · the principle it serves`. Do NOT rewrite the code —
review only, hand back the list.

**Severity rubric (assign one, defend it):**
- **blocker** — corrupts data, leaks a secret across a trust boundary, or double-applies an irreversible effect
  (double charge/send/delete) on a code path that real concurrent/retried traffic reaches. Ship-stopping.
- **major** — a real defect on a reachable path, but the blast radius is bounded (recoverable state, a leak of
  internal detail that isn't a secret, a race that degrades rather than corrupts).
- **minor** — a latent smell, a defense-in-depth gap, or a case gated behind something that makes it currently
  unreachable but one refactor from live. Worth fixing, not worth blocking.

**Evidence required — no vibes.** Each finding must carry ONE of: (a) a concrete reproduction (the request
sequence / interleaving that triggers it), or (b) a code-path trace naming the exact lines — for a race, the line
of the read AND the line of the conflicting write AND the two concurrent actors (which two requests/threads/tasks)
AND the interleaving that corrupts it. A finding that can't name the trace or the repro is a hunch; drop it or
label it explicitly `UNCONFIRMED — needs repro` and rank it below every evidenced finding. (This mirrors dynamic
race detection: a race is only real on an interleaving that can actually execute — Go's `-race`/ThreadSanitizer
reports are trusted precisely because each names the two accesses and the missing happens-before. You can't run
TSan on this target, so the code-path trace IS your happens-before argument — make it explicit.)

**False-positive discipline — rule out the guard before flagging.** Before writing a concurrency finding, confirm
the racing path is genuinely reachable concurrently (is the server actually multi-threaded / are there real
retries?) AND that no existing guard already closes it: a lock, an atomic op, a unique constraint, a
compare-and-set, an idempotency key, or single-threaded execution. Name the guard you checked and why it's
insufficient. An already-guarded path flagged as a race is the noise that gets the whole review ignored. Same for
OBS/CONFIG: a value validated one layer up, or a log line that's already redacted, is not a finding.

## Lens A — OBS / CONFIG
> Review this codebase for observability and configuration robustness, in the failure-category order below. For
> each finding follow the reporting discipline you were given (severity · file:line · fix · principle; evidence
> required; rule out existing guards first).
>
> 1. **Config validation at the boundary (fail fast, fail loud).** Is every config value — env var, config-file
>    key, CLI flag, secret handle — validated at STARTUP with a clear, specific error naming the missing/malformed
>    key, or does the app boot half-configured and fail late and cryptically deep inside a request? Flag any config
>    read with no presence/type/range check. Grep smells: `os.environ.get(...)` / `os.getenv` with no following
>    validation, `config[...]` reads scattered through request handlers rather than parsed once at boot, a default
>    silently substituted for a missing required value. Principle: treat configuration as code — parse-and-validate
>    once, at the edge, not lazily on the hot path (Google SRE, "treat your configuration as code").
> 2. **Config drift between environments.** Does the same key mean different things in dev vs prod, or does a
>    prod-only value (a real endpoint, a stricter timeout, a CUI/local-only flag) have no dev equivalent so the two
>    silently diverge? Flag config that isn't single-sourced/version-controlled, and any default that is safe in
>    dev but dangerous in prod. Grep smells: `if DEBUG`, `if os.environ.get("ENV") == ...` branches that change a
>    security-relevant behavior; hardcoded hosts/ports/paths that differ per machine.
> 3. **Secrets — in logs and errors, not just files.** Any secret, token, password, or key that is hardcoded,
>    checked into a config file, OR — the path reviews miss — echoed into a log line, an exception handler, a
>    stack trace, a verbose error response, or a debug dump of `os.environ`/request headers? A secret in a file is
>    the obvious case; a secret in a log or an error message is the one that leaks in production. Flag each. Grep
>    smells: `log/print(... key ...)`, `str(os.environ)`, exception handlers that serialize the whole request or
>    env, f-strings interpolating a variable named `*key*`/`*token*`/`*secret*`/`*password*` into a log. Principle:
>    OWASP Secrets Management — every secret read/exposure is an audit event; logs and build artifacts are primary
>    leak paths.
> 4. **Logging surface — structured, diagnosable, one event per unit of work.** On an error path, is enough logged
>    to diagnose the failure WITHOUT re-running it — what operation, which inputs (minus secrets), which failure —
>    ideally as one structured, high-cardinality event per request rather than scattered opaque string prints? Flag
>    (a) swallowed exceptions (`except: pass`, `except Exception: return None` with no log), (b) log lines that dump
>    request bodies / PII / secrets, and (c) errors logged as a bare string with no operation/id/context to pivot
>    on. Principle: wide structured events over ad-hoc string logs — you debug the unknown-unknowns by slicing on
>    high-cardinality context you captured up front (Charity Majors / Honeycomb).
> 5. **Are the failures that matter actually instrumented?** For each user-visible failure mode, is there a log or
>    signal that would let someone SEE it happened — or does it fail silently? This is the SRE production-readiness
>    question: "are all user-visible request failures well instrumented and monitored?" Flag any error path
>    (a rejected request, a swallowed 500, a degraded fallback, a dropped background task) that leaves no trace.
> 6. **Insecure or surprising defaults.** Debug mode on by default, permissive CORS, verbose/stack-trace errors
>    reaching the client, a trust-boundary check that defaults to allow, an auth/host guard off unless explicitly
>    enabled? Flag each with the safer default and note whether it crosses a trust boundary (internal detail —
>    paths, SQL, stack traces — reaching an untrusted client is at least major).
>
> **Exit criteria — a clean pass must have actually:** enumerated every config value the app reads and confirmed
> each is validated at a boundary; grepped for every secret-name pattern across log/error/exception paths (not just
> config files); checked every `except` block for silent swallowing; and named, for each user-visible failure mode,
> where it would be observed. "No findings" is only valid after those four sweeps ran — say which ran.

## Lens B — CONCURRENCY / IDEMPOTENCY
> Review this codebase for concurrency and idempotency defects, in the failure-category order below. For each
> finding follow the reporting discipline you were given — and for a race, the evidence MUST name the read line,
> the conflicting write line, the two concurrent actors, and the corrupting interleaving. Rule out existing guards
> (lock / atomic / unique constraint / CAS / idempotency key / single-threaded) before flagging.
>
> 1. **Lost update — read-modify-write on shared state.** Any fetch-then-modify-then-write cycle on shared state
>    (a counter, balance, status field, a whole JSON store/document, a list you append to) where two concurrent
>    cycles both read the old value and the second write clobbers the first? An ATOMIC write (write-the-whole-file
>    safely, a single `os.replace`) does NOT prevent this — it stops a torn/half-written file, but two readers who
>    both loaded the old contents still lose one update. Flag each; name the interleaving. Grep smells: `read_json`
>    /`load(...)` → mutate in Python → `write/replace(...)` with no lock spanning the read and the write; "read the
>    store, filter/append, write the store back" handlers. Safe forms: a lock held across the whole read-modify-write,
>    an atomic in-place operation (`UPDATE x SET n = n + 1`), or compare-and-set (write only if the value still
>    matches what you read). (Kleppmann DDIA §7; the DB-concurrency-defects catalogue — this is the single most
>    common one.)
> 2. **Idempotency under at-least-once / retries.** Can a retried, duplicated, or double-submitted request
>    (a client retry after a timeout, an at-least-once queue redelivery, a double-click, an SDK auto-retry with
>    exponential backoff) double-apply an effect — charge twice, send twice, insert twice, spawn two jobs? Flag any
>    state-mutating handler with no idempotency key, dedupe, or unique constraint. The hard case reviews miss:
>    ASYNC/queue work under at-least-once delivery, where the SAME message is legitimately delivered more than once
>    by design — the consumer must be idempotent, not the producer. Safe form (Stripe): a client-supplied
>    idempotency key, server caches the result (success AND failure) keyed by it, returns the cached result on
>    replay, and rejects a reused key carrying different parameters. Grep smells: POST handlers that create/charge/
>    enqueue with no dedupe key; queue consumers that `process(msg)` with no seen-set/unique-insert.
> 3. **Check-then-act / TOCTOU and write skew.** `if exists → create`, `if free → take`, `if not locked → lock`,
>    `if count < N → add` patterns with a gap between the check and the act, where two actors both pass the check
>    before either acts (double-booking, over-allocation, resurrecting a just-deleted record, two writers past a
>    "there can be only one" invariant)? This is write skew when each actor writes a DIFFERENT row but their
>    combination breaks a global constraint the per-row check couldn't see. Flag each and name the safe atomic form
>    (a unique constraint, `INSERT ... ON CONFLICT`, `SELECT FOR UPDATE` over the checked set, a lock covering both
>    the check and the act). (Kleppmann write-skew; DB-defects catalogue.)
> 4. **Ordering assumptions on an unordered transport.** Does any code assume events / callbacks / messages / async
>    completions arrive in the order sent, when the transport (a queue, threads, async tasks, webhooks, retries)
>    doesn't guarantee it? A retry alone reorders delivery. Flag reliance on ordering that isn't enforced, and any
>    "last write wins" that assumes the last write is the latest in real time.
> 5. **Shared mutable state without synchronization.** Module-level mutable globals, shared caches/memo dicts,
>    class attributes, or singletons mutated from concurrent requests/threads/async tasks with no lock? Include the
>    check-then-set-on-a-cache race (two misses both recompute and both write). Note honestly which are benign under
>    the language's atomicity guarantees (e.g. a single dict assignment under the CPython GIL) vs which genuinely
>    corrupt — a benign-but-fragile one is minor, a corrupting one is major/blocker. Grep smells: a module-level
>    `_CACHE = {}` / `_STATE = ...` written inside a handler; a `global` statement in a request path.
>
> **Exit criteria — a clean pass must have actually:** traced every write to shared/persistent state back to its
> read and confirmed a lock/atomic/CAS spans the pair; listed every state-mutating entry point and asked "what
> happens if this exact request arrives twice?"; and checked every module-level mutable global for concurrent
> writers. "No findings" is only valid after those three sweeps ran — say which ran, and name the guards that made
> a suspected race safe (proving you looked, not that there was nothing to look at).

## Sources these lenses are grounded in
OBS/CONFIG: Google SRE Book — [Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
(golden signals) and [the Production Readiness Review](https://sre.google/sre-book/evolving-sre-engagement-model/)
("are all user-visible failures instrumented?"), "treat your configuration as code"; Charity Majors / Honeycomb —
[structured wide events as the basis of observability](https://www.honeycomb.io/blog/structured-events-basis-observability);
OWASP — [Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
(secrets leak through logs/errors/artifacts, not just files). CONCURRENCY: Kleppmann, *Designing Data-Intensive
Applications* ch.7 (lost update, write skew, compare-and-set); the [DB concurrency-defects catalogue](https://www.ketanbhatt.com/p/db-concurrency-defects)
(grep-able smell → atomic fix per defect); [Stripe on idempotency keys](https://stripe.com/blog/idempotency)
(cache success+failure, param-match, at-least-once); Go race detector / [ThreadSanitizer](https://research.google.com/pubs/archive/35604.pdf)
(reports name the two accesses + missing happens-before — the evidence standard the lens borrows for its traces).

## Scheduling (do NOT fake it — this is the one real call)
These lenses are most useful as a recurring sweep of load-bearing repos. Schedule with the `scheduled-tasks` MCP,
one call, e.g. weekly:

```
mcp__scheduled-tasks__create_scheduled_task({
  name: "review-lenses weekly",
  schedule: "weekly",                      // pick the real cadence
  prompt: "/review-lenses <repo-path> --lens both"
})
```

No schedule is created by running this command — creating a standing scheduled task is a side-effectful config
change, so it's left as the explicit one-liner above for Douglas to fire when he picks the target repo + cadence.
