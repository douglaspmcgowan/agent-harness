# Product surfaces

Last verified: 2026-07-26

## Shared layer

`C:\Users\dougl\.agents` contains portable rules, skills, templates, state resolution, data and worktree contracts, and cross-product tools. Repositories contain project truth. The Setup folder contains the human explanation.

## Product-owned material

| Surface | Product-owned material | Shared material it consumes |
|---|---|---|
| Claude | `settings.json`, hook wiring and event payloads, plugins, session history, task-board storage, auto-memory, notification and usage behavior, managed worktrees | global imports, `.agents\skills`, repository `CLAUDE.md` → `AGENTS.md`, data/worktree contracts |
| Codex | `config.toml`, desktop permissions and approvals, plugin and connector state, task/session storage, app hooks, managed worktrees | global pointer, `.agents\skills`, repository `AGENTS.md`, data/worktree contracts |
| Cursor | user rules, `.cursor\rules`, editor settings, CLI/IDE permissions, hooks, background-agent configuration, managed cloud isolation | global rule adapter, repository `AGENTS.md`, shared state resolver, data/worktree contracts |

Product-owned files remain separate because the products use different schemas, event names, permission semantics, session identifiers, and user interfaces. Shared policy can feed each adapter.

## Current portability inventory

- Claude has 107 Markdown commands and 46 top-level skill folders.
- The shared `.agents\skills` catalog has wrappers for all 107 Claude commands plus native shared skills.
- Codex currently discovers the shared skill catalog.
- Claude and Codex have substantially overlapping hook sets, with a few intentional host differences.
- Cursor has a smaller native skill and hook set and needs adapters for several capabilities.

## Hook architecture

Portable hook logic should become pure shared detectors and state parsers. Each product retains a thin adapter that:

1. parses the product's event payload;
2. translates tool names and paths;
3. calls shared logic;
4. emits the product's exact response schema and exit behavior;
5. runs product-specific integration tests.

Cursor currently has documented limitations around hook verdicts and a July 2026 stdout timing race. Its built-in permissions remain an independent safety layer. See the [current Cursor hook race report](https://forum.cursor.com/t/race-condition-silently-disables-hooks-that-exit-quickly/165818/7) and [permission-verdict limitation](https://forum.cursor.com/t/support-authoritative-allow-deny-and-ask-verdicts-from-hooks/161342/6).

## Global instructions

- Claude imports the shared contracts from its global `CLAUDE.md`.
- Codex is instructed by its global `AGENTS.md` to read the shared contracts.
- Cursor receives a global always-on rule adapter and each bootstrapped repository contains `AGENTS.md`.

The shared machine-facing load map is `C:\Users\dougl\.agents\HARNESS-MAP.md`. Detailed Setup briefs remain on-demand references.

Product skill adapters translate surface mechanics around one canonical skill. Project bindings live in `skills-manifest.json`. See brief 10.

Cursor's official rules documentation describes Settings user rules, repository `.cursor\rules`, and repository `AGENTS.md`. The installed local global-rule folder is a useful local adapter; the committed repository contract remains the portable guarantee. Cursor's Auto-review, CLI permissions, IDE command state, classifier instructions, hooks, and cloud-agent controls are separate surfaces. See brief 16. [Cursor Rules](https://docs.cursor.com/context/rules-for-ai), [Cursor CLI permissions](https://docs.cursor.com/cli/reference/permissions), [Cursor Auto-review](https://cursor.com/changelog/auto-review).

## What remains product-specific

Notifications, status lines, token/usage windows, approval dialogs, connector authentication, task lists, transcript storage, memory databases, and managed worktree creation stay in the product layer. The shared harness documents their functional equivalents and avoids pretending they have identical implementations.
