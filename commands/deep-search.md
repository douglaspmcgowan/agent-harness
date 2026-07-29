---
name: deep-search
description: Multi-step web research with query fan-out, iterative deepening, human-authored sources (Reddit, HN, practitioner blogs), and inline citations. Use when the user asks to "research X", "find everything about Y", "what do people think about Z", or any question needing 3+ sources or subjective judgment.
---

# /deep-search

> **Want the sources to filter, not a synthesized answer?** Use **`/sift`** instead — it reuses this
> fan-out (Phases 2–5) for breadth, then clusters the sources into categories, pulls a representative image
> per source, and lands them as image-bearing, live-filterable review cards in the Workbench rather than a
> prose report.

## Phase 1 — Clarify (skip if the query is already unambiguous)

- Ask 1–3 targeted clarifying questions: scope, recency requirements, depth, and what a "good answer" looks like.
- Do not browse until the user confirms or explicitly says "just go."

## Phase 2 — Plan (fan-out)

- Decompose the question into 5–10 independent sub-queries covering different angles, including at least one contrarian/skeptical angle and one "what would falsify this" angle.
- Write the sub-query list to the user before searching, as a one-line plan.
- Scale effort: simple fact = 1 search batch; comparison = 2–4 batches; complex research = 5+ batches.
- **If the output is a file/report**: Write a stub file at the target path NOW — section headers filled, content as `TODO`. Commit BEFORE any WebSearch. A stream-idle timeout during Phase 6 otherwise erases the whole run; an early stub plus incremental re-Writes survives it.

## Phase 3 — Search (start wide, parallel, PRIORITIZE HUMAN-AUTHORED SOURCES)

- Issue WebSearch calls for all sub-queries in a SINGLE message using parallel tool calls. Sequential calls = no parallelism.
- Start with short broad queries; narrow only after seeing what came back.
- Include the current year in time-sensitive queries.
- **Always include targeted searches for human-written content** — not just vendor docs:
  - `site:reddit.com` + topic (especially r/ClaudeAI, r/LocalLLaMA, r/singularity, and any topic-specific subreddits)
  - `site:news.ycombinator.com` + topic
  - Practitioner blogs: Simon Willison (simonwillison.net), Every.to, Ethan Mollick (oneusefulthing.org), Latent Space, Dan Shipper, Jesse Vincent (blog.fsck.com), HumanLayer, Addy Osmani, Anthropic/OpenAI engineering blogs
  - X/Twitter posts from credible practitioners
  - YouTube breakdowns from technical practitioners (not ad-driven review channels)
- **For subjective questions — reviews, comparisons, "which is better," "how do I," "what do people prefer" — human-written posts and comments from credible people are PRIMARY sources, not supporting evidence.** A thoughtful Reddit comment from an experienced user often contains more truth than a vendor landing page. Weight accordingly.

## Phase 4 — Read (fetch, evaluate, prefer primary + human)

- WebFetch the 5–10 most promising URLs in parallel. Prefer: primary sources, peer-reviewed papers, .gov/.edu, first-party engineering blogs, credible practitioner blogs, and high-signal Reddit/HN threads. De-prioritize: SEO listicles, AI-generated summary sites, content farms.
- If a WebFetch returns a cross-host redirect notice, re-fetch the new URL — it does NOT auto-follow.
- Assume ~100KB truncation; pass a focused extraction prompt when fetching long pages.

## Phase 5 — Assess gaps and iterate

- After each read pass, list: (a) claims confirmed by ≥2 independent sources, (b) claims from only 1 source (mark tentative), (c) open questions still unanswered.
- If (c) is non-empty AND under budget, generate NEW sub-queries targeting ONLY the gaps. Loop to Phase 3. Don't re-search covered ground.
- Stop when: every sub-question has ≥2 independent sources, OR 2 full loops done, OR user's scope is covered.
- After each loop, re-Write the stub file with the latest synthesis. Don't batch persistence to the end — stream-idle timeouts on long runs are real and silent.

## Phase 6 — Synthesize with inline citations

- Attach a URL to EACH factual claim inline — `[per source](url)` — not a bibliography at the end.
- Flag single-source claims explicitly: "single source, unverified: ..."
- Flag contradictions between sources explicitly; do not pick a winner silently.
- For subjective questions, quote human practitioners verbatim where possible — a real user's voice carries more signal than a paraphrase.
- Close with a "Sources" list grouped by type: primary / practitioner / community.

## Execution model — inline vs dispatch

- **Inline** (run in your own context): small fan-outs only — ≤8 WebSearch + ≤8 WebFetch, ≤1 iteration round. Fits in one API stream window.
- **Dispatch to a background `general-purpose` Agent** (`run_in_background: true`): use when >10 web calls, >1 iteration round, or when your main context needs to stay free for other work. Encode the /deep-search phases into the agent's brief; require incremental Writes.
- Sub-agents that time out can NOT be resumed — SendMessage is not universally available, and work not written to disk is lost. Write-early, write-often.

## Gotchas

- WebSearch is US-only; it runs inside a single API call.
- Long active runs (~15+ min of continuous tool use) can hit API stream-idle timeouts. The session dies without flushing output. Mitigations: smaller fan-outs, dispatch to background agent, always Write the report file incrementally.
- WebFetch is public URLs only — authenticated pages (Google Docs, private GitHub, Confluence) fail. Use `gh` CLI for GitHub.
- Results cached 15 min per URL; re-fetches within that window are free.
- Cross-host redirects are NOT auto-followed — re-fetch the new URL.
- When the user asks about a product/feature, always search before claiming it doesn't exist.
