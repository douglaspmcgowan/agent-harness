# Memory & Usage Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a live RAM/commit/pagefile snapshot ("Memory" tab), a per-server memory column, and a
read-only Claude-usage summary to `longrun-dashboard.py`, backed by a new stdlib-only Node recorder.

**Architecture:** `memory-recorder.mjs` is a dumb OS-facts collector (PowerShell CIM/perf-counter
queries shelled out from Node, zero business logic, zero persistence) with three modes: `--sample`
(full snapshot), `--pids <csv>` (per-PID lookup for the Servers tab), `--events` (low-memory Windows
Event Log entries). `longrun-dashboard.py`'s Python side owns ALL business logic — bucket
classification, alert thresholds, and a short in-process trend ring buffer — shelling out to the
recorder synchronously on each `GET /api/memory` (~20s frontend poll, matching the existing
"Discovered" panel's live-system-call cadence). `GET /api/usage` is pure read-surfacing of the
already-rich `~/.claude/usage-estimator/` history — no new capture code.

**Tech Stack:** Python 3 stdlib (`subprocess`, `shutil`, `collections.deque`), Node.js ESM (zero deps,
matching the sibling `claude-usage-recorder.mjs`), PowerShell (`Get-CimInstance`, `Get-Process`,
`Get-WinEvent`) as the actual data source. No pytest — this codebase's whole regression gate is the
inline `self_test()` function (currently 104/104), extended incrementally per this plan's TDD steps.

**Reference docs:** Design spec at `C:\Users\dmcgowa2\.claude\tools\MEMORY_USAGE_TRACKER_DESIGN_2026-07-07.md`
(committed `claude-global-config@5cdb042`). Precedent script:
`C:\Users\dmcgowa2\Documents\Codex NASA Folder\scripts\claude-usage-recorder.mjs`.

**Schema note (resolves an inconsistency found during this plan's self-review — the design spec
conflated the recorder's raw output with the API's final shape; this plan is the authoritative
version):** `memory-recorder.mjs --sample` returns RAW facts only (`processes: [...]`, flat, no
grouping/top-N/trend/alerts — commitPct/pagefilePct ARE computed in Node since they're one division
each on data already in hand). `GET /api/memory` is what the DASHBOARD builds from that raw sample —
grouped `groups`, `topProcesses` (top 15 by privateBytes), `trend`, `alerts`. See Task 8.

---

## File Structure

- **Create:** `C:\Users\dmcgowa2\Documents\Codex NASA Folder\scripts\memory-recorder.mjs` — the OS-facts
  collector (Tasks 1–2).
- **Modify:** `C:\Users\dmcgowa2\Documents\Codex NASA Folder\package.json` — add `memory:sample`,
  `memory:watch`, `memory:report` npm scripts (Task 2).
- **Modify:** `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py` — new pure functions (bucket
  classifier, trend classifier, alert thresholds, JSONL tail-reader), new `sample_memory*()` subprocess
  wrappers, three new GET endpoints, a `memory` field on `/api/servers`, and the frontend Memory tab +
  header strip + Servers-tab column inside the `PAGE` string (Tasks 3–13). This file is mirrored to
  `C:\Users\dmcgowa2\Documents\Claude NASA Folder\claude-global-config\tools\longrun-dashboard.py` — the
  mirror is synced only once, in Task 14, not after every task (avoids 14 scrub+push round-trips for one
  feature; matches how this session's prior multi-fix passes were committed as one unit per pass).

Everything server-side lives near `find_pid_on_port`/`stop_port` (line ~5323–5424, right before
`class Handler`) — an untouched area with no round-3-spar overlap. All line numbers below are current
as of `claude-global-config@8e3007c` (104/104 self-test) — confirm with `Grep` before each edit in case
they've shifted; do not assume they're still exact if time has passed since this plan was written.

---

## Task 1: memory-recorder.mjs — schema, arg parsing, `--sample` mode

**Files:**
- Create: `C:\Users\dmcgowa2\Documents\Codex NASA Folder\scripts\memory-recorder.mjs`

There is no JS test framework in this repo (the sibling `claude-usage-recorder.mjs` has zero automated
tests — verified only by running its own modes and reading the output). This task follows that same
convention: "red/green" here means running the script and checking its actual stdout against the
expected shape, not a pytest/jest assertion.

- [ ] **Step 1: Write the script**

```js
#!/usr/bin/env node
import { execFileSync } from 'node:child_process';

const schemaVersion = 1;

function parseArgs(argv) {
  const args = { mode: 'sample', pids: [], quiet: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--sample') args.mode = 'sample';
    else if (a === '--pids') { args.mode = 'pids'; args.pids = String(argv[++i] || '').split(',').map(s => s.trim()).filter(Boolean).map(Number).filter(Number.isFinite); }
    else if (a === '--events') args.mode = 'events';
    else if (a === '--watch') args.mode = 'watch';
    else if (a === '--report') args.mode = 'report';
    else if (a === '--interval-sec') args.intervalSec = Number(argv[++i]);
    else if (a === '--quiet') args.quiet = true;
    else if (a === '--help' || a === '-h') args.mode = 'help';
    else throw new Error(`Unknown argument: ${a}`);
  }
  return args;
}

function runPs(script) {
  // -NoProfile/-NonInteractive: fast, no user profile side effects. Timeout guards a hung CIM call.
  const out = execFileSync('powershell.exe',
    ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script],
    { encoding: 'utf8', timeout: 8000, maxBuffer: 16 * 1024 * 1024 });
  return JSON.parse(out);
}

const SAMPLE_PS = `
$os = Get-CimInstance Win32_OperatingSystem
$mem = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
$pf = Get-CimInstance Win32_PerfFormattedData_PerfOS_PagingFile | Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
$procs = Get-Process | Select-Object ProcessName, Id, PrivateMemorySize64, WorkingSet64
$result = [ordered]@{
  physicalTotalBytes = [int64]$os.TotalVisibleMemorySize * 1024
  availableBytes = [int64]$os.FreePhysicalMemory * 1024
  commitBytes = [int64]$mem.CommittedBytes
  commitLimitBytes = [int64]$mem.CommitLimit
  pagedPoolBytes = [int64]$mem.PoolPagedBytes
  nonpagedPoolBytes = [int64]$mem.PoolNonpagedBytes
  cacheBytes = [int64]$mem.CacheBytes
  pagefilePctRaw = if ($pf) { [double]$pf.PercentUsage } else { 0 }
  processes = @($procs | ForEach-Object { [ordered]@{ name = $_.ProcessName; pid = [int]$_.Id; privateBytes = [int64]$_.PrivateMemorySize64; workingSetBytes = [int64]$_.WorkingSet64 } })
}
$result | ConvertTo-Json -Depth 4 -Compress
`;

function takeSample() {
  const raw = runPs(SAMPLE_PS);
  const commitPct = raw.commitLimitBytes > 0 ? raw.commitBytes / raw.commitLimitBytes : 0;
  const pagefilePct = (raw.pagefilePctRaw || 0) / 100;
  return {
    schemaVersion,
    timestamp: new Date().toISOString(),
    physicalTotalBytes: raw.physicalTotalBytes,
    availableBytes: raw.availableBytes,
    commitBytes: raw.commitBytes,
    commitLimitBytes: raw.commitLimitBytes,
    commitPct: Number(commitPct.toFixed(4)),
    pagefilePct: Number(pagefilePct.toFixed(4)),
    pagedPoolBytes: raw.pagedPoolBytes,
    nonpagedPoolBytes: raw.nonpagedPoolBytes,
    cacheBytes: raw.cacheBytes,
    processes: Array.isArray(raw.processes) ? raw.processes : (raw.processes ? [raw.processes] : [])
  };
}

function help() {
  console.log(`Usage:
  node scripts/memory-recorder.mjs --sample
  node scripts/memory-recorder.mjs --pids 1234,5678
  node scripts/memory-recorder.mjs --events
  node scripts/memory-recorder.mjs --watch --interval-sec 20
  node scripts/memory-recorder.mjs --report

Snapshot only -- no history is persisted by --sample/--pids/--events. Records SAFE facts only: RAM,
commit, pagefile, pool, cache, and per-process name/pid/private-bytes/working-set-bytes. Never records
env vars, command lines, tokens, or config file contents.`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.mode === 'help') return help();
  if (args.mode === 'sample') {
    const sample = takeSample();
    if (!args.quiet) console.log(JSON.stringify(sample));
    else process.stdout.write(JSON.stringify(sample));
    return;
  }
  throw new Error(`mode not yet implemented: ${args.mode}`);
}

main().catch(error => {
  console.error(error.stack || error.message || String(error));
  process.exit(1);
});
```

- [ ] **Step 2: Run it and verify the shape**

Run: `node "C:\Users\dmcgowa2\Documents\Codex NASA Folder\scripts\memory-recorder.mjs" --sample`

Expected: one line of JSON with `schemaVersion:1`, real positive `physicalTotalBytes`/`availableBytes`/
`commitBytes`/`commitLimitBytes` (billions), `commitPct`/`pagefilePct` between 0 and 1, and a
`processes` array with 100+ entries each having `name`/`pid`/`privateBytes`/`workingSetBytes`. If
`commitLimitBytes` is 0 or missing, the `Win32_PerfFormattedData_PerfOS_Memory` class name is wrong for
this Windows build — re-check with `Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory | Format-List
CommitLimit,CommittedBytes` directly in PowerShell before debugging the script further.

- [ ] **Step 3: Confirm no forbidden data leaked**

Run: `node "...\memory-recorder.mjs" --sample | Select-String -Pattern "ANTHROPIC_API_KEY|GEN_API_KEY|--add-dir|C:\\\\Users.*\\.claude\\\\projects"` (PowerShell)

Expected: no matches. The script never touches `process.env`, never shells a command that echoes its
own invocation, and `Get-Process`/CIM queries return no environment or command-line fields by design
(only `ProcessName`/`Id`/`PrivateMemorySize64`/`WorkingSet64` were selected in Step 1 — if a future edit
ever adds `CommandLine` to that `Select-Object`, this check is what would catch it).

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/dmcgowa2/Documents/Codex NASA Folder"
git add scripts/memory-recorder.mjs
git commit -m "Add memory-recorder.mjs --sample mode (safe OS memory facts, no persistence)"
```

(If this folder isn't a git repo or isn't tracked, skip — check with `git -C "C:\Users\dmcgowa2\Documents\Codex NASA Folder" status` first; this repo's tracking status wasn't confirmed during planning.)

---

## Task 2: memory-recorder.mjs — `--pids`, `--events`, `--watch`, `--report` modes + npm wiring

**Files:**
- Modify: `C:\Users\dmcgowa2\Documents\Codex NASA Folder\scripts\memory-recorder.mjs` (the `throw new Error('mode not yet implemented...')` branch from Task 1, Step 1)
- Modify: `C:\Users\dmcgowa2\Documents\Codex NASA Folder\package.json:6-13` (the `scripts` block)

- [ ] **Step 1: Add the three remaining modes**

Replace the `throw new Error(...)` line at the end of `main()` with:

```js
  if (args.mode === 'pids') {
    if (args.pids.length === 0) { console.log(JSON.stringify({ schemaVersion, timestamp: new Date().toISOString(), processes: [] })); return; }
    const idSet = args.pids.join(',');
    const ps = `Get-Process -Id ${idSet} -ErrorAction SilentlyContinue | Select-Object ProcessName, Id, PrivateMemorySize64, WorkingSet64 | ForEach-Object { [ordered]@{ name = $_.ProcessName; pid = [int]$_.Id; privateBytes = [int64]$_.PrivateMemorySize64; workingSetBytes = [int64]$_.WorkingSet64 } } | ConvertTo-Json -Depth 3 -Compress`;
    let raw;
    try { raw = runPs(ps); } catch { raw = []; }
    const processes = Array.isArray(raw) ? raw : (raw ? [raw] : []);
    const out = { schemaVersion, timestamp: new Date().toISOString(), processes };
    if (!args.quiet) console.log(JSON.stringify(out)); else process.stdout.write(JSON.stringify(out));
    return;
  }
  if (args.mode === 'events') {
    // 2004/2005: Microsoft-Windows-Resource-Exhaustion-Detector low-virtual-memory events. Confirmed
    // Windows event source, but whether THIS machine's System log actually has recent entries is an
    // empirical question -- an empty array here means "none in the window", not "broken" (see plan
    // Task 8, verify live before trusting the count).
    const ps = `Get-WinEvent -FilterHashtable @{LogName='System'; Id=2004,2005; StartTime=(Get-Date).AddHours(-24)} -ErrorAction SilentlyContinue | Select-Object -First 20 Id, LevelDisplayName, TimeCreated, @{n='Summary';e={$_.Message.Substring(0,[Math]::Min(200,$_.Message.Length))}} | ForEach-Object { [ordered]@{ id = $_.Id; level = $_.LevelDisplayName; timeCreated = $_.TimeCreated.ToString('o'); summary = $_.Summary } } | ConvertTo-Json -Depth 3 -Compress`;
    let raw;
    try { raw = runPs(ps); } catch { raw = []; }
    const events = Array.isArray(raw) ? raw : (raw ? [raw] : []);
    const out = { schemaVersion, timestamp: new Date().toISOString(), events };
    if (!args.quiet) console.log(JSON.stringify(out)); else process.stdout.write(JSON.stringify(out));
    return;
  }
  if (args.mode === 'report') {
    const sample = takeSample();
    console.log(`${sample.timestamp} commit=${(sample.commitPct * 100).toFixed(1)}% avail=${(sample.availableBytes / 1e9).toFixed(1)}GB pagefile=${(sample.pagefilePct * 100).toFixed(1)}% processes=${sample.processes.length}`);
    return;
  }
  if (args.mode === 'watch') {
    const interval = args.intervalSec || 20;
    for (;;) {
      const sample = takeSample();
      if (!args.quiet) console.log(`${sample.timestamp} commit=${(sample.commitPct * 100).toFixed(1)}% avail=${(sample.availableBytes / 1e9).toFixed(1)}GB`);
      await new Promise(resolve => setTimeout(resolve, interval * 1000));
    }
  }
```

- [ ] **Step 2: Run each mode and verify**

Run: `node "...\memory-recorder.mjs" --pids <a real PID from Task 1's --sample output>`
Expected: `{"schemaVersion":1,...,"processes":[{"name":"...","pid":<that pid>,"privateBytes":...,"workingSetBytes":...}]}`.

Run: `node "...\memory-recorder.mjs" --events`
Expected: valid JSON with an `events` array — length 0 is fine and expected (log honestly, don't treat as failure).

Run: `node "...\memory-recorder.mjs" --report`
Expected: one human-readable line with real numbers, no crash.

- [ ] **Step 3: Wire the npm scripts**

In `C:\Users\dmcgowa2\Documents\Codex NASA Folder\package.json`, the `scripts` block currently reads
(lines 6–13):

```json
  "scripts": {
    "start": "electron .",
    "bridge:enqueue": "node scripts/queue-research-request.mjs",
    "bridge:run": "node scripts/run-claude-research.mjs",
    "usage:sample": "node scripts/claude-usage-recorder.mjs --sample",
    "usage:watch": "node scripts/claude-usage-recorder.mjs --watch --interval-sec 300",
    "usage:report": "node scripts/claude-usage-recorder.mjs --report"
  },
```

Change to:

```json
  "scripts": {
    "start": "electron .",
    "bridge:enqueue": "node scripts/queue-research-request.mjs",
    "bridge:run": "node scripts/run-claude-research.mjs",
    "usage:sample": "node scripts/claude-usage-recorder.mjs --sample",
    "usage:watch": "node scripts/claude-usage-recorder.mjs --watch --interval-sec 300",
    "usage:report": "node scripts/claude-usage-recorder.mjs --report",
    "memory:sample": "node scripts/memory-recorder.mjs --sample",
    "memory:watch": "node scripts/memory-recorder.mjs --watch --interval-sec 20",
    "memory:report": "node scripts/memory-recorder.mjs --report"
  },
```

- [ ] **Step 4: Verify via npm**

Run: `cd "C:\Users\dmcgowa2\Documents\Codex NASA Folder" ; npm run memory:sample`
Expected: same JSON as Task 1 Step 2, now via the npm alias.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/dmcgowa2/Documents/Codex NASA Folder"
git add scripts/memory-recorder.mjs package.json
git commit -m "memory-recorder.mjs: add --pids/--events/--watch/--report modes + npm scripts"
```

---

## Task 3: Python — `sample_memory()` subprocess wrapper with graceful degradation

**Files:**
- Modify: `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py` (add near `find_pid_on_port`, currently
  line ~5323 — re-locate with `Grep -n "def find_pid_on_port"` first)
- Test: inline in `self_test()` (currently ends line 5320 with `return 0 if ok == total else 1` —
  re-locate with `Grep -n "return 0 if ok == total"`)

- [ ] **Step 1: Write the failing test**

Insert immediately before `return 0 if ok == total else 1` (case number continues from wherever
`self_test()` currently ends — check the last `total += 1` block's number and increment by one; as of
this plan's writing that's case 105):

```python
    # 105) Memory tracker (2026-07-08): sample_memory() must degrade gracefully when node isn't on
    #      PATH, never raise, and never fabricate numbers.
    total += 1
    old_path105 = globals().get("MEMORY_RECORDER_PATH")
    globals()["MEMORY_RECORDER_PATH"] = os.path.join(os.path.dirname(os.path.abspath(__file__)), "does-not-exist-105.mjs")
    old_which105 = shutil.which
    shutil.which = lambda name: None  # force the "node not found" path deterministically
    try:
        result105 = sample_memory()
        assert result105.get("available") is False, "sample_memory must report unavailable when node is missing, not raise"
        assert "reason" in result105, "an unavailable result must say WHY"
    finally:
        shutil.which = old_which105
        if old_path105 is not None:
            globals()["MEMORY_RECORDER_PATH"] = old_path105
    ok += 1; print("  PASS memory tracker: sample_memory() degrades to available=False when node is missing (no raise)")
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "NameError|sample_memory"`

Expected: `NameError: name 'sample_memory' is not defined` (or `MEMORY_RECORDER_PATH` undefined) — the
function doesn't exist yet.

- [ ] **Step 3: Add the `shutil` import, the path constant, and `sample_memory()`**

`shutil` is not currently imported (confirm with `Grep -n "^import shutil"` — the codebase currently
imports it locally inside several `self_test()` cases via `import tempfile, shutil`, never at module
level). Add it to the top-level import block (currently lines 31–46, alphabetical):

```python
import shutil
```
(insert between `import re` and `import socket`, keeping the existing alphabetical order)

Then, immediately before `def find_pid_on_port(port):` (currently line 5323 — re-check with Grep),
insert:

```python
MEMORY_RECORDER_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),  # ~/.claude
    "..", "Documents", "Codex NASA Folder", "scripts", "memory-recorder.mjs")
MEMORY_RECORDER_PATH = os.path.normpath(MEMORY_RECORDER_PATH)


def sample_memory():
    """One live memory snapshot via memory-recorder.mjs --sample --quiet, timeout-guarded. Never
    raises: node missing, a timeout, or bad JSON all return an explicit {"available": False, "reason":
    ...} shape rather than crashing the /api/memory handler (matches session_usage()'s best-effort
    convention elsewhere in this file)."""
    node = shutil.which("node")
    if not node:
        return {"available": False, "reason": "node not found on PATH"}
    if not os.path.isfile(MEMORY_RECORDER_PATH):
        return {"available": False, "reason": "memory-recorder.mjs not found at %s" % MEMORY_RECORDER_PATH}
    try:
        r = subprocess.run([node, MEMORY_RECORDER_PATH, "--sample", "--quiet"],
                            capture_output=True, text=True, timeout=5, creationflags=_NO_WINDOW)
    except subprocess.TimeoutExpired:
        return {"available": False, "reason": "memory-recorder.mjs timed out after 5s"}
    except OSError as e:
        return {"available": False, "reason": "failed to launch node: %s" % e}
    if r.returncode != 0:
        return {"available": False, "reason": "memory-recorder.mjs exited %d: %s" % (r.returncode, r.stderr[:200])}
    try:
        data = json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"available": False, "reason": "memory-recorder.mjs returned non-JSON output"}
    data["available"] = True
    return data
```

- [ ] **Step 4: Run it and verify it passes**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "PASS memory tracker: sample_memory|self-test cases passed"`

Expected: `PASS memory tracker: sample_memory() degrades...` and `105/105 self-test cases passed`.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/dmcgowa2/.claude/tools"
git status  # confirm what's tracked here before committing -- this dir may not be its own repo
```

Note: `~/.claude/tools/` is the LIVE copy; this repo's actual git home is `claude-global-config`. Do
NOT commit here per-task — Task 14 syncs the mirror and commits once for the whole feature (see File
Structure note above). Skip this step; move to Task 4.

---

## Task 4: Python — bucket classifier (pure function)

**Files:**
- Modify: `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py` (add after `sample_memory()` from Task 3)
- Test: inline in `self_test()`

- [ ] **Step 1: Write the failing test**

```python
    # 106) Memory tracker: bucket classifier matches Douglas's exact 5 groups, first-match-wins order,
    #      unmatched names fall into 'other' rather than being silently dropped.
    total += 1
    assert classify_memory_bucket("claude") == "agent_apps"
    assert classify_memory_bucket("Codex") == "agent_apps"
    assert classify_memory_bucket("node") == "dev_runtimes"
    assert classify_memory_bucket("WindowsTerminal") == "dev_runtimes"
    assert classify_memory_bucket("chrome") == "browsers_ui"
    assert classify_memory_bucket("msedgewebview2") == "browsers_ui"
    assert classify_memory_bucket("Obsidian") == "browsers_ui"
    assert classify_memory_bucket("SentinelAgent") == "nasa_enterprise"
    assert classify_memory_bucket("splunkd") == "nasa_enterprise", "splunk* must match as a prefix"
    assert classify_memory_bucket("CcmExec") == "nasa_enterprise"
    assert classify_memory_bucket("svchost") == "system"
    assert classify_memory_bucket("dwm") == "system"
    assert classify_memory_bucket("some_random_thing") == "other", "an unmatched name must fall into other, not vanish"
    assert classify_memory_bucket("") == "other"
    ok += 1; print("  PASS memory tracker: classify_memory_bucket covers all 5 buckets + other, case-insensitive")
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "NameError"`
Expected: `NameError: name 'classify_memory_bucket' is not defined`.

- [ ] **Step 3: Implement it**

```python
MEMORY_BUCKETS = [
    ("agent_apps", "Agent apps", ["claude", "codex"]),
    ("dev_runtimes", "Dev runtimes", ["node", "python", "powershell", "windowsterminal"]),
    ("browsers_ui", "Browsers/UI shells", ["chrome", "msedgewebview2", "obsidian"]),
    ("nasa_enterprise", "NASA endpoint/enterprise", ["sentinelagent", "splunk", "ccmexec", "sysinfocap"]),
    ("system", "System", ["svchost", "dwm", "wmiprvse"]),
]


def classify_memory_bucket(process_name):
    """Which of Douglas's 5 'large package pressure' buckets a process name belongs to, or 'other' if
    none match - never silently drops a process. First-match-wins over MEMORY_BUCKETS in order;
    case-insensitive substring match (so 'splunkd' matches the 'splunk' prefix, matching the spec's
    'splunk*' entry)."""
    name = (process_name or "").strip().lower()
    if not name:
        return "other"
    for key, _label, needles in MEMORY_BUCKETS:
        for needle in needles:
            if needle in name:
                return key
    return "other"
```

- [ ] **Step 4: Run it and verify it passes**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "PASS memory tracker: classify_memory_bucket|cases passed"`
Expected: `PASS memory tracker: classify_memory_bucket...` and `106/106 self-test cases passed`.

- [ ] **Step 5: (no commit — batched in Task 14, per File Structure note)**

---

## Task 5: Python — trend ring buffer + `classify_trend`

**Files:**
- Modify: `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py` (add after Task 4's code)
- Test: inline in `self_test()`

- [ ] **Step 1: Write the failing test**

```python
    # 107) Memory tracker: classify_trend compares latest vs OLDEST sample in the ring (not vs the
    #      immediately-prior one), using the decided +-2pp commitPct threshold; <2 samples -> unknown.
    total += 1
    from collections import deque as _deque107
    ring107 = _deque107(maxlen=8)
    assert classify_trend(ring107) == "unknown", "an empty ring must report unknown, not guess"
    ring107.append({"commitPct": 0.50})
    assert classify_trend(ring107) == "unknown", "a single sample must report unknown, not guess"
    ring107.append({"commitPct": 0.53})
    assert classify_trend(ring107) == "growing", "a +3pp delta must read as growing (threshold is +-2pp)"
    ring107.append({"commitPct": 0.51})  # oldest is still 0.50 -> delta vs oldest = +1pp = flat
    assert classify_trend(ring107) == "flat", "must compare vs the OLDEST in-ring sample, not the prior one"
    ring208 = _deque107([{"commitPct": 0.60}, {"commitPct": 0.55}], maxlen=8)
    assert classify_trend(ring208) == "dropping", "a -5pp delta must read as dropping"
    ok += 1; print("  PASS memory tracker: classify_trend compares vs oldest-in-ring, +-2pp threshold, unknown under 2 samples")
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "NameError"`
Expected: `NameError: name 'classify_trend' is not defined`.

- [ ] **Step 3: Implement the ring buffer + classifier**

```python
_MEMORY_RING_LOCK = threading.Lock()
_MEMORY_RING = collections.deque(maxlen=8)  # ~8 polls at the ~20s cadence = ~2-3 min of live history
MEMORY_TREND_THRESHOLD_PP = 0.02  # 2 percentage points of commitPct


def classify_trend(ring):
    """growing/flat/dropping/unknown from the trend ring buffer - compares the LATEST sample's
    commitPct against the OLDEST sample currently in the ring (the widest window the ring holds, ~2-3
    min at the dashboard's ~20s poll cadence), not the immediately-prior sample. Fewer than 2 samples
    -> 'unknown', an honest admission rather than a guess from insufficient data."""
    if len(ring) < 2:
        return "unknown"
    oldest = ring[0]["commitPct"]
    latest = ring[-1]["commitPct"]
    delta = latest - oldest
    if delta > MEMORY_TREND_THRESHOLD_PP:
        return "growing"
    if delta < -MEMORY_TREND_THRESHOLD_PP:
        return "dropping"
    return "flat"
```

`collections` is not currently imported at module level — add `import collections` to the top-level
import block (alphabetically, between `import concurrent.futures` and `import contextlib`).

- [ ] **Step 4: Run it and verify it passes**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "PASS memory tracker: classify_trend|cases passed"`
Expected: `PASS memory tracker: classify_trend...` and `107/107 self-test cases passed`.

---

## Task 6: Python — `memory_alerts()` threshold classifier

**Files:**
- Modify: `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py` (add after Task 5's code)
- Test: inline in `self_test()`

- [ ] **Step 1: Write the failing test**

```python
    # 108) Memory tracker: memory_alerts applies Douglas's exact thresholds (available <6GB warn, <3GB
    #      critical; commit >85% warn, >92% crisis), boundary-inclusive, multiple alerts can co-occur.
    total += 1
    GB108 = 1024 ** 3
    assert memory_alerts({"availableBytes": 10 * GB108, "commitPct": 0.50}) == []
    assert memory_alerts({"availableBytes": 6 * GB108, "commitPct": 0.50}) == [], "exactly 6GB must NOT warn (boundary is < not <=)"
    assert "available_warn" in memory_alerts({"availableBytes": 5.9 * GB108, "commitPct": 0.50})
    assert "available_critical" in memory_alerts({"availableBytes": 2.9 * GB108, "commitPct": 0.50})
    assert "available_critical" not in memory_alerts({"availableBytes": 3 * GB108, "commitPct": 0.50}), "exactly 3GB must NOT be critical"
    assert "commit_warn" in memory_alerts({"availableBytes": 10 * GB108, "commitPct": 0.86})
    assert "commit_crisis" in memory_alerts({"availableBytes": 10 * GB108, "commitPct": 0.93})
    both108 = memory_alerts({"availableBytes": 2 * GB108, "commitPct": 0.95})
    assert "available_critical" in both108 and "commit_crisis" in both108, "both alerts must be able to co-occur"
    ok += 1; print("  PASS memory tracker: memory_alerts applies exact thresholds, boundary-correct, co-occurring alerts")
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "NameError"`
Expected: `NameError: name 'memory_alerts' is not defined`.

- [ ] **Step 3: Implement it**

```python
MEMORY_AVAILABLE_WARN_BYTES = 6 * 1024 ** 3
MEMORY_AVAILABLE_CRITICAL_BYTES = 3 * 1024 ** 3
MEMORY_COMMIT_WARN_PCT = 0.85
MEMORY_COMMIT_CRISIS_PCT = 0.92


def memory_alerts(sample):
    """Douglas's exact thresholds: available RAM <6GB warn, <3GB critical; commit >85% warn, >92%
    crisis. Boundary-exclusive (< / >, not <= / >=) so a value sitting exactly on the line does not
    alert - matches this file's existing boundary convention (e.g. size_risk's >= for a different,
    intentionally-inclusive case; here Douglas's spec language was 'less than'/'greater than'). Returns
    a list so more than one alert can co-occur (e.g. both available_critical and commit_crisis)."""
    alerts = []
    avail = sample.get("availableBytes", 0)
    commit = sample.get("commitPct", 0)
    if avail < MEMORY_AVAILABLE_CRITICAL_BYTES:
        alerts.append("available_critical")
    elif avail < MEMORY_AVAILABLE_WARN_BYTES:
        alerts.append("available_warn")
    if commit > MEMORY_COMMIT_CRISIS_PCT:
        alerts.append("commit_crisis")
    elif commit > MEMORY_COMMIT_WARN_PCT:
        alerts.append("commit_warn")
    return alerts
```

- [ ] **Step 4: Run it and verify it passes**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "PASS memory tracker: memory_alerts|cases passed"`
Expected: `PASS memory tracker: memory_alerts...` and `108/108 self-test cases passed`.

---

## Task 7: Python — tail-read last JSONL line helper (for `/api/usage`)

**Files:**
- Modify: `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py` (add after Task 6's code)
- Test: inline in `self_test()`

- [ ] **Step 1: Write the failing test**

```python
    # 109) Memory tracker: _tail_last_jsonl_line reads only the LAST line of a JSONL file without
    #      parsing the whole file (usage-samples.jsonl can be thousands of lines) - empty/missing file
    #      returns None, not a crash.
    total += 1
    import tempfile as _tf109
    path109 = _tf109.mktemp(suffix=".jsonl")
    assert _tail_last_jsonl_line(path109) is None, "a missing file must return None"
    with open(path109, "w", encoding="utf-8") as _f109:
        _f109.write('{"a":1}\n{"a":2}\n{"a":3}\n')
    assert _tail_last_jsonl_line(path109) == {"a": 3}, "must return the LAST record, parsed"
    with open(path109, "w", encoding="utf-8") as _f109:
        _f109.write("")
    assert _tail_last_jsonl_line(path109) is None, "an empty file must return None, not crash"
    with open(path109, "w", encoding="utf-8") as _f109:
        _f109.write('{"a":1}\n{"a":2}\n')  # no trailing newline on last line
    assert _tail_last_jsonl_line(path109) == {"a": 2}, "must handle a file with no trailing newline"
    os.remove(path109)
    ok += 1; print("  PASS memory tracker: _tail_last_jsonl_line reads only the last record, handles missing/empty/no-trailing-newline")
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "NameError"`
Expected: `NameError: name '_tail_last_jsonl_line' is not defined`.

- [ ] **Step 3: Implement it**

```python
def _tail_last_jsonl_line(path, max_seek_bytes=65536):
    """Parse ONLY the last line of a JSONL file without reading/parsing the whole thing - usage-
    samples.jsonl can grow to thousands of rows, and this is called on every /api/usage poll. Seeks
    backward from EOF up to max_seek_bytes (a single JSON record is never remotely that large here) and
    splits on newlines, rather than a full readlines(). Returns None for a missing/empty file or a file
    whose tail has no parseable JSON line - never raises."""
    try:
        size = os.path.getsize(path)
    except OSError:
        return None
    if size == 0:
        return None
    try:
        with open(path, "rb") as f:
            seek_from = max(0, size - max_seek_bytes)
            f.seek(seek_from)
            tail = f.read().decode("utf-8", errors="replace")
    except OSError:
        return None
    lines = [ln for ln in tail.splitlines() if ln.strip()]
    if not lines:
        return None
    try:
        return json.loads(lines[-1])
    except json.JSONDecodeError:
        return None
```

- [ ] **Step 4: Run it and verify it passes**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "PASS memory tracker: _tail_last_jsonl_line|cases passed"`
Expected: `PASS memory tracker: _tail_last_jsonl_line...` and `109/109 self-test cases passed`.

---

## Task 8: Python — `GET /api/memory` and `GET /api/memory/events` endpoints

**Files:**
- Modify: `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py`:
  - Add `build_memory_payload()` after Task 7's code (before `find_pid_on_port`)
  - Modify `do_GET` routing — locate the real handler with `Grep -n 'def do_GET' ` and find the one
    inside `class Handler` (NOT the ones inside `self_test()`'s own test fixtures); insert a new
    `elif` branch right after the existing `elif parsed.path == "/api/discovered":` block

- [ ] **Step 1: Write the failing test**

```python
    # 110) Memory tracker: build_memory_payload merges a raw sample_memory()-shaped dict into the full
    #      API shape (groups/topProcesses/trend/alerts), independent of the live subprocess call, and
    #      handles available=False without crashing.
    total += 1
    fake_sample110 = {
        "available": True, "schemaVersion": 1, "timestamp": "2026-07-08T00:00:00Z",
        "physicalTotalBytes": 34000000000, "availableBytes": 2000000000,
        "commitBytes": 40000000000, "commitLimitBytes": 65000000000,
        "commitPct": 0.93, "pagefilePct": 0.05,
        "pagedPoolBytes": 1, "nonpagedPoolBytes": 1, "cacheBytes": 1,
        "processes": [
            {"name": "claude", "pid": 1, "privateBytes": 9_000_000_000, "workingSetBytes": 6_000_000_000},
            {"name": "node", "pid": 2, "privateBytes": 1_000_000_000, "workingSetBytes": 1_000_000_000},
            {"name": "node", "pid": 3, "privateBytes": 500_000_000, "workingSetBytes": 500_000_000},
            {"name": "weird_unmatched_proc", "pid": 4, "privateBytes": 1, "workingSetBytes": 1},
        ],
    }
    with _MEMORY_RING_LOCK:
        _MEMORY_RING.clear()
    payload110 = build_memory_payload(fake_sample110)
    assert payload110["available"] is True
    group_keys110 = {g["key"] for g in payload110["groups"]}
    assert {"agent_apps", "dev_runtimes", "other"}.issubset(group_keys110), "buckets present in the sample must appear in groups"
    node_group110 = next(g for g in payload110["groups"] if g["key"] == "dev_runtimes")
    assert node_group110["count"] == 1 and node_group110["privateBytes"] == 1_500_000_000, "the two node PIDs must be summed into one group row"
    assert len(payload110["topProcesses"]) == 4, "topProcesses lists individual processes, not grouped"
    assert "available_critical" in payload110["alerts"] and "commit_crisis" in payload110["alerts"]
    assert payload110["trend"] == "unknown", "first sample ever pushed to the ring must read as unknown, not a guess"
    unavailable110 = build_memory_payload({"available": False, "reason": "node not found on PATH"})
    assert unavailable110["available"] is False and unavailable110["reason"] == "node not found on PATH"
    assert unavailable110["groups"] == [] and unavailable110["topProcesses"] == [], "an unavailable sample must return empty collections, not crash"
    ok += 1; print("  PASS memory tracker: build_memory_payload groups/sums/tops/alerts/trend correctly, degrades cleanly when unavailable")
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "NameError"`
Expected: `NameError: name 'build_memory_payload' is not defined`.

- [ ] **Step 3: Implement `build_memory_payload` and wire the endpoints**

Add before `find_pid_on_port`:

```python
MEMORY_TOP_PROCESSES_N = 15


def build_memory_payload(sample):
    """Merge a raw sample_memory()-shaped dict into the full /api/memory response: per-bucket group
    sums, the top N individual processes by privateBytes, the current trend (pushing this sample into
    the shared ring first), and alerts. If the sample is unavailable, returns the same shape with empty
    collections and available=False rather than raising - the frontend always gets a renderable payload."""
    if not sample.get("available"):
        return {
            "available": False, "reason": sample.get("reason", "unknown"),
            "groups": [], "topProcesses": [], "trend": "unknown", "alerts": [],
        }
    processes = sample.get("processes") or []
    group_totals = {}
    for p in processes:
        key = classify_memory_bucket(p.get("name"))
        g = group_totals.setdefault(key, {"key": key, "count": 0, "privateBytes": 0, "workingSetBytes": 0})
        g["count"] += 1
        g["privateBytes"] += p.get("privateBytes", 0)
        g["workingSetBytes"] += p.get("workingSetBytes", 0)
    label_by_key = {k: label for k, label, _needles in MEMORY_BUCKETS}
    label_by_key["other"] = "Other"
    groups = []
    for key, g in group_totals.items():
        g["label"] = label_by_key.get(key, key)
        groups.append(g)
    groups.sort(key=lambda g: g["privateBytes"], reverse=True)
    top_processes = sorted(processes, key=lambda p: p.get("privateBytes", 0), reverse=True)[:MEMORY_TOP_PROCESSES_N]
    with _MEMORY_RING_LOCK:
        _MEMORY_RING.append({"commitPct": sample.get("commitPct", 0), "ts": sample.get("timestamp")})
        trend = classify_trend(_MEMORY_RING)
    alerts = memory_alerts(sample)
    out = dict(sample)
    out["groups"] = groups
    out["topProcesses"] = top_processes
    out["trend"] = trend
    out["alerts"] = alerts
    out.pop("processes", None)  # raw per-process list stays internal; the API surfaces groups + top N
    return out


def sample_memory_events():
    """Recent low-memory Windows Event Log entries via memory-recorder.mjs --events. Same fail-safe
    shape convention as sample_memory(): never raises, returns available=False with a reason on any
    failure. An empty events list on success is a real, honest result (nothing fired in the window),
    not a failure."""
    node = shutil.which("node")
    if not node:
        return {"available": False, "reason": "node not found on PATH", "events": []}
    try:
        r = subprocess.run([node, MEMORY_RECORDER_PATH, "--events", "--quiet"],
                            capture_output=True, text=True, timeout=8, creationflags=_NO_WINDOW)
    except subprocess.TimeoutExpired:
        return {"available": False, "reason": "memory-recorder.mjs --events timed out", "events": []}
    except OSError as e:
        return {"available": False, "reason": "failed to launch node: %s" % e, "events": []}
    if r.returncode != 0:
        return {"available": False, "reason": "exited %d: %s" % (r.returncode, r.stderr[:200]), "events": []}
    try:
        data = json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"available": False, "reason": "non-JSON output", "events": []}
    data["available"] = True
    return data
```

Then, in the real `do_GET` (inside `class Handler`, NOT inside `self_test()` — re-locate with
`Grep -n 'elif parsed.path == "/api/discovered"'` to find the exact current line), insert immediately
after that block:

```python
        elif parsed.path == "/api/memory":
            self._json(build_memory_payload(sample_memory()))
        elif parsed.path == "/api/memory/events":
            self._json(sample_memory_events())
```

- [ ] **Step 4: Run it and verify it passes**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "PASS memory tracker: build_memory_payload|cases passed"`
Expected: `PASS memory tracker: build_memory_payload...` and `110/110 self-test cases passed`.

- [ ] **Step 5: Live-verify against the real running dashboard**

Run (PowerShell): `Invoke-RestMethod http://127.0.0.1:8756/api/memory | ConvertTo-Json -Depth 6`
Expected: real numbers, `available:true`, `groups` covering real buckets on this machine (should include
`agent_apps`, `dev_runtimes`, likely `browsers_ui`), `trend:"unknown"` on the first hit (ring was just
cleared/empty for this process), settling to `growing`/`flat`/`dropping` after a few polls.

Run: `Invoke-RestMethod http://127.0.0.1:8756/api/memory/events | ConvertTo-Json -Depth 6`
Expected: valid JSON, `events` array (0 entries is fine — note in the final report whether this machine's
event log actually has any 2004/2005 entries in the last 24h, per the spec's honesty requirement).

---

## Task 9: Python — `GET /api/usage` endpoint

**Files:**
- Modify: `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py` (add `build_usage_payload()` after
  Task 8's code; add one more `elif` to `do_GET`)
- Test: inline in `self_test()`

- [ ] **Step 1: Write the failing test**

```python
    # 111) Memory tracker: build_usage_payload reads latest-rate-limits.json + tails usage-samples.jsonl
    #      WITHOUT touching state.json (the 18MB raw event ledger) - honest about staleness, never
    #      fabricates a percentage that isn't there.
    total += 1
    import tempfile as _tf111, shutil as _sh111, time as _time111
    dir111 = _tf111.mkdtemp()
    try:
        limits_path111 = os.path.join(dir111, "latest-rate-limits.json")
        samples_path111 = os.path.join(dir111, "usage-samples.jsonl")
        with open(limits_path111, "w", encoding="utf-8") as _f111:
            json.dump({"available": True, "fiveHour": {"usedPercentage": 42.5}, "sevenDay": {"usedPercentage": 18.0},
                       "capturedAt": "2026-07-08T00:00:00Z"}, _f111)
        with open(samples_path111, "w", encoding="utf-8") as _f111:
            _f111.write(json.dumps({"tokenUsage": {"today": {"total": {"apiEquivalentUsd": 3.21}}}}) + "\n")
        payload111 = build_usage_payload(limits_path111, samples_path111)
        assert payload111["fiveHourPct"] == 42.5 and payload111["sevenDayPct"] == 18.0
        assert payload111["todayUsd"] == 3.21
        assert "ageSeconds" in payload111, "must report how stale the reading is, not imply it's live"
        missing111 = build_usage_payload(os.path.join(dir111, "nope.json"), os.path.join(dir111, "nope2.jsonl"))
        assert missing111["available"] is False, "missing usage-estimator files must degrade cleanly, not crash"
    finally:
        _sh111.rmtree(dir111, ignore_errors=True)
    ok += 1; print("  PASS memory tracker: build_usage_payload reads rate-limits+tail-sample honestly, degrades on missing files")
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "NameError"`
Expected: `NameError: name 'build_usage_payload' is not defined`.

- [ ] **Step 3: Implement it**

```python
USAGE_ESTIMATOR_DIR = os.path.join(os.path.expanduser("~"), ".claude", "usage-estimator")


def build_usage_payload(limits_path=None, samples_path=None):
    """Read-only surfacing of the ALREADY-CAPTURED usage history in ~/.claude/usage-estimator/ - never
    parses the 18MB state.json raw event ledger, never triggers a new capture. limits_path/samples_path
    are injectable for testing; production calls use the real USAGE_ESTIMATOR_DIR files. Reports
    ageSeconds honestly so the frontend can show 'last sampled Xm ago' rather than implying live data -
    nothing here keeps `usage:watch` running."""
    limits_path = limits_path or os.path.join(USAGE_ESTIMATOR_DIR, "latest-rate-limits.json")
    samples_path = samples_path or os.path.join(USAGE_ESTIMATOR_DIR, "usage-samples.jsonl")
    limits = None
    try:
        with open(limits_path, encoding="utf-8") as f:
            limits = json.load(f)
    except (OSError, json.JSONDecodeError):
        pass
    if not limits or not limits.get("available"):
        return {"available": False, "fiveHourPct": None, "sevenDayPct": None, "todayUsd": None, "ageSeconds": None}
    last_sample = _tail_last_jsonl_line(samples_path)
    today_usd = None
    if last_sample:
        today_usd = (((last_sample.get("tokenUsage") or {}).get("today") or {}).get("total") or {}).get("apiEquivalentUsd")
    captured_at = limits.get("capturedAt")
    age_seconds = None
    if captured_at:
        try:
            import datetime as _dt
            parsed = _dt.datetime.fromisoformat(captured_at.replace("Z", "+00:00"))
            age_seconds = max(0, int((_dt.datetime.now(_dt.timezone.utc) - parsed).total_seconds()))
        except ValueError:
            pass
    return {
        "available": True,
        "fiveHourPct": (limits.get("fiveHour") or {}).get("usedPercentage"),
        "sevenDayPct": (limits.get("sevenDay") or {}).get("usedPercentage"),
        "todayUsd": today_usd,
        "ageSeconds": age_seconds,
    }
```

Add to `do_GET`, right after the `/api/memory/events` branch added in Task 8:

```python
        elif parsed.path == "/api/usage":
            self._json(build_usage_payload())
```

- [ ] **Step 4: Run it and verify it passes**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "PASS memory tracker: build_usage_payload|cases passed"`
Expected: `PASS memory tracker: build_usage_payload...` and `111/111 self-test cases passed`.

- [ ] **Step 5: Live-verify**

Run: `Invoke-RestMethod http://127.0.0.1:8756/api/usage | ConvertTo-Json`
Expected: real `fiveHourPct`/`sevenDayPct` numbers if `~/.claude/usage-estimator/latest-rate-limits.json`
exists and is marked available (confirmed present earlier this session), a real `ageSeconds` (likely
large, since no `usage:watch` process is currently running — this is the expected, honest behavior per
the design, not a bug).

---

## Task 10: Python — Servers-tab memory column

**Files:**
- Modify: `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py` — the real `do_GET`'s
  `elif parsed.path == "/api/servers":` block (currently line ~5508, inside `class Handler` — re-locate
  with `Grep -n 'elif parsed.path == "/api/servers"'` and take the one INSIDE the real `do_GET`, i.e.
  after `class Handler` starts around line 5425, not any occurrence inside `self_test()`)
- Test: inline in `self_test()`

- [ ] **Step 1: Write the failing test**

```python
    # 112) Memory tracker: attach_server_memory resolves each config's PID via find_pid_on_port and
    #      merges memory in via ONE batched --pids call (not one call per server) - a server with no
    #      resolvable PID gets memory=None, never a crash or a fabricated number.
    total += 1
    def _fake_find_pid112(port):
        return {9001: 111, 9002: 222}.get(port)
    def _fake_pids_sample112(pids):
        assert sorted(pids) == [111, 222], "must batch ALL resolved PIDs into one call, not one per server: got %r" % pids
        return {"available": True, "processes": [
            {"pid": 111, "name": "a", "privateBytes": 500, "workingSetBytes": 600},
            {"pid": 222, "name": "b", "privateBytes": 700, "workingSetBytes": 800},
        ]}
    configs112 = [{"id": "x::a", "port": 9001}, {"id": "x::b", "port": 9002}, {"id": "x::c", "port": 9003}]
    old_fpp112 = find_pid_on_port
    globals()["find_pid_on_port"] = _fake_find_pid112
    try:
        out112 = attach_server_memory(configs112, sample_pids_fn=_fake_pids_sample112)
    finally:
        globals()["find_pid_on_port"] = old_fpp112
    by_id112 = {c["id"]: c for c in out112}
    assert by_id112["x::a"]["memory"]["privateBytes"] == 500
    assert by_id112["x::b"]["memory"]["privateBytes"] == 700
    assert by_id112["x::c"]["memory"] is None, "a server with no resolvable PID must get memory=None, not crash or a fake 0"
    ok += 1; print("  PASS memory tracker: attach_server_memory batches PIDs into one call, unresolvable server -> memory=None")
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "NameError"`
Expected: `NameError: name 'attach_server_memory' is not defined`.

- [ ] **Step 3: Implement it**

```python
def sample_memory_pids(pids):
    """Per-PID memory lookup via memory-recorder.mjs --pids, for the Servers tab (guarantees a number
    for every registered server regardless of whether it'd make a 'top N by memory' cut). Same fail-
    safe shape as sample_memory(). pids: an iterable of ints."""
    pid_list = [p for p in pids if isinstance(p, int)]
    if not pid_list:
        return {"available": True, "processes": []}
    node = shutil.which("node")
    if not node:
        return {"available": False, "reason": "node not found on PATH", "processes": []}
    try:
        r = subprocess.run([node, MEMORY_RECORDER_PATH, "--pids", ",".join(str(p) for p in pid_list), "--quiet"],
                            capture_output=True, text=True, timeout=5, creationflags=_NO_WINDOW)
    except subprocess.TimeoutExpired:
        return {"available": False, "reason": "memory-recorder.mjs --pids timed out", "processes": []}
    except OSError as e:
        return {"available": False, "reason": "failed to launch node: %s" % e, "processes": []}
    if r.returncode != 0:
        return {"available": False, "reason": "exited %d" % r.returncode, "processes": []}
    try:
        data = json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"available": False, "reason": "non-JSON output", "processes": []}
    data["available"] = True
    return data


def attach_server_memory(configs, sample_pids_fn=sample_memory_pids):
    """For each server config, resolve its PID via find_pid_on_port (already used by stop_port) and
    merge in a 'memory' field: {privateBytes, workingSetBytes} if resolved, None if the server isn't
    running or its PID can't be found. Resolves ALL PIDs first, then makes exactly ONE batched
    sample_memory_pids() call - never one subprocess spawn per server row. sample_pids_fn is injectable
    for testing; production calls use the real sample_memory_pids."""
    pid_by_id = {}
    for cfg in configs:
        pid = find_pid_on_port(cfg["port"])
        if pid:
            pid_by_id[cfg["id"]] = pid
    sample = sample_pids_fn(list(pid_by_id.values())) if pid_by_id else {"available": True, "processes": []}
    by_pid = {p["pid"]: p for p in (sample.get("processes") or [])}
    for cfg in configs:
        pid = pid_by_id.get(cfg["id"])
        proc = by_pid.get(pid) if pid else None
        cfg["memory"] = ({"privateBytes": proc["privateBytes"], "workingSetBytes": proc["workingSetBytes"]}
                          if proc else None)
    return configs
```

Then modify the real `/api/servers` handler (inside `class Handler`'s `do_GET`) from:

```python
        elif parsed.path == "/api/servers":
            configs = load_server_configs()
            for c in configs:
                c["running"] = port_listening(c["port"])
                c["health"] = "healthy" if (c["running"] and check_http_health(c["port"])) else \
                               ("unhealthy" if c["running"] else "stopped")
            self._json(configs)
```

to:

```python
        elif parsed.path == "/api/servers":
            configs = load_server_configs()
            for c in configs:
                c["running"] = port_listening(c["port"])
                c["health"] = "healthy" if (c["running"] and check_http_health(c["port"])) else \
                               ("unhealthy" if c["running"] else "stopped")
            attach_server_memory(configs)
            self._json(configs)
```

- [ ] **Step 4: Run it and verify it passes**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "PASS memory tracker: attach_server_memory|cases passed"`
Expected: `PASS memory tracker: attach_server_memory...` and `112/112 self-test cases passed`.

- [ ] **Step 5: Live-verify**

Run: `Invoke-RestMethod http://127.0.0.1:8756/api/servers | ConvertTo-Json -Depth 4`
Expected: each server config now has a `memory` field — non-null for any currently-running registered
server, `null` for stopped ones.

---

## Task 11: Frontend — Memory tab (icon, panel, CSS, JS render + poll)

**Files:**
- Modify: `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py`, inside the `PAGE` string:
  - Tab rail (currently lines 2063–2073 — re-locate with `Grep -n 'class="tabrail"'`): add a 4th
    `<button class="tab-btn" data-tab="memory">`
  - After the `servers` `<section class="tabpanel">` block (currently ends ~line 2129): add a new
    `<section class="tabpanel" data-panel="memory">`
  - CSS block (`:root` starts ~line 1751): add a small set of memory-tab-specific classes reusing
    existing variables — no new visual system
  - JS: add `refreshMemory()` + render function, wire into the poll-interval block (currently lines
    ~3210–3214, `setInterval(refresh, 6000)` etc.), extend the tab-switch localStorage logic
- Test: inline in `self_test()` (asserts on the `PAGE` string, matching this file's existing convention
  for verifying frontend structure without a browser)

- [ ] **Step 1: Write the failing test**

```python
    # 113) Memory tracker: the 4th tab exists, is wired into the poll loop, and the render function
    #      uses labels/data only (no explanatory prose, per Douglas's standing no-commentary-text rule).
    total += 1
    assert 'data-tab="memory"' in PAGE, "the tab rail needs a 4th Memory tab button"
    assert 'data-panel="memory"' in PAGE, "a memory tabpanel section must exist"
    assert "function refreshMemory(" in PAGE, "a refreshMemory JS function must exist"
    assert re.search(r"setInterval\(refreshMemory,\s*\d+\)", PAGE), "refreshMemory must be on the periodic poll loop like the other panels"
    assert "This dashboard shows" not in PAGE and "This panel displays" not in PAGE, \
        "no explanatory commentary text in the memory tab (Douglas's standing no-commentary-text rule)"
    ok += 1; print("  PASS memory tracker: Memory tab wired into rail + poll loop, no commentary text")
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "AssertionError"`
Expected: `AssertionError: the tab rail needs a 4th Memory tab button`.

- [ ] **Step 3: Add the tab button**

In the tab rail (after the existing `servers` button, before `</nav>` — currently lines 2070–2073):

```html
    <button class="tab-btn" data-tab="servers" role="tab" aria-selected="false" title="Servers &amp; processes">
      <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><rect x="3" y="4.5" width="18" height="6" rx="1.4"/><rect x="3" y="13.5" width="18" height="6" rx="1.4"/><circle cx="6.8" cy="7.5" r="0.95" fill="currentColor" stroke="none"/><circle cx="6.8" cy="16.5" r="0.95" fill="currentColor" stroke="none"/></svg>
    </button>
    <button class="tab-btn" data-tab="memory" role="tab" aria-selected="false" title="Memory &amp; usage">
      <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><rect x="4" y="3" width="16" height="18" rx="1.6"/><path d="M8 8h8M8 12h8M8 16h5"/></svg>
    </button>
  </nav>
```

(the existing `servers` button is unchanged — only the new `memory` button is inserted after it, before
the closing `</nav>`)

- [ ] **Step 4: Add the tabpanel section**

After the existing `servers` `<section class="tabpanel">` block's closing `</section>` (currently right
before the `<footer` element, ~line 2129), insert:

```html
    <section class="tabpanel" data-panel="memory" role="tabpanel" hidden>
      <div class="mem-stats" id="mem-stats"><p class="empty">loading...</p></div>
      <div class="mem-buckets" id="mem-buckets"></div>
      <div class="mem-top" id="mem-top"></div>
    </section>
```

- [ ] **Step 5: Add CSS**

In the `<style>` block, after the existing `.servers-split` rules (currently ~line 1926), insert:

```css
  .mem-stats{display:flex;gap:16px;flex-wrap:wrap;margin-bottom:18px;}
  .mem-stat{background:var(--well);border:1px solid var(--line);border-radius:8px;padding:10px 14px;min-width:140px;}
  .mem-stat .mem-stat-label{font-size:var(--text-2xs);text-transform:uppercase;letter-spacing:0.05em;color:var(--muted);}
  .mem-stat .mem-stat-value{font-size:var(--text-md);font-weight:700;margin-top:2px;}
  .mem-stat.warn .mem-stat-value{color:var(--stalled);}
  .mem-stat.critical .mem-stat-value{color:var(--blocked);}
  .mem-trend-growing{color:var(--blocked);}
  .mem-trend-dropping{color:var(--active);}
  .mem-trend-flat,.mem-trend-unknown{color:var(--muted);}
  .mem-buckets{margin-bottom:18px;}
  .mem-bucket-row{display:flex;align-items:center;gap:10px;padding:6px 0;border-bottom:1px solid var(--line);font-size:var(--text-sm);}
  .mem-bucket-row .mem-bucket-label{flex:1 1 auto;}
  .mem-bucket-row .mem-bucket-count{color:var(--muted);font-size:var(--text-2xs);}
  .mem-top table{width:100%;border-collapse:collapse;font-size:var(--text-sm);}
  .mem-top td,.mem-top th{padding:4px 8px;text-align:left;border-bottom:1px solid var(--line);}
  .mem-top th{color:var(--muted);font-size:var(--text-2xs);text-transform:uppercase;letter-spacing:0.05em;font-weight:600;}
```

- [ ] **Step 6: Add the JS render + poll wiring**

After `function fmtElapsed(ts){...}` (currently ~line 2156, find the end of that function), insert:

```js
function fmtBytesGB(n){ return n == null ? '?' : (n / 1e9).toFixed(1) + ' GB'; }
function fmtPct(n){ return n == null ? '?' : Math.round(n * 100) + '%'; }
var _memBucketLabel = {agent_apps:'Agent apps', dev_runtimes:'Dev runtimes', browsers_ui:'Browsers/UI shells', nasa_enterprise:'NASA endpoint/enterprise', system:'System', other:'Other'};
async function refreshMemory(){
  try {
    var r = await fetch('/api/memory'); var d = await r.json();
    var statsEl = document.getElementById('mem-stats');
    if(!d.available){
      statsEl.innerHTML = '<p class="empty">' + esc(d.reason || 'unavailable') + '</p>';
      document.getElementById('mem-buckets').innerHTML = '';
      document.getElementById('mem-top').innerHTML = '';
      return;
    }
    var availWarn = (d.alerts || []).indexOf('available_warn') !== -1 || (d.alerts || []).indexOf('available_critical') !== -1;
    var availCrit = (d.alerts || []).indexOf('available_critical') !== -1;
    var commitWarn = (d.alerts || []).indexOf('commit_warn') !== -1 || (d.alerts || []).indexOf('commit_crisis') !== -1;
    var commitCrit = (d.alerts || []).indexOf('commit_crisis') !== -1;
    var trendCls = 'mem-trend-' + (d.trend || 'unknown');
    statsEl.innerHTML =
      '<div class="mem-stat' + (availCrit?' critical':availWarn?' warn':'') + '"><div class="mem-stat-label">Available RAM</div><div class="mem-stat-value">' + fmtBytesGB(d.availableBytes) + ' <span class="' + trendCls + '">(' + esc(d.trend || 'unknown') + ')</span></div></div>' +
      '<div class="mem-stat' + (commitCrit?' critical':commitWarn?' warn':'') + '"><div class="mem-stat-label">Commit</div><div class="mem-stat-value">' + fmtPct(d.commitPct) + '</div></div>' +
      '<div class="mem-stat"><div class="mem-stat-label">Pagefile</div><div class="mem-stat-value">' + fmtPct(d.pagefilePct) + '</div></div>';
    var buckets = (d.groups || []).slice().sort(function(a,b){ return b.privateBytes - a.privateBytes; });
    document.getElementById('mem-buckets').innerHTML = buckets.map(function(g){
      return '<div class="mem-bucket-row"><span class="mem-bucket-label">' + esc(_memBucketLabel[g.key] || g.key) + '</span>' +
        '<span class="mem-bucket-count">' + g.count + '</span><span>' + fmtBytesGB(g.privateBytes) + '</span></div>';
    }).join('');
    var top = (d.topProcesses || []);
    document.getElementById('mem-top').innerHTML = '<table><thead><tr><th>Process</th><th>PID</th><th>Private</th><th>Working set</th></tr></thead><tbody>' +
      top.map(function(p){ return '<tr><td>' + esc(p.name) + '</td><td>' + p.pid + '</td><td>' + fmtBytesGB(p.privateBytes) + '</td><td>' + fmtBytesGB(p.workingSetBytes) + '</td></tr>'; }).join('') +
      '</tbody></table>';
  } catch(e) { /* transient poll failure - next tick retries, matches every other panel's silent-retry convention */ }
}
```

Then add `refreshMemory();` (initial call) plus a poll interval next to the other `setInterval` calls
(currently lines ~3210–3214):

```js
setInterval(refresh, 6000);
setInterval(refreshServers, 6000);
setInterval(refreshDiscovered, 15000);  // a live netstat+PowerShell scan is heavier than the other polls
setInterval(refreshSessions, 10000);  // transcript scan across every project; not as cheap as a poll on one file
setInterval(refreshSkills, 30000);  // incremental + disk-cached, but only the active transcript changes between polls
refreshMemory();
setInterval(refreshMemory, 20000);  // live PowerShell/CIM shell-out each poll - same cost class as Discovered
```

Finally, find the tab-switch IIFE (`document.querySelectorAll('.tab-btn')` — currently ~line 3170–3180)
and confirm the existing generic `data-tab` → `data-panel` matching logic already handles a 4th tab with
no changes needed (it iterates `.tab-btn` and toggles the matching `[data-panel]` generically — verify
this by reading that block before assuming; if it hardcodes the 3 tab names anywhere, generalize it).

- [ ] **Step 7: Run it and verify it passes**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "PASS memory tracker: Memory tab|cases passed"`
Expected: `PASS memory tracker: Memory tab wired...` and `113/113 self-test cases passed`.

---

## Task 12: Frontend — header strip + Servers-tab memory column

**Files:**
- Modify: `C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py`, inside `PAGE`:
  - `<header class="apphdr">` (currently ~lines 2075–2083): add a header-strip `<div>` alongside the
    existing `<h1>`/help popover
  - `refreshServers()` (currently ~line 2787) and wherever server rows are rendered: add a memory cell
  - CSS: reuse `.mem-stat`-style classes from Task 11, no new system
- Test: inline in `self_test()`

- [ ] **Step 1: Write the failing test**

```python
    # 114) Memory tracker: the header strip is present and GLOBAL (outside any single tabpanel, so it's
    #      visible on every tab per Douglas's 'one place to decide' requirement); server rows show memory.
    total += 1
    apphdr_block114 = re.search(r'<header class="apphdr">.*?</header>', PAGE, re.S)
    assert apphdr_block114 and 'id="header-strip"' in apphdr_block114.group(0), \
        "the header strip must live inside <header class=\"apphdr\"> (outside all tabpanels) so it's visible on every tab"
    assert "function renderServerRow(" in PAGE or "s.memory" in PAGE, \
        "server row rendering must reference the memory field"
    ok += 1; print("  PASS memory tracker: header strip is global (in apphdr, not inside a tabpanel), server rows reference memory")
```

- [ ] **Step 2: Run it and verify it fails**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "AssertionError"`
Expected: `AssertionError: the header strip must live inside...`.

- [ ] **Step 3: Add the header strip HTML**

Modify the `<header class="apphdr">` block (currently):

```html
    <header class="apphdr">
      <div><h1>longrun dashboard</h1><div class="updated-at" id="updated"></div></div>
      <details class="help">
```

to:

```html
    <header class="apphdr">
      <div><h1>longrun dashboard</h1><div class="updated-at" id="updated"></div>
        <div class="header-strip" id="header-strip"></div>
      </div>
      <details class="help">
```

- [ ] **Step 4: Add CSS for the strip**

After the `.mem-top` CSS rules from Task 11, insert:

```css
  .header-strip{font-size:var(--text-2xs);color:var(--muted);margin-top:4px;display:flex;gap:14px;flex-wrap:wrap;}
  .header-strip .hs-crit{color:var(--blocked);}
  .header-strip .hs-warn{color:var(--stalled);}
```

- [ ] **Step 5: Populate the strip from `refreshMemory()` and add a `refreshUsage()` call**

In `refreshMemory()` (added in Task 11), after building `mem-top`, append:

```js
    document.getElementById('header-strip').dataset.mem = JSON.stringify({avail: d.availableBytes, commit: d.commitPct, availCrit: availCrit, commitCrit: commitCrit, availWarn: availWarn, commitWarn: commitWarn});
    renderHeaderStrip();
```

Add a new function (near `refreshMemory`):

```js
async function refreshUsage(){
  try {
    var r = await fetch('/api/usage'); var d = await r.json();
    document.getElementById('header-strip').dataset.usage = JSON.stringify(d);
    renderHeaderStrip();
  } catch(e) { /* transient - next tick retries */ }
}
function renderHeaderStrip(){
  var el = document.getElementById('header-strip');
  var mem = el.dataset.mem ? JSON.parse(el.dataset.mem) : null;
  var usage = el.dataset.usage ? JSON.parse(el.dataset.usage) : null;
  var parts = [];
  if(usage && usage.available){
    parts.push('Claude usage: 5h ' + (usage.fiveHourPct==null?'?':Math.round(usage.fiveHourPct)+'%') +
      ' · 7d ' + (usage.sevenDayPct==null?'?':Math.round(usage.sevenDayPct)+'%') +
      ' · today $' + (usage.todayUsd==null?'?':usage.todayUsd.toFixed(2)));
  }
  if(mem){
    var availCls = mem.availCrit ? 'hs-crit' : (mem.availWarn ? 'hs-warn' : '');
    var commitCls = mem.commitCrit ? 'hs-crit' : (mem.commitWarn ? 'hs-warn' : '');
    parts.push('Machine: <span class="' + availCls + '">RAM ' + fmtBytesGB(mem.avail) + ' avail</span>' +
      ' · <span class="' + commitCls + '">commit ' + fmtPct(mem.commit) + '</span>');
  }
  el.innerHTML = parts.join(' &nbsp;|&nbsp; ');
}
```

Add `refreshUsage();` and its poll interval next to the others (after the `refreshMemory` lines added in
Task 11):

```js
refreshUsage();
setInterval(refreshUsage, 60000);  // reads existing files (cheap), but the source data itself only
                                    // changes when a usage:sample run happens - no need to poll fast
```

- [ ] **Step 6: Add the memory cell to server rows**

Locate the server-row rendering inside `refreshServers()` / its associated row-builder (starting
~line 2787 — read the function fully with `Grep -n -A 40 'async function refreshServers'` before editing,
since this plan doesn't have its exact current row-template string memorized character-for-character;
find where each server's `port`/`running`/`health` fields are interpolated into a row and add one more
cell immediately after health):

```js
'<td>' + (s.memory ? fmtBytesGB(s.memory.privateBytes) : '&mdash;') + '</td>'
```

(match whatever the existing cell syntax is — `<td>`/`<span class="...">` — by reading the real
function first; the principle is: one more field, reusing `fmtBytesGB` from Task 11, `&mdash;` when
`s.memory` is `null`)

- [ ] **Step 7: Run it and verify it passes**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "PASS memory tracker: header strip|cases passed"`
Expected: `PASS memory tracker: header strip is global...` and `114/114 self-test cases passed`.

---

## Task 13: `impeccable` pass + live Playwright verification

**Files:** none new — a review/fix pass over Tasks 11–12's HTML/CSS/JS inside `longrun-dashboard.py`.

- [ ] **Step 1: Run the drafted tab past impeccable**

Invoke the `impeccable` skill, scoped narrowly: "review the new Memory tab, header strip, and Servers-
tab memory column just added to `longrun-dashboard.py`'s `PAGE` string — check it matches the existing
dark theme (`--bg`/`--panel`/`--well`/`--line`/`--ink`/`--muted` variables), the existing stat-tile/badge
visual language, spacing conventions, and the standing no-decorative-accent-bars / no-commentary-text
rules. Do not redesign — flag only genuine drift from the established system." Apply any fixes it
surfaces directly (small CSS/markup tweaks, not a rewrite).

- [ ] **Step 2: Restart the live dashboard onto the new code**

```powershell
$live = "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py"
$pythonw = "C:\Users\dmcgowa2\scoop\apps\python313\current\pythonw.exe"
$old = (Get-NetTCPConnection -LocalPort 8756 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1).OwningProcess
if ($old) { Stop-Process -Id $old -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 700
Start-Process -FilePath $pythonw -ArgumentList @($live,'--port','8756') -WindowStyle Hidden
Start-Sleep -Seconds 3
Invoke-WebRequest -Uri "http://127.0.0.1:8756/" -UseBasicParsing -TimeoutSec 8 | Select-Object StatusCode
```

Expected: `StatusCode 200`.

- [ ] **Step 3: Live Playwright smoke test**

Write a temp script (this session's established pattern) and run via Bash/Node:

```js
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1500, height: 1200 } });
  const errs = [];
  p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  p.on('pageerror', e => errs.push('pageerror: ' + e.message));
  await p.goto('http://127.0.0.1:8756/', { waitUntil: 'networkidle' });
  await p.click('.tab-btn[data-tab="memory"]');
  await p.waitForTimeout(2500);
  const r = {};
  r.memoryVisible = await p.$eval('.tabpanel[data-panel="memory"]', e => !e.hidden);
  r.statCount = await p.$$eval('.mem-stat', e => e.length);
  r.bucketRows = await p.$$eval('.mem-bucket-row', e => e.length);
  r.topRows = await p.$$eval('.mem-top tbody tr', e => e.length);
  r.headerStripText = await p.$eval('#header-strip', e => e.textContent).catch(() => null);
  await p.click('.tab-btn[data-tab="servers"]');
  await p.waitForTimeout(1500);
  r.serversHtmlSample = await p.$eval('#servers-list', e => e.innerHTML.slice(0, 400)).catch(() => null);
  r.consoleErrors = errs;
  console.log(JSON.stringify(r, null, 2));
  await b.close();
})().catch(e => { console.error('ERR', e); process.exit(1); });
```

Expected: `memoryVisible: true`, `statCount: 3`, `bucketRows` > 0, `topRows` > 0, `headerStripText`
contains "Claude usage" and/or "Machine:", `consoleErrors: []`.

- [ ] **Step 4: Fix anything the smoke test surfaces, re-run self-test**

Run: `python "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py" --self-test 2>&1 | Select-String "cases passed"`
Expected: `114/114 self-test cases passed` (or higher, if Step 1's impeccable pass or Step 4's fixes added
any new assertions).

---

## Task 14: Adversarial security check, mirror sync, commit, push, live restart, re-verify

**Files:**
- Mirror: `C:\Users\dmcgowa2\Documents\Claude NASA Folder\claude-global-config\tools\longrun-dashboard.py`
- Mirror: `C:\Users\dmcgowa2\Documents\Claude NASA Folder\claude-global-config\tools\` — copy of
  `memory-recorder.mjs` if this project's own convention is to mirror it (check first; unlike
  `longrun-dashboard.py`, `memory-recorder.mjs` lives in `Codex NASA Folder`, which is its own separate
  repo per Task 1 Step 4 — do not force it into the `claude-global-config` mirror unless investigation
  shows that's actually expected)

- [ ] **Step 1: Dispatch the adversarial security check**

Dispatch a dedicated Agent (general-purpose, NOT the same context that wrote this code) with this exact
brief: "Verify that `C:\Users\dmcgowa2\Documents\Codex NASA Folder\scripts\memory-recorder.mjs` never
outputs env var names/values, full command lines, tokens, or config file paths/contents, across ALL
three of its data-producing modes (`--sample`, `--pids <a few real pids>`, `--events`). Run each mode
for real, capture its actual stdout byte-for-byte, and grep it for: any `process.env` key names (e.g.
`ANTHROPIC_API_KEY`, `GEN_API_KEY`, `PATH`, `USERPROFILE`), any string containing `--add-dir` or
`--dangerously-skip-permissions` (command-line tells), any path under `.claude\projects` or
`.claude\usage-estimator` (config/transcript paths), and any string that looks like an API key pattern
(`sk-`, `Bearer `, 32+ char hex/base64 tokens). Report PASS/FAIL per mode with the actual command run and
what was (or wasn't) found — do not just re-read the source code and assert it looks safe; actually run
it and inspect the real output." Do not proceed to Step 2 until this reports PASS on all three modes; if
it reports FAIL, fix the leak in `memory-recorder.mjs` and re-run this check before continuing.

- [ ] **Step 2: Sync the mirror**

```bash
cp "/c/Users/dmcgowa2/.claude/tools/longrun-dashboard.py" "/c/Users/dmcgowa2/Documents/Claude NASA Folder/claude-global-config/tools/longrun-dashboard.py"
cd "/c/Users/dmcgowa2/Documents/Claude NASA Folder/claude-global-config"
git diff --stat -- tools/longrun-dashboard.py
```

Expected: a diff stat showing the additions from Tasks 3–13.

- [ ] **Step 3: NASA scrub + gitleaks + commit + push**

Run this repo's standard NASA-scrub denylist check against the staged diff (see `CLAUDE.md`'s
pre-commit checklist for the current denylist — do not re-embed the literal pattern in new docs; a
prior draft of this exact plan did, and one of the denylist keywords inside the QUOTED PATTERN STRING
then matched its own documentation, a confirmed-benign but confusing false positive fixed 2026-07-07).
**Use a properly gating shell construct, not `grep ... && echo HIT || echo CLEAN`** — that form never
actually blocks anything, because `echo` always exits 0, so the `&&` chain after it proceeds
regardless of which branch fired (found live 2026-07-07: this exact bug shipped in an earlier draft of
this plan and let the false-positive commit above go through uninspected). Use:

```bash
cd "/c/Users/dmcgowa2/Documents/Claude NASA Folder/claude-global-config"
git add tools/longrun-dashboard.py
if git diff --cached -- tools/longrun-dashboard.py | grep -qiE "<the repo's current NASA-scrub denylist pattern>"; then
  echo "SCRUB HIT - NOT proceeding. Inspect the match before doing anything else."
else
  echo "SCRUB CLEAN"
fi
```

Only proceed to `git commit`/`git push` if that printed `SCRUB CLEAN`. Expected: `SCRUB CLEAN`. Then:

```bash
git commit -m "Dashboard: Memory & Usage Tracker (new Memory tab, header strip, Servers-tab memory column)

New companion recorder Codex NASA Folder/scripts/memory-recorder.mjs (safe OS-facts-only, snapshot
mode + per-PID mode + low-memory event-log mode, no persistence). Dashboard shells out live on a ~20s
poll for /api/memory (bucket totals + top processes + a short in-process trend ring buffer + Douglas's
exact alert thresholds); /api/usage reads the already-rich ~/.claude/usage-estimator/ history via a
tail-read (never the 18MB raw event ledger); Servers tab gets a per-PID memory column via one batched
--pids call per poll. Design brainstormed + spec'd + planned via superpowers:brainstorming +
writing-plans (see MEMORY_USAGE_TRACKER_DESIGN_2026-07-07.md / _PLAN_2026-07-07.md in this same
tools/ folder). 114/114 self-test (was 104/104), impeccable-reviewed, live Playwright-verified, and
memory-recorder.mjs's actual output adversarially checked for env vars/command lines/tokens/config
paths (none found).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
git push origin master
```

- [ ] **Step 4: Restart live :8756 and re-verify**

```powershell
$live = "C:\Users\dmcgowa2\.claude\tools\longrun-dashboard.py"
$pythonw = "C:\Users\dmcgowa2\scoop\apps\python313\current\pythonw.exe"
$old = (Get-NetTCPConnection -LocalPort 8756 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1).OwningProcess
if ($old) { Stop-Process -Id $old -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 700
Start-Process -FilePath $pythonw -ArgumentList @($live,'--port','8756') -WindowStyle Hidden
Start-Sleep -Seconds 3
Invoke-RestMethod http://127.0.0.1:8756/api/memory | ConvertTo-Json -Depth 4
Invoke-RestMethod http://127.0.0.1:8756/api/usage | ConvertTo-Json
```

Expected: real memory numbers, real (or honestly-unavailable-with-a-reason) usage numbers, on the live
watchdog-supervised instance.

- [ ] **Step 5: Update task-state files**

Update `CURRENT-TASK.md`, `WORK_QUEUE.<sid>.md`, `STATUS.md`, `LOG.md` per this repo's standing
convention (see `CLAUDE.md` → "Task state, backlog, status & worklog") — mark this feature DONE, note
the final self-test count, the commit hash, and whether `/api/memory/events` actually found any real
event-log entries on this machine (an honest empirical note, not a guess).

---

## Self-Review (writing-plans checklist)

**1. Spec coverage** — every design-spec item maps to a task: recorder core+modes (1–2), graceful
degradation (3), buckets (4), trend (5), alerts (6), usage tail-read (7, 9), `/api/memory`+`/api/memory/
events` (8), Servers-tab per-PID column (10), Memory tab UI (11), header strip (12), impeccable+live
verify (13), security check+ship (14). No spec item lacks a task.

**2. Placeholder scan** — no "TBD"/"add appropriate error handling"/"similar to Task N" found; every
code step has complete, real code. One deliberate exception: Task 12 Step 6 says "match whatever the
existing cell syntax is" for the server-row template — this is not a placeholder for missing design
work, it's an instruction to read the ACTUAL current template (which this plan doesn't have memorized
character-for-character) before editing, matching this plan's own "re-locate before editing" discipline
used throughout for line numbers.

**3. Type consistency** — checked function names/signatures across tasks: `sample_memory()` (Task 3) →
consumed by `build_memory_payload()` (Task 8) ✓. `classify_memory_bucket()` (Task 4) → consumed by
`build_memory_payload()` (Task 8) ✓. `classify_trend()` (Task 5) + `_MEMORY_RING`/`_MEMORY_RING_LOCK` →
consumed by `build_memory_payload()` (Task 8) ✓. `memory_alerts()` (Task 6) → consumed by
`build_memory_payload()` (Task 8) ✓. `_tail_last_jsonl_line()` (Task 7) → consumed by
`build_usage_payload()` (Task 9) ✓. `sample_memory_pids()` + `attach_server_memory()` (Task 10) → wired
into the real `/api/servers` handler (Task 10 Step 3) ✓. Frontend `fmtBytesGB`/`fmtPct` (Task 11) →
reused by `renderHeaderStrip()` (Task 12) ✓ (defined before use, since Task 11 runs first). Fixed one
inconsistency during this self-review: the design spec's schema section conflated the recorder's raw
output with the final API shape — resolved in the "Schema note" above and consistently applied through
Tasks 1, 8, and 9 (recorder returns raw `processes`; `build_memory_payload` computes `groups`/
`topProcesses`; recorder's own `alerts` field from the original spec example is dropped from the
recorder's actual output in favor of computing it once, in Python, in `build_memory_payload`).

---

**Plan complete and saved to `C:\Users\dmcgowa2\.claude\tools\MEMORY_USAGE_TRACKER_PLAN_2026-07-07.md`.**

Given Douglas's explicit "complete all building" / auto-mode directive through this whole session,
proceeding with **Inline Execution** (via `superpowers:test-driven-development` task-by-task, in this
same session) rather than pausing for the Subagent-Driven-vs-Inline choice: this codebase's conventions
(CSS variable system, tab-rail architecture, subprocess/atomic-write patterns, the exact self-test
numbering discipline) were all built up over this session and are held in this session's own context —
re-explaining them to a fresh per-task subagent would cost more than it saves, and the tasks are tightly
sequential (each Python task's test/implementation depends on the prior task's function existing) rather
than independent, so subagent-driven-development's main advantage (parallel-friendly fresh context per
task) doesn't apply here. Flag if a different approach is wanted.
