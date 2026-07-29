---
name: trainer
description: "Skill track-record miner. Given ONE target skill (e.g. /hone), looks back at EVERY invocation since the skill was created, mines the session transcripts for how satisfied Douglas actually was each time — clean accept, corrective feedback, re-run/re-prompt, frustration, or a hard failure — attributes each signal to the skill (with an explicit 'ambiguous' bucket where the transcript genuinely can't disambiguate), aggregates a per-skill verdict with a before/after trend and the top recurring corrective themes, and hands the result to /ultraskill Improve Mode as evidence-grounded gap input. It never edits the skill file itself — it produces the track record; Improve Mode applies fixes. Use when Douglas says 'how is the X skill doing', 'review the X skill's track record', 'train the X skill', 'is X actually working', 'mine my uses of X', 'what feedback did I give on X', or '/trainer X'."
---

# /trainer <skill-name>

A skill ships and then just runs — and whether it's actually serving Douglas or quietly annoying him lives
only in the transcripts, scattered across every session it ever ran in. This command reads that record for one
named skill: every time it ran since it was built, did Douglas accept the result, correct it, re-run it, get
visibly frustrated, or hit a hard failure? It turns that scatter into an honest, evidence-quoted track record
and a short list of recurring failures — the exact input `/ultraskill` Improve Mode needs to actually fix the
skill, grounded in how it has really failed rather than in guesses.

## What this is NOT

- **Not `/detective`.** `/detective` mines transcripts for **Claude's own behavioral misses across ALL
  sessions** (dropped work, repeated asks, automatable manual steps) — it is not skill-scoped and produces a
  general forensic report. `/trainer` is narrowly scoped to **ONE named skill's satisfaction track record**,
  with a fixed accept/corrective/rerun/frustration/hard-fail taxonomy feeding a specific downstream consumer.
  `/trainer` reuses detective's *digest-before-mining* discipline; it does not reuse its topic-search semantics.
- **Not `/historian`.** `/historian` reads the build-log's **already-structured event data** (grouped commits,
  daily-report prose) and never opens raw session transcripts. `/trainer` does the opposite — it reads the raw
  session JSONLs directly, because there is no structured "skill satisfaction" layer yet; `/trainer` is the
  thing that would produce one.
- **Not `/ultraskill` Improve Mode.** Improve Mode's question is "how do OTHER practitioners solve this
  problem" (external landscape) and it EDITS the skill file. `/trainer`'s question is "how has Douglas himself
  experienced THIS skill in practice" (internal usage), and it edits nothing — it hands Improve Mode a
  pre-filled, evidence-grounded gap list. Complementary lenses on the same downstream action, not overlapping.
- **Not `/daily-activity`.** One day's raw signal vs. a skill's whole lifetime. No real overlap.

## Steps

### Step 0 — Resolve the target skill and its "since" bound

Read the target skill's own file first (`~/.claude/commands/<name>.md` or the relevant `skills/<name>/SKILL.md`)
so its current design is in view — a track record is only useful against what the skill claims to do. Then fix
the **since-creation window**:
- **Robust primary: the earliest invocation found in the corpus** (Step 1's grep). This always works when
  there's a track record to mine, and it's the honest bound — a skill's real history starts when it was first
  used, not when its file was authored.
- **Refinement (use only when it actually returns a date):** `git log --diff-filter=A --format=%ai --
  commands/<name>.md` in `claude-global-config/`. **Verified 2026-07-14 this is frequently empty** — the
  tracked repo syncs files into the working tree/index but many are staged-and-never-committed (e.g. `hone.md`
  is tracked yet absent from HEAD, so `git log` returns nothing). File mtime is also unreliable (Improve-Mode
  edits reset it). So treat git as a nice-to-have that sharpens the bound when a commit date exists, never the
  thing the window depends on. When neither the corpus nor git gives a confident start, say plainly the true
  creation date is unconfirmed.

### Step 1 — GATE: locate invocations, then check data sufficiency

Locate every invocation across the transcript corpus. Two roots of truth, **both** forms grepped (a skill is
invoked as a slash command AND via the Skill tool):
- Slash form: a `type: user` event whose content contains `<command-name>/<name></command-name>`.
- Skill-tool form: a `type: assistant` `tool_use` block with `name == "Skill"` and `input.skill == "<name>"`
  (JSON-parse to avoid substring collisions like `hone` inside `phone`, and namespaced `plugin:<name>`).

Search the same project roots `/daily-activity` scans (`C:\Users\dmcgowa2\.claude\projects\<slug>\*.jsonl` for
each working-dir slug, plus `<session>\subagents\agent-*.jsonl`); if a new project root exists, include it and
say so — these slugs drift as folders get renamed.

**Then gate on data sufficiency** (same mandatory pattern as `/hone` Step 2, `/probe` Step 2, `/historian`
Step 2): if the skill has fewer than ~3 invocations total, or fewer than 2 with any non-accept signal, say so
plainly and STOP — "not enough track record yet" is an honest outcome, not a forced verdict manufactured from
noise.

### Step 2 — Digest before mining (never raw-read a transcript into a finder's context)

Per session that contains an invocation, stream-extract ONLY: the invocation event(s), and the **adjacency
window** — the human turn(s) immediately following the skill's final report, plus the skill's own final report
text. Cap per-session extraction; keep the total digest small (detective's discipline). Do not pull whole
sessions into context.

### Step 3 — Mechanical signal pre-tag (deterministic first), then judgment

Establish the countable signal before any LLM judgment (historian's deterministic-first / narrative-second
split). Pre-tag each invocation's adjacency window mechanically where possible:
- **CORRECTIVE** lexical openers: "no", "not X", "actually", "that's wrong", "you missed", "should have", "do
  it like". (The error-correction opener is the single strongest lexical marker across the sources.)
- **RE-RUN**: a second `<command-name>/<name>` or Skill call on the same target within a close window. (Literal
  re-invocation is mechanical; a *rephrased* re-ask needs the Step-4 judgment pass — rephrasing is the
  strongest implicit-dissatisfaction signal per the research, so don't miss it by only grepping.)
- **FRUSTRATION** markers: curt 1–3-word replies right after a multi-paragraph completion report, "why did
  you", "you keep", "still not", "again?", "I already said", repeated caps/exclamation, or a mid-tool-use
  interrupt (a `queue-operation` event landing inside the skill's tool block — inferred from JSONL shape,
  validate before relying on it).
- **HARD-FAIL**: a `hook_blocking_error`/`hook_non_blocking_error` attachment inside the skill's tool calls, a
  non-zero exit in a tool_result the skill issued, or the skill's final report contradicted by a later Douglas
  message ("that file doesn't exist", "not what I asked") — the overclaim-caught case
  (`feedback_verification_discipline.md`).
- **ACCEPT (clean)**: none of the above — Douglas moved to a new topic, gave a short positive ack, or the
  session ended.

Conversation length after the invocation is a **triage pre-filter only** (dissatisfied stretches run longer),
never a standalone verdict — sentiment reflects perceived, not objective, quality.

### Step 4 — Attribute each signal to the skill (with an explicit ambiguous bucket)

This is the genuinely hard part, and the literature does not solve it cleanly — say so rather than faking a
mechanical rule. Apply this **designed** attribution rule (labeled as a designed choice, historian-style):
1. **Adjacency window** — attribute a corrective/frustration/re-run signal to the invocation only if it's in
   the human turn(s) immediately following the skill's report, with no intervening unrelated topic. A pivot to
   a new topic before the frustration means the frustration belongs to the new topic.
2. **Topic-continuity** — within that window, the correction must reference the skill's own output (an artifact
   path it just touched, a pronoun resolving to its report, or the skill named directly). Zero referential
   overlap = noise, not attributable.
3. **Multi-skill turns** — if two skills ran back-to-back, a correction after the second is ambiguous between
   them → tag `attribution: ambiguous`, never force-assign (detective's confabulation-consensus caution).
4. **Semantic re-run** — a rephrased re-ask that won't grep-match still counts as a re-run; catch it with the
   LLM pass over the adjacency window.

### Step 4.5 — Escalate a confusing or deeper-flaw finding (route by shape, don't force one tool)

When a tagged invocation is genuinely confusing, or a corrective/hard-fail signal points at a deeper flaw than
the skill itself (a harness collision, a systemic build defect, a root cause the adjacency window can't
settle), don't stop at "it failed" — escalate to get to the bottom of it. **Route by the shape of the
confusion, not by habit** (decided with Douglas 2026-07-16):

- **One already-identified incident → `/investigate`.** "*This* run failed confusingly — why?" Root-cause that
  single occurrence. Use when the confusion is bounded to one invocation and you need depth on it.
- **Cross-session recurrence → `/detective` (Topic Mode).** "Does this flaw show up in the *other* sessions/repos
  too, and where?" Use when the question is breadth — whether the finding is systemic. A cheap first pass is a
  targeted cross-corpus grep for the flaw's signature (error string, guard name) before committing to a full
  `/detective` fan-out; that grep alone often settles recurrence.
- The two compose: `/investigate` to nail the root cause of the confusing run, then `/detective` Topic Mode if
  you need to know whether it's systemic. Escalate only when a finding is genuinely unresolved — forcing an
  expensive sub-run when nothing is actually confusing is theater; say so and move on.

Fold whatever the escalation resolves back into the Step-5 verdict and the Step-6 gap list, tagged with which
tool ran and what it found.

### Step 5 — Aggregate into a per-skill verdict

Per invocation, record (historian's mandatory evidence-trail + confidence discipline — never a bare verdict):
`{ session_id, project, timestamp, invocation_form, signal, evidence_quote, attribution_confidence:
high|medium|low }`.

Per skill, produce: total invocation count, since-date, counts per signal category, a **trend** (split the
history into earlier vs. later halves, or bucket by month — so a skill that was rough early and has since
stabilized isn't flattened into one average), and the **top 3–5 recurring corrective themes** (cluster the
corrective/frustration quotes by rough topic — one recurring correction across N invocations is far more
actionable than N one-offs).

### Step 6 — Shape as `/ultraskill` Improve-Mode input, and hand off

End with a short list shaped exactly like Improve Mode's own Step-2 gap language ("traces to something
SPECIFIC found," not "could be more thorough"): each entry
`{ recurring_theme, occurrence_count, evidence: [quotes], proposed_fix_direction }`. This is a complementary,
usage-grounded lens Improve Mode weighs alongside its external research — Douglas (or a follow-on
`/ultraskill <name>` improve run) pastes it straight in. **`/trainer` never edits the skill file** — applying
fixes is Improve Mode's job. If a recurring theme is harness-level (not skill-specific), note that it should
also become a `feedback_*` memory entry.

## Safety constraints

- **Read-only over transcripts and the skill file.** `/trainer` writes nothing except its own report (and, if
  Douglas asks, a digest file under `_ultraskill/`). It never edits the target skill — that's Improve Mode.
- Never run with elevated/bypass permissions.
- Never raw-read whole transcripts into the main context — digest per Step 2 (streaming extraction, capped).
- No agent's `model` left unset on a GEN-keyed session (DELEGATE rule) if the Workflow below fans out.

## Workflow script (fan out the per-session digest; aggregate once)

Per-session digest+tag is embarrassingly parallel; aggregation needs all sessions at once (a real barrier).
`args.sessions` = the invocation-bearing sessions found in Step 1 (`[{ path, sessionId, project }]`);
`args.skill` = the target name; `args.since` = the resolved creation bound.

```js
export const meta = {
  name: 'trainer-run',
  description: 'Mine one skill\'s invocation track record: per-session digest+tag -> attribute+aggregate -> Improve-Mode gap list',
  phases: [
    { title: 'Digest' },
    { title: 'Aggregate' },
    { title: 'Synthesize' },
  ],
}

const SKILL = args.skill
const SINCE = args.since
const SESSIONS = args.sessions || []

const INVOCATION_SCHEMA = {
  type: 'object',
  properties: {
    session_id: { type: 'string' },
    project: { type: 'string' },
    timestamp: { type: 'string' },
    invocation_form: { type: 'string', enum: ['slash', 'skill_tool'] },
    signal: { type: 'string', enum: ['accept', 'corrective', 'rerun', 'frustration', 'hard_fail', 'ambiguous'] },
    evidence_quote: { type: 'string' },
    attribution_confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
  },
  required: ['session_id', 'signal', 'evidence_quote', 'attribution_confidence'],
}
const PER_SESSION_SCHEMA = {
  type: 'object',
  properties: { invocations: { type: 'array', items: INVOCATION_SCHEMA } },
  required: ['invocations'],
}

// Phase 1 — per session: locate the skill's invocations, extract only the adjacency window, tag + attribute.
const perSession = await parallel(SESSIONS.map(s => () =>
  agent(
    `In transcript ${s.path} (session ${s.sessionId}, project ${s.project}), find every invocation of the ` +
    `skill "${SKILL}" at or after ${SINCE}. For EACH, extract ONLY the invocation event, the skill's final ` +
    `report, and the human turn(s) immediately following it (the adjacency window) — do NOT read the whole ` +
    `session. Tag each with a signal (accept/corrective/rerun/frustration/hard_fail/ambiguous) using the ` +
    `deterministic markers first, then attribute to the skill via adjacency-window + topic-continuity; use ` +
    `"ambiguous" when two skills ran back-to-back. Quote the evidence line and set attribution_confidence.`,
    { phase: 'Digest', schema: PER_SESSION_SCHEMA, label: `digest:${s.sessionId.slice(0, 8)}` })
))
const invocations = perSession.filter(Boolean).flatMap(r => r.invocations)

// Phase 2 — barrier: aggregate ALL invocations into a per-skill verdict with trend + recurring themes.
const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    total: { type: 'number' },
    counts: { type: 'object' },
    trend: { type: 'string' },
    recurring_themes: { type: 'array', items: {
      type: 'object',
      properties: {
        theme: { type: 'string' },
        occurrence_count: { type: 'number' },
        evidence: { type: 'array', items: { type: 'string' } },
      },
      required: ['theme', 'occurrence_count', 'evidence'],
    } },
  },
  required: ['total', 'counts', 'trend', 'recurring_themes'],
}
const verdict = await agent(
  `Aggregate these ${invocations.length} tagged invocations of "${SKILL}" into a per-skill verdict: counts ` +
  `per signal, a before/after trend (earlier vs later halves), and the top 3-5 recurring corrective themes ` +
  `(cluster corrective/frustration quotes by topic). Data-sufficiency: if too thin, say so honestly.\n` +
  JSON.stringify(invocations),
  { phase: 'Aggregate', schema: VERDICT_SCHEMA, label: 'aggregate', model: 'opus' })

// Phase 3 — shape as Improve-Mode gap input (proposed fix directions), never editing the skill.
const gaps = await agent(
  `Turn this verdict for "${SKILL}" into /ultraskill Improve-Mode Step-2 input: for each recurring theme, a ` +
  `{ recurring_theme, occurrence_count, evidence:[quotes], proposed_fix_direction } phrased like Improve ` +
  `Mode's gap language ("traces to something SPECIFIC found," not "could be more thorough"). Flag any ` +
  `harness-level theme as also warranting a feedback_* memory entry. Do NOT edit the skill file.\n` +
  JSON.stringify(verdict),
  { phase: 'Synthesize', label: 'improve-input', model: 'opus' })

return { invocations, verdict, gaps }
```

## Final report — honest register

Report the track record, not a certification. State: the invocation count and since-date, the signal
breakdown with a quoted evidence line per non-accept case, the trend, the recurring themes, and the
Improve-Mode gap list. Name the limitations plainly, matching `/spar`/`/hone`/`/probe`: attribution of a
later utterance to an earlier skill run is a genuinely unsolved, noisy problem (the ambiguous bucket exists
for exactly this); small samples yield weak verdicts; the frustration/interrupt heuristics are inferred and
not yet validated against real interrupted sessions. Banned: "the skill is definitively broken/great" — report
what the record shows this pass and what would sharpen it.

---

*Tracked copy: also save this file to `claude-global-config/commands/trainer.md` (per the skills-are-tracked
convention) after a NASA scrub.*
