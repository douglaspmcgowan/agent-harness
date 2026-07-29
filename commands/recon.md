---
name: recon
description: "Douglas's landscape-recon workflow for adopting or improving an approach, strategy, tool, or process. Broadly researches the field, maps the landscape, mirrors it against his ACTUAL current setup (config, skills, hooks, memory, vault, repo), compares the two, then — in babysit mode surfaces it and asks where to dive deep; in auto mode decides the highest-leverage moves and produces concrete paths forward. Use when Douglas says 'recon X', 'I want to adopt/improve X', 'what's the landscape for X', 'how does X compare to what I do', 'help me get better at X', or '/recon'."
---

# /recon [topic] [--auto | --babysit]

Reconnaissance before adoption. When Douglas is trying to take on or improve an approach/strategy/tool/problem, this maps the field, holds it up against what he already does, and hands him (or takes) the next move. It is the front half of a build — it ends at a decision, not a deliverable, unless run in auto mode.

## Argument

- **`topic`** — the approach/strategy/tool/problem he wants to adopt or improve. Examples:
  > "/recon making my codebase legible to agents"
  > "/recon loop engineering"
  > "I want to improve how I do cross-session memory — recon it"
  > "what's the landscape for evals, and how does it compare to what I do?"
- **mode flag** — `--auto` or `--babysit`. Optional. **Default: babysit.** If no flag, infer: phrasing like "just do it", "you decide", "set it up" → auto; "surface to me", "walk me through", "I'll tell you where to go" → babysit. When genuinely unclear, default to babysit and say so.

## The contract (four moves)

1. **Landscape** — research the field broadly.
2. **Mirror** — read and summarize what Douglas *actually* does today (no guessing).
3. **Compare** — strategy-by-strategy, with a Have / Partial / Gap verdict against his setup.
4. **Paths** — concrete forward options. In **babysit** the choice of where to go deep is his; in **auto** it's mine.

---

## Phase 0 — Frame (1–2 lines, then proceed)

State: what he's adopting/improving, why now, and the mode. If the topic is ambiguous AND babysit → ask ≤3 questions in one message. If auto → pick the most useful reading, state the assumption, proceed.

---

## Phase 1 — Landscape recon (research the field)

Run the `/deep-search` method (or invoke it): fan out queries, deepen iteratively. **Prefer human practitioner sources** — Reddit/HN, Simon Willison, Every.to, Mollick, Latent Space, Anthropic/OpenAI/tool engineering blogs, the actual tool docs. Cross-verify factual claims with ≥2 sources; mark **[single-source]** otherwise; hedge uncited numbers as "roughly." Honour the knowledge-cutoff rule — web-check anything that may have changed.

Identify **6–12 distinct approaches/strategies**. For each:
- **Name** · **What it is** (2–3 sentences) · **Best at** (1 line) · **Limitation / cost** (1 line) · **Who uses it / tooling** (1 line) · **Sources** (1–3 URLs)

If the breadth is large, dispatch a research subagent (or `/parallelize`) and synthesize — don't serialize a wide sweep.

**Sensitive / classified-work topics:** stay local, no open web. Tooling/personal topics: web allowed.

---

## Phase 2 — Mirror: what Douglas already does (READ, don't guess)

Before any comparison, read his actual setup for this topic and summarize it honestly, **citing files**. Source order:
1. Relevant `~/.claude/commands/*.md` and installed skills
2. `~/.claude/hooks/`, `settings.json`, `CLAUDE.md` / `CLAUDE-*.md`
3. `~/.claude/memory/` (MEMORY.md index first, then the relevant reference/feedback files)
4. The relevant Obsidian vault folder(s)
5. For a code topic: the repo's `CLAUDE.md` / `README` / `STATUS.md` / `CURRENT-TASK.md`

Output a short "here's what you do today" paragraph or list, each claim tied to a file. Never fabricate his current practice — if you can't find it, say so.

---

## Phase 3 — Compare (reuse the `/compare-options` table)

One row per strategy from Phase 1:

| Strategy | Best at | Uniquely offers | Can't do / weakest | You already have it? |
|----------|---------|-----------------|--------------------|----------------------|

The **last column is the whole point**: verdict **Have** / **Partial** / **Gap**, plus the file or skill that proves it (e.g. "Have — `~/.claude/memory/` + MEMORY.md index"; "Gap"). Be honest about Partials — that's usually where the leverage is.

---

## Phase 4 — Surface or decide (MODE GATE)

**Babysit (default):** present, in order — *What it is* → *Landscape* → *Comparison table* → a **dive-deep shortlist** of 3–5 candidates (the highest-leverage Gaps/Partials), one line each with the reason. Then **STOP and ask which to pursue.** Do **not** build anything. The point is to let Douglas steer.

Alongside the shortlist, **offer an options-comparison pass before committing** (Douglas often wants to weigh alternatives first). Surface it as an explicit choice: "want me to run `/compare-options` on the top N before we pick?" If he says yes, run the `/compare-options` flow on those candidates (its tradeoff table: best-at / uniquely-offers / can't-do / fit-for-Douglas), then return here to the steering question. This is the recon↔compare-options merge: recon maps the field; compare-options weighs the finalists; the pick stays his.

**Visual comparison (optional, often worth it for a field of tools).** Render a self-contained HTML comparison — one **card per option** with: key **metrics/metadata** chips (maturity/stars, local-vs-cloud, platform, fit-for-Douglas), an inline **figure/diagram** that shows what the option *is* (a small SVG — architecture, fan-out, board, graph), an **info** blurb, and a **when-to-use / when-not** line. Add a top search/filter. Reference build: `Claude/Engineer/coordination-tools-recon.html` (in the vault). Delegate the build to a subagent; verify it loads with 0 console errors. This is the at-a-glance way to eyeball a landscape; pair it with the comparison table for the detail.

**Auto:** pick the **1–3 highest-leverage moves yourself**, stating the selection criterion (e.g. "biggest gap × lowest cost × touches active workstream"). Then produce a concrete plan and proceed to build it, looping to a verifiable end. Report once at completion. "Build it" here means whatever the chosen move actually is — a hook tweak, a memory file, a config change, a habit — scoped to that move only. `/recon` never assumes the move is "build a new Claude Code skill"; most recon topics aren't.

**If the chosen move specifically IS building a new Claude Code skill/capability** (recognizable because the topic itself was "find/build me a tool that does X"), don't improvise that build inline — hand off to **`/skill-forge`**, the dedicated skill-synthesis command, rather than growing this one into two jobs. Recon's role stops at naming the move; `/skill-forge` owns researching, synthesizing, building, and testing it.

---

## Phase 5 — Paths forward (both modes)

End with **2–4 concrete paths**, each as: the move · the 5-minute first test to validate it · the cost/risk · which of his active workstreams it touches (his research, CAD/structural, and tooling work, or the Claude harness itself).

---

## Operating constraints

- **Read before comparing.** Never fabricate either a strategy's capabilities or Douglas's current setup. Cite the file or the URL behind every claim.
- **Source everything external.** "reportedly"/"roughly" for single-source or uncited numbers.
- **No antithesis framing** ("X, not Y"). State the positive claim.
- **Babysit builds nothing** — recon and surface only. **Auto** makes surgical changes only, traced to the chosen move.
- **Default to babysit** when the mode is unclear.
- Lean on existing skills rather than re-rolling: `/deep-search` for Phase 1, `/compare-options` for Phase 3 and the optional finalists-comparison in Phase 4, `/parallelize` for wide sweeps.
- **Platform filter:** Douglas is on **Windows**. A tool that isn't usable on Windows (Mac-only app, etc.) is not a real option for him — drop it from the options/comparison, or flag it clearly as "not Windows-usable." Verify platform support before recommending.
- **Deprecated filter:** anything deprecated, sunsetting, or superseded does NOT go in the options or the main comparison. Note it in a one-line "deprecated — skipped (use X instead)" aside, and move on.
- Per the **Briefs → Obsidian** rule, write the recon brief into the vault and give Douglas the path.

---

## Output contract

1. Frame + mode (Phase 0)
2. Landscape — list/table with sources (Phase 1)
3. Mirror — his current setup, each claim cited (Phase 2)
4. Comparison table with Have/Partial/Gap (Phase 3)
5. **Babysit:** dive-deep shortlist + the steering question. **Auto:** chosen moves + what was built (Phase 4)
6. Paths forward (Phase 5)
