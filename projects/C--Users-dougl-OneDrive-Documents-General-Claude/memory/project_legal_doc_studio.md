---
name: project_legal_doc_studio
description: Recital — interactive legal-document studio (Motion to Dismiss demo) built for Anna / legal-solutions-website; live on Vercel + GitHub
metadata:
  node_type: memory
  type: project
  originSessionId: 5cc0a11e-b1ac-4167-af5b-ce63f46303f9
---

**Recital — Legal Document Studio.** Interactive viewer/editor for a Motion to Dismiss (U.S. District Court E.D. Pa., FRCP 12(b)(6), statute-of-limitations grounds, PA law). Built Jun 16 2026 as a capability demo for Anna Maxwell ([[project_amax_elite_accounts]] / the legal-solutions-website). Fillable highlighted fields with live propagation across the whole document, computed limitations math (incident date +2yr → deadline → days-late), citation→section→derivation mapping (click a paragraph → see its authorities + source memos + a "why this section exists" note), 21 authorities with weight/holding/links, 4 embedded research memos with an in-app markdown reader, edit mode, and court-clean print.

- **Live (PUBLIC):** https://legal-doc-studio.vercel.app — share THIS clean domain.
- **Gotcha:** the hashed `legal-doc-studio-*-douglas-mcgowans-projects.vercel.app` deployment URLs return **401** (team SSO "Standard Protection" on the `douglas-mcgowans-projects` scope). Only the clean project domain is exempt/public. Same pattern as [[project_client_portal]] / legal-solutions-website.
- **Repo:** github.com/douglaspmcgowan/legal-doc-studio (branch `master`), connected to Vercel → auto-deploys on push.
- **Stack:** static SPA, NO build step. `index.html` + `styles.css` + `app.js` + `data.js` + `refs-data.js` (4 memos embedded; regen via `node build-refs.mjs` from `reference/*.md`). Local: `python -m http.server 8911`.
- **Brand:** Sellit Cobalt (cohesive w/ Anna's site) — Inter Tight UI chrome, system serif for the document surface (authentic filing look), amber fill-tokens, cobalt(case)/green(statute) citation chips. Product register, not marketing.
- **Source content** = the Motion to Dismiss + 4 research files drafted in `OneDrive\Documents\General Claude\motion-to-dismiss\`. Project root `C:\Users\dougl\projects\legal-doc-studio\`.
- **Pending:** add to repo-map.md when G:\ remounts (was offline at build time).
