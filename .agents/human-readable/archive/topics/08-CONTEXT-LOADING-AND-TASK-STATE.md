# Context loading, task state, and cloud sessions

Last consolidated: 2026-07-29

Current authorities:

- human start page: `C:\Users\dougl\.agents\human-readable\README.md`;
- machine-facing map: `C:\Users\dougl\.agents\HARNESS-MAP.md`;
- live cross-agent contract: `C:\Users\dougl\.agents\CROSS-AGENT-CONTRACT.md`;
- portable repository baseline: `C:\Users\dougl\.agents\PORTABLE-PRINCIPLES.md`.

The project `MAP.md` template now begins with the core-document map and continues with architecture, paths, data flow, integrations, and ownership.

This guide consolidates the former architecture, product-surface, portability, repository-bootstrap, cloud-agent, Cursor-startup, and session briefs. Their dated source text remains under [`archive/topics`](archive/topics/).

## The reliable mental model

The harness has four loading classes:

1. product-global instructions loaded automatically;
2. project instructions loaded automatically or through a thin adapter;
3. skills and topic contracts loaded when the task triggers them;
4. briefs retained for Douglas and read by an agent when the topic applies.

A Markdown link gives a route. Claude’s `@path` syntax imports the full target. A rule that says “read this file when handling secrets” creates a conditional requirement. Detailed Setup briefs are usually read on demand.

The concise machine map is `C:\Users\dougl\.agents\HARNESS-MAP.md`.

## Surface map

| Surface | Automatic | Imported or required | On demand |
|---|---|---|---|
| Claude | user `CLAUDE.md`, repository `CLAUDE.md` | shared map and contract through `@`; project `AGENTS.md` through `@AGENTS.md` | selected skills, worktree protocol, verification, Setup briefs |
| Codex | user and repository `AGENTS.md` | shared map and contract required by the user file | selected skills, worktree protocol, verification, Setup briefs |
| Cursor | Settings user rules and recognized local global rules | repository `AGENTS.md` plus always-applied project `.mdc` adapter | selected skills, scoped `.mdc` rules, verification, Setup briefs |
| Cloud agent | committed repository instructions | committed adapters and project skills | provisioned data and service documentation |

## What is an `.mdc` file?

MDC is Cursor’s Markdown rule format. YAML frontmatter controls whether the rule is always applied, attached by file glob, or made available for agent-requested use. The body contains the instruction. Project rules live under `.cursor\rules`.

An always-applied project adapter should stay short. It tells Cursor to read the canonical repository `AGENTS.md`, task state, and verification contract. Domain-specific behavior belongs in scoped rules or skills.

Cursor's main public documentation guarantees repository rules and repository-root `AGENTS.md`. This machine also has a local global-rule collection under `C:\Users\dougl\.cursor\rules`; its newly added shared-contract rule still needs a live unrelated-repository proof. Brief 16 records the exact installed permission and loading state.

## Core project documents

| File | Job | Normal trigger |
|---|---|---|
| `CURRENT-TASK.md` | Active task and exact next action | Start/resume |
| `WORK_QUEUE.md` | Multi-step actionable queue | Multi-step work and keep-going |
| `STATUS.md` | Durable project state | Start/resume and milestones |
| `LOG.md` | Append-only work record | Read recent entries; append at handoff |
| `BACKBURNER.md` | Parked work | Planning and promotion |
| `VERIFY.md` | Required proof | Before completion |
| `MAP.md` | Architecture, data, owners, important paths | Orientation and unfamiliar code |
| `DESIGN.md` | Goals, constraints, decisions | Whole-feature or architecture work |
| `MEMORY.md` | Lean links to durable topic notes | Recall and repeat-work prevention |

Concurrent sessions use session-keyed `CURRENT-TASK` and `WORK_QUEUE` files through the shared resolver. `STATUS`, `LOG`, and `BACKBURNER` remain shared.

## Why the project `AGENTS.md` differs from the personal global file

The global file contains Douglas-specific behavior, machine paths, product permissions, vault boundaries, voice rules, and personal workflow defaults. A cloud session does not receive those machine-global files.

The project contract therefore carries the portable subset required for safe work:

- startup and Git reconciliation;
- project commands;
- data and secret boundaries;
- worktree ownership;
- task-state semantics;
- verification evidence;
- project skill bindings;
- cloud-data limitations.

The bootstrap template now includes that portable baseline directly. Local agents also receive Douglas’s richer global instructions. Cloud agents can operate safely from the committed contract.

## Resume protocol

Start from the exact repository or worktree directory. Read the automatic project contract and active state, inspect Git, then use old chat history as supporting context. Cross-product continuation happens through task files, commits, and handoff records.

## Repository adoption and cloud preparation

At the first local session in a Git repository, run:

```powershell
C:\Users\dougl\.agents\tools\Ensure-AgentProject.cmd -Repository .
```

The adoption tool adds missing baseline files, refreshes the managed portable-principles block, and preserves project-specific rules. Create new local repositories through `New-AgentRepository.cmd`.

Before dispatching a cloud agent:

1. confirm the repository contract is self-contained;
2. mark required skill bindings as cloud-required or vendored;
3. run the project-skill projection;
4. review and commit the generated skill copies and projection manifest;
5. provide safe fixtures or explicitly provisioned data;
6. configure scoped secrets through the cloud provider;
7. push the intended branch.

Cloud sessions receive committed repository material and configured environment setup. They do not receive this computer's global rules, local data roots, local unlocked Bitwarden vault, product session stores, or local permission files.

## Product-owned surfaces

The shared layer owns portable contracts, skill sources, state resolution, data and worktree rules, verifiers, and cross-product tools. Each product retains its own settings, hook wiring, permissions, task history, notifications, connectors, memory stores, and managed worktrees.

- Claude loads its user and repository `CLAUDE.md` files and follows their imports.
- Codex loads its global and repository `AGENTS.md` instructions and owns app task history, approvals, plugins, and managed worktrees.
- Cursor applies Settings rules and repository `.cursor\rules`; its always-applied project adapter requires the repository contract.

Product adapters translate loading and lifecycle mechanics around one canonical workflow. They do not become competing authorities for the underlying rule or skill.

## Worktrees and concurrent sessions

One writable task receives one branch, one worktree, and one owner. Worktrees isolate tracked files while sharing credentials, network services, browser profiles, cloud deployments, and external data unless the task creates explicit boundaries.

When several sessions share a folder, active `CURRENT-TASK` and `WORK_QUEUE` files become session-keyed through the shared resolver. `STATUS.md`, `LOG.md`, and `BACKBURNER.md` remain shared. A handoff records the repository, absolute worktree path, branch, owner, completed work, verifier evidence, and next action.

## What the general-ai verifier proves

`C:\Users\dougl\.agents\tools\Test-AgentProjectState.cmd -Repository C:\Users\dougl\projects\general-ai` verifies the repository's portable harness baseline. Its scope includes required project/state/manifest files, the managed contract and product adapters, project identity and path expectations, and other deterministic invariants encoded by the verifier.

The result is evidence about repository readiness. Application runtime health, cloud authentication, Bitwarden contents, Google Drive synchronization, scheduled-task execution, and restore success each require their own checks.

## Questions, approvals, and notifications

- A normal Codex response can ask Douglas a blocking question and leave the task waiting in the conversation.
- Some Codex execution modes expose a structured `request_user_input` control. Its availability is runtime-specific, so hooks and shared skills must capability-check before naming it.
- Sandbox escalation and important connector actions use native approval requests.
- Codex Automations have completion/failure notification policies for scheduled work.
- This Windows task does not expose a general-purpose push-notification command for an arbitrary question.
- Current OpenAI remote-access documentation supports answering questions and approving actions from the ChatGPT mobile app when connected to a supported Codex host. Do not promise mobile push delivery without verifying the active host and notification settings.

Shared hooks therefore direct the agent to safe autonomous fallbacks first, then use whatever question or approval channel the current product exposes.

## Corrections and feedback

A correction from Douglas routes by scope and mechanism. Stable shared behavior enters the canonical shared contract. Project and path behavior stays in repository instructions or scoped rules. Product mechanics stay in adapters. Machine-detectable failures use tests, hooks, permissions, or verifiers. Brief 10 contains the consolidated durable-correction workflow. The dated full rubric remains at [`archive/topics/17-FEEDBACK-ROUTING-AND-CORRECTIONS.md`](archive/topics/17-FEEDBACK-ROUTING-AND-CORRECTIONS.md).
