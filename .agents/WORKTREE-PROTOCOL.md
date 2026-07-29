# Cross-agent worktree protocol

Last verified: 2026-07-24

## Start

1. Identify the stable repository checkout and run `git worktree list --porcelain`.
2. Check whether the current directory is already a linked worktree by comparing `git rev-parse --git-dir` with `git rev-parse --git-common-dir`.
3. If the product offers a managed worktree, use it:
   - Claude Code CLI: `claude --worktree <task>`
   - Claude desktop and agent view: use the task's managed worktree
   - Codex desktop: use the task's managed worktree when the app creates one
   - Cursor: open the exact existing worktree directory; background agents use their platform-managed isolation
4. Use the shared PowerShell helper for a manual fallback.
5. Record the resolved absolute worktree path, branch, owner, shared resources, and verifier on the matching `TASK.md` item.

## Work

1. Install or restore dependencies inside the worktree.
2. Run the repository's baseline verifier before edits.
3. Claim one writer for the worktree.
4. Allocate unique ports and a task-specific test database.
5. Keep valuable runtime data under the shared project data root. Treat it as read-only unless the task explicitly owns a mutation.
6. Commit coherent checkpoints to the task branch.

## Finish

1. Run the repository's required tests, lint, type checks, and adversarial verification.
2. Ensure `git status --short` is empty.
3. Write a handoff containing the branch, commits, changed files, verifier results, and remaining risks.
4. Review the diff from the stable checkout.
5. Merge through a pull request when the repository has a remote and CI. A local merge is acceptable for a local-only repository after the same review gates.
6. Remove the worktree after the branch is merged or pushed to a safe remote.

## Merge ownership

The implementation agent prepares and verifies its branch. The stable-checkout owner reviews and merges. An agent may merge only when the task explicitly grants that authority and all repository gates pass.

## Shared-resource isolation

Worktrees isolate tracked files. They do not isolate:

- development ports;
- SQLite files outside the checkout;
- cloud deployments;
- browser profiles;
- external APIs;
- test accounts;
- credentials;
- queues or shared services.

Each task state must name any shared resource it can mutate and the isolation mechanism used.

## Cross-product handoff

A handoff from Claude, Codex, or Cursor must record:

- stable repository and absolute worktree path;
- branch, commits, and named owner;
- completed changes and remaining work;
- verifier commands and results;
- shared resources touched;
- exact next action.

The receiving agent opens that exact worktree, checks Git and durable task state, then resumes. Product chat history is supporting context.

Human operating guidance lives at `C:\Users\dougl\Setup\Agent Harness\01-ARCHITECTURE-AND-SESSIONS.md`.
