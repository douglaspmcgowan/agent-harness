# Task

## Goal

Finish and prove the portable Git-first harness, per-project data transport, selected Docket and large-data defaults, receiving-computer Capsule, and unattended secret injection.

## Active

- [~] T11 — Run full adversarial, secret-safety, portability, clone, restore, and harness verification | evidence: final 29-suite rerun, setup verifier, Gitleaks, CI, public links, and merge.

## Queue

- None.

## Blocked

- [!] T12 — Bootstrap the `Agent Runtime` Bitwarden project and per-computer machine token | blocked: Douglas must create or authorize the credential-bearing objects once; all non-secret setup proceeds first.

## Needs decision

- [?] T24a — Whether to disable Vercel Deployment Protection on the `hall-v-fleming` project.
  The deployment is live and Ready but returns 302 to Vercel SSO, so it is currently reachable
  only from Douglas's Vercel account. Turning protection off publishes a page naming a private
  individual and her litigation to the open, indexable web. Left ON pending an explicit decision.
- Otherwise none. The current implementation defaults are reversible and recorded in the spec.

## Completed

- [x] T24 — Research *Hall v. Fleming* (4th Cir. 2026), compare press framing, and publish a
  visual case history | evidence: full slip opinion extracted and read; three parallel research
  agents over religious-liberty press, secular/legal press, and doctrine/docket; Supreme Court
  docket scanned contiguously across OT2025/OT2026 ranges (no cert petition); Playwright render
  verified at 1280px and 390px with no horizontal overflow and no console errors; deployed to
  Vercel production (protection left ON — see T24a). Files under `sites/hall-v-fleming/`.
  Scope deliberately limited to the case and its coverage, not a personal profile of the litigant.

- [x] T1 — Implement topic-based GitHub project discovery with safe clone/pull decisions | evidence: integration tests and live `agent-project` inventory.
- [x] T2 — Implement the Google Drive SQLite snapshot adapter and Docket wrapper | evidence: atomic export/restore, checksum, retention, and path tests.
- [x] T3 — Normalize user-PATH executable discovery for agent processes | evidence: fresh-process resolver passes for every required installed executable.
- [x] T4 — Publish and verify Flight Tracker as a runnable GitHub project | evidence: public `master` at `a80ad6bd357d20e158d1dfe870f602b7033849f6`, `agent-project` topic, verifier, Gitleaks, GitHub Actions, and disposable-clone checks passed.
- [x] T5 — Reduce Capsule to the global harness plus approved Obsidian configuration | evidence: five scoped suites, disposable package inspection, and adversarial alias review passed.
- [x] T6 — Implement the fail-closed Bitwarden Secrets Manager command broker | evidence: tuple allowlist, Credential Manager bootstrap, redaction, and isolation tests.
- [x] T7 — Make task intake store questions as actionable queue tasks without an answers section | evidence: skill, hook reminder, project verifier, and regression tests passed.
- [x] T8 — Inventory retained local projects and give each one a valid remote or an explicit retirement mapping | evidence: Flight Tracker, Kelly, and Anna have verified remotes, topics, scans, actions, and clone checks; retained inventory has no unexplained remote gap.
- [x] T15 — Inventory the current Capsule payload by category and identify safe pruning candidates | evidence: 401 shared-harness files plus promoted runtime files and manifests were categorized; three hook dispatchers are active and remaining hook files are support/tests.
- [x] T22 — Implement DVC with Google Drive as the default commit-linked large-data adapter | evidence: independent disposable-repository proof passed for publish, receiving-computer clone/retrieve, checksums, corruption, stale/dirty protection, missing Drive delivery, upstream Git movement, rollback, and nested-junction rejection.
- [x] T9 — Consolidate the human guide and architecture map, including Git, Drive data, Bitwarden, PATH/sandbox boundaries, Capsule, recovery, separated project files, and phone-safe links | evidence: deterministic Markdown/HTML guide verifier and architecture/spec review passed.
- [x] T13 — Reconcile the real Docket data authority and portable export with the selected storage design | evidence: manifest, live authority, complete export, stale-write rule, restore drill, and verifier agree.
- [x] T14 — Reconcile Docket’s current architecture with phone access and present discrete storage options | evidence: repository inspection, current-source recon, selected Vercel Blob design, and phone acceptance passed.
- [x] T16 — Reconcile the general cross-device project-state problem across repository state, large project data, live shared state, and machine/harness state | evidence: SPEC and human guide define the data classes and decision rules.
- [x] T17 — Establish the technology-neutral cross-device portability specification and map the recon to its requirements | evidence: SPEC requirements, acceptance scenarios, decisions, and traceability passed independent review.
- [x] T18 — Define the separated per-project file architecture and phone-safe document link policy | evidence: templates, verifier, human guide, and spec agree.
- [x] T19 — Consolidate the conflicting legacy and v3 project-bootstrap/verifier paths into one project architecture | evidence: compatibility entrypoints, templates, docs, and verifiers use the same managed v3 files.
- [x] T20 — Remove the superseded Bitwarden Password Manager scaffold/broker path after proving no live consumer remains | evidence: Capsule and harness expose only the Secrets Manager machine-token broker.
- [x] T21 — Implement hardened Vercel Blob as Docket's selected authority | evidence: schema validation, conditional-write concurrency, complete export, safe restore, and phone/browser verification passed in production.
- [x] T23 — Implement the default recovery retention policy of 3 daily, 4 weekly, and 3 monthly points with per-project override | evidence: retention boundary tests and guide/spec decision record passed.
- [x] T10 — Refresh the installed harness and Google Drive Capsule from the verified source | evidence: global setup verifier passed; Drive Capsule independently verified 482 files with the approved Obsidian configuration; nine retired Password Manager artifacts are absent from active global state.

## Verification

- Next: run all 29 harness regression and integration suites, then merge and publish PR #8.
