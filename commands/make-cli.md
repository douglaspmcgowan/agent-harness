---
name: make-cli
description: "Build a command-line tool well, across two tracks: general CLI engineering (a real arg-parsing framework + the clig.dev hardening checklist) AND agentic CLIs on the Claude Agent SDK (query() loop, allowed_tools rail, hooks, mcp_servers, subagents, session resume, or the headless claude -p alternative). Runs a mandatory classification GATE first (deterministic CRUD/tool CLI -> Track A framework; exploration/judgment task worth an LLM loop -> Track B SDK; mixed -> Track A shell with a Track B agentic subcommand), refuses to force deterministic CRUD onto an agent loop, scaffolds in an isolated worktree, tests (golden-file/snapshot + exit-code matrix for Track A; a real end-to-end agent-loop invocation for Track B), adversarially re-checks the claims against the real files, and reports what was verified this pass and what remains before pointing at /spar or /probe for hardening. Verifies current Agent SDK package/API names by direct doc fetch rather than trusting stale memory. Use when Douglas says 'build a CLI', 'make a CLI', 'scaffold a command-line tool', 'build an agentic CLI', 'CLI on the Claude Agent SDK', '/make-cli'."
---

# /make-cli [target] [--track A|B|mixed] [--max-iterations N]

Building a CLI well is a set of decisions made on purpose, before the first line: which framework the command
count and audience call for, whether the task actually wants an LLM loop or a deterministic one, how output is
shaped so a human AND a script can both read it, and how the thing is shipped. This command classifies the CLI
first, scaffolds it against a real checklist rather than improvising the ergonomics, tests the parts that can
be tested deterministically, and re-checks its own claims against the files it wrote before reporting anything
as done.

**Deviate out loud.** This staged process is the well-reasoned default. When you genuinely judge that a
specific situation calls for a different move than this command prescribes, surface the divergence and your
reasoning to Douglas and let him decide, instead of silently complying or silently going your own way.

## What this is NOT

- **Not `/make-mcp`.** That builds an MCP *server* — a process that exposes tools to a host like Claude. This
  builds a *CLI* — a command a user or another program runs directly. An agentic CLI built here may *consume*
  MCP servers (see the `mcp_servers` wiring in Track B), but building the server is a different job with a
  different protocol. If Douglas wants to expose tools to a host rather than ship a runnable command, point him
  at `/make-mcp`.
- **Not the Claude Agent SDK documentation.** This is a build-and-harden procedure that ends with a runnable,
  tested CLI. The SDK docs are a reference; this command fetches them (Step 3) to confirm the current API, then
  builds against it. Reach for the docs directly when Douglas wants to understand an API surface rather than
  ship a tool.
- **Not `/engineer` or the generic Superpowers implementation skills.** Those implement arbitrary features.
  This is CLI-specific scaffolding: the framework decision table, the clig.dev basics checklist, the packaging
  tree, shell-completion generation. It carries knowledge those general skills do not.
- **Not `/hone`, `/probe`, or `/spar`.** Those three harden, measure, or attack an *existing* target. This
  *creates* a new CLI. It ends by handing off to them — a freshly scaffolded CLI is exactly the kind of thing
  worth sparring and probing once it exists, and this command says so plainly rather than claiming the new tool
  is already hardened.

## Procedure

### Step 0 — Resolve TARGET from ARGUMENTS

Needs enough that a subagent with ZERO conversation context could act alone. Establish four things: (1) the
**language** (Node/Python/Rust/Go/other); (2) the **audience** — developers, non-technical end users, or other
agents/programs calling it; (3) whether the task is **deterministic** (fixed inputs to fixed outputs) or wants
**agentic judgment** (exploration, open-ended reasoning, tool use decided at runtime); (4) the **distribution
target** — how it gets onto the machine that runs it. If ARGUMENTS lacks any of these and it isn't obvious from
the conversation (e.g. "make a CLI for the truss solver" right after discussing that Python package), ask which
of the four is unclear before proceeding. Do not guess at a language or an audience. Parse `--track A|B|mixed`
(if Douglas already decided) and `--max-iterations N` (default **3** — this is a scaffold pass, not an
open-ended loop).

### Step 1 — GATE: classify the CLI (mandatory, BEFORE scaffolding anything)

This gate mirrors `/hone`'s and `/probe`'s Step-2 gates: make the load-bearing decision before spending the
build. Route the target to exactly one:

- **Track A — deterministic CRUD/tool CLI.** Fixed commands with predictable inputs and outputs (a file
  converter, a deploy wrapper, a data query tool, a project scaffolder). The right tool is a real arg-parsing
  framework, run at default speed with no model in the loop. This is the common case.
- **Track B — agentic CLI on the Claude Agent SDK.** The task genuinely benefits from an LLM loop:
  exploration, judgment calls, tool use whose sequence is decided at runtime, natural-language input the user
  can't be expected to structure. The digest's own rule: the SDK suits exploration-and-judgment tasks.
- **Mixed — a Track A shell with a Track B agentic subcommand.** Most of the surface is deterministic commands
  (Track A framework), and one subcommand delegates to an agent loop. Build the shell as Track A and the one
  subcommand as Track B; they compose cleanly.

**Refuse to force deterministic CRUD onto an agent loop.** If the task is really fixed-input/fixed-output, an
LLM loop adds latency, cost, and non-determinism for nothing, and the honest classification is Track A. Say so
plainly rather than reaching for the SDK because it's novel. If the classification is genuinely ambiguous,
state which track you *suspect* and why, and let the design pass in the Workflow confirm or correct it. A
`--track` Douglas passed explicitly wins, but if it contradicts an obvious classification, flag the mismatch
before proceeding rather than silently building the wrong shape.

### Step 2 — Track A: general CLI engineering

**Pick the framework from the decision table**, keyed on language + command count + audience:

| Language | Situation | Framework |
|---|---|---|
| Node | lean, fewer than ~5 commands | **Commander** (fastest startup, ~18–25ms) |
| Node | validation-heavy | **yargs** |
| Node | 20+ commands, plugin platform | **oclif** (heavier startup, ~85–135ms — justified only at that scale) |
| Python | zero-dependency script | **argparse** (stdlib) |
| Python | production CLI, decorator style | **Click** (8.3.1; ~38.7% of Python CLI projects) |
| Python | type-hint-driven, modern | **Typer** (wraps Click) |
| Rust | any | **clap** (derive API) + thiserror/anyhow error split |
| Go | any | **cobra** (use `RunE` over `Run` so errors propagate) |

Then enforce the **clig.dev basics as a checklist** — every item is a scaffolding requirement, not a nicety:

- **Real arg-parsing library, never hand-rolled.** The framework above owns parsing.
- **`-h`/`--help` exists and is genuinely useful** — a synopsis, the flags with one-line descriptions, and at
  least one runnable example per command. Do not assume the framework's default `--help` is enough; check that
  every command's help actually documents its flags and shows an example, and add it where it's thin.
- **Prefer named flags over positional args.** Only the single obvious primary argument (the file to convert,
  the target to deploy) should be positional; everything else is a named flag. Positional order is invisible to
  the reader and unstable to extend.
- **Exit codes: zero on success, non-zero on failure.** A caller decides everything from this.
- **stdout for data, stderr for logs and errors.** So the data stream stays pipeable.
- **Dual output modes:** human-readable by default, a `--json`/`--plain` machine-readable mode, `-q`/`--quiet`
  and `-v`/`--verbose`. Hide stack traces by default; surface them under `-v`.
- **Actionable errors.** Every error message names the next step — the flag to pass, the file to fix, the
  command to run — alongside what failed. An error that only states the failure makes the user guess the remedy.
- **Idempotency / re-runnability.** Running the same command twice is safe: the second run either produces the
  same end state or clearly no-ops ("already exists, nothing to do"), rather than erroring or double-applying.
- **Reads stdin when input is piped.** When stdin is a pipe (not a TTY), accept the input stream as the data
  source (the `-` convention for "read stdin" where a file arg is expected). Stream output line-buffered so the
  tool works mid-pipe rather than only after it finishes.
- **Broken-pipe safety.** When a downstream reader closes early (`… | head`), handle `SIGPIPE`/`EPIPE` cleanly
  and exit quietly instead of dumping a traceback — restore default SIGPIPE in Python, swallow `EPIPE` on the
  stdout stream in Node.
- **TTY detection** (`isatty()`): color, animation, progress bars, and interactive prompts appear only when
  stdout/stdin are TTYs. Honor `NO_COLOR`, `--no-color`, `TERM=dumb`, and `--no-input`.
- **Destructive-action safety.** A command that deletes or overwrites confirms before acting when stdin/stdout
  is a TTY; when it is NOT a TTY (a pipe, CI), it requires an explicit `--force` or `--yes`/`-y` and otherwise
  exits non-zero without touching anything — so it never blocks waiting on input nobody will type, and never
  silently destroys in a script. Pair this with `--dry-run`/`-n` (print what would change, do nothing).
- **Config precedence chain:** flags > env vars > project `.env` > user config > system config. On POSIX put
  config/data in XDG Base Directory locations; on Windows use `%APPDATA%` for config and `%LOCALAPPDATA%` for
  cache/data (fall back to `%USERPROFILE%` if unset). The precedence chain is the same on both platforms; only
  the resolved directories differ.
- **Standard flag vocabulary:** `-a`/`--all`, `-f`/`--force`, `-y`/`--yes`, `-n`/`--dry-run`, `-q`/`--quiet`,
  `-v`/`--version`, `-h`/`--help`.
- **POSIX parsing conventions:** the `--` end-of-options terminator (everything after it is a positional, even
  if it looks like a flag), GNU-style short-flag clustering (`-abc` == `-a -b -c`), and `--flag=value` alongside
  `--flag value`. Verify the chosen framework enables these — check argparse and any manual-parsing path
  explicitly, since they may not support them out of the box.
- **Secrets via stdin or `--password-file`, never a flag or env var** (they leak into process listings and
  shell history).
- **Signal handling:** on Ctrl-C (`SIGINT`) AND on `SIGTERM` (the signal orchestrators, containers, and `kill`
  send on shutdown), print first, then clean up with a timeout; crash-only recovery so an interrupted run leaves
  recoverable state. Both signals share the same handler and the same cleanup deadline.
- **Packaging decision tree:** uvx/pipx for a Python-dev audience; PyInstaller/Nuitka (or PyApp) for
  non-technical end users; npx or a bundled binary for Node; a single static binary via
  `cargo build --release` / `go build` for Rust/Go. **Shell-completion generation is a required deliverable**,
  not optional.

### Step 3 — Track B: agentic CLI on the Claude Agent SDK

**First, confirm the current API by direct fetch — do not hardcode from memory.** The research these steps
rest on marks several SDK details as web-summary-only, unconfirmed by a primary fetch. Before scaffolding, the
design pass must `WebFetch` the official Agent SDK docs
(`https://code.claude.com/docs/en/agent-sdk/overview` and the migration guide) and confirm the current package
names, import surface, and option-type names against the live page. Build against what the fetch returns.

**Verified-current names to build against (confirm by fetch, then use):**

- **TypeScript:** `npm install @anthropic-ai/claude-agent-sdk`; import from `"@anthropic-ai/claude-agent-sdk"`.
- **Python:** `pip install claude-agent-sdk` (or `uv add claude-agent-sdk`), Python >= 3.10;
  `from claude_agent_sdk import query, ClaudeAgentOptions`.

**Deprecated `claude-code`-era names the skill must never emit** (flag them if seen, replace them): the npm
`@anthropic-ai/claude-code` package as an SDK source (it now ships only the CLI binary), the PyPI
`claude-code-sdk` package, `import claude_code_sdk`, and the `ClaudeCodeOptions` type. The rename to "Claude
Agent SDK" was announced 2025-09-29; the exact frozen version numbers of the old packages are unconfirmed by
primary fetch, so verify rather than quoting them.

**Core mechanisms to scaffold:**

- **The streaming loop:** `async for message in query(prompt=..., options=ClaudeAgentOptions(...))`, checking
  for the result (e.g. `isinstance(message, ResultMessage)` / `hasattr(message, "result")`).
- **`allowed_tools=[...]` as the default safety rail** — scope tools tightly by default.
  `permission_mode="acceptEdits"` (or looser) only when Douglas explicitly asks for it.
- **`HookMatcher(matcher="Edit|Write", hooks=[callback])`** for audit logging and guardrails.
- **`mcp_servers={"name": {"command": ..., "args": [...]}}`** to wire in MCP servers the agent should consume.
- **`AgentDefinition(description=..., prompt=..., tools=[...])`** for subagents, with `"Agent"` present in
  `allowed_tools`.
- **Session continuity:** capture `session_id` from the `SystemMessage` init event, resume via
  `ClaudeAgentOptions(resume=session_id)`.
- **Headless alternative for CI:** instead of embedding the SDK in-process, shell out to
  `claude -p "<prompt>" --allowedTools "..." --output-format stream-json --permission-mode ...`. Two distinct
  integration patterns — embed the loop, or shell out to the headless CLI — pick the one that fits the host.
- **`--bare` mode** to suppress local `.claude/` hook and plugin auto-discovery when shipping a production CLI
  (so an end user's stray local config can't alter the tool's behavior).

**A CLI an agent will actually call also obeys these** (they apply on top of Track A's basics when the
audience is other agents/programs):

- **Structured, machine-parseable success output.** Exit 0 with silence is not proof of success — emit a
  parseable result (JSON or an explicit status line) the caller can act on.
- **Differentiated exit codes** so a caller can decide retry vs. abort vs. escalate — a single generic `1` for
  every failure forces the caller to guess.
- **Actionable errors and idempotency still apply.** An agent caller re-runs and retries far more than a human;
  a re-run must be safe and every error must state the recovery step, so the caller can act without a human.

### Step 4 — Test

- **Track A:** golden-file/snapshot tests of stdout for the deterministic commands, plus an explicit
  **exit-code assertion matrix** — every command's success and failure paths, each asserting the exact exit
  code. A command whose failure exit code is untested is a command whose contract is unverified.
- **Track B:** a real **end-to-end invocation of the agent loop on a trivial task**, run in an isolated
  worktree — actually drive `query()` (or the headless `claude -p` path) through one small real turn and
  confirm the loop, the tool scoping, and the result-message handling behave, rather than asserting the code
  merely compiles.

### Step 5 — Verify and report

Re-check the claims against the real files (see the Workflow's adversarial verify phase), then report per
"Final report" below and point at `/spar` (adversarial break-fix) or `/probe` (test-quality pass) for
hardening the new tool.

## Procedure (how to run it)

1. Resolve TARGET, track, and `max_iterations` per Step 0.
2. **Run the Step-1 GATE yourself first**, before the Workflow — the classification is a cheap judgment and it
   selects everything downstream. If Douglas passed `--track` and it matches the obvious classification, carry
   it forward; if it contradicts, flag the mismatch and get his call before building.
3. **Call the `Workflow` tool** with the script below verbatim, passing
   `args: { target: "<resolved target + language + audience + distribution>", track: "<A|B|mixed>", maxIterations: <N>, allowUnisolated: false }`.
   This is an explicit skill-triggered Workflow use (per the Workflow tool's own rule) — no separate opt-in.
   The script runs a **Preflight** phase that actually creates (and removes) a scratch worktree to PROVE
   isolation is possible before writing anything. If `stopReason` comes back `no_isolation_available`, that is
   Douglas's call: AskUserQuestion — scaffold into a fresh committed directory (recommended), or proceed
   unisolated (files written directly to the real tree, stated plainly). Only re-invoke with
   `allowUnisolated: true` after he answers.
   - **The Design & Build pass and the adversarial Verify pass run on `model: 'opus'`** — Douglas's delegation
     policy reserves Opus for the load-bearing judgment (confirming the track, picking the framework, and for
     Track B confirming the current SDK API against the fetched docs before emitting a single import). The
     mechanical Scaffold phase stays on the default model.
4. **Report the result** per "Final report" below. Never say "production-ready" — report what was scaffolded,
   what was verified this pass, and what remains, the way `/spar` reports "no new issues across the last 2
   rounds" rather than "unbreakable."

## Safety constraints (apply every run, no exceptions)

- **Never run with elevated/bypass permissions.** A generic "build me a CLI" ask does not justify disabling
  the permission system; run at default tool permissions. If a safety layer or the classifier blocks an action
  mid-run, that is a correct block — narrow scope and try a different angle, do not route around it.
- **Isolate ALL scaffolding in a throwaway git worktree; never touch the caller's main tree — and PROVE
  isolation is possible before claiming it, never assume it.** `git worktree add` only carries COMMITTED
  content; an untracked or un-gitted target directory does not exist in a fresh worktree at all, so a run that
  assumes isolation can silently write into the real tree while reporting "worktree removed." (Same class of
  bug found and fixed in `/probe` and `/hone` on 2026-07-07.) The Preflight phase creates and proves a
  scratch worktree before any write. If it can't, STOP and ask Douglas.
- **Stay strictly scoped to the target.** Scaffold only the requested CLI and its tests; no touching unrelated
  processes, files, or services; no destructive or irreversible action on anything shared.
- **Clean up when done.** Remove every worktree (`git worktree remove --force`) and prune, and confirm
  `git status` on the main tree shows nothing unexpected before finishing. **Delete a throwaway branch with
  `git branch -d` (safe delete), not `-D`** — this machine's `block-dangerous-bash.js` hook unconditionally
  blocks `git branch -D`. Run worktree-remove and branch-delete as two separate calls, never chained. If a
  branch genuinely can't be `-d`-deleted, leave it and note the dangling pointer in the report rather than
  routing around the block.
- **The scaffold is handed back for Douglas to place — not committed.** Report what was written and where; do
  not `git commit` / `git push` unless Douglas separately asked.
- **Make only what the request requires** — the CLI, its checklist items, its tests. No unrelated refactors,
  no speculative extra commands, no drive-by cleanup beyond the tool being built.
- **Never emit a secret via flag or env var** in any generated code — the generated CLI must take secrets via
  stdin or `--password-file`, per the Track A checklist. This is a property of the scaffolded output, checked
  in the Verify pass.
- **If the target keeps a tracked mirror elsewhere in this repo's convention** (e.g. this harness's
  `~/.claude` ↔ `claude-global-config` split), note it and leave the mirror sync to Douglas.

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'make-cli',
  description: 'Build a CLI well across two tracks (general CLI engineering / Claude Agent SDK agentic CLI): preflight (prove isolation) -> Opus design+build decision -> scaffold+test (per track) -> Opus adversarial verify of the claims against the real files',
  phases: [
    { title: 'Preflight' },
    { title: 'Design & Build' },
    { title: 'Scaffold' },
    { title: 'Verify' },
  ],
}

const TARGET = args.target
const TRACK = ['A', 'B', 'mixed'].includes(args.track) ? args.track : 'unclassified'
const MAX_ITERATIONS = args.maxIterations || 3
const ALLOW_UNISOLATED = args.allowUnisolated === true

// --- Phase schemas (JSON-schema-validated agent output, spar/hone/probe pattern) ---

const PREFLIGHT_SCHEMA = {
  type: 'object',
  properties: {
    is_git_repo: { type: 'boolean' },
    target_tracked: { type: 'boolean' },   // the scaffold dir's parent is a tracked git tree we can worktree off
    can_isolate: { type: 'boolean' },       // true ONLY if a real worktree was created and PROVEN, then removed
    reason: { type: 'string' },
  },
  required: ['is_git_repo', 'target_tracked', 'can_isolate', 'reason'],
}

const DESIGN_SCHEMA = {
  type: 'object',
  properties: {
    confirmed_track: { type: 'string', enum: ['A', 'B', 'mixed'] },
    track_correction: { type: 'string' },       // '' if the passed track held, else why it was corrected
    language: { type: 'string' },
    audience: { type: 'string', enum: ['developers', 'end_users', 'agents', 'mixed'] },
    framework: { type: 'string' },               // Track A pick from the decision table (or 'n/a' for pure B)
    framework_rationale: { type: 'string' },      // why this framework given language + command count + audience
    sdk_api_confirmed_by_fetch: { type: 'boolean' }, // Track B/mixed: did the pass WebFetch the live SDK docs?
    sdk_api_notes: { type: 'string' },            // Track B/mixed: current package/import/option names as fetched
    integration_pattern: { type: 'string' },      // Track B: 'embed_sdk_loop' | 'headless_claude_p' | 'n/a'
    checklist_plan: { type: 'array', items: { type: 'string' } }, // which clig.dev/agentic items this CLI will satisfy
    destructive_commands: { type: 'array', items: { type: 'string' } }, // commands that delete/overwrite -> need confirm/--force/--yes + --dry-run
    destructive_safety_plan: { type: 'string' }, // TTY-confirm; non-TTY requires --force/--yes else non-zero; paired with --dry-run
    idempotency_plan: { type: 'string' },        // how a second identical run stays safe / no-ops
    actionable_errors_plan: { type: 'string' },  // errors state the next step (flag/file/command), not just the failure
    stdin_pipe_plan: { type: 'string' },         // reads piped stdin, streams line-buffered output, handles SIGPIPE/EPIPE
    signals_plan: { type: 'string' },            // SIGINT AND SIGTERM share one handler + cleanup-with-timeout
    config_dirs_plan: { type: 'string' },        // XDG on POSIX, %APPDATA%/%LOCALAPPDATA% on Windows; same precedence chain
    packaging: { type: 'string' },                 // chosen path from the packaging tree + shell-completion plan
    build_plan: { type: 'string' },
  },
  required: ['confirmed_track', 'language', 'audience', 'checklist_plan', 'build_plan'],
}

const SCAFFOLD_SCHEMA = {
  type: 'object',
  properties: {
    files_written: { type: 'array', items: { type: 'string' } }, // absolute paths in the worktree (or main tree if unisolated)
    entry_point: { type: 'string' },
    commands: { type: 'array', items: { type: 'string' } },
    tests_written: { type: 'array', items: { type: 'string' } },
    test_kind: { type: 'string' },                 // 'golden_file+exit_code_matrix' (A) | 'agent_loop_e2e' (B)
    test_result: { type: 'string' },               // what running the tests actually produced this pass
    completion_generated: { type: 'boolean' },      // shell-completion deliverable (Track A / mixed)
    help_flag_present: { type: 'boolean' },          // -h/--help exists and documents flags + shows an example
    destructive_safety_present: { type: 'boolean' }, // TTY-confirm + non-TTY-requires-force/yes + --dry-run wired for destructive cmds (n/a -> true if none)
    stdin_pipe_handled: { type: 'boolean' },         // reads piped stdin + streams output + SIGPIPE/EPIPE clean
    sigterm_handled: { type: 'boolean' },            // SIGTERM handled alongside SIGINT
    worktree_removed: { type: 'boolean' },           // must be true before finishing when isolated
    applied_directly_to_main_tree: { type: 'boolean' }, // honest disclosure flag for the unisolated path
    diff: { type: 'string' },                        // the scaffold as a diff, for handback
  },
  required: ['files_written', 'entry_point', 'worktree_removed', 'applied_directly_to_main_tree'],
}

const VERIFY_SCHEMA = {
  type: 'object',
  properties: {
    checklist_verified: {                            // each claimed checklist item re-checked against the real files
      type: 'array',
      items: {
        type: 'object',
        properties: {
          item: { type: 'string' },
          present: { type: 'boolean' },              // actually found in the scaffolded code, not just claimed
          evidence: { type: 'string' },
        },
        required: ['item', 'present'],
      },
    },
    no_deprecated_sdk_names: { type: 'boolean' },     // Track B/mixed: confirmed no claude-code-era names emitted
    no_secrets_via_flag_or_env: { type: 'boolean' },  // confirmed generated CLI takes secrets via stdin/--password-file
    exit_codes_differentiated: { type: 'boolean' },   // non-zero paths distinguishable (matters most for agent audience)
    help_flag_useful: { type: 'boolean' },            // -h/--help present and documents flags + shows an example
    destructive_nontty_requires_force: { type: 'boolean' }, // ASSERTED: a destructive cmd without --force/--yes in a non-TTY exits non-zero, does NOT proceed (n/a -> true if none)
    idempotent_rerun: { type: 'boolean' },            // a second identical run is safe / no-ops rather than erroring or double-applying
    errors_actionable: { type: 'boolean' },           // error messages name the next step, not just the failure
    stdin_pipe_and_sigpipe_ok: { type: 'boolean' },   // reads piped stdin + survives a closed downstream reader (| head) without a traceback
    sigterm_handled: { type: 'boolean' },             // SIGTERM cleans up with the same discipline as SIGINT
    tests_actually_ran: { type: 'boolean' },
    tests_evidence: { type: 'string' },
    gaps: { type: 'array', items: { type: 'string' } }, // claimed-but-missing or still-open items
    verdict: { type: 'string', enum: ['scaffolded', 'incomplete'] },
    reason: { type: 'string' },
  },
  required: ['checklist_verified', 'tests_actually_ran', 'gaps', 'verdict'],
}

// --- Prompts ---

function preflightPrompt(target) {
  return `Before any scaffolding begins, PROVE whether git-worktree isolation is actually possible for where ` +
    `this CLI will be built -- this command's entire safety guarantee depends on it, and assuming it works ` +
    `instead of proving it is exactly how prior runs silently wrote to a real main tree while claiming ` +
    `isolation. TARGET: ${target}\n\n` +
    `Do not infer from paths -- run real commands: (1) is the intended build location inside a git working ` +
    `tree at all (\`git -C <dir> rev-parse --is-inside-work-tree\`)? (2) is its content actually tracked/` +
    `committed, not just some ancestor directory (\`git -C <dir> ls-files -- <path>\`)? (3) ACTUALLY attempt ` +
    `\`git worktree add <scratch> HEAD\` and confirm with your own eyes (ls / Read) that the real files are ` +
    `present in it, then remove it (\`git worktree remove --force\`, then prune) so this check leaves no ` +
    `trace. Report is_git_repo, target_tracked, can_isolate (true ONLY if step 3 actually proved it), and ` +
    `reason in plain language if can_isolate is false.`
}

function designPrompt(target, track) {
  return `You are designing a command-line tool before a single file is scaffolded. TARGET: ${target}\n` +
    `Suspected track from the caller's gate: ${track}.\n\n` +
    `CONFIRM OR CORRECT THE TRACK. Track A = a deterministic CRUD/tool CLI built on a real arg-parsing ` +
    `framework, no LLM in the loop. Track B = an agentic CLI on the Claude Agent SDK, for exploration/judgment ` +
    `tasks that genuinely benefit from an LLM loop. Mixed = a Track A shell with one Track B agentic ` +
    `subcommand. REFUSE to force deterministic fixed-input/fixed-output work onto an agent loop -- if the task ` +
    `is really deterministic, the honest answer is Track A even if B was suggested. Set track_correction if you ` +
    `change it, with the reason.\n\n` +
    `FOR TRACK A / mixed: pick the framework from this table by language + command count + audience -- Node: ` +
    `Commander (<5 cmds, fastest startup), yargs (validation-heavy), oclif (20+ cmds, plugin platform); ` +
    `Python: argparse (zero-dep script), Click (production, decorator), Typer (type-hint-driven, wraps Click); ` +
    `Rust: clap derive + thiserror/anyhow; Go: cobra with RunE over Run. Give framework_rationale. Plan the ` +
    `clig.dev basics as checklist_plan: real arg lib (never hand-rolled), a genuinely useful -h/--help ` +
    `(synopsis + per-flag descriptions + a runnable example, do not assume the framework default suffices), ` +
    `named flags over positional (only the one obvious primary arg is positional), zero/non-zero exit codes, ` +
    `stdout=data / stderr=logs+errors, a --json/--plain machine mode + -q/-v (hide stack traces by default), ` +
    `ACTIONABLE errors (every message names the next step -- flag/file/command -- not just the failure), ` +
    `IDEMPOTENT re-runs (a second identical run is safe / clearly no-ops), STDIN/pipe friendliness (read piped ` +
    `stdin via the '-' convention, stream output line-buffered so it works mid-pipe, handle SIGPIPE/EPIPE ` +
    `cleanly when a downstream reader like | head closes early -- restore default SIGPIPE in Python / swallow ` +
    `EPIPE on stdout in Node), TTY detection (isatty) gating color/prompts/progress + honor NO_COLOR/--no-color` +
    `/TERM=dumb/--no-input, DESTRUCTIVE-ACTION safety (confirm before delete/overwrite when TTY; when NOT a TTY ` +
    `require explicit --force or --yes/-y else exit non-zero without acting; pair with --dry-run/-n -- name the ` +
    `destructive_commands, the destructive_safety_plan, idempotency_plan, actionable_errors_plan, and ` +
    `stdin_pipe_plan), config precedence (flags > env > project .env > user config > system -- same chain on ` +
    `both platforms; XDG dirs on POSIX, %APPDATA% for config + %LOCALAPPDATA% for cache/data on Windows, per ` +
    `config_dirs_plan), standard flags (-a/--all, -f/--force, -y/--yes, -n/--dry-run, -q/--quiet, -v/--version, ` +
    `-h/--help), secrets via stdin/--password-file (NEVER flag/env), SIGNAL handling for BOTH SIGINT AND SIGTERM ` +
    `sharing one handler (print-first then cleanup-with-timeout, crash-only recovery) per signals_plan. Choose a ` +
    `packaging path (uvx/pipx | PyInstaller/Nuitka | npx/bundled binary | single static binary via cargo/go ` +
    `build) and PLAN shell-completion generation as a required deliverable.\n\n` +
    `FOR TRACK B / the agentic subcommand: FIRST WebFetch the official Agent SDK docs ` +
    `(https://code.claude.com/docs/en/agent-sdk/overview and the migration guide) and confirm the CURRENT ` +
    `package names, import surface, and option-type names against the live page -- do NOT hardcode from memory. ` +
    `Set sdk_api_confirmed_by_fetch and record the confirmed names in sdk_api_notes. Build against: TS ` +
    `\`npm install @anthropic-ai/claude-agent-sdk\` (import from "@anthropic-ai/claude-agent-sdk"); Python ` +
    `\`pip install claude-agent-sdk\` (Python >=3.10, from claude_agent_sdk import query, ClaudeAgentOptions). ` +
    `NEVER emit the deprecated claude-code-era names (@anthropic-ai/claude-code as an SDK source, ` +
    `claude-code-sdk, import claude_code_sdk, ClaudeCodeOptions) -- if the fetch shows they've changed again, ` +
    `follow the fetch. Plan the core mechanisms: the query() streaming loop checking for the result message; ` +
    `allowed_tools=[...] as the default safety rail (permission_mode looser ONLY if the caller asked); ` +
    `HookMatcher guardrails; mcp_servers wiring; AgentDefinition subagents (with "Agent" in allowed_tools); ` +
    `session resume via session_id captured from the init SystemMessage. Choose integration_pattern: embed the ` +
    `SDK loop in-process, or shell out headless (claude -p ... --output-format stream-json --allowedTools ...); ` +
    `plan --bare to suppress local .claude/ discovery in a shipped CLI. For an agent audience ALSO plan: ` +
    `structured machine-parseable success output (exit 0 + silence is not proof) and DIFFERENTIATED exit codes ` +
    `so a caller can decide retry vs abort vs escalate.\n\n` +
    `Do NOT write files yet. Report confirmed_track, track_correction, language, audience, framework (+ ` +
    `rationale), sdk_api_confirmed_by_fetch + sdk_api_notes, integration_pattern, checklist_plan, packaging, ` +
    `and a concrete build_plan.`
}

function scaffoldPrompt(target, design, isolated) {
  const isolationClause = isolated
    ? `Create a THROWAWAY GIT WORKTREE off the build location's repo (git worktree add <tmp> HEAD) and scaffold ` +
      `THERE. NEVER write to the caller's main working tree. Capture the scaffold as \`diff\` (e.g. \`git diff\` ` +
      `output) before you remove the worktree, remove it (git worktree remove --force <tmp>) and prune, and set ` +
      `worktree_removed=true only after confirming it's gone and the main tree's git status is unchanged. Set ` +
      `applied_directly_to_main_tree=false.`
    : `NO GIT ISOLATION IS AVAILABLE (preflight proved it and Douglas explicitly authorized proceeding anyway). ` +
      `Write the scaffold DIRECTLY to the real target location -- there is no worktree and no diff-handback ` +
      `possible without one. State plainly which real files you created. Do NOT claim a worktree was used. Set ` +
      `worktree_removed=false and applied_directly_to_main_tree=true.`;
  return `Scaffold the CLI exactly to this confirmed design, then test it. TARGET: ${target}\n` +
    `DESIGN: ${JSON.stringify(design, null, 2)}\n\n` +
    `${isolationClause}\n\n` +
    `Build ONLY what the design specifies -- the framework it picked, every checklist_plan item, the packaging ` +
    `path, and (Track A/mixed) shell-completion generation. Make ONLY what the request requires; no speculative ` +
    `extra commands, no unrelated cleanup. For Track B / the agentic subcommand, use ONLY the SDK names ` +
    `confirmed by the design pass's live doc fetch -- never the deprecated claude-code-era names -- and never ` +
    `emit a secret via flag or env var.\n\n` +
    `emit a secret via flag or env var. Wire the DESTRUCTIVE-ACTION safety for every destructive command the ` +
    `design named (confirm on a TTY; require --force or --yes/-y on a non-TTY else exit non-zero without ` +
    `acting; --dry-run/-n prints and does nothing), a genuinely useful -h/--help, SIGINT+SIGTERM cleanup, ` +
    `stdin/pipe reading with SIGPIPE/EPIPE handling, idempotent re-runs, and actionable error messages -- and ` +
    `resolve config dirs by platform (%APPDATA%/%LOCALAPPDATA% on Windows, XDG on POSIX).\n\n` +
    `THEN TEST, matching the track: Track A -> write golden-file/snapshot tests of stdout for the deterministic ` +
    `commands AND an explicit exit-code assertion matrix (every command's success and failure exit codes), and ` +
    `actually run them. If the CLI has ANY destructive command, the matrix MUST include an assertion that ` +
    `invoking it without --force/--yes in a non-TTY (piped stdin/stdout) exits NON-ZERO and leaves the target ` +
    `untouched, rather than proceeding or hanging on a prompt. Track B / agentic subcommand -> drive the agent ` +
    `loop end-to-end on ONE trivial real task (a single small turn through query() or the headless claude -p ` +
    `path) and confirm the loop, tool scoping, and result handling behave -- not merely that it compiles. ` +
    `Report test_kind and the real test_result you observed this pass. Do NOT commit.\n\n` +
    `Report files_written (absolute paths), entry_point, commands, tests_written, test_kind, test_result, ` +
    `completion_generated, help_flag_present, destructive_safety_present, stdin_pipe_handled, sigterm_handled, ` +
    `worktree_removed, applied_directly_to_main_tree, and the diff.`
}

function verifyPrompt(target, design, scaffold) {
  return `Adversarially re-check a freshly scaffolded CLI against its OWN files before anything is reported as ` +
    `done. You are skeptical by default -- a claim in the scaffold report is not evidence; the code is. ` +
    `TARGET: ${target}\nDESIGN: ${JSON.stringify(design)}\nSCAFFOLD REPORT: ${JSON.stringify(scaffold)}\n\n` +
    `Read the actual scaffolded files (from the diff, or the real files if unisolated) and verify each claimed ` +
    `checklist item is GENUINELY present in the code, not just asserted -- for each set present + the evidence ` +
    `you saw (the line/construct that satisfies it). Specifically confirm: no secret is accepted via flag or ` +
    `env var (stdin/--password-file only); exit codes are differentiated enough that a caller can tell failure ` +
    `modes apart; -h/--help is present and actually documents the flags + shows an example (help_flag_useful); ` +
    `a second identical run is safe / no-ops (idempotent_rerun); error messages name the next step, not just ` +
    `the failure (errors_actionable); the tool reads piped stdin and survives a downstream reader closing early ` +
    `(| head) without a traceback (stdin_pipe_and_sigpipe_ok); SIGTERM cleans up like SIGINT (sigterm_handled). ` +
    `For any destructive command, ASSERT from the test evidence that invoking it without --force/--yes in a ` +
    `non-TTY exits NON-ZERO and does not proceed (destructive_nontty_requires_force -- true if there are no ` +
    `destructive commands). And for Track B/mixed, that NONE of the deprecated claude-code-era names ` +
    `(@anthropic-ai/claude-code as SDK, claude-code-sdk, import claude_code_sdk, ClaudeCodeOptions) appear ` +
    `anywhere. Confirm the tests ACTUALLY RAN this pass (tests_actually_ran + tests_evidence) rather than being ` +
    `only written. List every gap -- a checklist item claimed but missing from the code, or a still-open ` +
    `deliverable. Verdict is 'scaffolded' only if the core design was built and its tests ran; 'incomplete' ` +
    `otherwise, with the reason. Do this read-only against the files; do not edit, do not commit.`
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
    note: 'This build location cannot be isolated in a git worktree (' +
      (preflight ? preflight.reason : 'the preflight agent did not return a usable result') + '). make-cli ' +
      'refuses to silently fall back to writing the real tree. This needs Douglas\'s call: scaffold into a ' +
      'fresh committed directory and re-run for full isolation (recommended), or re-run with ' +
      'args.allowUnisolated=true to proceed without it (files written directly to the real tree, no worktree, ' +
      'no diff to hand back).',
  }
}
if (!isolated && ALLOW_UNISOLATED) {
  log('No isolation available -- proceeding UNISOLATED per explicit allowUnisolated=true. The scaffold will be written directly to the real target, not handed back as a diff.')
}

let stopReason = null
let design = null
let scaffold = null
let verify = null

for (let i = 1; i <= MAX_ITERATIONS; i++) {
  log(`Iteration ${i}/${MAX_ITERATIONS}: designing ${TARGET} (suspected track ${TRACK})`)
  // Opus for the load-bearing design judgment: confirm the track, pick the framework, and for Track B confirm
  // the current SDK API against a live doc fetch before a single import is emitted.
  design = await agent(designPrompt(TARGET, TRACK), { phase: 'Design & Build', schema: DESIGN_SCHEMA, label: `design-i${i}`, model: 'opus' })

  if (design && design.track_correction) log(`Iteration ${i}: design corrected the track -> ${design.confirmed_track} (${design.track_correction})`)
  const needsFetch = design && (design.confirmed_track === 'B' || design.confirmed_track === 'mixed')
  if (needsFetch && !design.sdk_api_confirmed_by_fetch) {
    log(`Iteration ${i}: SDK API was NOT confirmed by a live doc fetch -- re-running design rather than scaffolding against unverified names`)
    if (i === MAX_ITERATIONS) { stopReason = 'sdk_api_unconfirmed'; break }
    continue
  }

  log(`Iteration ${i}: scaffolding + testing (track ${design ? design.confirmed_track : TRACK})`)
  scaffold = await agent(scaffoldPrompt(TARGET, design, isolated), { phase: 'Scaffold', schema: SCAFFOLD_SCHEMA, label: `scaffold-i${i}` })

  log(`Iteration ${i}: adversarially verifying the scaffold against its own files`)
  verify = await agent(verifyPrompt(TARGET, design, scaffold), { phase: 'Verify', schema: VERIFY_SCHEMA, label: `verify-i${i}`, model: 'opus' })

  if (verify && verify.verdict === 'scaffolded' && (verify.gaps || []).length === 0) {
    stopReason = 'scaffolded'
    log(`Iteration ${i}: scaffolded and verified clean`)
    break
  }

  log(`Iteration ${i}: verify found ${verify ? (verify.gaps || []).length : '?'} gap(s) -- ${i < MAX_ITERATIONS ? 'iterating' : 'stopping at max_iterations'}`)
  if (i === MAX_ITERATIONS) stopReason = 'max_iterations'
}

return {
  target: TARGET,
  track: TRACK,
  confirmedTrack: design ? design.confirmed_track : TRACK,
  isolated,
  preflight,
  maxIterations: MAX_ITERATIONS,
  design,
  scaffold,
  verify,
  stopReason: stopReason || 'max_iterations',
  gaps: verify ? (verify.gaps || []) : [],
}
```

## Final report (what to tell Douglas)

- **Track that ran**, and whether the design pass confirmed or corrected the suspected classification (with the
  reason for any correction). If it refused to force deterministic CRUD onto an agent loop, say so.
- **Framework chosen** (Track A/mixed) and why, given language + command count + audience — and for Track B,
  the **integration pattern** (embedded SDK loop vs. headless `claude -p`) and confirmation that the current
  SDK API was verified by a live doc fetch (not quoted from memory), including the confirmed package/import
  names actually used.
- **Checklist coverage**, item by item, as the Verify pass re-checked it against the real files — which
  clig.dev/agentic items are genuinely present with evidence, and which are still open. Include the
  secrets-handling, differentiated-exit-code, `-h`/`--help`, idempotency, actionable-errors, stdin/SIGPIPE,
  SIGTERM, and destructive-action-safety checks explicitly — with the asserted result that a destructive
  command without `--force`/`--yes` in a non-TTY exits non-zero rather than proceeding.
- **Tests** — Track A: which commands got golden-file/snapshot coverage and the exit-code matrix, and that the
  tests actually ran this pass. Track B: that the agent loop was driven end-to-end on a trivial task, with the
  observed result.
- **Packaging + shell completion** — the chosen distribution path and whether completion generation was
  produced.
- **Isolation status, stated plainly, every time — never assumed.** Whether the run was isolated (worktree
  proven, scaffold handed back as a diff, nothing touched the main tree) or unisolated (no repo / untracked,
  Douglas explicitly authorized proceeding, files written directly to the real tree). Never say "worktree
  removed" or "handed back as a diff" unless isolation was actually proven this run.
- **Honest close.** Never claim the CLI is "production-ready," "fully tested," or "optimal." Report what was
  scaffolded, what was verified THIS pass, and what remains — the register `/spar` uses for "no new issues
  across the last 2 rounds" and `/hone` for "no change beat the baseline past noise this pass." Then point at
  the hardening handoff: run `/spar` to break-and-fix the new tool, and `/probe` for a measured test-quality
  pass, once Douglas has placed the scaffold.
- Full absolute path(s) of everything written, per the standing Files-list convention.

---

*Tracked copy: also save this file to `claude-global-config/commands/make-cli.md` (per the skills-are-tracked
convention) after a NASA scrub.*