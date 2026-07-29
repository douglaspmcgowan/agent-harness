---
name: build-graph-explorer
description: Build a knowledge-graph explorer SPA from a corpus of nodes and edges. Use when the user says "build a graph explorer", "make a knowledge map", "visualize my research corpus", "build something like the DFM explorer", or any task that involves rendering a force-directed graph with zoom levels (survey → cluster → detail). Reference implementation is dfm-graph-explorer/index.html (~5.6k lines, d3 v7, canvas + SVG hybrid).
---

# /build-graph-explorer [corpus description]

## Argument

The user names a corpus and what they want to explore. Minimum useful input:

> "Research papers on AI in design — nodes are papers/people/concepts, edges are citations and co-authorship"
> "Forum posts about manufacturing — nodes are discussion frames, edges are semantic similarity"

If they just say `/build-graph-explorer`, go to Phase 1.

---

## Phase 1 — Clarify corpus and graph model

Ask in one message:

1. **What are the nodes?** (papers, concepts, people, claims, posts, companies…)
2. **What are the edges?** (citations, semantic similarity, co-authorship, shared tags…)
3. **How many nodes do you expect?** (<500 / 500–5k / 5k–15k / >15k)
4. **What are the three zoom levels?** Every explorer needs:
   - L1: the full map (all nodes, clustered, overview)
   - L2: one cluster in detail (nodes + intra-cluster edges)
   - L3: one node deeply (full text, all edges, hop to neighbors)
5. **What is the clustering basis?** Topic modeling (BERTopic), manual categories, tags, embedding clusters?
6. **Do you have the data pipeline ready, or do you need to build it?**

---

## Phase 2 — Read the reference implementation

**Before writing any code**, read these two files in parallel:

```
Read: Claude Research Folder/dfm-graph-explorer/PLAYBOOK.md       ← architecture decisions
Read: Claude Research Folder/dfm-graph-explorer/index.html         ← canonical source (~5.6k lines)
```

> **Important:** The PLAYBOOK.md has some force-layout parameter values that have drifted from
> the live source. `index.html` is canonical for physics tuning — use those values, not the docs.

Key sections of `index.html` to internalize:

- Data loading and the `{frames, topics, edges}` contract (top of file)
- Three force layouts: `spiral` (default), `semantic`, `natural` — understand when each is used
- Canvas quadtree render path at L1 (fast, handles 4k+ nodes)
- SVG/DOM render path at L2/L3 (richer interaction, fewer nodes)
- Position cache key: `(layout, frames.length, first-8 frame ids joined)` — copy this pattern
- `forceCollide.strength(fn)` — read the comment about d3 v7 coercion (see errors table)

---

## Phase 3 — Define the data contract

Before building the pipeline, confirm the JSON shape:

```js
// graph_data.json
{
  frames: [
    {
      id: "unique-stable-id",
      text: "Short display label",
      full_text: "Full content for L3 detail view",
      topic_id: 3,          // -1 = outlier bucket (show as "Other", do not hide)
      metadata: {           // domain-specific extra fields shown in L3
        author: "...",
        year: 2024,
        url: "https://..."
      }
    }
  ],
  topics: [
    { id: 3, label: "Human-AI Interaction", color: "#5B6BBF", size: 42 }
  ],
  edges: [
    { source: "id-a", target: "id-b", weight: 0.72, type: "semantic" }
  ]
}
```

**Pre-threshold edges before export.** Don't export all O(n²) pairs — apply cosine threshold
(≥0.65 typically) and take top-k per node (k=10 is a good default). The SPA loads the full
file client-side; >4 MB gzipped causes perceptible load time.

---

## Phase 4 — Data pipeline

**If the user has a structured dataset** (CSV, JSONL, SQL): skip to Step 4.
**If the corpus is raw text** (papers, forum posts, emails): run the full pipeline.

```
raw corpus (text files / DB)
    │
    ▼ (1) Frame extraction
    frames.jsonl          ← LLM or regex extracts claim-like units; ~50–200 words each
    │
    ▼ (2) Embedding
    embeddings.jsonl      ← 1536-dim vectors via OpenAI text-embedding-3-small
    │
    ▼ (3) Topic modeling
    topics.csv            ← BERTopic clusters; label each cluster with LLM summary
    │
    ▼ (4) Edge construction
    edges.csv             ← cosine similarity ≥ 0.65, top-10 per node
                          ← also: structural edges (citation, co-author, explicit tag)
    │
    ▼ (5) Bundle
    graph_data.json       ← merge all above; pre-threshold; sort frames by topic_id
    │
    ▼ (6) SPA loads it
    index.html
```

Scripts to adapt from `ai-engineering-design-db/scripts/`:

- `consolidate.py` → frame extraction/dedup
- `embed.py` → embedding generation
- `extract-semantic-edges.py` → cosine edge construction
- `build-graph.py` → bundle into graph_data.json

---

## Phase 5 — Frontend scaffold

**Copy `dfm-graph-explorer/index.html` and make only these domain-specific changes:**

| What to change          | Where in the file                 | How                                                 |
| ----------------------- | --------------------------------- | --------------------------------------------------- |
| Data file path          | Top-level `fetch('...')` call     | Point to your `graph_data.json`                     |
| Node label field        | `frame.text` references           | Use your equivalent short-label field               |
| L3 detail fields        | Detail panel HTML template        | Show your domain metadata (author, year, url, etc.) |
| Topic colors            | `TOPIC_COLORS` or topic.color     | Assign per-cluster; use field-color palette pattern |
| Page title + header     | `<title>` and `<h1>`              | Domain name                                         |
| L1 cluster label logic  | `getClusterLabel()` or equivalent | Use `topic.label` from your topics.csv              |
| Search placeholder text | `#searchInput` placeholder        | Domain-appropriate hint                             |

**Do not change:**

- Force simulation parameters (use `index.html` values, not PLAYBOOK.md)
- Canvas render path logic
- Position cache key structure
- Quadtree hit detection
- L2/L3 transition animation timing
- The `topic_id === -1` outlier handling (always show "Other", never hide it)

---

## Phase 6 — Physics tuning (if needed)

Use the values from `index.html` §"simulation" as your baseline. Only tune if layout looks wrong.

**Spiral layout** (default L1): phyllotaxis positioning — `r = R_STEP * sqrt(i+1)`, `angle = i * 137.5°`. Controls cluster spread, not physics. Good starting point for any corpus.

**Semantic layout**: anchors topic centroids first (~50ms mini-sim), then runs full sim. Best when topics are well-separated in embedding space. Slower first render, cleaner result.

**Natural layout**: pure edge physics, no anchors. Produces tight hairball on dense graphs. Only use when edge structure is the point (citation networks, explicit taxonomies).

**Performance checkpoints:**

- <500 nodes: any layout, SVG OK at L1
- 500–5k nodes: spiral default, canvas at L1
- 5k–15k nodes: spiral only, consider pre-clustering large topics
- > 15k nodes: tile per cluster (`split_graph_data.py`); only load active cluster

---

## Phase 7 — Verify and deploy

```bash
# Local test
python -m http.server 8766
open http://localhost:8766

# Checks:
# - L1 renders without blank canvas (forceCollide bug — see errors table)
# - Clicking a cluster enters L2
# - Clicking a node enters L3 with full text visible
# - Search returns results and zooms to node
# - Back navigation works (browser history or in-app back button)
# - No console errors on 200+ node graphs

# Deploy
gh repo create [name] --public --source=. --push
npx vercel --yes --prod --name [name]
```

---

## Common errors

| Symptom                                      | Cause                                                                                        | Fix                                                                                                     |
| -------------------------------------------- | -------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Blank canvas, no error in console            | `forceCollide.strength(fn)` — d3 v7 coerces strength with `+value`; a function becomes `NaN` | Pass a number, not a function: `.strength(0.7)`                                                         |
| All nodes stack at origin on layout switch   | Position cache key mismatch                                                                  | Check cache key includes layout name + frame count + first-8 ids                                        |
| `forceLink` ignores edges, nodes drift apart | Edge `source`/`target` are strings but simulation expects object references                  | d3 mutates the edges array in place — check that you're not copying edges before passing to `forceLink` |
| Zoom reset on every filter change            | Canvas clear triggers a full re-init                                                         | Separate "update node visibility" from "reinitialize simulation"                                        |
| L2 cluster shows wrong nodes                 | `topic_id` indexing off by one                                                               | BERTopic ids start at -1 (outlier), so topic array offset by 1 — use id lookup, not array index         |
| Drag starts a pan instead of moving node     | Drag and zoom both use mouse down — conflict on canvas                                       | Default: disable node drag at L1; enable only at L2/L3 where SVG handles it                             |
| Graph loads but edges invisible              | Edge weight threshold too high for sparse graph                                              | Lower cosine threshold to 0.55; or add structural edges (explicit links)                                |
| Python embed script OOM on large corpus      | Embedding all at once                                                                        | Batch in groups of 500; append to `embeddings.jsonl` incrementally                                      |
| BERTopic produces all-outlier cluster (-1)   | Too few samples or wrong `min_cluster_size`                                                  | Use `min_cluster_size=5` for <1k frames; `min_cluster_size=15` for >5k                                  |
| Vercel 413 on large graph_data.json          | File >4.5 MB uncompressed                                                                    | Pre-threshold edges more aggressively; or tile per cluster                                              |

---

## Known gaps in the reference implementation (do not promise these work)

- **Drag-to-reposition nodes at L1** — shipped as a no-op; the drag/zoom conflict is not solved
- **Accessibility in canvas mode** — screen readers cannot access canvas; no ARIA live regions
- **Edge-reasoning overlay** (show LLM explanation for why two nodes are connected) — planned but not implemented in `index.html`
- **Incremental data updates** — pipeline assumes full offline rebuild; no live-update path

---

## Output contract

When done, report:

1. Node count, edge count, cluster count in the final `graph_data.json`
2. Which layout is default and why
3. Deploy URL
4. Any data pipeline steps that were skipped or need manual completion
5. Known gaps that apply to this specific build
