---
name: Project Status
description: Current active project and what's been deprecated -- read first to orient any new session
type: project
originSessionId: 770265e7-7ca6-4097-b7fe-fc0602ccb04b
---
The v1 Streamlit app (`dfm-kg-agent`, deployed at dfm-kg-agent.streamlit.app) is **no longer being actively worked on**. All new development is on **v2** (`dfm-kg-agent-v2/` subfolder inside `dfm_scraping`).

**Why:** v2 is a full rewrite with a better stack (Vite + React + TypeScript frontend on Vercel; FastAPI on Modal backend; Qdrant Cloud + Supabase). v1 is a research demo only.

**How to apply:** When starting a new session for v2 work, open Claude Code from `dfm_scraping/dfm-kg-agent-v2/` directly so the session is scoped to that git repo. Do not make further changes to `streamlit_app.py`, `dfm_agent.py`, or other v1 root-level files unless explicitly asked.

When the user says "the app" without qualification, they **always mean v2** (`dfm-kg-agent-v2/`). Never interpret "the app" as v1.

The ASME IDETC paper work (`main (2).tex`, `REVISION_PLAN_V2.md`) is still active and lives in the `dfm_scraping` root — it is separate from both v1 and v2 app development.
