# Cross-agent contract

Last verified: 2026-07-26

This is the shared operating contract for Claude, Codex, and Cursor on Douglas's personal Windows computer. Read `C:\Users\dougl\.agents\HARNESS-MAP.md` for the context-loading and document-routing map. Human documentation lives at `C:\Users\dougl\.agents\human-readable`. Product settings, hook wiring, permissions, session stores, authentication, notifications, and managed worktrees remain in each product's own directories.

## Starting and resuming work

1. Open the exact stable repository or existing worktree directory.
2. Read the repository-root `AGENTS.md`, `CURRENT-TASK*`, `STATUS.md`, and the last entries in `LOG.md`. Read `WORK_QUEUE*` for multi-step work.
3. Run `git worktree list --porcelain` and `git status --short --branch`.
4. Resume the product's old chat only when it belongs to this same directory and task. Repository state is authoritative when chat history and files disagree.
5. For work crossing products, write a handoff in durable task state containing the absolute worktree path, branch, owner, completed work, verifier results, and next action.

At the first local session in a Git repository, run `C:\Users\dougl\.agents\tools\Ensure-AgentProject.cmd -Repository <path>`. The adoption check is additive: it installs missing baseline files and security wiring while preserving existing project contracts. Create local repositories through `New-AgentRepository.cmd` so Git initialization and harness bootstrap happen together.

A resumed Claude, Codex, or Cursor chat remains product-owned. Cross-product communication happens through Git commits, repository task-state files, and handoff records.

## Instruction hierarchy

1. Product system and safety rules.
2. The product's user-global instructions.
3. This shared contract and `WORKTREE-PROTOCOL.md`.
4. The repository-root `AGENTS.md`, which is the canonical project contract.
5. A repository-root `CLAUDE.md` containing `@AGENTS.md`, which gives Claude the same project contract.
6. Scoped `.cursor\rules\*.mdc` only for path-specific Cursor behavior.
7. Task-state and subdirectory instructions nearest the files being changed.

When instructions conflict, follow the higher-precedence source and report the conflict. Keep project facts, commands, data paths, safety boundaries, and verification commands in `AGENTS.md`. Detailed Setup briefs are human and on-demand references unless an always-loaded instruction requires a specific brief for the current topic.

The project contract is the content of `AGENTS.md`. The project bootstrap is the larger starter set containing that contract, the Claude adapter, task-state files, data manifest, ignore rules, and security checks.

## Stable machine roots

| Purpose | Root |
|---|---|
| Stable Git checkouts | `C:\Users\dougl\projects\<project>` |
| Authoritative project data | `C:\Users\dougl\Data\Projects\<project>` |
| Restricted project data | `C:\Users\dougl\Data\Restricted\<project>` |
| Manual fallback worktrees | `C:\Users\dougl\Worktrees\<repository>\<task>` |
| Shared rules, adapters, templates, and tools | `C:\Users\dougl\.agents` |
| Human-readable setup documentation | `C:\Users\dougl\.agents\human-readable` |

Platform-managed worktrees may live in product-owned locations. Discover them with `git worktree list --porcelain`.

## Project data contract

Each project receives a per-project data folder:

```text
C:\Users\dougl\Data\Projects\<project>\
  inputs\       source material and imported datasets
  runtime\      application state and local databases
  outputs\      generated exports and reports
  private\      sensitive project records
```

The matching repository contains:

```text
data\
  README.md            descriptions, schemas, and acquisition instructions
  fixtures\            small, non-sensitive test fixtures that belong in Git
data-manifest.yaml     names, formats, sensitivity, checksums, and path variables
.env.example           variable names with safe placeholder values
.local\                disposable cache, always ignored
```

Applications receive the authoritative data location through `PROJECT_DATA_ROOT` or a project-specific environment variable.

### Placement rules

- Commit source code, tests, schemas, migrations, documentation, and small reproducible fixtures.
- Store mutable databases, credentials, private records, large corpora, and generated outputs under the data roots.
- Use `C:\Users\dougl\Data\Restricted` when tighter Windows permissions or explicit access approval is required.
- Use repository `.local\` only for regenerable cache or scratch data.
- Keep at least one independent backup of valuable ignored data.
- Exclude `.env`, credential exports, session material, real-record databases, and restricted data from Git.
- Treat ignored files as ordinary local files. Git cleanup, repository deletion, malware, disk loss, and agents with filesystem access can still affect them.

## Files or SQLite

Use plain files for documents, media, configuration, immutable inputs, portable exports, and append-only logs.

Use SQLite when the application needs at least one of:

- atomic changes spanning several records;
- relationships between entities;
- indexed lookup, filtering, sorting, or aggregation;
- safe concurrent reads with one local writer;
- schema migrations and integrity constraints;
- durable queues, histories, or state machines.

Example: a fellowship tracker with applications, contacts, deadlines, status history, reminders, and filtered dashboards benefits from SQLite. A folder of research PDFs and Markdown notes benefits from plain files plus a manifest.

SQLite is one local file. The application still needs migrations, exports, backups, and a documented data path. The installed `sqlite3` CLI is an inspection and maintenance tool; each application should use its language's SQLite dependency.

## Worktrees and ownership

- One writable task gets one branch, one worktree, and one named owner.
- Detect existing isolation before creating anything.
- Prefer the product's managed worktree feature.
- Use `C:\Users\dougl\.agents\tools\agent-worktree.cmd` for the manual fallback.
- Record repository, absolute worktree path, branch, owner, goal, shared resources, and verifier in task state.
- Run dependency setup and a baseline verifier inside the worktree before editing.
- Give parallel worktrees distinct ports, test databases, deployment targets, and mutable data.
- Give each worktree one writer.
- Review and merge from the stable checkout after the source worktree is clean and verified.
- Remove a worktree after its commits are merged or preserved remotely.

Read `C:\Users\dougl\.agents\WORKTREE-PROTOCOL.md` for the full lifecycle.

## Credentials and interactive authority

Bitwarden Password Manager Free is Douglas's human and local-development credential authority. Platform-native stores hold deployment credentials at their runtime boundary. Bitwarden Secrets Manager remains optional for a small set of machine-facing projects within its free-tier limits.

Douglas performs login, vault unlock, credential selection approval, high-impact rotation, machine-token creation or revocation, and final locking.

Agents may prepare a value-free command, request one named credential for one trusted executable, consume ordinary success or failure output, and update `.env.example` or secret manifests using names and purposes only.

Agents must never enumerate, export, print, summarize, or log vault data or session keys. Commands such as `bw list`, `bw export`, unrestricted `bw get`, and environment dumps are forbidden.

### Environment-variable discovery

On Windows, a sandboxed child process can see a narrower environment or registry view than the host. A process-scope miss proves only that the variable is unavailable to that process. Before declaring a named environment variable absent from the machine, run the shared metadata-only probe across Process, User, and Machine scopes from the host boundary:

```powershell
C:\Users\dougl\.agents\tools\Get-EnvironmentVariableMetadata.cmd -Pattern 'SUPABASE|POSTGRES|DATABASE'
```

The probe emits scope, name, set/unset state, and length. It never emits values. If sandbox and host results differ, report the boundary explicitly and inject the host value directly into one authorized child command without printing or persisting it.

The local broker at `C:\Users\dougl\.agents\tools\Invoke-WithBitwardenItem.cmd`:

- accepts one item identifier and one field;
- resolves the exact child executable against an allowlist;
- removes `BW_SESSION` before the child starts;
- injects the selected field only for that child;
- restores the prior process environment in `finally`.

The selected child can still read or transmit the injected value. Treat every allowed executable and argument list as trusted credential-dependent work.

An environment trust boundary is one set of processes, people, machines, and deployment stages allowed to receive the same secret under the same compromise assumptions. Local development, preview deployment, production deployment, GitHub Actions, and a cloud agent are separate boundaries unless a documented review combines them.

Each repository keeps `secret-manifest.json` as the canonical value-free inventory and generates `secret-manifest.md` from it. The updater reads names from `.env.example`; it never scans `.env`, vault contents, recovery keys, or environment values. Run:

```powershell
C:\Users\dougl\.agents\tools\Update-SecretManifest.cmd -Repository C:\path\to\repo
```

Password Manager vault items may hold one project's local secrets as hidden custom fields. The local item broker requires an interactive unlock, passes one selected field to one approved child executable, and removes `BW_SESSION` from the child. Cloud agents receive separately scoped GitHub, Vercel, or provider credentials through the platform that executes them.

When Secrets Manager is deliberately used, its project and read-only machine account stay narrowly scoped. `BWS_ACCESS_TOKEN` is itself a bootstrap secret and receives an expiration, revocation plan, and protected runtime injection path.

For Secrets Manager, use `C:\Users\dougl\.agents\tools\Invoke-WithBitwardenSecret.ps1` from a dedicated `powershell.exe -File` process. It retrieves one secret by ID, requires the secret ID, destination variable, executable, and exact argument list to match one allowlist record, injects the value through the approved environment variable, removes `BWS_ACCESS_TOKEN` before the child starts, restores the broker environment in `finally`, and never prints either value. The Docket publisher’s only current command approval is recorded in `bws-command-allowlist.json`; its empty `secretIds` array keeps the path fail-closed until the real Docket secret ID is recorded.

## Skills and adapters

Read `C:\Users\dougl\.agents\SKILL-PORTABILITY-CONTRACT.md` before adding, copying, renaming, or adapting a skill.

- One canonical skill owns the procedure.
- Legacy `source-command-*` entries are compatibility aliases.
- Product adapters translate invocation, tools, hooks, paths, and output contracts.
- Project `skills-manifest.json` records selected bindings and cloud requirements.
- Provider and model references exist only for verified behavioral differences.
- Project-specific portable skills are committed under `.agents\skills`.

## Docket and review state

Read `C:\Users\dougl\.agents\DOCKET-PROTOCOL.md` before creating or publishing Docket cards.

Docket cards are persistent review items. The durable source remains the project audit, brief, or task file. Card generation is credential-free. Publishing and result retrieval cross an authentication boundary controlled by Douglas. Sensitive cards stay local.

## Secret scanning

Gitleaks is installed at `C:\Users\dougl\Tools\gitleaks\gitleaks.exe`.

- A user Git template installs a pre-commit scan in newly initialized and cloned repositories.
- Project bootstrap installs `.gitleaks.toml` and a GitHub Actions workflow.
- Existing repositories use `C:\Users\dougl\.agents\tools\Enable-Gitleaks.cmd`.
- A blocked commit requires inspection. A confirmed exposed credential requires revocation or rotation before history cleanup.
- Gitleaks is a detection layer. It does not authorize runtime credential use.

## Safety enforcement

Safety comes from several independent layers:

1. product permissions and sandbox controls constrain filesystem, shell, network, and application actions;
2. product hook adapters block recognized dangerous commands, secret exposure, and protected paths;
3. the shared contract requires approvals and human-only boundaries;
4. Git worktrees and per-task ownership reduce write collisions;
5. Gitleaks scans staged changes and CI history;
6. Bitwarden keeps values outside repositories and limits runtime injection;
7. Git history, task state, backups, and restore tests provide recovery evidence.

Hooks are defense-in-depth. Current Cursor builds have documented hook race and verdict limitations, so Cursor's built-in deny and approval controls remain required.

## Backups

GitHub covers committed repository content. It leaves ignored data, uncommitted changes, local databases, and restricted files outside that copy.

Google Drive may synchronize selected folders. Synchronization propagates edits and deletions, so backup software should create versioned encrypted archives for irreplaceable data. Every valuable data root needs:

1. the live local copy;
2. a versioned second copy on another medium; and
3. an encrypted versioned offsite copy with a tested restoration.

Exclude `C:\Users\dougl\Data\Restricted` from cloud storage until Douglas makes a project-specific privacy decision.

## Durable corrections

When Douglas corrects an agent or asks that a mistake never recur, read `C:\Users\dougl\.agents\FEEDBACK-ROUTER.md`.

Treat enforcement as a list. Apply several mechanisms when each covers a distinct recurrence path. Append value-free project/path records to `.agents\feedback\FEEDBACK-LOG.md`; append shared/platform/provider records to `C:\Users\dougl\.agents\feedback\FEEDBACK-LOG.md`.

Classify breadth and enforcement separately. Keep path and project rules scoped to their code. Put stable cross-project behavior in the shared contract. Keep product mechanics in thin product adapters. Use a test, verifier, hook, or permission when software can detect the condition. Propagate cloud-required corrections through committed repository files.

## Action-required handoff

When a turn ends or a goal blocks with action required from Douglas, end the response with a numbered `Next steps for Douglas` checklist. Each step names the exact app, page, file, or command location; the action to take; the setting or field involved; the safe format of any value without exposing credentials; and the confirmation Douglas should send back. Omit the section when Douglas has no action to take.

## Setup documentation governance

Every material harness change must update:

1. the relevant brief in `C:\Users\dougl\.agents\human-readable`;
2. `CHANGELOG.md` in that folder;
3. the setup integrity stamp generated by `Update-HarnessSetupStamp.cmd`;
4. any affected product adapter;
5. the adversarial verification record.

Run `C:\Users\dougl\.agents\tools\Test-HarnessSetup.cmd` before calling a harness change complete.
