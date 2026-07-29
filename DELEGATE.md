<!-- SCRUBBED DEVICE TEMPLATE — reference only. Each device keeps its own real MAP.md/DELEGATE.md
     (device-local, @-imported by CLAUDE.md, normally NOT synced). This copy has machine/personal
     identifiers generalized (<USER>, <USER-EMAIL>) and contains no keys, URLs, or CUI. -->
# Delegation policy — this device (<USER>, NASA GSFC)

> Device-specific. `@`-imported by `CLAUDE.md`. This file exists on every device, but its CONTENT differs
> per device (security + context). The device-agnostic rule in `CLAUDE.md` is only: default Sonnet,
> escalate to Opus. Everything below is local policy for this machine.

## Model tiers
- **Haiku** — read-only inventories, glob/grep sweeps, status checks; mechanical/exploratory.
- **Sonnet** (default) — routine implementation, edits across known files, single-feature changes.
- **Opus / opusplan** — load-bearing architecture, hard-to-reverse refactors, debugging that already failed once on Sonnet, first-pass plans on a new project. Don't burn Opus on setup/formatting/deploy debugging.

### Subagent model default on a GEN-keyed session (resolves the tiers-vs-GEN ambiguity)
On a GEN-keyed session (e.g. the Claude GSFC folder), the "GEN Opus workhorse" guidance below applies to the **MAIN orchestrator thread only**. **Subagents you spawn default to Sonnet.** Concretely:
- **Workhorse = `model: "sonnet"`** → resolves to `claude-sonnet-4.6-thinking` (via `ANTHROPIC_DEFAULT_SONNET_MODEL` in the project `.claude/settings.json`). Use for most subagent work: doc/extraction, viewer/HTML builds, schema+validators, render/Playwright verify, single-feature edits across known files.
- **Escalate to `model: "opus"`** → `claude-opus-4.8-thinking` — ONLY for orchestration, key/architectural decisions, cross-file mapping, hard-to-reverse changes, or debugging that already failed once on Sonnet.
- **`model: "haiku"`** → trivial read-only lookups.
- **Recursive:** a sub-agent that spawns its own sub-agents applies the same rule (Sonnet workhorse, Opus for its key decisions).
- **Never leave the Agent `model` param unset on a GEN session** — unset silently inherits the session's Opus key, which is how everything wrongly ran on Opus before. The GSFC-project PreToolUse hook `agent-model-guard.js` **enforces** this: it blocks any Agent spawn with `model` unset. (Verified 2026-07-01; see [[reference_api_key_delegation]].)

## Reasoning effort for spawned agents (Douglas, 2026-07-23, standing)
Default every spawned agent to **LOW reasoning effort**; use **medium** only for genuinely complex tasks
(open-ended design, cross-file architecture, hard debugging). Never higher without a new ruling. Where the
dispatch surface exposes an effort knob (Workflow `agent()` `effort:`), set it explicitly; where it doesn't
(plain Agent/Task dispatch), approximate with the model tier (Haiku for mechanical/inventory work, Sonnet
for the rest) and tightly-scoped briefs.

## When to spawn sub-agents / Workflow
Spawn ONLY when (a) 3+ genuinely independent parts with no shared file writes, (b) one investigation would burn 30+ files of context you won't need after, or (c) the work won't fit one window. Dispatch all independent Task calls in ONE message. Every Task carries: objective · exact output format · read-first paths · 2–3 key project rules inline · scope boundary. Never two workers on one file; stuck 3+ iterations → re-plan. `/parallelize` decomposes; `Workflow` for deterministic multi-stage fan-out.

## impeccable (design skill) — per-command model tiers
impeccable's commands vary from mechanical (audit, layout, typeset) to pure taste (colorize, delight,
critique, live) — full table + the escalation rule + the actual dispatch mechanism (Skill has no model
param, so escalation means an Agent dispatch with an explicit model) live in `IMPECCABLE_DELEGATE.md`.
Read it before running any non-trivial impeccable command.

## Codex
**GPT-5.5 dispatch route (Douglas, 2026-07-22): use the GEN API key for gpt-5.5 dispatches going forward** (the NMC/LiteLLM proxy route, not the User-scope OPENAI_API_KEY path — that key is unset here and Douglas runs one-off Codex jobs through the Codex desktop app himself).
Discrete, well-specified, low-risk work that passes the two-question test: (1) one-paragraph self-contained brief? (2) verification signal that needs no judgment? If either is no, keep it. Draft via `/codex-brief`; call Codex from the main session only.

## THIS DEVICE — default to the GEN API as much as possible

> **Douglas 2026-07-23 (standing):** the GEN key is updated and can run almost everything — GEN-first is
> the RULE, including full agentic work via the claude CLI on GEN (`gen-claude.sh`). Keep a teammate
> in-house (Anthropic Task subagent) ONLY when live mid-run steering matters (SendMessage-able,
> judgment-heavy, spec still moving) — that is the EXCEPTION, not the rule. Conductor mode: main thread
> orchestrates, GEN does the bulk.
The GEN API (`GEN_API_KEY` + `GEN_BASE_URL`, header `x-api-key`, model `claude-opus-4-8`) is the heavy-lifting workhorse here. **Two hard constraints decide when it can be used:**
1. **No web *tools*.** The GEN *model* endpoint has no `WebSearch`/`WebFetch` tools, so anything that relies on those tools for live data does NOT go to GEN. (Caveat: a session's **shell still reaches the open internet** — `curl`/`wget` GET works even on a GEN-keyed session, verified 2026-07-01. So "no internet" is about the model's tools, not the machine's network. Map of what the shell can/can't do: `Claude GSFC Folder/search.md`.)
2. **NASA-only.** GEN is for NASA/work content. Personal / non-work tasks do NOT go to GEN.

If a task clears both (NASA work **and** no internet needed) → prefer GEN. That covers most heavy generation and most of the actual build work.

**Orchestrator default for long or complex sessions:** the main session acts as an **orchestrator of GEN agents** — keep bulk generation and source data out of the main context window and on GEN. Even the main work thread should default to GEN when both constraints are met. Reserve the main (Anthropic) session for: web research, personal tasks, and judgment/precision work you must verify line-by-line.

**Mechanics:** reuse `…/Claude NASA Folder/_deleg_run.py` (reads `GEN_API_KEY`/`GEN_BASE_URL` from `os.environ`, never prints them). `GEN_API_KEY` authenticates ONLY against `GEN_BASE_URL`. Full details + desktop-app winreg variant: `[[reference_api_key_delegation]]`.

**Full agentic CLI on GEN (not just one-shot calls):** you can run an ENTIRE Claude Code session (tools/files/loops/vision) on GEN, not only `gen.py` completions. Launcher: `…/ai-for-cad/cad-forge/gen-claude.sh` (one command — derives base+key from `gen.py`, sets the required `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` fix so the proxy stops 400-ing on `context_management`, model `claude-opus-4.8-thinking`, defaults to a large `--allowedTools`). `/usr/bin/bash gen-claude.sh -p "<prompt>" --add-dir "<folder>"`. Note: a child `claude --dangerously-skip-permissions` is blocked by the auto-mode classifier unless a settings rule allows it — the baked-in allow-list is the clean autonomous-but-scoped path. Full how-to: `[[reference_api_key_delegation]]`.

## Decision flow
1. Personal / non-NASA? → main session or normal web tools. **Not GEN.**
2. Needs the `WebSearch`/`WebFetch` *tools* or live web search? → main session / web research. **Not GEN.** (A one-off `curl` GET of a known URL is fine from any shell, including GEN sessions.)
3. NASA work, no internet needed? → **GEN** (especially bulk generation; orchestrate from main).
4. Needs ongoing judgment / line-by-line verification? → keep in main; optionally let GEN draft, you verify.
