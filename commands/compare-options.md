---
name: compare-options
description: "Douglas's recurring workflow: commission N concrete options for a tool, approach, or design choice, render them, then compare tradeoffs across what each does best, what each uniquely offers, and what each can't do. Use when the user says 'what are my options for X', 'compare these approaches', 'what's each best at', or 'what does each have that the others don't'."
---

# /compare-options [topic]

## Argument

The user names a tool category, approach, or decision space. Minimum useful input:

> "What are my options for building an explorable explanation?"
> "Compare these three deck themes"
> "What's each of these skills best at?"
> "Compare approaches for the knowledge-graph viz"

If they just say `/compare-options` with no argument, go to Phase 0.

---

## Phase 0 — Scope the decision (skip if argument is clear)

Ask in one message, at most 3 questions:

1. **What's the decision?** (e.g., "which explorable-explanation tool to use", "which deck theme to pick", "how to render the pipeline funnel")
2. **What are the candidate options?** (user may already have a list, or want me to generate them)
3. **What's the output format?** Side-by-side HTML comparison page, markdown table, or prose pick-and-explain?

If the user has already listed candidates, skip to Phase 1.

---

## Phase 1 — Fan out: build or characterize N concrete options

**Default: generate 3–5 options.** More than 5 → prune to strongest candidates first and say so.

For each option, document:

- **Name + source** (skill name + where to get it, or framework name + URL)
- **What it makes** — the artifact type (self-contained HTML, notebook, React component, PNG)
- **How it's invoked** — slash command, `npx`, library import, no-code UI
- **Complexity floor** — what's the simplest thing it can produce, and how much setup does that take?

**When the options are tools/skills (the most common case for Douglas):**

Read the skill file or WebFetch the README before characterizing it. Do not fabricate capabilities.
State the source: "per the README" or "per the skill file at `~/.claude/commands/<name>.md`."

**When the options are design variants (deck themes, layout approaches):**

Build them. Write N self-contained HTML files (`option-1-<label>.html`, `option-2-<label>.html`, …) into a working dir, each demonstrating the approach on the actual content. Take Playwright screenshots for proof.

**Anti-amnesia:** write `options-log.md` in the working dir immediately after fanning out — one row per option so compaction can't erase the set.

---

## Phase 2 — Compare: tradeoffs table

Build a markdown table with one row per option:

| Option | Best at | Uniquely offers | Can't do / weakest at | Fit for Douglas's work |
|--------|---------|-----------------|----------------------|------------------------|

**"Best at"** — the one thing this option does better than any of the others. Be specific: "D3 force-directed graphs with 7,000+ nodes" not "data visualization."

**"Uniquely offers"** — the capability that NONE of the other candidates have. If two options both have it, note that.

**"Can't do / weakest at"** — honest ceiling or failure mode. Don't skip this column.

**"Fit for Douglas's work"** — map to his actual domains, not hypotheticals:

- **IDETC paper / Tacit-DFM research** — pipeline funnel (23-field schema, 5,000→88 filter funnel), AC1 inter-rater stats, knowledge graph (7,864 nodes / 13,148 edges), worked example
- **AI for CAD / DFM** — process explainers, Fusion 360 / generative-design 3D, CAD-generation pipeline diagrams
- **example-service / Celedon** — training walkthroughs, staged pipeline visualizations, product demos
- **Agency kit / dpm-agent-kit** — hook/skill/memory system diagrams, interactive terminals, agent architecture explorables
- **Obsidian vault** — self-contained notes, canvas embeds, Dataview-adjacent interactive content
- **Symposium write-ups** — scroll-narrative explainers for conference audiences

---

## Phase 3 — What each has that the others don't

After the table, one paragraph per option:

**Option N (name).** The thing that makes this irreplaceable in the set: the capability, workflow property, or output type that you lose if you drop this option. If two options are genuinely redundant, say so and recommend dropping the weaker one.

This section is where "I already have GSAP from slides-ultra — does this add anything new?" gets answered honestly.

---

## Phase 4 — Pick and synthesis

End with:

1. **Douglas's situation:** which of his current active workstreams does this decision touch?
2. **My pick:** one option, named, with a one-sentence reason. If the answer is genuinely "it depends on the artifact," name two cases and a pick for each.
3. **What to try first:** the lowest-friction test — the single command or file to run to validate the pick in 5 minutes.

Do not give a ranked list of all options. One pick, two picks if truly context-dependent, no more.

---

## Operating constraints

- **Read before characterizing.** If a skill file or README exists locally, read it. WebSearch/WebFetch if it's remote. Never fabricate a capability.
- **Source every claim.** "Supports 7,000-node force graphs" needs a source or "reportedly" if unverified.
- **No antithesis framing** ("X, not Y"). State the positive claim.
- **Match the set to the decision.** If Douglas named 4 options and I think a 5th is clearly better, add it and say why — but don't silently inflate to 8.
- **Don't compress the table for brevity.** The whole point is comprehensive per-option detail. Four full rows beat two vague rows.
- **HTML comparison page (optional):** if Douglas wants a visual side-by-side, build `compare-<topic>.html` with one card per option matching his design: full outlines (no left-accent bars), font pairing, one dominant accent color. Row-hover only if cells genuinely correspond across columns. Read `~/.claude/memory/feedback_design_incidents.md` first.

---

## Output contract

When done, report:

1. How many options were characterized and from what sources
2. The tradeoff table (Phase 2)
3. The "uniquely offers" paragraph per option (Phase 3)
4. Your pick + what to try first (Phase 4)
5. Whether an HTML comparison page was built, and where it is
