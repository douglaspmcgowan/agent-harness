---
name: Validation Documentation Map
description: Where validation argument, reviewer data, IRR metrics, and paper draft content lives
type: reference
---

## Key Validation Documents
- **`validation_argument_outline.md`** -- THE master document for validation section. Contains:
  - What to change in paper and where (Part 1)
  - Citations needed (Part 2)
  - 5 argument outlines with counterpoint defenses (Part 3)
  - IDETC readiness checklist (Part 4)
  - All numbers to report: quality distributions, IRR tables, human means, automated review stats (Part 5)
  - What NOT to include: kappa, alpha, TOST, Bland-Altman (Part 6)
  - LLM-as-Judge findings for internal reference (Part 7)
  - Future IRR study design recommendations (Part 8)
  - Scripts and data files reference (Part 9)
  - **Chance-corrected IRR table** (AC1, Fleiss' K, All-3 Exact/Adjacent) added 2026-03-11

- **`reviewer_docs/review_summary.md`** -- Human & LLM review summary with per-reviewer means, pairwise agreement, quality distributions, and discussion text

- **`paper_draft.md`** -- The actual IDETC paper draft being revised

- **`reviewer_rubric.md`** -- The rubric given to human reviewers

- **`IRR_Metrics.md`** -- WARNING: contains numbers from WRONG reviewer set (R1/R2/R4 not R2/R3/R4). Has warning banner. Do not use for current analysis.

## Validated Numbers Location
All correct R2/R3/R4 numbers are in `validation_argument_outline.md` Part 5. If numbers conflict between documents, `validation_argument_outline.md` is authoritative (verified 2026-03-11).

## Human Majority Baseline (R2/R3/R4)
- 88% Keep (23/26), 12% Revise (3/26), 0% Remove
- Revise frames: F3 (taxonomy boundary), F5 and F6 (possible hallucination in main_point)
- Each reviewer independently flagged exactly 15% (4/26) for revision
