---
name: overlap
description: "Given a NEW thing Douglas is considering (a tool, pattern, capability, library, or idea -- not necessarily code), scans across his ENTIRE harness (commands/skills, Agent Skills, hooks, memory files, CLAUDE.md/MAP.md/DELEGATE.md behavior rules, settings.json) using digest-then-compare (never raw-reads the whole corpus), scores overlap against what already exists, and for genuine gaps makes an explicit BUILD-NEW vs FOLD-INTO-EXISTING recommendation scored against named decision criteria (independent deployability, data/lifecycle sharing, change cadence, single-purpose fit, Rule of Three) -- not just a similarity percentage, which is where every comparable tool stops. Use when Douglas says 'does this overlap with anything I have', 'check for overlap', 'is X already in my harness', 'overlap check on X', 'should this be its own skill or folded into Y', or '/overlap X'."
---

# /overlap [new-thing]

Every comparable tool found in research stops at a similarity score. This one has to answer the harder
question underneath it: not just "is this redundant" but "if it's genuinely new, where does it belong."

## What this is NOT

- **Not `/recon`.** `/recon` maps an external landscape and helps Douglas decide what to do about a
  problem he already has — most of its topics aren't "compare this to what I own" at all. `/overlap` starts
  from the opposite direction: something specific is already on the table, and the question is whether it's
  redundant with the harness Douglas already has, not whether it's a good idea in the abstract.
- **Not `/ultraskill`.** `/ultraskill` researches an external landscape and BUILDS something new to fill a
  gap. `/overlap` is the check that should run BEFORE that decision — confirming there IS a gap, and that it
  isn't better served by extending something that already exists. `/ultraskill`'s own Step 0 should point
  here first if there's real doubt about whether the capability already exists in some form; treat this as
  upstream of ultra-skill, not a replacement for it.
- **Not `skill-build-pathways.html`/`skill-pathways.json`.** Those document KNOWN, already-decided skill
  sequences (Construct, Harden Tail). `/overlap` evaluates something NOT yet decided.
- **Not `/detective`.** `/detective` mines SESSION TRANSCRIPTS for behavioral patterns (dropped work,
  repeated asks). `/overlap` mines the HARNESS ITSELF — instructions, skills, hooks, memory — for capability
  redundancy. Different corpus entirely, though it borrows detective's digest-before-mining discipline
  directly (see Step 1).

## Procedure

### 0. Resolve the new thing from ARGUMENTS

Needs enough detail that a subagent with ZERO conversation context could act on it alone: what the new
thing actually does (not just its name), and whether Douglas is asking "does this exist" (pure detection) or
"where should this go" (detection + placement decision) or both (the default). If ARGUMENTS is a bare name
with no description and it isn't obvious from the conversation, ask what it does before proceeding — don't
guess at scope from a name alone.

### 0b. Deep mode — when the "new thing" is an external CORPUS, read its SOURCE (not its description)

The default flow compares the harness against a *described* new thing. When the new thing is a whole external
CORPUS rather than one capability — someone's entire skills repo, a plugin marketplace, another person's Claude
Code setup, a framework with many parts — a README- or inventory-level description is **not enough**, and
comparing against it will undercount the real deltas. A README says "a code-review skill"; the actual SKILL.md
says "two independent Standards/Spec sub-agents with a no-merge rule." The overlap verdict lives in that gap.

**Trigger deep mode** whenever the new thing has more than ~5 discrete components, or Douglas says "read each
one" / "deep." In deep mode, BEFORE Step 1's comparison: dispatch subagents to fetch and read the ACTUAL
SOURCE of each external component — clone the repo (`git clone --depth 1`), `gh api` the files, or fetch each
real source file — never a landing page, README, or third-party summary. One subagent can read several
components; each returns the real mechanism **quoted from source**, not a paraphrase. Then run Steps 1–5
comparing the harness against those source-level mechanisms. If a component's source can't be reached, say so
and mark that one comparison description-level-only, rather than silently treating a description as if it were
the source. (Added after a 2026-07 run compared descriptions instead of source and undercounted the real
deltas — the failure this mode exists to prevent.)

### 1. Digest the harness before comparing — never hand raw files to a finder agent

Same discipline as `/detective`'s Section 2, applied to a different corpus. Douglas's harness spans seven
real sources, each independently large enough to blow context if read raw:

| Layer | Path |
|---|---|
| Skills/commands | `~/.claude/commands/*.md` |
| Agent Skills (global) | `~/.claude/skills/*/SKILL.md` |
| **Agent Skills (PROJECT-scoped)** | **`<project-root>/.claude/skills/*/SKILL.md` and `<project-root>/.agents/skills/*/SKILL.md`** — the `npx skills add` convention installs here (real files under `.agents/skills/`, symlinked into `.claude/skills/`), NOT under `~/.claude/`. A glob of `~/.claude/` alone MISSES these entirely (confirmed 2026-07-14: the whole Leonxlnx **taste-skill** suite was wrongly reported "not installed" because only the global dirs were checked). Always check the CWD's project-root `.claude/skills/` + `.agents/skills/` too, and the live Skill-tool listing. |
| Hooks | `~/.claude/hooks/*.js` (+ matching `.test.js`) |
| Memory | `~/.claude/memory/*.md` + `MEMORY.md` index |
| Behavior rules | `~/.claude/CLAUDE.md`, `MAP.md`, `DELEGATE.md` |
| Permissions/wiring | `~/.claude/settings.json` (+ `.local.json`, per-project variants) |
| **Built-in Claude Code skills** | **NOT on disk under `~/.claude/` at all** — compiled into the Claude Code binary itself (confirmed this session: `verify`, `run`, `debug`, `simplify`, `code-review`, `security-review`, etc. have no source file anywhere under `~/.claude`). Check via the live Skill-tool listing shown in this session's own system reminders, `/help`, or by researching `code.claude.com/docs/en/skills` and `.../commands` directly — a glob/grep of `~/.claude/` alone WILL silently miss these (confirmed by live-testing this skill 2026-07-08: it missed `verify`/`run` entirely on the first real run because they weren't findable via file search). **Always check this layer explicitly, never assume the six file-based layers are exhaustive.** |

Not every check needs all seven — a new HOOK idea only needs hooks + memory + settings.json; a new SKILL
idea needs commands + skills + memory + CLAUDE.md + built-in skills (this last one especially, since a new
skill idea is exactly the kind of thing most likely to already exist as a built-in). Scope to the layers
actually relevant to what's being checked, say which ones were skipped and why. For each relevant layer,
extract only: name/id, one-line
description/purpose, and (for hooks/skills) the actual trigger condition — not full file contents. Cap total
digest size the same way detective.md does.

### 2. Score overlap — qualitative judgment anchored to a real reference point, not a computed formula

Compare the new thing's description against every digested item's description and judge overlap the way a
careful reviewer would: does this existing item do substantially the same job for substantially the same
reason. The "~30%" figure below is a CALIBRATION ANCHOR, not a number this skill computes precisely — Skills
Janitor's real tool runs actual Jaccard similarity as a script; an LLM doing this by reading descriptions is
approximating that judgment, not executing the formula. Use 30%-ish semantic overlap as roughly "this is
worth flagging," not as a threshold to justify with false decimal precision. A name collision without a real
description match is NOT overlap — check what it actually does, not what it's called. Report EVERY candidate
that clears the bar, not just the single strongest one — composite overlap across two or three different
existing pieces (each covering part of the new idea) is common and just as disqualifying as one item that
covers all of it (confirmed live-testing this skill 2026-07-08: a real check came back with 3 separate
overlapping artifacts, not one).

### 3. For genuine gaps — make the build-vs-fold-in call explicit, scored against named criteria

If nothing scores above threshold (or what does only partially covers it), don't stop at "no overlap found."
Score the fold-in-vs-build-new question against these, all with real precedent (see this skill's own
research; full citations in the 2026-07-08 CURRENT-TASK entry that built this):

- **Independent deployability** (Newman) — could the new capability be added, edited, or removed without
  touching the host's own file/logic? If yes, that's evidence FOR building it separately; if editing it
  always requires editing the host too, that's evidence FOR folding in.
- **Data/lifecycle sharing** — does it need its own state, or does it fundamentally read/write the same
  state as an existing piece? Shared state pulls toward folding in.
- **Change cadence** (Team Topologies) — would this need to evolve on a different rhythm than the thing
  it'd be bolted onto? A different cadence pulls toward separate.
- **Single-purpose fit** (Chrome Web Store's Single Purpose policy) — does the candidate host already have
  ONE describable purpose? Would folding the new thing in break that in one sentence? If the host's purpose
  can no longer be stated in one sentence after folding this in, that's a real cost, not a formality.
- **Rule of Three** (Fowler/Roberts) — is this the first or second time this exact shape has come up, or the
  third+? Don't extract a new abstraction/skill on the first occurrence; a single instance folded into
  something adjacent is usually right until a real third instance justifies pulling it out.

Weigh these explicitly, don't just default to one answer. State which criteria point which way and why the
overall call goes the direction it does — the goal is a defensible decision, not a coin flip dressed up in
jargon.

### 4. Verify at least one claim against live state, not just description text

Same discipline as `/detective`'s Section 4. If the overlap-check flags an EXISTING skill/hook as covering
the new idea, actually read that item's real file (not just its cached description) and confirm it really
does what its description claims before reporting "already covered" as settled — a stale or drifted
description is a real failure mode elsewhere in this harness this session (task-state-reminder.js's own
tracked-mirror drift was found and fixed this way).

### 5. Report

- **Verdict, stated plainly**: overlap found (name EVERY overlapping item found, not just the strongest one
  — composite overlap across 2-3 partial matches is common, see Step 2) / genuine gap, fold into [existing
  item] / genuine gap, build new / genuinely ambiguous, here's why and what would resolve it.
- **The scoring**, not just the verdict — which layers were checked, what scored above threshold and why it
  didn't fully cover the new thing, and which of the 5 decision criteria drove the fold-in-vs-build call.
- **If "build new"**: point at `/ultraskill` (Build Mode) as the next step, don't build it here.
- **If "fold in"**: name the exact host file/section and what would need to change — don't apply the edit
  here either unless Douglas separately asks; this skill's job is the recommendation, not the implementation.
- Full absolute path(s) of anything read, per the standing Files-list convention.

## What NOT to do

- Don't stop at a similarity score and call it done — the whole point of this skill over the tools that
  already exist (Skills Janitor, SkillCheck) is making the build-vs-fold-in call explicit, not just flagging
  redundancy.
- Don't manufacture a "genuine gap" finding to justify having run the check — if something already covers
  the new idea well, say so plainly and stop there.
- Don't apply any edit as part of this skill (see Step 5) — this is a recommendation tool, not a build tool.
- Don't read full raw files across all seven layers when the new thing only plausibly touches one or two of
  them — scope the digest to what's actually relevant (Step 1).

---

*Tracked copy: also save this file to `claude-global-config/commands/overlap.md` (per the skills-are-tracked
convention) after a NASA scrub.*
