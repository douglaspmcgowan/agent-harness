---
name: task
description: "Prompt-intake triage for Douglas's giant multi-intent prompts. Takes a long, messy prompt that mixes tasks, questions, offhand comments, 'look into X' investigations, decisions, and things he's ruled out — and decomposes it into typed components (TASK / QUESTION / INVESTIGATE / DECISION-NEEDED / COMMENT / OUT-OF-SCOPE), tags each actionable one with a parallelization class and a GEN/API-key-handoff eligibility, builds a dependency-ordered plan, and surfaces only the genuinely sharp clarifying/wayfinding questions — then seeds a WORK_QUEUE and hands specific clusters to /parallelize (3+ independent) or /design (a whole-feature design problem). It TRIAGES; it does not fan out workers (that's /parallelize) or design a product (that's /design). Use when Douglas says 'break this prompt down', 'triage this', 'what are all the things I asked for', 'plan this out', 'sort out everything in this message', 'what did I actually ask', or '/task'."
---

# /task [prompt or reference] [--collaborate|--delegate]

Douglas writes long prompts that carry many things at once — real tasks, half-formed questions, an aside or
two, a "look into X," a fork he hasn't decided, and something he's explicitly ruled out — all in one block. A
normal read tends to latch onto the first task and quietly drop the rest. This command does the opposite: it
accounts for **every** clause, names what KIND each one is, works out what has to happen before what, and asks
only the questions that are actually sharp — so nothing he said gets silently lost and the work starts in the
right order.

## What this is NOT

- **Not `/parallelize`.** `/parallelize` takes an already-legible multi-part task and classifies, drafts
  dispatch packets, and fans out workers. `/task` is upstream of it: it turns a raw, mixed-intent prompt into
  the typed, ordered breakdown that `/parallelize` then consumes. `/task` tags which components *could* run in
  parallel; it never drafts dispatch packets or spawns agents. When `/task` finds 3+ independent TASK
  components, it HANDS OFF to `/parallelize` — it does not do the fan-out itself.
- **Not `/design`.** `/design` presumes intent is already singular ("build this app") and owns the whole
  design arc. `/task` runs before that: it isolates intents from a messy prompt. If one of the components it
  isolates turns out to be a whole-feature design problem, `/task` hands that cluster to `/design` — it does
  not design anything itself.
- **Not `superpowers:brainstorming`.** Brainstorming explores intent and requirements for ONE creative task
  before building it. `/task` operates one level up — sorting a prompt that may contain several tasks, several
  questions, and several asides — and decides which fragments even warrant brainstorming. When a single
  isolated TASK is genuinely creative/underspecified, `/task` routes it to brainstorming; it doesn't replace it.
- **Not `/recon`.** `/recon` researches an external landscape to help Douglas decide a direction. `/task`
  looks only at the prompt in front of it and Douglas's own context — no landscape survey.
- **Not `wayfinder`.** `wayfinder` charts a LARGE, multi-session effort as a fog-of-war decision-map and
  resolves one decision ticket per session over time. `/task` triages ONE prompt in ONE pass into a flat
  ordered breakdown. They compose: for a big decision-heavy prompt, `/task` escalates TO wayfinder (Step 6) —
  its DECISION-NEEDED components become wayfinder's decision tickets. For an ordinary multi-task prompt, `/task`
  alone (flat queue) is right and wayfinder would be overkill.
- **Not the volatile Task board (`TaskCreate`/`TaskList`).** That in-session board is scratch memory. `/task`'s
  durable output is a seeded `WORK_QUEUE.md` (the real system of record per CLAUDE.md), not the volatile board.

## Steps

### Step 0 — Resolve what's being triaged and the mode

The input is normally **the giant prompt in the current turn** (Douglas invokes `/task` inside or right after
the messy message). It can also be a prompt he pastes or points at. If it's genuinely unclear which text to
triage, ask — otherwise take the current message.

Modes (default `--collaborate`):
- **`--collaborate`** — batch every DECISION-NEEDED and sharp clarifying question into ONE `AskUserQuestion`
  before proceeding (per `feedback_use_askuserquestion.md` and CLAUDE.md's "batch 1-3 ambiguities into ONE
  message" rule). Never ping-pong.
- **`--delegate`** — resolve each DECISION-NEEDED by stating an assumption, marked `ASSUMED:`, and proceed;
  surface only ambiguities that would waste >10 min if guessed wrong (his standing autonomy rule outranks the
  mode).

### Step 1 — GATE: does this prompt even need triage? (decomposition-necessity)

Before decomposing anything, judge whether the prompt is actually multi-intent. A single clear ask with no
asides ("fix the failing test in X") does NOT need this machinery — say so plainly and route straight to doing
it (or to the one right skill). Only proceed when the prompt genuinely carries multiple distinct intents,
mixed types, or buried questions/asides. (Same gate discipline as `/design` Step 2 and `/hone` Step 2 — refuse
to over-process a simple request. Sourced: HM-RAG decomposition-necessity gate, arxiv 2504.12330.)

### Step 1b — NO-BIG-PROMPT route: the completeness sweep

When the gate finds **no substantial multi-intent prompt to digest** — Douglas fires `/task` with an empty or
tiny argument, or a bare "did I miss anything?", "are we caught up?", "what's still open?" — do NOT sit idle
and do NOT invent a triage. **Route to a completeness sweep** instead:

1. Dispatch ONE cheap subagent (`model: 'haiku'`, or `sonnet` `effort:'low'` if the transcript is long) whose
   whole job is to read **only the user messages** from the recent transcript (the last day, or the last few
   hours if that is the natural session boundary) and list **every concrete thing Douglas asked for** — task,
   deliverable, or fix — with, for each, a one-line verdict: `DONE` / `PARTIAL` / `NOT DONE` / `UNCLEAR`, plus
   the evidence it used (a later "that's fine", a file that exists, a commit). Reading only user turns keeps it
   cheap and dodges the trap of grading my own completion claims against my own prose.
   - Transcript source: the session JSONL under `~/.claude/projects/<cwd-slug>/*.jsonl` (filter to
     `role:"user"` / `type:"user"` lines), or the path named in the current session's summary block. Hand the
     subagent the path and the time window; have it return structured rows, not a wall of text.
2. Cross-check the returned list against the live `WORK_QUEUE.md` — anything the sweep marks NOT DONE / PARTIAL
   that is missing from the queue gets **added** as a `- [ ]` line; anything the queue calls done that the
   sweep disputes gets flagged `[?]` for Douglas.
3. Report the sweep as a short table (ask → verdict → evidence), lead with the NOT-DONE / PARTIAL rows, and
   seed/patch the queue. This is the durable answer to "this has happened a number of times" — a mechanical
   re-derivation of the ask-list from the source of truth (his own words), not my memory of what I did.

This route exists because the failure mode is asymmetric: a dropped task is invisible unless something goes
back to the raw asks and re-checks them. `/task` with no new prompt IS that recheck.

### Step 2 — Decompose into typed components (every clause gets exactly one tag)

Walk the prompt clause by clause. Tag each fragment as exactly one of six types — nothing gets dropped, and
nothing gets two tags:

- **TASK** — an imperative with a concrete deliverable ("build X", "fix Y", "sync Z"). → becomes a WORK_QUEUE
  `- [ ]` line.
- **QUESTION** — answerable now from existing knowledge or the files at hand. → answer inline, no queue entry.
- **INVESTIGATE** — needs reading/research before an answer or decision can exist. → AFK-dispatchable (a
  subagent can resolve it without Douglas). (= wayfinder's *research* ticket type.)
- **DECISION-NEEDED** — a fork where Douglas's judgment picks the branch (not research). → HITL; surfaced via
  AskUserQuestion (collaborate) or resolved as `ASSUMED:` (delegate). (= wayfinder's *grilling* ticket +
  `/design`'s `[NEEDS CLARIFICATION]`.)
- **COMMENT / ASIDE** — an offhand remark, vent, or context with no action or answer required. → one
  acknowledgment line, no ticket, no queue entry. (This is the type unique to Douglas's real prompt shape.)
- **OUT-OF-SCOPE / NON-GOAL** — something he explicitly ruled out. → one acknowledgment line; never scheduled,
  never revisited unless he redraws scope. (= wayfinder's "out of scope is a scoping act, not a step on the
  route"; `/design`'s Non-goals.)

When a clause is ambiguous between two types, default to the more action-bearing one (TASK > QUESTION >
COMMENT) — Douglas's "proceed, don't ask" autonomy rule. Answer every QUESTION inline **at the top of the
report**, before task narration (CLAUDE.md's surface-questions rule).

**Coverage re-pass (mechanical, before emitting anything).** "Nothing gets dropped" is a claim; check it.
After tagging, re-read the RAW prompt top to bottom a second time and map every sentence/clause to a component
by number. The clause count and the component count must reconcile; any orphan sentence gets tagged on the spot
or flagged in the report as UNMAPPED (never silently absorbed into a neighbor). The first pass latches onto
salient asks — the second pass over the original text is what catches the buried one. (Sourced: point-by-point
coverage grading in acceptance-criteria eval work; the independent-count handshake in arxiv 2606.18519.)

### Step 3 — Tag each actionable component: parallelization class + GEN eligibility

For every **TASK** and **INVESTIGATE** component:

**Parallelization class** (reuse `/parallelize` step 2's three-way split verbatim — don't re-derive):
- **INDEPENDENT** — no shared files, no data dependency → parallel-worker candidate.
- **DEPENDS-ON <component>** — needs another component's output first → sequential.
- **SHARES-WRITE-TARGET <component>** — writes the same file as another → must merge into one worker.

First-pass file-disjointness can be judged from the prompt alone: components naming different paths/subsystems
are likely disjoint; different verbs on the same noun ("look into X" + "fix X") are the SAME target, not
disjoint. Confirm against real paths only when a component is about to be queued as a TASK.

**QUICK (the two-minute rule, from GTD's Clarify step).** A TASK resolvable in roughly two minutes of main-
session work — one command, one small edit, one lookup — gets the extra tag `QUICK`. Managing a queue entry
for it costs more than doing it; the orchestrator should knock QUICK items out inline immediately after the
triage report, before any dispatch machinery, and they never go to `/parallelize`. They still get queue lines
(so the keep-going loop sees them), placed first among tasks. `/task` itself still only tags — the read-only
constraint holds.

**GEN / API-key-handoff eligibility** (the two-gate AND-test from `DELEGATE.md`): tag a component `GEN-eligible`
only if BOTH hold — (1) it's NASA/work content (not personal), AND (2) it needs no live web (no WebSearch/
WebFetch tool; a one-off `curl` of a known URL doesn't disqualify it). Anything needing live web, or personal
in nature, or needing line-by-line judgment, stays in the main session. `/task` only *tags* eligibility — it
does not invoke GEN (that's the orchestrator's call, and per DELEGATE the spawned agent's `model` is set
explicitly, never left unset).

### Step 4 — Order the work (dependency-aware)

Build a small dependency edge list (X depends on Y if X's action reads or needs Y's output — a DECISION-NEEDED
gating a downstream TASK, an INVESTIGATE feeding a TASK's parameters). Then order:

1. **DECISION-NEEDED + sharp clarifying questions first** — cheapest to resolve, and they unblock everything.
2. **QUICK TASKs** — two-minute items, done inline by the orchestrator right after the report.
3. **INVESTIGATE next** — may feed decisions or task parameters; AFK-dispatchable in parallel.
4. **Independent TASKs, fanned wide** — the `/parallelize` handoff candidates.
5. **Dependent TASKs, in dependency order.**
6. **COMMENT / OUT-OF-SCOPE** — acknowledged, never scheduled.

(Topological ordering over the edge list: seed with zero-dependency components, execute, decrement dependents,
repeat. Sourced: BMW Agents / task-DAG planning; Anthropic "Building Effective Agents" orchestrator-triage.)

### Step 5 — Surface only the SHARP wayfinding questions

Apply wayfinder's sharpness test as the bar for promoting an aside into a real question: *"whether you can
state the question precisely now — not whether you can answer it now."* Ticket it when the question is already
sharp (even if blocked); leave it as an unresolved note when you can't yet phrase it that sharply. Then:
- **`--collaborate`**: batch all DECISION-NEEDED + sharp clarifying questions into ONE `AskUserQuestion`.
- **`--delegate`**: resolve each as `ASSUMED: <assumption>` and proceed, surfacing only the >10-min-if-wrong
  ones.

Do not manufacture questions to look thorough — a clean prompt with no real forks yields no questions.

**The asymmetry runs the other way, though — guard the under-surfacing side harder.** The documented dominant
failure of models here is silent commitment: they *recognize* a fork and then resolve it to one interpretation
without ever showing it, rather than over-asking. (Sourced: "Knowing but Not Showing", arxiv 2605.25284 — LLMs
detect ambiguity yet default to a single answer; "Ask or Assume?", arxiv 2603.26233 — decoupling
underspecification-detection from execution is what restores calibration, exactly the read-only-triage split
`/task` already makes.) So a fork you recognized is never allowed to vanish into a chosen branch: if it is
sharp, ticket it; if it is not yet phrasable sharply, it becomes a **visible unresolved note** in the report,
carried as a default that is still under review. In `--delegate`, every resolution is written as its
own listed `ASSUMED:` line for that reason, so the assumption stays on the surface where Douglas can read it
and flip it.

### Step 6 — Emit the breakdown, seed the queue, name the handoffs

Produce (report format below), then:
- **Seed `WORK_QUEUE`** (the session's real queue per CLAUDE.md) with one `- [ ]` per TASK, in the Step-4
  order, carrying the parallelization + GEN + QUICK tags inline **and a `done when: <observable check>` on
  every line** — a file that exists, a test that passes, a command whose output shows X. Untestable adverbs
  ("properly", "gracefully", "cleanly") are banned in a done-when; if no observable check can be phrased, the
  component is underspecified — send it back to DECISION-NEEDED rather than queue it vague. The done-when is
  what lets the keep-going loop (and a resumed session) flip `[ ]`→`[x]` on evidence; without it, items get
  marked done from the worker's own completion prose — the documented premature-done failure. (Sourced:
  verification-aware planning,
  arxiv 2510.17109; agent-verifiable acceptance-criteria practice.) This satisfies the standing "seed the
  queue first" rule for the multi-step work the prompt just created.
- **Name the handoffs explicitly**: 3+ INDEPENDENT TASKs → recommend `/parallelize`; a TASK cluster that's a
  whole-feature design problem → recommend `/design`; a single creative/underspecified TASK → `brainstorming`.
  `/task` recommends and stops at the seam; it does not execute the handoff unless Douglas says go.
- **Optional wayfinder escalation (for LARGE, multi-session, decision-heavy prompts).** When the triage
  reveals the work is bigger than one session can hold AND turns on several unresolved DECISION-NEEDED forks
  (not just a handful of independent tasks), a flat `WORK_QUEUE` undersells it — offer to hand off to the
  `wayfinder` skill instead, which charts the work as a fog-of-war decision-map (Destination / Decisions-so-far
  / Not-yet-specified / Out-of-scope) and resolves one decision ticket per session. The mapping is natural and
  already built: `/task`'s **DECISION-NEEDED** components become wayfinder **decision tickets** (its `[»]`
  lines), **INVESTIGATE** components become **research tickets**, **OUT-OF-SCOPE** components become the map's
  **Out of scope** section, and anything too vague to phrase sharply goes to **Not yet specified** (the same
  fog-vs-ticket sharpness test both use). Small or single-session prompts stay on the flat queue — do not
  stand up a wayfinder map for a handful of tasks (that's the ceremony wayfinder itself warns against).

## Report format

Answer every QUESTION first (top of message), then:

```
TRIAGE — <N> components from the prompt (every clause accounted for)

TASKS (queued):
  [order] <task> · <INDEPENDENT|DEPENDS-ON x|SHARES-WRITE x> · <GEN-eligible|main-session> · [QUICK] · done when: <check>
INVESTIGATE:
  <item> · AFK (subagent-resolvable)
DECISIONS NEEDED:
  <fork> · options: A / B · resolves when: <what settles it>
QUESTIONS (answered above):
  <q> → <one-line pointer to the answer>
ASIDES (acknowledged, no action):
  <comment>
OUT OF SCOPE (ruled out, not scheduled):
  <item>

ORDER: <the dependency-ordered plan, one line>
HANDOFFS: <e.g. "TASKs 2/4/5 independent → /parallelize; TASK 6 is a design problem → /design">
QUEUE: seeded <path to WORK_QUEUE>
```

Nothing from the prompt may be silently omitted — if a clause doesn't fit a type, say so and ask rather than
dropping it. The `<N> components` count in the header must match what the Step-2 coverage re-pass reconciled;
any UNMAPPED clause appears as its own line.

## Safety constraints

- **Read-only triage.** The one write is seeding `WORK_QUEUE` (per the task-state convention). No other file
  edits, no commits, no agent dispatch — `/task` plans; the handoffs execute.
- Never run with elevated/bypass permissions.
- GEN eligibility is only a *tag*; actually routing a component to GEN is the orchestrator's separate decision
  under `DELEGATE.md` (and never leaves an Agent `model` param unset on a GEN-keyed session).
- No decision is resolved by guessing in `--collaborate`; no >10-min-if-wrong ambiguity is buried in
  `--delegate`.

## Final report — honest register

Report what was triaged, not a promise the plan is optimal. Say plainly: every clause was tagged (or which
one couldn't be and needs Douglas), which questions were answered vs left open, and which handoffs are
recommended vs done. Banned: claiming the decomposition is "complete" or "the only correct one" — a triage is
a reading of the prompt, and Douglas can retag any component.

---

*Tracked copy: also save this file to `claude-global-config/commands/task.md` (per the skills-are-tracked
convention) after a NASA scrub.*
