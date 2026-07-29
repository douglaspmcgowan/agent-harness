# Memory & Usage Tracker — design spec (2026-07-07)

Target: `longrun-dashboard.py` (Douglas's personal Windows ops dashboard, single-file Python stdlib
HTTP server, watchdog-supervised on :8756). Companion recorder: new
`Codex NASA Folder/scripts/memory-recorder.mjs`, sibling to the existing
`Codex NASA Folder/scripts/claude-usage-recorder.mjs`.

## Goal

Answer two questions from one place while the dashboard is open: "what is eating this machine's RAM
right now" and "how much Claude usage/rate-limit headroom do I have" — so Douglas can decide whether
to fork/stop sessions, close apps, or stop dev servers without hunting across Task Manager and a
separate usage tool.

## Decisions (resolved via brainstorming dialogue)

1. **`/api/memory` is a live shell-out, not a file-based watcher.** The dashboard's Python handler
   runs `node memory-recorder.mjs --sample --quiet` synchronously (5s timeout) on a ~20s frontend poll
   — matching the existing "Discovered" panel's 15s cadence for a live-system-call endpoint. Rejected:
   a separate always-on `memory:watch` process (the precedent `usage-samples.jsonl` was found ~40 min
   stale with no watcher running — NASA blocks Task Scheduler, so an unwatched watcher silently rots).
2. **Memory/RAM is snapshot-only — no persisted history.** `memory-recorder.mjs`'s `--sample` writes
   `latest.json` (atomic overwrite), no JSONL append, no pruning logic to design or maintain. Trend
   (growing/flat/dropping) comes from a short in-process ring buffer the DASHBOARD itself holds across
   its last ~8 polls (~2 minutes) — never written to disk.
3. **Usage already has good history — read it, don't recapture it.** `/api/usage` reads the existing
   `~/.claude/usage-estimator/latest-rate-limits.json` (tiny) plus the **last line only** of
   `usage-samples.jsonl` (seek-from-end tail read, like `session_detail`'s existing pattern) — never
   the 18MB `state.json` raw event ledger. No new capture work; `claude-usage-recorder.mjs` already
   does this well with its own 8-day prune.
4. **Servers-tab memory uses a dedicated per-PID lookup, not top-N reuse.** A small server process
   might not make a "top N by memory" cut; Douglas's spec wants a guaranteed number next to every
   registered server. `find_pid_on_port` already exists (used by `stop_port`); resolve each running
   server's PID, batch into one `memory-recorder.mjs --pids a,b,c` call.
5. **`/api/memory/events` is in scope now** (was marked optional in the original spec; Douglas
   confirmed build-now). Queries the System event log for the well-known low-memory /
   Resource-Exhaustion-Detector event IDs (2004/2005) via `Get-WinEvent` — verify these actually fire
   on this machine during implementation rather than assume; "0 events" must not be misread as broken.
6. **Header strip is global** (visible on every tab, not just Cards) — "one place to decide" only
   works if it's always present.

## Schema (memory-recorder.mjs `--sample` output, schemaVersion 1)

```json
{
  "schemaVersion": 1,
  "timestamp": "2026-07-07T...",
  "physicalTotalBytes": 0, "availableBytes": 0,
  "commitBytes": 0, "commitLimitBytes": 0, "commitPct": 0.0, "pagefilePct": 0.0,
  "pagedPoolBytes": 0, "nonpagedPoolBytes": 0, "cacheBytes": 0,
  "groups": [{"name": "claude", "count": 0, "privateBytes": 0, "workingSetBytes": 0}],
  "topProcesses": [{"name": "claude", "pid": 0, "privateBytes": 0, "workingSetBytes": 0}],
  "alerts": []
}
```

**Explicitly excluded from every mode's output** (hard security constraint): env vars, command lines,
tokens, config file paths/contents. Verified by a dedicated adversarial check before this ships (see
Testing).

## Data sources

PowerShell shelled out from Node (matches the "no native binding" convention already used by the
sibling script): `Get-CimInstance Win32_OperatingSystem` (physical/available RAM),
`Win32_PerfFormattedData_PerfOS_Memory` (commit/pagefile/pool/cache), `Get-Process` grouped by
`ProcessName` (groups + top processes), `Get-WinEvent` (events mode only).

## `memory-recorder.mjs` modes

- `--sample [--quiet]` → one reading, `latest.json` atomic write, JSON to stdout.
- `--pids <csv> [--quiet]` → per-PID private/working-set bytes only, for the Servers-tab lookup.
- `--events [--quiet]` → recent low-memory Event Log entries (IDs 2004/2005), JSON to stdout.

npm scripts (`Codex NASA Folder/package.json`): `memory:sample`, `memory:watch` (manual/ad-hoc use,
not load-bearing for the dashboard), `memory:report`.

## Dashboard backend additions (`longrun-dashboard.py`)

- `MEMORY_RECORDER_PATH` constant; `sample_memory()` / `sample_memory_pids(pids)` /
  `sample_memory_events()` — each `subprocess.run(timeout=5)`, `shutil.which('node')` checked first,
  any failure returns an explicit `{"available": false, "reason": ...}` shape, never raises.
  Bucket classifier — pure function, case-insensitive substring match against `groups[].name`/
  `topProcesses[].name`, first-match-wins in this fixed order (mirrors `_match_skill_key`'s style):
  1. **Agent apps**: `claude`, `Codex`
  2. **Dev runtimes**: `node`, `python`, `powershell`, `WindowsTerminal`
  3. **Browsers/UI shells**: `chrome`, `msedgewebview2`, `Obsidian`
  4. **NASA endpoint/enterprise**: `SentinelAgent`, `splunk*`, `CcmExec`, `SysInfoCap`
  5. **System**: `svchost`, `dwm`, `WmiPrvSE`
  6. Anything matching none of the above is grouped under an `other` bucket (not silently dropped).
- `_MEMORY_RING = collections.deque(maxlen=8)` (lock-guarded) + `classify_trend(ring)` — pure,
  testable. Decided threshold: compares latest sample's `commitPct` against the OLDEST sample
  currently in the ring (≈2 minutes prior at the 20s poll cadence) — delta > +2 percentage points →
  `growing`, delta < −2pp → `dropping`, otherwise `flat`. Fewer than 2 samples in the ring → `unknown`
  (not a guess).
- `memory_alerts(sample)` — pure function applying Douglas's exact thresholds (available RAM <6GB
  warn, <3GB critical; commit >85% warn, >92% crisis).
- `GET /api/memory` → sample + push ring + trend + buckets + alerts, one JSON payload.
- `GET /api/memory/events` → recent low-memory event IDs.
- `GET /api/usage` → `latest-rate-limits.json` + tail-read last line of `usage-samples.jsonl`
  (`_tail_last_jsonl_line(path)` — seek-from-end, reused pattern).
- `/api/servers` gains a `memory` field per row, resolved via `find_pid_on_port` + one batched
  `--pids` call.

## Frontend additions

- New `data-tab="memory"` in the existing vertical icon-tab rail (new inline SVG, localStorage-
  persisted like `cards`/`skills`/`servers`).
- Memory tab: stat row (RAM used/available, commit used/headroom, pagefile %) using the existing
  stat-tile visual language; trend indicator; 5 bucket rows; top-processes table; threshold badges
  styled like the existing `.ktag`. Labels/data only — no commentary text.
- Servers tab: one new memory column per row (`—` if not running / PID unresolved).
- Global header strip above the tab rail: `Claude usage: 5h X% · 7d Y% · today $Z` /
  `Machine: RAM X% · commit Y% · Z GB avail`, colored on threshold breach.
- One `impeccable` pass on the drafted tab: matches dark theme + spacing + no decorative bars.

## Testing & verification

- TDD (`self_test()` extension, same pattern as this session's 91→99 progression) for every pure
  function: bucket classifier, trend classifier, alert thresholds, tail-line reader. Subprocess calls
  themselves are NOT part of `self_test()` (must not require Node on PATH to pass) — `sample_memory()`
  degrades to an explicit `unavailable` shape when Node is missing, and that degradation path IS
  self-tested.
- Live Playwright smoke test against the real running :8756 instance (this session's established
  verification pattern): new tab renders, `/api/memory` and `/api/usage` return real numbers, Servers
  tab shows memory per row, 0 console errors.
- **Adversarial security check** (dedicated Agent, not self-graded): verify the recorder's actual
  byte-for-byte stdout/written JSON across all three modes never contains env var names/values, full
  command lines, tokens, or config file paths/contents — checked against real output, not the schema
  on paper.
- Mirror to `claude-global-config`, NASA scrub, gitleaks, commit, push, restart live :8756, re-verify.

## Out of scope (this pass)

- Historical memory charting/graphing (explicitly rejected — snapshot only, per Douglas's correction).
- `memory:watch` as a load-bearing always-on process (script supports it for manual/ad-hoc use, but
  the dashboard never depends on it running).
- Any "kill arbitrary PID" action — memory numbers are informational only; existing
  known-launch.json-ports-only stop discipline is unchanged.
