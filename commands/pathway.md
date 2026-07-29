---
name: pathway
description: "Executes a named compound PATHWAY -- an ordered chain of Douglas's existing skills (e.g. harden-tail: solo-review -> probe -> spar -> hone) -- end-to-end against ONE target, one sequential agent() per step, with genuine idempotent step-skip on resume. Reads chain definitions from hooks/skill-pathways.json (the same file the chain-suggester hook reads for passive nudging) and ACTIVELY drives execution instead of just detecting/suggesting. Idempotency rides Workflow's own result cache: each step is dispatched as a Workflow agent() call with a stable label, and a tiny per-(chain,target) pointer file records the run's id so a later invocation replays every already-completed step from that cache and runs only what's left. Runs a gate FIRST (unknown chain -> list and stop; this exact (chain,target) already fully complete -> say so and stop). Use when Douglas says 'run the pathway', 'run the harden-tail pathway', 'execute the <name> pathway against <target>', 'walk the chain', 'run my build pathway on X', 'resume the pathway', or '/pathway'."
---

# /pathway [chain] against [target] [--max-iterations passthrough]

Run a whole *chain* of skills as one operation. A pathway is an ordered list of Douglas's existing skills
(defined in `skill-pathways.json`) that he tends to invoke as a group -- the real one today is **harden-tail**
(`solo-review -> probe -> spar -> hone`). This command dispatches each step in order against a single shared
target, records where the run got to, and -- on a second invocation of the same `(chain, target)` -- **skips
the steps that already ran and picks up at the next unfinished one**. The skip is genuine: it rides
Workflow's own result cache, so a resumed run replays the completed steps and executes only what is left.

## What this is NOT

- **Not the `skill-build-pathways.html` editor app** (at `Claude NASA Folder/skill-pathways/`, a standalone
  HTML + `server.py` tool). That app *authors and reviews* pathway definitions -- it's where a chain like
  harden-tail is drawn up and edited. `/pathway` is the other end: it *runs* an already-defined chain. One
  designs the pathway; this executes it. (No command collision either -- the editor is an HTML app served by
  `server.py`, with no slash command of its own.)
- **Not `task-state-reminder.js`'s chain-suggester hook.** That hook reads the SAME `skill-pathways.json` but
  only *passively detects* -- when a prompt names 2+ of a chain's skills it nudges "you tend to run these as a
  group," scanning the transcript for which steps already fired, and never executes anything. `/pathway` is the
  active counterpart: it actually dispatches the steps. The hook says "you might want the whole chain"; this
  runs the whole chain. (It also supersedes the hook's transcript-scan as the *resume* signal -- see "Why this
  mechanism" below for why an explicit pointer beats re-reading the transcript.)
- **Not `/spar`.** `/spar` attacks ONE target repeatedly with a fresh adversary each round -- same skill, many
  iterations, one axis (break-fix). `/pathway` walks a SEQUENCE of DIFFERENT skills, once each, against one
  target -- solo-review then probe then spar then hone. A pathway can *contain* `/spar` as one of its steps,
  composing it alongside the other skills in the chain.
- **Not the bare `Workflow` tool.** `Workflow` is the generic durable-execution engine (the same one `/spar`,
  `/hone`, `/probe` embed). `/pathway` is a specific skill that *uses* `Workflow` for exactly one job: driving a
  named skill-chain with resumable step-skip. If Douglas wants an arbitrary custom multi-stage fan-out, that's
  raw `Workflow` / `/parallelize`; `/pathway` only runs chains defined in `skill-pathways.json`.

## Why this mechanism (design rationale -- read before trusting the skip)

The whole point of this skill is *genuine* idempotent resume that goes past the detection/nudging the harness
already has. Three findings drove the design:

- **Temporal's durable-execution model.** A completed Activity's result is cached in the workflow's event
  history; on replay/retry that Activity is **skipped** -- the workflow *remembers* the cached result and
  reuses it rather than recomputing it. (docs.temporal.io/workflow-execution; Hatchet.run's durable-execution writeup.)
  This is the correct shape for "resume a half-finished pathway."
- **Chat-history recovery is a weak signal.** A 2026 finding on AI-agent recovery (the Crab paper, via
  Augment Code's durable-agent guide) measured **8-13% correctness for chat-history-only recovery vs. 100%
  for an explicit, semantics-aware checkpoint/restore**. Re-scanning the transcript for "was this step already
  done" -- exactly what the chain-suggester hook does -- is therefore the wrong mechanism to lift wholesale for
  *active* execution. The right move is an explicit external state pointer.
- **Douglas's own `Workflow` tool already implements the Temporal pattern.** `Workflow({scriptPath,
  resumeFromRunId})` replays cached `agent()` results for any call whose `(prompt, opts)` are unchanged and
  executes only what's new. So this skill does **not** hand-roll a completion tracker. It (1) embeds a Workflow
  whose loop dispatches one `agent()` per step with a **stable label** (`step-<skillName>`), so Workflow's own
  cache *is* the skip mechanism, for free; and (2) keeps a **tiny per-(chain,target) pointer file** -- lifting
  the NAMING convention of the chain-suggester's `.chain-progress.<id>.json`, but changing its CONTENTS to just
  `{ chainId, target, lastRunId, status, updatedAt }` and its SCOPING to survive across sessions -- so a later
  invocation can look up the prior `runId` and pass it as `resumeFromRunId`, letting Workflow do the actual
  skip. That is the evidenced synthesis: Temporal's replay-skip concept, implemented by Douglas's own Workflow
  tool, with the chain-suggester's file-naming convention repurposed to hold a runId pointer instead of a
  transcript-scan tally.

## Procedure

### Step 1 -- Resolve CHAIN and TARGET from ARGUMENTS

`/pathway` needs BOTH:
- **A chain**, fuzzy-matched (case-insensitive substring, on `id` or `name`) against `skill-pathways.json`'s
  `chains` array. Read the file at `C:\Users\dmcgowa2\.claude\hooks\skill-pathways.json`. If exactly one chain
  matches, use it. If **none** match, this is gate condition (a) -- list every available chain (id + name +
  its `steps`) and STOP; do not invent a chain. If **more than one** matches, list the matches and ask which.
- **A target**, resolved with the same rigor `/spar`/`/probe`/`/hone` demand: enough that a subagent with ZERO
  conversation context could act on it alone -- what it is, where it lives (path/port/URL), how to run/build/
  test it. Each composed step (solo-review/probe/spar/hone) needs a runnable target of its own. If ARGUMENTS
  lacks a target and it isn't obvious from the conversation (e.g. "/pathway harden-tail" right after
  discussing a specific app), **ask which target and how to run it -- do not guess a target.**

### Step 2 -- The gate (mandatory, BEFORE dispatching anything -- mirrors `/hone` Step 2, `/probe` Step 2)

Two real short-circuits worth checking before spending a single `agent()` call:

- **(a) Unknown chain.** If Step 1 found no chain matching the requested name, that IS the result: list the
  available chains and stop. Nothing to execute.
- **(b) Already complete.** Resolve the per-(chain,target) pointer file (Step 3) and read it. If a prior run
  for THIS exact `(chain, target)` pair has `status: "complete"` (all steps ran successfully), say so plainly
  and STOP -- do not re-invoke Workflow. Even though a resume would just replay every step from cache, that's
  wasted ceremony worth short-circuiting explicitly. (Douglas can force a fresh run by deleting the pointer
  file, whose path you print.)

### Step 3 -- Resolve the pointer file, then read any prior runId

The pointer file is the resume handle. It is **project-scoped and per-target**, so a run started in one
session resumes in a later one:

1. Determine the target's own directory (the path from Step 1; for a non-path target, use the current project
   folder). Get its project-scoped state dir with the harness's existing keyer -- run, via the Bash tool:
   `node "C:/Users/dmcgowa2/.claude/hooks/hook-state.js" statedir "<targetDir>"`. That prints
   `<root>/taskstate/<project>/` for a registered project (right next to that project's durable
   `STATUS.md`/`LOG.md`), or a basename-isolated dir otherwise -- **and it does not depend on a session id**,
   which is exactly why the pointer survives across sessions (unlike the chain-suggester's session-keyed
   `.chain-progress.<id>.<sid>.json`).
2. Build a filesystem-safe `<targetSlug>` from the target (lowercase; every run of non-alphanumerics -> `-`;
   trim leading/trailing `-`; cap ~40 chars). This disambiguates two different targets of the same chain,
   keeping the `.chain-progress.<id>` naming convention while making the file genuinely per-(chain,target).
3. The pointer path is `<stateDir>/.pathway-progress.<chainId>.<targetSlug>.json`. If it exists, read
   `lastRunId` and `status`. `status: "complete"` fires gate (b) above. `status: "partial"` (or missing/absent
   file) means run/resume: carry `lastRunId` forward as the Workflow's `resumeFromRunId` if present.

### Step 4 -- Dispatch the pathway via Workflow

Call the `Workflow` tool with the script below **verbatim**, passing
`args: { chainId: "<id>", chainName: "<name>", steps: <the chain's ordered steps array>, target: "<resolved
target + how to run/test it>" }`. If Step 3 found a prior `lastRunId` and the status was `partial`, ALSO pass
the Workflow's own option `resumeFromRunId: "<lastRunId>"` so every already-completed step replays from cache
and only the unfinished steps execute. This is an explicit skill-triggered Workflow use (per the Workflow
tool's own rule: "the user invoked a skill... whose instructions tell you to call Workflow") -- no separate
opt-in. Steps run **sequentially, one `agent()` per step, in order** -- never `parallel()`/`pipeline()`, because
a later step (e.g. `hone`) may depend on an earlier step's fixes already being in the tree.

### Step 5 -- Persist the pointer, then report

After the Workflow returns, capture the **runId the Workflow printed** and write the pointer file from Step 3
with exactly: `{ chainId, target, lastRunId: "<that runId>", status: "<complete|partial>", updatedAt:
"<ISO8601>" }` -- `status` is `complete` iff every step came back `ran`, else `partial`. Then report per "Final
report" below. On a later `/pathway <same chain> against <same target>`, Step 3 will read this `lastRunId` and
hand it back as `resumeFromRunId`, and Workflow's cache does the skipping.

## Safety constraints (apply every step, no exceptions)

- **Never dispatch a step with elevated/bypass permissions.** A generic "run the pathway" ask does not justify
  disabling the permission system, and the auto-mode classifier will correctly block a `bypassPermissions`
  mode. Every step runs at default tool permissions -- and each composed skill enforces its own safety rules
  on top (solo-review's read-only finder, probe's/hone's worktree isolation, etc.); `/pathway` does not
  loosen any of them.
- **A correct block is respected and never routed around.** If a step's skill is blocked mid-run by the
  target's own safety layer or the classifier, that is a correct block -- record that step `blocked` with the
  reason and move on to the next step. Do not reimplement the blocked action around the guard. (Same precedent as `/spar`:
  a blocked "stop any discovered process" endpoint was correctly dropped and left out rather than
  reimplemented around the guard.)
- **Continue past a failed/blocked/skipped step; never abort the whole pathway on one step.** Each step gets a
  per-step disposition (`ran` / `skipped` / `blocked` / `failed` + reason) and the sequence keeps going --
  matching `/spar`'s and `/solo-review`'s precedent of only hard-stopping a *unit of work* on a correct safety
  block, and even then the block stops only THAT step while the chain continues. A downstream step that
  genuinely depends on a failed upstream one will report its own `skipped`/`failed` with that as the reason.
- **Stay scoped to the target itself.** No killing/touching unrelated processes, files, or services; no
  destructive or irreversible action on anything shared. Cleanup is each composed skill's own responsibility
  (they restore their own worktrees/processes); `/pathway` adds only the small pointer file, whose path it
  reports.
- **No commits.** Running a pathway means invoking the step skills and recording progress -- never
  `git commit`/`git push`, unless Douglas separately asked for that. (The step skills themselves already
  hold this line.)
- **If the target keeps a tracked mirror elsewhere in this repo's convention** (e.g. this harness's
  `~/.claude` <-> `claude-global-config` split), that is the composed skill's own sync responsibility, exactly
  as when it's run standalone -- `/pathway` doesn't change it.
- **Known limitation -- no locking on the pointer file.** The `.pathway-progress.<chainId>.<targetSlug>.json`
  pointer has NO lock. Two sessions running the same `(chain, target)` pair at once can race it (last write
  wins on the pointer; both may also drive the same step concurrently). This is a stated, accepted limitation
  of v1 that the skill surfaces openly here -- don't run the same pathway against the same target from two
  sessions simultaneously. (Single-session resume across time, the actual use case, is unaffected.)

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'pathway',
  description: 'Execute a named skill-chain end-to-end against one target: one sequential agent() per step, each dispatched with a stable label so a resumeFromRunId run replays every already-completed step from Workflow cache and runs only the unfinished ones. Continues past a failed/blocked step with a per-step disposition rather than aborting the chain.',
  phases: [
    { title: 'Step' },
  ],
}

const CHAIN_ID = args.chainId
const CHAIN_NAME = args.chainName || args.chainId
const STEPS = Array.isArray(args.steps) ? args.steps : []
const TARGET = args.target

// One disposition per step. `status` continues the chain on anything but a clean 'ran' -- a blocked step is a
// CORRECT safety-layer block (recorded and respected, never routed around); a failed step errored; a skipped
// step didn't apply.
const STEP_SCHEMA = {
  type: 'object',
  properties: {
    step: { type: 'string' },
    status: { type: 'string', enum: ['ran', 'skipped', 'blocked', 'failed'] },
    invoked_via_skill_tool: { type: 'boolean' },   // true only if the named Skill was actually invoked
    summary: { type: 'string' },                    // one paragraph: what that skill found/did this step
    reason: { type: 'string' },                     // required for anything other than 'ran'
    changed_paths: { type: 'array', items: { type: 'string' } },
  },
  required: ['step', 'status', 'summary'],
}

function stepPrompt(skillName, target, position, total, priorSteps) {
  return `You are executing step ${position} of ${total} in the "${CHAIN_NAME}" pathway against a single ` +
    `shared target. THIS STEP: invoke the "${skillName}" Skill against the target below and let it run to ` +
    `completion. TARGET: ${target}\n\n` +
    `Use the Skill tool exactly as you normally would to run "${skillName}" -- do NOT substitute your own ` +
    `ad-hoc version of what that skill does; actually invoke the skill and let its own procedure drive the ` +
    `step. Run at default tool permissions; never request or use elevated/bypass permissions. Stay strictly ` +
    `scoped to the target itself.\n\n` +
    (priorSteps.length
      ? `Earlier steps in this SAME pathway already ran against the SAME target (any fixes/changes they made ` +
        `are already in the tree -- build on them, do not undo them): ${JSON.stringify(priorSteps)}\n\n`
      : '') +
    `Dispositions: if "${skillName}"'s run is correctly BLOCKED by the target's own safety layer or the ` +
    `permission classifier, that is a correct block, not a bug to route around -- record status "blocked" ` +
    `with the reason and end this step (do NOT abort the pathway; the caller continues to the next step). If ` +
    `the skill errors out or can't run for another reason, record "failed" with the reason. If it is genuinely ` +
    `not applicable to this target, record "skipped" with why. Otherwise record "ran".\n\n` +
    `Report: step (="${skillName}"), status, invoked_via_skill_tool, a one-paragraph summary of what the skill ` +
    `found/did this step, reason (for anything other than "ran"), and changed_paths (absolute paths of any ` +
    `files the skill changed this step, or []).`
}

const results = []
const priorSummaries = []

for (let i = 0; i < STEPS.length; i++) {
  const skillName = STEPS[i]
  log(`Pathway ${CHAIN_ID}: step ${i + 1}/${STEPS.length} -- invoking "${skillName}" against ${TARGET}`)
  // STABLE label + deterministic prompt per step. On a resumeFromRunId run, Workflow replays any completed
  // agent() call whose (prompt, opts) are unchanged straight from cache instead of re-dispatching it. The
  // prompt is a pure function of (skillName, TARGET, position, total, priorSummaries); priorSummaries is itself
  // rebuilt from the prior steps' own cached results on replay, so it reconstructs identically -- the whole
  // prefix of completed steps replays deterministically (Temporal's replay-determinism requirement), and only
  // the first not-yet-completed step onward actually executes.
  const res = await agent(stepPrompt(skillName, TARGET, i + 1, STEPS.length, priorSummaries),
    { phase: 'Step', schema: STEP_SCHEMA, label: `step-${skillName}` })

  const disposition = res || { step: skillName, status: 'failed', summary: '',
    reason: 'the step agent returned no usable result' }
  results.push(disposition)
  priorSummaries.push({ step: skillName, status: disposition.status, summary: disposition.summary })
  log(`Pathway ${CHAIN_ID}: step ${i + 1} "${skillName}" -> ${disposition.status}`)
  // Never abort the whole pathway on one step's failure/block -- record the per-step disposition and continue
  // to the next skill in the chain (spar/solo-review precedent: a correct safety-layer block stops only THAT
  // unit of work while the sequence continues).
}

const ranCount = results.filter(r => r.status === 'ran').length
const allRan = results.length === STEPS.length && ranCount === STEPS.length

return {
  chainId: CHAIN_ID,
  chainName: CHAIN_NAME,
  target: TARGET,
  steps: STEPS,
  stepsDispatched: results.length,
  ranCount,
  notRan: results.filter(r => r.status !== 'ran'),
  status: allRan ? 'complete' : 'partial',
  results,
  changedPaths: [...new Set(results.flatMap(r => r.changed_paths || []))],
}
```

## Final report (what to tell Douglas)

- **Which chain ran against which target**, and whether this was a fresh run or a **resume** (if a prior
  `lastRunId` was passed as `resumeFromRunId`, say which earlier steps replayed from cache vs. which actually
  executed this invocation -- that's the whole point of the mechanism, so make it visible).
- **Step-by-step table**: step (skill) -> disposition (`ran`/`skipped`/`blocked`/`failed`) -> one-line
  summary, in chain order. Anything `blocked`/`failed`/`skipped` gets its reason stated explicitly and
  surfaced -- these are exactly the items that need Douglas's call.
- **Overall status**: `complete` (every step ran) or `partial` (N of M ran; the rest need another `/pathway`
  pass or manual attention). Never claim the target is "fully hardened," "done," or "bulletproof" -- report
  what the pathway actually ran this pass and what remains, in the measured register `/spar` uses when it
  reports "no new issues across the last 2 rounds."
- **The pointer file path** (`.pathway-progress.<chainId>.<targetSlug>.json`) and its written `status`, so
  Douglas knows where the resume handle lives and can delete it to force a fresh run.
- Full absolute path(s) of anything the composed steps changed (aggregated from each step's `changed_paths`),
  per the standing Files-list convention.

---

*Tracked copy: also save this file to `claude-global-config/commands/pathway.md` (per the skills-are-tracked
convention) after a NASA scrub.*

