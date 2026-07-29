# Repository bootstrap and cloud agents

Last verified: 2026-07-26

## Should repositories be bootstrapped by default?

Yes. The shared harness now has two entry points:

```powershell
C:\Users\dougl\.agents\tools\New-AgentRepository.cmd -Repository C:\Users\dougl\projects\my-project
```

creates a new Git repository and bootstraps it. For a clone or existing repository:

```powershell
C:\Users\dougl\.agents\tools\Ensure-AgentProject.cmd -Repository C:\path\to\repo
```

performs an idempotent adoption pass. It adds missing baseline files, creates the project data root, enables Gitleaks, generates the value-free secret manifest, and preserves existing project contracts and files.

The Claude, Codex, and Cursor global adapters require this first-open adoption check. Git’s global template still supplies Gitleaks to newly initialized and cloned repositories; the project adoption pass supplies the richer project-specific baseline.

The 2026-07-26 inventory found fourteen top-level Git repositories across the current workspace and `C:\Users\dougl\projects`. Two contain the complete current baseline, three contain partial Claude/Codex contracts, and nine still need adoption. Opening the exact repository remains the first step; run the state verifier when readiness is uncertain.

## Portable base rules

The repository `AGENTS.md` template now carries the machine-independent subset of Douglas’s global rules:

- address Douglas correctly and answer direct questions first;
- source and verify claims;
- preserve unrelated changes;
- keep plan requests plan-only;
- keep credential values out of output and Git;
- use matching project skills;
- verify and adversarially test before completion;
- update task, status, map, design, verification, and memory files on explicit lifecycle triggers;
- preserve Douglas’s prose preference against the rhetorical antithesis construction.

Machine paths, vault locations, personal product permissions, hook wiring, session stores, and device-specific settings remain in local global files.

## Why `CURRENT-TASK.md` and `WORK_QUEUE.md` both exist

`CURRENT-TASK.md` carries the explanation a new session needs: the goal, completed steps with evidence, remaining steps in order, and exact next verifier.

`WORK_QUEUE.md` carries concise action state:

```text
- [ ] pending
- [~] in progress
- [x] verified complete
- [!] blocked
- [?] Douglas’s decision required
```

Hooks and continuation loops can parse checkboxes reliably. A narrative task file supports accurate resumption. Queue items should link to the task narrative when detail would duplicate it.

## Automatic update model

The harness has three layers:

1. Bootstrap creates every required file and the core-document map.
2. Always-loaded project rules define exactly when each file changes.
3. `Test-AgentProjectState.cmd` detects missing files, unresolved identity placeholders, incomplete map structure, and unfinished verification commands.

Agents supply semantic content because architecture and status require project judgment. The verifier supplies deterministic coverage for structure and unresolved scaffolding.

## Preparing a cloud agent

1. Run the adoption check locally.
2. Fill in project identity, commands, data classifications, verification, map, and design placeholders.
3. Select only the shared skills the cloud task needs in `skills-manifest.json`.
4. Mark a binding with `"cloudRequired": true` or `"delivery": "vendored"`.
5. Run:

```powershell
C:\Users\dougl\.agents\tools\Sync-ProjectSkills.cmd -Repository C:\path\to\repo
```

6. Review `.agents\skills` and `skill-projection-manifest.json`.
7. Run tests, Gitleaks, and `Test-AgentProjectState.cmd`.
8. Commit and push the repository branch.
9. Start the cloud agent from that repository and branch.
10. Provision named secrets and data through the cloud product’s environment controls. Keep values out of repository files.

The sync tool copies only manifest-selected canonical skills. Generated copies carry source hashes and projection markers. A project-owned skill without a projection marker is protected from replacement.

## Skill selection

A skill belongs in a project when repository evidence shows one of these:

- a recurring project workflow;
- a fragile or specialized verifier;
- project-owned tools or schemas;
- a cloud session that needs the procedure without access to the personal machine.

General preferences remain in `AGENTS.md`. Product adapters stay thin. A provider/model adapter is added only after a verified behavioral difference requires one.

Corrections use brief 17's scope/mechanism router. A cloud-relevant correction must also reach the committed repository contract, verifier, scoped rule, or vendored skill.

## Cloud limitation

A cloud agent receives committed files and configured environment setup. It cannot rely on `C:\Users\dougl\.agents`, local SQLite databases, ignored data, local environment variables, or desktop session history. The committed contract, selected skills, fixtures, manifests, migrations, and setup commands therefore form the cloud context pack.

## Managed portable judgment baseline

`C:\Users\dougl\.agents\PORTABLE-PRINCIPLES.md` owns the versioned block projected into every repository `AGENTS.md`. It carries Douglas’s portable communication, evidence, reversible-safety, engineering-judgment, completion, and durable-feedback rules. `Sync-PortableContract.ps1` replaces only the marked block, preserves repository-specific instructions, and stores a recovery copy before changes.

The strict repository verifier requires the current block and `.agents\feedback\FEEDBACK-LOG.md`. All 21 inventoried repositories adopted and passed this baseline on 2026-07-26.
