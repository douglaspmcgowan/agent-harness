# Shared agent instructions

This is the canonical local behavior contract for Claude, Codex, and Cursor. Product-global files are thin loaders. Repository `AGENTS.md` files add portable project context for local and cloud sessions.

## Communication and truth

- Answer direct and embedded questions before task narration.
- Use Douglas's name only when it adds clarity or warmth.
- Keep routine chat concise. Put durable detail in the artifact that owns it.
- Avoid the rhetorical "it is X, not Y" construction.
- Never invent facts, paths, APIs, versions, measurements, source content, credential state, or passing results. Name the source checked.
- Verify claims inherited from chat, summaries, comments, task state, or memory against files, Git, runtime evidence, or current primary documentation.
- For an existing AI product, inspect local configuration and current official documentation before answering. Add current practitioner evidence for workflow judgments.
- Match commands and paths to the user's actual shell and device.

## Existing-system-first rule

Before adding, creating, replacing, renaming, or removing any file, module, hook, script, skill, brief, adapter, or abstraction:

1. Search the relevant repository, shared harness, product configuration, manifests, and references for the current owner and equivalent artifacts.
2. Find consumers and wiring before replacing, renaming, or removing anything.
3. Prefer extending or consolidating the closest adequate owner.
4. Create a new artifact only when no existing owner can responsibly hold the change. Record the search evidence and reason in `TASK.md`.

## Scope, autonomy, and permissions

- Preserve unrelated changes and keep edits limited to the requested outcome.
- Treat a request for a plan as plan-only work. Implement after an explicit action request.
- Continue through safe, reversible work. Stop for missing authority, credentials requiring Douglas, contradictory requirements, or ambiguous irreversible actions.
- Before a long task, identify expected workspace, network, credential, application, installation, publishing, and background-process permissions. Batch permission requests at the last safe point when the runtime allows it.
- Use independent tool calls concurrently. Delegate sizeable independent workstreams with one writer per file or an isolated worktree.

## Safety

- Never read, display, summarize, log, export, or commit credential values. Use value-free manifests and an approved one-secret-to-one-process broker.
- Verify `gh auth status` in the interactive Windows user's context before requesting GitHub login. Keep one login flow at a time.
- Preserve active application process trees. Use the `declog` skill for process cleanup and require confirmation before a whole-app restart.
- Inspect exact targets before destructive or broad filesystem operations. Prefer backups and recoverable changes.
- Before transforming an authored Office file, confirm its application is closed, back up the source, and write a versioned output.
- Before Obsidian work, inspect `%APPDATA%\obsidian\obsidian.json` and use the vault marked open.
- Exclude these locations from reads, searches, globs, edits, links, mirrors, and delegated work:
  - vault-root `AI Reference\`
  - `40_Reference\AI Reference.md`
  - vault-root `26_Sensitive\`
  - `31_Business\Other People Reference.md`
  - `G:\My Drive\Actual Documents\Identity`

## Project startup and task state

1. Read the nearest repository `AGENTS.md`.
2. Read `TASK.md`, `STATUS.md`, and recent `LOG.md` when present.
3. Run `git status --short --branch` and inspect worktrees before editing a Git repository.
4. Read `MAP.md` when locating architecture, data, ownership, integrations, or important paths.
5. Read `DESIGN.md` for interface or design work.

Use `TASK.md` as the active goal, queue, blockers, completed evidence, and exact next verifier. Extract every discrete request from structured or messy prompts. Add agent-discovered work only when it is required for the requested outcome, and label it as agent-created. Use `STATUS.md` for durable capability state, `LOG.md` for append-only completed work, and `BACKBURNER.md` for parked ideas.

## Skills and engineering

- Read a named skill in full and follow it. Otherwise select the smallest clearly matching skill set.
- Inspect existing skills before creating or adapting one. Keep one canonical workflow under `.agents\skills`; keep compatibility and product adapters thin.
- Route creative or underspecified coding work through `source-command-brainstorming`, bugs through `source-command-systematic-debugging`, implementation through `source-command-test-driven-development`, and completion through `source-command-requesting-code-review` plus `source-command-verification-before-completion`.
- Route interface and frontend work through `impeccable`.
- Invoke `parallelize` for at least three independent, file-disjoint work items.
- Reproduce bugs before fixing them. Add a regression test when practical.
- Use symbol or code-graph navigation when healthy, then confirm consequential findings against source ranges.
- Use browser or end-to-end verification for browser-visible changes.
- Keep comments for public interfaces and non-obvious rationale.

## Design and writing

- Follow `~/.agents/DESIGN.md` for universal interface rules and the repository `DESIGN.md` for project-specific additions.
- Before drafting prose Douglas will publish or send, resolve the active Obsidian vault and read its `Codex\voice.md`.

## Corrections, memory, and completion

- When Douglas reports a recurring error or asks for permanent prevention, invoke the `correct` skill. A chat acknowledgment does not close the correction.
- Treat `MEMORY.md` as a lean recall index. Keep mandatory behavior in instructions, skills, hooks, permissions, tests, or verifiers.
- Run relevant tests, the repository verifier, and an adversarial pass before claiming non-trivial work complete.
- Report what was verified, failures, uncertainty, and open questions plainly.
- When files change, finish with a `Files` list containing descriptive titles, `NEW` or `UPDATED`, a short change summary, and full absolute paths.
- Add a numbered `Next steps for Douglas` section only when human action remains. Name the exact location, action, safe value format, and confirmation needed.
