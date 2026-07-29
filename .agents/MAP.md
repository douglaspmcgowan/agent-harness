# Cross-agent harness map

This is the machine-facing map for the shared local harness. The human guide and its HTML mirror explain the same system for Douglas.

## Authority and loading

| Surface | Automatic entry point | Loads | Owns |
|---|---|---|---|
| Shared local harness | `~/.agents/AGENTS.md` | Conditional links in this map | Cross-product behavior |
| Claude | user `CLAUDE.md` | Shared `AGENTS.md`; repository `CLAUDE.md` imports repository `AGENTS.md` | Claude settings, hooks, sessions, permissions |
| Codex | user `AGENTS.md` | Shared `AGENTS.md`; Codex also loads repository `AGENTS.md` | Codex settings, hooks, tasks, approvals, plugins |
| Cursor | always-applied user rule | Shared `AGENTS.md`; repository rule requires repository `AGENTS.md` | Cursor settings, hooks, editor state, permissions |
| Cloud agent | repository files | Repository `AGENTS.md`, adapters, selected vendored skills | Ephemeral runtime |

Product-global adapters contain loading instructions and product mechanics only. The shared `AGENTS.md` owns local cross-product behavior. A repository `AGENTS.md` contains a short managed portable block plus project identity, commands, data boundaries, and local constraints so cloud sessions remain self-contained.

## Shared files

| Path | Read when | Owns |
|---|---|---|
| `AGENTS.md` | Every local session through an adapter | Shared behavior and routing |
| `DESIGN.md` | Interface, frontend, visual, or design work | Universal interface rules |
| `MAP.md` | Orientation, architecture, paths, ownership, integration | This map |
| `MEMORY.md` | Recall or repeated work | Lean links to durable references |
| `skills\<name>\SKILL.md` | Its trigger matches | Canonical repeatable workflow |
| `skills\correct\SKILL.md` | A correction or permanent-prevention request | Evidence, scope, enforcement, proof |
| `feedback\FEEDBACK-LOG.md` | Correction audit or review | Append-only value-free history |
| `tools\` | A routed workflow requires deterministic execution | Shared scripts and verifiers |
| `human-readable\README.md` | Human orientation or harness explanation | One authored human guide |
| `human-readable\README.html` | Browser/Obsidian HTML viewing | Generated mirror of the guide |

The feedback log is an audit trail. Agents load the `correct` skill for the procedure and read relevant log entries only during correction review, recurrence analysis, or supersession.

## Repository starter

| File | Owns |
|---|---|
| `AGENTS.md` | Portable behavior block and project contract |
| `CLAUDE.md` | Claude import of `AGENTS.md` |
| `.cursor\rules\00-project-contract.mdc` | Cursor pointer to `AGENTS.md` |
| `DESIGN.md` | Managed universal rules plus project-specific interface rules |
| `MAP.md` | Project architecture, data flow, ownership, integrations, paths |
| `TASK.md` | Current goal, queue, blockers, completed evidence, next verifier |
| `STATUS.md` | Durable project capability state |
| `LOG.md` | Append-only completed-work record |
| `BACKBURNER.md` | Parked work |
| `MEMORY.md` | Lean links to durable project references |
| `skills-manifest.json` | Canonical project skill bindings |
| `data-manifest.yaml` | External project-data authorities, adapters, and recovery rules |
| `secret-manifest.json` / `secret-manifest.md` | Value-free runtime-variable inventory and generated human view |
| `PRODUCT.md` | Product intent when the repository represents an app or product |

`PRODUCT.md` is project-specific. Repositories that do not represent a product may omit it.

## Ownership rule

Before an artifact changes, search for its existing owner and consumers:

| Concern | First owner to inspect |
|---|---|
| Cross-product behavior | Shared `AGENTS.md` |
| Universal interface rule | Shared `DESIGN.md` |
| Project behavior or fact | Repository `AGENTS.md`, `MAP.md`, or `STATUS.md` |
| Active or parked work | `TASK.md` or `BACKBURNER.md` |
| Repeatable procedure | Existing canonical skill |
| Deterministic guard | Existing dispatcher, permission, test, or verifier |
| Product-specific mechanics | Product adapter and product-owned settings |
| Human explanation | Existing section of `human-readable\README.md` |

Extend or consolidate the nearest adequate owner. Before replacement, renaming, or removal, find every consumer, adapter, manifest entry, hook wire, test, and documentation link.

## Data, secrets, and portability

- GitHub carries committed project and portable harness content.
- Project runtime and external data live outside Git at the documented project data root and move only through the project's declared adapter.
- Bitwarden holds credential values. Repositories carry names, purposes, and safe placeholders only.
- Capsule carries the shared global harness, receiving-computer tools, value-safe manifests, safe instructions, and the approved Obsidian snapshot authenticated by the recorded harness revision.
- `capsule\Capture-ApprovedObsidianConfig.ps1` is the only live-vault-to-harness route; Capsule refresh consumes only its reviewed and committed output.
- Product session stores and authentication remain product-owned.

## Update routing

- Behavior change: `AGENTS.md` and affected thin adapters.
- Universal interface rule: `DESIGN.md` and managed project starter block.
- Architecture, path, ownership, integration, or loading change: `MAP.md`.
- Recurring correction: `correct` skill, narrow enforcement artifact, and value-free log entry.
- Reusable fact: durable reference plus one line in `MEMORY.md`.
- Human explanation: the existing section in `human-readable\README.md`, then regenerate `README.html`.
