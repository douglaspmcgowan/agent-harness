---
name: map-field
description: Map a domain or field from a corpus of newsletters, papers, or discourse into a structured "schools of thought" site. Use when the user says "map this field", "build a schools-of-thought site", "organize these newsletters into positions", "what are the competing views on X", or when starting a new field-map project. Distilled from the AI Schools of Thought Explorer build.
---

# /map-field [domain]

## Argument

The user names a domain or passes a corpus. Minimum useful input:

> "Map the AI-in-education space from my newsletter inbox"
> "Build a schools-of-thought map for computational creativity"

If they just say `/map-field` with no argument, go to Phase 1.

---

## Phase 1 — Scope the domain (skip if argument is clear)

Ask in one message:

1. **What is the domain?** (e.g., "AI agents", "design-for-manufacturing", "protein folding methods")
2. **What's the corpus?** Gmail newsletters? A folder of papers? A list of URLs? Pasted text?
3. **What's the output?** A site (multi-page HTML) or a document/report?
4. **How many schools do you expect?** (rough guess — fine to be wrong)
5. **Is this a new map or extending an existing one?** If extending: which site, what already exists?

---

## Phase 2 — Collect

**Source priority, highest signal first:**

1. Curated newsletters (Every, TLDR, Stratechery, Interconnects, domain-specific). Pre-filtered — cheap at breadth.
2. Individual substacks/blogs of practitioners the newsletters cite most. Follow citation trails.
3. Primary research / investor memos (a16z, Sequoia, Foundation Capital, domain labs).
4. Reddit/HN threads — the honest practitioner version that newsletters sanitize.

**How to extract:**

- **Gmail corpus:** Use the Gmail MCP connector. Search by sender + date range, NOT keyword —
  keyword searches miss "I didn't know to ask for this" articles.

  ```
  mcp__2d7d2974-...__search_threads(query="from:every.to after:2026-01-01")
  mcp__2d7d2974-...__get_thread(id=..., messageFormat: "FULL_CONTENT")
  ```

  For short-link newsletters (TLDR etc.): resolve the redirect URL, then WebFetch the actual article.
  The newsletter blurb is a teaser — fetch the real content.

- **Large volume (>20 emails/articles):** Dispatch parallel `general-purpose` subagents with date
  slices. Give each a structured return format, not prose:

  ```
  Return a table: | URL | Author | Date | One-sentence thesis | Mechanism | Stance (pro/skeptic/orthogonal) |
  ```

- **What to capture per article:** URL, author, date, one-sentence thesis, one-sentence mechanism,
  stance (pro / skeptic / orthogonal / orthogonal-complement).

**Amnesia prevention — write to disk immediately:**
After each collection batch, append to `research/source-log.md` in the project directory:

```
| [date] | [email/article ID or URL] | [author] | [one-line thesis] | [placed in school: X or "pending"] |
```

DO NOT let source placement live only in subagent transient context — it will be lost on compaction.

---

## Phase 3 — Categorize

**Rule of three.** An argument becomes a "school" only when ≥3 independent voices make it.

- Fewer than 3 = a voice, not a school. Put in `pending/` and revisit.
- More than ~6 voices in one school = too broad; split it.

**Name the school by its thesis, not its author or publication.**

- ✓ "Folder-as-agent" — survives if the originating newsletter folds
- ✗ "The Every thesis" — dies with Every

**Find the live disagreements.** Schools matter because they conflict.
For each candidate school, explicitly record in `research/schools-draft.md`:

- The counter-position: which other school disagrees?
- The shared premise: what do they agree on even while disagreeing?
- The companion: which school sits adjacent and reinforces this one?

**Two-level structure:**

- **Topics** (stable containers, 4–8 total): coarse categories that don't change often
- **Schools** (live inside topics, can be added/retired): the actual positions

Topic examples for AI field: "How AI works", "How AI changes work", "How to deploy AI", "AI safety"

**Parking lot:** Single-voice ideas go to `research/parking-lot.md`. Revisit every time ≥3 voices accumulate on a pending idea.

---

## Phase 4 — Build the site

**Three-level hierarchy.** Each level has exactly one job:

```
Home
└── Topic (why these schools fight each other — card grid + intro)
    └── School (the synthesis — one essay, inline citations, reading list)
```

**Synth pattern, not catalog pattern.** The school page is a flowing essay that weaves sources
together with inline `<a>` tags. Do NOT give every article its own card — the catalog pattern
reads as a bibliography and kills the argument. One essay per school, one argument per essay.

**Reading list format** (under the synth essay):

```html
<ul class="reading-list">
  <li>
    <a href="URL">Title</a> <span class="by">— Author</span>
    <span class="desc">What THIS piece contributes (not what it's about)</span>
  </li>
</ul>
```

The `desc` should say _"argues X from angle Y"_, not _"covers topic Z"_.

**Reference implementation:** `ai-schools-of-thought-explorer/` in the Claude Research Folder.
Read its `index.html` (or main server file) before writing any school pages.

**Stack:** shared CSS, static HTML, no build step. One person should be able to edit a single
file and refresh. Don't introduce a framework until the site has >40 schools.

**Topic page structure:**

- Intro paragraph: what unifies this topic and why the schools disagree here
- Card grid linking to each school
- "Live tension" callout: which two schools are most directly opposed right now?

**School page structure:**

1. School name + one-sentence thesis
2. Core claim (the thing it's staking out)
3. Why it's right (steelman, citing 2–3 sources)
4. Where it's weak (the honest objection)
5. Who holds this view (2–3 named voices)
6. Reading list

---

## Phase 5 — Maintain and extend

**Adding a new school:**

1. Check parking lot — has it accumulated ≥3 voices?
2. Add it to `schools-draft.md` with counter/companion/shared-premise filled in
3. Write the school page
4. Add its card to the topic page
5. Update any opposing school pages that now have a named counter-position

**Retiring a school:**

- Don't delete — mark as `status: dormant` with a note on why (e.g., "consensus absorbed into X")
- Keep the page but add a banner: "This position has largely been absorbed into [school]"

**Biweekly refresh candidate:** If this map needs to stay current with fast-moving discourse
(e.g., AI news), offer to schedule a remote agent to run Phase 2 collect → Phase 3 categorize
and flag new schools or updates. Use `/schedule` for the routine.

---

## Source log format

Maintain `research/source-log.md` throughout. Format:

```markdown
## [YYYY-MM-DD] Batch [N]

| ID/URL | Author | Date | Thesis | Mechanism | School placed             |
| ------ | ------ | ---- | ------ | --------- | ------------------------- |
| url    | Name   | date | ...    | ...       | "AI-as-tool" or "pending" |
```

This is the key anti-amnesia mechanism. Context windows compact; disk doesn't.

---

## Output contract

When done, report:

1. Number of schools identified and which topics they map to
2. Schools in parking lot (not yet ≥3 voices)
3. Live tensions (top 2–3 disagreeing school pairs)
4. Path to the site and whether it deploys
5. Whether a biweekly refresh routine was offered
