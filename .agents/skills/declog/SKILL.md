---
name: declog
description: Audit Windows memory pressure and stale developer/agent process trees, then surface safe evidence for a human cleanup decision. Use when Douglas says "declog", reports high RAM or commit use, sees excess Chrome/Playwright/Node/Python/WebView2/Electron processes, suspects orphaned MCP or agent helpers, asks what can be killed, or wants a before/after memory report. The skill protects active ChatGPT, Codex, Claude, Cursor, browsers, and Windows components; it never kills by process name alone.
---

# Declog

Measure first. Build a process tree from immutable identity fields, separate physical working set from committed private bytes, classify only typed stale patterns, and put every uncertain process in Douglas's decision list.

## What this is NOT

- A generic task-killer or an instruction to end every process with the same name.
- A cure for driver/kernel pool growth. Use RAMMap and PoolMon when pool pressure dominates.
- An application profiler.
- A reason to terminate individual renderers inside an active ChatGPT, Codex, Claude, Cursor, Chrome, WebView2, or Electron tree.
- A substitute for lifecycle cleanup in Playwright, Node, or Python code.

## Gate 1 — establish the symptom

Run the deterministic audit:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\declog\scripts\Get-DeclogReport.ps1" -SampleSeconds 2 -AsJson
```

Record physical RAM used and available; commit used and limit; paged and nonpaged kernel pools; cache; per-type working set and private-byte totals; and short-interval deltas.

Treat working set as current physical residence. Treat private bytes as process-specific committed virtual memory. Shared pages, the kernel, drivers, cache, compression, and hardware allocations prevent process working sets from reconciling exactly to total RAM.

If nonpaged pool is materially responsible for the pressure, stop process cleanup and recommend Microsoft RAMMap plus PoolMon. Read [references/research.md](references/research.md) before explaining kernel-memory diagnostics or practitioner findings.

## Gate 2 — classify process trees

Use the report's classifications:

1. `protected-active-tree`: leave running.
2. `established-node-cleanup`: eligible only for the existing guarded stale-agent cleanup tool.
3. `decision-required`: show Douglas the process type, executable path, PID, age, ownership, parent state, descendants, working set, private bytes, and deltas.
4. `informational`: include in totals; take no action.

Typed detectors cover Playwright-managed Chromium/headless-shell paths and browser drivers; detached Node or possible MCP helpers; detached Python interpreters; WebView2 and Electron helpers; stale `git`, `taskkill`, and `conhost` helpers; and ordinary Chrome roots that require a human decision.

Path, creation time, owner SID, session, parentage, and descendants are part of identity. Process name alone is never evidence.

## Gate 3 — protect active work

Protect each active `ChatGPT.exe`, `codex.exe`, `codex-command-runner*.exe`, `Claude.exe`, and `Cursor.exe` root and every descendant. Protect Windows core processes and executables under Windows core paths. Treat missing ownership or executable path as ambiguity.

Before proposing termination, identify the owning application or task where evidence permits. Do not print command lines or environment variables. They may contain secrets.

## Gate 4 — ask for a bounded decision

Present a compact table with candidate ID and type, root PID, age, executable path, working set and private-byte totals, short-interval change, reason, expected effect, and uncertainty.

Recommend a candidate only when its full tree evidence supports the recommendation. Put all other candidates under “Needs your decision.” Never silently expand a selected PID to unrelated siblings.

## Gate 5 — revalidate immediately

After Douglas chooses a candidate, rerun the live report immediately:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".agents\skills\declog\scripts\Get-DeclogReport.ps1" -SampleSeconds 0 -RevalidateCandidateId "<candidate-id>" -AsJson
```

Proceed only when `Revalidation.Valid` is `true`. A candidate ID binds PID, creation time, executable path, owner SID, session, and classification. A missing or changed process fails closed.

For `established-node-cleanup`, invoke only the established guarded tool:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\dougl\.agents\tools\Clear-StaleAgentProcesses.ps1"
```

Run its dry-run first. Use `-Execute` only after Douglas authorizes the reported tree. The established tool performs its own fresh inventory and safety revalidation.

For every other class, show the exact selected tree after revalidation and request explicit authorization before termination. Prefer the owner application's graceful close command. Use force only when graceful shutdown failed and Douglas approved escalation.

## Gate 6 — verify the effect

Run the report again. Compare physical used/available, commit used, kernel pools, candidate-tree working set/private bytes, and remaining instances.

Report reclaimed working set and commit separately. A large private-byte reduction may produce only a small physical-RAM change.

## Safety constraints

- Never kill by name, wildcard, memory size, CPU percentage, or PID alone.
- Never terminate during a fixture test or dry-run.
- Never terminate an active-agent descendant or Windows-core process.
- Never expose process command lines, environment values, secret-bearing files, or credential material.
- Never infer staleness from a missing parent alone; require age, exact path, owner/session, ancestry, and typed evidence.
- Never automate ambiguous-process termination.
- Never claim kernel pressure was fixed by ending a user process without post-action measurements.
- Make no commits unless separately requested.

## Workflow contract

```text
audit -> account for memory -> build tree -> protect active roots
      -> type exact stale patterns -> surface ambiguity
      -> Douglas selects -> revalidate immutable identity
      -> graceful close or established guarded tool
      -> measure again -> report verified effect and remaining uncertainty
```

## Final report

State what was measured and when; what was protected; what was safely classified; what Douglas chose; what actually terminated; physical and committed memory before/after; kernel/cache findings; unresolved processes; and the lifecycle fix when a tool repeatedly leaks helpers.

Use “verified this pass” language. Avoid claims such as fully cleaned, optimal, leak-free, or permanently fixed without longitudinal evidence.
