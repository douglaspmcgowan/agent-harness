---
name: client
description: Initialize, adopt, or refresh a client project repository from business context, messages, files, links, and supplied assets.
---

# Client

Turn uneven client material into a sourced operating record: a client profile, a delivery ledger, an asset/source inventory, and a repository that follows the local project harness.

Read [references/artifact-contract.md](references/artifact-contract.md) before creating or changing client artifacts. Run [scripts/Test-ClientProject.ps1](scripts/Test-ClientProject.ps1) before reporting completion.

## Boundaries and routing

- Use `client` for repository intake, profile creation, source capture, delivery governance, and later profile refreshes.
- Use a discovery or brainstorming skill when the engagement goal remains unresolved and Douglas asks to explore it.
- Use a proposal or statement-of-work workflow for pricing, contract language, signatures, or legal terms.
- Use project-specific build, design, debugging, and deployment skills after a deliverable becomes active.
- Treat live website, account, messaging, payment, and production changes as separate delivery actions with their own authorization and verification.

## Required outputs

Create or refresh these repository-root files:

1. `CLIENT.md` — sourced client profile and open-question register.
2. `DELIVERABLES.md` — requested work, commitments, status, dependencies, acceptance evidence, and next actions.
3. `SOURCES.md` — source and asset provenance ledger.

Adopt the normal project harness when available: `AGENTS.md`, `CURRENT-TASK.md`, `WORK_QUEUE.md`, `STATUS.md`, `LOG.md`, `BACKBURNER.md`, `MAP.md`, `DESIGN.md`, `VERIFY.md`, data and secret manifests, and product adapters.

## Step 0 — Resolve mode and authority

Classify the request before writing:

| Mode | Signal | Allowed action |
|---|---|---|
| Plan | Douglas asks for a plan, outline, or sketch | Return a written plan only. |
| Initialize | New client or empty folder | Create the governed repository and required outputs. |
| Adopt | Existing client project lacks the profile or ledger | Add missing artifacts while preserving current contracts. |
| Refresh | New client facts, files, decisions, or requests arrive | Update sources first, then affected profile and delivery entries. |
| Execute | A live deliverable is explicitly assigned | Hand off to the matching implementation skill after intake is current. |

Resolve the stable repository path. For an existing repository, read its instructions and task state first. For a local greenfield repository, prefer the shared `New-AgentRepository` bootstrap when available. For an existing unbootstrapped repository, prefer the additive `Ensure-AgentProject` bootstrap.

Stop when the target repository is ambiguous, when a destructive choice is unresolved, or when contract/legal meaning would have to be invented.

## Step 1 — Inventory sources before claims

Inventory every supplied message, attachment, link, current website, repository file, and named system without exposing secret values.

Assign stable source IDs:

- `MSG-###` for client or Douglas messages
- `FILE-###` for supplied files
- `WEB-###` for verified public pages
- `DEC-###` for explicit decisions
- `OBS-###` for agent observations

Record each item in `SOURCES.md` with location, date received or checked, sensitivity, and the claims it supports. Preserve filenames exactly. Copy client-provided source assets into the project’s declared data root when permitted; otherwise record their current absolute paths and the copy blocker.

Apply the evidence labels exactly:

- `Confirmed` — directly stated by the client/Douglas or verified in an authoritative source.
- `Observed` — directly visible in a file, system, or live page.
- `Inferred` — reasoned from evidence and clearly marked for confirmation.
- `Open` — unknown, contradictory, or awaiting a decision.

Never promote an inference into a confirmed fact. Never treat a request as a commercial commitment.

## Step 2 — Build the client profile

Create `CLIENT.md` from the artifact contract. Capture only supported information:

- identity, locations, contact channels, ownership descriptors, and business model
- customers, users, buyers, and communities served
- products, services, differentiators, and desired outcomes
- stakeholders, decision authority, approvers, and communication preferences
- current digital estate, platforms, domains, integrations, and known failure points
- brand assets, voice, visual patterns, and accessibility or compliance constraints
- operational, technical, regulatory, data, privacy, and security constraints
- for AI work: intended use, affected people, data classes, human oversight, failure cost, evaluation evidence, monitoring, and shutdown/rollback authority
- contradictions, assumptions, and open questions

Attach source IDs to factual bullets. Use explicit `Unknown` values where a required field lacks evidence.

## Step 3 — Build the delivery ledger

Create `DELIVERABLES.md` from the artifact contract. Give every item a stable `DEL-###` ID and one state:

`Requested`, `Proposed`, `Approved`, `Active`, `Blocked`, `In review`, `Verified`, `Delivered`, `Deferred`, or `Cancelled`.

Each entry must include:

- desired business or user outcome
- exact artifact, service, or change
- source and request date
- scope status and owner
- dependencies and client inputs
- acceptance evidence
- risk and rollback/recovery note when the work changes a live system
- current state and next action

Place urgent client-facing requests first. Separate immediate continuity work from replacement or transformation work. Add a change record whenever an approved item’s scope, acceptance evidence, or dependencies change.

## Step 4 — Establish project boundaries

Update the repository contract and maps with confirmed project-specific facts:

- one-sentence purpose and stable paths
- setup, test, lint, build, and end-to-end verification commands that actually exist
- data placement and asset inventory
- value-free credential and access requirements
- external systems and live-change boundaries
- relevant project skill binding

Keep passwords, API keys, tokens, session material, and recovery codes outside Git. Record only credential names, purpose, provider, owner, and required access level in the secret manifest. Treat client account identifiers and personal contact details according to the project’s data sensitivity decision.

## Step 5 — Seed active work

For multi-step work:

1. Seed `WORK_QUEUE.md` from active deliverables.
2. Set `CURRENT-TASK.md` to the current approved goal and exact next verifier.
3. Put durable project state in `STATUS.md`.
4. Append completed work to `LOG.md`.
5. Put later ideas in `BACKBURNER.md`.

Queue checkboxes reflect evidence: `[ ]` todo, `[~]` active, `[x]` verified, `[!]` blocked, `[?]` awaiting Douglas.

## Step 6 — Validate and adversarially review

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<skill>\scripts\Test-ClientProject.ps1" -Repository "<repo>"
```

Then challenge the result:

1. Trace every confirmed profile claim to `SOURCES.md`.
2. Check that every client request appears once in `DELIVERABLES.md`.
3. Check that each active/verified/delivered item has acceptance evidence.
4. Search tracked files for credential values and unreviewed personal data.
5. Check that repository commands exist and that reported verifiers were actually run.
6. Check that live actions were neither implied nor performed during intake without explicit authority.

Report the exact checks that passed, concrete gaps, and current limitations.

## Safety constraints

- Preserve source material and authored files. Write new versions when replacement is required.
- Keep secret values out of files, logs, prompts, and tool output.
- Keep legal terms, fees, deadlines, and contractual scope marked `Open` until an authoritative source confirms them.
- Keep inferred facts visibly labeled.
- Keep live external mutations behind a separate explicit execution request.
- Keep changes scoped to client setup and the requested active deliverables.
- Avoid commits and pushes unless Douglas separately requests them.

## Forward-test workflow

When a Workflow-style `agent()` runner exists, use this script to test the artifact set with independent roles. Otherwise perform the same three phases serially and disclose the limitation.

```js
export const meta = {
  name: "client-forward-test",
  description: "Trace client facts and delivery commitments, then challenge readiness",
  phases: [
    { title: "Trace" },
    { title: "Delivery" },
    { title: "Adversarial Review" },
  ],
}

const ARTIFACT_SCHEMA = {
  type: "object",
  properties: {
    pass: { type: "boolean" },
    findings: {
      type: "array",
      items: {
        type: "object",
        properties: {
          severity: { type: "string", enum: ["high", "medium", "low"] },
          file: { type: "string" },
          description: { type: "string" },
          evidence: { type: "string" },
        },
        required: ["severity", "file", "description", "evidence"],
      },
    },
  },
  required: ["pass", "findings"],
}

const repository = args.repository
const trace = await agent(
  `In ${repository}, trace every Confirmed or Observed claim in CLIENT.md to a real SOURCES.md entry. ` +
  `Flag unsupported claims, contradictions, sensitive values, and missing source locations. Read-only.`,
  { phase: "Trace", schema: ARTIFACT_SCHEMA, label: "source-trace" },
)
const delivery = await agent(
  `In ${repository}, compare the supplied intake sources with DELIVERABLES.md. Flag omitted requests, ` +
  `duplicate items, commitments inferred from requests, missing acceptance evidence, and hidden dependencies. Read-only.`,
  { phase: "Delivery", schema: ARTIFACT_SCHEMA, label: "delivery-audit" },
)
const adversarial = await agent(
  `In ${repository}, independently challenge CLIENT.md, DELIVERABLES.md, SOURCES.md, AGENTS.md, task state, ` +
  `data boundaries, and secret manifests. Reproduce each finding from files. Read-only.`,
  { phase: "Adversarial Review", schema: ARTIFACT_SCHEMA, label: "adversarial" },
)

return {
  repository,
  pass: trace.pass && delivery.pass && adversarial.pass,
  trace,
  delivery,
  adversarial,
}
```

## Final report

State:

- repository initialized or refreshed
- client and delivery artifacts created or updated
- source and asset handling
- live actions deliberately left pending
- verifier evidence
- known gaps and required client decisions
- full absolute paths of all files written

Use evidence-bounded language such as “verified in this pass” and “remains open.”
