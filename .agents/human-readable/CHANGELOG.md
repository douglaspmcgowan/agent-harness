# Agent Harness Setup changelog

## 2026-07-29 — Git-first portable architecture

- Installed a profile-wide Cursor 3.x rule at `.cursor\rules\00-agent-harness.mdc`, backed up and removed the stale cross-agent loader, and left the cloud User Rules paste as optional.
- Made global installation back up and remove the retired Bitwarden Password Manager scripts, scaffold manifests, tests, and local scaffold IDs so only the Secrets Manager route remains active.
- Made the canonical Capsule entrypoint prefer its own committed `.agents` tools automatically, preventing an older Drive package from overriding a newer release during refresh.
- Pinned the production Bitwarden broker to the interactive Windows profile's trusted executable, allowlist, credential module, and Credential Manager target; test injection now lives in a credential-isolated core module.
- Replaced the organization-licensed Gitleaks action with a checksum-pinned free Gitleaks CLI workflow that scans complete Git history.
- Corrected DVC first-publication safety across independent Google Drive replicas: remote content is immutable and additive, failed publication never recursively deletes remote bytes, the temporary claim is documented as same-host only, and guarded Git publication remains the cross-computer pointer compare-and-swap.
- Defined the current release as Windows 10/11 receiving-computer reconstruction with Claude, Codex, and Cursor parity; macOS and Linux adapters and acceptance runs remain deferred.
- Replaced the transitional workspace-sync model with a Git-first map: GitHub repositories carry source and committed project state, and the `agent-project` topic drives safe dynamic discovery.
- Organized cross-device portability around repository state, large project data, live shared application state, and machine/harness state.
- Added the decision lanes for Git LFS, DVC with a Google Drive remote, plain Drive artifacts, Supabase, and regeneration, with practitioner and primary-source evidence.
- Recorded the completed global-only Capsule boundary, approved Obsidian configuration portability, and a fresh passing synthetic package scan; the exact file baseline remains deferred while concurrent source additions change the assembled count.
- Preserved the verified implementation map of three externally wired hook dispatchers: security, task state, and continuation.
- Defined `C:\Users\dougl\Data\Projects` as the local project-data root and `C:\Users\dougl\My Drive\Project Data` as the portable artifact root governed by per-project `data-manifest.yaml` adapters.
- Documented SQLite, Git LFS, DVC, plain Drive, Supabase, and Vercel Blob as discrete data choices, including Supabase export limits and three evidence-based Docket options.
- Selected reversible v3 defaults: hardened Vercel Blob for Docket, DVC with Google Drive for commit-linked large data, plain Drive for human and immutable files, and per-project retention of 3 daily, 4 weekly, and 3 monthly recovery points with manifest overrides.
- Made Docket's full repository `SPEC.md` normative for feature parity and recorded `action: "more"` as the request-more decision form replacing a product-level ticket entity.
- Replaced Password Manager Login-item scaffolding guidance with one Bitwarden Secrets Manager `Agent Runtime` project, prefixed keys, per-computer machine accounts, and an exact-command broker.
- Added the executable/PATH and sandbox security-context map, task-only question tracking, current human bootstrap, and production-refresh blockers.
- Linked the technology-neutral `SPEC.md` as the functional, acceptance, and recon-traceability contract while retaining this guide as the one human entrypoint.
- Documented the exact repository-owned project-file set and the phone-safe sharing boundary: GitHub web links for repository files, Drive share links for external artifacts, and Windows paths for the computer that owns those local files.
- Finalized the canonical 13-file human core with `skills-manifest.json`; commands live in `AGENTS.md`, while verifier evidence and the exact next command live in `TASK.md`. Clarified that `DESIGN.md` carries managed universal interface rules plus project-specific interface rules and exceptions, and separated generated/support files required by `Test-AgentProjectState`.
- Removed OneDrive from the active provider architecture.

## 2026-07-29 — Portable setup and retention corrections

- Defined the target Capsule boundary as the shared global harness, bootstrap/verification tools, and value-safe repository inventory; project code/rules/handoffs/small data stay in GitHub and excluded/live data uses reviewed `data-manifest.yaml` adapters.
- Recorded the implementation gap that current backup, refresh, bootstrap, and restore code still packages legacy workspace/project/application data.
- Changed the documented local harness-snapshot retention target to 3 daily, 4 weekly, and 3 month-end recovery points; automatic deletion remains disabled because the current creator has no pruning tool.
- Replaced active OneDrive-preservation instructions with a provider-neutral sync-root, known-folder, collision, and local-staging preflight while retaining Google Drive's `My Drive\Capsule` as setup transport.
- Corrected the value-free Docket publisher tuple to `C:\Users\dougl\projects\docket\sync-cloud.js`.
- Replaced the default quarantine deletion primitive with validated extended-length inspection and `robocopy /MIR /XJ /R:1 /W:1` empty-tree cleanup; injected persistent failures remain bounded and recoverable.

## 2026-07-29 — Simplified cross-agent authority

- Consolidated shared behavior into global `AGENTS.md`, universal interface rules into `DESIGN.md`, runtime ownership into `MAP.md`, and recall pointers into lean `MEMORY.md`.
- Added one idempotent `Manage-Harness.ps1` path for global installation, project starters, selected skill projection, verification, source-hash parity, deterministic stamping, and dry runs.
- Preserved the live Codex `AGENTS.md` and produced a section-by-section edit proposal.
- Replaced the split current-task and queue model with one concise `TASK.md`; the tested migration archives and removes the three retired root files after preserving state.
- Consolidated product hook wiring to security, task-state, and continuation dispatchers while retaining tested legacy modules behind the dispatchers.
- Replaced raw prompt telemetry with length, line count, SHA-256, structural counts, and routing flags.
- Made the global package portable across Windows profiles by rendering product-adapter home paths and including every baseline skill source.
- Consolidated the active human documentation into this guide and its source-hash-verified HTML mirror; prior topical briefs remain in the archive.
- Changed personal Docket publication to every valid unresolved personal card, excluded local resolved and archived IDs, guarded pulled decisions, and reduced its Bitwarden mapping to one `REVIEW_SECRET` plus the separate blob token.
- Recorded Docket pull request #2 at `32d2346`: strict cloud-archive verification, 162 local items reconciled, two stale setup cards archived, and 160 cards left outbound.
- Added one Capsule entrypoint and a self-contained backup, refresh, verify, alternate-profile restore, integrity, and traversal regression test.
- Recorded the public GitHub authority and retained credential values outside Git, Capsule, logs, and command arguments.
- Reconciled the human guide with the verified `20260729-081324` Capsule, three live hook dispatchers, completed `TASK.md` migration, merged Docket client, and remaining credential/RAMMap gates.
- Made `README.md` the Capsule entrypoint and changed receiving-computer verification commands to resolve the actual open Capsule folder across Google Drive path variants.
- Packaged `Refresh-Capsule.ps1` under Capsule `tools`, taught deployed refreshes to resolve their root assets, and preserved same-path account/software maps and tools during `Harness.ps1 -Action sync`.
- Added an assembled source-to-Capsule-to-second-snapshot regression that requires the packaged refresh tool, integrity coverage, successful deployed sync, and byte-for-byte account-map preservation.
- Recorded the corrected live deployment: snapshot `20260729-081324`, 34,062 integrity records, packaged refresh-tool coverage, preserved account-map contents, and a roughly 743.55 MB Gitleaks scan with no leaks.
- Enforced one selected `payload\workspace` snapshot per assembled Capsule; unselected immediate non-reparse siblings are pruned only after the new package passes scanning, integrity generation, and verification, then final integrity and verification run again.
- Replaced direct workspace pruning with a same-volume temporary quarantine transaction that rejects and revalidates reparse roots, rolls back pre-commit failures to a verified state, commits only after selected-state integrity verification, and preserves verified recovery when quarantine cleanup fails.
- Serialized refreshes with an exclusive per-Capsule lock, rejected reparse points across existing ancestor chains, journaled move intent before mutation, and rechecked the exact workspace set after verification.
- Changed `Harness.ps1 -SourceRoot` resolution to prefer the supplied source tools over stale packaged Capsule tools, with packaged fallback preserved for receiving computers.
- Reconciled the Docket protocol with the local SQLite authority, 162-card value-safe inventory, two archived decisions, 160 unresolved publication candidates, authenticated unresolved-only sync, and strict cloud-archive acknowledgement.
- Aligned the project-state verifier with the consolidated `TASK.md` contract and added a regression that rejects projects missing `TASK.md`.
- Replaced hard-coded Capsule snapshot, integrity-count, and scan-size claims in active guides with the generated manifest and verifier authorities.
- Added three bounded, fully revalidated quarantine-cleanup attempts after a real Windows missing-child race; persistent failure still preserves the verified selected Capsule and reports the exact quarantine.
- Fixed Bitwarden Login scaffold assembly for base item templates that omit the `login` property and added a value-free create-mode regression covering the real creator path.

## 2026-07-29 — Human-readable consolidation

- Added the `declog` skill with fixture-tested active-tree protection, cycle-safe ancestry traversal, fail-closed candidate revalidation, and read-only live reporting.
- Added value-safe Bitwarden Password Manager Login scaffolds for eight evidenced projects and a creator that requires an already-unlocked CLI session.
- Added a portable nightly-backup task installer with catch-up, battery-safe execution, a limited interactive account, and a six-hour ceiling.
- Reproduced severe desktop latency at 97% physical-memory use. Stopping the in-progress backup improved the baseline; stopping Google Drive produced the largest measured CPU and disk reduction.
- Reduced active human navigation to README, briefs 08, 09, 10, 11, 15, 18, and 21, plus the update protocol and changelog.
- Moved superseded topic briefs into `archive/topics`, dated audits into `archive/audits`, and the ZIP64 recovery record into `archive/incidents`.
- Consolidated architecture/session guidance into brief 08; Bitwarden Password Manager Login-item and Hidden-field operations into brief 09; skill audits, durable corrections, and conceptual declog routing into brief 10; and storage, nightly backup, Drive, and retention guidance into brief 15.
- Made the direct My Drive Capsule folder the primary receiving-computer route in brief 21.
- Recorded the Nightly Agent Backups task as Ready with a daily 02:00 trigger; successful snapshot `20260729-002722` now supplies the current recovery pointer.
- Refreshed and integrity-verified the Documents and My Drive Capsule copies from snapshot `20260729-002722`.
- Regenerated `setup-stamp.json` after deploying the consolidated tree.
- Recorded the premature-completion and insufficient-parallel-dispatch incident as a shared value-free feedback item; task-state completion enforcement remains a tested follow-up.
- Fixed the feedback recorder's empty-field trailing whitespace and added a regression assertion so correction logs pass Git whitespace validation.

## 2026-07-28 — Capsule operating map and process-safety correction

- Added a dry-run-first stale-agent-process cleanup, regression fixture, four-times-daily limited-user task installer, active-agent exclusions, immediate revalidation, and value-free audit log.
- Published Capsule under `Google Drive\My Drive\Capsule` as the direct cross-computer entry and retained the Google Drive Computers route as a fallback.
- Added the exact remaining human Bitwarden steps and Docket credential boundary to Capsule.
- Added Capsule's agent entry point, cross-computer update model, excluded-data routes, account-field guidance, Bitwarden responsibility boundary, GitHub transport explanation, and documented retention recommendation.
- Added the complete Capsule connection map to the human-readable harness brief.
- Recorded the Codex renderer shutdown failure and prohibited per-renderer termination inside the active `OpenAI.Codex` process tree.
- Added receiving-computer OneDrive preservation and migration-gate instructions.
- Added the Windows security-context check that prevents repeated GitHub authentication prompts from sandbox-only credential failures.

## 2026-07-27 — Capsule portable recovery and `general-ai`

- Added Capsule as the transferable Windows rebuild package with offline bundles for every committed repository, approved app data, the portable harness, setup guidance, and SHA-256 integrity records.
- Renamed the coordination authority to `general-ai` while retaining `general-claude` as the active-session rollback copy.
- Recorded Bitwarden Password Manager Free as the unlimited-project credential authority and added the full second-computer procedure.
- Updated repository restore to prefer offline bundles so initial GitHub authentication can be completed later in the rebuild.
- Added a fail-closed current-tree bundle fallback for repositories whose older Git history contains known Gitleaks findings.
- Made that fallback omit and count any still-flagged current-tree files, then require the reduced bundle to pass Gitleaks.
- Made Capsule and recovery JSON readers explicitly UTF-8 and added a Unicode-filename restore regression.
- Required every bundle to clone into an empty temporary repository during backup and added current-tree fallback for partial local object stores.
- Restored recorded GitHub URLs as `origin` while retaining each offline bundle as the `capsule` remote.

## 2026-07-27 — Portable workspace recovery installed

- Installed nightly portable workspace snapshots, three-mode project restore, approved application-data export, transactionally consistent SQLite backup, full-tuple Password Manager brokering, and deterministic File Explorer Quick Access recovery.

## 2026-07-27 — Personal-file Drive coverage clarified

- Kept local Desktop, Documents, and Downloads as intentional Google Drive computer-folder roots.
- Removed the earlier recommendation to deselect Downloads.
- Documented continuous Google Drive synchronization and the current event-driven Agent Backups cadence.
- Recorded that no nightly Agent Backups scheduled task exists yet.
- Reconciled the concurrent action-required handoff rule and its verifier coverage into the canonical harness repository.

## 2026-07-27 — Local folders and free secrets model

- Repointed Google Drive guidance to the live local Desktop, Documents, and optional Pictures folders after the OneDrive exit.
- Kept live repositories, worktrees, product state, and mutable application data outside broad folder sync.
- Made Bitwarden Password Manager Free the unlimited-project human/local authority.
- Documented platform-native deployment secrets and Doppler's current ten-project free alternative.
- Clarified that local Docket needs no passcode while its public Vercel API requires `APP_SECRET`/`REVIEW_SECRET`.

## 2026-07-27 — Lowercase migration and Docket loopback repair

- Moved the 168 main repository to `C:\Users\dougl\projects\168-audit`, bootstrapped it, and created an exact replacement worktree under `C:\Users\dougl\Worktrees`.
- Created a Berkeley replacement worktree from published commit `e4e8b53`, applied the cross-agent baseline, and parked two redacted historical Gitleaks findings for value-safe review.
- Recorded that the old worktree directories cannot be deleted while the active workspace ACL denies directory deletion.
- Copied missing personal Desktop, non-General-Claude Documents, Pictures, and Attachments files into normal local Windows folders without overwriting collisions; the follow-up missing-file comparison is clean.
- Stopped Google Drive again after it auto-restarted; the database still shows nine unsafe computer-folder roots plus the normal streamed My Drive row.
- Migrated and content-verified inactive repositories into `C:\Users\dougl\projects`; preserved the active 168 and Berkeley linked worktrees at their current paths.
- Replaced the incomplete umbrella copy with a lean, bootstrapped `general-claude` coordination repository and retained the incomplete copy under a dated reversible name.
- Copied the IDETC archive into its per-project data folder and verified matching SHA-256 hashes.
- Imported five setup handoff cards into Docket, bringing the local total to 162.
- Repaired Docket's loopback API authentication with socket validation and an unspoofable in-process marker while preserving fail-closed cloud authentication; all 73 tests pass and Gitleaks is clean.
- Read the stopped Google Drive client's root-preference database in read-only mode and confirmed nine unsafe broad selected folders; documented their required Preferences removal.
- Recorded the expired GitHub CLI credential and pending device confirmation.
- Reauthorized GitHub CLI in the Windows keyring, configured the reusable Git HTTPS helper, pushed Docket commit `33b00f4` and the current harness documentation, and refreshed the remote-verified recovery pointer.

## 2026-07-27 — Private Git authorities, human-readable relocation, and safer backup boundary

- Published the five reviewed harness commits and verified the clean lowercase clone at `C:\Users\dougl\projects\agent-harness`.
- Created the private `douglaspmcgowan/docket` repository, added its Gitleaks workflow, and verified its lowercase clone with 69 passing tests and zero Gitleaks findings.
- Established `C:\Users\dougl\.agents\human-readable` as the canonical explanatory layer beside the live agent contracts.
- Standardized current documentation on the lowercase `C:\Users\dougl\projects` root.
- Replaced broad Google Drive backup recommendations with the curated `C:\Users\dougl\Documents\Agent Backups` recovery-artifact folder and paused Drive while its unsafe roots are removed.
- Documented Bitwarden Secrets Manager Free as the current no-cost Docket secret workflow, including the human setup steps and agent handoff.
- Removed BitLocker from the active security backlog while retaining its readiness brief as reference material.
- Recorded that OneDrive is uninstalled and its old data tree remains temporarily for safe migration and active-session continuity.
- Removed roughly 7.3 GiB of obsolete OneDrive AppData residue and installed an exact-path `RunOnce` cleanup for the final shell-locked files.
- Completed GitHub CLI browser authorization and verified persistent keyring access to both private repositories.
- Marked the partial lowercase General Claude copy as migration-incomplete so no agent treats it as authoritative before the Google Drive cleanup and completion comparison.

## 2026-07-26 — Tracked shared harness, skill projection, and isolated Docket verification

- Added deterministic Claude skill projection and exact-hash adapter approval tooling; the current 50-skill projection resolves with zero conflicts.
- Added the portable shared layer and reviewed Claude adapters to `ai-consulting-1/doug-harness`, scrubbed restricted-machine tokens, scanned 14.6 MB with Gitleaks, and pushed the resulting commits.
- Established `C:\Users\dougl\projects\agent-harness` as the stable clean local clone and updated live remotes to the repository’s current GitHub location.
- Expanded the semantic Skills Docket to 157 cards.
- Repaired the four broken skill entries, reduced the always-triggering superpowers compatibility skill to a capability-based pointer, removed the forbidden font reference, and reran the audit with zero broken records.
- Added stale-card archival and a regression test to the Docket builder; the canonical outbox now contains exactly 157 current cards and preserves the prior 161-file set under history.
- Added a tested Docket outbox importer, loaded the final 157-card set into local SQLite, and verified the loopback UI at port 8471; the Docket suite now has 69 passing tests.
- Added a Bitwarden Secrets Manager runtime broker, exact Docket publisher allowlist, and subprocess regression test proving one-secret injection, bootstrap-token isolation, parent restoration, and rejection of unapproved arguments.
- Replayed Docket’s SQLite migration, compatibility, and rollback behavior in an isolated worktree; all 67 tests and Gitleaks passed.
- Added a safer backup-pointer exporter. Its OneDrive metadata write remains approval-gated; no full repository bundle was copied into a synced folder.

## 2026-07-26 — Tactician command discovery

- Added a thin `source-command-tactitian` compatibility alias for Douglas's common spelling.
- Verified that the alias points to the canonical `source-command-tactician` procedure and keeps one implementation.
- Documented command spelling aliases in the skills-and-adapters brief and refreshed the harness integrity stamp.

## 2026-07-26 — Portable judgment baseline, feedback, and Docket SQLite

- Promoted Douglas’s portable judgment rules into a versioned managed repository block and verified adoption across all 21 structured repositories.
- Added the cross-platform `feedback` skill, append-only shared/project logs, a value-free recorder, and non-exclusive enforcement lists.
- Vendored the feedback skill into every repository for cloud-agent readiness.
- Documented the exact Google Drive whole-folder decision; the safe immediate Drive “Add folder” list is empty pending sanitized exports.
- Implemented Docket’s local SQLite authority with current and previous JSON exports; all 67 tests pass.
- Recorded GitHub authentication as the remaining blocker for creating and pushing the private Docket remote.

## 2026-07-26

- Applied the structured project baseline to fifteen existing repositories and initialized six clear non-Git project folders as local repositories.
- Replaced twenty placeholder verification contracts with repository-specific commands and filled sixteen evidence-based project purposes.
- Verified all twenty-one repositories with the strict project-state verifier and created matching four-directory local data roots.
- Fixed `Enable-Gitleaks.ps1` to resolve PowerShell application commands through `Source`, then added and passed a disposable regression test.
- Recorded three value-safe Gitleaks review blockers in their project backlogs without reading detected strings.
- Added the durable twenty-one-repository inventory and excluded administrative, staging, duplicate-state, and umbrella folders.
- Reduced Cursor automatic global-rule loading from eighteen rules to ten while retaining credential, monitoring, task-state, repository, overwrite, research-verification, and UI safety.
- Replaced stale Cursor monitoring, credential-storage, rollover, and repository-map instructions with current cross-agent contracts and preserved backups.
- Verified Cursor Desktop 3.13.10 permission state: CLI Auto-review with explicit allow/deny tokens, classifier instructions, IDE auto-run enabled, full auto-run disabled, and retained legacy command state.
- Documented the local and cloud session-start guarantees, including the fourteen-repository adoption inventory.
- Added a two-axis feedback router for selecting shared, platform, project, path, provider/model, or human scope and rule, skill, memory, verifier, hook, permission, or brief enforcement.
- Recorded the 18 always-applied Cursor feedback/contract rules as a consolidation backlog rather than treating every correction as permanent global context.
- Added a value-free host environment metadata probe and contract rule so sandboxed process misses cannot be misreported as machine-wide absence.
- Created the durable Setup documentation system.
- Documented session startup, resume, handoff, project contract, bootstrap, storage, SQLite, Bitwarden, BitLocker, Gitleaks, Google Drive, and product ownership.
- Installed checksum-verified SQLite CLI 3.53.4 and Gitleaks 8.30.1.
- Added automatic Gitleaks hooks for future repositories and adoption tools for existing repositories.
- Verified the native Git hook with a safe commit and a synthetic blocked finding.
- Installed and scanned Gitleaks hooks in `boundaries-reader` and `claude-global-config`; deferred the active flight-tracker repository.
- Added project bootstrap tooling and Gitleaks CI templates.
- Verified the full project bootstrap in a disposable user-owned repository: 11 repository files, four data directories, the Git hook, and the initial Gitleaks scan.
- Hardened the Bitwarden broker by removing `BW_SESSION` from the child environment and requiring an exact executable allowlist.
- Verified that a broker child receives the selected field, cannot observe `BW_SESSION`, and blocks an executable absent from the allowlist.
- Added a shared task-state resolver and updated Cursor continuity adapters.
- Caught and fixed an unrelated-root-task injection during integration testing.
- Corrected two Cursor security hooks to emit deny responses and documented current Cursor hook limitations.
- Added a Cursor global shared-contract rule.
- Established documentation freshness and verification requirements.
- Recorded that current Google Drive configuration does not prove coverage for the shared harness or data roots.
- Recorded that Device Encryption status requires Douglas's elevated Settings check.
- Added a concise cross-product context-loading map and removed the human Setup README from Claude's always-imported context.
- Added full task-state, cloud-session, secrets, skill-adapter, Docket, and ZIP64 operating briefs.
- Expanded the project bootstrap with portable cloud rules, Cursor adapter, verification/map/design/memory files, and value-free secret and skill manifests.
- Added deterministic secret-manifest refresh/check tooling and per-skill Docket-card generation.
- Corrected Google Drive coverage: OneDrive Documents is one of the three configured roots, so `General Claude` has configured Drive coverage while Projects, Data, and the shared harness remain outside it.
- Recorded the missing Docket local client/daemon and established a durable card outbox pending authenticated restoration.
- Audited the full shared skill catalog and grouped findings per skill.
- Added the `skill-audit` canonical skill, structural scanner, semantic rubric, and 156-card Docket outbox.
- Added qualified skill identities for canonical skills, aliases, product adapters, provider/model modules, and project bindings.
- Updated `Codex-sync` with a shared-harness/Claude-projection reconciliation phase and one-way canonical ownership.
- Documented the transitional permanent dirty-file model and its divergence-manifest replacement.
- Changed the secret-exposure hook response contract to continue automatically with metadata-only evidence and ask Douglas only when a safe fallback cannot complete the task.
- Added a repeatable subprocess test covering blocked reads, environment dumps, benign reads, and malformed input.
- Forward-tested `skill-audit` and added a Windows launcher, multi-root invocation, classification precedence, strict shared frontmatter rules, severity aggregation, and broader provider/path signals.
- Documented Codex question, approval, automation-notification, and runtime capability boundaries; removed any shared assumption that `AskUserQuestion` is universally available.
- Installed checksum-verified Bitwarden Secrets Manager CLI 2.1.0 under `C:\Users\dougl\Tools\bws`.
- Moved the canonical human Setup folder into the Google-Drive-covered workspace and added openable start/map copies.
- Added the human/agent document classification, core-document map, backup inventory, and cloud-agent preparation brief.
- Added additive first-open repository adoption, a new-repository wrapper, project-state verification, and selected-skill cloud projection.
- Expanded the portable repository contract with Douglas’s machine-independent rules and explicit document-update triggers.
- Extracted and verified `FOR-DOUGLAS.zip`, moved its `personal-internal` bundle outside Drive coverage, and restored the Docket source repository.
- Verified all 65 recovered Docket tests; recorded the missing remote and credential-dependent publication boundary.
- Bound Bitwarden broker approvals to the exact executable, argument list, destination variable, and secret ID; the Docket publisher remains fail-closed until its real value-free secret ID is recorded.
- Added an exclusive Skills Docket outbox lock and a regression test that blocks concurrent builders before any card changes.
- Synchronized the safer-alternative secret guard and its subprocess test into Codex’s active hook directory after a stale Codex copy demanded an unavailable product-specific question tool.
