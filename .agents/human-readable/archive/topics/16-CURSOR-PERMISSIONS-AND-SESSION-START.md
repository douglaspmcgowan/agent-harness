# Cursor permissions and session start

Last verified: 2026-07-26

## Verified state on this computer

Cursor Desktop is version `3.13.10`.

The installed configuration has several permission surfaces:

| Surface | Verified state | Source |
|---|---|---|
| Cursor CLI | `approvalMode` is `auto-review`; 91 allow tokens and 86 deny tokens | `C:\Users\dougl\.cursor\cli-config.json` |
| Auto-review classifier | Seven allow instructions and eleven block/review instructions | `C:\Users\dougl\.cursor\permissions.json` |
| Cursor IDE persistent state | Agent auto-run is enabled; full auto-run is disabled; the older command state retains 67 allow entries and zero deny entries | Cursor `state.vscdb`, queried by exact JSON paths without reading credential values |
| Run Everything | Disabled | Cursor `state.vscdb` |
| Project rules | Bootstrapped repositories receive `.cursor\rules\00-project-contract.mdc` with `alwaysApply: true` | shared repository template |
| Local global rules | `C:\Users\dougl\.cursor\rules` contains ten always-applied safety/continuity rules and ten on-demand task/reference rules | filesystem inventory after feedback-scope audit |

The old `_enable_run_everything.py` helper is historical residue. Its settings differ from current live state. Do not run it.

## Auto-review and allowlists

Cursor's current Auto-review description says:

1. allowlisted calls run immediately;
2. sandboxable calls run in the sandbox;
3. remaining calls go to a classifier that may allow them, choose a safer route, or request approval.

The Auto-review settings screen may present classifier instructions instead of an editable command table. The machine still has explicit CLI allow/deny tokens, classifier instructions, and retained IDE command state. Treat these as distinct controls.

For this setup:

- the CLI deny list remains authoritative over matching CLI allow rules;
- classifier instructions describe safe and unsafe call shapes;
- hooks provide additional detection and task-state behavior;
- platform approval and sandbox controls remain active;
- Run Everything stays disabled.

The safe operating default is Auto-review with narrow deterministic denies, safer-alternative classifier instructions, and project-scoped work.

Official references:

- [Cursor Auto-review Run Mode](https://cursor.com/changelog/auto-review)
- [Cursor CLI permissions](https://docs.cursor.com/cli/reference/permissions)
- [Cursor rules](https://docs.cursor.com/context/rules-for-ai)

## What a new local session receives

### Codex

Start the task from the exact repository or worktree folder. Codex receives its user-level `AGENTS.md`, then the repository-root `AGENTS.md` when present. The user-level contract requires the first-open adoption check.

For a bootstrapped repository, no additional prompt is required. For an older repository, the first local agent should run:

```powershell
C:\Users\dougl\.agents\tools\Ensure-AgentProject.cmd -Repository C:\path\to\repo
```

### Cursor

Start the task with the repository root opened as the workspace. A bootstrapped repository supplies two independently supported project surfaces:

- repository-root `AGENTS.md`;
- `.cursor\rules\00-project-contract.mdc`.

Cursor's public documentation supports both project surfaces. Cursor staff have also described `C:\Users\<user>\.cursor\rules` as a local global-rule folder, though that behavior is absent from the main public rules page. Treat repository files as the portable guarantee.

The current global file adapter has not yet been live-proven from an unrelated repository after its 2026-07-26 installation. The repository contract is therefore the completion criterion for a ready Cursor project.

## Current repository readiness

The 2026-07-26 inventory found fourteen top-level Git repositories across the current workspace and `C:\Users\dougl\projects`.

- Two have the complete current baseline: the disposable bootstrap verification repository and the recovered Docket repository.
- Three have `AGENTS.md` and `CLAUDE.md` but lack the Cursor project adapter.
- Nine lack the current portable baseline.

The machine-level harness is installed. Existing repositories still require one additive adoption pass. The pass preserves existing contracts and makes Git status dirty because it creates tracked harness files for review.

## Cloud sessions

A cloud session receives the committed repository and its configured environment. It does not receive this computer's global rules, local skill catalog, local data, or local permission files.

Before dispatch:

1. adopt and fill the repository contract;
2. select and vendor required skills;
3. commit the project adapters, manifests, and task state;
4. push the branch;
5. configure named secrets and required data in the cloud environment;
6. start the cloud agent from that repository and branch.

Cursor Background Agents clone the GitHub repository into an isolated environment and work on their own branch. Their terminal-command security model differs from local Auto-review, so committed instructions, environment configuration, scoped secrets, and network controls carry the cloud boundary.

Official references:

- [Cursor Background Agents](https://docs.cursor.com/background-agent)
- [Cursor agent practices](https://cursor.com/blog/agent-best-practices)

## Reliable start rule

Open the exact repository or worktree. A ready repository contains `AGENTS.md`, `CLAUDE.md`, `.cursor\rules\00-project-contract.mdc`, `VERIFY.md`, and the core task-state files. Run the state verifier whenever readiness is uncertain:

```powershell
C:\Users\dougl\.agents\tools\Test-AgentProjectState.cmd -Repository C:\path\to\repo
```
