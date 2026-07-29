# Cross-agent harness map

Last verified: 2026-07-26

This is the concise machine-facing map for Claude, Codex, Cursor, repository sessions, and cloud sessions. Detailed explanations live under `C:\Users\dougl\.agents\human-readable` and are read when their topic applies.

## Context-loading classes

| Class | Meaning | Examples |
|---|---|---|
| Automatic | The product inserts it at session or project start | Claude user `CLAUDE.md`; Codex user and repository `AGENTS.md`; Cursor Settings/local global rules and always-applied project rules |
| Imported | An automatic file explicitly imports the full target | Claude `@C:/Users/dougl/.agents/CROSS-AGENT-CONTRACT.md`; repository `CLAUDE.md` importing `@AGENTS.md` |
| Required on condition | An always-loaded instruction tells the agent to read it when a trigger applies | `WORKTREE-PROTOCOL.md` for parallel work; `VERIFY.md` before completion; a matching `SKILL.md` after its metadata triggers |
| Human/on-demand | Durable explanation for Douglas and for agents handling that topic | `C:\Users\dougl\.agents\human-readable\*.md`; Obsidian briefs |

Links and path mentions do not load a target by themselves. Claude `@` imports load the target. Skill metadata is discoverable before the full skill body is loaded.

## Product startup

For a local Git repository, each product runs `C:\Users\dougl\.agents\tools\Ensure-AgentProject.cmd -Repository <repository>` at first open. The command adds missing baseline files and adopts the managed portable-principles block while preserving project-specific rules. New local repositories should be created through `New-AgentRepository.cmd`.

### Claude

1. Claude loads `C:\Users\dougl\.claude\CLAUDE.md`.
2. Its `@` imports load this map and the shared cross-agent contract.
3. A repository `CLAUDE.md` imports repository `AGENTS.md`.
4. Relevant skill metadata selects a skill; Claude reads the selected `SKILL.md`.
5. Hooks may inject resolved task-state content.

### Codex

1. Codex loads `C:\Users\dougl\.codex\AGENTS.md` through the product instruction layer.
2. That file requires this map and the shared contract.
3. Codex loads the repository-root `AGENTS.md`.
4. Codex discovers shared and repository skills, then reads a selected `SKILL.md` after it triggers.
5. The app owns task history, approvals, plugins, and managed worktrees.

### Cursor

1. Cursor applies Settings user rules and any local global rules recognized by the installed build.
2. Repository `.cursor\rules\*.mdc` files load according to `alwaysApply`, descriptions, and glob scopes.
3. Cursor reads repository-root `AGENTS.md`; the always-applied project adapter requires it before work.
4. Cursor discovers user or project skills and loads a selected `SKILL.md` when relevant.
5. Cursor owns editor state, memories, background-agent settings, and managed cloud isolation.

## Repository document wiring

| Document | Loaded or read when | Owner |
|---|---|---|
| `AGENTS.md` | Every repository session | Shared project contract |
| `CLAUDE.md` | Every Claude repository session; imports `AGENTS.md` | Claude adapter |
| `.cursor\rules\00-project-contract.mdc` | Every Cursor repository session | Cursor adapter |
| `CURRENT-TASK.md` or session-keyed equivalent | Start/resume and every active handoff | Active task |
| `WORK_QUEUE.md` or session-keyed equivalent | Multi-step work and keep-going loop | Action queue |
| `STATUS.md` | Start/resume and milestone handoff | Durable project state |
| `LOG.md` | Last 5–10 entries at start; append at handoff | Append-only work log |
| `BACKBURNER.md` | Planning, parking, and promoting work | Shared backlog |
| `VERIFY.md` | Before a completion claim | Verification contract |
| `MAP.md` | Locating architecture, data, owners, or unfamiliar files | Navigation map |
| `DESIGN.md` | Whole-feature design or architecture decisions | Design record |
| `MEMORY.md` | Recall and before repeating prior work | Lean index to durable reference files |
| `secret-manifest.json` | Credential-dependent work or environment setup | Value-free canonical secret inventory |
| `secret-manifest.md` | Human review and agent orientation | Generated view; never contains values |
| `skills-manifest.json` | Skill discovery, bootstrap, or cloud-session setup | Project skill bindings |
| `skill-projection-manifest.json` | After local skill export and in cloud review | Hashes and provenance of vendored shared skills |
| `.agents\feedback\FEEDBACK-LOG.md` | Explicit correction or recurrence review | Append-only, value-free project feedback |

## Task-state locations

- Single active session: repository-root `CURRENT-TASK.md` and `WORK_QUEUE.md`.
- Concurrent sessions in one folder: session-keyed active files under the shared resolver’s `taskstate\<project>` directory.
- Shared state remains `STATUS.md`, `LOG.md`, and `BACKBURNER.md`.
- A handoff records repository, absolute worktree path, branch, owner, completed work, verifier evidence, and next action.

## Cloud-session readiness

Cloud sessions receive repository files and configured environment setup. They cannot rely on `C:\Users\dougl\.agents`, local data roots, local secrets, or product-global files.

Every cloud-ready repository therefore commits:

- a self-contained `AGENTS.md`;
- the Claude and Cursor adapters;
- task-state contracts and verification commands;
- `skills-manifest.json`;
- any project-specific skills under `.agents\skills`;
- safe fixtures and manifests;
- setup scripts that provision dependencies without secret values.

Before dispatching a cloud agent, mark required bindings in `skills-manifest.json` with `"cloudRequired": true` or `"delivery": "vendored"`, run `Sync-ProjectSkills.cmd`, review the generated `.agents\skills` copies and projection manifest, commit them, and push the branch. The cloud agent then receives the selected skills through the repository.

Machine-global personal preferences remain local. Portable safety, verification, data, worktree, and task-state rules belong in repository `AGENTS.md`.

## Topic routing

- Project/session loading: `CROSS-AGENT-CONTRACT.md` and Setup brief 08.
- Project data, backup, Drive, and restore: Setup brief 15.
- Worktrees/concurrency: `WORKTREE-PROTOCOL.md`.
- Credentials and Bitwarden project scaffolds: Setup brief 09.
  - `New-BitwardenProjectScaffolds.ps1` creates empty Password Manager Login items.
  - `Invoke-WithBitwardenItem.ps1` performs full-tuple Password Manager injection.
  - `Invoke-WithBitwardenSecret.ps1` handles the optional Secrets Manager boundary.
- Memory pressure and stale helper processes: `skills\declog\SKILL.md`; inventory first, preserve active owner trees, and surface ambiguous candidates for a human decision.
- Skills/adapters: `SKILL-PORTABILITY-CONTRACT.md` and Setup brief 10.
- Docket/review board: `DOCKET-PROTOCOL.md` and Setup brief 11.
- Harness mutation: `C:\Users\dougl\.agents\human-readable\UPDATE-PROTOCOL.md`.
- Agent correction or recurring mistake: `FEEDBACK-ROUTER.md` and Setup brief 10.

## Shared portable baseline

- `PORTABLE-PRINCIPLES.md` is the canonical managed block projected into every repository `AGENTS.md`.
- `tools\Sync-PortableContract.ps1` replaces only that marked block and backs up the previous repository contract.
- `skills\feedback\SKILL.md` routes corrections into one or more enforcement mechanisms.
- `feedback\FEEDBACK-LOG.md` stores shared value-free correction records.
- Cursor permissions or session startup: Setup brief 08.
- Local project/repository location and readiness: Setup brief 18.
