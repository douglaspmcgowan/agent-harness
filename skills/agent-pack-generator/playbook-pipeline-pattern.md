# Playbook — Phase pipeline pattern

For packs that run a multi-step workflow on top of a corpus. Reference: DaVinci TTC at `…/NASA Ignition/flat/` (4 phases: Concept Intern → Cost & Schedule → Adversarial Review → Document Developer).

Reference advisor packs do not need this. Skip unless the user explicitly asks for a workflow.

## Files specific to a pipeline pack

| File | Purpose |
|---|---|
| `phase-N-<name>.md` | One per phase. Owns its phase's deliverables, exit criteria, handoff line, per-turn checklist. |
| `phase-guide.md` | Pipeline orchestration. Read order, "which phase am I in?" decision tree, handoff mechanics. |
| `status-object-spec.md` | Schema of the runtime status object (the only mutable state). |
| `playbook-<runner>-ops.md` | Operating manual for the target runner — view click-paths, document/table quirks, native-view-first guidance. |

## Phase file skeleton

Each `phase-N-*.md` should have:

- **One-sentence role.** "Concept Intern: opening interview, architecture skeleton, build-then-ask loop."
- **Default-if-no-phase flag** if relevant ("Default phase if status object is fresh").
- **Deliverables** — what artifacts must exist before this phase can hand off (in the runner: which model objects, documents, tables).
- **Exit criteria** — boolean checklist. All must be true to hand off.
- **Per-turn checklist** — what the agent does each turn while this phase is active.
- **Handoff line (literal)** — the exact sentence the agent says when exit criteria are met. The user types "phase N+1" / "ready" to advance.
- **Restrictions** — what this phase does NOT do (so it doesn't bleed into the next phase's territory).

## phase-guide.md skeleton

Three things:

1. **Phase table** — # | Name | Owns | File. Same table as in `AGENTS.md`.
2. **"Which phase am I in?" decision tree** — if status object says phase N, you're in N. If status is missing or fresh, default to phase 1. If user explicitly types "phase N", switch.
3. **Handoff mechanics** — how the user advances (chat message), how the agent confirms (reads new phase file, prints TURN-CHECK with new mode field, announces).

## status-object-spec.md skeleton

The runtime status object is the only mutable state. It lives in the runner (DaVinci `_TTC_Status` Package; Claude Project artifact; etc.) — NOT in a markdown file. Pack files are static.

Standard fields:

| Field | Type | Notes |
|---|---|---|
| `phase` | int | 1..N. Active phase. |
| `last_action_at` | timestamp | When the agent last touched the runner. |
| `last_action_summary` | string | One sentence — what the agent did last. |
| `open_user_questions` | list[str] | Sticky across sessions. Re-ask on resume; don't self-answer. |
| `unverified_artifacts` | list[str] | Things the agent built but hasn't confirmed render correctly. |
| `scope_in` | list[str] | What's in scope for the current concept / project. |
| `invariants` | list[str] | Things the agent must not contradict. |
| `takeaways` | list[str] | Things the user has stated as conclusions. |
| `residual_risks` | list[str] | Open risks the user has acknowledged. |
| `systems_built` | list[str] | (Phase 1+) Concrete artifacts created. |
| `systems_pending` | list[str] | (Phase 1+) Artifacts queued for next turn. |

Per-runner adaptations:

- **DaVinci**: status object is a Package in the project model. Read with `database.load("_<NAME>_Status")`; if missing, create from this schema and announce in chat.
- **Claude Project**: status object is a project artifact (markdown or JSON). Read at turn start, write before reply ends.

## Why phases are chat-driven

Two iterations of the DaVinci pack tied phase-switching to the runner's persona dropdown. The model lost track. The current pattern works: the user types "phase 2" / "ready for next" / "let's move on", and the agent loads the next phase file and updates the status object.

This means **the agent must self-detect the active phase from the status object** at the start of every turn — never assume the previous turn's phase carries over without checking.

## When phases should merge

If you find yourself writing a phase that mostly delegates to the next phase, or a phase whose only output is "set up for the next phase," merge them. Personas 4 + 5 in the early TTC iterations were a "Briefing Writer" + "Image Prompt Writer" — both writing the same kind of artifact. Merged on 2026-06-03 into a single Document Developer with two output objects. The pack got simpler and the user lost nothing.

Don't add phases speculatively. Add a phase only when the work it does is genuinely separable from the work of its neighbors AND the user benefits from being able to stop after that phase's output.

## Common pitfalls

- **Phase boundaries that the user can't see.** If the agent is "in phase 3" but the user can't tell what changed, the phase boundary isn't doing work. Each phase should have a distinct deliverable in the runner.
- **Phase-2-doing-phase-3-things.** Scope creep across phases. Each phase file should explicitly say what it does NOT do.
- **Status object as a markdown file in the pack.** Doesn't survive across sessions in DaVinci. Use a runtime object.
- **Skipping the status-update on Q&A turns.** A pure-discussion turn still updates `last_action_at` + `last_action_summary`. Otherwise next-session resume has no recovery point.
- **Silent phase transition.** When the agent advances phases, it announces ("Now in Phase 2 — Cost & Schedule Estimator. Three quick scope questions before I start the ROM…"). The user shouldn't have to guess.
