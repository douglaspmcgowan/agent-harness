---
name: spar
description: "Adversarial break-fix loop: dispatch parallel breakers with distinct lenses (input-fuzzing, state/ordering, resource/perf, spec-contradiction) to break TARGET in one batch, fix every real finding with Superpowers discipline (systematic-debugging + TDD), dispatch fresh breakers against the patched target, repeat until 2 consecutive rounds find nothing new or max_iterations is hit (default 10; 2 with --fast). Use when Douglas says 'spar', 'spar with it', 'break it and fix it', 'keep attacking this until it holds', 'spar fast', '/spar'."
---

# /spar [target] [--max-iterations N] [--fast]

Sparring: attack, patch, attack again. One round is not evidence of soundness — a single clean pass just means
this round's breaker didn't find anything, not that nothing is there. This command keeps going, with fresh
adversaries each round so no single agent's blind spots stand in for "unbreakable."

## Why it was slow (bottleneck diagnosis, added 2026-07-10)

The wall-clock cost was structural, not incidental — three compounding factors:

1. **Round count, not round cost, dominated.** Each round dispatched ONE generic breaker that reported whatever
   it happened to trip over, then stopped. Reaching real coverage meant repeating rounds rather than covering
   more ground within a round, so runs routinely needed most of the 10-round ceiling to reach the 2-consecutive-
   dry-round stop condition — up to 10 sequential break→fix pairs plus the security-review pass.
2. **Every dispatch is a fresh subagent doing real, slow work.** A breaker actually runs/builds/exercises the
   live target (not a code read), and a fixer does a full RED→GREEN TDD cycle plus a full regression/self-test
   run. Each of those is genuinely several real minutes, not API latency — so total time is round count times
   several minutes per round, times two (break + fix), serialized because each round's breaker needs the prior
   round's fix already applied before it can re-attack.
3. **Fixing was already batched per round** (one fixer call per round handles that round's whole findings list,
   one regression check at the end) — this was not the bottleneck. The lever that actually cuts time is making
   each round find more per dispatch, and doing round 1's dispatches concurrently instead of serially.

The changes below attack factor 1 and 2 directly: parallel lensed breakers cover more distinct attack surface
per wall-clock minute than one generic breaker covers per round, and `--fast` caps the round ceiling itself for
when a full 10-round sweep isn't warranted. Factor 3 (batching) is preserved and made explicit rather than
changed, since it wasn't where the time went.

## What this is NOT

Not `/solo-review` or `/panel-ultra-review` — those are strictly **read-only**: they read code and reason about
what could go wrong, and never touch the target. `/spar` is the opposite: every round's breaker must actually
**run** the target and cause real failures live, and every round's fixer actually **edits** the target. If Douglas
wants findings without any code changes, point him at `/solo-review` instead.

## Procedure

1. **Resolve TARGET from ARGUMENTS.** Needs enough detail that a subagent with ZERO conversation context could
   act on it alone: what it is, where it lives (path/port/URL), how to run/build/test it, and any existing
   test/self-test entry point. If ARGUMENTS is missing this and it isn't obvious from the conversation (e.g. "spar
   with the dashboard" right after discussing a specific app), ask which target and how to run it before
   proceeding — don't guess at a runnable target.
2. **Resolve mode and max_iterations.** Parse `--fast` and `--max-iterations N` from ARGUMENTS. Default
   `fast: false`, `maxIterations: 10`. If `--fast` is present and `--max-iterations` is not, default
   `maxIterations` to **2** instead — `--fast` trades round-count assurance for speed; an explicit
   `--max-iterations` always wins if Douglas gave one, even alongside `--fast`.
3. **Call the `Workflow` tool** with the script template below verbatim, passing
   `args: { target: "<resolved target description>", maxIterations: <N>, fast: <bool> }`. This is an explicit
   skill-triggered Workflow use (per the Workflow tool's own rule: "the user invoked a skill... whose instructions
   tell you to call Workflow") — no separate opt-in needed. The script runs a Security Review pass FIRST (see
   below), then the adversarial Break/Fix loop — round 1 always dispatches parallel lensed breakers (see
   "Parallel lensed breakers" below); `fast` additionally caps rounds at `maxIterations` and keeps every round
   parallel/time-boxed instead of just round 1.
4. **Report the result** (see "Final report" below). Never claim the target is "unbreakable" — report "no new
   issues found across the last 2 rounds" or "stopped at max_iterations with N still open," which is what actually
   happened.

## Security Review — runs once, before Round 1 (added 2026-07-07, Douglas's explicit request)

Anthropic's built-in `security-review` skill is a distinct, established check (vulnerabilities: injection,
auth, secrets, unsafe deserialization, etc.) — different in kind from the adversarial breaker, which finds
functional/behavioral bugs by actually attacking the running target. Running it first means known-shape
security issues get caught by a purpose-built pass before the general-purpose breaker starts, rather than
relying on the breaker to stumble into them. Findings from this pass feed the SAME fixer used for every
other round (RED/GREEN/regression-check discipline, no unrelated changes) — it is not a second, separate
fix mechanism, just a different SOURCE of findings for round 0.

## Parallel lensed breakers (default, added 2026-07-10)

Round 1 always dispatches four breakers concurrently instead of one, each pointed at a distinct lens —
input-fuzzing, state/ordering, resource/perf, spec-contradiction (see the script's `LENSES` constant for the
exact focus text each gets). This is the direct fix for "couldn't one agent break it in multiple ways before
sending a fixer": now four agents each break it in one way, at the same time, and their findings merge into a
single batch before the fixer ever runs. A lightweight token-overlap dedupe drops near-duplicate findings
across lenses before the fixer sees them; the fixer prompt also groups its edits by file and is told to treat
any leftover duplicate as one fix, not four. In the default (thorough) mode, rounds after round 1 revert to the
original single-breaker-with-full-history pattern — by then the loop is mostly re-verifying prior fixes and
hunting for what four lenses' worth of round 1 missed, which doesn't need four concurrent agents. In `--fast`
mode every round (there are at most 2) uses the parallel-lens dispatch, since there's no round 3+ left to
catch what a single breaker would miss.

## `--fast` mode (added 2026-07-10)

For when a full 10-round sweep isn't warranted — a smaller change, a quick sanity pass, or Douglas explicitly
wants speed over the last increment of assurance. `--fast`:
- caps `maxIterations` at **2** (unless Douglas also passed an explicit `--max-iterations`, which wins),
- keeps every round's breaker dispatch parallel/lensed, not just round 1,
- adds a time-box clause to each breaker/fixer prompt: prioritize breadth across the lens's likely failure
  modes over chasing one obscure edge case to exhaustion.

The thorough default (10 rounds, single-breaker rounds after round 1, no time-box clause) is unchanged unless
`--fast` is passed — this is an opt-in trade, not a replacement.

## Safety constraints (apply every round, no exceptions)

- **Never dispatch the breaker or fixer with elevated/bypass permissions.** A generic "give it full access" ask is
  not specific enough to justify disabling the permission system, and the auto-mode classifier will correctly
  block a `bypassPermissions` mode on a general "break/fix this" goal. Run both at default tool permissions.
- **If the target's own safety layer (or the classifier) blocks an action mid-round, that is a correct block, not
  a bug** — do not route around it. Narrow scope and try a different angle instead (this is the established
  pattern: an attempt to add a "stop any discovered process" endpoint was blocked as unsafe and correctly dropped
  rather than reimplemented around the block).
- **Stay scoped to the target itself.** No killing/touching unrelated processes, files, or services; no
  destructive or irreversible action on anything shared. Both breaker and fixer must restore any state they
  changed (stop what they started, leave `git status` clean of anything unexpected) and confirm they did, before
  finishing.
- **The fixer makes only the change each finding requires** — no unrelated refactors, no drive-by cleanup, no
  speculative abstractions beyond the fix. If a finding can't be fixed safely in scope (fixing it would itself
  require bypassing a safety mechanism, or it needs Douglas's judgment call), it reports `skipped`/`wont_fix` with
  a reason instead of forcing it through.
- **No commits.** Fixing means editing and verifying, never `git commit`/`git push`, unless Douglas separately
  asked for that.
- **If the target keeps a tracked mirror elsewhere in this repo's convention** (e.g. this harness's
  `~/.claude` ↔ `claude-global-config` split), the fixer keeps the mirror in sync as part of each round.

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'spar',
  description: 'Adversarial break-fix loop: parallel lensed breakers attack the target in batch, fix with TDD, repeat until clean or max iterations',
  phases: [
    { title: 'Security Review' },
    { title: 'Break' },
    { title: 'Fix' },
  ],
}

const TARGET = args.target
const FAST = !!args.fast
const MAX_ITERATIONS = args.maxIterations || (FAST ? 2 : 10)

// Distinct attack lenses for round 1's (and, in --fast, every round's) parallel breaker dispatch.
const LENSES = [
  { key: 'input-fuzzing', focus: 'malformed, boundary, oversized, wrong-type, and adversarially crafted input at every entry point' },
  { key: 'state-ordering', focus: 'concurrency, race conditions, out-of-order calls, and partial/interrupted operations that leave state inconsistent' },
  { key: 'resource-perf', focus: 'resource exhaustion, timeouts, large/slow inputs, and degenerate-scale performance cases' },
  { key: 'spec-contradiction', focus: "places where the target contradicts its own stated spec/docs/comments, or where two of its own behaviors conflict with each other" },
]

// Cheap token-overlap dedupe so near-duplicate findings from different lenses don't reach the fixer as separate
// items. Keeps the first occurrence; anything with >60% word overlap with an already-kept finding is dropped.
function dedupeFindings(findings) {
  const kept = []
  const keptTokens = []
  for (const f of findings) {
    const tokens = new Set((f.description || '').toLowerCase().replace(/[^a-z0-9 ]/g, '').split(/\s+/).filter(Boolean))
    const isDup = keptTokens.some(s => {
      const inter = [...tokens].filter(t => s.has(t)).length
      const union = new Set([...tokens, ...s]).size
      return union > 0 && inter / union > 0.6
    })
    if (!isDup) { kept.push(f); keptTokens.push(tokens) }
  }
  return kept
}

const BREAK_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
          description: { type: 'string' },
          repro: { type: 'string' },
          evidence: { type: 'string' },
        },
        required: ['id', 'severity', 'description', 'repro', 'evidence'],
      },
    },
    state_restored: { type: 'boolean' },
    notes: { type: 'string' },
  },
  required: ['findings', 'state_restored'],
}

const FIX_SCHEMA = {
  type: 'object',
  properties: {
    results: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          status: { type: 'string', enum: ['fixed', 'skipped', 'wont_fix'] },
          evidence: { type: 'string' },
          reason: { type: 'string' },
        },
        required: ['id', 'status', 'evidence'],
      },
    },
    regression_check: { type: 'string' },
  },
  required: ['results'],
}

function breakerPrompt(target, priorFixed, lens, timeBoxed) {
  const angleClause = lens
    ? `For this dispatch, concentrate your attack through this lens: ${lens.focus}. Work through it ` +
      `exhaustively -- try several distinct angles within it, not just the first one that occurs to you -- ` +
      `before concluding you're done. If you trip over something obviously broken outside this lens, still ` +
      `report it, but don't go hunting outside your lens at the expense of covering it thoroughly.\n\n`
    : `Work through multiple distinct attack angles yourself in this one dispatch -- input-fuzzing ` +
      `(malformed/boundary/oversized/wrong-type input), state/ordering (concurrency, races, partial/` +
      `interrupted operations), resource/perf (exhaustion, timeouts, degenerate scale), and spec-contradiction ` +
      `(places the target contradicts its own docs/comments/behavior) -- rather than stopping at the first ` +
      `issue you find and calling the round done.\n\n`
  const timeClause = timeBoxed
    ? `This is a fast, time-boxed pass -- prioritize breadth across the likely failure modes over chasing one ` +
      `obscure edge case to exhaustion.\n\n`
    : ''
  return `You are a rigorous, hostile adversary. Your ONLY goal is to break the following target in as many ` +
    `real ways as you can: ${target}\n\n` +
    angleClause + timeClause +
    `Do NOT just read the code and speculate -- actually run it, send it real crafted/malformed/concurrent/` +
    `edge-case input, race it, exhaust it, whatever it takes. Every finding you report must be something you ` +
    `personally reproduced live, with exact repro steps and the actual output/evidence you saw -- not a ` +
    `hypothetical. Stay strictly scoped to the target itself: never take an action with effects outside it ` +
    `(no killing unrelated processes, no touching unrelated files/services, no destructive or irreversible ` +
    `action on shared systems). Do not request or use elevated/bypass permissions. If the target's own safety ` +
    `layer blocks an action you try, that is a correct block, not a bug to route around -- drop that avenue and ` +
    `try a different one. Before you finish, restore any state you changed (stop anything you started, revert ` +
    `anything you edited) and confirm you did (e.g. git status shows nothing unexpected, processes you started ` +
    `are stopped).\n\n` +
    (priorFixed.length
      ? `These issues were already found and fixed in earlier rounds -- verify each is GENUINELY still fixed ` +
        `(try to re-break them specifically) before looking for new ones: ${JSON.stringify(priorFixed)}\n\n`
      : '') +
    `Report every distinct real issue you found this round, each with a stable id, severity, description, exact ` +
    `repro steps, and the evidence you observed. If you found nothing after a genuine, thorough attempt, say so ` +
    `plainly rather than padding with speculative or trivial issues.`
}

function fixerPrompt(target, findings) {
  return `The following real, live-reproduced issues were just found in: ${target}\n\n` +
    `FINDINGS:\n${JSON.stringify(findings, null, 2)}\n\n` +
    `Fix the WHOLE batch above using rigorous engineering discipline, before running any regression check -- ` +
    `group your edits by file (findings touching the same file get fixed together, in one pass, to avoid ` +
    `conflicting edits) rather than working file-by-finding. For each: root-cause it first (don't patch a ` +
    `symptom), reproduce it with a failing test BEFORE changing any implementation code (RED), make the ` +
    `minimal change that makes the test pass (GREEN). If two findings turn out to be the same underlying bug ` +
    `under different ids, fix it once and mark both ids resolved by that one fix, noting which id was the ` +
    `canonical fix. Once the whole batch is fixed, re-run the target's full existing test/self-test suite ONE ` +
    `time to confirm no regression -- not once per finding. Make ONLY the change each finding requires -- no ` +
    `unrelated refactors, no drive-by cleanup, no speculative abstractions. If the target keeps a tracked ` +
    `mirror copy elsewhere in this repo's convention, keep it in sync. If a finding turns out to be unfixable ` +
    `safely in scope (e.g. fixing it would require an action a safety layer correctly blocks, or it needs a ` +
    `human judgment call), mark it "skipped" or "wont_fix" with a clear reason instead of forcing a workaround ` +
    `-- do not disable or bypass any safety mechanism to force a fix through. Never commit.\n\n` +
    `Report, per finding id: status (fixed/skipped/wont_fix), the evidence that proves it (e.g. the failing-` +
    `then-passing test output, or a live re-check), and for anything not fixed, why. Also report the result of ` +
    `the single full regression/self-test run after the whole batch.`
}

function securityReviewPrompt(target) {
  return `Invoke the "security-review" Skill against the following target and report its findings: ${target}\n\n` +
    `Use the Skill tool exactly as you normally would to run a security review -- injection, auth/access ` +
    `control, secret handling, unsafe deserialization, SSRF, and whatever else that skill's own methodology ` +
    `covers. Do not substitute your own ad-hoc review for it; actually invoke the skill.\n\n` +
    `Report every distinct real finding with a stable id, severity, description, exact repro/location, and ` +
    `the evidence (the specific code/config that's vulnerable and why). If the skill finds nothing, say so ` +
    `plainly rather than inventing findings to fill the report.`
}

const rounds = []
let stopReason = null
let dryStreak = 0
const fixedSoFar = []

log(`Security Review: running Claude Code's built-in security-review skill against ${TARGET} before the adversarial loop starts`)
const securityResult = await agent(securityReviewPrompt(TARGET), { phase: 'Security Review', schema: BREAK_SCHEMA, label: 'security-review' })
let securityFixResult = null
if (securityResult && securityResult.findings && securityResult.findings.length > 0) {
  log(`Security Review: found ${securityResult.findings.length} issue(s) -- dispatching fixer before Round 1`)
  securityFixResult = await agent(fixerPrompt(TARGET, securityResult.findings), { phase: 'Fix', schema: FIX_SCHEMA, label: 'security-review-fix' })
  const fixed = (securityFixResult?.results || []).filter(r => r.status === 'fixed')
  fixedSoFar.push(...fixed.map(r => ({ id: r.id, evidence: r.evidence })))
} else {
  log('Security Review: no findings')
}

for (let i = 1; i <= MAX_ITERATIONS; i++) {
  // Round 1 always parallelizes across lenses (this is what replaces "one breaker, one breakage, one round").
  // In --fast mode every round does, since there's at most 2 rounds total and no round 3+ left to catch what
  // a single generic breaker misses.
  const useLenses = i === 1 || FAST
  let findings

  if (useLenses) {
    log(`Round ${i}/${MAX_ITERATIONS}: dispatching ${LENSES.length} parallel breakers (${LENSES.map(l => l.key).join(', ')}) against ${TARGET}`)
    const lensResults = await parallel(LENSES.map(lens => () =>
      agent(breakerPrompt(TARGET, fixedSoFar, lens, FAST), { phase: 'Break', schema: BREAK_SCHEMA, label: `break-r${i}-${lens.key}` })
    ))
    const merged = lensResults.flatMap(r => r?.findings || [])
    findings = dedupeFindings(merged)
    if (merged.length !== findings.length) {
      log(`Round ${i}: ${merged.length} raw finding(s) across lenses, deduped to ${findings.length} distinct`)
    }
  } else {
    log(`Round ${i}/${MAX_ITERATIONS}: dispatching breaker against ${TARGET}`)
    const breakResult = await agent(breakerPrompt(TARGET, fixedSoFar, null, FAST), { phase: 'Break', schema: BREAK_SCHEMA, label: `break-r${i}` })
    findings = breakResult?.findings || []
  }

  if (findings.length === 0) {
    dryStreak++
    rounds.push({ round: i, found: 0, fixed: 0, findings: [], fixResults: [] })
    log(`Round ${i}: breaker(s) found nothing (dry streak ${dryStreak}/2)`)
    if (dryStreak >= 2) { stopReason = 'clean'; break }
    continue
  }
  dryStreak = 0

  log(`Round ${i}: breaker(s) found ${findings.length} distinct issue(s) -- dispatching fixer for the whole batch`)
  const fixResult = await agent(fixerPrompt(TARGET, findings), { phase: 'Fix', schema: FIX_SCHEMA, label: `fix-r${i}` })

  const fixed = (fixResult?.results || []).filter(r => r.status === 'fixed')
  fixedSoFar.push(...fixed.map(r => ({ id: r.id, evidence: r.evidence })))

  rounds.push({
    round: i,
    found: findings.length,
    findings,
    fixResults: fixResult?.results || [],
    regressionCheck: fixResult?.regression_check || null,
  })

  if (i === MAX_ITERATIONS) stopReason = 'max_iterations'
}

const allFindings = rounds.flatMap(r => r.findings || [])
const allFixResults = rounds.flatMap(r => r.fixResults || [])
const stillOpen = allFixResults.filter(r => r.status !== 'fixed')

return {
  target: TARGET,
  maxIterations: MAX_ITERATIONS,
  fast: FAST,
  securityReview: {
    findings: securityResult?.findings || [],
    fixResults: securityFixResult?.results || [],
  },
  iterationsRun: rounds.length,
  stopReason: stopReason || 'max_iterations',
  rounds,
  totalFound: allFindings.length + (securityResult?.findings?.length || 0),
  totalFixed: allFixResults.filter(r => r.status === 'fixed').length + (securityFixResult?.results || []).filter(r => r.status === 'fixed').length,
  stillOpen: [...stillOpen, ...(securityFixResult?.results || []).filter(r => r.status !== 'fixed')],
}
```

## Final report (what to tell Douglas)

- **Mode used**: thorough (default) or fast (`--fast`), and `maxIterations` actually in effect.
- **Security Review results first**: findings from the built-in security-review skill (run once, before Round 1)
  and their fix status — labeled distinctly from the adversarial rounds since they came from a different
  mechanism (a purpose-built skill, not a hostile breaker agent).
- **Stop reason**: `clean` (2 consecutive dry rounds — the honest phrasing is "no new issues found across the
  last 2 rounds," not "unbreakable") or `max_iterations` (N still open, needs another `/spar` pass or manual
  attention).
- **Round-by-round table**: round # → lensed (parallel) or single breaker → found → fixed → skipped/wont_fix
  (with reasons).
- **Anything `skipped`/`wont_fix`**, listed explicitly with why — these are exactly the kind of finding that
  needs Douglas's call, not a silently dropped item.
- Full absolute path(s) of anything changed, per the standing Files-list convention.

---

*Tracked copy: also save this file to `claude-global-config/commands/spar.md` (per the skills-are-tracked
convention) after a NASA scrub.*
