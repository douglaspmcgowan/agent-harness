---
name: historian
description: "Reasons over the build-log's already-structured event/activity history (git-log commits grouped into EVENTS, plus the daily narrative activity reports) across all projects, and PROPOSES new Insights entries of three kinds — pattern, thread, automation-candidate. Runs a deterministic signal scan FIRST (real co-occurrence/repeat/condition-action-consequence thresholds, computed and auditable before any narrative reasoning), gates on 'not enough real event data yet' before spending anything, classifies each candidate by three independent tests (PREVALENCE -> pattern, KEYNESS -> thread, CONDITION-ACTION-CONSEQUENCE -> automation-candidate), and cites a concrete evidence trail (the exact events/commits/days) for every proposal so a human can check it. READ-ONLY over the event/activity data — writes no code, and NEVER writes insights.json directly; proposals go to a separate proposed-insights file for Douglas's review. Use when Douglas says 'historian', 'mine the build-log for insights', 'what patterns are in the history', 'propose insights', 'find threads/automation candidates across projects', '/historian'."
---

# /historian [target] [--since <date>] [--project <name>] [--max-candidates N]

The build-log already tells the story of what happened — the events, the commits inside them, the daily
reports. `historian` reads that story across the whole timespan and asks a narrower question: which recurring
shapes, which single-but-important observations, and which repeated-manual-pain loops are worth writing down
as **Insights**. It does not touch the daily-report machinery, it does not rate code, and it never decides on
its own that something is an insight — it *proposes*, with the exact events behind each proposal shown, and
Douglas keeps the curated set by hand.

The order matters and is deliberate: the "does this shape really repeat / really co-occur" question is
answered **mechanically and auditably first** — the way code-maat computes temporal coupling from
actual shared-commit counts before anyone narrates what it means, and the way repowise fixes a deterministic
score before an LLM writes a word of prose about it. Only shapes that clear a real numeric or structural test
get handed to the narrative pass. That split is the whole design: keep "is this genuinely a repeating shape"
countable and checkable; use the model only to write the sentence once the evidence already stands.

## What this is NOT

- **Not `/daily-review` or `/daily-activity`.** Those scan ONE day (or a catch-up backfill window) of raw
  session + git activity and *produce the daily report itself* — the narrative record of a single day.
  `historian` runs in the opposite direction: it reads the **already-structured** build-log history that those
  reports (plus the grouped git-log EVENTS) have already produced, across the **whole timespan**, and proposes
  Insights from it. It never generates or edits a daily report, and it depends on those reports as an input —
  a day with a real daily report attached is stronger evidence than a bare commit message (see the confidence
  rule below). If Douglas wants today's activity written up, that is `/daily-activity`, not this.
- **Not `/tech-debt-audit` or `/solo-review` or `/panel-ultra-review`.** Those read the *code* and reason
  about what could go wrong in it (a one-shot quality narrative, or a review of specific changes). `historian`
  reads the *event/activity history* and never opens the code under study to judge it — its evidence is
  commits-as-log-entries and daily-report prose, not the source. It touches no code and reviews no diff.
- **Not `/hone`, `/probe`, or `/spar`.** Those three MEASURE, BREAK, or HARDEN running code, each mutating a
  target in an isolated worktree. `historian` is strictly read-only over event/activity DATA — no worktree for
  its own run, no code edits, nothing to break. It borrows their *honesty register* (a proposal with an
  N-event evidence trail and a confidence flag, never "definitely a pattern"), not their code-mutating loop.
- **Not `superpowers:*` or `impeccable`.** Unrelated domains (development discipline; frontend/design). If a
  request is about writing code, testing code, or building UI, it is not this skill.
- **Not a replacement for the curated `insights.json`.** `historian` PROPOSES; it writes only to a separate
  proposed-insights file. The curated `insights.json` stays hand-maintained by Douglas — this skill never
  writes to it directly (see Safety constraints).

## The data it reasons over (the real build-log shapes)

`historian` reads the build-log's own structured data, not raw git. The concrete shapes, as they exist in the
build-log tool today:

- **`EVENTS[]`** — git-log commits already grouped into events. Each event:
  `{ date, time, tag, title, id?, subsystem, blurb, commits: [ [time, hash, kind, message], ... ] }`.
  Event ids look like `ev-85-pass`; `subsystem` is the project (e.g. `cad-forge`, `sme-tacit-frames`); each
  commit row carries its own `kind` (`milestone`/`decision`/`iteration`/`automation`/`blocker`/`routine`/`other`).
- **`DAILY_REPORTS[]`** — the daily narrative activity, some verbatim from Douglas's Obsidian daily reports,
  some generated from a day's git log where no report was written. Each:
  `{ date, title, meta, excerpt, quote, src }`. The `src` field distinguishes a real daily report
  (`Daily Reports/YYYY-MM-DD.md`) from a git-log-derived day (`cad-forge git log, 07-02`) — this distinction
  is load-bearing for the confidence flag.
- **`insights.json` / `INSIGHTS[]`** — the curated target set `historian` de-duplicates against and proposes
  additions to (never overwrites). Each: `{ kind, title, body, seenIn: [eventId, ...] }` where
  `kind ∈ {pattern, thread, automation-candidate}` and `seenIn` is the evidence trail of event ids.

If the build-log stores these somewhere other than the mockup's inline arrays by the time this runs (a JSON
export, a data module), resolve the actual path in Step 0 — the *shapes* above are the contract, wherever they
live.

## Procedure

### Step 0 — Resolve TARGET from ARGUMENTS

Needs enough that a subagent with ZERO conversation context could act alone: where the build-log's event and
activity data actually live (the `EVENTS` / `DAILY_REPORTS` arrays or their exported JSON path), and where the
curated `insights.json` (the de-dup target) lives. **The data files are commonly untracked/gitignored** (a
build-log's `data/*.json` living next to a `.gitignore`'d directory is the normal case, not an edge case) —
resolving TARGET must check the filesystem directly (`Glob`/`Read`) rather than relying on `git ls-files` or
any tracked-file discovery, which would silently miss real data and wrongly conclude "nothing to reason over."
Parse optional `--since <date>` (only consider events/days on or after it), `--project <name>` (restrict to one
`subsystem`), and `--max-candidates N` (cap how many candidates go to the narrative pass; default **12**). If
ARGUMENTS lacks the data locations and they aren't
obvious from the conversation, ask where the event/activity data and the curated insights file are — don't
guess at a data source, and never fall back to raw `git log` when the point is to read the *already-structured*
build-log.

### Step 1 — Load and normalize the event/activity history (read-only)

Read the `EVENTS`, `DAILY_REPORTS`, and current `INSIGHTS`/`insights.json` for the resolved scope. Build a
flat, addressable view: every event by id, every commit row (with its `date`/`subsystem`/`kind`/`message`),
every daily report by date (tagged real-report vs git-log-derived via its `src`). This is a pure read — no
writes, no code opened. The point of normalizing first is that every later claim must be able to name the
exact event ids / commit hashes / report dates it rests on; an un-addressable observation can't carry an
evidence trail and is therefore not proposable.

**Guard against the bare-log-under-explains failure (Allspaw's "second story").** A commit-message-only log
throws away the situational context that made an action make sense at the time. Where a real daily report
exists for a date, treat its prose as the richer source and prefer it over the terse commit line; where only
the commit message exists, that thinness is itself recorded and lowers the confidence of anything built on it
(Step 4/5). Never silently upgrade a one-line commit into a confident narrative claim.

### Step 2 — The data-sufficiency gate (MANDATORY, before anything expensive)

Mirroring `/hone` Step 2 and `/probe` Step 2: check the conditions that make the whole pass meaningless or
fabricated BEFORE spending the deterministic scan or any narrative reasoning.

1. **Not enough real event data yet.** If the scoped history has too few genuinely separate events to support
   even a prevalence claim (a rule of thumb, stated as a DESIGNED CHOICE below: fewer than ~8 events, or
   fewer than 2 distinct active days, or a single subsystem with a single event), say so plainly —
   *"not enough real event history in scope to mine for insights yet; N events across M days is too thin —
   come back after more has accumulated, or widen `--since`/`--project`"* — and STOP. Do not force a pattern
   out of three commits. This gate is exactly what stops the tool from manufacturing a confident-sounding
   shape from noise, which finding #5 (Card 2017, the "5 whys" critique) shows is the dominant failure mode of
   mechanical root-cause / pattern extraction: it stops at the first plausible-looking shape and reports it as
   real, with no mechanism to notice what it missed.
2. **Nothing new since the curated set.** If everything in scope is already covered by existing `insights.json`
   entries (every candidate shape de-dups to an insight already curated), say *"no new insight material in
   scope — the curated set already covers what's here"* and STOP rather than re-proposing what Douglas already
   wrote down.

If the gate fires on either condition, that report IS the deliverable. Do not manufacture a weaker candidate
to look useful — the same discipline as `/hone`'s already-optimized gate.

### Step 3 — Deterministic signal scan FIRST (mechanical, auditable, before any narrative reasoning)

This is the repowise / code-maat move: establish "is this really a repeating or co-occurring shape" by
**computation you can re-check by hand**, before the model narrates anything. repowise (finding #6) computes a
deterministic, non-LLM health score first and only lets an LLM write prose on top of the already-established
number; `historian` copies that split exactly. Compute three candidate pools from the normalized data.

**The numeric thresholds below are a DESIGNED CHOICE for this build-log's scale, NOT borrowed from any cited
methodology.** Braun & Clarke (finding #2) explicitly give no occurrence count, so any number here is ours to
own, to state in the run, and to tune as the history grows. State the thresholds actually used so a reader can
audit them.

**(a) Repeat / prevalence candidates — the raw material for `pattern`.** Group commit rows and event blurbs by
a normalized signature (shared `subsystem` + shared `kind` + a normalized topic key drawn from the message —
e.g. "gate blind-spot", "held model tightened", "recover from primary source"). A signature that recurs across
**≥ 2 genuinely separate events** (different event ids, and — designed choice — ideally on **≥ 2 distinct
days** so a single marathon day's back-to-back commits don't masquerade as a recurring pattern) is a
prevalence candidate. Reject a signature that only ever appears inside ONE event's commit list (that is one
episode, not a recurrence) — the analogue of code-maat's max-changeset-size filter that stops a mega-commit
from inflating coupling.

**(b) Co-occurrence candidates — temporal coupling, the code-maat mechanism applied to events.** Two topics
(or two subsystems) that repeatedly show up **in the same event or the same day** are temporally coupled the
way code-maat calls two files coupled when they change in the same commit/changeset. Compute it the way
code-maat does — as a shared-occurrence count plus a coupling ratio — and apply real floors: **≥ 2 shared
events** and a **co-occurrence ratio ≥ ~0.4** (of the days/events where either topic appears, the fraction
where both appear). code-maat's own published defaults (min 10 revisions per file, min 10 shared commits,
~50% coupling strength) are calibrated for large repos over years; this build-log is smaller and younger, so
these floors are **scaled-down DESIGNED CHOICES**, labeled as such — code-maat's *mechanism*, not its numbers,
transplanted. A strong co-occurrence is often the spine of a `thread` (two things genuinely moving together)
or a second `pattern`.

**(c) Condition → action → consequence candidates — the axial-coding template, for `automation-candidate`.**
Scan for the grounded-theory shape (finding #3, Strauss & Corbin's paradigm: conditions → action/interactional
strategies → consequences): a recurring **condition/trigger** → a **repeated manual action** → a **costly or
wasteful consequence**. Concretely: a trigger topic that recurs (condition), followed each time by the same
kind of manual remediation commit (action), where the log/report shows a real cost — rework, a reopened
verdict, a re-fix (consequence). This is the only pool whose candidates carry an explicit
trigger/action/consequence triple, and that triple is exactly what makes an `automation-candidate` *actionable*
rather than a vague "we should automate this."

Output of Step 3 is three pools of **mechanically-qualified candidates**, each already carrying the exact
event ids / commit hashes / dates that put it over threshold. Anything that did not clear a threshold is
dropped here, before the model spends a token narrating it. Cap the total handed forward at `--max-candidates`
(default 12), ranked by strength of the mechanical signal.

### Step 4 — Classify each candidate by THREE INDEPENDENT tests (the core step)

For each mechanically-qualified candidate, apply three independent tests grounded in findings #2 and #3. A
candidate files under its **primary** fit — one kind, never duplicated across all three. The tests are
independent on purpose: a candidate can pass one and fail the others, and a purely frequency-based tool would
wrongly collapse them into one "how often" ladder.

1. **PREVALENCE test → `pattern`.** Does the shape genuinely recur across **≥ 2 separate real events, each
   citable**? This is Braun & Clarke's *prevalence* criterion — recurrence across the dataset. A candidate
   from pool (a) or (b) that clears the repeat/co-occurrence floors and reads as a real recurring shape (not an
   artifact of one busy day) is a `pattern`. Its `seenIn` MUST list the ≥ 2 distinct event ids.
2. **KEYNESS test → `thread`.** Is this worth noting **on its own narrative merit even without repetition**?
   Braun & Clarke explicitly license a single vivid, non-repeating observation as a legitimate theme —
   *keyness* is relevance to the question, independent of count. A candidate that does NOT clear the prevalence
   floor but is clearly important to where the work is heading (a direction emerging, a quiet architectural
   drift, a cross-project reach) is a `thread`, not a discarded pattern. This is the one kind a frequency-only
   tool throws away — the reason the tests are independent. A `thread` still cites the events that prompted the
   observation, even if only one or two.
3. **CONDITION-ACTION-CONSEQUENCE test → `automation-candidate`.** Does the candidate carry a concrete
   **recurring trigger → repeated manual action → costly/wasteful consequence** triple (finding #3's axial
   paradigm), such that a specific, bounded automation would remove the repeated manual step? Borrow the SRE
   postmortem bar (finding #4): the proposed automation must be **actionable, specific, and bounded with a
   single clear owner-action** — "run the new checker against a fixture set of known-broken geometry before
   trusting its PASS" qualifies; "be more careful with gates" does not. If the triple is real but the fix needs
   Douglas's judgment call, propose it as a `thread` that names the open question rather than a false
   automation-candidate. (Finding #4's caveat is honored, not overclaimed: SRE culture does not formally
   separate "contributing factor" from "action item," so this test is a two-stage condition→bounded-fix shape,
   presented as a designed convention, not a borrowed taxonomy.)

A candidate that passes none of the three is dropped with a one-line reason (kept in the run log, not
proposed). A candidate that plausibly fits two kinds files under its strongest fit only, with a note that it
also touches the other — never a duplicate entry across kinds.

### Step 5 — Evidence trail + confidence flag (MANDATORY, per finding #5's Card 2017 caution)

Every proposed insight MUST carry:

- **`seenIn`** — the specific real event ids backing it, matching the curated schema. In addition, an
  **`evidence`** block naming the exact commit hashes and/or daily-report dates a human can open to check the
  claim. This is the direct implication of finding #5: the more automated the extraction, the higher the risk
  of a confident, plausible-but-wrong shape with nothing to check it against. A bare assertion is never
  proposable — if a candidate can't name its evidence, it doesn't ship.
- **`confidence` ∈ {high, medium, low}**, set by the strength of the evidence, not the confidence of the
  prose. Downgrade to **low** when the trail rests on a single terse commit message with no daily-report
  context (finding #4's "second story" caution — the bare log under-explains); **medium** for a git-log-derived
  day (`src` is a git log, not a real `Daily Reports/*.md`) or a two-event trail; **high** only when ≥ 2 events
  are corroborated by at least one real daily report. Confidence is about how checkable the evidence is, and it
  travels with the proposal so Douglas can triage the thin ones first.

### Step 6 — De-duplicate against the curated set, then write proposals to a SEPARATE file

De-duplicate every surviving proposal against the current `insights.json` — by `kind` + normalized `title` +
`seenIn` overlap. Anything already curated is dropped (or, if it *extends* an existing insight with new
events, proposed explicitly as an "extend `<existing title>`" note, not a fresh duplicate). Write the
survivors to a **separate proposed-insights file** (`proposed-insights.json` alongside the build-log data, or
`.proposed-insights/<timestamp>.json` — resolve the path in Step 0), each entry carrying
`{ kind, title, body, seenIn, confidence, evidence }`. **Never write to `insights.json`.** The curated set is
Douglas's to maintain by hand; `historian` only ever proposes.

The `body` prose is written last, only for candidates that already passed a test — the repowise /
claude-github-summary lesson (findings #6 and #7): the deterministic signal is fixed first, then the model
writes connective, readable prose (leaning first-person-narrative, not a bullet stub — the specific instruction
claude-github-summary found Claude follows reliably) on top of already-established evidence, never the other
way round.

## Safety constraints (apply every run, no exceptions)

- **READ-ONLY over the event/activity data; writes NO code.** `historian` reads `EVENTS`, `DAILY_REPORTS`, and
  `insights.json`, and writes exactly one output: the separate proposed-insights file. It never opens the
  projects' source to judge it, never edits a repo, never mutates the build-log data. Because it mutates no
  code, **it needs no git worktree for its own real invocation** (unlike `/spar`, `/hone`, `/probe`, which
  isolate code mutations in a throwaway worktree) — there is nothing to isolate.
- **NEVER write to `insights.json` directly.** This is the hard line. The curated insights set stays
  hand-maintained by Douglas; `historian` writes only to the separate `proposed-insights` file and leaves the
  curated file byte-for-byte untouched. A proposal is a proposal — Douglas promotes it by hand, or doesn't.
- **No elevated / bypass permissions.** A generic "mine the history" ask does not justify disabling the
  permission system; run at default tool permissions. If a safety layer blocks an action mid-run, that is a
  correct block — narrow scope, don't route around it.
- **Stay scoped to the build-log data.** No touching unrelated processes, files, services, or shared state; no
  destructive or irreversible action on anything. The only file created is the proposed-insights output.
- **No commits.** `historian` proposes and reports — never `git commit` / `git push`, unless Douglas separately
  asked for that.
- **The proposed-insights file is a review artifact, not an applied change.** It is handed back for Douglas to
  read and selectively promote into `insights.json` himself, the same way `/hone` hands back a diff and
  `/probe` hands back a test — the tool does not apply it.

## Procedure (how to run it)

1. Resolve TARGET, `--since`, `--project`, and `--max-candidates` per Step 0, and the concrete paths of the
   event/activity data, the curated `insights.json`, and where the proposed-insights output should go.
2. **Run the data-sufficiency gate (Step 2) yourself first, before the Workflow** — loading and counting the
   scoped events is a cheap read, and the whole point is to short-circuit before spending the scan + narrative
   passes. If the gate fires (not enough event data, or nothing new since the curated set), report that and
   STOP — do not call the Workflow.
3. Otherwise **call the `Workflow` tool** with the script below verbatim, passing
   `args: { target: "<resolved data locations + curated insights path + proposed-insights output path>", since: "<date or ''>", project: "<subsystem or ''>", maxCandidates: <N> }`.
   This is an explicit skill-triggered Workflow use (per the Workflow tool's own rule) — no separate opt-in.
   - **The Gate & Signal-Scan and Classify judgment runs on `model: 'opus'`** — Douglas's delegation policy
     reserves Opus for the load-bearing calls (whether the data-sufficiency gate fires, which of the three
     independent tests a candidate actually passes, whether a condition→action→consequence triple is real and
     bounded). The mechanical Narrate phase stays on the default model.
   - **If the `Workflow` tool is genuinely unavailable in the current environment** (confirmed absent, not
     just unfamiliar), run Steps 3-6 as sequential manual reasoning instead, following the same prompts and
     JSON-schema shapes the script below encodes — this was exercised live during this skill's own build/test
     pass (real repos, real data) with no loss of rigor, just without the Workflow tool's phase tracking.
4. **Report the result** per "Final report" below. Never claim a proposal is "definitely a pattern" or names
   "the real root cause" — report each as *"proposed with an N-event evidence trail, confidence high/medium/low"*.

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'historian',
  description: 'Reasons over build-log event/activity history and PROPOSES insights (pattern/thread/automation-candidate): deterministic signal scan + data-sufficiency gate FIRST, then per-candidate three-test classification, then cited narrative prose; writes proposals to a separate file, never insights.json',
  phases: [
    { title: 'Gate & Signal Scan' },
    { title: 'Classify' },
    { title: 'Narrate' },
  ],
}

const TARGET = args.target
const SINCE = args.since || ''
const PROJECT = args.project || ''
const MAX_CANDIDATES = args.maxCandidates || 12

// --- Phase schemas (JSON-schema-validated agent output, spar/hone/probe pattern) ---

const SCAN_SCHEMA = {
  type: 'object',
  properties: {
    // Data-sufficiency gate (Step 2) -- computed mechanically before anything expensive.
    gate_fired: { type: 'boolean' },
    gate_reason: { type: 'string', enum: ['', 'insufficient_data', 'nothing_new'] },
    gate_note: { type: 'string' },              // plain-language, e.g. "6 events across 2 days is too thin"
    events_counted: { type: 'integer' },
    active_days: { type: 'integer' },
    // The DESIGNED-CHOICE thresholds actually used this run (stated for auditability, per finding #2).
    thresholds_used: { type: 'string' },
    // Three mechanically-qualified candidate pools (Step 3). Anything below threshold is already dropped.
    candidates: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          pool: { type: 'string', enum: ['repeat', 'co_occurrence', 'condition_action_consequence'] },
          signal_summary: { type: 'string' },   // the mechanical basis: counts/ratio that put it over threshold
          seen_in: { type: 'array', items: { type: 'string' } },   // event ids
          evidence_hashes: { type: 'array', items: { type: 'string' } },  // commit hashes / report dates
          // For condition_action_consequence candidates only:
          condition: { type: 'string' },
          manual_action: { type: 'string' },
          consequence: { type: 'string' },
        },
        required: ['id', 'pool', 'signal_summary', 'seen_in'],
      },
    },
  },
  required: ['gate_fired', 'gate_reason', 'events_counted', 'active_days', 'thresholds_used', 'candidates'],
}

const CLASSIFY_SCHEMA = {
  type: 'object',
  properties: {
    candidate_id: { type: 'string' },
    // The three independent tests (Step 4) -- each pass/fail is recorded even when only one fires.
    prevalence_pass: { type: 'boolean' },       // recurs across >=2 separate cited events -> pattern
    keyness_pass: { type: 'boolean' },          // worth noting on narrative merit alone -> thread
    cac_pass: { type: 'boolean' },              // real bounded condition->action->consequence -> automation-candidate
    primary_kind: { type: 'string', enum: ['pattern', 'thread', 'automation-candidate', 'none'] },
    also_touches: { type: 'string' },           // secondary kind noted, NOT duplicated as its own entry
    drop_reason: { type: 'string' },            // required when primary_kind = 'none'
    // Evidence trail + confidence (Step 5) -- mandatory for any non-'none' candidate.
    seen_in: { type: 'array', items: { type: 'string' } },
    evidence: { type: 'string' },               // exact hashes / report dates a human can open
    confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
    confidence_reason: { type: 'string' },      // why this level (thin single commit vs corroborated by a real daily report)
    duplicate_of_existing: { type: 'boolean' }, // de-dup against curated insights.json
    extends_existing_title: { type: 'string' }, // set if it extends rather than duplicates an existing insight
  },
  required: ['candidate_id', 'prevalence_pass', 'keyness_pass', 'cac_pass', 'primary_kind'],
}

const NARRATE_SCHEMA = {
  type: 'object',
  properties: {
    proposals: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          kind: { type: 'string', enum: ['pattern', 'thread', 'automation-candidate'] },
          title: { type: 'string' },
          body: { type: 'string' },             // connective narrative prose, written last on established evidence
          seenIn: { type: 'array', items: { type: 'string' } },
          confidence: { type: 'string', enum: ['high', 'medium', 'low'] },
          evidence: { type: 'string' },
          extends: { type: 'string' },          // '' for a fresh proposal, else the existing insight it extends
        },
        required: ['kind', 'title', 'body', 'seenIn', 'confidence', 'evidence'],
      },
    },
    written_to: { type: 'string' },              // path of the separate proposed-insights file (NEVER insights.json)
    wrote_insights_json: { type: 'boolean' },    // MUST be false -- a guard on the hard line
  },
  required: ['proposals', 'written_to', 'wrote_insights_json'],
}

// --- Prompts ---

function scanPrompt(target, since, project, maxCandidates) {
  return `You are running the data-sufficiency GATE and the deterministic SIGNAL SCAN for a build-log ` +
    `insight-mining pass. This is READ-ONLY over the event/activity data -- open no source code, edit nothing, ` +
    `and do NOT fall back to raw git log; read the already-structured build-log data.\n\nDATA + SCOPE: ${target}` +
    `${since ? `\nOnly consider events/days on or after ${since}.` : ''}` +
    `${project ? `\nRestrict to subsystem/project: ${project}.` : ''}\n\n` +
    `STEP 2 GATE FIRST (before any scan work): count the genuinely separate events and distinct active days in ` +
    `scope. If the history is too thin to support even a prevalence claim (rule of thumb, a DESIGNED CHOICE: ` +
    `< ~8 events, or < 2 distinct active days, or a single subsystem with a single event), set gate_fired=true, ` +
    `gate_reason='insufficient_data', and STOP with a plain gate_note -- do NOT force candidates out of noise. ` +
    `Also gate on nothing-new: if every shape you'd surface already de-dups to an existing curated insight, set ` +
    `gate_fired=true, gate_reason='nothing_new'.\n\n` +
    `If the gate does NOT fire, run the DETERMINISTIC SIGNAL SCAN (mechanical, auditable, before any narrative ` +
    `reasoning -- the repowise/code-maat split). Compute three candidate pools, and STATE the numeric ` +
    `thresholds you used in thresholds_used (they are DESIGNED CHOICES for this build-log's scale, not borrowed ` +
    `from any methodology):\n` +
    `(a) REPEAT/PREVALENCE -- normalized signatures (subsystem + commit kind + topic key) that recur across ` +
    `>=2 SEPARATE events, ideally on >=2 distinct days; reject anything confined to ONE event's commit list ` +
    `(one episode, not a recurrence -- the max-changeset-size filter analogue).\n` +
    `(b) CO-OCCURRENCE -- temporal coupling (code-maat's mechanism): topics/subsystems appearing in the same ` +
    `event or same day; require >=2 shared events AND a co-occurrence ratio >= ~0.4. Scaled-down floors on ` +
    `purpose (code-maat's own 10/10/50% are for large old repos).\n` +
    `(c) CONDITION -> ACTION -> CONSEQUENCE -- the axial-coding shape: a recurring trigger, a repeated manual ` +
    `remediation, and a real cost (rework, a reopened verdict, a re-fix). Fill condition/manual_action/` +
    `consequence for these.\n\n` +
    `Every candidate MUST carry the exact event ids (seen_in) and commit hashes / report dates ` +
    `(evidence_hashes) that put it over threshold -- an un-addressable candidate is not a candidate. Rank by ` +
    `signal strength and return at most ${maxCandidates}. Report gate fields, counts, thresholds_used, and the ` +
    `qualified candidate pools.`
}

function classifyPrompt(target, candidate, curatedInsights) {
  return `Classify ONE mechanically-qualified build-log candidate by THREE INDEPENDENT tests. This is ` +
    `read-only reasoning over event/activity data -- no code, no edits.\n\nCANDIDATE: ${JSON.stringify(candidate)}\n\n` +
    `CURATED INSIGHTS to de-dup against (do NOT propose a duplicate of any of these): ${JSON.stringify(curatedInsights)}\n\n` +
    `Apply each test independently -- a candidate can pass one and fail the others; do NOT collapse them into a ` +
    `single "how often" ladder:\n` +
    `1. PREVALENCE -> pattern: does the shape genuinely recur across >=2 SEPARATE real events, each citable ` +
    `(not an artifact of one busy day)? (Braun & Clarke's prevalence.)\n` +
    `2. KEYNESS -> thread: is it worth noting on its own narrative merit EVEN WITHOUT repetition -- a direction ` +
    `emerging, an architectural drift, a cross-project reach? (Braun & Clarke explicitly license a single vivid ` +
    `non-repeating observation as a legitimate theme -- do NOT discard a keyness-only candidate as a failed ` +
    `pattern.)\n` +
    `3. CONDITION-ACTION-CONSEQUENCE -> automation-candidate: is there a real recurring trigger -> repeated ` +
    `manual action -> costly/wasteful consequence triple, AND is the fix actionable, specific, and BOUNDED ` +
    `(SRE postmortem bar)? If the triple is real but the fix needs Douglas's judgment, file it as a thread that ` +
    `names the open question, NOT a false automation-candidate.\n\n` +
    `Set primary_kind to the STRONGEST single fit (or 'none' with a drop_reason if it passes no test). If it ` +
    `also touches a second kind, note it in also_touches -- do NOT emit a duplicate entry. For any non-'none' ` +
    `result, provide seen_in (>=2 event ids for a pattern), an evidence string naming exact hashes/report ` +
    `dates, and a confidence (high only if >=2 events corroborated by at least one REAL daily report; medium ` +
    `for a git-log-derived day or a two-event trail; LOW if it rests on a single terse commit with no daily-` +
    `report context -- the bare log under-explains). Flag duplicate_of_existing / extends_existing_title after ` +
    `de-dup.`
}

function narratePrompt(target, classified, outputPath) {
  return `Write the final PROPOSED insights, prose LAST, only for candidates that passed a test. This is the ` +
    `narrative layer on top of already-established deterministic evidence (repowise/claude-github-summary ` +
    `split) -- you are writing the sentence, not deciding whether the shape is real (that's already settled).\n\n` +
    `CLASSIFIED CANDIDATES (only non-'none', non-duplicate ones): ${JSON.stringify(classified)}\n\n` +
    `For each, write a { kind, title, body, seenIn, confidence, evidence } entry matching the curated ` +
    `insights.json schema. The body is connective, readable prose (lean first-person-narrative, NOT a bullet ` +
    `stub); the title is a single concrete claim. Carry seenIn/confidence/evidence through unchanged from ` +
    `classification -- never inflate a confidence. For a candidate that EXTENDS an existing insight, set ` +
    `extends to that insight's title rather than duplicating it.\n\n` +
    `Write the result to the SEPARATE proposed-insights file at: ${outputPath}. You MUST NOT write to, edit, ` +
    `or touch insights.json -- the curated set is hand-maintained by Douglas. Set wrote_insights_json=false ` +
    `and confirm insights.json is byte-for-byte unchanged. Report the proposals and written_to path.`
}

// --- Run ---

log(`historian: gate + deterministic signal scan over ${TARGET}${PROJECT ? ` (project=${PROJECT})` : ''}${SINCE ? ` (since=${SINCE})` : ''}`)
const scan = await agent(scanPrompt(TARGET, SINCE, PROJECT, MAX_CANDIDATES), { phase: 'Gate & Signal Scan', schema: SCAN_SCHEMA, label: 'gate-scan', model: 'opus' })

if (!scan || scan.gate_fired) {
  return {
    target: TARGET,
    stopReason: scan ? `gate_fired:${scan.gate_reason}` : 'no_scan_result',
    gate_note: scan ? scan.gate_note : 'no scan result',
    events_counted: scan ? scan.events_counted : 0,
    active_days: scan ? scan.active_days : 0,
    thresholds_used: scan ? scan.thresholds_used : '',
    note: 'Data-sufficiency gate fired (or scan failed) -- no insights proposed this pass. This is a valid, honest outcome, not a failure to find something.',
  }
}

const candidates = (scan.candidates || []).slice(0, MAX_CANDIDATES)
log(`historian: ${candidates.length} mechanically-qualified candidate(s) -- classifying by the three tests`)

// Classify each candidate in parallel (per-candidate is independent, file-disjoint reasoning).
const classified = await parallel(candidates.map(c => () =>
  agent(classifyPrompt(TARGET, c, '<curated insights.json in scope>'), { phase: 'Classify', schema: CLASSIFY_SCHEMA, label: `classify-${c.id}`, model: 'opus' })
))

const kept = (classified || []).filter(r => r && r.primary_kind && r.primary_kind !== 'none' && !r.duplicate_of_existing)
log(`historian: ${kept.length} candidate(s) passed a test and are not duplicates -- narrating`)

let narrated = null
if (kept.length) {
  narrated = await agent(narratePrompt(TARGET, kept, '<proposed-insights output path from args>'), { phase: 'Narrate', schema: NARRATE_SCHEMA, label: 'narrate' })
}

return {
  target: TARGET,
  since: SINCE,
  project: PROJECT,
  thresholds_used: scan.thresholds_used,
  events_counted: scan.events_counted,
  active_days: scan.active_days,
  candidatesScanned: candidates.length,
  classified,
  proposals: narrated ? narrated.proposals : [],
  proposedInsightsFile: narrated ? narrated.written_to : null,
  wroteInsightsJson: narrated ? narrated.wrote_insights_json : false,   // MUST be false
  stopReason: kept.length ? 'proposed' : 'no_candidate_passed',
}
```

## Final report (what to tell Douglas)

Report in the register of `/spar`, `/hone`, and `/probe` — measured, non-fabricating, and it PROPOSES, it does
not decide:

- **Gate outcome first.** If the data-sufficiency gate fired, that IS the report: *"not enough real event
  history in scope yet — N events across M days"* or *"no new insight material — the curated set already covers
  what's here."* A fired gate is an honest, complete answer; do not follow it with a manufactured proposal.
- **Thresholds used**, stated plainly and labeled as designed choices for this build-log's scale (not borrowed
  from any methodology) — so Douglas can see and adjust the bar.
- **Proposed insights**, grouped by kind (pattern / thread / automation-candidate). For each: the title, which
  test it passed, its `seenIn` event ids, and — mandatory — its **evidence trail** (the exact commit hashes /
  daily-report dates a human can open) and its **confidence** (high / medium / low, with why). An
  automation-candidate additionally names its condition → action → consequence and the bounded fix.
- **What was scanned but dropped** — candidates that cleared the mechanical threshold but passed none of the
  three tests, or de-duplicated to an existing insight, each with a one-line reason. The drops matter: they
  show what was considered and ruled out, the transparency finding #5 demands.
- **The proposed-insights file path** (full absolute path, per the standing Files convention), and an explicit
  confirmation that **`insights.json` was not touched** — the proposals are Douglas's to promote by hand.
- **Ban overclaiming.** Never "definitely a pattern," never "the real root cause," never "this is what's
  happening." Each proposal is *"proposed with an N-event evidence trail, confidence high/medium/low"* — the
  same honesty register as `/spar`'s "no new issues across the last 2 rounds," `/hone`'s "nothing beat the
  baseline past noise," and `/probe`'s "no counterexample found this pass." A mechanical signal plus a cited
  trail is a proposal for review, not a proven truth about the work.

---

*Tracked copy: also save this file to `claude-global-config/commands/historian.md` (per the skills-are-tracked
convention) after a NASA scrub.*
