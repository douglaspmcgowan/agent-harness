# Memory Index

## Reference

- [Claude Research Folder path](project_paths.md) — Google Drive path to main research workspace
- [Claude Toolkit Map](reference_toolkit_map.md) — One-stop map of all installed hooks, skills, slash commands, MCP servers, memory rules, and templates; at G:\My Drive\UC Berkeley\Research\Claude Research Folder\claude-toolkit-map.md
- [DPM Sites Hub map](reference_dpm_sites_hub.md) — All Vercel deployments, GitHub repos, playbooks, custom skills, and hooks; hub at dpm-sites.vercel.app
- [MCP servers map](reference_mcp_servers.md) — All MCP servers (local + platform), auth, paths, capabilities, and pre-approved permissions
- [Obsidian vault & sync setup](reference_obsidian_vault_sync.md) — Active vault is LOCAL (C:\Users\dougl\Main\Yoga 7 Local John 1412), Obsidian Sync remote "John 14:12"; Drive Metropolis vault is separate. Check obsidian.json before writing.
- [Automation audit + design skills](reference_automation_audit.md) — June 2026 audit of 2 weeks of sessions → vault Claude\Automation Audit June 2026\; ranked build list; design-taste + impeccable skills installed
- [Motion & interaction defaults](reference_motion_interaction_defaults.md) — concrete numbers for buttons/motion/radii/focus: icon-button hover-reveal (Cursor pattern), easings, durations, tabular-nums, reduced-motion; complements impeccable skill
- [Design tooling shortlist](reference_design_tooling.md) — curated skills/MCPs/component packs/color+type tools/practitioner refs to install or bookmark (Vercel guidelines skill, shadcn registry MCP, tweakcn, frontend-design skill…); beyond impeccable/taste/shadcn

## Projects

- [Client Portal](project_client_portal.md) — multi-customer client portal for Doug's AI consulting business (Jars of Clay); repo douglaspmcgowan/client-portal, Next+Supabase, brutalist/academia themes; LIVE at client-portal-psi-three.vercel.app, needs Supabase keys for data persistence
- [Berkeley House](project_berkeley_house.md) — 7-room co-op property site at 1636½ 63rd St Berkeley; Next.js 16+Supabase+Stripe ACH+Twilio; LIVE at berkeley-house.vercel.app; Supabase ref nmksafjyroefeazymfha
- [Legal Doc Studio "Recital"](project_legal_doc_studio.md) — interactive Motion-to-Dismiss viewer/editor demo for Anna; live legal-doc-studio.vercel.app (clean domain public, hash URLs 401), repo douglaspmcgowan/legal-doc-studio, static SPA
- [AMAX Elite accounts](project_amax_elite_accounts.md) — legal-solutions-website: all Google/web assets under Anna • amaxeliteseals.org ("AMAX Elite Chrome" profile, NOT Doug's gmail); live ONLY at .org (.com is dead/NXDOMAIN)
- [Jars of Clay manual tasks](manual_tasks_jars_portal.md) — Doug's own setup tasks for the portal (Supabase, admin password, domain); full checklist in vault 31_Business/Jars of Clay — Manual Tasks.md
- [Business tasks](business_tasks.md) — running list of tasks Doug owes to clients/others for the AI consulting business

## User profile

- [Berkeley ME PhD program](user_berkeley_phd.md) — Major field Design, advisor Kosa Goucher-Lambert, Chancellor's Fellow, started FA25, prelim August 2026

## Feedback rules

- [AI-isms to avoid](feedback_ai_isms.md) — generated-site/UI tells to avoid in web + prose work; running list
- [Verify before asserting — search first](feedback_verify_before_asserting.md) — WebSearch before answering any factual question about tools/features; never answer from memory then correct later
- [Test beats assertion](feedback_test_beats_assertion.md) — When a claim is cheaply checkable, test before asserting/searching; working example + user's direct experience outrank web search; don't abandon working solutions
- [Never overwrite user-edited files](feedback_never_overwrite_files.md) — Read before Write on any file that may have been touched outside the session
- [Don't auto-expand lists](feedback_dont_expand_lists.md) — On check/verify prompts, report findings in chat only
- [Synthesize, don't catalog](feedback_synthesize_not_catalog.md) — Research outputs should be essays with a POV, not bullet lists
- [Durable state before compaction](feedback_durable_state_before_compaction.md) — Update CURRENT-TASK.md before context compacts on multi-step tasks
- [Background agent tracking](feedback_background_agent_tracking.md) — After ANY background task dispatch (Codex, agent, shell, pip install, model pull), call ScheduleWakeup(180) immediately; reschedule on every wake if still running; never use a longer first interval
- [Delegation checkpoints](feedback_delegation_checkpoints.md) — Two-question test before ≥200 lines or post-compaction resume
- [Codex avoidance rules](feedback_codex_avoidance_rules.md) — 7 hard rules for when NOT to use Codex; check before every dispatch
- [Render check after layout](feedback_render_check_after_layout.md) — Playwright screenshot after any CSS positioning change
- [Visual UI check](feedback_visual_ui_check.md) — Desktop + mobile screenshot after any UI-affecting change
- [Repo verification before commit](feedback_repo_verification_before_commit.md) — git remote -v + branch + repo-map.md before any commit/push
- [Credential storage](feedback_credential_storage.md) — Secrets in ~/.config/<project>/ only; never echo or log
- [No secret/env dumps](feedback_no_secret_dumps.md) — Never env/printenv/cat .env/echo $SECRET; enforced by block-secret-dump hook (Bash+PowerShell), committed to global config
- [Long prompt discipline](feedback_long_prompt_discipline.md) — Messages with 5+ items → write CURRENT-TASK.md first
- [Session rollover](feedback_session_rollover.md) — "Run session rollover" → ~/bin/rollover-session.ps1
- [Image aspect ratios](feedback_image_aspect_ratios.md) — Always preserve original aspect ratio when resizing
- [Creative writing variety](feedback_creative_writing_variety.md) — Taglines/names/copy → generate 5–10 varied options
- [Guided tour default](feedback_guided_tour_default.md) — New web apps with state → ship with guided tour + help modal; see build-playbook.md Phase 6
- [Edge-case tests default](feedback_edge_case_tests_default.md) — v1 Playwright suites → include 10-class edge-case checklist from playwright-playbook.md Phase 4
- [Chat vs site edit](feedback_chat_vs_site.md) — Questions about a site → answer in chat; only propose file edits when explicitly asked to change the site
- [Other People Reference off-limits](feedback_other_people_reference.md) — 31_Business/Other People Reference.md is private; never read, search, glob, or include in any mirror
- [Identity folder off-limits](feedback_identity_folder.md) — G:\My Drive\Actual Documents\Identity is completely off-limits; hook enforces on Read/Write/Edit/Bash/PowerShell
- [Task compartmentalization across sessions](feedback_task_compartmentalization.md) — CURRENT-TASK.md is folder/cwd-scoped so concurrent sessions in a shared folder collide; own folder per workstream, header blocks by session+date, never continue another session's ACTIVE block
