---
name: IRR Verification Results
description: Correct R2/R3/R4 inter-rater reliability metrics, common errors found, and how to recompute
type: project
---

## Verified R2/R3/R4 IRR Metrics (as of 2026-03-11)

### Reviewer Data Locations
- **R2**: `reviewer_docs/reviewer_2_review.json` (JSON, 26 frames)
- **R3**: `Reviewer 3 -- Knowledge Frame Evaluation.md` (markdown in project root, must be manually parsed)
- **R4**: `reviewer_docs/reviewer_4_review.json` (JSON, 26 frames)
- **R1**: `reviewer_docs/reviewer_1_review.json` / `Reviewer Data.md` -- EXCLUDED from current panel
- **R5**: `Reviewer 5 -- Knowledge Frame Evaluation.md` -- EXCLUDED (ceiling-effect ratings)

### Known Data Issues (Fixed)
- R2 frame 17 was MISSING `extraction_accuracy` key in JSON. Fixed: added `"extraction_accuracy": 3`
- `IRR_Metrics.md` contains numbers from a DIFFERENT reviewer set (likely R1/R2/R4), NOT R2/R3/R4. WARNING banner added. Use `validation_argument_outline.md` for correct R2/R3/R4 numbers.

### Correct Numbers (702 total ratings: 26 frames x 9 dimensions x 3 raters)

**Quality Distribution (pooled across 3 raters, tiered):**
- Overall: 83.9% Good, 11.0% Acceptable, 5.1% Poor
- Primary (EA+CL+PR+MP): 96.5% Good, 3.2% Acceptable, 0.3% Poor
- Tribal Knowledge: 28.2% Good, 44.9% Acceptable, 26.9% Poor

**Pairwise Agreement Means:**
- Primary: EA=92%, CL=93%, PR=95%, MP=95% -> mean 94%
- Secondary: SC=85%, ES=83%, OJ=77%, FT=72%, AP=69%
- Tribal Knowledge: 45%

**Chance-Corrected (Gwet's AC1):**
- EA=0.919, CL=0.933, PR=0.947, MP=0.947 (primary: near-perfect)
- SC=0.825, ES=0.818, AP=0.644, FT=0.659 (secondary: substantial)
- TK=0.185 (slight -- inherently subjective)

**Fleiss' Kappa:** All terrible due to prevalence paradox. EA=0.209, PR=-0.026, MP=-0.026, etc. Do NOT report as primary metric.

**All-3 Exact / Adjacent:**
- Primary: 88.5-92.3% exact, 96.2-100% adjacent
- Secondary: 53.8-76.9% exact, 80.8-100% adjacent
- TK: 23.1% exact, 88.5% adjacent

### Tiering Rules
- 1-3 scale (EA, CL, TK): 3=Good, 2=Acceptable, 1=Poor
- 1-5 scale (PR, MP, FT, SC, AP, ES): 4-5=Good, 3=Acceptable, 1-2=Poor

### Common Errors Found in Documents
- review_summary.md had wrong R3 means: TK was 1.96 (correct: 1.92), FT was 3.88 (correct: 3.92)
- validation_argument_outline.md had wrong secondary pairwise: FT was 70% (correct: 72%), AP was 70% (correct: 69%), TK was 43% (correct: 45%)
- EA Good% was 94.8% in some tables (correct: 94.9%)
- Total ratings was 701 before R2 F17 EA fix (correct: 702)

### Scripts for Recomputation
- `_verify_irr_tmp.py` -- computes means, judgments, quality distributions, pairwise agreement from raw data
- `_verify_ac1.py` -- computes Fleiss' Kappa and Gwet's AC1 for tiered ratings
- `benchmark_tiered_irr.py`, `benchmark_irr.py`, `benchmark_3rater.py` -- existing IRR scripts
