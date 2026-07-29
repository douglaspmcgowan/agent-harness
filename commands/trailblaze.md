---
name: trailblaze
description: "Authors and edits named BUILD-PATHWAYS -- ordered chains of Douglas's existing skills stored in hooks/skill-pathways.json (the same library the chain-suggester hook reads to nudge, and /pathway reads to execute). Resolves whether a request is a real pathway job (a REUSABLE named chain) vs a single-skill build (/ultraskill), a chain execution (/pathway), or a one-off per-project chain (/design inline), and stops if it's one of those. Mines real session usage for how Douglas actually sequences the skills -- evidence with session ids + quotes, the way the harden-tail entry was built -- rather than inventing an order; when authoring from a described intent with no usage yet, marks the evidence aspirational. Decides author-new vs edit-existing, preserves existing evidence/note and appends a dated change note on edits, verifies every step names a REAL installed skill, backs up the load-bearing library before writing, and verifies the JSON still parses AND the consuming hook still loads it. Edits the library; never executes a pathway. Use when Douglas says 'author a build pathway', 'add a new pathway', 'edit the harden-tail pathway', 'add a step to <pathway>', 'reorder the <pathway> chain', 'make a named chain of skills', 'trailblaze', or '/trailblaze'."
---

# /trailblaze [pathway-name | described intent] [--edit <id>]

A build-pathway is a named, reusable ORDER for skills Douglas already owns -- solo-review then probe then
hone then spar, run as a group because that's how he keeps asking for them. This command owns authoring and
editing those pathways in the library. It does not run one, and it does not invent an order from taste: the
order comes from how Douglas has actually sequenced the skills in real sessions, captured as evidence, the
same way the `harden-tail` entry already in the file was built. A pathway with no real usage behind it yet is
allowed, but it gets marked aspirational so a reader can tell a codified habit from a proposal.

## What this is NOT

- **Not `/pathway`.** `/pathway` EXECUTES a named chain end-to-end against one target -- one sequential
  `agent()` per step, with resume/step-skip. `/trailblaze` writes and edits the chain DEFINITION that
  `/pathway` (and the chain-suggester hook) then read. Authoring the recipe and cooking it are different
  jobs; this is the recipe. If Douglas wants a chain RUN, that's `/pathway`, and this command never runs one.
- **Not `/ultraskill`.** `/ultraskill` researches a landscape and BUILDS a single new skill (or improves
  one) to fill a capability gap. `/trailblaze` builds nothing new at the skill level -- it arranges skills
  that ALREADY EXIST into an order. If a pathway needs a step that doesn't exist yet, that missing step is an
  `/ultraskill` job first; `/trailblaze` only wires together skills already installed.
- **Not `/design`.** `/design`'s Step 7 COMPOSES a per-project build chain inline for the one app it's
  designing, from whatever is installed at that moment -- a throwaway sequence scoped to that one project.
  `/trailblaze` writes a DURABLE, reusable NAMED pathway that any later session (and `/design`
  itself) can pull from `skill-pathways.json`. When `/design` decides a composed chain is worth keeping
  beyond the current project, THAT is the hand-off into here. A one-off chain that only makes sense for one
  app stays inline in `/design`; it does not get a library id.
- **Not `/overlap`.** `/overlap` decides whether a NEW capability is redundant with the harness and, if not,
  whether to build it or fold it in. `/trailblaze` operates after that question is already settled for the
  individual skills -- they exist and are decided -- and only concerns their SEQUENCING into a named group.

## What a pathway IS -- the `skill-pathways.json` schema (study before writing)

The library lives at `~/.claude/hooks/skill-pathways.json`: a top-level `{ "chains": [ ... ] }` array. Each
chain object:

| Field | Type | Consumed by | Rules |
|---|---|---|---|
| `id` | string | the hook (progress file `.chain-progress.<id>.json`) + `/pathway` | **kebab-case, filesystem-safe**, unique across chains. It becomes a filename fragment, so no spaces/slashes. |
| `name` | string | hook nudge text | human-readable title (e.g. "Harden Tail"). |
| `steps` | string[] | hook regex-match + `/pathway` execution | **each entry MUST be a real installed skill name** (a `~/.claude/commands/*.md` file's `name`, or a built-in Skill-tool name). Order is load-bearing -- it's the execution order. |
| `minNamedToTrigger` | integer | hook (`checkChainOpportunity`) | how many of the chain's step-skills a prompt must name together before the hook surfaces the chain. Defaults to 2 if omitted. |
| `evidence` | `[{session, quote}]` | humans only (NOT read by the hook) | real session ids + verbatim quotes showing Douglas asked for this cluster. Aspirational entries get marked as such (see Step 2). |
| `note` | string | humans only (NOT read by the hook) | provenance + a dated log of changes (extractions, reorders), like harden-tail's `2026-07-14` reorder note. |

The hook (`task-state-reminder.js` -> `loadChains`/`checkChainOpportunity`) reads only `id`, `name`, `steps`,
`minNamedToTrigger`. `evidence` and `note` are documentation for Douglas and this skill -- they must stay
valid JSON but the hook ignores them. **Anything that breaks `id`/`name`/`steps`/`minNamedToTrigger` or the
JSON itself breaks the hook and `/pathway`;** Step 6 exists to catch exactly that.

## Procedure

### Step 0 -- Resolve the pathway need from ARGUMENTS

Determine which job this is:
- **Author NEW**: a name/intent for a chain that doesn't exist yet (e.g. "a pathway that runs solo-review
  then probe then spar"), OR a described intent ("a chain for standing up a new repo's tooling").
- **Edit EXISTING**: add/remove/reorder steps of a chain already in the file (e.g. "add hone to harden-tail",
  "reorder the harden-tail chain"), keyed by its `id`.

Needs enough that the edit is unambiguous: for a new pathway, the intended step skills and their order (or the
intent to derive them from evidence); for an edit, WHICH chain `id` and the exact change. If ARGUMENTS is a
bare name with no described steps/intent and it isn't obvious from the conversation, ask what the chain should
do before proceeding -- don't guess an order from a name alone.

### Step 1 -- GATE: is this actually a pathway job? (mandatory, before any write)

Mirroring `/hone`'s and `/probe`'s early gate. Stop and redirect if the request is really one of these:
1. **A single skill that doesn't exist yet** -> that's `/ultraskill` (Build Mode). A pathway can only wire
   together skills already installed. If a needed step is missing, say so and point at `/ultraskill` to
   build it first; don't invent a step name that resolves to nothing (it would silently never match in the
   hook and fail in `/pathway`).
2. **Wanting a chain RUN against a target** -> that's `/pathway`. `/trailblaze` writes definitions; it never
   executes one. If Douglas says "run harden-tail on X", hand off to `/pathway`.
3. **A one-off sequence only meaningful for one project** -> that belongs inline in `/design`'s Step 7, not
   as a durable library id. A pathway earns a library entry only when it's a REUSABLE habit that recurs
   across projects (see the Rule of Three lens below); a single project's build order stays inline.

Only if none of those fire is this a real `/trailblaze` job -- proceed.

### Step 2 -- Gather evidence: mine real usage, don't invent the order

The order in a pathway is a claim about how Douglas actually works, and it must be evidenced the way
`harden-tail` was (two real session quotes, e.g. *"run whatever skills in this list that you haven't yet:
solo review, spar, tune, probe"*). This is the "codify recurring multi-step tasks" discipline from skill
practice -- and it doubles as the Rule of Three check from `/overlap`: a sequence worth a durable id is one
Douglas has reached for repeatedly across sessions.

- **Digest-then-mine, never raw-read.** Borrow `/detective`'s and `/overlap`'s discipline: scan session
  transcripts for prompts where Douglas named these step-skills together, and pull the verbatim quote +
  session id for each. Keep the transcripts out of the main context -- a subagent may do the mining and
  return only `{session, quote}` pairs. (This is a bounded read pass, not a `Workflow` fan-out; authoring a
  library entry is deterministic editing, so this command deliberately has no embedded Workflow script.)
- **Set the order FROM the evidence.** If the quotes show a consistent sequence, use it; if Douglas has an
  explicit reason for an order (harden-tail's note records *"spar is the FINAL adversarial gate, so it runs
  last"*), record that reasoning in `note`.
- **Aspirational pathways are allowed but must be marked.** If Douglas asks to author a chain from a described
  intent with NO real usage behind it yet, say so plainly and set the `evidence` to an explicit aspirational
  marker (e.g. `[{"session": "aspirational", "quote": "authored from described intent 2026-07-14; no prior
  usage evidence yet"}]`) rather than fabricating a session id or a quote. Never invent a session id or a
  quote to make a proposal look like a habit.

### Step 3 -- Decide author-new vs edit-existing

- **Author NEW** if no chain covers this sequence. Choose a short kebab-case `id` distinct from every existing
  chain id, a readable `name`, the evidenced `steps` order, a sensible `minNamedToTrigger` (see Step 5), the
  `evidence` array, and a `note` recording where the chain came from and its date.
- **Edit EXISTING** if a chain with this `id` already exists. **Preserve its existing `evidence` and `note`**
  -- do not overwrite them. Apply only the step change asked for (add/remove/reorder), and **append a dated
  line to `note`** explaining the change, exactly like the `harden-tail` note's
  `"Order corrected 2026-07-14 per Douglas: ..."` line. If the edit is driven by new usage, add the new
  `{session, quote}` to `evidence` rather than replacing the old ones.

### Step 4 -- Verify every step names a REAL installed skill (mandatory, before writing)

Each `steps[]` entry must resolve to a skill that actually exists, or the hook's regex silently never matches
and `/pathway` fails at that step. For every step name:
- confirm a `~/.claude/commands/<step>.md` file exists (its frontmatter `name`), **or** it's a built-in
  Skill-tool name (the ones with no file on disk -- check the live Skill listing in this session's own
  reminders, the way `/overlap`'s Step 1 checks the built-in layer). Do not assume a file-glob is exhaustive;
  built-ins won't show up in `~/.claude/commands/`.
- if a named step doesn't resolve to any installed skill, STOP -- this is the Step-1 gate condition #1
  (missing skill -> `/ultraskill` first). Report which step didn't resolve; don't write a dangling step.

### Step 5 -- Write/edit `skill-pathways.json` (back it up first)

`skill-pathways.json` is load-bearing (the hook and `/pathway` both read it live), so before any edit:
1. **Back up**: copy the current file to a timestamped sibling under
   `~/.claude/hooks/_backups/skill-pathways.BACKUP_<yyyyMMdd_HHmmss>.json` (the same `_backups/` convention
   already used for this file -- see the existing `_backups/skill-pathways.BACKUP_*.json`).
2. **Write** the new/edited `chains` array, keeping all OTHER chains byte-for-byte unchanged (surgical edit --
   touch only the chain being authored/edited). Match the file's existing 2-space indentation and formatting.
3. **`minNamedToTrigger` guidance**: default **2** -- the hook nudges once a prompt names at least this many
   of the chain's step-skills together. Use 2 for most chains (matches `harden-tail`). Raise it only for a
   long chain where 2 named skills would over-trigger, and never set it above `steps.length`.

### Step 6 -- Verify the JSON parses AND the consuming hook still loads it

The whole point of the backup + this step is that a malformed edit silently disables the hook (`loadChains`
swallows a parse error and returns `[]` -- no chains, no nudge, no throw), so a broken file looks fine until
a nudge quietly stops firing. Prove the edit is sound, don't assume it:
1. **JSON parses**: `python -c "import json; json.load(open(r'<path>'))"` (use this machine's Python 3.13 at
   `C:/Users/dmcgowa2/scoop/apps/python313/current/python.exe`) -- exit 0, no exception.
2. **The hook still loads it**: run `loadChains()` the way the hook does and confirm it returns the expected
   chains (id/name/steps present). A direct node check against the real file:
   `node -e "const fs=require('fs');const c=JSON.parse(fs.readFileSync(String.raw\`C:\Users\dmcgowa2\.claude\hooks\skill-pathways.json\`,'utf8'));if(!Array.isArray(c.chains))throw new Error('chains not array');for(const ch of c.chains){if(!ch.id||!ch.name||!Array.isArray(ch.steps))throw new Error('bad chain '+JSON.stringify(ch.id));}console.log('OK',c.chains.length,'chains');"`
   -- must print `OK <n> chains`. If either check fails, restore the backup and fix before reporting anything
   as done.

This command EDITS the library. It does not EXECUTE a pathway -- that is `/pathway`'s job, and `/trailblaze`
never dispatches a step.

### Step 7 -- The honest final report

In the register of `/spar` / `/hone` / `/probe` (measured, non-fabricating):
- **What changed**: authored `<id>` / edited `<id>` -- the exact steps before -> after, and for an edit, the
  dated `note` line appended.
- **Evidence**: the `{session, quote}` pairs backing the order, or plainly that it's **aspirational** (no
  prior usage) if that's the case -- never dressed up as a habit.
- **Step verification**: that every step resolved to a real installed skill (Step 4), naming any that didn't.
- **Both checks passed**: JSON parses AND the hook's `loadChains` returned the chains (Step 6), quoting the
  actual command output observed rather than asserting it "should parse."
- **Do NOT claim the pathway "works" or "is proven"** -- it's a definition that's valid and loadable; whether
  it produces a good RESULT is only known once `/pathway` runs it. Report "authored and loadable," and point
  at `/pathway` to actually run it.
- Full absolute path(s) of the library file and the backup, per the standing Files-list convention, tagged
  NEW/UPDATED.

## Safety constraints

- **Never run with elevated/bypass permissions.** Authoring a library entry is ordinary editing; run at
  default tool permissions. A blocked call means narrow scope and try another angle, never route around it.
- **Back up before editing the load-bearing file.** `skill-pathways.json` is read live by the hook and
  `/pathway`; always copy it to a timestamped `_backups/` sibling before writing (Step 5), and restore from
  it if Step 6's verification fails.
- **Surgical scope.** Touch only the chain being authored/edited; leave every other chain and the file's
  formatting byte-for-byte unchanged. On an edit, preserve the existing `evidence`/`note` and append rather
  than overwrite.
- **Never fabricate evidence.** A `{session, quote}` pair must be real, or explicitly marked aspirational.
  Don't invent a session id or a quote to make a proposal read like a codified habit.
- **This command edits definitions only -- it never executes a pathway** (that's `/pathway`) and never
  builds a new skill (that's `/ultraskill`).
- **No commits/pushes** unless Douglas separately asks. The one in-place write is `skill-pathways.json`
  (plus its backup); writing this skill file itself is the only other direct write.

---

*Tracked copy: also save this file to `claude-global-config/commands/trailblaze.md` (per the
skills-are-tracked convention) after a NASA scrub.*
