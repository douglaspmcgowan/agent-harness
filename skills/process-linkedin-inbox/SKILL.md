---
name: process-linkedin-inbox
description: Process pasted LinkedIn posts in /inbox/linkedin/, categorize, extract links, and propose site edits to the AI-in-design-map field map. Use when Douglas says "process my LinkedIn inbox" or invokes /process-linkedin-inbox.
---

# Process LinkedIn inbox

This skill turns a folder of pasted LinkedIn posts into proposed edits for Douglas's field-mapping site at `C:/Users/dougl/My Drive (douglaspmcgowan@gmail.com)/UC Berkeley/Research/Claude Research Folder/ai-in-design-map/`.

## When to invoke

- User says "process my LinkedIn inbox"
- User says "/process-linkedin-inbox"
- User mentions newly pasted posts in `inbox/linkedin/`

## Inputs

Files at `ai-in-design-map/inbox/linkedin/*.md` (excluding `processed/` subfolder). Each file is unstructured — pasted post content, possibly with author + URL, possibly without.

## Workflow

### Step 1 — survey the inbox

```bash
ls "ai-in-design-map/inbox/linkedin/" | grep -v processed
```

If empty, tell Douglas there's nothing new and stop.

### Step 2 — read each file

For each file, read it whole. Don't skip ones without URLs.

### Step 3 — categorize each post into one of seven topic clusters

Map each post to **one primary** cluster (and optionally secondary):

1. **Text-to-CAD** — natural language → editable parametric CAD
2. **Generative / topology design** — Fusion Generative, ToffeeX, nTop, lattices
3. **CAD kernels &amp; formats as AI substrate** — OCCT, Parasolid, STEP, USD
4. **Simulation-AI** — FEA/CFD surrogates, neural operators, PINNs, FNO
5. **Manufacturing-knowledge AI** — DFM, tacit knowledge, mfg data, CAM AI
6. **Design theory + AI** — academic, human-AI collaboration in design
7. **Industrial-AI market thesis** — VC/operator commentary, American Dynamism

If a post fits none of these, flag it as "out of scope" and don't propose site edits.

### Step 4 — extract links

For each post, list every URL — papers, products, blogs, threads, GitHub repos, HuggingFace pages. Verify each URL with WebFetch if it's load-bearing for a proposed edit.

### Step 5 — propose site edits

For each in-scope post, decide one or more of:

- **schools/** — does this post add evidence for a specific school of thought? (e.g., a new paper supporting "Discourse-mining DFM" → diff to `site/schools/discourse-mining.html`'s reading list)
- **who.html** — does this post name a new researcher / lab / company / conference? (e.g., a new lab page → diff to `site/who.html`)
- **channels.html** — does this post name a new channel/source? (e.g., a new Substack → diff to `site/channels.html` Section A or `site/resources/newsletters.html`)
- **products/** — does this post name a new tool? (e.g., a new generative-CAD product → diff to the relevant `site/products/*.html`)
- **follow.html** — does this post name an active X/LinkedIn handle worth tracking? (e.g., a new founder → diff to the relevant cluster on `site/follow.html`)

For each proposed edit, output a unified-diff-style proposal — file path, location, proposed insertion. **Don't apply diffs without Douglas's say-so.**

### Step 6 — write the session report

Write `inbox/linkedin/processed/YYYY-MM-DD-report.md` with:

- Total posts processed
- Per-post: brief, primary cluster, links extracted, proposed edits (paths only)
- Out-of-scope posts (one-line summary each)

### Step 7 — wait for Douglas's review

Show Douglas the report + the diffs. Ask: "Apply all? Apply some? Re-categorize?" Apply only what he greenlights.

### Step 8 — archive

After diffs are applied (or rejected), move processed inbox files to `inbox/linkedin/processed/` so they don't get re-processed next run.

## Output format conventions

- Diffs use the same patterns as existing site pages (cat-card, reading-list, comp-list).
- Reading-list entries: `<li><a href="URL" target="_blank" rel="noopener">title</a> <span class="by">— author, date</span><span class="desc">one-line argument</span></li>`
- Cat-card additions: standard format from `topics/*.html`.

## Don't

- Don't apply diffs without Douglas's review
- Don't re-categorize posts already in `processed/`
- Don't over-fit: if a post is broadly about "AI" but doesn't add evidence to a specific school, mark it adjacent and skip
- Don't bloat reading lists past ~10 entries per school — propose a swap instead of an add when full
