---
name: detective
description: Broad forensic sweep across MANY recent session transcripts, looking for five specific patterns -- dropped work, things Claude should have automated but made Douglas remind it of, manual steps Douglas did that could be automated, long-run/permission-grant moments, and repeated asks. Writes a scannable Obsidian report with evidence and a concrete fix per finding. Use for "look through my sessions and find what's going wrong" / "what should I automate" asks spanning a day or more. Also has a Topic Mode: when Douglas names a SPECIFIC topic/pattern/error/tool to search for ("find every time I mentioned X", "look for every Y crash"), searches transcripts for that one thing instead of the five fixed categories. For digging into ONE already-known incident, use /investigate instead. Overlaps partly with /daily-review (which focuses on playbook maintenance) -- don't run both over the same window; /detective is the deeper one-off forensic pass.
---

# /detective — cross-session forensic sweep

Generalized from the first run of this sweep (2026-07-02, `Session detective sweep — 2026-07-02.md`), which found
real, previously-invisible bugs: a plugin hook broken on every session all day, and a security hook that silently
went dark for 6 concurrent sessions because nothing checked that the guard actually ran.

## The five categories (default; can be narrowed if Douglas asks for fewer)

1. **Dropped** — Claude (or the harness) silently failed to do, or stopped doing, something it should have.
2. **Reminder** — Douglas had to prompt Claude to do something that should have happened automatically.
3. **Automatable manual** — Douglas did something by hand that a hook/script/skill could do instead.
4. **Long-run/permission** — a long-running or background moment, or a permission grant, that Douglas had to
   notice, wait on, or approve.
5. **Repeated pattern** — Douglas asked for the same thing more than once because state didn't persist.

## Procedure

### 1. Scope
Default: all top-level sessions with activity in the last 24h across every project. Exclude subagent/workflow-leaf
transcripts (path contains `/subagents/`) — Douglas isn't a participant in those, so they can't contain a
"reminder" or "repeated ask" by definition; note this exclusion explicitly in the final report. Widen the window
or narrow to specific projects only if asked.

### 2. Digest before mining — never hand a raw transcript to a finder agent
Session JSONLs run 10-70MB+; reading them raw blows context and money for no benefit, since 95% of a transcript is
tool-call payloads irrelevant to this sweep. Write a small script (Python is fine, throwaway) that streams each
top-level session file and extracts ONLY:
- `human_messages` — genuine typed user turns (a `type: user` entry where `message.content` is a plain string,
  not a list containing a `tool_result` block — that shape marks a synthetic/tool-relay message, not something
  Douglas typed).
- `mode_changes` — permission mode transitions (`type: mode`).
- `hook_errors` — `attachment.type` of `hook_non_blocking_error`/`hook_blocking_error`, with the hook name + stderr.
- `background_tasks` — background Bash/Agent/Workflow dispatches and their outcomes.
- `long_gaps` — idle gaps over ~180s between turns, largest N by duration.
- `denial_signals` — assistant/tool-result text matching permission/denial/blocked/interrupted phrasing.
- `error_signals_count`, `tool_use_counts`, turn counts.
Cap each list (e.g. 20-30 items) so one huge session can't crowd out everything else. Write one condensed JSON
digest per session; this should take total digest size from hundreds of MB down to low single-digit MB.

### 3. Fan out — bin-pack digests into batches, find, then merge
If the sweep spans more than a handful of sessions, use the `Workflow` tool (announce this to Douglas first if
not already authorized for the turn — this skill does not itself grant blanket Workflow authorization): bin-pack
digests into batches sized to stay well under a single agent's comfortable context, run one "find" agent per
batch against all 5 categories with a structured-output schema (category, session_id, project, summary, evidence
quote, automation_suggestion, severity), then one merge agent per category that dedupes/ranks across all batches.
If the sweep is small enough for a handful of direct agent calls, skip Workflow and just do it inline.

**Guard the merge step against "confabulation consensus," not just duplicates** (added 2026-07-08, ultra-skill
Improve Mode research — AgentAuditor, arXiv:2602.09341). Every batch runs the SAME prompt against the SAME 5
categories, so multiple batches independently "finding" the same category can mean either real corroboration
OR every batch converging on the same prompt-primed false positive — a naive dedupe can't tell these apart. The
merge agent must track WHERE batches agree vs. where they diverge, not just count occurrences as confirmation;
treat a finding that shows up in only ONE batch with strong evidence as more trustworthy than one that shows up
in three batches with thin, similar-sounding evidence.

**Split each category into "mechanically detectable from digest fields" vs. "requires semantic judgment"
before deciding whether it needs an LLM pass at all** (Improve Mode research — Stella Laurenzo's independent
Claude Code audit, github.com/anthropics/claude-code#42796, replicated at lucemia/claude-session-analyzer,
purely quantitative, no LLM in the loop). Categories 3 (Long-run/permission) and parts of 5 (Repeated pattern —
specifically session-restart clustering) reduce almost entirely to counting digest fields already extracted
(hook_errors, denial_signals, long_gaps, session start-times) — a deterministic rule over the digest is cheaper
and more reliable than an LLM judgment call for these. Reserve the LLM fan-out for categories that genuinely
require reading intent from prose (1, 2, 4 — did Claude actually understand what was asked and silently not do
it, versus the tool call visibly failing).

### 4. Verify — harness-artifact-first, and don't stop at one headline claim
At least one finding in each sweep tends to be checkable against ground truth beyond the transcript (a file mtime,
a git log, a hook actually firing) — do that check for whichever finding is the most consequential, exactly like
the check-secret-exposure.js mtime correlation in the 2026-07-02 sweep. Don't present every finding as verified
fact when most are necessarily "the transcripts say this happened" — say which one(s) you personally confirmed.

**Before attributing ANY finding to Claude's own behavior, check whether it's actually a hook/harness/config
artifact first** (added 2026-07-08, Improve Mode research — a directly analogous LLM-as-judge postmortem,
dev.to/gpgkd906, plus Anthropic's own April 2026 quality-regression postmortem, where three real regressions
that *looked* like model behavior were actually harness-level bugs: a caching bug silently dropping reasoning
history, a silent effort downgrade, an over-aggressive verbosity cap). This maps directly onto categories 1
(Dropped) and 5 (Repeated pattern) — both are exactly the shape of finding that's often really a hook/config bug,
not a genuine behavior pattern. Any finding phrased with absolute language ("always," "never," "silently
dropped," "Claude cannot") gets flagged for extra scrutiny and, where practical, cross-checked against a
quantitative artifact (an exit code, a hook_errors entry, an actual re-run) rather than trusted from the
transcript's own narrative text alone.

### 5. Write the report
Structure (see the 2026-07-02 sweep for a full worked example):
- One-paragraph headline finding.
- A "Fix-first list" of the 3-5 highest-severity items, linked to their full write-up below.
- One section per category, each finding with: occurrence count + severity, a verbatim quote as evidence, and a
  concrete fix (a real mechanism — hook/script/config change — never "I'll remember to").
- **Every finding carries an exact source pointer** (session ID + line/timestamp), not just the one that got
  ground-truth verified (added 2026-07-08, Improve Mode research — Corelight's and Datadog's report formats both
  require per-finding source citations, not a sampled subset) — cheap to include, keeps every claim traceable
  back to real evidence instead of just the headline one.
- A closing "what's already working" section crediting things that functioned correctly — a sweep that only ever
  finds fault stops being trusted.
- Cross-link a companion doc if a prior sweep/audit already diagnosed the same root cause recurring — don't
  re-diagnose from scratch, note "same root cause as [[prior doc]], still unfixed" instead.
Write it to the vault (`Claude/Engineer/<name> — <date>.md`) per the "Briefs → Obsidian" rule, and give Douglas the
full path plus a terse chat summary leading with the fix-first list — don't make him open the file to find out
what matters most.

### 6. Before reporting a root cause as fact
Same discipline as `/investigate` step 3: a merge/synthesis agent's output is itself an inherited claim, not
ground truth — spot-check its highest-severity items against the raw find-agent output or the source transcript
before it goes in the report as settled fact, especially anything that will get written into memory afterward.

## Topic Mode — searching for one specific thing (added 2026-07-08, Douglas: "add a mode where if i ask
## you to look for a specific topic, you look for that specific thing")

The five-category sweep above answers "what's going wrong across my sessions" -- an OPEN-ended question.
Topic Mode answers a DIFFERENT, NARROW question: "every time I asked about/mentioned/dealt with X, what
happened." Trigger this mode instead of the default sweep when Douglas names a specific topic, pattern,
tool, error, or recurring thing to search for (e.g. "detective, find every time I mentioned the VTK
install," "run detective on how I've talked about SentinelOne," "look for every uv_spawn crash") --
distinguishable from the default sweep by ARGUMENTS naming a concrete subject rather than being bare or
generic ("look through my sessions and find what's going wrong").

**Why this needs its own digest shape, not a filter on the existing one.** The 5-category digest (Section
2 above) extracts a FIXED set of signals (hook_errors, denial_signals, long_gaps, etc.) tuned specifically
for those 5 categories -- a named topic could be anything (a tool name, an error string, a project, a
person, a recurring frustration) and won't reliably show up in any of those fixed fields. Topic Mode needs
its own targeted extraction instead of filtering the 5-category digest after the fact.

### Procedure

1. **Resolve the topic and scope.** Get the exact topic/pattern from Douglas's own words (don't paraphrase
   it into something broader or narrower) and the time window (default: same as the main sweep, all
   sessions in the last 24h across every project, unless he says otherwise -- a named topic often warrants
   a WIDER window than the default drift-sweep, since "every time I've mentioned X" implies all history,
   not just yesterday; ask if the window is ambiguous rather than guessing small).
2. **Digest for topic occurrences, not the 5 fixed categories.** Same streaming-not-raw-read discipline as
   Section 2 (never hand a raw 10-70MB transcript to a finder agent), but the extraction is different: for
   each session, pull every `human_messages` entry AND every assistant text block AND (if the topic is
   technical -- an error, a tool, a file) every `hook_errors`/tool_result snippet that contains the topic
   (case-insensitive substring match, or a small set of Douglas-approved synonyms if he gives them --
   e.g. "VTK install" should probably also catch "vtk.libs" or "vtkfmt"). Cap per-session hits (e.g. 15) so
   one chatty session doesn't crowd out others. This is a MUCH smaller digest than the 5-category one since
   it's filtering to actual matches, not extracting broad signal categories.
3. **Fan out only if the match count or session count is large** (same Workflow-vs-inline judgment call as
   Section 3) -- a handful of real matches doesn't need a multi-agent pipeline, just read them directly.
4. **Verify at least one finding against live state**, same discipline as Section 4, when the topic
   concerns something checkable (a file, a config value, a fix that was supposedly applied) -- don't
   present "the transcripts say X happened" as settled fact when it's checkable.
5. **Report differently from the 5-category sweep**: NOT a "Fix-first list" (that structure is specific to
   the dropped/reminder/automatable/long-run/repeated taxonomy) -- instead, a chronological or
   session-grouped list of every real occurrence, each with: session + project, a verbatim quote, what
   happened as a result (if anything), and whether it's still open/unresolved. Close with a one-line
   summary of the pattern across occurrences (recurring complaint? resolved once then regressed? a single
   isolated mention?) -- but don't force a narrative if the honest answer is "these are N unrelated
   mentions with no real pattern."
6. **Same "don't fabricate" discipline as the main sweep**: don't inflate a single mention into a "pattern,"
   don't skip cleanup of scratch digest files, don't bypass a guard to make cleanup easier.

Write the report to the vault same as the main sweep (`Claude/Engineer/<topic> — <date>.md`) unless the
topic search is small enough that a direct chat answer with quotes is more useful than a standing doc --
use judgment; a 3-occurrence topic search probably doesn't need its own permanent file, a 20-occurrence
one probably does.

## What NOT to do
- Don't loosen or bypass a safety hook to make the digest script's job easier (e.g. don't reach for a bulk-delete
  bypass to clean up scratch digest files afterward — single-file deletes are always allowed and are the correct
  tool here).
- Don't fabricate an occurrence count or severity — if a pattern only shows up once, say once.
- Don't skip the cleanup of scratch digest files, but don't bypass guards to do it (see above).
