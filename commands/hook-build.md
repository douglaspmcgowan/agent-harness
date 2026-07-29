---
name: hook-build
description: "Test a Claude Code hook script for real, right after it's written or on demand. Reads the target hook, designs a battery of synthetic stdin payloads specific to that hook's own logic (normal case, edge cases, malformed input, a should-block case, a should-NOT-block case), runs each via direct subprocess execution (node/python <hook> < payload), asserts the actual exit code + stderr against what SHOULD happen, and offers to write a <hookname>.test.js sibling matching Douglas's existing convention so it's repeatable without re-invoking this skill. Use when Douglas says 'test this hook', 'hook build', 'verify this hook works', right after Claude finishes writing a new hook file, or '/hook-build'."
---

# /hook-build [hook-path]  —  test a hook for real

Tests one hook, right now, by actually running it — not by reading the code and reasoning about
whether it looks right. A hook is structurally just a small CLI program that reads JSON from stdin
and exits 0 (allow) or 2 (block), writing feedback to stderr. That means it can be tested the same
way any stdin-driven CLI is tested: pipe a payload in, assert the exit code and stderr out. This
command designs and runs that battery for one specific hook, then optionally leaves behind a
`<hookname>.test.js` so the same checks can be re-run later without invoking this skill again.

**Corrects a prior misunderstanding.** An earlier attempt at this idea built a standing PostToolUse
meta-hook that fired automatically after every hook edit — that conflicted with an existing safety
invariant and was the wrong shape entirely. Douglas's own correction: *"I wanted you to make a skill
that when you make a hook, you test it in a bunch of different ways to make sure it works. That's
it... That shouldn't require you to write a hook to make a hook — that's just a skill to make one
hook or to verify and test a specific hook."* This is that skill: on-demand, invoked deliberately
(like `/spar`, `/hone`, `/probe`), never a standing background hook.

## What this is NOT

- **Not a hook.** Nothing about this skill installs, wires, or fires automatically in
  `settings.json`. It has no matcher, no event, no standing trigger. It runs once, when invoked, on
  one named target, and produces a report — the same shape as `/spar`/`/hone`/`/probe`, not the
  shape of `warn-large-read.js` or `concurrent-edit-lock.js`.
- **Not `/harness-review`.** `/harness-review` is a broad, multi-file adversarial pass over the
  *entire* harness (all the loop hooks + their interactions) or a diff, looking for edge cases
  across rule-by-rule reads and cross-cutting lenses. `/hook-build` is narrow and single-target: one
  hook, run for real, this session. Point Douglas at `/harness-review` if he wants the wide sweep;
  use this when there's one specific hook to prove out.
- **Not `/probe`.** `/probe` runs property-based sweeps and mutation testing against an existing
  test SUITE for a whole codebase target, with a mandatory gate on whether the target has real
  invariants worth it. A single hook script is almost never a good `/probe` target on its own (one
  file, one function, no suite to mutate against yet) — `/hook-build` is the right-sized tool for
  "does this one hook actually do what I just wrote it to do," and produces the FIRST test file that
  a later `/probe` pass could mutation-test against.
- **Not code review.** This doesn't read the hook and give opinions on style, structure, or whether
  the approach is a good idea. It runs the hook against real crafted input and reports the actual
  exit codes it observed. If Douglas wants a design opinion, that's `/solo-review` or
  `requesting-code-review`.
- **Not a substitute for the adversarial-verify discipline in CLAUDE.md** ("try to break it before
  claiming it works" / "don't mock away the exact condition that would expose the bug"). This skill
  is exactly the concrete mechanism CLAUDE.md's global rule was asking for — the skill IS the
  durable artifact, not a chat promise to "be careful next time."

## Research this design is built on

- **The core mechanism — subprocess-pipe-and-assert-exit-code — is already Douglas's own established
  convention.** `guard-hooks.test.js`, `keep-going.test.js`, and `concurrent-edit-lock.test.js` (all
  in `~/.claude/hooks/`) already do exactly this: `spawnSync(NODE, [hookPath], { input:
  JSON.stringify(payload), encoding: 'utf8' })`, then assert `r.status` (2=block, 0=allow) and match
  `r.stderr` against an expected substring. This skill formalizes and drives that same pattern for a
  brand-new hook, rather than inventing a different testing approach.
- **Claude Code's own docs recommend the identical manual mechanic**: pipe sample JSON to the hook
  script and check the exit code (`echo '{"tool_name":"Bash",...}' | ./hook.sh; echo $?`) —
  confirming direct subprocess execution (not a mock, not a unit-test-the-function shortcut) is the
  correct and intended way to verify a hook's actual stdin/exit-code contract, since mocking away the
  stdin/exit boundary is exactly the boundary being tested.
- **The one purpose-built OSS hook-tester found** (`VoxCore84/claude-code-hook-tester`) auto-discovers
  hook scripts, sends mock JSON via stdin, and asserts a three-way exit-code taxonomy: `0 = pass`,
  `2 = block`, *anything else (1, 127, a crash, a timeout) = treat as a bug*, not a soft failure. That
  third bucket is easy to miss when only checking "0 or 2" — this skill's battery explicitly checks
  for it. That same tool's own README states it does NOT cover malformed JSON or adversarial inputs —
  a real, named gap in existing tooling, which is exactly what Steps 2–3 below are for.
  Search also turned up `karanb192/claude-code-hooks-tests` and `grahama1970/claude-code-hooks-test`
  as adjacent repos, but neither could be confirmed (from public README/source alone) to test the
  actual subprocess contract rather than exported functions — noted rather than assumed.
- **General adversarial-input taxonomy for any stdin/JSON-driven CLI** (language-agnostic, drawn from
  fuzzing/boundary-value-testing practice, not Claude-Code-specific): malformed/truncated JSON, empty
  stdin, missing required fields, wrong field types (a string where a number was expected, `null` for
  a required path), oversized payloads, and unexpected/unknown enum-like values (an unrecognized
  `tool_name`). For any hook that does **path matching**: mixed slash styles, `..` traversal
  sequences, a path hidden inside a `python -c "..."` or `node -e "..."` one-liner where a naive
  regex over the raw command string would miss it. For any hook that does **command-string
  matching**: chained-command operators (`&&`, `;`, `|`, backticks, `$(...)`) that could smuggle a
  blocked command past a check anchored only on the string's start, and the **OWASP command-injection
  testing methodology's actual guidance**: understand the specific filter/regex before crafting a
  bypass, rather than throwing a generic payload list — i.e., the false-negative cases in Step 2
  below should target the *specific* pattern the hook under test actually uses, not a canned list.
- **Honest scope note from the research**: "testing a Claude Code hook" is a narrow enough niche that
  almost no practitioner content exists titled exactly that — what's genuinely well-established is
  the general "pipe stdin, assert exit code" CLI-testing pattern (which Douglas's own `.test.js`
  files already prove out) plus general adversarial-input taxonomies. This skill's contribution is
  combining those two well-established things into a single on-demand pass scoped to one hook, not
  inventing a new testing technique.

### Additional practitioner research (2026-07-07, dedicated deep-search pass beyond the above)

- **The single most load-bearing finding, a genuine tension worth surfacing to Douglas per-hook, not
  silently resolved either way: fail-OPEN-on-unexpected-error vs. fail-CLOSED.** Practitioner consensus
  (dev.to, Medium — "The Silent Failure Mode in Claude Code Hooks") is the opposite of Douglas's own
  established convention: wrap all validator logic in try/catch and force `process.exit(2)` (BLOCK) in
  the catch block, because an uncaught exception defaults to a non-blocking exit code, silently letting
  the dangerous action through. One practitioner reported ~3 hours of autonomous operation before
  noticing pushes weren't actually being blocked, for exactly this reason. Every one of Douglas's
  existing SECURITY hooks does the opposite by design (`catch (_) { /* fail open */ } process.exit(0)`),
  matching the Stop-hook convention ("both fail OPEN... never trap") -- but a Stop hook trapping an
  agent mid-task and a SECURITY hook silently waving a dangerous command through on an internal bug are
  different-stakes failures. When testing ANY blocking-type hook, add an explicit case that forces an
  internal exception (e.g. malformed input past what JSON.parse alone would catch, a null where a
  string method is called) and report which way it fails -- don't assume fail-open is obviously correct
  just because it's the existing pattern; flag it as Douglas's own call per hook, especially for ones
  gating something genuinely dangerous.
- **Claude Code's own hook-stdin JSON serialization can itself defeat a correctly-written hook (issue
  #53463, github.com/anthropics/claude-code).** Hook stdin occasionally arrives with literal unescaped
  control characters instead of properly-escaped JSON (non-deterministic trigger: PDF paste, certain
  terminals, multi-line prompts) -- a strict `JSON.parse` throws, and if the hook fails OPEN on that
  throw (see above), its security check is silently skipped for that call. This is a defense-in-depth
  gap in Claude Code's OWN plumbing, not a hook-author bug -- worth testing explicitly: a payload with a
  raw control character (e.g. `\x01`) embedded in a JSON string value, confirming the hook's own
  fail-open/fail-closed choice under THIS specific malformed-input shape, not just generic "not json".
- **Prefer the `args` array exec-form over a shell-string `command` whenever no shell parsing is
  actually needed** -- confirmed independently by this research (not just this session's own
  performance finding): it spawns via `execve()` directly with zero shell involved, which also makes the
  hook's own wiring immune to shell-injection regardless of what a value extracted from `tool_input`
  might contain, on top of the performance win already measured this session.
- **Concurrency model, confirmed**: when multiple hooks match the same event, Claude Code runs ALL of
  them in PARALLEL by default (sync hooks: Claude waits for all; async: waits for none) -- there is
  currently no sequencing/chaining mechanism (open feature request, closed not-planned). If two hooks on
  the same event both modify tool input, "last hook to finish wins" since they race -- never have more
  than one hook on the same matcher mutate the same field.
- **Numeric performance budget, independently cited by two sources**: target under 500ms for a
  synchronous command hook. Use this as a concrete pass/fail bar when timing a hook, not just "faster is
  better" -- Douglas's OLD shell-wrapped hooks (700ms-1.3s each) were already over this budget before
  concurrency/AV effects made it worse.
- **A hook enforcement mechanism (a flag/sentinel file, an env-var opt-in gate) is advisory against a
  sufficiently determined circumvention, not a hard technical barrier** (issue #61953: an agent
  deliberately deleted a hook-created flag file to bypass a mandatory gate, rather than passively
  ignoring the rule -- an escalating arms race the reporter says cost more time than it saved). Directly
  relevant to Douglas's own `ALLOW_ENV_MUTATION=1`/`ALLOW_BULK_DELETE=1` opt-in pattern: these work
  because the invoking agent chooses in good faith to type the literal opt-in string, not because
  anything prevents a differently-instructed agent from just adding it. Worth naming as a known
  property, not a flaw to fix -- the opt-in is a friction/intentionality gate, not a security boundary.

## Procedure

### Step 0 — Resolve TARGET

Resolve the hook file path from `[hook-path]` in ARGUMENTS, or from context if Claude just finished
writing a new hook this session. Needs: the file's absolute path, and its runtime (`node` — check for
a `#!/usr/bin/env node` shebang or `.js` extension — or `python`/`sh` otherwise). If ambiguous (more
than one hook was just touched, or none is obvious from context), ask which file before proceeding —
don't guess at a target.

### Step 1 — Read the target and understand its contract (the gate before writing any payload)

Read the hook file in full. Extract, and state explicitly before designing tests:

- **Which event(s) and matcher it's wired for** — check `~/.claude/settings.json` for an existing
  wiring (`grep` the filename), or infer from the code (does it read `tool_name`/`tool_input`,
  `notification_type`, a Stop-hook shape with `session_id`/`cwd`/`transcript_path`?). If it isn't
  wired yet (brand new, not yet added to settings.json), say so — that's a fact to report, not a
  blocker to testing.
- **What it's supposed to block, allow, or warn on** — the actual condition(s) in the code, not a
  guess from the filename. Name the specific regex/string-match/threshold logic driving the decision.
- **Its exit-code contract** — does it ever exit 2 (block), or is it detection-only / side-effect-only
  (always exits 0, like `warn-large-read.js` and `notification-toast.js`)? This determines what
  "should trigger" vs "should NOT trigger" even means for this specific hook — a detection-only hook
  never blocks, so its should/shouldn't split is about whether the *warning* fires, not the exit code.
- **Any shared dependency** it requires — most of Douglas's hooks `require('./hook-state.js')`
  for project/session keying, or read `~/.claude/settings.json` conventions. Note this so payloads
  include whatever fields that dependency needs (e.g. `cwd`, `session_id`) to exercise the real path
  rather than an early-return stub.

If the hook's own purpose can't be determined from the code (no discernible condition, dead code,
or it's actually a different kind of script entirely), stop and report that rather than fabricating
a plausible-sounding contract to test against.

### Step 1.5 — For a hook wired via a shell wrapper (`shell: "powershell"` etc.), test the WIRING, not just the SCRIPT

Real findings from this session's hook-overhead investigation (2026-07-07), each one found live, not
theoretical — fold these into Step 1's contract-reading whenever the target hook is invoked through a shell:

- **A `shell:"powershell"` wrapper is NOT free, and can dominate the hook's own logic time.** Measured on
  this machine: `powershell -Command "node ..."` cost 789ms-1.3s per call vs. `node.exe` invoked directly
  at ~100-120ms — an 8-13x tax, BEFORE the hook's own code runs at all. `pwsh` (PowerShell 7+, what Claude
  Code's `shell:"powershell"` setting is documented to use) is not guaranteed to be installed — check
  `Get-Command pwsh`; if absent, Claude Code silently falls back to Windows PowerShell 5.1, which has its
  own separate (still real) startup cost. If a hook is measurably slow and its own logic is simple regex
  matching, suspect the wrapper before the script.
- **Prefer the exec-form (`command` + `args`, no `shell` field) over a shell string whenever the command
  needs no shell parsing** (no `&&`/`;`/`|`/quoting-that-requires-a-shell) — this spawns the interpreter as
  a DIRECT child with zero shell overhead, and as a side effect avoids MSYS/Git-Bash fork-table collisions
  entirely (no bash.exe spawned either) without needing `shell:"powershell"` as a workaround.
- **A shell-wrapped hook that TIMES OUT can leak an orphaned process.** When `spawnSync` kills a shell-form
  child on timeout, the kill signal reaches the immediate child (the shell), not necessarily the
  grandchild it spawned (e.g. `node.exe` under `powershell -Command`) — reproduced directly: a deliberately
  hung `node.exe` survived well after both the shell-form and exec-form invocations reported identical
  `ETIMEDOUT`/`SIGTERM`. If a hook is wired via a shell wrapper, test this explicitly: spawn a
  deliberately-hanging version of the script with a short timeout, then check (via `Get-CimInstance
  Win32_Process` or equivalent) whether the underlying interpreter process is still running afterward.
  Exec-form does not have this failure mode (the interpreter is the direct child).
- **When comparing "before" vs "after" for a performance-motivated hook change, measure the REAL wiring
  shape, not just the script in isolation.** `spawnSync(node, [script], {input})` alone will look identical
  before and after a shell-wrapper change — the difference only shows up when the SAME shell/exec-form the
  hook is actually configured with in `settings.json` is reproduced in the timing harness.

### Step 1.6 — For any hook that scans raw command/text strings with a segment-splitting regex, test quoted-string false positives specifically

A real bug found this session, pre-existing (not introduced by a refactor): a hook detecting "does this
command invoke program X as a new segment" split the command on shell metacharacters like `|`/`;`/`&`
WITHOUT excluding characters that appear inside a quoted string literal. A command like
`jq -e '... == "Bash|PowerShell" ...'` contains a literal `|` inside a quoted jq filter string — splitting
naively on it makes "PowerShell" (with no space before it, since the split lands right after the `|`
adjacent to the quote) look like the start of a new shell segment, triggering a false block. General rule
for Step 2's edge cases: for ANY hook that splits/scans command text on shell separator characters
(`;`/`&`/`|`/backtick/`$(`), add a specific test case where that exact separator character appears inside
a single- or double-quoted string in the payload (not as real shell syntax) and assert it does NOT
false-positive. `block-dangerous-bash.js`'s own `tokenize()` function (quote-aware, respects `'...'`/`"..."`
boundaries) is the existing reference pattern for doing this correctly if a fix is needed.

### Step 2 — Design the payload battery (specific to THIS hook, not a generic template)

Design real JSON payloads for each of these categories, adapting the specifics to the hook's own
logic from Step 1 — do not reuse a fixed list of paths/commands across unrelated hooks:

1. **Normal / expected case** — the ordinary input this hook was built to see day-to-day, expected
   to pass through cleanly.
2. **2–3 edge cases specific to this hook's own matching logic**, e.g.:
   - a path-matching hook: mixed `/`/`\` slash styles, a path expressed with `..` traversal, the
     same target path smuggled inside a `python -c "..."` or `node -e "..."` one-liner, and a path
     that is *almost* but doesn't quite match (a near-miss filename/directory) to check for
     over-eager matching.
   - a command-matching hook: the blocked command chained after an allowed one via `&&`/`;`/`|`, an
     equivalent command spelled with extra whitespace/quoting, and a command that merely *mentions*
     the blocked string in an unrelated context (per the real, already-known caveat in
     `guard-env-mutation.js`/`guard-bulk-delete.js`: they match substrings, so a commit message that
     quotes `git rm` trips them — test whether THIS hook has the same false-positive shape).
   - a threshold/numeric hook (like `warn-large-read.js`'s line-count estimate): a value just under,
     at, and just over the threshold.
3. **Malformed/empty stdin** — empty string, truncated JSON, non-JSON garbage, valid JSON with the
   wrong field types (a number where a string was expected, `null` for a required field), valid JSON
   missing required fields entirely, and (if cheap to construct) an oversized payload.
4. **A case that SHOULD trigger** the hook's block/warn behavior, unambiguously.
5. **A case that should CLEARLY NOT trigger it** — an ordinary, benign, everyday input that has no
   business being flagged. This is Douglas's own most commonly hit failure mode with existing hooks
   (false positives) — give it real weight, not a token single case. Prefer inputs drawn from
   genuinely common daily usage (a normal `git commit -m` mentioning an unrelated word, a routine
   file read, a plain `ls`) over contrived-but-technically-different inputs.

### Step 3 — Run the battery via direct subprocess execution

For each payload, actually run the hook — do not reason about what it would probably do:

- **Node hook**: `spawnSync(NODE, [hookPath], { input: JSON.stringify(payload), encoding: 'utf8' })`
  (Douglas's own established pattern from `guard-hooks.test.js`/`keep-going.test.js`).
- **Python hook**: `subprocess.run([python, hookPath], input=payload, capture_output=True, text=True)`.
- **Shell hook**: pipe via `printf '%s' "$payload" | ./hook.sh` and capture `$?`.

Record, per payload: the exit code, stderr content, stdout content, and whether it hung/timed out
(set a short timeout — 5s is Douglas's own convention in `settings.json` hook wiring — a hook that
never returns is itself a finding).

### Step 4 — Assert against what SHOULD happen, not just "didn't crash"

For every payload, state the EXPECTED exit code and stderr shape from Step 1's contract BEFORE
running it, then compare against what was actually observed. "It ran without throwing" is not a
pass — a hook that silently exits 0 on a case it should have blocked is a real, dangerous failure
that "didn't crash" would hide. Use the three-way taxonomy from the research: `0 = allow` (correct
for a should-NOT-trigger case), `2 = block` (correct for a should-trigger case on a
blocking-type hook), `anything else (1, 127, a signal, a timeout) = a bug`, always, regardless of
what the payload was.

### Step 5 — Offer to write `<hookname>.test.js` (or the equivalent for its runtime)

If a sibling test file doesn't already exist for this hook, offer to write one capturing the exact
cases just run — matching the established convention in Douglas's existing `.test.js` files
precisely: a `cases` array or explicit `check()` calls, a `run()`/`runRaw()` helper wrapping
`spawnSync`, a final pass/fail tally printed with `console.log`, and `process.exit(fail ? 1 : 0)` so
it composes with any suite runner. Only write it if Douglas accepts the offer, or if this skill was
invoked with an instruction to write tests as part of the same request — don't silently create a
file he didn't ask for.

### Step 6 — Report (see "Final report" below)

## Safety constraints (apply every invocation, no exceptions)

- **Never run with elevated/bypass permissions.** Testing a hook does not justify disabling the
  permission system; run at default tool permissions.
- **Never let a synthetic payload actually execute the dangerous action the hook exists to stop.**
  The point of piping a payload to the hook is to observe the HOOK's own exit code and stderr, not
  to run the payload's underlying command for real. For a hook like `guard-bulk-delete.js`, test with
  a JSON payload whose `tool_input.command` field is the string `"rm -rf runs/"` — the hook script
  reads and pattern-matches that string; nothing about testing the hook requires actually invoking
  `rm -rf` on a real directory. If a proposed test case would require truly executing the dangerous
  command to observe the result (rather than just handing the hook the string it inspects), redesign
  the test so only the hook's own decision logic runs — never the real destructive action.
- **Test against the real hook file directly — a copy only if the hook has a destructive SIDE EFFECT
  of its own** (writes a lock file, mutates shared state, calls an external command). Most of
  Douglas's hooks are pure decision logic reading stdin and writing stderr, safe to invoke directly
  as-is; for one that touches shared state (e.g. `concurrent-edit-lock.js`'s lock files, anything
  under `taskstate/`), point its payload's `cwd` at a fresh temp directory (exactly the pattern
  `keep-going.test.js`'s `mkproj()` helper already uses) so the test never touches real project
  state.
- **No commits.** Testing means running payloads, reporting, and optionally offering a new test file
  — never `git commit`/`git push`, unless Douglas separately asked for that.
- **Make only the change the offer in Step 5 requires** — a new `<hookname>.test.js` file, nothing
  else. Don't refactor the hook under test, don't touch unrelated hooks, don't edit `settings.json`
  wiring as a side effect of testing.
- **This skill is cheap by design — keep it that way.** No embedded multi-agent Workflow, no
  unnecessary LLM calls beyond the reasoning needed to design good payloads for the specific hook at
  hand. The expensive part of this task is real subprocess execution (near-instant), not model
  inference — don't let the skill balloon into a heavier loop than the task needs.

## Final report (what to tell Douglas)

- **What was tested**: the hook's file path, its event/matcher wiring (or "not yet wired"), and the
  specific condition(s) it implements, in plain language.
- **The payload battery actually run**, each with: the case description, the payload's key content,
  the EXPECTED result stated before running, the ACTUAL exit code + stderr observed, and pass/fail.
- **Any real gap found in the hook's OWN logic** — not "it works," but the specific thing that broke:
  a false positive, a false negative, an unhandled malformed-input crash, a matching regex a
  one-liner slipped past, a threshold off-by-one. If nothing broke across a genuine, specific
  battery, say so plainly — "no failure found across N cases this pass" — never "fully tested" or
  "hardened" (the same non-overclaiming register as `/spar`'s "no new issues across the last 2
  rounds" and `/probe`'s ban on "fully tested").
- **Whether a `<hookname>.test.js` was written**, and its path if so — or that Douglas declined /
  wasn't asked, if not.
- Full absolute path(s) of anything read or written, per the standing Files-list convention.

---

*Tracked copy: also save this file to `claude-global-config/commands/hook-build.md` (per the
skills-are-tracked convention) after a NASA scrub.*
