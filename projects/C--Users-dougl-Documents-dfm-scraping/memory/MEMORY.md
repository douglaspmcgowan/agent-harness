# DFM Scraping Project Memory

## Memory Files (see individual files for details)
- [project_status.md](project_status.md) -- **READ FIRST** — v1 Streamlit app is deprecated, only v2 is active
- [irr_verification.md](irr_verification.md) -- Correct R2/R3/R4 IRR metrics, data locations, common errors, recomputation scripts
- [tool_workarounds.md](tool_workarounds.md) -- Edit/Write EEXIST bug workarounds, file encoding, sed gotchas, allowlist config
- [schema_and_agent.md](schema_and_agent.md) -- Schema refactor details, DFM agent functions/schemas, backup files
- [validation_docs.md](validation_docs.md) -- Where validation argument, reviewer data, IRR metrics, and paper content lives
- [latex_paper.md](latex_paper.md) -- LaTeX/ASME table formatting, ASME class gotchas, appendix structure, report data sources, bib format, key references
- [archive/](archive/) -- Archived v1-specific memories (streamlit_implementation.md, neo4j_setup.md)

## Environment
- Windows 11, PowerShell for running commands
- Python venv at `.\venv\Scripts\python.exe`
- PowerShell env vars: use `[Environment]::SetEnvironmentVariable('VAR','val','Process')` (not `$env:VAR`)
- gpt-5-nano does NOT support `temperature=0` -- omit temperature param or use default (1)
- Unicode arrows cause UnicodeEncodeError on Windows cp1252 terminal -- use `->` in print strings and schema descriptions
- Bash tool runs under /usr/bin/bash; use `./venv/Scripts/python.exe` to run Python (NOT bare `python`)
- Edit/Write tools often fail with EEXIST -- use sed or Python scripts via Bash instead (see tool_workarounds.md)
- Project allowlist in `.claude/settings.json` -- prevents repeated permission prompts for sed, grep, python, etc.

## Schema Structure (as of 2026-02-18)
- **FrameType**: risk, heuristic, principle, case, workaround, observation, comparison, other
- **ScopeDomain**: design_geometry, machining_process, material, tooling, programming, shop_operations, quality, cost, machine_capability, other
- **EpistemicStance**: absolute_authoritative, direct_neutral, hedged_emphatic, tentative_subjective, narrative_implied
- Schema field descriptions ARE the prompt (structured output API). SYSTEM_PROMPT covers behavioral rules only.
- Three prompt surfaces: schema.py Field(description=...), SYSTEM_PROMPT in extract.py, RETRY_SUPPLEMENT in extract.py

## Key Extraction Issues (as of 2026-02-18)
- epistemic_stance overrides: `apply_epistemic_stance_overrides()` handles hedge+strong combos
- applicability: context_dependent no longer DEFAULT. Universal put first with clearer definition
- EXTRACTION PRIORITY: personal practice > definitions
- VERBATIM QUOTING: character-for-character, no ellipses, shorter substrings
- example_context fill rate: 95-100% on non-nano models
- Wider fuzzy match window (+/- 10%) for quotes >80 chars

## Model Comparison: Extraction (as of 2026-02-18)
- **gpt-4.1-mini**: BEST mini-class (11% variability, 100% EC fill, verbatim quotes)
- **gpt-4.1**: Best overall quality (18-19 frames, 100% EC fill, verbatim)
- **gpt-5**: Richest type diversity (22-23 frames, occasionally splits finer)
- gpt-5-nano/mini: NOT recommended (high variability, paraphrasing)

## Model Comparison: LLM-as-Judge (as of 2026-03-06, V3 rubric, 26 frames)
- Human baseline (R2/R3/R4): 88% Keep, 12% Revise, 0% Remove
- **gpt-4.1**: 65% Keep, 65% agreement. BEST judge. Non-reasoning = doesn't overthink.
- **gpt-5 minimal**: 54% Keep, 54% agreement. Reasoning makes it harsher.
- **gpt-5 medium**: 50% Keep, 58% agreement. Catches both Revise frames but over-flags.
- **gpt-5.4 medium**: 15% Keep, 15% agreement. Catastrophically harsh. Unusable.
- Key finding: More reasoning = worse agreement with humans
- gpt-5 does NOT support reasoning_effort="none" -- minimum is "minimal"

## DFM Agent (as of 2026-03-03 V4)
- `dfm_agent.py`: RAG agent (Qdrant retrieval + NetworkX traversal + GPT synthesis)
- `dfm_report_schema.py`: Pydantic schemas + all prompts
- Interactive: `unpack` (frame details), `context` (provenance + summary), `help`
- Structured output streaming NOT possible: `response_format=DFMReportV2` returns complete JSON only

## File Safety
- **NEVER** run extract.py with MAX_POSTS > 5 without setting OUTPUT_FULL_FILE to a new filename
- extractions.json / extractions_se_all.json are production output -- treat as precious
- OVERWRITE protection: refuses to overwrite unless OVERWRITE=true
- Never hand-edit large JSON data files or contents of archive/ or src/scraping_logic/

## Pipeline Safety (hard-won lessons)
- **Checkpoint clobbering**: Running `infer_edges.py` with `--limit 3` for testing overwrites `infer_edges_checkpoint.json` (7,882 entries) with only 14 entries. Always back up checkpoint files before test runs, or use separate output files.
- `infer_edges.py --incremental --old-extractions <file>` compares old vs new extractions, only re-classifies changed frame pairs
- After rebuilding `provenance_graph.gpickle` or `qdrant_data/`, Streamlit app needs restart (cached resources persist across reruns)
- Git serves as backup for `provenance_graph.gpickle` and `semantic_edges.json` (regenerable via `git checkout`)
- Always open files with `encoding='utf-8'` to avoid cp1252 errors on Windows

## Stack Exchange API Gotchas
- `q` param: max 3 single-word OR terms; quoted phrases must be alone
- `title` param: max 1 term
- `sort=relevance` doesn't paginate beyond page 1
- Unauthenticated: 300/day; keyed: 10,000/day
