#!/usr/bin/env python3
"""longrun-watcher.py - external, out-of-session watchdog for long Claude Code runs.

Runs in its OWN terminal, OUTSIDE any Claude session. It relaunches `claude` after the
session dies (e.g. the 5h usage limit), sleeping until the limit resets; STOPS when the
run finishes cleanly; and STOPS+logs if the run STALLS (no transcript progress across
relaunches).

What it does NOT do: it does not fix the in-session "agent ended its turn and won't
recheck a running background task" bug. Once a session is alive but idle, only an
in-session Stop hook can wake it. This watcher is the layer for surviving session DEATH
and long unattended runs.

Usage:
  python longrun-watcher.py --project-dir "<root>" --claude-cmd "claude --continue" \
      [--session-id <sid>] [--max-relaunches 12] [--max-stall 3] [--max-wait 21600] \
      [--usage-state <path>] [--poll 30]
  python longrun-watcher.py --self-test

Abort any time: create `.stop-watcher` in --project-dir (or `.stop-autorun.<sid>`).
Decisions + sleeps are logged to <project-dir>/.longrun-watcher.log
CAVEATS: verified by --self-test + stub, NOT against a real 5h limit. --claude-cmd must
be a command that actually EXITS on the limit and runs unattended (headless -p or
--permission-mode for true hands-off); bare `claude --continue` assumes interactive resume.
"""
import argparse, glob, json, os, re, shutil, subprocess, sys, time
from datetime import datetime, timezone

LIMIT_RE = re.compile(r"usage limit|rate limit|limit reached|resets? at|too many requests|\b429\b", re.I)

# ---- self-heal: SentinelOne's static-AI engine has twice killed Claude/Codex process
# trees on this machine and quarantined files belonging to them mid-run (confirmed via
# Windows Event Log, see memory project_sentinelone_ai_cli_false_positives.md) - including,
# on 2026-07-02, the very hooks/tools this watcher depends on (keep-going.js vanished from
# ~/.claude/hooks/ mid-session). Since this watcher is the thing surviving process death
# and relaunching anyway, it's the natural place to also detect and heal a missing critical
# file BEFORE the next relaunch, so the resumed session doesn't inherit a broken hook.
HOME = os.path.expanduser("~")
MIRROR_ROOT = os.path.join(HOME, "Documents", "Claude NASA Folder", "claude-global-config")
CRITICAL_RELPATHS = [
    os.path.join("hooks", "keep-going.js"),
    os.path.join("hooks", "check-secret-exposure.js"),
    os.path.join("hooks", "hook-state.js"),
    os.path.join("hooks", "wait-on-usage-limit.js"),
    os.path.join("hooks", "session-primer.js"),
    os.path.join("hooks", "task-state-reminder.js"),
    os.path.join("hooks", "hook_guarantee.js"),
    os.path.join("tools", "longrun-watcher.py"),
    os.path.join("tools", "longrun-preflight.js"),
]


def heal_critical_files(project_dir, log_fn):
    """Restore any missing canonical hook/tool file from the tracked mirror. Returns the
    list of paths healed (empty if everything was already present, or nothing could be
    healed). Never overwrites an EXISTING file - only fills in a genuine gap, so it can't
    clobber a legitimate in-progress edit."""
    healed = []
    for rel in CRITICAL_RELPATHS:
        home_path = os.path.join(HOME, ".claude", rel)
        mirror_path = os.path.join(MIRROR_ROOT, rel)
        if os.path.isfile(home_path):
            continue
        if not os.path.isfile(mirror_path):
            log_fn(project_dir, "HEAL FAILED: %s missing and no mirror copy at %s"
                   % (home_path, mirror_path))
            continue
        try:
            shutil.copyfile(mirror_path, home_path)
            healed.append(home_path)
        except OSError as e:
            log_fn(project_dir, "HEAL FAILED: could not restore %s: %r" % (home_path, e))
    if healed:
        log_fn(project_dir,
               "HEALED %d missing critical file(s) from the tracked mirror (likely a "
               "SentinelOne quarantine event - see project_sentinelone_ai_cli_false_positives.md): %s"
               % (len(healed), ", ".join(healed)))
    return healed
ISO_RE = re.compile(r"([0-9]{4}-[0-9]{2}-[0-9]{2}[ T][0-9:]+(?:\.[0-9]+)?(?:Z|[+-][0-9:]+)?)")


# ---- pure decision logic (unit-tested via --self-test) -----------------------------
def decide(*, clean_exit, usage_limited, transcript_advanced, relaunches, stalls,
           max_relaunches, max_stall):
    """Return one of: DONE, WAIT_RESUME, STALL, MAXRELAUNCH, RELAUNCH."""
    if clean_exit and not usage_limited:
        return "DONE"
    if usage_limited:
        return "MAXRELAUNCH" if relaunches >= max_relaunches else "WAIT_RESUME"
    if relaunches >= max_relaunches:
        return "MAXRELAUNCH"
    if not transcript_advanced:                       # no forward progress this run
        return "STALL" if stalls + 1 >= max_stall else "RELAUNCH"
    return "RELAUNCH"                                  # made progress but exited (crash) -> retry


# ---- helpers ------------------------------------------------------------------------
def parse_iso(s):
    if not s:
        return None
    try:
        t = datetime.fromisoformat(str(s).replace("Z", "+00:00"))
        if t.tzinfo is None:
            t = t.replace(tzinfo=timezone.utc)
        return t.timestamp()
    except Exception:
        return None


def transcripts_root():
    return os.path.join(os.path.expanduser("~"), ".claude", "projects")


def pick_transcript(cands, session_id, key):
    """Pure selection: when a session is pinned, match ONLY its transcript and never fall back to a
    foreign newest (a wrong-session bug). Unpinned -> newest overall."""
    if session_id:
        cands = [c for c in cands if os.path.basename(c).startswith(session_id)]
        if not cands:
            return None      # STRICT: pinned + no match -> None (do NOT chase another session's transcript)
    return max(cands, key=key) if cands else None


def find_transcript(session_id):
    cands = glob.glob(os.path.join(transcripts_root(), "*", "*.jsonl"))
    return pick_transcript(cands, session_id, os.path.getmtime)


def progress_sig(session_id):
    """A cheap signature of transcript progress: (path, size, last-bytes-hash)."""
    p = find_transcript(session_id)
    if not p:
        return None
    try:
        size = os.path.getsize(p)
        with open(p, "rb") as f:
            if size > 2048:
                f.seek(-2048, os.SEEK_END)
            tail = f.read()
        return (p, size, hash(tail))
    except Exception:
        return None


def read_tail(path, n):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            return f.read()[-n:]
    except Exception:
        return ""


def read_usage(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def detect_limited(output_tail, usage):
    if usage.get("limited") is True:
        return True
    return bool(LIMIT_RE.search(output_tail or ""))


def seconds_until_reset(output_tail, usage, max_wait, now=None):
    now = now if now is not None else time.time()
    t = parse_iso(usage.get("resets_at"))
    if not t:
        m = ISO_RE.search(output_tail or "")
        if m:
            t = parse_iso(m.group(1))
    secs = (t - now) if t else 3600          # safe default when reset time is unknown
    secs += 60                                # small buffer past the reset boundary
    return int(max(60, min(secs, max_wait)))  # never instant-resume; never exceed max_wait


def abort_requested(project_dir, session_id):
    if os.path.exists(os.path.join(project_dir, ".stop-watcher")):
        return True
    return bool(session_id) and os.path.exists(
        os.path.join(project_dir, ".stop-autorun." + session_id))


def sleep_interruptible(project_dir, session_id, seconds, step=5):
    """Sleep in short increments, checking the abort sentinel each time, so a long
    WAIT_RESUME nap (up to --max-wait, default 6h) can actually be aborted promptly
    instead of only being checked once the full sleep elapses. Returns True if aborted."""
    end = time.time() + seconds
    while time.time() < end:
        if abort_requested(project_dir, session_id):
            return True
        time.sleep(min(step, max(0, end - time.time())))
    return False


def find_live_pids(session_id):
    """Windows-specific: PIDs of live `claude`/`claude.exe` processes whose command line references
    this session_id. Returns None if the check itself failed (so the caller falls back rather than
    wrongly assuming 'no live process'), or a list of PIDs.

    Found live 2026-07-02, testing a second real death/relaunch cycle: an earlier version of this
    matched ANY process whose command line contained the session_id substring, not just the actual
    payload process. A launch chain wraps `claude`/`claude.exe` in several bash.exe layers (the shell
    that invokes gen-claude.sh, the harness's own background-task tracking wrapper) that each carry the
    full command line -- including the session_id -- as an argument. Some of those wrapper shells
    lingered well after the real claude.exe process had exited (confirmed: a `Name -eq 'claude.exe'`
    filter found zero matches at the same moment the unfiltered query still showed 6+ bash.exe/
    powershell.exe entries), so the watcher waited indefinitely for processes that were never the thing
    actually running the session. Filtering to the process NAME, not just the command line, fixes it."""
    try:
        ps_cmd = ("Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*%s*' -and "
                  "($_.Name -eq 'claude.exe' -or $_.Name -eq 'claude') } | "
                  "Select-Object -ExpandProperty ProcessId") % session_id
        out = subprocess.run(["powershell", "-NoProfile", "-Command", ps_cmd],
                              capture_output=True, text=True, timeout=15)
        if out.returncode != 0:
            return None
        return [int(x) for x in out.stdout.split() if x.strip().isdigit()]
    except Exception:
        return None


def wait_until_quiet(project_dir, session_id, log_fn, poll=3, max_checks=200):
    """Found live 2026-07-02: the watcher's first relaunch used to fire immediately with no check for
    whether the target session already has a live process handling it -- racing a still-running session
    with a second, competing `claude --resume`/`--session-id` launch. Proven live: a transcript-mtime
    heuristic (v1 of this fix) missed the actual bug, because the real session had gone >2 minutes
    without a transcript write (mid-tool-call) while still very much alive -- a direct process check
    (command line contains the session_id) is the reliable signal, confirmed against the live process
    that triggered this fix. Falls back to a short, cheap transcript-mtime wait if the process check
    itself is unavailable (e.g. non-Windows), rather than flying fully blind."""
    pids = find_live_pids(session_id)
    if pids is None:
        sig = progress_sig(session_id)
        if sig is None:
            return
        try:
            age = time.time() - os.path.getmtime(sig[0])
        except OSError:
            return
        if age >= 20:
            return
        log_fn(project_dir, "process check unavailable; transcript modified %ds ago -- waiting 20s as a "
               "cheap precaution" % int(age))
        time.sleep(20)
        return
    if not pids:
        return  # no live process for this session -- safe to launch
    log_fn(project_dir, "session %s already has a live process (pid %s) -- waiting for it to exit before "
           "the first relaunch (avoids racing a still-running session)" % (session_id, pids))
    checks = 0
    while checks < max_checks:
        time.sleep(poll)
        checks += 1
        pids = find_live_pids(session_id)
        if not pids:
            log_fn(project_dir, "prior process for session %s has exited -- proceeding" % session_id)
            return
    log_fn(project_dir, "gave up waiting after %d checks (pid still alive: %s) -- proceeding anyway"
           % (max_checks, pids))


def log(project_dir, msg):
    line = "[" + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + "] " + msg
    print(line, flush=True)
    try:
        with open(os.path.join(project_dir, ".longrun-watcher.log"), "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


# ---- single-instance lock (found live 2026-07-01: /longrun re-invoked mid-run stacked a SECOND watcher onto
# the same session, launching a duplicate `gen-claude.sh --resume` process on top of the still-alive one --
# that resource pileup is what froze the desktop app. A documented "check before you launch" step in the
# skill is not enough since a busy/panicking session can skip it; enforce it here so it can't be skipped.) ---
def lock_path(project_dir, session_id):
    return os.path.join(project_dir, ".longrun-watcher.lock" + (("." + session_id) if session_id else ""))


def pid_alive(pid):
    """Windows-specific liveness check (os.kill(pid, 0) is not a reliable exists-check on Windows). Returns
    True/False, or None if the check itself failed (caller must not treat None as either answer)."""
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-Command",
                              "Get-Process -Id %d -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id" % pid],
                              capture_output=True, text=True, timeout=15)
        if out.returncode != 0:
            return None
        return str(pid) in out.stdout.split()
    except Exception:
        return None


def acquire_lock(project_dir, session_id, log_fn, pid=None):
    """Refuse to start a second watcher for the same session while one is already alive. Returns the lock
    path to hold (caller must release_lock it on every exit path), or None if a live duplicate exists."""
    p = lock_path(project_dir, session_id)
    try:
        with open(p, "r", encoding="utf-8") as f:
            existing = int(f.read().strip())
        alive = pid_alive(existing)
        if alive:
            log_fn(project_dir, "REFUSING to start: another watcher (pid %d) is already running for this "
                   "session -- exiting rather than stacking a duplicate (this is the 2026-07-01 incident's "
                   "root cause; stop the existing one first if you really want to relaunch)" % existing)
            return None
        if alive is None:
            log_fn(project_dir, "WARNING: could not verify whether the lock's pid %d is still alive (liveness "
                   "check itself failed) -- proceeding, since refusing on an unverifiable check risks a "
                   "permanent false lockout" % existing)
    except (FileNotFoundError, ValueError, OSError):
        pass
    try:
        with open(p, "w", encoding="utf-8") as f:
            f.write(str(pid if pid is not None else os.getpid()))
    except OSError:
        pass
    return p


def release_lock(lock_file):
    if lock_file:
        try:
            os.remove(lock_file)
        except OSError:
            pass


def claude_cmd_has_resume(claude_cmd, session_id, cwd=None):
    """True if claude_cmd resumes THIS session_id, either directly or via a referenced wrapper script (the
    recommended pattern for avoiding PowerShell's quote-mangling of an inline `-p "..."` prompt -- see
    longrun.md step 5b). Looks inside the LAST whitespace-separated token if it names an existing .sh/.ps1
    file, so the false "no --resume" warning doesn't fire on a correctly-wrapped command."""
    needle = "--resume " + session_id
    if needle in claude_cmd:
        return True
    last = claude_cmd.strip().split()[-1] if claude_cmd.strip() else ""
    if last.lower().endswith((".sh", ".ps1")):
        path = last if os.path.isabs(last) else os.path.join(cwd or ".", last)
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                return needle in f.read()
        except OSError:
            return False
    return False


# ---- main loop ----------------------------------------------------------------------
def watch(a):
    lock_file = acquire_lock(a.project_dir, a.session_id, log)
    if lock_file is None:
        return 5   # distinct exit code: refused due to an already-live duplicate watcher
    try:
        return _watch_locked(a)
    finally:
        release_lock(lock_file)


def _watch_locked(a):
    run_log = os.path.join(a.project_dir, ".longrun-watcher.run.log")
    stalls = relaunches = 0
    log(a.project_dir, "watcher start: cmd=%r max_relaunches=%d max_stall=%d max_wait=%ds"
        % (a.claude_cmd, a.max_relaunches, a.max_stall, a.max_wait))
    if a.session_id and not claude_cmd_has_resume(a.claude_cmd, a.session_id, cwd=a.project_dir):
        log(a.project_dir, "WARNING: --session-id set but --claude-cmd (nor the wrapper script it points at) "
            "resumes '--resume %s'; '--continue' may resume a DIFFERENT session. Prefer: claude --resume %s ..."
            % (a.session_id, a.session_id))
    if a.session_id and progress_sig(a.session_id) is None:
        log(a.project_dir, "note: no transcript matches session-id %s yet (fine on a fresh start; a persistent "
            "mismatch now STALLs within --max-stall runs instead of chasing the wrong session)" % a.session_id)
    if a.session_id:
        wait_until_quiet(a.project_dir, a.session_id, log)
    while True:
        if abort_requested(a.project_dir, a.session_id):
            log(a.project_dir, "ABORT sentinel found -> stop")
            return 0
        relaunches += 1
        heal_critical_files(a.project_dir, log)
        before = progress_sig(a.session_id)
        log(a.project_dir, "run #%d launching" % relaunches)
        try:
            with open(run_log, "w", encoding="utf-8") as out:
                rc = subprocess.run(a.claude_cmd, shell=True, stdout=out,
                                    stderr=subprocess.STDOUT, cwd=a.project_dir).returncode
        except Exception as e:
            log(a.project_dir, "launch error: %r" % e)
            rc = 1
        tail = read_tail(run_log, 8000)
        usage = read_usage(a.usage_state)
        limited = detect_limited(tail, usage)
        after = progress_sig(a.session_id)
        advanced = (after is not None) and (after != before)
        clean = (rc == 0) and not limited
        d = decide(clean_exit=clean, usage_limited=limited, transcript_advanced=advanced,
                   relaunches=relaunches, stalls=stalls,
                   max_relaunches=a.max_relaunches, max_stall=a.max_stall)
        log(a.project_dir, "run #%d: exit=%s advanced=%s limited=%s stalls=%d -> %s"
            % (relaunches, rc, advanced, limited, stalls, d))
        if d == "DONE":
            log(a.project_dir, "run finished cleanly -> stop"); return 0
        if d == "MAXRELAUNCH":
            log(a.project_dir, "hit max relaunches (%d) -> stop" % a.max_relaunches); return 2
        if d == "STALL":
            log(a.project_dir, "STALLED: no transcript progress across %d runs -> stop" % a.max_stall); return 3
        if d == "WAIT_RESUME":
            stalls = 0
            secs = seconds_until_reset(tail, usage, a.max_wait)
            log(a.project_dir, "usage-limited; sleeping %ds until reset" % secs)
            if sleep_interruptible(a.project_dir, a.session_id, secs):
                log(a.project_dir, "ABORT sentinel found during sleep -> stop"); return 0
            continue
        # RELAUNCH
        stalls = stalls + 1 if not advanced else 0
        if sleep_interruptible(a.project_dir, a.session_id, a.poll):
            log(a.project_dir, "ABORT sentinel found during sleep -> stop"); return 0
        continue


# ---- self-test ----------------------------------------------------------------------
def self_test():
    C = dict(max_relaunches=12, max_stall=3)
    cases = [
        (dict(clean_exit=True, usage_limited=False, transcript_advanced=True, relaunches=1, stalls=0, **C), "DONE"),
        (dict(clean_exit=False, usage_limited=True, transcript_advanced=True, relaunches=1, stalls=0, **C), "WAIT_RESUME"),
        (dict(clean_exit=False, usage_limited=True, transcript_advanced=False, relaunches=12, stalls=0, **C), "MAXRELAUNCH"),
        (dict(clean_exit=False, usage_limited=False, transcript_advanced=False, relaunches=2, stalls=0, **C), "RELAUNCH"),
        (dict(clean_exit=False, usage_limited=False, transcript_advanced=False, relaunches=2, stalls=2, **C), "STALL"),
        (dict(clean_exit=False, usage_limited=False, transcript_advanced=True, relaunches=2, stalls=0, **C), "RELAUNCH"),
        (dict(clean_exit=False, usage_limited=False, transcript_advanced=True, relaunches=12, stalls=0, **C), "MAXRELAUNCH"),
        (dict(clean_exit=True, usage_limited=True, transcript_advanced=True, relaunches=1, stalls=0, **C), "WAIT_RESUME"),
        (dict(clean_exit=False, usage_limited=False, transcript_advanced=False, relaunches=1, stalls=0, max_relaunches=12, max_stall=1), "STALL"),
        (dict(clean_exit=False, usage_limited=True, transcript_advanced=True, relaunches=3, stalls=2, **C), "WAIT_RESUME"),
    ]
    ok = 0
    for i, (inp, want) in enumerate(cases, 1):
        got = decide(**inp)
        flag = "PASS" if got == want else "FAIL"
        if got == want:
            ok += 1
        print("  %s case %d: want %-12s got %s" % (flag, i, want, got))
    # reset-time helpers
    r1 = seconds_until_reset("", {"resets_at": "2999-01-01T00:00:00Z"}, max_wait=21600, now=0)
    assert r1 == 21600, r1                                   # far future -> clamped to max_wait
    r2 = seconds_until_reset("usage limit. resets at 1970-01-01T00:30:00Z", {}, max_wait=21600, now=0)
    assert r2 == 1860, r2                                    # 30min + 60s buffer parsed from output
    r3 = seconds_until_reset("", {}, max_wait=21600, now=0)
    assert r3 == 3660, r3                                    # unknown -> 1h default + buffer
    print("  PASS reset-time helpers (clamp / parse / default)")
    # transcript selection: a pinned session never falls back to a foreign newest (wrong-session fix)
    key = lambda c: {"a-1.jsonl": 1, "b-2.jsonl": 9}.get(os.path.basename(c), 0)
    cands = ["/x/a-1.jsonl", "/x/b-2.jsonl"]
    assert pick_transcript(cands, "a", key) == "/x/a-1.jsonl", "pinned picks its own transcript"
    assert pick_transcript(cands, "zzz", key) is None, "pinned mismatch -> None (no foreign fallback)"
    assert pick_transcript(cands, "", key) == "/x/b-2.jsonl", "unpinned -> global newest"
    assert pick_transcript([], "a", key) is None, "no candidates -> None"
    print("  PASS transcript selection (strict pin / no foreign fallback)")
    # single-instance lock: refuses a live duplicate, steals a stale lock, releases cleanly (2026-07-01 fix)
    import tempfile
    tmp = tempfile.mkdtemp(prefix="longrun-lock-test-")
    try:
        me = os.getpid()   # guaranteed alive -- this test process itself
        l1 = acquire_lock(tmp, "sidA", lambda d, m: None, pid=me)
        assert l1 is not None, "first acquire on an empty dir must succeed"
        l2 = acquire_lock(tmp, "sidA", lambda d, m: None, pid=me)
        assert l2 is None, "second acquire while the first pid is genuinely alive must be REFUSED"
        release_lock(l1)
        assert not os.path.exists(lock_path(tmp, "sidA")), "release_lock must remove the file"
        stale_pid = 999999999   # not a real process
        with open(lock_path(tmp, "sidB"), "w", encoding="utf-8") as f:
            f.write(str(stale_pid))
        l3 = acquire_lock(tmp, "sidB", lambda d, m: None, pid=me)
        assert l3 is not None, "a lock naming a dead pid must be stolen, not honored"
        release_lock(l3)
        print("  PASS single-instance lock (refuses live duplicate / steals stale lock / releases cleanly)")
        # resume-detection: direct inline match, wrapper-script match (the recommended pattern), true negative
        assert claude_cmd_has_resume("claude --resume abc123 -p hi", "abc123"), "direct --resume in the string"
        wrapper = os.path.join(tmp, "resume.sh")
        with open(wrapper, "w", encoding="utf-8") as f:
            f.write('bash gen-claude.sh --resume abc123 --model x -p "hello"\n')
        assert claude_cmd_has_resume("bash " + wrapper, "abc123"), "resume found INSIDE a referenced wrapper script"
        assert not claude_cmd_has_resume("claude --continue", "abc123"), "no --resume anywhere -> False"
        assert not claude_cmd_has_resume("bash " + wrapper, "zzz999"), "wrapper resumes a DIFFERENT session -> False"
        print("  PASS resume-detection (inline / wrapper-script / true negative / wrong-session)")
        # heal_critical_files: restores a missing file from the mirror, never touches an existing
        # one, and reports (not crashes on) a file missing from BOTH sides.
        fake_home = os.path.join(tmp, "fakehome")
        fake_mirror = os.path.join(fake_home, "Documents", "Claude NASA Folder", "claude-global-config")
        os.makedirs(os.path.join(fake_home, ".claude", "hooks"))
        os.makedirs(os.path.join(fake_mirror, "hooks"))
        os.makedirs(os.path.join(fake_mirror, "tools"))
        with open(os.path.join(fake_mirror, "hooks", "keep-going.js"), "w", encoding="utf-8") as f:
            f.write("// mirror copy")
        with open(os.path.join(fake_home, ".claude", "hooks", "check-secret-exposure.js"), "w", encoding="utf-8") as f:
            f.write("// already present, must NOT be overwritten")
        global HOME, MIRROR_ROOT
        real_home, real_mirror = HOME, MIRROR_ROOT
        HOME, MIRROR_ROOT = fake_home, fake_mirror
        try:
            healed = heal_critical_files(tmp, lambda d, m: None)
        finally:
            HOME, MIRROR_ROOT = real_home, real_mirror
        kg_path = os.path.join(fake_home, ".claude", "hooks", "keep-going.js")
        cse_path = os.path.join(fake_home, ".claude", "hooks", "check-secret-exposure.js")
        assert kg_path in healed, "missing file with a real mirror copy must be restored"
        assert os.path.isfile(kg_path), "restored file must actually exist on disk now"
        assert cse_path not in healed, "an EXISTING file must never be reported as healed"
        with open(cse_path, encoding="utf-8") as f:
            assert f.read() == "// already present, must NOT be overwritten", \
                "an EXISTING file's content must be untouched"
        print("  PASS heal_critical_files (restores missing-with-mirror, never touches existing, "
              "handles missing-from-both)")
    finally:
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)
    print("\n%d/%d decision cases passed" % (ok, len(cases)))
    return 0 if ok == len(cases) else 1


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--project-dir")
    p.add_argument("--claude-cmd", default="claude --continue")
    p.add_argument("--session-id", default="")
    p.add_argument("--max-relaunches", type=int, default=12)
    p.add_argument("--max-stall", type=int, default=3)
    p.add_argument("--max-wait", type=int, default=21600)     # 6h ceiling on any single sleep
    p.add_argument("--usage-state", default=os.environ.get(
        "CLAUDE_USAGE_STATE", os.path.join(os.path.expanduser("~"), ".claude", "usage-state.json")))
    p.add_argument("--poll", type=int, default=30)
    p.add_argument("--self-test", action="store_true")
    a = p.parse_args()
    if a.self_test:
        return self_test()
    if not a.project_dir:
        p.error("--project-dir is required (or use --self-test)")
    a.project_dir = os.path.abspath(a.project_dir)
    return watch(a)


if __name__ == "__main__":
    sys.exit(main())
