---
name: Schema Structure and DFM Agent Details
description: Schema field changes from 2026-02-18 refactor, DFM agent key functions/schemas, backup file references
type: reference
---

## Schema Changes (2026-02-18 refactor)
- **Fields removed**: condition_value, knowledge_domain, directness, expression_strength
- **Fields added**: example_context (required when applicability != universal), extraction_rationale (required when frame_type/scope == other)
- **New classes**: ThreadFrame (scraper-only), ExtractionOutput (LLM-facing schema, separate from PostExtractionResult)
- **Output format**: JSON dict with `thread_frames` and `results` keys (not a flat list)

## DFM Agent Key Components
- Key schemas: DFMReportV2, DisciplineSection, ReasoningChain, ChainedFrame, FormulaEntry, ContradictionEntryV2, BackfillOutput, GapBackfill
- Key functions: `query_dfm()` (main pipeline), `decompose_query()`, `synthesize_report_v2()`, `backfill_knowledge_gaps()`, `get_frame_details()`, `gather_provenance_context()`, `summarize_context()`
- Interactive defaults: concise-with-frame-ID-refs + auto-backfill (override with --full / --no-backfill)
- CLI single-query defaults: full output, no backfill (add --concise / --backfill)

## Backup Files
- schema.py.bak2, extract.py.bak2 -- pre-2026-02-18 refactor
- schema.py.bak3, extract.py.bak3 -- pre-prompt-fixes
- dfm_agent.py.bak4 -- pre-V3
- dfm_agent.py.bak5 -- pre-V4/paper-aligned

## Other Notes
- iterate.py NOT yet updated for new schema -- needs field name changes before running
- File Patterns: schema field descriptions ARE the prompt (structured output API); SYSTEM_PROMPT covers behavioral rules; frame type definitions live in schema.py
