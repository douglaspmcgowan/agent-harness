# SPEC

## Product

### Problem

Douglas works across multiple Windows computers and more than ten software projects with Claude, Codex, and Cursor. Four kinds of state must move between computers:

1. repository state: source code, project configuration, schemas, migrations, project rules, task status, and handoffs;
2. external project data: datasets, media, application databases, exports, and generated artifacts that are too large or too active for ordinary Git;
3. live application state: records that phones, computers, users, or agents must read and update through a deployed application;
4. machine and harness state: shared agent rules, skills, hooks, tools, approved application configuration, executable discovery, and credential access.

The current environment uses several partial transports. A receiving computer needs one declared reconstruction flow that identifies the authority for every required asset, retrieves it through the correct transport, and proves that the restored project works.

This release defines **agent-platform portability on Windows 10/11**: Claude, Codex, and Cursor share one contract and reconstruction model across Douglas's Windows computers. macOS and Linux require future OS adapters and their own receiving-computer acceptance runs.

### Users and jobs

- **Douglas** needs to open another computer, restore the shared agent environment, retrieve every retained project, and continue work with current project state and data.
- **A receiving agent** needs deterministic instructions that it can execute without inventing paths, providers, credentials, or restore procedures.
- **A project agent** needs to know which files belong in Git, which data lives elsewhere, which adapter it may run, and what evidence proves a safe sync or restore.
- **A deployed application client** needs current shared data from a phone or computer with defined authentication, concurrency, and recovery behavior.

### Outcomes

- Every retained project has a reachable Git remote or a documented retirement mapping.
- Every required non-repository asset has one declared authority, transport, restore procedure, and verifier.
- A receiving computer can reconstruct the global harness and retained projects from declared authorities.
- Project code, status, and safe configuration converge through Git without placing active worktrees in a desktop-sync folder.
- Live multi-device application records converge through a network data service with defined conflict behavior.
- Large project data remains outside ordinary Git history while exact versions remain discoverable and verifiable.
- Backups are proven through restore exercises rather than presence checks alone.
- Credential values remain outside repositories, Capsule payloads, command arguments, logs, and transcripts.

### Scope

- GitHub repository discovery, clone, guarded pull, and project verification.
- Guarded publication of retained local repositories and project-state changes to their canonical remotes.
- Portable project contracts and task/status/configuration files.
- A versioned `data-manifest.yaml` contract for external project data.
- Reviewed project-data adapters for export, upload, download, restore, regeneration, and verification.
- Shared harness installation and recovery through the global Capsule.
- Approved Obsidian configuration portability without vault-content packaging.
- Executable discovery and approved access to the interactive Windows user's existing authentication context.
- A fail-closed credential broker for exact approved commands.
- Docket as the first complete live-data case study.
- Integrity, recovery, and adversarial verification.
- Windows 10/11 receiving-computer reconstruction with Claude, Codex, and Cursor parity.

### Non-goals

- Automatic merging of dirty, ahead, diverged, or wrong-origin repositories.
- Desktop file synchronization of active Git metadata or a database while it is being written.
- Packaging project checkouts, live project databases, dependency folders, caches, or build outputs inside Capsule.
- Selecting one storage technology for every project-data class.
- Replacing application-specific data models with a universal database.
- Offline-first Docket synchronization before the online multi-device authority is proven.
- macOS and Linux installation adapters in this release.

## Functional

### User stories

- As Douglas, I can stage one Capsule on another computer and let an agent install and verify the shared harness.
- As Douglas, I can retrieve all retained projects from GitHub through a topic-based inventory.
- As Douglas, I can see one map that explains where code, status, configuration, large files, live records, secrets, and backups live.
- As a project agent, I can read one manifest and know how each external asset is retrieved, updated, restored, and verified.
- As a project agent, I can safely decline an undeclared or path-escaping data operation.
- As a Docket user, I can review, archive, request more information, and record decisions from a phone or computer against one current data authority.
- As a receiving agent, I can distinguish an absent login from a sandbox visibility problem before starting a new authentication flow.
- As Douglas, I can recover data from a verified export if a live provider or local computer fails.

### Requirements

- **FR-001 — Repository authority:** Every retained project MUST declare one canonical Git remote or one explicit retirement mapping.
- **FR-002 — Dynamic discovery:** The system MUST discover published retained repositories from an explicit GitHub topic without a manually maintained repository list.
- **FR-003 — Guarded synchronization:** Repository synchronization MUST clone missing repositories and pull only clean default branches that have the expected origin and no ahead or diverged state.
- **FR-004 — Portable project state:** Each project repository MUST carry its project contract, map, design constraints, task state, durable status, work log, verification instructions, safe configuration examples, and data manifest when applicable.
- **FR-005 — Global Capsule boundary:** Capsule MUST carry the shared harness, bootstrap and verification tools, integrity metadata, value-safe setup information, and approved application configuration.
- **FR-006 — Capsule exclusions:** Capsule MUST exclude project checkouts, live application databases, project workspace snapshots, repository bundles, dependency folders, caches, and generated build output.
- **FR-007 — Data classification:** Every external asset MUST declare its class as immutable file, versioned large artifact, live document or object state, live relational state, local transactional state, portable export, or regenerable output.
- **FR-008 — Asset authority:** Every external asset MUST declare one authoritative source and MUST distinguish that authority from backup destinations and local caches.
- **FR-009 — Manifest fields:** Every external asset declaration MUST include a stable asset ID, project, class, authority, local destination, adapter, version rule, integrity rule, restore verifier, and regeneration rule when regeneration is possible.
- **FR-010 — Adapter allowlisting:** A receiving or project agent MUST execute only an adapter declared by the repository manifest and installed from a reviewed source.
- **FR-011 — Adapter safety:** Every mutating adapter MUST validate path containment, reject reparse-point escapes, use an atomic or provider-safe publish operation, preserve the prior recoverable state until the new artifact verifies, and reject a stale publish unless the manifest declares a single-writer lease.
- **FR-012 — Adapter modes:** Every project-data adapter MUST expose inspect, publish or export, retrieve or restore, and verify behavior appropriate to its asset class.
- **FR-013 — Large versioned data:** Data whose exact version belongs to a code revision MUST store version metadata in Git and content bytes in a declared large-data remote.
- **FR-014 — Modest repository binaries:** A project MAY use Git LFS when binary files belong directly to commits and their version frequency and storage consumption remain within the repository's declared budget.
- **FR-015 — Human and immutable files:** Human-edited documents, media, and immutable recovery exports MAY use a plain synchronized file provider when concurrent programmatic mutation is absent.
- **FR-016 — Local transactional data:** A local database MUST remain outside a desktop-sync root while active and MUST travel through a consistent database-native backup or export.
- **FR-017 — Live shared state:** Records that require multi-device writes, authentication, transactions, relational queries, or immediate network access MUST use a declared network data service.
- **FR-018 — Live-state structural authority:** A live data project's schemas, document contracts, migrations when applicable, safe fixtures, and generated types when useful MUST remain versioned with the repository.
- **FR-019 — Live-state recovery:** A live data project MUST declare complete off-site exports for its database, document store, and object bytes as applicable.
- **FR-020 — Regeneration:** Dependency folders, caches, and deterministic build artifacts MUST be reconstructed from committed source and declared commands.
- **FR-021 — Device bootstrap:** The receiving flow MUST verify Capsule, install the harness, restore approved application configuration, establish project-data roots, verify executables, reuse existing authenticated user context, discover repositories, verify projects, and run declared data adapters.
- **FR-022 — Executable discovery:** Required command-line tools MUST resolve in a fresh normal-user process through the Windows user PATH or a declared absolute fallback.
- **FR-023 — Authentication diagnosis:** An agent MUST verify the interactive user's existing authentication state before requesting another login when a sandboxed command cannot access user credentials.
- **FR-024 — Credential injection:** Credential values MUST be injected only into an allowlisted child process for the shortest practical lifetime and MUST be scrubbed afterward.
- **FR-025 — Hook consolidation:** The installed harness MUST route supported product events through a bounded declared dispatcher set while preserving security, task/lifecycle, notification, and continuation behavior.
- **FR-026 — Hook support code:** Hook libraries, legacy compatibility modules, fixtures, and tests MAY remain packaged when declared dispatchers call or verify them; they MUST remain unwired as separate hook processes.
- **FR-027 — Docket feature parity:** Docket's selected authority MUST satisfy the complete feature contract in `SPEC.md` from the canonical repository `https://github.com/douglaspmcgowan/docket.git` at migration baseline revision `f3688602c02a7f0c96b70427f7d78d68cf43f4e1`, including briefs, supported decision forms, stable IDs, phone access, views and grouping, embedded answerable cards, decisions and comments, archive/read behavior, `action: "more"`, safe ingestion, and result round trips.
- **FR-028 — Docket concurrency:** Docket's network authority MUST detect or prevent lost updates when two clients modify the same logical record or aggregate.
- **FR-029 — Docket recovery:** Docket MUST support a complete export and verified restore of every authoritative record required for feature parity.
- **FR-030 — Docket boundary decision:** Docket's final network authority MUST be selected from measured candidates after live concurrency, backup, effort, and complete feature-parity comparison.
- **FR-031 — Integrity records:** Every packaged Capsule payload file MUST have an integrity record, and verification MUST fail on a missing, changed, undeclared, or path-escaping payload.
- **FR-032 — Human map:** One Markdown guide and its HTML mirror MUST explain the complete authority, transport, update, and receiving-computer flow.
- **FR-033 — Recon traceability:** Each recommended storage or sync mechanism MUST map to the requirement it satisfies, its tradeoffs, and current primary and practitioner evidence when those categories are available. An unavailable evidence category MUST be labeled explicitly with the limitation and its effect on confidence.
- **FR-034 — Local repository reconciliation:** Before topic-based discovery is considered complete, the system MUST inventory retained local Git repositories and report missing remotes, missing topics, uncommitted changes, unpushed commits, and retirement candidates.
- **FR-035 — Guarded publication:** The system MUST support a reviewed Device A commit and push followed by a Device B guarded pull, while preserving dirty or divergent work for human resolution.
- **FR-036 — External-data concurrency:** Each mutable external-data adapter MUST use compare-and-swap, immutable generations plus a guarded current pointer, or an explicit single-writer lease. A desktop-sync folder MUST NOT be treated as a distributed lock: each computer can hold an independent replica before reconciliation. DVC publication MUST keep remote content immutable and additive, MUST NOT recursively delete remote bytes during rollback, and MUST use the guarded Git update of tracked `.dvc` metadata as the cross-computer compare-and-swap. A local claim MAY reduce races among processes that share one operating-system filesystem, but it MUST NOT claim cross-computer exclusivity.
- **FR-037 — Capsule provenance:** Capsule MUST record its canonical source remote, exact harness repository revision, and release identity. Verification MUST authenticate that Git revision, deterministically reconstruct the expected payload from that checkout plus approved configuration inputs whose digests are committed at the revision, and compare the security-relevant manifest fields, payload inventory, and payload hashes. Verification MUST reject a package whose payload, integrity hashes, and embedded provenance were jointly replaced.
- **FR-038 — Supported OS matrix:** The release MUST declare supported operating systems, product adapters, path conventions, executable discovery, and one receiving-computer verifier for every supported OS.
- **FR-039 — Manifest validation:** The repository MUST provide a versioned manifest schema and a concrete validator that rejects missing required fields, unsupported classes, unsafe destinations, and unresolved adapters.

### Entities and rules

#### Repository

A Git checkout with a canonical remote, project contract, current project state, verification instructions, and optional external-data manifest. GitHub carries its committed authority; local dirty changes remain owned by their working computer until committed and pushed.

#### Project state

Small text files such as `TASK.md`, `STATUS.md`, `LOG.md`, `MAP.md`, `DESIGN.md`, manifests, migrations, and safe configuration examples. These files travel with the repository and use normal Git conflict handling.

#### External asset

A required project input or state item whose content stays outside ordinary Git. Its manifest declaration names its authority, local placement, transport adapter, version rule, integrity rule, restore verifier, and regeneration behavior.

#### Adapter

A reviewed, project-declared operation that inspects, publishes, retrieves, restores, or verifies one external-asset class. Adapters have bounded paths and never infer an undeclared destination.

#### Capsule

The receiving-computer package for the shared cross-agent harness. It carries global bootstrap material and approved portable application configuration. Its integrity manifest intentionally contains one record for every packaged payload file. Its trust anchor is the authenticated canonical Git remote and exact revision recorded in the package; deterministic reconstruction may exclude declared nondeterministic envelope fields such as generation time, while every payload byte and security-relevant manifest field remains covered.

#### Live data service

A network-accessible authority for current application records. Depending on the application, it can be object storage with explicit concurrency controls or a transactional database provided directly or through a deployment platform integration.

#### Live document or object state

Mutable JSON documents or separately addressed objects served through network storage. Concurrent writers use conditional writes, immutable generations with a guarded pointer, or an explicit single-writer lease.

#### Backup

A recoverable copy outside the primary authority. A backup gains verified status only after integrity validation and a restore exercise into a safe target.

#### SQLite

An embedded relational database stored in a local file and accessed through a library inside the application process. It is suitable for local transactions and queries. Cross-device transport uses its backup API, `VACUUM INTO`, or an equivalent consistent export while the writable authority remains local.

#### Git LFS

A Git extension that replaces tracked large files with small pointer objects while a Git LFS service stores the bytes. Each file version remains tied to a Git commit.

#### DVC

A data-versioning layer that stores small hashes and metadata in Git and stores large content in a declared remote such as object storage or Google Drive. It adds verified pull/push behavior and can connect data versions and reproducible pipeline stages to code revisions.

#### Vercel storage

Vercel Blob is object storage and can hold private files or JSON, including conditional ETag writes. Transactional Postgres and other databases connected through Vercel are external Marketplace provider resources whose credentials Vercel injects into the deployment.

## Acceptance

### Scenarios

- **AC-001 / FR-001–FR-003, FR-034 — Recover repository inventory**
  - **Given** retained local projects, a fresh receiving projects directory, and authenticated GitHub CLI,
  - **When** local reconciliation and topic discovery run,
  - **Then** missing remotes, topics, commits, and retirement mappings are reported; missing published repositories are cloned; clean default branches are pulled; and dirty, ahead, diverged, colliding, unsafe, or wrong-origin paths remain unchanged.
  - **Verifier:** retained-local-repository audit, repository-sync integration suite, and live dry run.

- **AC-002 / FR-004 — Restore project control state**
  - **Given** a freshly cloned retained project,
  - **When** its project-state verifier runs,
  - **Then** required contracts, maps, task/status files, verification instructions, and declared manifests validate.
  - **Verifier:** `Test-AgentProjectState.ps1`.

- **AC-003 / FR-005–FR-006, FR-031, FR-037 — Build the global Capsule**
  - **Given** authenticated access to the canonical harness Git remote at the recorded revision and approved configuration inputs whose digests are committed at that revision,
  - **When** Capsule refresh, clean-stage deterministic reconstruction, and verification run,
  - **Then** the package contains the global payload, excludes project/runtime payloads, covers every file with an integrity record, records its canonical remote, exact revision, and release identity, matches the reconstructed payload inventory and hashes, and rejects changed or unsafe content. A fixture that jointly changes one payload file, its integrity hash, and its embedded provenance MUST fail against the authenticated revision.
  - **Verifier:** Capsule unit, portability, harness, Obsidian-configuration, clean-reconstruction, jointly-tampered payload/hash/provenance, and adversarial path suites.

- **AC-004 / FR-007–FR-012, FR-039 — Validate an external-data declaration**
  - **Given** a project with an external asset,
  - **When** `Test-DataManifest.ps1` validates its manifest against the versioned schema,
  - **Then** the asset has every required authority, supported class, adapter, version, integrity, restore, and regeneration field; its destination is safe; and its adapter resolves to an installed reviewed implementation.
  - **Verifier:** manifest schema, fixture, unsafe-destination, and adapter-resolution tests.

- **AC-005 / FR-011–FR-012 — Reject unsafe adapter targets**
  - **Given** aliases, reparse points, missing parents, path traversal, and roots outside the declared data directories,
  - **When** an adapter is invoked,
  - **Then** inspection reports the condition and mutation fails before data moves.
  - **Verifier:** per-adapter adversarial path suite.

- **AC-006 / FR-013–FR-016, FR-036 — Reconstruct and safely update large or local data**
  - **Given** a Git revision, its declared external-data version, and two clients holding different generations,
  - **When** retrieval and publication are exercised,
  - **Then** the declared version lands at the safe local path with matching integrity; a stale Git pointer update or dirty destination is rejected; and a failed or racing DVC publisher cannot delete either immutable remote generation, including bytes synchronized from another replica before rollback.
  - **Verifier:** disposable retrieve/verify exercise plus a same-host concurrent-publish fixture, a synchronized-competitor-object rollback fixture, and stale-pointer/destination fixtures.

- **AC-007 / FR-017–FR-019 — Recover a live service**
  - **Given** a live relational service, document store, or object authority and all associated storage,
  - **When** scheduled exports run and the latest set is restored into a disposable target,
  - **Then** structural contracts, stable IDs, record values, integrity checks, and required object bytes match the export manifest.
  - **Verifier:** project-specific restore drill.

- **AC-008 / FR-020–FR-023, FR-038 — Reconstruct a receiving computer**
  - **Given** a supported clean Windows profile,
  - **When** the receiving flow executes,
  - **Then** the harness installs, approved configuration restores, project-data roots are established, required executables resolve, existing logins are reused when visible, repositories are discovered, declared adapters run against fixtures, and project verifiers pass.
  - **Verifier:** Windows alternate-profile bootstrap, data-root, adapter fixture, and fresh normal-user executable checks.

- **AC-009 / FR-024 — Broker one credential**
  - **Given** an allowlisted project, secret, executable, and argument tuple,
  - **When** the broker launches the child process,
  - **Then** the credential exists only in the child environment, output is redacted, and the broker fails closed for every unlisted tuple.
  - **Verifier:** broker, token-store, redaction, and isolation tests.

- **AC-010 / FR-025–FR-026 — Prove consolidated hooks**
  - **Given** Claude, Codex, and Cursor hook configuration,
  - **When** the hook contract suite inspects every wired command,
  - **Then** every supported event routes through the bounded dispatcher set declared in the implementation map, behavioral parity fixtures pass, and no support module is independently wired.
  - **Verifier:** task-hook `Run-All.ps1`, cross-product behavior fixtures, and installed-state hook audit. The current implementation map declares three dispatchers.

- **AC-011 / FR-027–FR-030 — Select and prove Docket authority**
  - **Given** `SPEC.md` from `https://github.com/douglaspmcgowan/docket.git` at migration-baseline commit `f3688602c02a7f0c96b70427f7d78d68cf43f4e1` plus representative records for every supported feature,
  - **When** the selected authority runs the complete Docket acceptance matrix plus concurrent-write, phone, export, and restore tests,
  - **Then** every normative feature works, no update is silently lost, and a semantically complete disposable restore passes.
  - **Verifier:** Docket's full spec-linked unit/browser suite, concurrent-write test, deployed phone smoke test, and restore drill.

- **AC-012 / FR-032–FR-033 — Verify human documentation**
  - **Given** the final implementation and current vendor documentation,
  - **When** the Markdown guide and HTML mirror are generated and checked,
  - **Then** their architecture and decisions match, links resolve, and each recommendation maps to a requirement and cited evidence.
  - **Verifier:** source-hash parity, link checker, HTML render, and recon traceability audit.

- **AC-013 / FR-034–FR-035 — Propagate project state between devices**
  - **Given** a retained project changed on Device A and a clean clone on Device B,
  - **When** Device A's reviewed changes are committed and pushed and Device B runs guarded synchronization,
  - **Then** Device B receives the same commit and project-state files while uncommitted, unpushed, ahead, or divergent states are surfaced without overwrite.
  - **Verifier:** disposable Device A → GitHub fixture remote → Device B integration test.

- **AC-014 / NFR-001–NFR-005, NFR-007 — Exercise system qualities**
  - **Given** unchanged authorities, a receiving profile rooted differently from the source computer, unsafe aliases, injected failures, and Claude/Codex/Cursor fixtures,
  - **When** bootstrap, repository discovery, data retrieval, and hook dispatch run twice,
  - **Then** repeat runs preserve effective state; generated scripts, manifests, and resolved destinations contain no source-computer drive letter or profile-specific absolute path; unsafe operations fail before mutation; file and database integrity checks remain complete; every sync diagnostic reports the inspected authority, action, result, verifier, and any actionable exception without credential values; and supported agent products receive equivalent contract behavior.
  - **Verifier:** assembled idempotence, path-safety, fault-injection, redaction, and cross-agent parity suite.

- **AC-015 / NFR-006 — Measure performance**
  - **Given** representative Capsule, hook, repository, and project-data fixtures,
  - **When** their declared benchmarks run,
  - **Then** observed sizes, transfer times, and hook latency are recorded and any approved threshold failure blocks release.
  - **Verifier:** versioned benchmark report; thresholds remain an open decision until measured.

- **AC-016 / FR-033 — Audit recon evidence**
  - **Given** every recommendation in the traceability table,
  - **When** the evidence audit runs,
  - **Then** each row carries dated primary-source and practitioner-source IDs that directly support its material claims, or explicitly identifies an unavailable evidence category, the resulting limitation, and its effect on confidence.
  - **Verifier:** recon source-ID coverage check plus sampled link retrieval.

### Requirement coverage

| Requirements | Acceptance |
|---|---|
| FR-001, FR-002, FR-003, FR-034 | AC-001 |
| FR-004 | AC-002 |
| FR-005, FR-006, FR-031, FR-037 | AC-003 |
| FR-007, FR-008, FR-009, FR-010, FR-011, FR-012, FR-039 | AC-004, AC-005 |
| FR-013, FR-014, FR-015, FR-016, FR-036 | AC-006 |
| FR-017, FR-018, FR-019 | AC-007 |
| FR-020, FR-021, FR-022, FR-023, FR-038 | AC-008 |
| FR-024 | AC-009 |
| FR-025, FR-026 | AC-010 |
| FR-027, FR-028, FR-029, FR-030 | AC-011 |
| FR-032, FR-033 | AC-012, AC-016 |
| FR-034, FR-035 | AC-013 |
| NFR-001, NFR-002, NFR-003, NFR-004, NFR-005, NFR-007 | AC-014 |
| NFR-006 | AC-015 |

### Non-functional requirements

- **NFR-001 — Portability:** Scripts and manifests MUST use environment roots, repository-relative paths, or receiving-profile paths instead of source-computer drive letters.
- **NFR-002 — Safety:** Mutating operations MUST be bounded, reversible when practical, and fail before following an unsafe alias or undeclared path.
- **NFR-003 — Integrity:** File transports MUST use SHA-256 or a provider-native equivalent; database transports MUST also run a database-native integrity or restore check.
- **NFR-004 — Observability:** Every sync reports inspected authority, action, result, verifier, and actionable exception without credential values.
- **NFR-005 — Idempotence:** Repeating bootstrap, repository discovery, and retrieve operations against unchanged authorities MUST preserve the same effective state.
- **NFR-006 — Performance:** Concrete project-data size, transfer-time, and hook-latency thresholds remain unresolved until representative measurements are recorded.
- **NFR-007 — Cross-agent parity:** Claude, Codex, and Cursor MUST load the same portable project contract and equivalent shared hook behaviors where their product surfaces permit.

### Open decisions

- None. Each selected default remains reversible through the same acceptance criteria.

### Resolved decisions

- **RD-001 — Docket publication boundary:** All valid personal Docket cards may use the authenticated cloud authority. Credential values remain protected and outside card content.
- **RD-002 — Large-versioned-data default:** DVC metadata travels in the project Git repository. Content-addressed bytes travel through Google Drive Desktop under `%PROJECT_DATA_SYNC_ROOT%\<project>\dvc\<asset-id>`. Each computer writes its own untracked `.dvc\config.local`, which keeps source-machine paths out of Git and reuses the existing Drive Desktop login. Remote DVC objects are immutable and additive: rollback restores local staging and configuration while leaving every remote byte in place, including unreferenced partial uploads and objects arriving from another Drive replica. The adapter refreshes the tracked Git remote before publication and rejects an advanced upstream; the guarded Git push is the final cross-computer compare-and-swap for the committed `.dvc` pointer. A temporary local lock only coordinates first publishers sharing one Windows filesystem and provides no cross-computer ownership guarantee.
- **RD-003 — Snapshot retention default:** Snapshot-style recovery exports keep 3 daily, 4 weekly, and 3 monthly verified points unless the project declares an override. DVC content referenced by retained Git branches or tags is excluded from time-bucket pruning; automatic `dvc gc` remains disabled.
- **RD-004 — Docket authority:** Harden the deployed private Vercel Blob document store with schema validation, ETag conditional writes, complete checksummed export, and verified restore. This preserves the current phone/browser deployment with the smallest migration. A future provider-database migration must pass the same feature, concurrency, phone, export, and restore criteria.

## Recon traceability

| Problem lane | Requirements | Recon finding | Current recommendation | Evidence |
|---|---|---|---|---|
| Repository code, project status, and configuration | FR-001–FR-004, FR-034–FR-035 | Git and GitHub provide revision history, merge behavior, remotes, and topic-based discovery. Desktop file sync around `.git` creates avoidable partial-state and conflict risk. | Keep project control state in each GitHub repository. Use guarded commit/push and clone/pull. | P14, P15, P16, H2 |
| Shared machine and agent harness | FR-005–FR-006, FR-021–FR-026, FR-031–FR-038 | A small verified bootstrap package can reconstruct global rules and tools. Project payloads made the earlier Capsule large and coupled updates to nightly snapshots. | Keep Capsule global-only. The current Windows design uses three externally wired dispatchers and retains their support modules and tests. | P13, H3, L1 |
| Modest low-churn binaries tied to commits | FR-014 | Git LFS preserves normal Git pointers and GitHub hosting convenience. Each changed binary version consumes separate LFS storage and downloads use bandwidth quota. | Use selectively with an explicit repository budget. | P2; practitioner-specific evidence remains limited |
| Large data tied to exact code versions | FR-009–FR-013 | DVC keeps hashes and metadata in Git while content lives in Drive or object storage. A mounted Drive remote reuses Google Drive Desktop authentication and requires DVC on each computer. | Use DVC metadata in Git with content under `%PROJECT_DATA_SYNC_ROOT%\<project>\dvc\<asset-id>`. The adapter rejects stale publication and dirty retrieval, and reports SHA-256 evidence. | P3, P4, H1 |
| Human documents, media, and immutable exports | FR-015 | Practitioners commonly separate code in Git from large human files in Drive or another file sync service. Drive handles arbitrary files and human browsing; active databases and worktrees create unsafe churn. | Use plain Drive folders for human assets and immutable, checksummed exports. | H2; provider-specific primary evidence remains limited |
| Local transactional application state | FR-016 | SQLite provides transactions and queries in one local file. Database-native snapshot operations create consistent copies; desktop sync of a live file can capture intermediate state. | Keep writable SQLite local. Export consistent snapshots only when a project genuinely needs local authority or offline recovery. | P11, P12, H5 |
| Live phone and multi-device state | FR-017–FR-019, FR-027–FR-030, FR-036 | Vercel Blob already holds Docket's four private JSON aggregates and supports ETag conditional writes. Vercel's relational choices are Marketplace databases such as Supabase or Neon. A database adds row transactions, queries, constraints, and mature schema tools. | Compare hardened Blob with one database-backed implementation fixture. For a single-user Docket, hardened Blob is the lowest-migration candidate; a database gains value with concurrent writers, relational queries, Auth/RLS, or record growth. | P5, P6, P7, L2; practitioner-specific Vercel evidence remains limited |
| Supabase recovery | FR-018–FR-019 | Supabase versioned migrations fit Git. Its database backups omit Storage object bytes, and the Free plan needs user-managed logical exports. | Treat Supabase as a live authority and export database plus Storage separately to an off-site destination with restore drills. | P8, P9, P10, H4 |
| Reproducible generated output | FR-020 | Dependencies, caches, and deterministic builds can be recreated from committed inputs and commands. Shipping them increases size and platform coupling. | Regenerate them during bootstrap and verify the result. | L3; external practitioner evidence remains limited |

### Source basis

Sources were retrieved or rechecked on **2026-07-29**.

Primary documentation:

- **P1:** [GitHub repository limits](https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits)
- **P2:** [GitHub Git LFS billing](https://docs.github.com/en/billing/concepts/product-billing/git-lfs)
- **P3:** [DVC remote data workflow](https://dvc.org/doc/command-reference/get)
- **P4:** [DVC with Google Drive](https://dvc.org/doc/user-guide/data-management/remote-storage/google-drive)
- **P5:** [Vercel storage overview](https://vercel.com/docs/storage)
- **P6:** [Vercel Blob and conditional writes](https://vercel.com/docs/vercel-blob)
- **P7:** [Vercel Marketplace storage](https://vercel.com/docs/marketplace-storage)
- **P8:** [Supabase local migration workflow](https://supabase.com/docs/guides/local-development/cli-workflows)
- **P9:** [Supabase database backups](https://supabase.com/docs/guides/platform/backups)
- **P10:** [Supabase Storage S3 compatibility](https://supabase.com/docs/guides/storage/s3/compatibility)
- **P11:** [SQLite backup API](https://www.sqlite.org/backup.html)
- **P12:** [SQLite network filesystem guidance](https://www.sqlite.org/useovernet.html)
- **P13:** [chezmoi multi-machine configuration model](https://www.chezmoi.io/user-guide/setup/)
- **P14:** [GitHub repository topics and topic-based discovery](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics)
- **P15:** [GitHub clone, fetch, and pull behavior](https://docs.github.com/en/get-started/using-git/getting-changes-from-a-remote-repository)
- **P16:** [GitHub push behavior and non-fast-forward protection](https://docs.github.com/en/get-started/using-git/pushing-commits-to-a-remote-repository)

Practitioner evidence:

- **H1:** [Hacker News discussion of DVC's Git-metadata and external-content split](https://news.ycombinator.com/item?id=19129408)
- **H2:** [Practitioner discussion of Git projects plus separate large-file sync](https://www.reddit.com/r/AskProgramming/comments/1cux4ve/how_do_you_deal_with_multiple_computers/)
- **H3:** [Practitioner discussion of cross-platform configuration management](https://news.ycombinator.com/item?id=34296396)
- **H4:** [Practitioner Supabase backup and restore discussion](https://www.reddit.com/r/Supabase/comments/1un85ho/how_do_you_actually_back_up_your_supabase_project/)
- **H5:** [Simon Willison on continuous SQLite backup](https://simonwillison.net/2025/Oct/3/litestream/)

Local evidence:

- **L1:** current three-dispatcher wiring, Capsule package tests, and installed-state verifier in this repository.
- **L2:** Docket `api\_store.js`, deployed Vercel inspection, and the current 84-test passing baseline.
- **L3:** current project manifests, ignored dependency/cache boundaries, and receiving-computer regeneration tests.
