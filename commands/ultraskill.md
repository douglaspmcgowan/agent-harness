---
name: ultraskill
description: "Douglas's ultra-skill maker: given a capability he wants (not a specific tool), deep-searches the real landscape (GitHub, blogs/articles, and any specific sources he names), reads the actual source of the 2-3 strongest candidates rather than their pitch, synthesizes the proven mechanisms into ONE new Claude Code skill matching his existing spar/hone/probe architecture, dispatches a background build-and-live-test Workflow against real targets, and adversarially verifies it — grading the result against a domain-completeness rubric via a separate, fresh-context depth-audit agent so the skill reaches senior depth on the domain's hard parts, beyond merely correct structure (depth gate added 2026-07-16) — then wires the finished skill into the sibling skills whose flow should reach it so it is discoverable and not merely present (wiring step added 2026-07-17), before reporting. Use when Douglas says 'build me a skill for X', 'make an ultra skill for X', 'synthesize a tool that does X', 'ultra-skill X', or '/ultraskill'. Distinct from /recon (which maps a landscape and helps him DECIDE, without building) — invoke this once the decision to build is already made, either directly or handed off from a /recon auto-mode move. Also has an IMPROVE MODE (added 2026-07-08): given an EXISTING skill (not a new capability), runs the same deep-research-then-synthesize discipline against how OTHER practitioners solve the problem that skill already addresses, then edits the existing skill in place rather than building a new one. Use when Douglas says 'ultra-skill the X skill', 'improve X with ultra-skill', 'run the ultra skill process on X', or 'use ultra skill to make X better'. Has a FAST MODE (--fast / --light, added 2026-07-18): for a prose-procedure skill wrapping a local surface already read this session (no executable security surface), it collapses the background build-and-test Workflow + fresh-context depth audit into an inline write + a real one-shot exercise of the mechanism + self-graded rubric, keeping every quality gate (rubric, approval, authoring checklist, wiring, honest report). Trigger with 'ultra-skill --fast', 'fast mode', 'light build', 'don't run the full workflow'."
---

# /ultraskill [capability]

Building a new skill by synthesis, not by installing the first thing that shows up in a search or writing
one from a blank page. The 2026-07-06 sessions that produced `/hone` and `/probe` did this by hand, twice,
successfully — this codifies that exact process so it doesn't have to be reinvented or half-remembered a
third time.

## What this is NOT

- **Not `/recon`.** `/recon` maps a landscape and helps Douglas DECIDE what to do next — most of its topics
  aren't "build me a skill" at all (they're "how do I get better at X", "what's out there for Y"), and its
  own auto mode executes whatever the chosen move actually is, generically. `/ultraskill` starts from the
  opposite end: Douglas already knows he wants a NEW SKILL BUILT for a capability, and this owns the whole
  research-synthesize-build-test arc for that. `/recon`'s auto mode should hand off here when (and only
  when) the chosen move specifically is "build a new Claude Code skill" — it should never improvise that
  build inline itself.
- **Not installing a single community plugin.** If one existing tool is a clean, sufficient fit, installing
  it is faster and simpler than forging a new skill — don't reach for this command out of habit. This
  command exists for the case where the best answer is assembled FROM several real, verified mechanisms
  (the way `/hone` took its measurement loop from `optimization-suite`, its CAD levers from Douglas's own
  gate-hardening history, and its honesty discipline from `/tech-debt-audit` and `/spar`), not sitting
  whole in any one repo.
- **Not `/spar`.** `/spar` hardens an EXISTING target by attacking it. This command creates something new
  (Build Mode) or improves an existing skill's DESIGN via research (Improve Mode) — neither one attacks a
  running target the way `/spar` does.

## Improve Mode — same research discipline, applied to an EXISTING skill (added 2026-07-08)

Build Mode (the rest of this file) starts from a capability Douglas wants and doesn't have. Improve Mode
starts from a skill he ALREADY HAS and asks: how do other practitioners solve the same underlying problem,
and does that surface anything worth changing here? Trigger this mode instead of Build Mode when Douglas
names an EXISTING skill/command to improve, rather than a new capability to build.

### Step 0 (Improve) — Resolve the target skill and its actual problem statement

Read the target skill's file in FULL first (not a summary, not a memory of it from earlier in the
conversation — the real file on disk, right now). Extract, explicitly, before researching anything: what
underlying problem does this skill actually solve (state it as a general problem, not the skill's own
name — e.g. detective.md's real problem is "forensic sweep across many transcripts for specific signal
categories," not "be detective.md"), what's its current mechanism/architecture, and what's already been
tried/rejected (skills often have "What NOT to do" or design-history sections recording prior mistakes —
don't re-propose something already tried and abandoned without addressing why it failed before).

### Step 1 (Improve) — Deep research on how OTHER practitioners solve the SAME underlying problem

Same discipline as Build Mode's Step 1 (GitHub, blogs/articles, human-practitioner sources over marketing
copy, any sources Douglas names) but the QUESTION is different: not "what's the best tool for this
capability" but "how do people who've built something solving this same underlying problem handle it —
what do they do differently, what do they name as hard-won lessons, what mechanism/pattern shows up
repeatedly across independent sources." Read actual source/methodology where practical, not just landing
pages, same as Build Mode's Step 2.

### Step 2 (Improve) — Identify concrete, evidenced gaps — don't manufacture busywork

Compare the target skill's CURRENT approach against what the research surfaced. For each candidate change,
it must trace to something SPECIFIC found in Step 1 (a named mechanism, a named failure mode, a concrete
practitioner lesson) — not a generic "this could be more thorough" instinct. If the research finds the
skill's existing approach already matches best practice, or finds nothing that would genuinely change it,
say so plainly rather than inventing a change to justify having run the process — an Improve Mode pass that
finds nothing real is a valid, honest outcome, not a failure of the pass. Where the target BUILDS or exposes
something with a known domain bar (an API, a CLI, a protocol server, a security surface), also grade its
current design against that domain's completeness rubric (Build Mode's Step 1.5), so the pass catches the
systematic depth gaps a topic-framed search would miss.

### Step 3 (Improve) — Apply as edits to the EXISTING file, not a new file

Editing the target skill is a change to Douglas's harness, so FIRST present the planned edits — what changes,
where, and why each traces to a Step-2 finding — and get his explicit approval before making them; ask any
open questions here rather than guessing, and edit only on his go. Then, unlike Build Mode's Step 3 (write a
new skill file matching the sibling-skill register), Improve Mode edits the target skill IN PLACE — new
sections, revised procedure steps, updated frontmatter description if the capability grew. If the capability grew
enough that other skills should now hand off to it, run the Step-5.5 wiring check for the improved skill too.
Keep the target's own existing voice/structure/conventions; don't reformat unrelated parts of the file while making the change
(same "surgical, only what the finding requires" discipline as everywhere else). The edited skill must also
satisfy the **Skill authoring checklist** below — grade it against those rules before finishing, the same as
a newly built skill. Sync to `claude-global-config/commands/` after, matching the tracked-copy convention
(itself a harness change, so it rides the same approval).

### Step 4 (Improve) — Test the change for real, not just read it back

If the change is testable via direct execution (a hook, a script with real logic), pipe-test it the way
`/hook-build` does. If the target is a prose-procedure skill (like most of Douglas's `.md` commands) with
no directly-executable logic to unit-test, the honest verification is: re-read the FULL edited file for
internal consistency (does the new section contradict an existing one, does a new trigger condition
collide with an existing one), and if practical, dispatch a small test by actually attempting to follow the
new procedure once against a real, low-stakes target and reporting what happened -- don't claim "tested"
for a prose skill when only a read-through happened.

### Step 5 (Improve) — Report to Douglas

- What research surfaced, with sources (same citation discipline as Build Mode).
- Exactly what changed in the target file and why each change traces to a specific research finding — or
  that nothing changed because the research didn't surface anything the current design was missing.
- Full absolute path of the file edited.

## Fast mode (`--fast` / `--light`) — for prose skills over an already-mapped surface

Build Mode's default is a background build-and-test Workflow plus a fresh-context depth audit — the right
weight for a skill that BUILDS a security-bearing artifact (an API / MCP / CLI / protocol server), where a
topic-framed search misses systematic depth gaps. It is overweight for a **prose-procedure skill that wraps a
local surface the caller has already read this session** (a `/docket`-style enqueue, a viewer build over a known
schema, a research-triage tail): there the whole domain fits in a few files already in context, and a
multi-agent fan-out mostly re-reads what the caller knows and burns tokens confirming a prose file the caller
can verify by reading. `--fast` collapses that path. It changes only HOW the skill is built and verified,
never the quality bar — the Step-1.5 rubric and the Skill authoring checklist still apply in full.

### Eligibility gate (both must hold — if either fails, refuse `--fast` and run full Build Mode)

1. **No executable security surface in the produced artifact.** The new skill is a prose procedure (a `.md`
   command), not a tool that stands up an API/MCP/CLI/protocol server, a parser on untrusted input, an auth
   surface, or a destructive-action path. Any of those → full Build Mode, because the depth audit is exactly
   the guard for the gap those artifacts hide.
2. **The domain surface is small and already read this session** (or trivially readable inline now) — the 2-4
   real files/schemas the skill composes over are in context, so synthesis needs no fresh landscape sweep. If
   the capability still needs genuine open-web landscape research the caller hasn't already done, run full
   Build Mode (or at least full Step 1 first).

State explicitly, in one line, that both gate conditions hold before proceeding — if you can't, you're not
eligible for `--fast`.

### Fast procedure (replaces Steps 4–5 only; every other step is unchanged)

Run Build Mode Steps 0–3.5 exactly as written — resolve the capability, do (or confirm you already did) the
research, **build the Step-1.5 domain rubric**, read the real source of what you compose over, synthesize
matching the sibling register (`spar`/`hone`/`probe`) **and** the Skill authoring checklist, and clear the
Step-3.5 approval gate. Then, instead of Step 4's background Workflow and Step 5's after-the-fact artifact
check:

1. **Write the skill file inline** (Opus judgment is the caller's own here) — the full file, covering every
   rubric item or marking it `scoped-out — reason`, in one pass.
2. **Verify for real — exercise it once, don't read it back.** This is the load-bearing replacement for the
   dropped Test + Depth-Audit phases, so it is not optional and not a re-read. For a prose skill with no
   directly-runnable logic: actually FOLLOW the new procedure once, end to end, against ONE real low-stakes
   target, and report concretely what happened (what the mechanism produced, what broke, what was awkward). If
   the skill has any executable fragment (a CLI call, an enqueue command, a script), RUN that fragment against
   a real target. A skill claimed "fast-verified" on a read-through only is a failed run — say so and fix it.
3. **Self-administer the rubric.** Grade the written file against the Step-1.5 rubric yourself, one verdict per
   item (PRESENT / SHALLOW / ABSENT / scoped-out). Fast mode trades the *fresh-context adversarial* auditor
   for the caller's own honest grading — so hold the line: any SHALLOW/ABSENT with no scoped-out reason gets
   fixed inline before reporting, exactly as a revise round would.
4. **Then resume the normal tail** — Step 5.5 wiring and Step 6 report, unchanged, including the rubric
   coverage table (now self-graded) and the same honesty register.

Fast mode never skips: the rubric, the approval gate, the real-exercise verification, the authoring
checklist, the wiring, or the honest report. It skips only the background multi-agent fan-out and the separate
fresh-context depth auditor — and only for a prose skill whose domain was already in front of you.

## Procedure (Build Mode)

### Step 0 — Resolve the capability from ARGUMENTS

Needs: what capability or problem Douglas wants solved (not a specific tool name — if he already named the
exact tool to install, that's not an ultra-skill job), any candidate sources he already has in mind, and
which of his real repos would make sensible live-test targets once something is built. If this is missing
and isn't obvious from the conversation, ask rather than guessing at scope.

### Step 1 — Deep research across the real landscape

Fan out research the way `/deep-search` does: GitHub (skills, plugins, marketplaces), technical
blogs/articles, and any specific sources Douglas names. Prefer human-practitioner sources over marketing
copy. Identify the 2-4 strongest real candidates — not the first result, the best-evidenced ones (stars,
recency, actual maintainers, confirmed real via direct fetch, not taken on a landing page's word).

**Sweep the named-practitioner canon, not just repos + keywords.** The strongest prior art is often one
specific person's working method, filed under an ADJACENT topic a domain-framed keyword search never
surfaces. Concrete failure this fixes: building `/design`, a "design process" search missed **Matt Pocock's
grill-me / spec planning workflow** entirely — it's filed under "TypeScript / AI-coding," a neighboring lane —
and only got folded in three days later, by accident. So before settling candidates, explicitly enumerate the
well-known individual practitioners in this domain AND its adjacent domains, consult Douglas's trusted-source
list in `CLAUDE.md` (Simon Willison, Every.to, Mollick, Latent Space, Anthropic/OpenAI eng, plus the domain's
own named figures), and check what each does *differently*. Keyword/repo search finds tools and methodology;
the practitioner sweep finds the person whose actual method is the best thing to synthesize.

**On YouTube and email sources**, since Douglas may mention these as places he saw something: this command
cannot watch video directly — search for the video's title/description/any indexed transcript instead, and
say plainly if a claimed mechanism couldn't be independently confirmed that way. For email/newsletters:
don't proactively search Douglas's inbox as a standing default — only pull from it (via the Gmail connector,
read-only) when he names a specific newsletter/email or explicitly says to check his inbox for this. If he
wants a specific email folded into the research, the cheapest path is for him to forward or paste the
relevant part rather than granting a blanket inbox search.

### Step 1.5 — Build the domain completeness rubric (the depth bar)

Shape-complete and depth-complete are separate bars, and this process historically checked only the first: a
synthesized skill can carry every sibling section — frontmatter, gate, safety, workflow, final report — and
still be shallow on the domain's hard parts. The 2026-07-16 build of `/make-api`, `/make-mcp`, and `/make-cli`
shipped structurally complete yet under-taught authorization/BOLA, concurrency, async, MCP tool-poisoning, and
destructive-action safety, all deferred downstream, because nothing graded them against a senior bar. This
step is the fix.

Turn the research into an explicit **domain completeness rubric** before synthesizing: the checklist a staff
engineer in this domain grades against — the named standard or threat model (OWASP API Top 10, the full
clig.dev checklist, the MCP spec's security section, the relevant RFCs), the security/failure/edge surface,
and the hard-won gotchas practitioners name. **Anchor every rubric item to real senior source fetched in
Steps 1-2**, rather than items the model volunteers on its own — a self-authored rubric rewards the
generator's own blind spots and launders shallowness into a green score. Keep each item binary (covered or
scoped-out) so verbosity can't game it. This rubric is a first-class deliverable: it is the target Step 3 must
cover and the grading key the Step-4 Depth Audit scores against. This matches Anthropic's own skill-authoring
guidance — build the evaluations before the documentation, evaluations as the source of truth
(platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices).

### Step 2 — Read the actual source, not the pitch

For the 2-4 strongest candidates, fetch and read their real SKILL.md/source (`gh api` / direct clone), not
just their README's marketing description. If practical, test-run the strongest one against a real target
before deciding what to keep from it — a live test surfaces real bugs a description never would (e.g.
`optimization-suite`'s undocumented worker-result JSON schema, or a `--help` that throws instead of printing
usage, both only found by actually running it, not reading about it).

### Step 3 — Synthesize, matching Douglas's existing architecture

Decide what to actually keep from each candidate — the goal is ONE coherent new skill, not a bundle. Before
writing anything, read `~/.claude/commands/spar.md`, `~/.claude/commands/hone.md`, and
`~/.claude/commands/probe.md` as the template for the register this new skill must match:

- Frontmatter with `name`, `description`, and concrete trigger phrases.
- A **"What this is NOT"** section disambiguating against every existing adjacent skill/command (`/spar`,
  `/hone`, `/probe`, `/tech-debt-audit`, `panel-ultra-review`, `superpowers:*`, `impeccable`, whichever are
  actually adjacent to this capability) — this is where redundancy gets caught BEFORE building, not after.
- Numbered Steps, including a mandatory classification/gate step early (mirroring `/hone`'s Step 2 and
  `/probe`'s Step 2) that stops the tool from doing expensive, meaningless, or already-done work.
- A **Safety constraints** section: no elevated/bypass permissions, all trial/mutation/write work isolated
  in a throwaway git worktree that never touches the caller's main tree, cleanup via `git branch -d` (not
  `-D`, which `block-dangerous-bash.js` unconditionally blocks) as two separate calls, no commits unless
  separately asked, only the change the technique requires.
- An embedded **Workflow script**, JSON-schema-validated `agent()` phases, in the same style as the other
  three.
- A **Final report** section that bans overclaiming language ("fully tested", "optimal", "unbreakable") in
  favor of "what was verified this pass and what remains", matching `/spar`'s and `/hone`'s honesty register.

Beyond matching the sibling register, the synthesis bar is **rubric coverage**: every item on the Step-1.5
domain rubric is either covered by a design-time step or explicitly marked `scoped-out — reason`. Having every
section a sibling has is necessary and insufficient. One rule the 2026-07-16 gap makes non-negotiable for any
BUILD skill: it must design its own produced artifact's security, safety, and edge-handling in, and its
`Safety constraints` section must cover the attack surface of the thing it BUILDS, separate from the build
harness (worktrees, permissions). Deferring the whole hardening surface to a downstream `/spar` is disallowed;
name the hardening the artifact needs and design the core of it in.

The synthesized skill must also satisfy the **Skill authoring checklist** below — front-loaded description,
collapsed triggers, a deliberate invocation type, checkable per-step completion criteria, and no no-ops — so
it invokes reliably and stays context-cheap.

Name the new skill something short and distinct from any existing command (check `~/.claude/commands/` for
collisions before finalizing).

### Step 3.5 — Approval gate: get Douglas's go before touching the harness (mandatory)

Writing a new command file into `~/.claude/commands/`, and every later registration (`claude mcp add`, a
`settings.json`/hook edit, a Claude Desktop `mcpServers` entry, the tracked-mirror sync) are changes to
Douglas's harness. Before making any of them, STOP and present the plan for approval: the skill's name, its
one-line purpose, the exact file path it will write, and every harness registration or settings change it
will trigger, each in his shell's syntax (PowerShell/cmd). Wait for an explicit yes, and ask any open
questions here rather than guessing. A generic 'build me a skill' request does not pre-authorize the harness
write. The research, synthesis, and isolated-worktree testing before this point need no approval; the moment
of writing to `~/.claude` or settings does. On approval, proceed to Step 4.

### Step 4 — Dispatch a background build-and-test Workflow

**If `--fast` was invoked and its eligibility gate holds** (see the Fast mode section above), do NOT dispatch
this Workflow — follow the Fast procedure instead, then rejoin at Step 5.5. The rest of Step 4/5 below is the
full-Build-Mode path.

Call the `Workflow` tool (this is an explicit skill-triggered use, no separate opt-in) with phases:

1. **Design & Build** (`model: 'opus'` — the synthesis judgment is load-bearing) — write the actual skill
   file, informed by everything read in Steps 1-3, and covering every item on the Step-1.5 domain rubric, and satisfying the Skill authoring checklist
   (front-loaded description, collapsed triggers, deliberate invocation type, checkable completion criteria, no no-ops).
2. **Test** (parallel, against 2-3 REAL targets from Douglas's actual repos that stress genuinely different
   cases — not synthetic examples) — each test agent sets up its OWN isolated worktree
   (`using-git-worktrees` discipline), actually invokes the new skill's procedure, and reports concretely
   what happened, including friction/bugs hit using the skill's own instructions. This phase proves the skill
   RUNS; a separate phase proves it is DEEP.
3. **Depth Audit** (`model: 'opus'`, a skeptical domain-expert persona) — grade the built skill against the
   Step-1.5 domain rubric, one verdict per item (PRESENT / SHALLOW / ABSENT / scoped-out) with the specific
   missing thing named. Run it as a FRESH agent given only the built file, the rubric, and the real source,
   never the generation transcript — a critic that shares the builder's context converges to agreement (the
   coherence trap) and rubber-stamps. Does-it-run correctness (the Test phase) and domain depth (here) are
   orthogonal, so both run, by different agents. If any item comes back SHALLOW/ABSENT with no scoped-out
   reason, trigger at most ONE bounded revise-and-retest round with actionable per-item fixes.
4. **Adversarial Synthesis** (`model: 'opus'`, genuinely skeptical) — re-verify both the test agents' and the
   depth auditor's claims against the real files/repos rather than rubber-stamping; consolidate the rubric
   coverage and decide whether that one bounded revise round is warranted, and if so, be specific about
   exactly what's broken and where.

**Don't block on this** — dispatch it and keep doing other useful work in the same turn (per
`[[feedback_background_tasks]]`); report when the completion notification arrives.

### Step 5 — Verify the artifact actually landed before trusting any workflow's own verdict

**This is not optional — it was the real failure mode the first time this process ran unsupervised.** A
`Workflow` agent call can hit a transport failure ("Connection closed mid-response", "Unable to connect to
API") AFTER its `Write` tool call already committed the file to disk but BEFORE the structured return value
made it back to the script. When that happens, the workflow's own synthesis can confidently report "file was
never built, not shippable" against a file that actually exists and is mostly or fully complete — exactly
what happened building `/probe`. Before accepting ANY workflow verdict (success or failure) at face value:

1. Independently check the real file with `Glob`/`Read` — don't trust the workflow's self-report.
2. If the file exists but the workflow claimed failure, read it fully and assess it yourself: is it
   complete (does every section a sibling skill has — frontmatter, disambiguation, steps, safety
   constraints, an embedded Workflow script, a final-report section — actually exist), or is a specific
   piece missing (most likely the embedded script, since that's usually the longest tail-end block a cut
   response would drop)? Fix the concrete gap directly rather than re-running the whole expensive workflow.
3. Only re-run the full build workflow if the file is genuinely absent or fundamentally broken, not for a
   mechanical completion gap you can fix yourself in one edit.
4. **Accept on depth coverage, with shape-presence as the floor.** Confirm every Step-1.5 rubric item is
   covered or explicitly scoped-out, past the check that every section a sibling has exists. A file that
   landed complete in SHAPE yet SHALLOW on the rubric goes back through one Depth-Audit revise round.
   Shape-presence was the only bar the first runs checked, and it is what let the shallow skills through.

### Step 5.5 — Wire the new skill into the harness (discoverability)

A skill nothing else points to only runs when Douglas remembers its name exists. The build isn't done until
the sibling skills whose flow should reach the new one actually reference it — this is how `/onboard` got
wired into `/design` Step 9 and how `/recon`'s auto mode hands off to this command. It is the inverse of the
Step-3 "What this is NOT" map: that list names the adjacent skills to disambiguate FROM; here, of those same
neighbors, ask which are COMPLEMENTARY — where a sibling's existing step has a natural point at which handing
off to (or naming) the new skill genuinely helps — and wire those.

1. **Find the real wire points.** From the Step-3 adjacency, separate merely-disambiguated neighbors (leave
   them cross-referenced, no wire) from complementary ones (a genuine handoff point exists in the sibling's
   current procedure). A wire is warranted only where a sibling's EXISTING step would actually reach for this
   capability — not everywhere the topic is vaguely related. **Zero good wire points is a valid finding;**
   forcing a reference into a skill that doesn't need it is noise. The usual real ones are `/engineer`'s
   toggle menu, `/design`'s build pathway, and `/recon`'s auto-mode handoff — most skills warrant none.
2. **Pick the cheapest wire type that works, per target.** A real invocation (a `+toggle`, a numbered step,
   an auto-mode handoff) where the sibling should actually RUN the new skill; a one-line cross-reference
   pointer where it should just be DISCOVERABLE from there. Match the target file's existing convention — a
   toggle joins the toggle menu; a "What this is NOT" gets the reciprocal line.
3. **These are harness edits — they ride the Step-3.5 approval gate.** Editing an existing sibling changes
   Douglas's harness exactly as writing the new file does. Present the planned wires (which files, which
   lines, real-invocation vs pointer, and why each target genuinely needs it) and get his go before editing.
   Surgical edits only — don't reformat the sibling while adding a line.
4. **Sync + reciprocate.** After editing, sync each touched sibling's tracked mirror in
   `claude-global-config/commands/` (same NASA-scrub convention), and make the new skill's own "What this is
   NOT"/cross-refs point back at the wired siblings, so discovery is bidirectional.

**Completion criterion:** every complementary sibling either carries a real wire to the new skill or is
recorded as "considered, no wire needed — reason"; the new skill points back at each wired sibling; and every
touched file's tracked mirror is synced.

### Step 6 — Report to Douglas

- The exact file path of the new skill and the name chosen (and why, if a collision was avoided).
- The **wiring** — which sibling skills now reach the new one and how (toggle / step / pointer), or that none
  warranted a wire, so discoverability is proven alongside the artifact's existence.
- What was synthesized from where — which mechanisms came from which candidate, and what was left out and
  why (so he can judge the synthesis, not just trust it happened).
- The live test results — what worked, what didn't, any bugs found using the skill for real.
- Known limitations, stated plainly, the same register as `/hone`'s and `/probe`'s own "known limitations"
  sections.
- The **rubric coverage table** — each Step-1.5 domain-rubric item marked covered or scoped-out (with reason),
  so the report proves depth alongside the shape checks.
- Treat the Step-1.5 rubric as v1: fold any depth gap found by USING the skill for real (now or later) back
  into the skill as a gotcha and into the rubric, so the bar tracks gaps observed in real use, beyond the ones
  imagined up front (Anthropic's capture-every-failure pattern).
- Full absolute path(s) of anything written, per the standing Files-list convention.

## Skill authoring checklist (both modes — from Pocock's `writing-great-skills`)

Every skill this command writes (Build Mode) or edits (Improve Mode) must satisfy these authoring rules, so
it invokes reliably and stays context-cheap on top of being structurally complete. Source: Matt Pocock's
`writing-great-skills` (github.com/mattpocock/skills). Apply it as you write in Build Mode Step 3, and grade
the edited file against it in Improve Mode Step 3:

- **Front-load the description.** Lead with the core concept so invocation-matching is reliable; carry only
  triggers and cross-skill reach in the description, keeping identity and preamble out of it.
- **Collapse the triggers.** One trigger phrase per branch; fold synonyms together instead of listing five
  near-duplicates for the same path.
- **Choose the invocation type deliberately.** Make a skill model-invocable only when the model must reach it
  autonomously or another skill calls it; otherwise set `disable-model-invocation: true` so its description
  stops costing always-on context. A user-only slash command that keeps model triggers must earn that cost.
- **Checkable completion criteria per step.** Every step ends on a concrete, verifiable condition an agent
  cannot declare done early — the same defend-against-premature-completion discipline as the depth gate.
- **Single source of truth.** One authoritative place per concept, with its definition, rules, and caveats
  co-located under one heading; state a rule once.
- **Order by immediacy.** Inline what every run needs; push branch-specific or reference detail to a later
  section so the common path stays lean.
- **Prompt positively.** State the target behavior directly; reserve 'don't' for hard guardrails, each paired
  with the correct action.
- **Eliminate no-ops.** Cut any line that leaves behavior unchanged versus the model's default; strengthen a
  weak leading word rather than padding around it.
- **Include a deviation clause.** The skill's staged process is the well-reasoned default, not a straitjacket.
  Give the skill a standing rule that when the model genuinely judges a specific situation calls for a
  different move than the skill prescribes, it surfaces the divergence and its reasoning to Douglas for his
  call, instead of silently complying or silently going its own way. State it once, near the top, so it
  governs the whole run.

Report an `authoring_checklist` line: which rules the skill satisfies and any it deliberately breaks with a
reason (a self-contained single-file skill choosing inline disclosure over linked files is a valid, stated
exception — Douglas's family is self-contained by design).

## Safety constraints

- Never run with elevated/bypass permissions for any part of this process.
- All live-testing against real repos happens in isolated, cleaned-up git worktrees — never the caller's
  main tree.
- No commits, unless Douglas separately asks for that.
- **Any change to Douglas's harness requires his explicit approval first, in BOTH modes.** Writing a new
  command file, editing an existing skill, `claude mcp add`, a `settings.json`/hook edit, a Claude Desktop
  entry, or the tracked-mirror sync each change his harness — present the exact change and get a yes before
  making it (Build Mode Step 3.5, Improve Mode Step 3). Research, synthesis, and worktree testing need no
  approval; touching `~/.claude` or settings does.
- Writing the new skill file itself (to `~/.claude/commands/`) is the one direct, in-place write this
  command makes, and it happens only after that approval gate — everything else (test targets, mutation/trial
  work inside a built skill's own test phase) stays isolated per that skill's own safety constraints.

---

*Tracked copy: also save this file to `claude-global-config/commands/ultraskill.md` (per the
skills-are-tracked convention) after a NASA scrub.*
