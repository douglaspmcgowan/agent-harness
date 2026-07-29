# Skills, adapters, audits, and durable corrections

Last consolidated: 2026-07-29

This guide consolidates the former skill-audit and feedback-routing briefs. Their dated source text remains under [`archive/audits`](archive/audits/) and [`archive/topics`](archive/topics/).

## Cloud export update

`C:\Users\dougl\.agents\tools\Sync-ProjectSkills.cmd` now vendors only manifest-selected shared skills into a repository. A binding is selected with `"cloudRequired": true` or `"delivery": "vendored"`. Generated copies receive a projection marker and hash; an existing project-owned skill without that marker is protected from replacement.

Commit `.agents\skills` and `skill-projection-manifest.json` before starting a cloud agent. The cloud session receives those selected skills through Git.

## What a product adapter is

A product adapter is a thin loader or translation layer around one canonical skill. It maps invocation, tool names, paths, hooks, permission results, and product-owned features. It does not contain a separate copy of the full procedure.

Full copies drift. The current corpus demonstrates that risk: 107 migrated Claude command wrappers preserve Claude vocabulary and shell assumptions, and twelve capability names have duplicate shared definitions.

## Naming convention

Use qualified identities in manifests, audits, and Docket records. Keep product-required filesystem names where the surface requires them.

| Form | Qualified identity | Normal home |
|---|---|
| Canonical skill | `skill:<name>` | `.agents\skills\<name>` |
| Existing command alias | `alias:<legacy>:<name>` | discoverable legacy folder |
| Product adapter | `adapter:<surface>:<name>` | product projection, metadata, rule, or launcher |
| Project binding | `binding:<project>:<name>` | `skills-manifest.json` |
| Provider adapter | `provider:<provider>:<name>` | `references\providers\<provider>.md` |
| Model-family adapter | `model:<family>:<name>` | `references\models\<family>.md` when verified |

The canonical folder and its frontmatter `name` match.

## Command spelling aliases

Common spoken or typed variants use thin discoverable alias packages. The alias keeps only trigger metadata and a pointer to the canonical procedure, so both spellings appear in skill catalogs without creating two implementations.

`source-command-tactitian` is the compatibility spelling for `source-command-tactician`. Both live in `C:\Users\dougl\.agents\skills`; the alias loads the canonical skill body.

Claude Code currently discovers personal skills under `~\.claude\skills` and project skills under `.claude\skills`. This harness treats the personal folder as a generated projection of selected canonical packages. Codex and Cursor can discover the shared `.agents\skills` home. The projection manifest records source hashes and prevents a product copy from becoming a competing authority.

## How project skills are selected

A project gets a binding when repository evidence shows a recurring, fragile, resource-dependent, or cloud-required workflow.

Evidence includes:

- package and framework files;
- deployment targets;
- project-owned schemas or assets;
- repeated task history;
- a specialized verifier;
- a safety-critical operation;
- cloud agents needing the workflow from the repository.

General personal workflows stay in the global catalog. Project-specific portable skills are committed under `.agents\skills`. `skills-manifest.json` records the reason, source, dependencies, required surfaces, and cloud requirement.

## Provider and model adapters

Provider adapters handle real API and lifecycle differences: Bitwarden versus GitHub Actions secrets, Vercel versus local deployment, or GitHub versus another review system.

Model-family adapters are rare. They require a verified difference in tools, structured output, context constraints, or execution environment. Ordinary quality preferences belong in product configuration or delegation policy.

## Skill writing discipline

- Put triggering conditions in the description.
- Keep the main procedure concise and under 500 lines.
- Use one-level references for variants and detailed source material.
- Use scripts for deterministic repeated work.
- State inputs, output contract, write scope, stop conditions, and verification.
- Identify adjacent skills and route cleanly.
- Avoid shell-specific examples unless the skill selects the shell.
- Avoid hardcoded machine paths in portable skills.
- Require backups before replacement and prohibit silent overwrite.
- Test realistic low-risk cases and validate the skill directory.

Agent Skills use progressive disclosure: metadata is visible for discovery, the `SKILL.md` body loads after activation, and references or scripts are accessed only when needed. [Agent Skills specification](https://agentskills.io/client-implementation/adding-skills-support), [Anthropic Agent Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview), [Cursor agent practices](https://cursor.com/blog/agent-best-practices), [OpenAI Codex app](https://openai.com/index/introducing-the-codex-app/).

## Docket review

The audit writes one evidence record per skill. The Docket build step creates one review card per skill, grouped by portability status and severity. Douglas can approve remediation, keep the current design, defer it, or request deeper review.

The audit record remains authoritative. Docket stores review state.

## Baseline feedback skill

`feedback` is cloud-required in the repository template because durable correction routing applies to every project. It is vendored under `.agents\skills\feedback`. Other skills remain selected through recurring workflow, fragile verification, project-owned resources, or demonstrated cloud need.

## Installed projection mechanism

`C:\Users\dougl\.agents\skills` is the canonical skill authority. `C:\Users\dougl\.claude\skills` is the Claude product projection.

`Sync-ClaudeSkills.ps1` selects canonical skills, refreshes directories carrying a projection marker, preserves unmanaged Claude-owned directories, and reports an unreviewed collision. `Approve-ClaudeSkillAdapter.ps1` records intentional Claude deltas by exact source and target hashes. A later hash change reopens review.

Dated projection result preserved from the 2026-07-26/27 audit:

- 50 canonical non-command skills selected;
- 27 current product copies;
- 23 reviewed Claude adapters;
- zero conflicts;
- 157 semantically audited skills represented in the Skills Docket.

Canonical names use the workflow name, such as `feedback`. Product copies retain that name under the product root. Intentional variants are classified in metadata as `adapter:claude`, `adapter:codex`, or `adapter:cursor`. Provider/model modules use `provider:<provider>` or `model:<model-family>`. Repository-selected copies are project bindings governed by `skills-manifest.json`.

## Durable correction routing

A correction is classified along two axes:

1. **Scope:** project/path, shared cross-project, product-specific, provider-specific, or human-only.
2. **Mechanism:** contract rule, skill, memory reference, verifier, hook, permission, setup brief, or backlog record.

Use the narrowest proven scope. Stable cross-project behavior belongs in the shared contract or a canonical skill. Project facts stay in repository state or scoped instructions. Product mechanics stay in adapters. Machine-detectable failures receive a deterministic test, hook, permission, or verifier. Human rationale and pending decisions stay in briefs or backlog state.

Every correction record remains value-free and identifies the evidence, scope, mechanism, status, and superseding record when one exists. A recurring-error remedy reaches future sessions through a durable artifact.

## Skill audit lifecycle

The skill audit records evidence per skill: trigger quality, portability, dependencies, safety boundaries, verification, cloud delivery, and known product adapters. Docket stores review state while the audit artifact remains the technical evidence.

Audit conclusions that change a skill update the canonical package, its tests, projection metadata, and any project binding. Dated portfolio totals and one-time findings belong in the archived audit at [`archive/audits/13-SKILL-AUDIT-RESULTS.md`](archive/audits/13-SKILL-AUDIT-RESULTS.md).

## Declog skill

`declog` is the Windows memory-pressure and stale-process audit skill. It gives Douglas a decision-ready report before any termination.

Its conceptual workflow is:

1. measure physical memory, commit, cache, compression, and kernel pools;
2. group processes by executable and parent/child tree;
3. inspect detached or aged Node, Python, Playwright Chromium/Chrome, WebView2, browser-helper, and agent CLI trees;
4. protect active ChatGPT, Codex, Claude, Cursor, browser, test-runner, and command-runner ownership;
5. identify lagging candidates with age, ancestry, command provenance, resident memory, committed memory, and confidence;
6. surface exact candidates and expected recovery to Douglas;
7. terminate only the approved, revalidated trees;
8. remeasure memory and record a value-free result.

The skill treats process name and memory size as insufficient evidence. Active desktop-agent renderer children stay protected. Playwright browser processes require evidence that their owning test runner and automation session have exited. Python and Node processes require ancestry, start-time, listening-port, open-job, and executable-path checks appropriate to the available tools.

The scheduled stale-agent cleanup remains a narrow guard for the already reproduced orphaned Node helper pattern. `declog` supplies the broader interactive audit for unfamiliar memory pressure and leaves uncertain candidates for Douglas to decide.

The 2026-07-29 live audit reproduced a separate latency interaction: an active Agent Backups verification run plus Google Drive synchronization drove physical-memory use to 97%, high CPU, and heavy file-system activity. Stopping the verification run improved the baseline; stopping Google Drive produced the largest measured reduction. `declog` reports whole-application pressure alongside stale candidates and preserves busy, actively owned applications.

## Archived sources

- [`archive/topics/17-FEEDBACK-ROUTING-AND-CORRECTIONS.md`](archive/topics/17-FEEDBACK-ROUTING-AND-CORRECTIONS.md) preserves the full dated routing rubric.
- [`archive/audits/13-SKILL-AUDIT-RESULTS.md`](archive/audits/13-SKILL-AUDIT-RESULTS.md) preserves the dated portfolio audit.
