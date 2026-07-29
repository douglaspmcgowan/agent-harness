# Hooks review & triage

**Type:** review / recommendations  
**Date:** 2026-07-26  
**Scope:** `claude-global-config` hooks + `settings.json` wiring  
**Audience:** Douglas  

This document consolidates the full hooks pass: what exists, what’s novel, keep/remove/modify with rationale, wiring hygiene, and ranked next steps. It supersedes the earlier “SPEC/AC Stop gate blocks until P1 green” recommendation — see [Proof vs autonomy](#proof-vs-autonomy-updated).

---

## Verdict

The harness is strong at **not stopping early** (`keep-going`) and **not doing unsafe things** (secrets, destructive bash, authored-doc, firmware, vault paths). Capability is ahead of wiring: several good consolidations and escape hatches sit on disk while settings still launches duplicate cold `node.exe` processes and references missing files.

Roughly a third of hooks on disk are dead weight, superseded, project-local, or fighting the harness design. Cut hard; keep the autonomy + secret/destructive core; consolidate Bash pre-hooks.

**North star for proof (updated):** make verification visible and hard to skip *when you opt into a SPEC*, without turning “all P1 ACs green” into a Stop / keep-going prerequisite. Autonomy stays checkbox-driven; proof stays advisory or separately opt-in.

---

## How hooks are wired today

| Event | Role |
|---|---|
| **PreToolUse** | Hard blocks / warns before Bash, Write/Edit, Read/Grep/Glob, web, Obsidian |
| **PostToolUse** | Secret scan of output, audit log, classifier-bypass forensics, Codex poll reminder, task mirroring |
| **UserPromptSubmit** | Nudge if this session still has open `CURRENT-TASK` |
| **SessionStart** | Inject project+session boot context (`session-primer`) |
| **PreCompact** | Push goals into durable files before context dies |
| **Stop** | `keep-going` (autonomy) + `wait-on-usage-limit` (longrun / 5h window) |
| **statusLine** | Cost/ctx/5h display; also writes `usage-state.json` for the wait hook |

State is keyed by **(project, session)** via `hook-state.js` / `taskstate/`. That keying is load-bearing for every autonomy hook.

`settings.json` currently hardcodes NASA-machine paths (`C:/Users/dmcgowa2/...`). Treat this repo as a sync mirror; live wiring may differ per machine.

---

## Summary by cluster

### 1. Autonomy / “don’t stop early”

| Hook | Role |
|---|---|
| `keep-going.js` | Stop voter: blocks stop while `[ ]`/`[~]` remain; fail-open; no-progress release; parked `[!]`/`[?]`; consolidates ralph-loop completion promises |
| `wait-on-usage-limit.js` | Opt-in longrun: sleeps until 5h reset, then exit 2 so the loop resumes |
| `mirror-tasks-to-current.js` | In-chat Task board → durable `CURRENT-TASK.<sid>.md` |
| `task-state-reminder.js` | UserPromptSubmit: surface open work / timeouts / skill gaps |
| `session-primer.js` | SessionStart boot context; ARMED/INERT report |
| `precompact-save-guard.js` | Durableize goals before compact |

### 2. Secrets & exfil

| Hook | Role |
|---|---|
| `block-secret-dump.js` | Pre: hard-block env/cred dumps (exit 2; works in subagents) |
| `check-secret-exposure.js` | Pre: `decision:block` so the turn can pivot + AskUserQuestion |
| `scan-write-for-secrets.js` | Pre Write/Edit: don’t bake keys into source |
| `scan-output-for-secrets.js` | Post: block result if key-shaped (wired) |
| `scrub-secrets-from-output.js` | Post: redact + continue (unwired; built for httpx leak) |
| `block-sensitive-file-read.js` | Pre Read/Grep/Glob: close Read-tool bypass |
| `allow-tags.js` | Library: `[allow-secret]` / `[allow-all]` from last user message only, single-shot |
| `block-ai-reference.js` / `protect-ai-reference.js` | Vault path blocks (weaker vs fuller — see triage) |

### 3. Destructive / env / config self-defense

`block-dangerous-bash`, `guard-bulk-delete`, `guard-env-mutation`, `protect-security-config`, `protect-authored-docs`, `protect-firmware`, `block-obsidian-delete`, `block-visible-powershell`.

### 4. Permission / UX friction

| Hook | Role |
|---|---|
| `allow-cd-chain-bash.js` | Auto-allow `cd X && <already-allowed-cmd>` via permissionDecision (replaces hard block) |
| `block-cd-chain-bash.js` | Superseded blocker — delete |
| `warn-large-read.js` | Soft nudge against dumping huge files into context |

### 5. Multi-session / forensics

`concurrent-edit-lock`, `bypass-incident-log`, `audit-bash-log`, `impeccable-run-log`, `auto-schedule-codex-poll` (weak — see modify).

### 6. Opt-in quality gates (mostly unwired)

`dep-audit-gate`, `test-green-gate`, `gates-config.js`, `py-complexity-advisory`, `warn-generated-file-edit`, `format-on-edit`, `double-shot-latte`.

### 7. Meta / ops

`hook_guarantee.js` (offline invariants), `security-checks-fast.js` (Bash pre-hook consolidator), `harness-keying.js`, `migrate-root-state.js`, statusline + usage-wait pair.

### Named skill pathway

`hooks/skill-pathways.json` currently defines only **`harden-tail`** (`solo-review → probe → hone → spar`). Build/verify chains (`/app-verification-chain`, `/spec`, `/user`) remain opt-in skills.

---

## Particularly interesting / novel

1. **`keep-going` as a control system** — Fail-open, session isolation, no-progress escape, parked markers, ralph promise loop folded in. Failure-mode driven (R1–R14), not a dumb “always continue.”

2. **`hook-state.js` project+session keying** — Multi-project folders and multi-session collision avoidance. State relocated out of `.claude/` because of upstream write-gate bug #43001.

3. **`allow-cd-chain-bash`** — Fixes Claude Code’s *prefix* permission matching without rewriting the command or limiting agents. Uses PreToolUse `permissionDecision` ahead of the allowlist.

4. **`allow-tags` single-shot user escape** — Transcript-tail, user-role-only, consumed after first tool call, fail-closed. Better than disabling the whole hook.

5. **`wait-on-usage-limit` + statusline writer** — Sleeps to `resets_at` with a long Stop timeout. Practical for overnight autonomy.

6. **`security-checks-fast`** — Correct diagnosis (N cold `node.exe` starts per Bash call). Preserves exit-contract differences for hooks that cannot merge.

7. **Detective → mechanical fix pattern** — `bypass-incident-log`, `concurrent-edit-lock`, `precompact-save-guard` came from session sweeps. Harness learning from itself.

8. **`dep-audit-gate` + `gates-config` opt-in** — Registry existence check for hallucinated packages; presence-gated so casual projects stay light.

---

## Wiring / hygiene issues

| Issue | Why it matters |
|---|---|
| Settings still spawns **6–9 separate Bash pre-hooks**; `security-checks-fast.js` exists but is **not wired** | Paying the timeout tax the consolidation was built to kill |
| Settings references **`block-egress-exfil.js`** and **`block-nasa-web-egress.js`** — **not in this repo** | Silent no-ops or hook failures depending on install path |
| Many strong hooks **on disk, not in settings**: `allow-cd-chain-bash`, `scrub-secrets-from-output`, `protect-ai-reference`, opt-in gates, toasts, etc. | Capability ≠ enforcement |
| Settings paths hardcode **`C:/Users/dmcgowa2/...`** | Easy to review the wrong “live” harness on a Mac/sync clone |
| Overlap: `block-ai-reference` vs `protect-ai-reference`; old `block-cd-chain-bash` still present after allow redesign | Drift / double intent |
| README / hub docs still describe an older ~11-hook snapshot | Stale inventory |

### Currently wired (from `settings.json`)

`block-visible-powershell`, `block-secret-dump`, `check-secret-exposure`, `block-dangerous-bash`, `guard-env-mutation`, `guard-bulk-delete`, `block-egress-exfil` *(missing file)*, `protect-security-config`, `protect-authored-docs`, `protect-firmware`, `scan-write-for-secrets`, `concurrent-edit-lock`, `block-ai-reference`, `block-sensitive-file-read`, `warn-large-read`, `block-nasa-web-egress` *(missing file)*, `block-obsidian-delete`, `scan-output-for-secrets`, `audit-bash-log`, `bypass-incident-log`, `auto-schedule-codex-poll`, `impeccable-run-log`, `mirror-tasks-to-current`, `task-state-reminder`, `session-primer`, `precompact-save-guard`, `keep-going`, `wait-on-usage-limit`, `session-usage-statusline`.

### On disk but not event-wired

`allow-cd-chain-bash`, `allow-tags` (library), `block-cd-chain-bash` (superseded), `check-session-size`, `dep-audit-gate`, `double-shot-latte`, `format-on-edit`, `gates-config` (library), `harness-keying` / `migrate-root-state` / `hook_guarantee` (CLI), `hook-state` (library), `notification-toast`, `protect-ai-reference`, `py-complexity-advisory`, `scrub-secrets-from-output`, `security-checks-fast`, `stop-toast-gate`, `teammate-idle-capture`, `test-green-gate`, `test-secret-hooks` (test runner), `warn-generated-file-edit`.

---

## Decision rules for triage

| Keep if… | Remove if… |
|---|---|
| Prevents a real incident already hit | Unwired for months and nothing asks for it |
| Enforces a CLAUDE.md hard rule mechanically | Superseded by a clearer replacement |
| Fail-open, session-scoped, cheap | LLM-as-judge Stop voter next to deterministic `keep-going` |
| Global across machines/projects | Hardcoded to one project/path (cad-forge, machine-local python) |

---

## KEEP — core (always on)

| Hook | Role | Why keep |
|---|---|---|
| `hook-state.js` | Library | Autonomy stack needs (project, session) keying |
| `keep-going.js` | Stop | Load-bearing autonomy; fail-open + parked + ralph |
| `wait-on-usage-limit.js` | Stop (opt-in `.longrun`) | Overnight runs survive 5h resets |
| `session-usage-statusline.js` | statusLine | UX + feeds usage-state |
| `session-primer.js` | SessionStart | Cold-start; ARMED/INERT |
| `task-state-reminder.js` | UserPromptSubmit | Open work / timeouts / skill gaps |
| `mirror-tasks-to-current.js` | PostToolUse Task* | Task board → Stop-readable state |
| `precompact-save-guard.js` | PreCompact | Goals survive compact |
| `allow-tags.js` | Library | False-positive escape without disabling guards |
| `block-dangerous-bash.js` | Pre Bash | Catastrophe + git/SQL |
| `block-secret-dump.js` | Pre Bash | Hard-block dumps (exit 2 in subagents) |
| `check-secret-exposure.js` | Pre Bash | Different contract: pivot + AskUserQuestion |
| `scan-write-for-secrets.js` | Pre Write/Edit | Don’t bake keys into source |
| Output secret backstop | Post Bash | Need one — prefer scrub (see Modify) |
| `block-sensitive-file-read.js` | Pre Read* | Close Read-tool bypass |
| `guard-bulk-delete.js` | Pre Bash | Real ~50-file incident |
| `guard-env-mutation.js` | Pre Bash | Half-broken pip/VTK incident |
| `protect-security-config.js` | Pre Write/Edit + Bash | Don’t gut the harness |
| `protect-authored-docs.js` | Pre | Office overwrite rule |
| `protect-firmware.js` | Pre Write/Edit | Cheap, high blast radius |
| `block-visible-powershell.js` | Pre Bash | Windows UX; warn-only failed |
| `warn-large-read.js` | Pre Read | Soft context hygiene |
| `concurrent-edit-lock.js` | Pre Write/Edit | Multi-session collision |
| `bypass-incident-log.js` | Post | Durable classifier-bypass forensics |
| `audit-bash-log.js` | Post Bash | Redacted forensics |
| `hook_guarantee.js` | CLI / CI | Offline invariants |
| `migrate-root-state.js` / `harness-keying.js` | CLI | Ops; don’t event-wire |

---

## KEEP — but MODIFY

### 1. Bash PreToolUse → wire `security-checks-fast.js`

**Today:** settings launches 6–9 separate node processes.  
**Change:** One `security-checks-fast` for Bash|PowerShell. Keep standalone only when contracts differ:

- `check-secret-exposure` (JSON `decision:block`)
- `protect-authored-docs` (`continue:false`)
- recovered `block-egress-exfil` if turn-kill semantics still needed

**Also wire separately:** `allow-cd-chain-bash` (stdout `permissionDecision:allow` — cannot merge into exit-2 consolidator).  
**Why:** Measured 14–17s timeouts from cold starts; consolidator already exists.

### 2. Vault off-limits: prefer `protect-ai-reference.js`

| File | Coverage |
|---|---|
| `block-ai-reference` (wired) | Only “AI Reference” |
| `protect-ai-reference` (unwired) | AI Reference + `26_Sensitive` + Other People Reference + Identity |

**Change:** Wire `protect-ai-reference` on Read|Grep|Glob and Bash/Write/Edit/Obsidian as CLAUDE.md claims; delete or thin-wrap `block-ai-reference`.  
**Why:** Memory/CLAUDE.md already treat protect-* as the enforcer; wired hook is the weaker subset.

### 3. Output secrets: prefer `scrub`, demote pure `scan-output` block

| Hook | Behavior |
|---|---|
| `scan-output-for-secrets` (wired) | Block result if key-shaped |
| `scrub-secrets-from-output` (unwired) | Redact + continue; built for httpx leak |

**Change:** Primary PostToolUse path = scrub. Keep scan as escalate-only or merge: scrub + systemMessage.  
**Why:** Call already ran; redacting is the right fix for the documented failure mode.

### 4. Wire `allow-cd-chain-bash.js`; delete `block-cd-chain-bash.js`

Explicit redesign (“don’t limit my agents”). Blocker is superseded.

### 5. Fix or kill `auto-schedule-codex-poll.js`

**Today:** Appends a line to `BACKGROUND-TASKS.md`. Does not schedule, cancel zombies, or detect 0-diff.  
**Change:** Actually queue `ScheduleWakeup` + status checks, or remove and build a real Codex zombie watcher.  
**Why:** Name overpromises; false comfort.

### 6. `impeccable-run-log.js` — keep only if used

Keep wired if `.impeccable/RUN_LOG.md` is read in practice; else demote to project-level for UI repos. Blind spot: Agent-dispatched impeccable work without a Skill call.

### 7. `block-obsidian-delete.js` — keep; verify MCP tool names

Cheap vault safety; re-check matcher after connector upgrades.

### 8. Opt-in gates — keep pattern, fix product

| Hook | Verdict |
|---|---|
| `gates-config.js` | Keep library |
| `dep-audit-gate.js` | Keep; wire as opt-in warn-only |
| `test-green-gate.js` | Keep as optional warn; easy to ignore — do **not** promote to hard Stop block |
| semgrep gate | Documented in places; **not in repo** — don’t claim it exists until it does |

---

## KEEP temporarily / niche

| Hook | Outcome | Why |
|---|---|---|
| `notification-toast.js` | Wire on Windows (Notification + PermissionRequest); skip headless/Mac-only | Real AskUserQuestion toast gap |
| `stop-toast-gate.js` | Keep with notification-toast on Windows; else delete | `harness-keying` already treats leftover Stop toast scripts as clutter vs keep-going |
| `check-session-size.js` | Optional Stop warn; low priority | Soft advice; fine to delete if Stop chain stays lean |
| `teammate-idle-capture.js` | Wire once under TeammateIdle, capture one payload, then delete | Temporary diagnostic, not a product hook |
| `test-secret-hooks.js` | Keep as test runner | Needs missing egress/NASA files or drop those cases |

---

## REMOVE / DELETE

| Hook | Why delete |
|---|---|
| `block-cd-chain-bash.js` | Superseded by `allow-cd-chain-bash` |
| `block-ai-reference.js` | Strict subset of `protect-ai-reference`; delete after cutover |
| `double-shot-latte.js` | LLM Stop voter next to deterministic `keep-going`; cost + edge cases; `harness-keying` already flags it as leftover Stop clutter |
| `format-on-edit.js` | Surprising file rewrite; PostToolUse on Write/Edit fights `hook_guarantee` invariant 2; prettier via npx is slow/flaky |
| `py-complexity-advisory.js` | cad-forge-only + hardcoded machine python path — move to that project or delete from global |
| `warn-generated-file-edit.js` | Unwired, narrow; project-level for codegen repos only if needed |

### Missing from disk but still in settings

| Name | Outcome | Why |
|---|---|---|
| `block-egress-exfil.js` | Recover from NASA/security pack if CUI/high-risk egress still matters; else remove from settings | Referenced + tested + remembered as installed; absent here → silent gap |
| `block-nasa-web-egress.js` | Keep on NASA machine; remove from personal-desktop settings if no NASA-internal content there | MAP/commands assume it; personal clone shouldn’t pretend it’s active |

Either restore the file or delete the matcher. No ghost entries.

---

## Target wiring shape

```
PreToolUse Bash|PS:  security-checks-fast → check-secret-exposure → protect-authored-docs
                     → [egress if recovered] → allow-cd-chain-bash
PreToolUse Write|Edit: protect-firmware, protect-security-config, scan-write-for-secrets,
                       protect-authored-docs, concurrent-edit-lock, protect-ai-reference
PreToolUse Read|Grep|Glob: protect-ai-reference, block-sensitive-file-read, warn-large-read
PreToolUse Web*:     block-nasa-web-egress  (NASA machine only)
PreToolUse Obsidian: block-obsidian-delete (+ protect-ai-reference if MCP paths appear)
PostToolUse Bash|PS: scrub-secrets (primary), audit-bash-log, bypass-incident-log
PostToolUse Agent:   bypass-incident-log + (fixed Codex poll OR nothing)
PostToolUse Skill:   impeccable-run-log  (optional)
PostToolUse Task*:   mirror-tasks-to-current
UserPromptSubmit:    task-state-reminder
SessionStart:        session-primer
PreCompact:          precompact-save-guard
Stop:                keep-going → wait-on-usage-limit
                     (+ optional soft proof nudge — see below; never “all P1 ACs green”)
statusLine:          session-usage-statusline
Opt-in Pre:          dep-audit-gate (when gates.json says so)
Windows-only:        notification-toast (+ stop-toast-gate if finish toasts wanted)
```

**Not event-wired:** `hook-state`, `allow-tags`, `gates-config`, `hook_guarantee`, `harness-keying`, `migrate-root-state`, tests.

---

## Proof vs autonomy (UPDATED)

### What was previously recommended (superseded)

A Stop gate that, when `SPEC.md` / `VERIFICATION.md` exist, **refuses stop** while P1 `AC-###` rows are unproven (with `[?]` waivers). That would have made “done” mean “P1 matrix green” in the same mechanical way `keep-going` makes “done” mean “no open checkboxes.”

### Douglas’s constraint (2026-07-26)

**Do not keep going until all P1 ACs are done.** Autonomy and acceptance-criteria proof must stay separable. Finishing the work queue / stopping the session must remain possible while ACs are still open, waived, deferred, or intentionally incomplete.

### Revised recommendation

Keep proof machinery, change the enforcement shape:

| Do | Don’t |
|---|---|
| Surface unproven P1 ACs as a **warn / statusline / primer / Stop stderr nudge** when SPEC exists | Block Stop or force keep-going solely because P1 ACs remain open |
| Allow explicit park: `[?]` / “deferred” / “out of scope this session” on AC rows | Treat open P1 ACs as actionable keep-going work by default |
| Keep `/spec`, `/app-verification-chain`, `/user`, `/spar`, `/probe` as **opt-in or pathway** tools | Make full AC green the default exit criterion for every project with a SPEC |
| Optionally add a **separate opt-in** (e.g. `.claude/gates.json` `"proof_required": true` or a `/longrun`-style flag) for sessions that *want* hard proof-before-stop | Bake hard proof-before-stop into global Stop for all SPEC projects |

**Concrete shapes that fit the constraint:**

1. **Soft proof nudge (default if SPEC present)** — On Stop or SessionStart: if P1 ACs are unproven, print a one-line stderr / primer note listing counts (`3 P1 open, 1 waived`). Always exit 0 w.r.t. proof. `keep-going` still keys only off `WORK_QUEUE` / `CURRENT-TASK` checkboxes.
2. **Opt-in hard proof gate** — Only when a project or session explicitly arms it (gates.json / flag). Same fail-open discipline as `keep-going` on harness error. Off by default.
3. **Named `construct` pathway** — Resumable skill chain for when Douglas *chooses* grill → spec → TDD → smoke → independent verify. Does not alter default Stop.
4. **Verification artifacts without Stop coupling** — e.g. require recording a verify path when flipping a *WORK_QUEUE* item tagged `ui`/`frontend` — scoped to that checkbox, not “all P1 ACs.”

### What stays true from the earlier feedback doc

- Best verification skills are still mostly **opt-in**; mediocre exits are still easy.
- Closing that gap should mean **better defaults and visibility**, not forcing AC completion to stop.
- Fail open on harness self-error; waivers first-class; prove Stop exit codes with synthetic JSON before writing `feedback_*.md`.
- Do not chase more slide/brand/research skills or soft CLAUDE.md rules with no hook/test.

`FEEDBACK-harness-recommendations.md` P0.1 (“Stop gate tied to SPEC / AC matrix”) should be read as **superseded** by this section unless an explicit opt-in hard gate is requested later.

---

## Ranked recommendations (updated)

### P0 — do first

1. **Wire `security-checks-fast` + `allow-cd-chain-bash`; unwire duplicated Bash individuals** — performance + correctness.
2. **Swap `block-ai-reference` → `protect-ai-reference`.**
3. **Resolve egress/NASA ghosts** — restore files or delete settings lines; NASA vs personal machine differs.
4. **Delete:** `block-cd-chain-bash`, `double-shot-latte`, `format-on-edit`, `py-complexity-advisory` (or move last to cad-forge).
5. **Unify PostToolUse secret handling** around scrub.
6. **Minimal eval/CI for load-bearing hooks** — `keep-going` exit codes, `hook_guarantee`, secret false-positive battery. Fail when Stop semantics drift.

### P1 — high ROI next

7. **Soft proof nudge when SPEC exists** (warn/primer/status only) — visibility without AC-forced keep-going.
8. **Named `construct` pathway** in `skill-pathways.json` (today only `harden-tail`) — resumable front half of `/app-verification-chain`, opt-in by invocation.
9. **Hard cost/iteration budgets** on armed loops (ralph + keep-going) — kill runaway overnight spend.
10. **Frontend/visual done-signal** scoped to WORK_QUEUE items tagged `ui`/`frontend` (artifact path), not global P1 AC completion.
11. **Hook liveness heartbeat** — critical hooks must have fired ≥1 this session or yell at Stop/statusline (`hook_guarantee` is offline-only).
12. **Codex zombie watcher** — cancel dead PIDs / flag 0-diff fast finishes (`CODEX-DELEGATION-LOG.md` FM-1/FM-2); replace or absorb `auto-schedule-codex-poll`.
13. **Detective → harness WORK_QUEUE** — findings become durable fix items, not chat promises.

### P2 — later

14. Scope lock warn (diff vs open ask / CHANGE note) — warn-only unless opted in.
15. Global memory coherence for duplicated `feedback_*.md`.
16. Contract/API tests as verification rows for multi-surface apps (still not a Stop prerequisite).

### Explicit non-goals

- Hard Stop / keep-going until all P1 ACs are green (global default)
- More slide / brand / fellowship / LinkedIn skills
- Another general research skill beside `/deep-search`
- Soft prose rules in CLAUDE.md with no hook, test, or gate
- Broadening permission allowlists as a substitute for better gates
- Another LLM Stop judge (`double-shot-latte` class)
- More PostToolUse-on-Write/Edit surprise side effects

---

## Suggested sequencing

```
Week 1     Wire security-checks-fast + allow-cd-chain-bash
           protect-ai-reference cutover; delete superseded hooks
           resolve egress/NASA settings ghosts; scrub as Post secret primary
Week 2     keep-going + hook_guarantee evals in a single test entrypoint
           soft proof nudge (warn-only) if SPEC present
Week 3     construct pathway in skill-pathways.json
Week 4+    budgets → UI artifact signal on tagged queue items →
           hook liveness → Codex zombie watcher → detective→queue
Later      scope-lock warn, memory consolidation, contract tests
```

---

## Design constraints (carry into any implementation)

1. **Fail open on harness self-error** — a broken gate must never trap the session (`keep-going` R1).
2. **Autonomy ≠ proof** — `keep-going` keys off work-queue checkboxes; AC matrices do not silently become keep-going work.
3. **Presence-gated extras** — SPEC nudge / dep-audit / test-green only when oracle or gates.json exists; casual chats stay light.
4. **Hard proof only if explicitly armed** — never the global default.
5. **Waivers are first-class** — `[?]` / deferred / out-of-scope beats silent skip.
6. **Proportionality** — tiny scripts don’t earn `/user` or full verification chains.
7. **Durable fix over chat promise** — accepted recommendations end as hook, test, pathway, settings change, or queue item.
8. **Prove root cause before memory** — for Stop-hook changes, pipe synthetic JSON in and assert exit codes before `feedback_*.md`.

---

## Open decisions

- [ ] Soft proof nudge: Stop stderr, SessionStart primer, statusline, or all three?
- [ ] Should any project get an **opt-in** hard proof gate (`proof_required`), or stay warn-only forever?
- [ ] This clone’s role: NASA machine / personal desktop / sync mirror? (decides egress, NASA web, Windows toasts)
- [ ] `construct` pathway: wrap `/app-verification-chain` or replace hand invocation?
- [ ] Budget units: iteration caps only, or also proxy/$ ceilings on GEN/Codex paths?
- [ ] Visual/UI signal: only WORK_QUEUE items tagged `ui`/`frontend`?

---

## Evidence anchors

| Claim | Where |
|---|---|
| Only harden-tail pathway | `hooks/skill-pathways.json` |
| keep-going rules / fail-open | `hooks/keep-going.js` header R1–R14 |
| Bash consolidator + why | `hooks/security-checks-fast.js` header |
| allow-cd redesign | `hooks/allow-cd-chain-bash.js` header |
| allow-tags escape | `hooks/allow-tags.js` |
| Offline guarantee | `hooks/hook_guarantee.js` |
| Leftover Stop clutter policy | `hooks/harness-keying.js` (`STOP_OK`, double-shot/toast warn) |
| Spec + AC oracle (skills) | `commands/spec.md`, `commands/app-verification-chain.md` |
| Independent user pass | `commands/user.md` |
| Codex zombie / wrapper FMs | `CODEX-DELEGATION-LOG.md` FM-1, FM-2 |
| Earlier proof-gap writeup (P0.1 superseded here) | `FEEDBACK-harness-recommendations.md` |
| Verification modes | `VERIFY.md` |

---

## Related docs

- `FEEDBACK-harness-recommendations.md` — earlier harness north-star note; **P0.1 hard SPEC/AC Stop gate is superseded** by [Proof vs autonomy](#proof-vs-autonomy-updated) in this file.
- `VERIFY.md` — verification modes by output type.
- `CLAUDE.md` — global behavior + harness map.
