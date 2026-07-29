---
name: news-digest
description: Builds Douglas's interactive AI/Design/Tech news digest. Each run pulls fresh stories from his news emails (Gmail MCP) and a curated set of web/RSS/Reddit/X/forum sources, merges them into a persistent corpus (adding new, pruning stale), then renders an interactive digest.html + a markdown note in NASA_GSFC_Vault_1/News Digest/. Topics: AI, Design, AI-in-Design/Engineering, and big Tech/coding. Invoke with /news-digest. This is PERSONAL (not NASA) work — open-web WebFetch/WebSearch are allowed here.
---

# /news-digest

## Purpose

Give Douglas one calm, scannable brief of what's new across **AI**, **Design**, **AI-in-design/engineering** (his research lane), and **big Tech/coding** — pulled from the newsletters already hitting his inbox plus the best public sources. Each run keeps a **persistent corpus**: new stories are added, stale ones age out, and the whole thing stays organized so the digest reflects "what's live right now," not a one-shot snapshot.

Two outputs every run:
- `News Digest/digest.html` — the interactive dashboard (topic filters, keyword search, story clustering, "new since last run").
- `News Digest/Latest Digest.md` (+ a dated copy in `News Digest/digests/`) — the Obsidian-readable summary.

**Scope note:** This is personal news, not NASA work. WebFetch/WebSearch ARE allowed for this skill. Do not route it through NASA endpoints. Keep it out of any ITAR/CUI context.

---

## Paths

- Working folder: `C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\News Digest\`
- `sources.json` — the editable source registry (Gmail senders/labels, web/RSS, Reddit, X, forums).
- `corpus.json` — the persistent store. **Read it first** so you don't re-add items already present.
- `build_digest.py` — deterministic prune + cluster + render. You do **not** reimplement this; you feed it corpus.json and run it.

---

## Phase 0 — Load state

1. Read `sources.json` and `corpus.json`.
2. Note `corpus.last_run` (the date of the previous build) and the set of existing item `id`s and `url`s — these are your dedup keys.
3. Default lookback for gathering: since `last_run` (or 7 days if this is the first run).

---

## Phase 1 — Gather fresh items (parallelize)

You are looking for **individual stories/links**, not the newsletters themselves. A single TLDR email contains ~8 stories — pull every story that clears the score bar (see Phase 2), linking to the actual target URL printed in the email, never inventing one.

**Volume = comprehensive.** Don't cap the gather. Pull everything from the sources that clears the score bar; the digest stays calm through clustering + progressive disclosure (`first_screen_cap`), not through dropping real stories at gather time. The only filter at this stage is "is this a real, on-topic story worth Douglas's attention" — if yes, include it.

### 1a. Gmail (news emails)
For each sender/label in `sources.json.gmail`:
- `search_threads` with `from:<sender> newer_than:<window>` (or `label:<id> newer_than:<window>`).
- For promising threads, `get_thread` with `messageFormat: FULL_CONTENT` and extract the headline + real link for each top story.
- Skip pure-promo senders; the registry already excludes them.

### 1b. Web / RSS
For each source in `sources.json.web` (and `forums`), `WebFetch` the `rss` feed when present (cheaper, structured); fall back to the `url`. Pull the top items since `last_run`. Respect each source's topic tag and weight.

### 1c. Reddit / X / forums
- Reddit: `WebFetch` each `.rss` endpoint in `sources.json.reddit`; take the top posts.
- X: **corroboration-only.** An X/Twitter post may be surfaced **only when a real article/RSS/web item also covers the same story** — i.e. the X item shares a `cluster` key with at least one non-X source in this run. A standalone X post with no corroborating coverage is dropped (rumors and single-account claims don't make the digest on their own). Use X as a *pointer* to find the underlying story, then cite the underlying source. No open RSS for X — try a live nitter instance from `sources.json.twitter.nitter_instances`; if all are unreachable, skip X for this run and note it. Never block the digest on X.

**Hard rule:** only include a link that actually appears in the source. If you can't find the real URL, drop the item. Never fabricate or guess article URLs (CLAUDE.md).

---

## Phase 2 — Normalize, dedup, cluster, score

Build a list of item objects and **merge into `corpus.json`** (don't overwrite existing items; append new ones, and bump `last_seen` to today for any existing item that reappeared).

Item schema:
```json
{
  "id": "stable-slug-or-url-hash",
  "title": "Headline as written",
  "url": "https://real-target-link",
  "source": "TLDR (email)",
  "source_type": "email|rss|web|reddit|twitter|forum",
  "topic": "ai|design|ai_in_design|tech",
  "topics": ["ai", "tech"],
  "summary": "2–4 sentences — full context on what happened and why it matters. Only on cluster leads / score ≥7. Empty string otherwise.",
  "rbtl": "1–2 sentences — the meta story, what this actually signals. Only on cluster leads / score ≥7. Empty string otherwise.",
  "first_seen": "YYYY-MM-DD",
  "cluster": "openai-ipo",   // OPTIONAL: shared key for same-story dedup across sources
  "score": 7,                 // 0–10 importance (see below)
  "pinned": false             // true only for evergreen sources, never dated stories
}
```

Rules:
- **Dedup:** if a story's `url` or `id` already exists in the corpus, don't duplicate it — update `last_seen` instead.
- **Cluster:** when ≥2 sources cover the same story, give them the same `cluster` key (a short slug). build_digest.py shows one lead item with a "+N more on this story" expander. This is the single highest-value behavior — Techmeme/Ground News feel calm because of it.
- **Topic routing:**
  - `ai` — models, labs, AI products, research, policy.
  - `design` — UX, visual/web/product design, design tools (non-AI angle).
  - `ai_in_design` — generative UI, AI design/eng tooling, LLM-in-the-product-loop, Douglas's research lane. When a story is both, prefer `ai_in_design` if the design/eng angle is the point.
  - `tech` — big tech, startups, coding, infra, everything else notable.
- **Score (0–10):** newsworthiness × relevance to Douglas. Launches/leaks/major moves 7–9; solid reads 5–6; minor 3–4. Add nothing for `summary` you can't ground in the source text.
- **Summaries + RBTL = top stories only.** For cluster leads and items scoring ≥7, write two fields:
  - `summary`: 2–4 sentences. What happened, key details, full context — more depth than a wire-service lede. Ground every claim in the source.
  - `rbtl` ("Reading Between the Lines"): 1–2 sentences on the *meta* story. What this actually signals — the competitive dynamic, the thing the press release doesn't say, the power move buried in the announcement, the implication most coverage will miss. Be direct and analytical; don't hedge into the obvious.
  Everything else ships as headline + source + link with empty `summary` and `rbtl`. build_digest.py renders `rbtl` only on cluster lead items with a distinct style, so the long tail stays clean.
- Do **not** set `is_new` — build_digest.py computes that from `first_seen` vs `last_run`.

Write the merged corpus back to `corpus.json` (preserve the existing `references` array and `retention_days`).

---

## Phase 3 — Render

Run the deterministic builder:
```bash
cd "C:/Users/dmcgowa2/Documents/NASA_GSFC_Vault_1/News Digest" && python build_digest.py
```
It prunes items past their per-topic retention window (pinned kept), clusters, flags "new since last run," and writes `digest.html`, `Latest Digest.md`, and `digests/YYYY-MM-DD.md`. It also stamps `last_run` and fills `last_seen`. Confirm the printed item/prune counts look sane.

If you changed the look/layout, re-render and **screenshot `digest.html` to verify** before claiming done (headless Playwright on the `file:///…/News%20Digest/digest.html` URL — the path has a space, URL-encode it). Don't trust the markup unseen.

---

## Phase 4 — Report

Output to chat: the digest.html path, item count, how many new, how many pruned, and the 3–5 biggest new stories as a quick list. Offer to open `digest.html`. Nothing else.

---

## Operating constraints

- **Manual only.** This skill runs when Douglas types `/news-digest` — nothing else. Do **not** create a scheduled task, cron job, or wake-up to run it on a cadence. (If he ever wants automation, it's a deliberate, separate ask — offer it as a one-line note, never set it up unprompted.)
- **Personal, web-allowed** — but never send this through NASA/ITAR/CUI endpoints or contexts.
- **Never fabricate links, headlines, or numbers.** Drop an item before you invent its URL. Hedge uncited claims.
- **Never read API keys / secrets** (CLAUDE.md). The Gmail MCP handles auth; you never touch tokens.
- **File safety:** `corpus.json`, `digest.html`, and the generated markdown are all skill-owned generated files — overwriting them on each run is expected and fine. Do **not** touch other vault notes Douglas authored. `sources.json` is Douglas's to edit; only change it if he asks.
- **Don't expand scope:** no new topics, no extra outputs, no refactors of build_digest.py unless asked. Add a source to `sources.json` only on request.
- If a source is unreachable, skip it and note it in the report — never block the whole digest on one feed.
- Reddit/X may rate-limit or block automated fetches; if so, skip and note it rather than retrying in a loop.
