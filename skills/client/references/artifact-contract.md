# Client artifact contract

Use this contract when creating or refreshing `CLIENT.md`, `DELIVERABLES.md`, and `SOURCES.md`.

## Why these artifacts exist

The structure combines mechanisms from established practices:

- Thoughtbot’s kickoff asks who the work serves, what is known, what remains unknown, why the work matters now, where findings live, who owns which role, and which deliverables are expected: https://thoughtbot.com/playbook/strategy/customer-discovery/kickoff
- 18F’s product guide covers users, stakeholder priorities, technical landscape, and regulatory obligations; its stakeholder guidance captures influence, decision authority, goals, and communication needs: https://guides.18f.org/product/discover/ and https://guides.18f.org/product/discover/stakeholders/
- The GOV.UK discovery guide frames the problem, constraints, assumptions, value, and an evidence-based go/no-go decision before build work: https://www.gov.uk/service-manual/agile-delivery/how-the-discovery-phase-works
- Jonathan Stark’s consulting guidance starts with the client’s desired outcome and keeps risks and assumptions explicit: https://jonathanstark.com/daily/20160925-can-every-type-of-project-to-be-value-priced and https://jonathanstark.com/daily/20160812-how-to-write-proposals-that-close
- NIST AI RMF maps intended use, business context, risk tolerance, affected people, human oversight, evaluation, and monitoring for AI systems: https://airc.nist.gov/airmf-resources/airmf/5-sec-core/

The open-source Digital Marketing Pro `client-onboarding` skill informed the structured intake, stakeholder, access, communication, knowledge-transfer, and risk fields. Fixed questionnaire length and universal 30/60/90 milestones are intentionally omitted so small and urgent engagements stay proportional: https://github.com/indranilbanerjee/digital-marketing-pro/blob/main/skills/client-onboarding/SKILL.md

## `CLIENT.md`

```markdown
# Client profile

Last updated: YYYY-MM-DD
Profile status: Draft | Client-confirmed

## Identity

- Legal/trading name:
- Business type:
- Location(s):
- Ownership descriptors:
- Source(s):

## Business

### Products and services

### Customers, users, and buyers

### Desired outcomes

### Differentiators and proof

## Stakeholders and decisions

| Person or role | Organization | Interest | Influence | Decision authority | Communication | Source |
|---|---|---|---|---|---|---|

## Current digital estate

| System | Purpose | Owner | Current condition | Access required | Source |
|---|---|---|---|---|---|

## Brand

### Supplied assets

### Observed visual and verbal patterns

### Accessibility, licensing, and usage constraints

## Constraints and risks

### Operational

### Technical

### Data, privacy, security, and compliance

## AI context

- Intended use:
- Affected people:
- Data classes:
- Human oversight:
- Cost of failure:
- Evaluation evidence:
- Monitoring:
- Shutdown or rollback authority:

## Evidence status

### Confirmed

### Observed

### Inferred

### Open questions and contradictions
```

## `DELIVERABLES.md`

```markdown
# Deliverables

Last updated: YYYY-MM-DD

## Delivery rules

- A request enters as `Requested`.
- Commercial commitment requires an authoritative approval source.
- Completion requires recorded acceptance evidence.
- Scope changes receive a dated change record.

## Register

| ID | Priority | Deliverable | Desired outcome | Scope status | State | Owner | Dependencies | Acceptance evidence | Source | Next action |
|---|---|---|---|---|---|---|---|---|---|---|

## Detail

### DEL-001 — Title

- Desired outcome:
- Requested artifact/change:
- In scope:
- Exclusions:
- Dependencies and client inputs:
- Acceptance evidence:
- Risk and recovery:
- Owner:
- State:
- Source:
- Next action:

## Change record

| Date | Deliverable | Change | Source | Impact |
|---|---|---|---|---|
```

## `SOURCES.md`

```markdown
# Sources and assets

Last updated: YYYY-MM-DD

## Source ledger

| ID | Type | Description | Location | Received/checked | Sensitivity | Supports |
|---|---|---|---|---|---|---|

## Asset ledger

| Source ID | Filename | Stable location | Format | Size/checksum | Usage or rights note | Observations |
|---|---|---|---|---|---|---|

## Decisions

| ID | Date | Decision | Authority | Affected artifacts |
|---|---|---|---|---|

## Provenance gaps

- Unknown or inaccessible sources.
- Client statements awaiting confirmation.
- Conflicting details that remain unresolved.
```

## Minimum readiness

A client repository is ready for delivery planning when:

- every confirmed profile claim has a source ID;
- every supplied request has a delivery entry;
- active work has an owner, dependencies, next action, and acceptance evidence;
- contract terms and deadlines have authoritative sources;
- credential requirements are value-free;
- live external changes remain separately authorized;
- AI work captures intended use, affected people, data classes, oversight, evaluation, monitoring, and rollback authority.
