---
name: fellowship-review
description: Review a graduate fellowship or scholarship application draft (personal statement, research proposal, essay) against type-specific rubrics and common winning patterns. Use when the user asks to review, critique, or give feedback on a fellowship/scholarship draft, or prep for a fellowship interview.
---

# /fellowship-review

Evidence-based review of graduate fellowship and scholarship drafts. Source-of-truth for the process is `Fellowship_Writing_Guide.md` in the user's Claude Research Folder. This skill operationalizes §5 of that document.

## Phase 1 — Load context
- Read `Fellowship_Writing_Guide.md` if it exists in the current working directory or the user's Claude Research Folder. Prefer §§1–5 over summaries.
- Read the draft the user provided. If they didn't attach one, ask for it before doing anything else.
- If the user didn't name the fellowship, ask which fellowship this is for. Never review without knowing the fellowship.

## Phase 2 — Classify the fellowship type

Classify into one of:
- **Research** — NSF GRFP, NDSEG, DOE CSGF, NASA NSTGRO, UC-National Lab, DoD SMART
- **Leadership / well-rounded** — Rhodes, Marshall, Mitchell, Truman, Soros, Knight-Hennessy
- **Industry** — Google, Meta, NVIDIA, Apple, Microsoft, Adobe, Qualcomm
- **Faith / identity** — Harvey (28twelve), HSF, AISES, Point Foundation
- **Niche** — split further into: project-grant (Sigma Xi GIAR), domain (Link), completion (Josephine de Kármán)
- **Hybrid** — Hertz (research + interview-heavy), Autodesk Research Residency

If unclear, ask. Do not guess the type — it determines everything that follows.

## Phase 3 — Pull the rubric

State back to the user (one paragraph):
- What this fellowship is *selecting for*
- The highest-weighted criterion
- The technical-vs-personal essay split for this type
- The 1-2 biggest type-specific traps

Pull this from §3 of the guide. Do NOT proceed until this is explicit.

## Phase 4 — Universal checks (from §1)

Verify against these. For each, report **strong / partial / missing**:

- [ ] **Fund-the-person framing**: does the draft position the applicant as the protagonist, or is the project the protagonist?
- [ ] **Coherent narrative**: is there one argument about who this person is and where they're going, or is it a résumé in prose?
- [ ] **Funder's exact vocabulary**: does the draft use the solicitation's criterion words verbatim?
- [ ] **Show-don't-tell quantification**: count impact claims with numbers vs. without. Report the ratio.
- [ ] **Bolded load-bearing sentences**: are the 3–5 must-not-miss sentences emphasized?
- [ ] **Paragraph shape**: spot-check top 3 paragraphs — does each open with a take-home sentence?
- [ ] **Specificity**: count named methods, institutions, mentors, programs. Report the count.
- [ ] **Broader impacts / service weighted appropriately** (type-specific %).
- [ ] **Childhood content ≤2 sentences** unless prompt invites more.
- [ ] **No spotlight theft**: who is the grammatical subject of each paragraph?
- [ ] **Forward-looking close**: does it end on stakes, not summary?
- [ ] **Document-level arc**: wide interest → gap → contribution → stakes present?

## Phase 5 — Type-specific checks (from §3)

Apply only the checks for the identified type:

**Research**: bolded hypothesis? Intellectual Merit + Broader Impacts headers? BI ≥40% of personal statement? PhD-timeline feasible? Figure load-bearing (not decorative)?

**Leadership**: SELF / OTHERS / WORLD axes addressed? Character arc evident? Not the "anecdote → cliché → résumé → idealism" formula? Every achievement defensible in a 20-minute interview?

**Industry**: named company teams / papers / product surfaces? Publication record explicit? Near-term deliverable? Overlaps *stated* company priority areas?

**Faith/identity**: named institutional anchors (church, org, community)? Concrete formation experiences? Strategic-field argument present?

**Project-grant**: budget line items appropriate — no tuition/salary/general-consumable asks? Single-year feasibility?

**Hertz**: interview prep — 90-second research pitch rehearsed? Freshman-physics review done? One "creativity" example rehearsed cold? Prepared question to ask interviewer?

## Phase 6 — Reviewer-simulation scan

Reread the draft as if you have 3 minutes per page (NSF reviewer pace):
- Read only the first sentence of every paragraph — does the argument hold?
- Read only bolded text — does it tell the story?
- What lands? What gets skimmed past?

Report this as a short "what a tired reviewer at minute 15 takes away" paragraph.

## Phase 7 — Counterintuitive-moves audit (from §4)

- Does this sound like the applicant's own voice, or could their advisor have written it?
- Is this written to persuade one champion reviewer, or to avoid offending three lukewarm ones?
- Is the résumé leading, or is a specific scene leading?
- Leading with vision or with credentials?
- Any manufactured adversity / trauma-vomit?

## Phase 8 — Deliver in this format

1. **Fellowship type + rubric** — 1 paragraph.
2. **Top 3 strengths** — what to preserve.
3. **Top 5 issues ranked by impact on score** — fix-first order.
4. **Line edits** — specific sentences to cut, rewrite, or add, with suggested replacements. Don't rewrite wholesale.
5. **Missing items against rubric** — what's not there but needs to be.
6. **Reviewer-simulation summary** — minute-15 takeaway.

## Phase 9 — Hand control back

Do NOT rewrite the document wholesale. Propose edits; let the user decide which to accept. This preserves voice and prevents generic-ing out a personal document.

If the user asks you to make the edits yourself, only change the exact sentences they point to — don't sweep through the document making "style improvements" they didn't ask for.

## Scope and limits

- Verify factual claims in the draft (e.g., named publications exist, metrics are accurate) when easy; flag when they can't be verified.
- If the draft is for a fellowship whose rubric isn't in the guide, ask the user for the solicitation URL and read it before reviewing.
- For interview prep, use §2 of the guide (reviewer perspectives by type) — don't default to NSF-style feedback for a Rhodes interview.
- Never claim this process guarantees an award. It reduces known failure modes.
