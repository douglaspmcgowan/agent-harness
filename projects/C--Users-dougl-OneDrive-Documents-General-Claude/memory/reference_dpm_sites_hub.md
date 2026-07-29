---
name: DPM Sites Hub — Playbooks, Skills, Repos, Hooks
description: Master map of douglaspmcgowan Vercel deployments, GitHub repos, playbooks, custom skills, and hooks — keyed to dpm-sites hub (Section III)
type: reference
originSessionId: 0a29b488-924b-4d17-9719-1c244969b67a
---

## Hub location

- **Live site**: `dpm-sites.vercel.app` (password-protected)
- **Local repo**: `~/dpm-sites/` — current structure: data/, font-picker/, profile/, scripts/, index.html, styles.css, profile-playbook.md
- **GitHub**: `github.com/douglaspmcgowan/dpm-sites`

---

## Playbooks — live at G: drive

Playbooks live in `G:\My Drive\UC Berkeley\Research\Claude Research Folder\` (the Claude Research Folder on Google Drive), not in `~/dpm-sites/`.

| Title                    | Path                                                                      |
| ------------------------ | ------------------------------------------------------------------------- |
| Build (web app scaffold) | `…\Claude Research Folder\playbooks\build-playbook.md`                    |
| Explainer Site           | `…\Claude Research Folder\playbooks\explainer-site-playbook.md`           |
| Knowledge Graph Explorer | `…\Claude Research Folder\playbooks\knowledge-graph-explorer-playbook.md` |
| Dashboard Tracker        | `…\Claude Research Folder\dashboard-tracker-playbook.md`                  |
| Playwright               | `…\Claude Research Folder\playwright-playbook.md`                         |
| Explainer Site (older)   | `…\Claude Research Folder\explainer_site_playbook.md`                     |
| DFM Graph Explorer       | `…\Claude Research Folder\dfm-graph-explorer\PLAYBOOK.md`                 |
| AI Schools of Thought    | `…\Claude Research Folder\ai-schools-of-thought-explorer\PLAYBOOK.md`     |
| AI Engineering Design DB | `…\Claude Research Folder\ai-engineering-design-db\PLAYBOOK.md`           |
| Profile System           | `~/dpm-sites/profile-playbook.md` (local only)                            |

Playbook index: `…\Claude Research Folder\playbooks\INDEX.md`. Full repo list: `…\Claude Research Folder\repo-map.md`

---

## Custom Claude Code Skills — `~/.claude/skills/` + `~/.claude/commands/`

All invokable as slash commands. Last verified: 2026-05-20.

| Skill                   | Command                    | System-prompt auto-invoke     | What it does                                                                         |
| ----------------------- | -------------------------- | ----------------------------- | ------------------------------------------------------------------------------------ |
| Deep Search             | `/deep-search`             | ✓                             | Multi-step web research with query fan-out, human-authored sources, inline citations |
| Environment Preflight   | `/environment-preflight`   | ✗ (file exists, not surfaced) | Disposable audit of tooling, auth, config, repo shape before a session               |
| Fellowship Review       | `/fellowship-review`       | ✓                             | Evidence-based review of fellowship/scholarship drafts against type rubrics          |
| Hue                     | `/hue`                     | ✓                             | Meta-skill: generates design-language skills from URL/name/screenshot                |
| Parallelize             | `/parallelize`             | ✓                             | Decompose multi-part tasks into parallel sub-agent dispatches with output contracts  |
| Process LinkedIn Inbox  | `/process-linkedin-inbox`  | ✓                             | Categorize inbox posts → propose edits to ai-in-design-map field-map site            |
| Research Asset Manifest | `/research-asset-manifest` | ✗ (file exists, not surfaced) | Build machine-readable inventory of a research folder to reduce future token spend   |
| Build Graph Explorer    | `/build-graph-explorer`    | ✓                             | Build knowledge-graph SPA from corpus; reference impl: dfm-graph-explorer            |
| Build Tracker           | `/build-tracker`           | ✓                             | Build deadline/application tracker adapted from conference-tracker reference impl    |
| Daily Review            | `/daily-review`            | ✓                             | Daily git+session analysis → direct playbook edits + automation candidate report     |
| Make Playbook           | `/make-playbook`           | ✓                             | Extract reusable pattern from a session and write structured playbook to playbooks/  |
| Map Field               | `/map-field`               | ✓                             | Map domain from newsletters/papers into structured schools-of-thought site           |

### Platform-level skills (anthropic-skills + built-ins)

Injected by the platform; no local files. All auto-invoke via system prompt.

**anthropic-skills**: pdf, docx, xlsx, pptx, canvas-design, consolidate-memory, setup-cowork, theme-factory, skill-creator, web-artifacts-builder

**Built-in platform skills**: update-config, keybindings-help, simplify, fewer-permission-prompts, loop, schedule, claude-api, init, review, security-review



---

## Hooks — 19 wired in `~/.claude/settings.json` (reconciled with hub 2026-06-13)

> Reconciled 2026-06-13: the hub's hook gallery now matches the wired set (19 entries incl. `protect-ai-reference.js`). `stop-toast-gate`, `auto-schedule-codex-poll`, `task-state-reminder` are present on the hub — the old "missing from hub" flag is cleared. Table below is the older 11-hook snapshot; see hub `index.html` (subsection "C. Hooks & Automations") for the full current list.

| File                           | Trigger                        | What it does                                                                                                                                                                       |
| ------------------------------ | ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `check-secret-exposure.js`     | PreToolUse · Bash              | Blocks bash commands that contain raw secrets                                                                                                                                      |
| `block-dangerous-bash.js`      | PreToolUse · Bash              | Blocks rm -rf, force-push, and other destructive patterns                                                                                                                          |
| `protect-firmware.js`          | PreToolUse · Write/Edit        | Blocks writes to firmware/bootloader paths                                                                                                                                         |
| `block-obsidian-delete.js`     | PreToolUse · Obsidian MCP      | Blocks delete operations via obsidian MCP                                                                                                                                          |
| `scrub-secrets-from-output.js` | PostToolUse · Bash\|PowerShell | Scrubs API key patterns (OpenAI, Anthropic, Google, AWS, Stripe, GitHub, Slack) from tool output before it enters transcript. Added 2026-05-19 after httpx error leaked a raw key. |
| `format-on-edit.js`            | PostToolUse · Write/Edit       | Auto-formats files after edits                                                                                                                                                     |
| `auto-schedule-codex-poll.js`  | PostToolUse · Agent            | Schedules a wakeup after any Agent dispatch to poll completion                                                                                                                     |
| `task-state-reminder.js`       | UserPromptSubmit               | Reminds about CURRENT-TASK.md state on prompt submit                                                                                                                               |
| `session-primer.js`            | SessionStart                   | Injects session context at start                                                                                                                                                   |
| `stop-toast-gate.js`           | Stop                           | Gate/toast on session stop                                                                                                                                                         |
| `check-session-size.js`        | Stop                           | Warns when session context is growing large                                                                                                                                        |

---

## Vercel Deployments — `douglas-mcgowans-projects`

### Research

| Site                                 | URL                                         |
| ------------------------------------ | ------------------------------------------- |
| IDETC Paper Site                     | `idetc-paper-site.vercel.app`               |
| The Web Looks the Way Someone Chose  | `web-design-guide-lilac.vercel.app`         |
| Apps Look the Way Someone Chose      | `app-aesthetics-guide.vercel.app`           |
| Ways of Thinking                     | `viz-research-hub.vercel.app`               |
| AI Industry Map — Explorer           | `ai-industry-map-explorer.vercel.app`       |
| AI Industry Map                      | `ai-industry-map.vercel.app`                |
| AI Schools of Thought                | `ai-schools-of-thought-explorer.vercel.app` |
| Paper Terminology Hub                | `terminology-site.vercel.app`               |
| Research Hub                         | `dpm-research-hub.vercel.app`               |
| DFM Graph Explorer                   | `dfm-graph-explorer.vercel.app`             |
| DFM · Knowledge Graph Agent          | `dfm-kg-agent-v2.vercel.app`                |
| AI in Engineering Design — Field Map | `ai-in-design-map.vercel.app`               |

### Personal

| Site                   | URL                                 |
| ---------------------- | ----------------------------------- |
| Profile                | `dpm-sites.vercel.app/profile/`     |
| Digital Garden         | `dpm5970digitalgarden.vercel.app`   |
| Share Hub              | `dpm-share-hub.vercel.app`          |
| Font Picker            | `dpm-sites.vercel.app/font-picker/` |

### Projects (active tracker)

| Site              | URL                            |
| ----------------- | ------------------------------ |
| Psych Battery App | `psych-battery-app.vercel.app` |
| 168 Audit         | `168-audit.vercel.app`         |

---

## GitHub repos (douglaspmcgowan)

Key repos: `idetc-paper-site`, `web-design-guide`, `app-aesthetics-guide`, `viz-research-hub`, `ai-industry-map-explorer`, `ai-industry-map`, `ai-schools-of-thought-explorer`, `terminology-hub`, `dfm-graph-explorer`, `dfm-kg-agent-v2`, `ai-in-design-map`, `dpm-sites`, `dpm-share-hub`

Full authoritative list: `~/My Drive/UC Berkeley/Research/Claude Research Folder/repo-map.md`
