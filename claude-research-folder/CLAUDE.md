# Claude Research Folder — workspace memory

> This file serves a dual purpose: (a) Claude Code reads it as project instructions when working in this folder, (b) the productivity plugin uses it as working memory. Keep it under ~80 lines.

## Me

Doug McGowan — UC Berkeley researcher (Expedition 3 / hybrid AI-augmented design). Hybrid knowledge worker; primary tools are Claude Code (CLI), Codex (delegation), Obsidian (notes), VS Code, Vercel.

Background: Penn State Mech-E undergrad → UC Berkeley research. Active on Psych_Battery / Mental Meter, dpm-research-hub, AI-in-design field-mapping, fellowships/grad apps.

## People

| Who | Role |
|-----|------|
| **Kosa** | Research advisor (TBD: full name + role — surfaces frequently in to-dos and feedback notes) |
| **Tahira Reid Smith** | Professor (profile in Obsidian) |
| **Tim Simpson** | Professor (Penn State; profile in Obsidian) |
| **Sara McMains** | Berkeley research connection |
| **Congxing Cai** | (TBD: role) |
| **Eric Olah-Reiken** | (TBD: role) |
| **Casey Simone B** | GitHub: `caseysimoneb`; runs IDETC26-atlas-gui repo; "her guide" referenced in to-dos |
| **Bjorn** | (TBD: surname + papers) — to-do mentions "check out bjorn's papers" |
| **Zahra Amos** | Friend, F-1/E-3 visa, Biology/Berkeley; owns `zahra-job-tracker.vercel.app` |
| **Elisa LJ11** | Original author of upstream `psych-battery` repo Doug forked |

## Projects

| Codename | What |
|----------|------|
| **Psych_Battery / Mental Meter** | Physical battery + web app for visualizing mental energy. UC Berkeley Expedition 3. Live at psych-battery.vercel.app. Repo: `~/psych-battery/`. |
| **dpm-research-hub** | Flask backend + research synthesis hub. Live at dpm-research-hub.vercel.app. Repo: `~/dpm-research-hub/`. |
| **AI-in-design-map** | Field-mapping site from newsletter/paper corpus. Repo path: `~/My Drive/.../Claude Research Folder/ai-in-design-map/`. |
| **DFM-KG-agent v2** | Knowledge-graph agent for design-for-manufacturing. Repo: `~/dfm-kg-agent-v2/`. |
| **AI engineering design DB** | Database project. Repo: `~/ai-engineering-design-db/`. |
| **Zahra job tracker** | Friend's job-search dashboard. Live at zahra-job-tracker.vercel.app. |

## Terms

| Term | Meaning |
|------|---------|
| **KG** | Knowledge graph |
| **CHI** | ACM CHI conference (Human-Computer Interaction) |
| **IDETC / IDETC-CIE** | ASME International Design Engineering Technical Conferences (and Computers & Information in Engineering) |
| **MDEZ** | (TBD — Doug used in Kosa-feedback notes about agentic learning) |
| **GRFP** | NSF Graduate Research Fellowship Program |
| **EUC** | Emerging-Undergraduate-Curriculum-related award |
| **TLDR / Every** | Email newsletters Doug auto-ingests |
| **Codeburn** | GitHub-related tool/service Doug enabled |
| **292C** | Berkeley course (TBD: full name) |
| **Every / TLDR** | Newsletter sources for the email agent |

## Preferences

- **Code comments:** only when the WHY is non-obvious. Don't comment what code already says.
- **Lists:** never auto-expand a user-defined list. On "check/verify" prompts, report findings in chat.
- **Clarifying questions:** batch into one message at start. No ping-pong.
- **Mobile-first:** UI work assumes 320px-wide as the design constraint; multi-viewport screenshots after every change.
- **Repo discipline:** verify `git remote -v` + branch before any commit/push.
- **Credentials:** never echo or log; storage in `~/.config/<project>/` not repo root.
- **Visual UI check:** Playwright + screenshot at desktop AND mobile after any UI change.
- **Delegation:** Codex (GPT-5.4/5.5) for greenfield codegen ≥75 lines, long single-file refactors, mechanical find-rewrite, adversarial diff review. Opus for load-bearing architecture decisions only.

## Working files

- **TASKS.md** — productivity-system task list (in this folder)
- **To-Do.md** — long-form brainstorm; lives at `Obsidian/Metropolis Pt. 1--The Maverick And The Test/To-Do.md`
- **CURRENT-TASK.md** — active session task tracker (this folder)
- **MEMORY.md** — auto-memory index at `~/.claude/projects/C--Users-.../memory/MEMORY.md`
- **repo-map.md** — local-path → GitHub-repo authoritative map (this folder)
