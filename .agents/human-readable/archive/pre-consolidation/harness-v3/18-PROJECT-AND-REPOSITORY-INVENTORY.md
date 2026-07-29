# Dated project and repository inventory

Inventory snapshot: 2026-07-27

This file preserves dated repository-location evidence. Re-run the inventory and project verifier before using counts, branches, dirty-file totals, or rollback status as current facts. The coordination repository's current canonical identity is `C:\Users\dougl\projects\general-ai`; `general-claude` paths are rollback or staging context.

## Result

Twenty-five canonical repositories now live under lowercase `C:\Users\dougl\projects`. Twenty-four use the shared structured project baseline; `agent-harness` uses the harness's own structure and verifier.

- repository `AGENTS.md`, Claude adapter, and Cursor project rule;
- `CURRENT-TASK.md`, `WORK_QUEUE.md`, `STATUS.md`, `LOG.md`, and `BACKBURNER.md`;
- concrete `VERIFY.md`, core-first `MAP.md`, `DESIGN.md`, and lean `MEMORY.md`;
- data, secret, and skill manifests;
- value-free `.env.example`;
- Gitleaks project configuration, CI workflow, and pre-commit hook;
- `C:\Users\dougl\Data\Projects\<project>\{inputs,runtime,outputs,private}`.

All 24 project-baseline repositories pass `Test-AgentProjectState.cmd`. The new `general-claude` coordination repository is committed locally and clean; publishing it as a new private GitHub repository requires Douglas's explicit repository-creation approval.

## 2026-07-27 migration state

- Nine inactive repositories were copied from the old OneDrive workspace and verified with exact tree hashes, Git state comparisons, and the project verifier.
- `base-flight-finder` and the `flight-tracker` coordination folder were copied and verified independently.
- The old incomplete 4.48 GiB umbrella copy was preserved reversibly as `C:\Users\dougl\projects\general-claude-incomplete-20260727`.
- A lean coordination repository now lives at `C:\Users\dougl\projects\general-claude`.
- The 168 main repository now lives at `C:\Users\dougl\projects\168-audit`. Its exact replacement worktree is `C:\Users\dougl\Worktrees\168-audit\codex-168-audit-redesign-relocated`.
- Berkeley's exact published completion commit now has a replacement worktree at `C:\Users\dougl\Worktrees\berkeley-house\agent-property-finance-completion-relocated`.
- The old 168 and Berkeley worktrees remain registered rollback copies. The active workspace ACL denies directory deletion, so their physical removal must occur after this workspace closes.
- `ASME_IDETC_2026.zip` was copied to `C:\Users\dougl\Data\Projects\idetc-writing-ide\inputs` and verified by SHA-256.

The canonical repository names are:

`agent-harness`, `anna-maria-mcgowan`, `base-flight-finder`, `berkeley-house`, `bible-name-search`, `boundaries-reader`, `claude-global-config`, `client-portal`, `conference-tracker`, `contact-form-caller`, `docket`, `drive-organizer`, `fellowship-tracker`, `general-ai`, `grandpa-help`, `harness`, `harness-bootstrap-verification-20260726`, `idetc-writing-ide`, `jars-of-clay`, `kelly-uniforms-business`, `legal-doc-studio`, `legal-solutions-website`, `motion-to-dismiss`, and `redline-idetc`.

## Historical pre-migration manifest

The table below records the 2026-07-26 source locations used for migration evidence. Use the lowercase canonical roots listed above for new sessions.

| Repository | Local path | Current branch | Remotes | Bootstrap |
|---|---|---:|---:|---|
| 168-audit-redesign | `C:\Users\dougl\OneDrive\Documents\General Claude\168-audit-redesign` | `codex/168-audit-redesign` | 1 | Verified |
| boundaries-reader | `C:\Users\dougl\OneDrive\Documents\General Claude\boundaries-reader` | `main` | 1 | Verified |
| claude-global-config | `C:\Users\dougl\OneDrive\Documents\General Claude\claude-global-config` | `master` | 1 | Verified |
| contact-form-caller | `C:\Users\dougl\OneDrive\Documents\General Claude\contact-form-caller` | `master` | 0 | New local repository; verified |
| drive-organizer | `C:\Users\dougl\OneDrive\Documents\General Claude\drive-organizer` | `master` | 0 | New local repository; verified |
| base-flight-finder | `C:\Users\dougl\OneDrive\Documents\General Claude\flight-tracker\base-flight-finder` | `codex/award-comparison-workspace` | 1 | Verified |
| grandpa-help | `C:\Users\dougl\OneDrive\Documents\General Claude\grandpa-help` | `master` | 0 | New local repository; verified |
| harness | `C:\Users\dougl\OneDrive\Documents\General Claude\harness` | `master` | 0 | New local repository; verified |
| harness-bootstrap-verification-20260726 | `C:\Users\dougl\OneDrive\Documents\General Claude\harness-bootstrap-verification-20260726` | `master` | 0 | Disposable verifier; verified |
| idetc-writing-ide | `C:\Users\dougl\OneDrive\Documents\General Claude\idetc-writing-ide` | `master` | 0 | New local repository; verified |
| motion-to-dismiss | `C:\Users\dougl\OneDrive\Documents\General Claude\motion-to-dismiss` | `master` | 0 | New local repository; verified |
| vault-review-mobile | `C:\Users\dougl\OneDrive\Documents\General Claude\vault-review-mobile` | `master` | 0 | Recovered repository; verified |
| anna-maria-mcgowan | `C:\Users\dougl\projects\anna-maria-mcgowan` | `master` | 0 | Verified |
| berkeley-house | `C:\Users\dougl\projects\berkeley-house` | `main` | 1 | Verified; credential review parked |
| client-portal | `C:\Users\dougl\projects\client-portal` | `fix/app-quality-pass` | 1 | Verified |
| conference-tracker | `C:\Users\dougl\projects\conference-tracker` | `fix/app-quality-pass` | 1 | Verified |
| fellowship-tracker | `C:\Users\dougl\projects\fellowship-tracker` | `fix/app-quality-pass` | 1 | Verified; credential review parked |
| jars-of-clay | `C:\Users\dougl\projects\jars-of-clay` | `main` | 1 | Verified |
| legal-doc-studio | `C:\Users\dougl\projects\legal-doc-studio` | `master` | 1 | Verified |
| legal-solutions-website | `C:\Users\dougl\projects\legal-solutions-website` | `main` | 1 | Verified; credential review parked |
| redline-idetc | `C:\Users\dougl\projects\redline-idetc` | `main` | 1 | Verified |

## Gitleaks review boundary

The additive structure and staged-file pre-commit hooks are installed everywhere. Three current-tree scans require a human-controlled review of tracked content:

| Repository | Tracked file | Location | Required outcome |
|---|---|---:|---|
| berkeley-house | `.github/workflows/ci.yml` | line 29 | Determine genuine credential or false positive |
| fellowship-tracker | `data/scholarships.json` | line 2910 | Determine genuine credential or false positive |
| legal-solutions-website | `CLAUDE.md` | line 90 | Determine genuine credential or false positive |

The detected strings were never read or displayed. Each project `BACKBURNER.md` carries a blocked credential-review task. Genuine credentials require rotation or revocation before content/history remediation. Confirmed false positives receive a narrow evidence-backed allow rule.

Ignored `.env.local`, `.next`, and cache artifacts also trigger a raw directory scan. They remain outside Git. Pre-commit uses a redacted staged-content scan.

## Existing work and dirty repositories

The copied repositories preserve their exact prior Git state, including user and agent changes. A dirty repository has tracked modifications, staged changes, or untracked files relative to its current commit. Dirty state is valid during active work and must be preserved across migration. The replacement worktrees carry the finished commits and project contracts; old worktrees are rollback copies pending ACL-safe cleanup.

## Non-repository folders

These stay outside the repository manifest:

- `.claude`, `Setup`, and `taskstate`: workspace/harness administration;
- `project-bootstrap-stage`, `cursor-rule-audit-stage`, `harness-bootstrap-stage`, `harness-update-stage`, and `skill-audit-work`: temporary or audit staging;
- `app-quality-fixes`: cross-project prompt material;
- the top-level `berkeley-house` folder: task-state material for `C:\Users\dougl\projects\berkeley-house`;
- the top-level `flight-tracker` folder: umbrella state around the nested `base-flight-finder` repository;
- `research`: shared cross-project briefs.

## Opening a project

Open the exact repository path in Codex or Cursor. The repository contract and adapters now load from that root. Run:

```powershell
C:\Users\dougl\.agents\tools\Test-AgentProjectState.cmd -Repository C:\path\to\repo
```

before dispatching a cloud agent or when readiness is uncertain.
