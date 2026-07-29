---
name: Streamlit App Implementation Details
description: Streamlit app internals -- logging fields, localStorage keys, UI component locations, PDF/Flash/Analysis mode gotchas
type: reference
---

## Logging Architecture
- `visitor_log.jsonl` -- fields: timestamp, IP, user_agent, name, contact, session_id, ip_hash
- `query_log.jsonl` -- fields: timestamp, IP, is_admin, visitor_name, contact_info, query, model, flash_mode, elapsed_s, token_usage, num_rules, num_disciplines, num_gaps, summary_preview
- `token_tally.json` -- cumulative stats (queries, tokens, unique IPs, page_views)
- Admin visits (OWNER_IPS) excluded from visitor log and page_views, but queries ARE logged (is_admin=true)
- All timestamps in PST (America/Los_Angeles)

## localStorage Keys
- `_dfm_public_ip` -- cached public IP from api.ipify.org
- `_dfm_welcome_done` -- welcome form shown flag
- `_dfm_admin_token` -- SHA256 of admin password (persists login across reload)

## Session State Keys
- `_visitor_first_name`, `_visitor_last_name`, `_visitor_contact` -- welcome form data (all optional)
- `flash_on` -- Flash Mode toggle (must use explicit key="flash_on")

## Key UI Components in streamlit_app.py (~3200 lines)
- `render_frame_popover()` (~line 785)
- `render_design_rules()` (~line 880)
- `render_knowledge_gaps()` (~line 1061)
- `generate_pdf_report()` (~line 1302)
- `_render_kg_explorer()` (~line 2095)
- `_render_admin_page()` (~line 2562)

## PDF Generation (fpdf2) Gotchas
- Helvetica only supports Latin-1 -- `_sanitize_for_pdf()` replaces Unicode with ASCII
- `write_html()` leaves cursor at unpredictable X -- call `_reset()` before AND after
- `_safe_text()` and `_safe_html()` wrap all write ops with sanitization + cursor reset
- `&bull;` HTML entity decodes to Unicode bullet (U+2022) which Helvetica can't render -- use `-`
- Try/except around formula rendering (Courier font can be too wide)

## Flash Mode
- gpt-4.1-mini (~20s response time)
- "Fill the Gaps" button ONLY appears for live flash queries (cached examples already have backfill)
- Backfill: calls `backfill_knowledge_gaps()`, stores in result_dict, triggers rerun
- Home button must reset `flash_on` to False

## Analysis Modes (as of 2026-03-11)
| Mode | Model | reasoning_effort | top_k | max_hops | max_frames | Decompose | Backfill |
|---|---|---|---|---|---|---|---|
| Flash Mode | gpt-4.1-mini | None | 5 | 1 | 10 | No | No |
| Quick Search | gpt-4.1 | None | user | user | user | user | user |
| Efficient Thinking | gpt-5 | "low" | user | user | user | user | user |
| Deep Reasoning | gpt-5 | None (default) | user | user | user | user | user |
- gpt-4.1-mini does NOT support reasoning_effort -- only gpt-5 models do
- Implementation: monkey-patch decompose/synthesize/backfill at query time
- Benchmark script: `benchmark_4modes.py` -> `benchmark_4modes_results.json`

## IP Detection (CRITICAL -- hard-won knowledge)
- Streamlit Cloud strips real public IPs from ALL server-side headers (X-Forwarded-For, CF-Connecting-IP, X-Real-IP all return private 192.168.x.x IPs)
- `st.context.ip_address` returns None on Streamlit Cloud
- Cookie approach does NOT work (WebSocket connections don't send cookies set by iframe JS)
- Working solution: Client-side JS in `_inject_client_js()` fetches real IP from `api.ipify.org`, passes back via `?_cip=` query param, stored in session_state
- `_is_private_ip()` checks RFC 1918 ranges -- used to detect if IP resolution hasn't happened yet
- IP cached in localStorage as `_dfm_public_ip` so returning visitors skip the ipify fetch
- Welcome form MUST wait for IP resolution before showing (prevents flash before JS redirect)
- Admin/owner detection via OWNER_IPS secret only works AFTER IP is resolved

## Welcome Form
- `@st.dialog` popup for first-time visitors (first name, last name, contact -- all optional)
- Form is SKIPPED for admin/owner visitors (matched by OWNER_IPS)
- Form is DELAYED until public IP is resolved (prevents showing during JS redirect)
- "Form shown" flag persisted to localStorage (`_dfm_welcome_done`) so returning visitors never see it
- JS also handles welcome form persistence (`?_vf=1` query param) in same redirect as IP to avoid double-redirect

## Example Cache
- 4 examples: thin-walled aluminum, fixturing thin parts, deep pocket milling, climb vs conventional milling
- Load via `DFMReportV2.model_validate(cached["report"])`
- Regenerate with `generate_example_cache.py`
