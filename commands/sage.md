---
name: sage
description: "Reads across EVERY solo-review, spar, probe, and tune run artifact a repo has accumulated, finds the issues that were actually there, and distills the ones that generalize into durable, cited WISDOM. Runs a deterministic scan of the review artifacts FIRST (enumerate + count findings, before any narrative extraction), gates on 'no run artifacts found' before spending anything, classifies each recurring or high-value finding into a fixed lesson-type taxonomy (invariant-violation, verification-gap, staleness, contract-mismatch, silent-failure, concurrency-hazard, resource-exhaustion, config-footgun, authority-disagreement, process-lesson) under the overarching gate-honesty principle, borrows the IDETC knowledge-frame schema (applicability = universal / context_dependent / situational; a stated rule + a cited source_quote) to shape each entry, and writes a lean WISDOM.md index at the repo root that maps to wisdom/<topic>.md detail files — every lesson citing the exact review artifact it came from. De-dups against the existing WISDOM.md (a lesson already captured is UPDATED with the new citation, never duplicated); a lesson violated again AFTER capture is tagged ⟳ recurred-after-capture and surfaced as a promotion candidate for a durable enforcement artifact (hook/test/gate/CLAUDE.md rule); entries carry first_seen/last_confirmed dates and superseded ones are moved to a Retired section with a reason; a final consumption check verifies something in the repo actually reads WISDOM.md (the Google-SRE action-item-drift guard). READ-ONLY over the artifacts and the code they reference; writes only WISDOM.md + wisdom/*.md. Use when Douglas says 'sage', 'sage this repo', 'mine the reviews for wisdom', 'what have the reviews taught us', 'build the WISDOM file', 'extract the durable lessons', '/sage'."
---

# /sage [target] [--since <date>] [--type <lesson-type>] [--max-lessons N]

Every solo-review, spar, probe, and tune run already found the issues that were there. `sage` reads back
across all of them at once and asks a narrower question: which of these findings carry a lesson, a technique,
or a rule that a FUTURE build should follow instead of rediscovering the hard way. It does not re-review the
code and it does not re-run the gate. Its evidence is the review artifacts the other skills already produced,
and its output is a curated `WISDOM.md` — rules, lessons, and pitfalls, each tagged by type and cited to the
run it came from, so the next build stands on what the last ten reviews learned.

The order is deliberate and mirrors `/historian` and `/probe`: the "does this issue really recur / is it
really worth writing down" question is answered **mechanically first** — enumerate the artifacts, count the
findings, compute per-type prevalence — before the model narrates a single lesson. Only findings that clear a
real bar (recurs across ≥2 artifacts, OR is a universal principle worth stating even once) get distilled. The
model writes the sentence once the evidence already stands.

## The knowledge-capture model (IDETC frame schema, borrowed)

Douglas's IDETC 2026 paper captures tacit design-for-manufacturing knowledge from unstructured discourse into
**knowledge frames** — a structured record with a `frame_type`, a `scope`, an `applicability`, a `subject`
anchor, and a `source_quote` that grounds every claim in the real text it came from. `sage` reuses that model
for build-lessons: a review artifact is the "discourse," and a WISDOM entry is the "frame." The mapping is
direct and honest (schema facts per `reference_idetc.md`, not invented):

- **`subject`** (IDETC: the noun-phrase graph-node anchor) → each WISDOM lesson leads with a short subject
  phrase naming the concept (e.g. "held ≠ load-path", "threshold defined in two places").
- **`frame_type`** (IDETC enum: risk / heuristic / principle / workaround / observation) → each lesson is one
  of those kinds. `sage`'s ten lesson **types** below are the build-domain `scope`; the `frame_type` is
  whether the entry is a *pitfall* (risk), a *rule/heuristic*, or a *principle*.
- **`applicability`** (IDETC enum, verbatim: `universal` / `context_dependent` / `situational`) → this is
  exactly Douglas's promotion bar ("applies universally or to a couple situations"). A `universal` or
  `context_dependent` lesson is promoted to WISDOM; a purely `situational` one-off is noted in the run report
  but NOT promoted, unless it recurs.
- **`source_quote`** (IDETC: the verbatim grounding) → every WISDOM entry cites the exact artifact + finding
  id it was distilled from. No entry ships without its citation, the same way no IDETC frame ships without its
  source quote.

Do not invent IDETC paper claims. The only thing borrowed is the *schema shape* above (which is real and
cited); the lessons themselves come only from the repo's own review artifacts.

## What this is NOT

- **Not `/solo-review`, `/spar`, `/probe`, or `/tune`.** Those PRODUCE the artifacts — they review, break,
  test, or measure a live target and write a dated findings file. `sage` runs in the opposite direction: it
  READS the artifacts those skills already wrote, across the whole history, and distills the durable lessons.
  It reviews no code and re-runs no gate. If Douglas wants a fresh review of the current code, that is one of
  those four skills, not this one.
- **Not `/historian`.** `/historian` mines the **build-log's event/activity history** (git-log commits grouped
  into events, plus daily reports) and proposes *insights* (pattern / thread / automation-candidate) about how
  the work is going. `sage` mines the **review artifacts** (SOLO_REVIEW / spar / probe / tune outputs) and
  distills *lessons* (rules / pitfalls / techniques) about how the build should be done. Different input,
  different output, different question — `historian` asks "what's the shape of the work," `sage` asks "what
  should the next build not get wrong again." They are complementary; neither replaces the other.
- **Not `/tune`.** `/tune` recalibrates Douglas's personal writing-voice files from writing samples. `sage`
  distills engineering lessons from code-review artifacts. The word "learn" is the only overlap.
- **Not a linter or a fresh audit.** `sage` adds no new findings of its own about the current code. If a
  lesson is not already grounded in a real review artifact, `sage` does not manufacture it — that would be a
  fresh review, which is `/solo-review`'s job.

## The lesson-type taxonomy (the fixed list)

Ten lesson types, derived from the real recurring shapes across cad-forge's own review artifacts, under one
overarching principle. Every promoted lesson files under exactly one type (its strongest fit). The `frame_type`
tag (risk / heuristic / principle) is orthogonal — a lesson of any type can be a pitfall to avoid, a rule to
follow, or a principle to hold.

**Overarching principle — GATE-HONESTY.** The north star that threads through every type. Three rules: (1)
never loosen a threshold, weaken a check, or exclude a case to manufacture a pass; (2) when two verifiers
disagree, promote the STRICTER independent oracle to a hard gate rather than trusting the looser one; (3) a
gate must exercise the constraint it names — "PASS" for a narrow or proxy definition is not a physical or
logical guarantee. This is not a defect class; it is the lens the ten types are read through.

1. **invariant-violation** — a single rule, threshold, count, or scope is defined in two places (or assumed in
   one place and violated in another) and the two drift. Includes threshold-splits (two probers using
   different values for the same physical concept) and scope-count invariants (a removable/absent item counted
   in a "complete" total). *frame_type: usually risk.*
2. **verification-gap (proxy-not-physical)** — a check verifies a PROXY (proximity, bounding box, registry
   entry, declared type, joint-membership) instead of the true physical or logical constraint it claims to
   test (point-in-solid capture, a load path, real clamping). Douglas's core physical-verification ethos, as a
   lesson class. *frame_type: risk or principle.*
3. **staleness** — an artifact is read as authoritative while a fresher sibling exists, while it has been
   superseded, or while a value is hardcoded/frozen and its live source has moved on. *frame_type: risk.*
4. **contract-mismatch (producer/consumer)** — two modules disagree on a key, field name, schema, or source
   path: a `.get(key, fallback)` on a key that never exists, a reference to a constant that was never defined,
   an unsubstituted format placeholder, a consumer reading the wrong file. *frame_type: risk.*
5. **silent-failure** — an error is swallowed or a failure path returns a benign success/zero: a bare
   `except: pass` around a measurement, an endpoint that computes validation issues then returns `ok:True`, an
   unimplemented branch that returns a harmless default instead of failing loud. *frame_type: risk or heuristic.*
6. **concurrency-hazard** — shared-state mutation, a lock leaked or double-released, a check-then-act race
   across threads, an optimistic-UI staleness window, a shared cache returned by reference and mutated by a
   caller. *frame_type: risk.*
7. **resource-exhaustion** — unbounded growth or a missing ceiling: per-job state/logfiles never pruned, a
   long-running child with no wall-clock timeout, a consumer that re-runs an expensive computation inline.
   *frame_type: risk or heuristic.*
8. **config-footgun** — an environment-specific default or assumption that works on the author's machine and
   breaks elsewhere: a missing `encoding="utf-8"` on Windows (cp1252 default), a CWD-relative path that silently
   reads the wrong file from another directory. *frame_type: heuristic.*
9. **authority-disagreement (no single source of truth)** — multiple signals each claim to be authoritative
   for the same quantity and disagree, with none designated canonical (four tools reporting four different
   masses; a gate that PASSes while an independent audit FAILs; two design-intent files naming the same joint
   differently). *frame_type: principle or risk.*
10. **process-lesson** — a lesson about HOW to run the build or review rather than a code defect: freeze a
    read-only snapshot or take a worktree before reviewing a moving target churned by a parallel session; let
    geometry override vision on anything measurable; "assess the assessment" (exclude a known false-positive
    class explicitly rather than silently). *frame_type: heuristic or principle.*

Step 0's first job on any run is to reconcile this fixed list against what the artifacts actually contain: if a
recurring finding genuinely fits none of the ten, add a new type WITH its definition and evidence rather than
forcing a bad fit — but treat that as the exception, and never split a type just to look thorough.

## Procedure

### Step 0 — Resolve TARGET from ARGUMENTS

Needs enough that a subagent with ZERO conversation context could act alone: the repo root to sage, and where
its review artifacts live. Parse optional `--since <date>` (only artifacts dated on or after it), `--type
<lesson-type>` (restrict extraction to one type), and `--max-lessons N` (cap promoted lessons per run; default
**40**). If ARGUMENTS lacks the repo root and it isn't obvious from the conversation, ask — don't guess.

### Step 1 — Deterministic artifact scan FIRST (mechanical, auditable, before any narrative reasoning)

This is the `/historian` Step-3 / `/probe` Step-3 move: establish the evidence base by computation you can
re-check by hand, before the model distills anything. Enumerate every review artifact in scope. The recognized
shapes (glob these; the filesystem is the source of truth, since many artifacts are untracked):

- **solo-review outputs** — `SOLO_REVIEW_*.md` (findings blocks: `ID:` / `SEVERITY:` / `WHERE:` / `ISSUE:` /
  `WHY:` / `FIX:`, plus a Disposition table in Apply-mode runs).
- **spar outputs** — `SPAR_*.md` / `SPAR_HANDOFF_*.md` (round-by-round break/fix findings).
- **probe outputs** — `PROBE_*.md` (coverage gaps, property counterexamples, mutation survivors).
- **panel / model reviews + handoffs** — `REVIEW_HANDOFF.md`, `REVIEW_DETAILED*.md`, `LOOPS_AND_REVIEW.md`,
  `findings.json`, `runs/**/gen_review.md`, `runs/**/review_*.md`.
- **the append-only worklog** — `LOG.md` (root-cause lines like "ROOT CAUSE found", "RECKONING", "gate
  honesty overhaul" are high-density lesson sources; each is one dated entry a human can re-open).

For each artifact, count the findings (grep the `ID:`/`SEVERITY:`/`### F`/severity-header markers) and record
its date and source-skill. Then compute, **mechanically**, the two things that decide what gets distilled:

- **per-type prevalence** — bin every finding into the ten types (by keyword/shape), and count how many
  DISTINCT artifacts each type appears in. A type seen in ≥2 separate artifacts is a strong lesson candidate.
- **per-lesson recurrence** — group findings by a normalized signature (the underlying rule, not the surface
  symptom — e.g. "missing encoding=utf-8", "held means joint-membership not load-path", "threshold defined
  twice"). A signature recurring across ≥2 artifacts is a recurring lesson; a vivid single-artifact finding
  with a universal principle is a keyness lesson (borrowing `/historian`'s prevalence-vs-keyness split).

Output of Step 1 is a table: artifacts enumerated, total findings, per-type counts, and the ranked list of
candidate lessons each already carrying the exact artifact(s) it rests on. Anything un-citable is dropped here.

### Step 2 — The gate (MANDATORY, before anything expensive)

Mirroring `/probe` and `/historian`: check the conditions that make the pass meaningless BEFORE distilling.

1. **No run artifacts found.** If the scan finds zero review artifacts in scope (a repo that has never been
   solo-reviewed / sparred / probed), say so plainly — *"no review artifacts found under `<root>` — run
   `/solo-review`, `/spar`, or `/probe` first; sage distills what those produce, it does not review code
   itself"* — and STOP. Do not fall back to reviewing the code. This is the hard gate.
2. **Nothing new since the existing WISDOM.md.** If a `WISDOM.md` already exists and every candidate lesson
   de-dups to an entry already in it, say *"no new lessons — WISDOM.md already covers what the artifacts in
   scope contain"* and STOP rather than re-writing what's there.

If either fires, that report IS the deliverable. Do not manufacture a weak lesson to look useful.

### Step 3 — Distill each candidate into a WISDOM entry (the core step)

For each candidate that cleared the scan (recurs across ≥2 artifacts, OR is a universal/context_dependent
principle worth stating even from one), write a WISDOM entry using the IDETC-frame shape:

- **subject** — the short noun-phrase anchor.
- **type** — one of the ten (its strongest fit); **frame_type** — risk / heuristic / principle.
- **applicability** — `universal` / `context_dependent` / `situational`. Only `universal` and
  `context_dependent` are promoted; a `situational` one-off is listed in the run report as "seen but not
  promoted" unless it recurred.
- **lesson** — the rule stated IMPERATIVELY and concretely ("pass `encoding='utf-8'` to every `open()`", "a
  press-fit/proximity check must run point-in-solid before crediting capture"), never a vague gloss ("be
  careful with encodings"). Borrow `/tune`'s Style-Eliciting-Prompt discipline: imperative feature-atoms.
- **enforceability — the reminder test.** Concrete is necessary but not sufficient: a lesson must name a
  *mechanism* the build can enforce; a bare *reminder* to stay vigilant fails this bar. Apply the litmus every
  practitioner postmortem guide converges on — *if a
  future build ignores this lesson, what catches the defect anyway?* A lesson whose only answer is human
  vigilance ("reviewers should watch for swallowed exceptions", "remember to pass encoding") is a reminder: it
  relies on memory and diligence, so it drifts and the class recurs weeks later even though the sentence was
  written. Rewrite it as the mechanizable default a build can enforce ("a bare `except` around a measurement
  fails the gate", "CI greps every `open(` for an explicit encoding") and mark `reminder_only`, which makes it
  a promotion candidate for a real hook/test/gate on FIRST capture, ahead of any recurrence. (Sources: the
  "be more careful" action item is the canonical postmortem anti-pattern per incident.io, Rootly, and The Art
  of CTO's reminder-vs-mechanism / enforcement-mechanism test; NASA LLIS's actionable-recommendation-over-bare-
  observation bar is the same test, and its recurrence rule — a lesson must be new or a refinement, never a
  repeat — is why a reminder that recurs is treated as a mechanism gap rather than logged as a fresh lesson.)
- **why** — one line on what actually breaks if the lesson is ignored (the physical/operational consequence
  the artifact recorded).
- **source(s)** — the exact artifact path + finding id(s) it was distilled from. Every entry, no exception.

Rank by leverage (prevalence × severity) and cap at `--max-lessons`. Group by type.

### Step 4 — De-duplicate against the existing WISDOM.md (the update rule)

Before writing, read any existing `WISDOM.md` and its `wisdom/*.md` detail files. For each new entry, check
`type` + normalized `subject` + source-overlap against what's already captured:

- **Already present, same lesson** — do NOT add a second entry. UPDATE the existing one: append the new
  artifact citation to its source list, bump its recurrence count, and widen its `applicability` only if the
  new evidence genuinely warrants it (e.g. `situational` → `context_dependent` because a second, different
  situation now shows it). Never duplicate a lesson across two entries.
- **Present but the new evidence extends it** — extend that entry (a new sub-case, a sharper rule), noting the
  added artifact, rather than spawning a near-duplicate.
- **Genuinely new** — add it as a fresh entry under its type.
- **Recurred AFTER capture — escalate.** When the new citation's artifact is dated
  AFTER the existing entry's `first_seen`, the lesson was already written down and got violated anyway.
  Append the citation as usual, but also tag the entry `⟳ recurred-after-capture` and list it in the final
  report as a **promotion candidate**: a lesson that recurs after being captured is failing as prose and
  wants a durable enforcement artifact (a hook, a test, a gate, a CLAUDE.md rule) — the same bar as the
  standing "make the fix real" rule, and Google SRE's recurrence question ("what happened to the corrective
  actions from last time?"). `sage` recommends the artifact; it does not build it.
- **Reminder-only lesson — promote on FIRST capture.** A lesson that cleared the bar but named no
  enforcement beyond human vigilance (`reminder_only`, per Step 3's litmus) is a promotion candidate the first
  time it is written, without waiting for a recurrence: the litmus already proved nothing catches its defect if
  a build forgets, so its second occurrence is a matter of time. Tag it `⚙ needs-mechanism` and list it in the
  report alongside the `⟳ recurred-after-capture` entries, each with the hook/test/gate it wants. This
  front-loads Google SRE's recurrence question instead of paying for the second incident to ask it.
- **Retire superseded entries — never silently delete.** While reading the existing WISDOM.md, if an
  entry's lesson has since been mechanized (a hook/test/gate now enforces it, per the artifacts) or its
  cited context no longer exists, move it to a short **Retired** section at the bottom of the index with a
  one-line reason (`retired: enforced by <artifact>` / `retired: superseded by <entry>`). The record stays
  auditable; the active list stays live.

This is the same index-discipline as Douglas's memory files: one topic = one entry; when the entry's hook
outgrows a line, the detail moves to the `wisdom/<topic>.md` file, not into a second index line.

### Step 5 — Write the output (the contract)

Two-tier, mirroring `MEMORY.md` → reference-file discipline:

- **`WISDOM.md` at the repo root** — a LEAN index. A one-line TL;DR, the gate-honesty principle stated once at
  the top, then the lessons grouped by type. Each lesson is a compact entry: **subject** — the imperative rule
  — `[type · frame_type · applicability]` — `why` — **source:** `<artifact>#<finding-id>` — `first_seen` /
  `last_confirmed` dates (temporal anchors, so a future run can tell a live lesson from a fossil — the
  agent-memory staleness discipline). Entries tagged `⟳ recurred-after-capture` keep the tag until the
  recommended enforcement artifact exists. A **Retired** section at the bottom holds superseded entries with
  their one-line reason. When a type has
  enough depth to warrant it, its entry points to a `wisdom/<topic>.md` detail file (`→ wisdom/<topic>.md`)
  and the index keeps only the one-line hook.
- **`wisdom/<topic>.md` detail files (optional, as warranted)** — one per heavy theme (e.g.
  `wisdom/gate-honesty.md`, `wisdom/verification-gaps.md`, `wisdom/staleness.md`). Each holds the full
  case-by-case detail: every instance, its artifact citation, the concrete before/after rule, and any
  worked example — the material too long for the index line.

Write incrementally if long (header + first section via `Write`, then append small chunks) to avoid a
mid-stream stall on a large single generation, per `/solo-review`'s own note.

### Step 6 — The honest final report (see "Final report" below)

## Safety constraints (apply every run, no exceptions)

- **READ-ONLY over the artifacts AND the code they reference; writes ONLY `WISDOM.md` + `wisdom/*.md`.** `sage`
  reads the review artifacts (and may open a referenced source file to confirm a lesson is real, never to
  edit it), and writes exactly the WISDOM index + its detail files. It never edits the repo's code, never
  re-runs a gate/accept/build, never mutates a review artifact. Because it mutates no code, it needs no git
  worktree — there is nothing to isolate.
- **No fabricated lessons.** Every promoted entry cites a real artifact + finding id. If a candidate can't name
  its source, it does not ship — the same bar `/historian` holds ("an un-addressable observation is not
  proposable") and Douglas's standing "don't fabricate" rule. `sage` adds no findings of its own about the
  current code; it only distills what the artifacts already found.
- **Preserve the gate-honesty ethos in the lessons themselves.** A lesson must never read "loosen the
  threshold to make it pass" — the artifacts record the opposite discipline, and a WISDOM entry that inverted
  it would be a corruption of the record. When an artifact's own FIX loosened nothing (the cad-forge norm),
  the lesson carries that: fix the defect, never the gate.
- **Never run with elevated / bypass permissions.** A generic "mine the reviews" ask does not justify
  disabling the permission system; run at default tool permissions. If a safety layer blocks an action
  mid-run, that is a correct block — narrow scope, don't route around it.
- **No commits.** `sage` writes the WISDOM files and reports — never `git commit` / `git push`, unless Douglas
  separately asked. The WISDOM files are a durable in-repo artifact, not a task-tracking entry: do not touch
  the repo's `CURRENT-TASK` / `WORK_QUEUE` / `STATUS` files.
- **Author docs in the code repo, per convention.** `WISDOM.md` and `wisdom/*.md` live WITH the code (like
  `LOG.md` / `STATUS.md`), not in the Obsidian vault — they are a build artifact the next session reads, and
  they follow the same voice rules as any doc (no "it's X, not Y" antithesis in the lessons).

## Procedure (how to run it)

1. Resolve TARGET, `--since`, `--type`, `--max-lessons` per Step 0, and the concrete paths of the review
   artifacts and any existing `WISDOM.md`.
2. **Run the gate (Step 2) yourself first, before the Workflow** — enumerating and counting the artifacts is a
   cheap read, and the whole point is to short-circuit before spending the distillation pass. If the gate
   fires (no artifacts, or nothing new), report that and STOP — do not call the Workflow.
3. Otherwise **call the `Workflow` tool** with the script below verbatim, passing
   `args: { target: "<repo root + artifact locations + existing WISDOM.md path>", since: "<date or ''>", type: "<lesson-type or ''>", maxLessons: <N> }`.
   This is an explicit skill-triggered Workflow use (per the Workflow tool's own rule) — no separate opt-in.
   - **The Gate & Scan and the Distill/Classify judgment run on `model: 'opus'`** — Douglas's delegation policy
     reserves Opus for the load-bearing calls (whether the gate fires, which type a finding really is, whether
     a lesson is `universal` vs `situational`, whether a candidate de-dups to an existing entry). The mechanical
     Write phase stays on the default model.
   - **If the `Workflow` tool is genuinely unavailable** (confirmed absent, not just unfamiliar), run Steps 1–5
     as sequential manual reasoning following the same prompts and shapes the script encodes — this was
     exercised live during this skill's own build/test pass (the cad-forge run that seeded its first
     `WISDOM.md`) with no loss of rigor, just without the Workflow tool's phase tracking.
4. **Report the result** per "Final report" below.

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'sage',
  description: 'Reads across a repo\'s solo-review/spar/probe/tune artifacts and distills durable, cited lessons into WISDOM.md: deterministic artifact scan + no-artifacts gate FIRST, then per-candidate ten-type classification with IDETC-frame applicability, de-dup against the existing WISDOM.md (update-not-duplicate), then write the lean index + wisdom/<topic>.md detail files. Read-only over the artifacts; writes only the WISDOM files.',
  phases: [
    { title: 'Gate & Scan' },
    { title: 'Distill' },
    { title: 'Write' },
  ],
}

const TARGET = args.target
const SINCE = args.since || ''
const TYPE = args.type || ''
const MAX_LESSONS = args.maxLessons || 40

const TYPES = ['invariant-violation', 'verification-gap', 'staleness', 'contract-mismatch', 'silent-failure',
  'concurrency-hazard', 'resource-exhaustion', 'config-footgun', 'authority-disagreement', 'process-lesson']

const SCAN_SCHEMA = {
  type: 'object',
  properties: {
    gate_fired: { type: 'boolean' },
    gate_reason: { type: 'string', enum: ['', 'no_artifacts', 'nothing_new'] },
    gate_note: { type: 'string' },
    artifacts_scanned: { type: 'array', items: { type: 'object', properties: {
      path: { type: 'string' }, source_skill: { type: 'string' }, date: { type: 'string' }, findings: { type: 'integer' },
    }, required: ['path', 'findings'] } },
    total_findings: { type: 'integer' },
    per_type_artifact_counts: { type: 'object' },   // { type: N_distinct_artifacts }
    candidates: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' },
      subject: { type: 'string' },
      signature: { type: 'string' },                 // the normalized underlying rule (dedup key)
      recurrence: { type: 'integer' },               // distinct artifacts this lesson appears in
      seen_in: { type: 'array', items: { type: 'string' } },   // artifact#finding-id citations
    }, required: ['id', 'subject', 'signature', 'recurrence', 'seen_in'] } },
  },
  required: ['gate_fired', 'gate_reason', 'total_findings', 'candidates'],
}

const DISTILL_SCHEMA = {
  type: 'object',
  properties: {
    candidate_id: { type: 'string' },
    type: { type: 'string' },
    frame_type: { type: 'string', enum: ['risk', 'heuristic', 'principle'] },
    applicability: { type: 'string', enum: ['universal', 'context_dependent', 'situational'] },
    promote: { type: 'boolean' },                    // false for situational one-offs -> reported not written
    subject: { type: 'string' },
    lesson: { type: 'string' },                       // imperative, concrete rule
    why: { type: 'string' },
    sources: { type: 'array', items: { type: 'string' } },   // artifact#finding-id, MANDATORY
    dedup: { type: 'string', enum: ['new', 'update_existing', 'extend_existing'] },
    existing_subject: { type: 'string' },             // set when dedup != 'new'
    recurred_after_capture: { type: 'boolean' },      // new citation postdates the existing entry's first_seen
    reminder_only: { type: 'boolean' },               // names no mechanism beyond human vigilance -> promotion candidate on first capture
  },
  required: ['candidate_id', 'type', 'frame_type', 'applicability', 'promote', 'subject', 'lesson', 'sources', 'dedup'],
}

const WRITE_SCHEMA = {
  type: 'object',
  properties: {
    wisdom_index_path: { type: 'string' },
    detail_files: { type: 'array', items: { type: 'string' } },
    entries_written: { type: 'integer' },
    entries_updated: { type: 'integer' },             // existing entries that gained a new citation
    entries_retired: { type: 'integer' },             // superseded entries moved to Retired (never deleted)
    situational_not_promoted: { type: 'integer' },
    wisdom_is_consumed: { type: 'boolean' },          // does anything in the repo reference WISDOM.md?
    consumption_note: { type: 'string' },             // what references it, or the pointer line to recommend
    wrote_only_wisdom: { type: 'boolean' },           // MUST be true -- guard on the read-only-code line
  },
  required: ['wisdom_index_path', 'entries_written', 'wrote_only_wisdom'],
}

function scanPrompt(target, since, type, maxLessons) {
  return `You are running the GATE and the deterministic ARTIFACT SCAN for a build-lesson distillation pass. ` +
    `READ-ONLY: open the review artifacts (and, if needed to confirm a finding is real, the code they cite) ` +
    `but edit nothing and re-run no gate/build.\n\nREPO + ARTIFACTS: ${target}` +
    `${since ? `\nOnly consider artifacts dated on or after ${since}.` : ''}` +
    `${type ? `\nRestrict to lesson type: ${type}.` : ''}\n\n` +
    `GATE FIRST: enumerate every review artifact under the repo (SOLO_REVIEW_*.md, SPAR_*.md, PROBE_*.md, ` +
    `REVIEW_HANDOFF.md, REVIEW_DETAILED*.md, LOOPS_AND_REVIEW.md, findings.json, runs/**/gen_review.md / ` +
    `review_*.md, and LOG.md root-cause lines) by hitting the FILESYSTEM directly (Glob/Grep, not git ls-files ` +
    `-- many are untracked). If ZERO artifacts exist, set gate_fired=true, gate_reason='no_artifacts', and STOP ` +
    `with a note pointing at /solo-review, /spar, /probe -- do NOT fall back to reviewing the code. If a ` +
    `WISDOM.md already exists and every lesson you'd surface already de-dups to an entry in it, set ` +
    `gate_fired=true, gate_reason='nothing_new'.\n\n` +
    `If the gate does NOT fire, run the mechanical scan: for each artifact count its findings (ID:/SEVERITY:/` +
    `### F markers) and record date + source-skill. Then bin findings into the TEN lesson types [${TYPES.join(', ')}] ` +
    `and count DISTINCT artifacts per type (per_type_artifact_counts). Group findings by a NORMALIZED signature ` +
    `(the underlying rule, not the surface symptom) and, for each, record recurrence = number of distinct ` +
    `artifacts it appears in, plus seen_in = the exact artifact#finding-id citations. A candidate is worth ` +
    `carrying forward if recurrence >= 2 OR it states a universal principle worth writing even from one ` +
    `artifact. Every candidate MUST carry citable seen_in -- an un-citable candidate is dropped here. Rank by ` +
    `recurrence x severity and return at most ${maxLessons}.`
}

function distillPrompt(target, candidate, existingWisdom) {
  return `Distill ONE scanned candidate into a durable WISDOM entry using the IDETC knowledge-frame shape. ` +
    `Read-only reasoning over the artifacts.\n\nCANDIDATE: ${JSON.stringify(candidate)}\n\n` +
    `EXISTING WISDOM.md (de-dup against this; do NOT duplicate an entry already here): ${existingWisdom}\n\n` +
    `Assign: type (the single strongest of the ten [${TYPES.join(', ')}]); frame_type (risk=pitfall / ` +
    `heuristic=rule / principle); applicability (universal / context_dependent / situational -- IDETC enum). ` +
    `Set promote=true ONLY for universal or context_dependent lessons; a purely situational one-off is ` +
    `reported but NOT written (promote=false) unless it recurred across >=2 artifacts. Write the lesson ` +
    `IMPERATIVELY and concretely (a rule a future build can follow: "pass encoding=utf-8 to every open()", "run ` +
    `point-in-solid before crediting capture") -- never a vague gloss. why = one line on what breaks if ignored. ` +
    `sources = the exact artifact#finding-id citations (MANDATORY -- no entry without them). Set dedup: 'new', ` +
    `or 'update_existing'/'extend_existing' (with existing_subject) if this lesson is already captured -- in ` +
    `which case the write phase appends the new citation to that entry, never a second entry. When updating an ` +
    `existing entry whose first_seen PREDATES the new citation's artifact, also set recurred_after_capture=true ` +
    `-- the lesson was written down and violated anyway, so it is a promotion candidate for a durable ` +
    `enforcement artifact (hook/test/gate/CLAUDE.md rule), flagged in the report. Apply the REMINDER TEST: if a ` +
    `future build ignores this lesson, what mechanism catches the defect anyway? If the only answer is human ` +
    `vigilance ("be careful", "reviewers should watch for X"), set reminder_only=true, rewrite the lesson as ` +
    `the mechanizable default a hook/test/gate could enforce, and treat it as a promotion candidate on FIRST ` +
    `capture -- a reminder relies on memory, drifts, and the class recurs. Preserve the gate-honesty ` +
    `ethos: never phrase a lesson as loosening a threshold to pass.`
}

function writePrompt(target, entries, indexPath) {
  return `Write the distilled lessons to the WISDOM files. TARGET REPO: ${target}\n\n` +
    `ENTRIES (promote=true only; update_existing/extend_existing entries modify an existing entry, never ` +
    `duplicate it): ${JSON.stringify(entries)}\n\n` +
    `Write a LEAN ${indexPath} at the repo root: a one-line TL;DR, the GATE-HONESTY principle stated once at ` +
    `the top, then lessons grouped by type. Each index line: **subject** -- the imperative rule -- ` +
    `[type . frame_type . applicability] -- why -- source: artifact#finding-id. When a type has enough depth, ` +
    `move its full case-by-case detail into wisdom/<topic>.md and keep only the one-line hook + a -> wisdom/<topic>.md ` +
    `pointer in the index (the MEMORY.md index-vs-reference discipline). For update_existing entries, append ` +
    `the new citation to the existing entry rather than adding a new line. Stamp every entry with first_seen / ` +
    `last_confirmed dates; tag recurred_after_capture entries with the recurrence marker and reminder_only ` +
    `entries with a needs-mechanism marker (both are promotion candidates in the report); move superseded entries ` +
    `(mechanized by a hook/test/gate, or their cited context is gone) to a Retired section with a one-line ` +
    `reason instead of deleting them (entries_retired). Then run the CONSUMPTION CHECK: grep whether anything ` +
    `in the repo references WISDOM.md (CLAUDE.md, primer, skill, README); set wisdom_is_consumed and, if ` +
    `false, put the recommended one-line pointer in consumption_note (recommend only -- write no file besides ` +
    `the WISDOM files). Write ONLY WISDOM.md and ` +
    `wisdom/*.md -- touch NO code, NO gate, NO other repo file. Write incrementally if long (header first, then ` +
    `append small chunks) to avoid a mid-stream stall. Set wrote_only_wisdom=true and confirm no code file was ` +
    `modified. Every promoted entry MUST show its source citation. No "it's X, not Y" antithesis in the prose.`
}

// --- Run ---

log(`sage: gate + deterministic artifact scan over ${TARGET}${TYPE ? ` (type=${TYPE})` : ''}${SINCE ? ` (since=${SINCE})` : ''}`)
const scan = await agent(scanPrompt(TARGET, SINCE, TYPE, MAX_LESSONS), { phase: 'Gate & Scan', schema: SCAN_SCHEMA, label: 'gate-scan', model: 'opus' })

if (!scan || scan.gate_fired) {
  return {
    target: TARGET,
    stopReason: scan ? `gate_fired:${scan.gate_reason}` : 'no_scan_result',
    gate_note: scan ? scan.gate_note : 'no scan result',
    artifacts_scanned: scan ? (scan.artifacts_scanned || []).length : 0,
    total_findings: scan ? scan.total_findings : 0,
    note: 'Gate fired (no review artifacts, or nothing new since WISDOM.md) -- no lessons distilled this pass. A valid, honest outcome.',
  }
}

const candidates = (scan.candidates || []).slice(0, MAX_LESSONS)
log(`sage: ${candidates.length} scanned candidate(s) across ${(scan.artifacts_scanned || []).length} artifact(s) -- distilling`)

const distilled = await parallel(candidates.map(c => () =>
  agent(distillPrompt(TARGET, c, '<existing WISDOM.md in scope, or "(none yet)">'), { phase: 'Distill', schema: DISTILL_SCHEMA, label: `distill-${c.id}`, model: 'opus' })
))

const promoted = (distilled || []).filter(d => d && d.promote)
log(`sage: ${promoted.length} lesson(s) promoted (universal/context_dependent) -- writing WISDOM`)

let write = null
if (promoted.length) {
  write = await agent(writePrompt(TARGET, promoted, 'WISDOM.md'), { phase: 'Write', schema: WRITE_SCHEMA, label: 'write' })
}

return {
  target: TARGET,
  since: SINCE,
  type: TYPE,
  artifacts_scanned: (scan.artifacts_scanned || []).length,
  total_findings: scan.total_findings,
  per_type_artifact_counts: scan.per_type_artifact_counts,
  candidatesScanned: candidates.length,
  distilled,
  promoted: promoted.length,
  situational_not_promoted: (distilled || []).filter(d => d && !d.promote).length,
  wisdom: write,
  wroteOnlyWisdom: write ? write.wrote_only_wisdom : true,
  stopReason: promoted.length ? 'wrote_wisdom' : 'no_lesson_promoted',
}
```

## Final report (what to tell Douglas)

Report in the measured, non-fabricating register of `/spar`, `/probe`, and `/historian`:

- **Gate outcome first.** If the gate fired (no review artifacts, or nothing new), that IS the report — a
  fired gate is an honest, complete answer; do not follow it with a manufactured lesson.
- **What was scanned** — the artifacts enumerated (count, dates, source-skills) and the total findings read.
  This is the evidence base; name it so Douglas can see the coverage. Name the dominant lesson-type in the
  per-type distribution too: a type that concentrates across many artifacts is itself a process signal, the way
  IBM's Orthogonal Defect Classification reads a spike in one defect-type as a problem in the phase that should
  have caught it (Chillarege et al.). The heaviest type points at the build practice that is systematically
  weakest — the highest-leverage place to add enforcement.
- **Lessons distilled**, grouped by type, each with its `frame_type`, `applicability`, the imperative rule,
  and — mandatory — its **source citation** (the exact artifact + finding id). Flag which entries are NEW vs
  which UPDATED an existing WISDOM entry with a new citation.
- **What was seen but not promoted** — situational one-offs that appeared in only one artifact and stated no
  universal rule, listed briefly so Douglas can see what was considered and set aside.
- **Promotion candidates** — every `⟳ recurred-after-capture` lesson AND every `⚙ needs-mechanism`
  (reminder-only) lesson — one whose only enforcement is human vigilance, flagged on FIRST capture — each with
  the enforcement artifact it wants (hook / test / gate / CLAUDE.md rule). A lesson violated again after being
  written down has proven prose insufficient; a lesson that never named a mechanism was prose from the start.
  Recommend the mechanism, and let Douglas pick — `sage` builds none of them.
- **Consumption check** — grep whether ANYTHING in the repo actually reads WISDOM.md (a CLAUDE.md pointer, a
  session primer, a skill's read-first list, a README line). Google SRE's finding on action items applies
  verbatim to lesson files: they fail through slow drift, shared once and never opened again. If nothing
  references it, say so plainly and give the one-line pointer to add (report-only — `sage` writes only the
  WISDOM files, so the pointer is Douglas's or the next session's edit). Also report any entries retired
  this pass, with reasons.
- **The WISDOM files written** — full absolute paths of `WISDOM.md` and any `wisdom/<topic>.md`, each tagged
  NEW/UPDATED, per the standing Files-list convention. Confirm no code file was touched.
- **Ban overclaiming.** A distilled lesson is a captured pattern with a cited trail, never "the complete set of
  lessons" or "everything the reviews taught." Acceptable close: "distilled N lessons across M artifacts this
  pass; more will surface as more reviews land." Never claim the WISDOM file is complete or final.

---

*Tracked copy: also save this file to `claude-global-config/commands/sage.md` (per the skills-are-tracked
convention) after a NASA scrub. The generated `WISDOM.md` / `wisdom/*.md` live in the target repo, not the
harness — they are a per-repo build artifact, not tracked with the skills.*
