---
name: sift
description: "Turns 'research everything about X' into a categorized, image-rich, filterable triage queue in Douglas's Workbench — instead of a prose report. Casts a WIDE net (deep-search-style query fan-out for BREADTH of sources, not one synthesized essay), clusters the sources into named categories, pulls ONE representative image per source (paper figure / first page / og:image / favicon — best-effort), and enqueues them as image-bearing review cards (one per source, category as a colored tag, Keep/Maybe/Discard, likely-keeps first) plus an optional filterable HTML brief, so he skims + filters candidates fast with visual cues and the live search box. Use when Douglas says 'sift X', 'sift through sources on X', 'gather everything about X into my workbench', 'find all the sources on X so I can filter them', 'broad research pass on X into review cards', or '/sift'. Composes with /deep-search (breadth front-end) but ends in the Workbench, not a report. Distinct from /deep-search (which SYNTHESIZES one cited answer) and /docket (which just routes an already-built batch)."
---

# /sift [topic]

A broad research pass whose deliverable is a **triage surface**, not an essay. Cast a wide net, cluster
what comes back into named categories, give every source a representative image, and land the whole set in
the Workbench (`:8471`) as image-bearing **review cards** he can Keep/Maybe/Discard and live-filter — optionally
alongside one rich **HTML brief** that shows the same sources grouped by category. The point is fast visual
triage of MANY candidates, so breadth and scannability beat depth-on-any-one-source.

## What this is NOT

- **Not `/deep-search`.** deep-search fans out to ANSWER a question and hands back one synthesized, cited
  report. `/sift` reuses its fan-out for the front half (Phases 2–5) but the back half is different: it does
  NOT collapse sources into a prose conclusion — it keeps them as discrete, categorized, image-bearing cards
  to triage. When the ask is "what's the answer to X," use deep-search; when it's "show me everything on X so
  I can filter it," use sift.
- **Not `/docket`.** docket routes an already-assembled brief/review/decision batch into the Workbench. `/sift`
  does the research + categorization + image work that PRODUCES the batch, then uses the same enqueue core
  docket uses to land it. docket is the last step sift performs, not a substitute for it.
- **Not `/gallery`.** gallery generates HTML design VARIANTS as an option-select decision. sift gathers
  external research SOURCES as review cards.
- **Not `/recon` or `/map-field`.** Those map a landscape to help Douglas DECIDE a direction. sift just
  surfaces and organizes the raw sources for his own filtering — no recommendation, no adopt/reject call.

## Step 1 — Classify + gate (do this before any searching)

State the topic in one line and pick the mode; refuse the expensive path when it's pointless:

- **Fix the inclusion criterion up front — what a "keep" looks like.** Before any searching, pin one line
  describing what makes a source a keeper for THIS ask (the angle, artifact type, recency, or claim Douglas
  actually wants), the way a systematic review fixes its eligibility criteria *before* screening rather than
  after — Cochrane/PRISMA treat this as the most consequential call after the topic itself, because a
  criterion set mid-screen quietly bends what gets kept. If Douglas stated one, use it verbatim; if he
  didn't, infer the implied keeper-shape from the topic, state it as a one-line assumption, and proceed
  (don't block on a question — autonomy rule). This criterion is what the relevance RANK in Steps 2/5 scores
  against (rank 1 = matches the criterion, not merely on-topic), and it rides on the review SET so every
  Keep/Maybe/Discard is judged against a stated target instead of a bare topic string.
- **Is this a public/personal research topic?** sift searches the open web, so it is **public-topics-only**,
  exactly like `/deep-search` and `/news-digest` (per `MAP.md` NASA egress rules). If the topic is
  NASA-internal / CUI / ITAR, STOP — say so and do not run the open-web fan-out.
- **Is a source pile actually what he wants?** If the real ask is a synthesized answer, hand off to
  `/deep-search` instead and say so. sift is for "give me the sources to filter," not "tell me the answer."
- **Surface choice.** Default: **review cards + an HTML brief**. Offer to skip the brief for a quick pass, or
  skip cards for a read-only overview. If unstated, do both — the cards are the triage workflow, the brief is
  the scannable overview.

## Step 2 — Cast the wide net (breadth fan-out)

Run `/deep-search` Phases 2–5 (plan → search → read → iterate) with the goal set to **breadth of distinct,
credible sources**, not convergence on an answer:

- Decompose the topic into 6–12 sub-queries spanning angles, sub-topics, and at least one contrarian angle.
- **Prioritize human-authored sources** (Reddit, HN, practitioner blogs, first-party eng blogs, papers) over
  SEO listicles and AI-summary farms — same discipline as deep-search Phase 3.
- **No source ceiling.** Keep going until the angles are covered and new searches stop surfacing genuinely
  new credible sources (deep-search's "2 loops or gaps closed" stop). Report roughly how many you gathered
  and note if you deliberately stopped early.
- Dedupe by canonical URL, then catch the near-duplicates a URL check misses — same title + authors across
  hosts (arXiv vs publisher vs a reposting blog), the clustering Rayyan's similarity graph does with edit
  distance. Merge each cluster into ONE card on the best URL; list the mirrors in its Source section. Drop
  dead links and paywalled-with-no-content pages, keeping a count of what you dropped and why (feeds the
  Step 6 funnel).
- Heavy fan-out (>10 web calls / multiple loops): dispatch a background `general-purpose` Agent per
  deep-search's execution model, requiring it to return a structured source list (title, url, source-type,
  a SUBSTANTIVE 3-5 sentence summary — problem/method/finding, enough to review the source blind — a
  one-line relevance, a relevance RANK 1–3 **scored against the Step 1 inclusion criterion** (1 = matches the
  criterion / likely keep, 2 = plausible, 3 = long shot; drives the enqueue order in Step 5), a suggested
  category, venue/year if known, and an image URL/plan per the next step). Pass the inclusion criterion
  verbatim into each agent's brief — a subagent scores relevance against a stated target or it drifts
  (Anthropic's clear-contract lesson). **Douglas reviews these cards without opening the sources, so the summary is not optional — a card
  with only a one-line relevance is a failed card.**
- **Scale the fan-out and draw hard boundaries.** A narrow topic is one agent and ~10 calls; a broad
  landscape is 2–4 agents, each owning an explicit, NON-overlapping slice of the sub-queries — Anthropic's
  multi-agent research lesson: vague overlapping briefs produce duplicate searches and duplicate sources
  the dedupe pass then has to mop up.

## Step 3 — Categorize (cluster the sources)

Group the gathered sources into **3–7 named categories** that fit the topic (e.g. *Foundational papers ·
Practitioner explainers · Community threads · Tools/repos · Critiques/contrarian · News*). Each source gets
exactly one category. A category becomes the card's colored tag and the brief's section heading. Keep
category names short and human — they are the primary scan axis. If a source is genuinely a "misc," a small
*Other* bucket is fine; don't force a taxonomy that doesn't fit.

## Step 4 — Pull ONE representative image per source (hard requirement — best-effort, not perfect)

Every source gets a visual. Pick the best available per source TYPE; graceful degradation is built in
(a broken image renders a labeled placeholder, never a broken glyph), so "something usually nice" beats
"perfect":

- **Web page / blog / thread / repo:** extract `og:image` (or `twitter:image`) from the page HTML you already
  fetched in Step 2 — that's the page's own representative image. GitHub repos → the owner/social preview or
  the org avatar.
- **Paper (arXiv/journal):** prefer a first-figure or first-page thumbnail if the landing page exposes one;
  many arXiv pages only carry a generic og:image, so falling back to the publisher/arXiv icon is acceptable.
- **Last-resort fallback:** a favicon/domain icon (`https://icons.duckduckgo.com/ip3/<host>.ico`) so the card
  still carries a visual cue.

**Local-download vs hotlink — decide per source (default: download for robustness on this machine).**
- **Download (preferred here):** GET the image with a shell fetch (`curl`/`Invoke-WebRequest` — the model's
  WebFetch tool returns text only, and the shell reaches the open web per `MAP.md`), save it into the reviewer
  asset store `C:\Users\dmcgowa2\.claude\reviewer\assets\<unique-name>.<ext>`, and set the card's `image` to
  the bare filename. The reviewer serves it via `/review/api/asset` — no runtime network dependency, works
  offline, and sidesteps proxy/egress flakiness (remote hotlinks were observed failing to load in the
  Workbench's browser on this machine). Keep images small (a thumbnail is enough).
- **Hotlink:** set `image` to the full `https://…` URL. Zero storage, but rendering depends on the viewer's
  network reaching that host; a miss degrades to the labeled placeholder.

Never fabricate an image URL. If no real image is findable, use the favicon fallback or omit `image` (the
card still renders cleanly without one).

## Step 5 — Enqueue the triage surface

Build the batch and enqueue via the same core `/docket` uses (no new deps). Node runs by absolute path (the Bash
tool PATH is broken on this machine); assemble the JSON in a temp file per item or loop the core directly.

**A) Review cards — one per source** (the Keep/Discard triage workflow). Per-card `review` schema:
```json
{
  "title": "<source title>",
  "description": "<SUBSTANTIVE 3-5 sentence summary — what problem it tackles, the method/approach, and the key result or claim. Enough to review the source BLIND, without opening it. NOT a one-liner.>",
  "options": ["Keep", "Maybe", "Discard"],
  "source": "sift: <topic>",
  "image": "<asset filename OR https URL>",
  "tags": [{"text": "<Category name>", "tone": "<cyan|green|amber|coral|purple|steel|blue>"}],
  "sections": [
    {"label": "Source", "text": "<canonical URL>"},
    {"label": "Why it matters", "text": "<one line: why it's relevant to the topic>"},
    {"label": "Type", "text": "<venue/year · source-type, if known>"}
  ]
}
```
- `source: "sift: <topic>"` groups every card into ONE review SET (its own tile + live filter box + Focus/
  Scroll modes in the reviewer). Use the SAME source string for the whole batch.
- **"Maybe" is the Rayyan-style third state** (Include/Exclude/Undecided): an unsure card gets parked
  honestly instead of forcing a fake Keep/Discard, and Douglas can sweep the Maybes in a second pass.
- **Enqueue in relevance-rank order (rank 1 first, rank 3 last)** — prioritized screening, the mechanism
  ASReview and Rayyan train a model for: the front of the queue carries the probable keeps, so even a
  partial triage covers the best candidates. Break ties by category so same-colored chips run together.
- One `tone` per category (pick from the seven valid tones), consistently, so the colored chip = the category.
- Put the URL in a `sections` entry labeled `Source` — the reviewer renders it as a clickable link.
- `card_html` (optional): a fully-sandboxed custom HTML card body for a source that deserves a richer inline
  preview (a quoted thread excerpt, a styled snippet). Static HTML/CSS + `<img>` only — scripts are stripped
  by the sandbox. Use sparingly; the image + description carry most cards.

**Turnkey processor — `workbench/sift_enqueue.js`.** The download-image-per-source (og:image → favicon
`.ico` fallback), category→tone mapping, and enqueue loop are already implemented and tested. Feed it a
batch JSON array (each element `{title, url, source_type, summary, relevance, rank, category, image, venue?,
year?}` — `summary` = the SUBSTANTIVE 3-5 sentence review-it-blind description; `relevance` = one-line
why-it-matters; `rank` = 1–3 relevance rank, and the array pre-sorted by it so the queue order lands right;
`image` = the og:image URL the breadth pass extracted, or null) and a set-source string:
```
C:/Users/dmcgowa2/tools/nodejs/node.exe "C:\Users\dmcgowa2\Documents\Claude NASA Folder\workbench\sift_enqueue.js" <batch.json> "sift: <topic>"
```
It downloads each image into `~\.claude\reviewer\assets\`, falls back to the site favicon
(`icons.duckduckgo.com/ip3/<host>.ico`) when the og:image misses, sets the card's `image` to the bare
asset filename, enqueues one review card per source via `lib/enqueue.js`, and prints the per-category
breakdown. It deletes nothing. **Verify the script exists before invoking it** (checked absent from
`workbench/` on 2026-07-21); if absent, hand-roll the loop with
`core.enqueue({type:'review', item})` via `lib/enqueue.js`, reproducing the image-download + tone + fallback
logic yourself and enqueuing in rank order. The reviewer poller ingests whether or not `:8471` is up.

**B) HTML brief (optional, recommended)** — one self-contained page grouping the SAME sources by category,
each as an image card, with a client-side text filter and category jump-links. Enqueue as a `brief` with
`format:"html"` + `src` = an absolute `.html` path (the briefs viewer renders it in a `sandbox="allow-scripts"`
iframe, so inline JS filtering and remote/asset images both work). Keep it fully self-contained (inline CSS +
JS; no external files — srcdoc has no base). This is the "surface it well" overview alongside the card queue.

## Step 6 — Report

- **The inclusion criterion used** (the Step 1 "what a keep looks like" line, quoted) — so the ranking is
  auditable and Douglas can flip it and re-rank if the criterion was off.
- The review SET name (`sift: <topic>`), card count, and category breakdown (N per category).
- The brief path (if built) and its Workbench URL.
- Where to act: **http://127.0.0.1:8471/review** (cards) and **/briefs** (overview).
- How images were sourced (downloaded vs hotlinked) and any sources that fell back to a favicon or no image.
- **The funnel, PRISMA-style:** N identified → M after dedupe + near-duplicate merge → D dropped (dead /
  paywalled / off-topic, with the reason class) → C enqueued — plus whether you stopped early. Never imply
  exhaustiveness. Match `/hone`'s and `/probe`'s honesty register: report what was gathered this pass, not
  "everything on X."
- Full absolute paths of any files written (batch JSON, brief HTML, downloaded assets), per the Files-list
  convention. Clean up the temp batch JSON after enqueue.

## Deviation clause

This staged flow is the well-reasoned default. If a specific run genuinely calls for a different move — the
topic wants a synthesized answer (hand to `/deep-search`), the sources are few enough to just list in chat,
or Douglas wants cards-only / brief-only — surface the divergence and your reasoning in one line and let him
decide, rather than forcing the full pipeline or silently skipping a step.

## Safety constraints

- **Public topics only.** Open-web fan-out is for public/personal research (per `MAP.md`); never run it on
  NASA-internal / CUI / ITAR content.
- **No secrets in any card/brief body**, and nothing in this flow sends Douglas's data to the open web — it
  only reads public sources and writes locally under `~\.claude\reviewer` / `~\.claude\briefs`.
- **Zero new dependencies** — enqueue via `workbench/lib/enqueue.js` / `bin/workbench.js`, the same path
  `/docket` uses. Do not add a package or a second enqueue route.
- **No fabricated content** — every source, URL, and image traces to something actually fetched. If an image
  can't be found, fall back or omit; don't invent one.
- Downloaded images stay small and land only in the reviewer asset store; don't bulk-download full-res media.

## Wiring (where this lives)

- Enqueue core / CLI: `workbench/lib/enqueue.js`, `workbench/bin/workbench.js` (review + brief types).
  Turnkey per-source image+enqueue processor: `workbench/sift_enqueue.js`.
- Review cards carry `image` + optional `card_html`; the reviewer has a per-set live filter box
  (added alongside this skill, 2026-07-18). Brief HTML renders sandboxed with scripts allowed.
- The card renders `description` as the LEAD paragraph, then `sections` below it (Source link, a
  tinted "Why it matters"/relevance panel, Type = venue·year·source-type). So the substantive summary
  goes in `description`; keep the one-line why-it-matters in a `Why it matters` section. (The reviewer
  used to let sections REPLACE the description blob — fixed 2026-07-18 so both show, description first.)
- The reviewer's `/api/asset` serves `.png/.jpg/.gif/.webp/.ico` (favicon `.ico` added 2026-07-18 so the
  favicon fallback actually renders; `.svg` stays rejected — it's a same-origin XSS vector).
- Front-end research engine: `/deep-search` (Phases 2–5). Routing sibling: `/docket`. App roster:
  [[reference_local_apps]]; auto-route rule: [[feedback_auto_route_workbench]].
