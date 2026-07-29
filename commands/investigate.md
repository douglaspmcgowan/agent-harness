---
name: investigate
description: Deep-dive root-cause investigation of ONE specific incident (a crash, a silently-failed hook, a security tool false-positive, a mysteriously missing file). Verifies against authoritative sources before naming a cause, and bundles the FULL damage inventory into the first report instead of a partial one. Use when Douglas says "investigate this", "figure out what actually happened", "root-cause this", or names one incident by symptom. For a broad sweep across MANY sessions looking for automation candidates, use /detective instead.
---

# /investigate — one-incident root-cause

Built 2026-07-02 after two recurring failure patterns: (1) a plausible-sounding root cause got written to memory
before being reproduced, then had to be retracted (the "harness gate" vs. "rogue plugin Stop hook" incident); (2)
a SentinelOne incident report went out on the first pass without a full damage inventory, forcing a second ask
("I also lost some hooks and other stuff as well"). This skill exists to make both mistakes structurally harder.

**Scope check first.** If Douglas's ask is "what's been going wrong across my sessions lately" / "find automation
candidates" rather than one named incident, stop and use `/detective` instead — that skill's digest-and-fan-out
approach is built for many sessions; this one is built to go deep on one.

## Procedure

### 1. Pin down the incident precisely
State back, in one line, what specifically broke (symptom, approximate time, session/project if known) before
digging. If Douglas's description is vague ("it stalled again"), ask ONE clarifying question or name your working
assumption and proceed — don't silently guess a different incident than the one he means.

### 2. Establish ground truth BEFORE hypothesizing
Never let the first plausible narrative in a transcript stand in for verified fact. For this incident, check the
actual authoritative source, not just what the session's own text claims happened:
- **A hook/process crash or silent failure** → read the actual hook script, fire it synthetically with a
  realistic payload (`spawnSync`/equivalent) and read its real stdout/stderr/exit code — don't infer from a
  one-line transcript error string alone.
- **A file went missing or changed unexpectedly** → check its mtime, `git log`/`git diff` against last known-good,
  and whether any OTHER concurrent session/process could have touched it (see [[feedback_cadforge_guards_incident]],
  and the check-secret-exposure.js race in the 2026-07-02 detective sweep, for the pattern of correlating a
  file's on-disk mtime against multiple sessions' error timestamps).
- **A security tool (SentinelOne, Defender, etc.) killed or flagged something** → pull the actual OS-level event
  log (`Get-WinEvent -LogName 'SentinelOne/Operational'` or the equivalent for the product in question) BEFORE
  concluding it's a false positive on a specific binary. Do not assume "AI tool got flagged, must be a false
  positive" without reading the actual detection record — that assumption without the log check is exactly what
  went wrong in [[project_sentinelone_ai_cli_false_positives]] the first time.
- **A permission/classifier block** → reproduce the exact denied action once (safely) rather than reasoning about
  what "probably" triggered it.

### 3. Don't write an unreproduced cause as fact
If the procedure above still leaves the cause as a strong hypothesis rather than a reproduced fact, say so
explicitly in the output — "most likely X, not confirmed" — per Douglas's own standing rule: don't write a
diagnosed root cause to durable memory until it's reproduced. A hypothesis is a lead, not a memory entry.

### 4. Bundle the FULL damage inventory on the first pass — never a partial one
Before writing up or reporting anything, always check ALL of the following, even if only one was mentioned:
- Every file that changed, was deleted, or is newly missing (`git status`, `git diff`, compare directory listing
  to last known-good if not tracked).
- Every hook/script that stopped firing or errored in the same window (grep sibling session transcripts for the
  same timestamp range — a hook crash is rarely isolated to one session if it's a shared file).
- Every session that was active/concurrent during the incident window, not just the one that surfaced the symptom.
- What is now fixed vs. still broken vs. needs Douglas's decision.
Report ALL of this in the FIRST response, not doled out across follow-up questions.

### 5. Write the fix, verify it, then write the incident note
- Fix the root cause (not just the symptom) where you can do so safely and it's clearly in scope.
- Verify the fix the same way you verified the diagnosis — reproduce, don't just reason.
- Write a short incident note: what broke, verified cause (or best hypothesis, labeled as such), evidence, the
  fix, and a regression check that would catch it recurring. For a harness/loop incident this goes in
  `Claude/Engineer/` in the vault per the "Briefs → Obsidian" rule; for a project-specific incident it goes in
  that project's own STATUS.md/LOG.md.

## What NOT to do
- Don't propose a bypass of a safety hook/classifier as "the fix" for a block you don't like — if a guard is in
  the way of something legitimate, that's itself the incident to report to Douglas, not a wall to route around
  (see Dropped #6 in the 2026-07-02 detective sweep for what this looks like when done wrong).
- Don't call something "fixed" because a classifier or test passed once — re-run the exact repro that caught it.
