#!/usr/bin/env python3
"""longrun-dashboard.py — local live dashboard for active /longrun runs + background project status.

v2 (2026-07-02): redesigned after v1 mis-detected activity (it only looked for the EXTERNAL
watcher's .longrun-watcher.log, which most /longrun runs never create — they run via the
in-session ralph-loop + keep-going mechanism instead). Now detects the REAL state markers:
  - `.claude/state/<project>/.longrun` flag + `.claude/ralph-loop.local.md` (session_id,
    max_iterations, completion_promise) = a true armed /longrun.
  - Plain CURRENT-TASK.md/STATUS.md/WORK_QUEUE.md/LOG.md at a project root (no .longrun flag)
    = a bounded background build (e.g. a single Agent-tool dispatch), shown as a lighter card.
Per longrun card: WORK_QUEUE done/open/in-progress counts + current item text, the keep-going
stall/loop counter (`.keep-going.progress.<sid>`), the last keep-going.log decision (continuing /
blocked-on-Douglas / finished), the live session transcript's size+freshness (fork-before-huge
warning folded in here, not as a separate table), and direct paths to the project's own output
files (STATUS.md, LOG.md, CURRENT-TASK, WORK_QUEUE) so "where's the output" has a real answer.

No external deps (stdlib http.server only). Binds 127.0.0.1 only.

v3 (2026-07-02): added a server tracker + start/stop controls for every server named in any
known project's `.claude/launch.json` (the exact same commands documented in
"Local dashboard commands — start & stop reference.md") - so starting/stopping one of Douglas's
own dashboards is a button click instead of a terminal command. This is the one place the
dashboard is no longer purely read-only: /api/servers/start spawns a subprocess (detached, using
that config's own already-vetted command - never an arbitrary one), /api/servers/stop kills
whatever process owns that port via taskkill. Both endpoints only ever act on configs found in
a real launch.json under a known root, never on arbitrary user input.

Run: python longrun-dashboard.py [--port 8756]
"""

import collections
import concurrent.futures
import contextlib
import glob
import http.server
import itertools
import json
import os
import re
import shutil
import socket
import socketserver
import subprocess
import sys
import threading
import urllib.error
import urllib.parse
import urllib.request

# Every child process this dashboard spawns (netstat / powershell / node / taskkill) is a console binary; when
# launched from the windowless pythonw parent Windows would otherwise allocate a NEW console for each one, flashing
# a popup window on every poll. CREATE_NO_WINDOW suppresses that. 0 on non-Windows so the flag is a harmless no-op.
_NO_WINDOW = getattr(subprocess, "CREATE_NO_WINDOW", 0)

HOME = os.path.expanduser("~")
PROJECTS_DIR = os.path.join(HOME, ".claude", "projects")
ROOTS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "longrun-dashboard.roots.txt")
ARCHIVE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "longrun-dashboard.archived.json")

DEFAULT_ROOTS = [
    r"C:\Users\dmcgowa2\Documents\Claude NASA Folder",
    r"C:\Users\dmcgowa2\Documents\Claude NASA Folder\ai-for-cad",
    r"C:\Users\dmcgowa2\Documents\Claude NASA Folder\ai-for-cad\cad-forge",
    r"C:\Users\dmcgowa2\Documents\Claude NASA Folder\text-to-truss",
    r"C:\Users\dmcgowa2\Documents\Claude NASA Folder\sme-tacit-frames",
    r"C:\Users\dmcgowa2\Documents\Claude GSFC Folder",
    r"C:\Users\dmcgowa2\Documents\Claude GSFC Folder\text-to-truss",
    r"C:\Users\dmcgowa2\Documents\Claude GSFC Folder\Text-to-Spaceship",
]

WARN_BYTES = 30 * 1024 * 1024
CRIT_BYTES = 50 * 1024 * 1024
STALL_COUNT_THRESHOLD = 3


_ROOT_DISCOVERY_SKIP_DIRS = {"node_modules", "__pycache__", ".git", ".claude", "_backups", "dist",
                             "build", ".venv", "venv", "site-packages", ".impeccable"}
_ROOT_MARKER_NAMES = (".git", "CURRENT-TASK.md", "package.json")


def _has_root_marker(path):
    return any(os.path.exists(os.path.join(path, m)) for m in _ROOT_MARKER_NAMES)


def _discover_child_roots(base_roots, max_depth=3):
    """Auto-discovers real project roots nested under each of `base_roots`, instead of requiring every
    subfolder to be hand-added to roots.txt (Douglas 2026-07-08: several real subfolders -- e.g.
    IDETC-ultra-decks, frames-workbench, dfm-explorable -- were never in the whitelist at all, so a
    session working almost entirely inside one of them fell through and matched the umbrella folder as
    the only remaining prefix). A subfolder qualifies if it directly contains .git/CURRENT-TASK.md/
    package.json; discovery BFS-expands up to max_depth levels so a nested case like ai-for-cad/
    cad-forge is found without hardcoding depth. Known junk dirs (node_modules, .git, __pycache__, a
    dotfolder, ...) are never descended into."""
    known = list(dict.fromkeys(base_roots))  # de-duped, order preserved
    frontier = list(known)
    for _ in range(max_depth):
        next_frontier = []
        for parent in frontier:
            try:
                children = os.listdir(parent)
            except OSError:
                continue
            for name in children:
                if name in _ROOT_DISCOVERY_SKIP_DIRS or name.startswith("."):
                    continue
                child = os.path.join(parent, name)
                if child in known or not os.path.isdir(child):
                    continue
                if _has_root_marker(child):
                    known.append(child)
                    next_frontier.append(child)
        if not next_frontier:
            break
        frontier = next_frontier
    return known


def load_roots():
    if os.path.isfile(ROOTS_FILE):
        with open(ROOTS_FILE, encoding="utf-8") as f:
            roots = [ln.strip() for ln in f if ln.strip() and not ln.strip().startswith("#")]
        if not roots:
            roots = DEFAULT_ROOTS
    else:
        roots = DEFAULT_ROOTS
    return _discover_child_roots(roots)


def load_archived():
    """Set of root paths Douglas has archived (hidden from the main board, still restorable).
    A missing or corrupt file just means "nothing archived yet" - never a crash."""
    if not os.path.isfile(ARCHIVE_FILE):
        return set()
    try:
        with open(ARCHIVE_FILE, encoding="utf-8") as f:
            data = json.load(f)
        return set(data) if isinstance(data, list) else set()
    except (OSError, json.JSONDecodeError):
        return set()


def save_archived(archived_set):
    with open(ARCHIVE_FILE, "w", encoding="utf-8") as f:
        json.dump(sorted(archived_set), f, indent=2)


# The archived-roots file is a shared read-modify-write resource: POST /api/longruns/archive and
# /unarchive each load the set, mutate it, and save it back. The server is a ThreadingTCPServer (one
# thread per connection), so without serialization two concurrent archive/unarchive POSTs each read
# the same set, mutate a private copy, and the last writer clobbers the other's change - a card the
# user tried to archive silently stays visible (or vice-versa). Only THIS process ever writes the
# file (no separate --drain-actions-style writer), so an in-process threading.Lock is sufficient;
# no cross-process OS advisory lock is needed here (unlike the action queue). - LR5-01, 2026-07-07.
_ARCHIVE_LOCK = threading.Lock()


def set_archived(root, archived):
    """Adds (archived=True) or removes (archived=False) `root` from the archived set as ONE atomic
    load-modify-save, serialized by _ARCHIVE_LOCK so concurrent archive/unarchive POSTs can't lose an
    update (LR5-01). Returns the updated set."""
    with _ARCHIVE_LOCK:
        current = load_archived()
        if archived:
            current.add(root)
        else:
            current.discard(root)
        save_archived(current)
        return current


def partition_archived(cards, archived_set):
    """Splits collect_all()'s output into (active, archived) by root membership in archived_set -
    a pure function so the actual partitioning logic (not just the file I/O) is unit-testable
    without spinning up the HTTP server."""
    active = [c for c in cards if c["root"] not in archived_set]
    archived = [c for c in cards if c["root"] in archived_set]
    return active, archived


def read_text(path, max_bytes=200_000):
    if not path:
        return None
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read(max_bytes + 1)
    except OSError:
        return None
    if len(content) > max_bytes:
        # Previously silent: zero signal anywhere that displayed checklist counts / current-item
        # detection were undercounting the real file (2026-07-03 solo-review, LOW - the largest
        # file in this exact deployment, text-to-truss's WORK_QUEUE.md, was 63KB against this
        # 200KB cap and actively growing). A stderr warning is visible in the terminal this
        # dashboard is run from, matching this file's own pattern of printing actionable messages
        # rather than swallowing problems, without changing every caller's return type.
        print("longrun-dashboard: WARNING - %s exceeds %d bytes and was truncated; checklist "
              "counts and current-item detection below the cutoff will be silently wrong"
              % (path, max_bytes), file=sys.stderr)
        content = content[:max_bytes]
    return content


def tail_lines(path, n=30):
    if not path or not os.path.isfile(path):
        return None
    try:
        with open(path, "rb") as f:
            f.seek(0, os.SEEK_END)
            size = f.tell()
            block = 8192
            data = b""
            while size > 0 and data.count(b"\n") <= n:
                step = min(block, size)
                size -= step
                f.seek(size)
                data = f.read(step) + data
        text = data.decode("utf-8", errors="replace")
        return "\n".join(text.splitlines()[-n:])
    except OSError:
        return None


def parse_frontmatter(text):
    """Tiny YAML-lite parser for ralph-loop.local.md's `---\\nkey: value\\n---` header."""
    if not text or not text.startswith("---"):
        return {}
    end = text.find("\n---", 3)
    if end == -1:
        return {}
    header = text[3:end]
    out = {}
    for line in header.splitlines():
        if ":" not in line:
            continue
        k, _, v = line.partition(":")
        v = v.strip().strip('"')
        out[k.strip()] = v
    return out


BLOCKED_KEYWORD_RE = re.compile(r"\bBLOCKED\b", re.I)


def parse_checklist(text):
    if not text:
        return {"x": 0, "open": 0, "wip": 0, "parked": 0, "blocked": 0}
    counts = {"x": 0, "open": 0, "wip": 0, "parked": 0, "blocked": 0}
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("- [x]"):
            counts["x"] += 1
        elif s.startswith("- [ ]"):
            # A source file may mark a genuinely-blocked item with the plain "open" checkbox
            # instead of "[!]" (found live 2026-07-02 in sme-tacit-frames/WORK_QUEUE.md, Component
            # 07 / Track C) - re-home it as blocked so "open" doesn't overstate real backlog.
            counts["blocked" if BLOCKED_KEYWORD_RE.search(s[5:]) else "open"] += 1
        elif s.startswith("- [~]"):
            counts["blocked" if BLOCKED_KEYWORD_RE.search(s[5:]) else "wip"] += 1
        elif s.startswith("- [?]"):
            counts["parked"] += 1
        elif s.startswith("- [!]"):
            counts["blocked"] += 1
    return counts


def _extract_tasks_auto_block(text):
    """Finds the content between "<!-- TASKS:AUTO START ... -->" and the next
    "<!-- TASKS:AUTO END -->", using plain str.find() rather than a regex (2026-07-03
    adversarial review, HIGH: the old regex `<!--\\s*TASKS:AUTO START.*?-->(.*?)<!--\\s*
    TASKS:AUTO END\\s*-->` exhibited catastrophic backtracking - verified live, a crafted 200KB
    CURRENT-TASK.md with many repeated unterminated START markers made a single dashboard
    request take 8.97s). str.find() is linear-time per call with no backtracking possible."""
    start_marker = text.find("TASKS:AUTO START")
    if start_marker == -1:
        return None
    start_tag_close = text.find("-->", start_marker)
    if start_tag_close == -1:
        return None
    end_marker = text.find("TASKS:AUTO END", start_tag_close)
    if end_marker == -1:
        return None
    return text[start_tag_close + 3:end_marker]


def parse_task_board(current_task_text):
    """Extract the in-chat TaskList board mirrored into CURRENT-TASK.md by
    mirror-tasks-to-current.js (the <!-- TASKS:AUTO START/END --> block) — this is the live
    per-session task/status stream Douglas asked for, not just the WORK_QUEUE file."""
    if not current_task_text:
        return None
    block = _extract_tasks_auto_block(current_task_text)
    if block is None:
        return None
    items = []
    for line in block.splitlines():
        s = line.strip()
        mm = re.match(r"^-\s*\[([ x~!?])\]\s*(.+)$", s)
        if mm:
            items.append({"marker": mm.group(1), "text": mm.group(2).strip()})
    if not items:
        return None
    return {"items": items, "counts": parse_checklist(block)}


def current_item_text(text):
    if not text:
        return None
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("- [~]"):
            return s[5:].strip()
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("- [ ]"):
            return s[5:].strip()
    return None


def _normalize_item_text(t):
    """Reduce an item's text to just its words, for comparing the same underlying task as
    described by two different sources (a WORK_QUEUE bullet vs. a mirrored in-chat task-board
    label) that use different punctuation/markdown around the same words."""
    if not t:
        return ""
    t = re.sub(r"[^a-z0-9 ]+", " ", t.lower())
    return re.sub(r"\s+", " ", t).strip()


def current_item_conflict(current_item, task_board):
    """Returns a warning string if `current_item` (the WORK_QUEUE-derived "next thing to do")
    appears to already be marked DONE in the live in-chat task board mirror - a direct, concrete
    sign the two sources have drifted apart (found live 2026-07-02: WORK_QUEUE said "next: T0-6",
    the task board already had T0-6 checked off 60+ items further along). Returns None when
    there's nothing to compare or no conflict is detected."""
    if not current_item or not task_board or not task_board.get("items"):
        return None
    cur = _normalize_item_text(current_item)
    if not cur:
        return None
    cur_words = cur.split()
    for item in task_board["items"]:
        if item.get("marker") != "x":
            continue
        done_text = _normalize_item_text(item.get("text"))
        if not done_text:
            continue
        done_words = done_text.split()
        if len(cur_words) <= len(done_words):
            shorter, longer, shorter_words, longer_words = cur, done_text, cur_words, done_words
        else:
            shorter, longer, shorter_words, longer_words = done_text, cur, done_words, cur_words
        # Word-boundary containment (not a raw substring, which can match mid-word) AND the
        # shorter text must make up a substantial fraction of the longer text's words - a short
        # shared boilerplate clause inside two otherwise-different task descriptions must not trip
        # this (2026-07-03 solo-review, MEDIUM: verified live with this project's own real SR1/SR2
        # adjacent items - "run solo review and apply fixes" is a literal substring of a much
        # longer, unrelated done-item's text, but only ~22% of its words - raising the old 8-char
        # minimum alone would NOT have fixed this, since the shared clause is already 32 chars).
        if (len(shorter_words) >= 3
                and (" " + shorter + " ") in (" " + longer + " ")
                and len(shorter_words) / len(longer_words) >= 0.5):
            return ("WORK_QUEUE's current item (%r) already appears DONE in the live task "
                    "board (%r) - these two sources have drifted; trust the live task board."
                    % (current_item[:80], item.get("text")))
    return None


def freshness_note(wq_mtime, ct_mtime, now):
    """When WORK_QUEUE.md and CURRENT-TASK.md (the two sources a longrun card blends) were last
    touched far apart in time, name whichever one is staler so a viewer knows which number to
    trust more. A small gap is normal edit-order noise, not a real staleness signal."""
    if wq_mtime is None or ct_mtime is None:
        return None
    gap = wq_mtime - ct_mtime
    if abs(gap) < FRESHNESS_GAP_SECONDS:
        return None
    staler = "taskboard" if gap > 0 else "checklist"
    return {"stalerSource": staler, "ageDiffSeconds": abs(gap)}


FRESHNESS_GAP_SECONDS = 30 * 60  # 30 min - found live 2026-07-02: a WORK_QUEUE and its own
                                 # session's task-board mirror can legitimately drift by minutes
                                 # during normal back-and-forth editing; an hour+ gap is the real
                                 # "one of these two sources stopped being updated" signal.

DORMANT_THRESHOLD_SECONDS = 30 * 60  # 30 min - a plain-file project (no active /longrun session)
                                      # with leftover open/wip checklist items but no output file
                                      # touched in the last half hour has nothing actually driving
                                      # it right now, however its "continuing"-labeled longrun
                                      # cousin project may be. Found live 2026-07-02: a project
                                      # card showed "continuing" for a subagent whose own recorded
                                      # text said "the agent dies with this session" - already
                                      # dead, not moving.


def plain_project_status(checklist, most_recent_mtime, now):
    """Status for a plain-file (no .longrun flag) project card. Distinguishes "has unfinished
    checklist items AND something touched an output file recently" (continuing) from "has
    unfinished items but nothing has touched this project in a while" (dormant - a real, distinct
    state from continuing, since nothing is actually advancing it right now) from "no signal
    either way" (unknown, an honest admission rather than defaulting to continuing)."""
    # Parked ([?] needs-Douglas) and blocked ([!]) items also count as "not fully finished" -
    # found live 2026-07-03: sme-tacit-frames had 0 open/wip but 2 parked + 2 blocked real
    # needs-Douglas items and still read "finished".
    has_remaining = bool(checklist.get("open") or checklist.get("wip")
                         or checklist.get("parked") or checklist.get("blocked"))
    if not has_remaining:
        return "finished", "no open/wip checklist items remaining"
    if most_recent_mtime is None:
        return "unknown", "has open/wip items, but no output file to check for recent activity"
    if (now - most_recent_mtime) < DORMANT_THRESHOLD_SECONDS:
        return "continuing", "has open/wip items and an output file was touched in the last 30 min"
    return "dormant", ("has open/wip items but no output file touched in over 30 min - "
                        "nothing appears to be actively driving this right now")


ADD_DIR_RE = re.compile(r'--add-dir\s+"([^"]+)"')


def extract_add_dirs(resume_cmd_text):
    """Pull every `--add-dir "<path>"` out of a `.resume-cmd.<sid>.sh` wrapper script - the
    session's OWN tracked output files (STATUS/LOG/WORK_QUEUE) often live under the workspace
    root's `.claude/state/` dir, nowhere near the actual project folder the session is driving,
    so this is the only generic signal that ties a longrun session to that project folder."""
    if not resume_cmd_text:
        return []
    return ADD_DIR_RE.findall(resume_cmd_text)


def find_cross_reference(project_root, longrun_cards):
    """If a plain-file project's root is the same folder (or a parent of the same folder) that
    an ACTIVE longrun card is writing its own output files into, OR that the session was given
    via `--add-dir`, return that longrun card's root - the two cards describe the same
    underlying project, and the plain-file one may be stale relative to the live one.
    Path-boundary safe: a root that merely shares a string prefix (e.g. 'C:\\W2\\subproject' vs
    'C:\\W') must not false-match."""
    # normcase lowercases on Windows (the only platform this script runs on) and is a no-op on
    # POSIX - without it, two paths that are the SAME folder on disk but differ only in case
    # (2026-07-03 solo-review, MEDIUM: this project's own Text-to-Spaceship root is capitalized on
    # disk while its .claude/state/ subdir is keyed lowercase "text-to-spaceship") spuriously fail
    # to cross-reference, since os.path.commonpath does plain case-sensitive string comparison.
    proj = os.path.normcase(os.path.normpath(project_root))
    for card in longrun_cards:
        candidates = [os.path.dirname(p) for p in (card.get("outputFiles") or [])]
        candidates += list(card.get("addDirs") or [])
        for cand in candidates:
            cand = os.path.normcase(os.path.normpath(cand))
            try:
                if os.path.commonpath([cand, proj]) == proj:
                    return card["root"]
            except ValueError:
                continue
    return None


def resolve_current_item(wq_text, ct_text):
    """Prefer WORK_QUEUE's own current-item signal. Only fall back to CURRENT-TASK's mirror
    when WORK_QUEUE has NO content at all - if WORK_QUEUE exists and simply has nothing open
    or wip left, that IS the real signal ("nothing left"), not a reason to fall through to a
    possibly-stale CURRENT-TASK snapshot from an earlier phase."""
    item = current_item_text(wq_text)
    if item is not None:
        return item
    if not wq_text:
        return current_item_text(ct_text)
    return None


# A safe session-id stem: letters, digits, dot, underscore, hyphen only. Deliberately excludes any
# path separator, drive-letter colon, and every glob metacharacter, so a caller-supplied id can't be
# used to escape PROJECTS_DIR or inject a glob pattern (see find_transcript / LR-01).
_SAFE_SESSION_ID_RE = re.compile(r"[A-Za-z0-9._-]+")


def find_transcript(session_id):
    if not session_id:
        return None
    # A session id is a bare filename stem (Claude Code uses UUIDs); it must never carry a path
    # separator, a drive letter, or a glob metacharacter. Without this guard a caller-supplied sid
    # like "C:/secret/x" collapses the os.path.join below to a raw absolute path (on Windows
    # os.path.join drops everything before a later drive-letter component) so glob reads ANY .jsonl
    # anywhere on disk, and a bare "*" dumps the newest transcript with no id known at all
    # (LR-01, 2026-07-07). The whitelist charset admits no "/" "\\" ":" "*" "?" "[" "]", closing
    # both the traversal and the glob-injection paths; anything else is treated as "no such session".
    if not _SAFE_SESSION_ID_RE.fullmatch(session_id):
        return None
    matches = glob.glob(os.path.join(PROJECTS_DIR, "*", session_id + ".jsonl"))
    if not matches:
        return None
    # A session_id should be unique, but a resumed/re-keyed project can leave the same
    # session_id.jsonl under more than one project-hash folder (2026-07-03 solo-review, HIGH) -
    # glob's match order isn't a documented contract, so pick the freshest, not matches[0].
    if len(matches) > 1:
        matches.sort(key=os.path.getmtime, reverse=True)
    path = matches[0]
    try:
        st = os.stat(path)
    except OSError:
        return None
    return {"path": path, "sizeBytes": st.st_size, "mtime": st.st_mtime}


def last_log_line_for(log_path, session_id):
    if not log_path or not os.path.isfile(log_path) or not session_id:
        return None
    try:
        with open(log_path, "r", encoding="utf-8", errors="replace") as f:
            lines = [ln for ln in f if ("sid=" + session_id) in ln]
    except OSError:
        return None
    return lines[-1].strip() if lines else None


def last_log_line_any(log_path):
    """sid-unfiltered fallback for when a ralph-loop's session_id can't be resolved (a .longrun
    flag present with no session_id in ralph-loop.local.md - found live 2026-07-02 on
    Text-to-Spaceship). last_log_line_for can't filter by sid in that case and returns None even
    though the log clearly has real content; this surfaces the log's actual last line instead of
    reporting no signal at all."""
    if not log_path or not os.path.isfile(log_path):
        return None
    try:
        with open(log_path, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except OSError:
        return None
    return lines[-1].strip() if lines else None


STALL_AGE_SECONDS = 600  # 10 min — found live 2026-07-02: a BLOCK decision with no follow-up
                         # transcript activity for 42+ minutes turned out to be a real, worth-
                         # flagging stall (possibly the mid-stream-stall/UI-wedge failure mode
                         # documented earlier), while a 5-6 minute gap on a different session was
                         # normal between-turns idle. "idle" alone didn't distinguish these — a
                         # human glancing at the dashboard needs the difference to be obvious, not
                         # something they compute themselves from a raw timestamp.


NEEDS_DOUGLAS_RE = re.compile(r"needs[\s-]douglas", re.I)


def derive_status(sentinels, last_log_line, transcript):
    """Returns (label, detail). Distinguishes "wanted to continue but nothing happened for a
    long time" (possibly-stalled — worth a look) from "wanted to continue and did, recently"
    (continuing — fine) and "nothing forced, quiet" (idle — fine, no action needed)."""
    age = _age_seconds(transcript["mtime"]) if transcript else None
    age_str = ("%dm" % round(age / 60)) if age is not None else "unknown"

    if sentinels.get("need_user"):
        return ("blocked", "waiting on Douglas (.need-user sentinel present)")
    if last_log_line and NEEDS_DOUGLAS_RE.search(last_log_line):
        # The .need-user sentinel isn't the only place this signal can live - the keep-going
        # logger sometimes writes an explicit "needs Douglas" phrase straight into the log line's
        # own text without a matching sentinel file ever getting dropped (2026-07-03 solo-review,
        # MEDIUM: verified live on Text-to-Spaceship - a real BLOCK line said "needs Douglas:
        # loosens 8 verdicts" while zero .need-user.* sentinel files existed anywhere under that
        # project). Treat it as an equal-strength blocked signal, same tier as the sentinel.
        return ("blocked", "waiting on Douglas - the log line itself says so, even though no "
                            ".need-user sentinel file exists")
    if sentinels.get("no_keepgoing") or sentinels.get("stop_autorun"):
        return ("stopped", "keep-going disabled for this session (sentinel present)")
    if last_log_line:
        if "queue empty; work complete" in last_log_line:
            return ("finished", "last decision: queue empty, work complete")
        if "completion token detected" in last_log_line:
            return ("finished", "completion-promise loop finished — completion token detected")
        if re.search(r"\bBLOCK\b", last_log_line):
            if age is not None and age < 300:
                return ("continuing", "forced to continue, and is — transcript active %s ago" % age_str)
            if age is not None and age >= STALL_AGE_SECONDS:
                return ("stalled",
                        "keep-going said continue, but no transcript activity in %s — "
                        "may be wedged (see the mid-stream-stall failure mode) or waiting on "
                        "something; worth a look" % age_str)
            return ("idle", "forced to continue, but no transcript activity in %s yet — "
                             "watch this if it doesn't move soon" % age_str)
        if re.search(r"\bALLOW\b", last_log_line):
            return ("idle", "last decision: ALLOW (not forced) — nothing more queued right now")
    if transcript and age is not None and age < 300:
        return ("active", "transcript writing within the last 5 minutes")
    return ("unknown", "no recent keep-going log entry or transcript activity found")


def checklist_says_finished(checklist):
    """True iff the checklist has at least one item AND none remain open/wip/parked/blocked - a
    fully checked-off WORK_QUEUE is strong, independent evidence of real completion, even when
    the keep-going log's activity signal is stale (found live 2026-07-02: a5056bdb's WORK_QUEUE
    went 7/7 done via work completed OUTSIDE the tracked resume mechanism, so no fresh
    keep-going log entry ever recorded it). An EMPTY checklist (nothing ever tracked here) is
    NOT the same thing as a completed one - must not be conflated. Parked ([?] needs-Douglas)
    and blocked ([!]) items also do NOT count as finished (found live 2026-07-03: sme-tacit-frames
    showed 0 open/wip but 2 parked + 2 blocked real needs-Douglas items, and still read
    "finished" - a viewer scanning for what needs attention would skip right past it)."""
    total = sum(checklist.get(k, 0) for k in ("x", "open", "wip", "parked", "blocked"))
    return total > 0 and all(checklist.get(k, 0) == 0 for k in ("open", "wip", "parked", "blocked"))


def override_status_if_checklist_finished(status, checklist):
    """A fully-completed checklist overrides an activity-DERIVED status (stalled/continuing/
    idle/unknown/active) to finished, but never an explicit sentinel-driven status (blocked =
    .need-user present, stopped = keep-going disabled) - those reflect a deliberate signal that
    must not be silently masked by an inference from checklist state."""
    if status in ("blocked", "stopped"):
        return status
    return "finished" if checklist_says_finished(checklist) else status


def _age_seconds(ts):
    import time
    return time.time() - ts


def _now_seconds():
    import time
    return time.time()


def size_risk(size_bytes):
    if size_bytes is None:
        return "ok"
    if size_bytes >= CRIT_BYTES:
        return "critical"
    if size_bytes >= WARN_BYTES:
        return "warn"
    return "ok"


def collect_longrun(root):
    state_root = os.path.join(root, ".claude", "state")
    longrun_flags = glob.glob(os.path.join(state_root, "*", ".longrun"))
    if not longrun_flags:
        return None
    # glob's ordering isn't a documented contract (2026-07-03 solo-review, HIGH) - if more than
    # one state dir under this root has a .longrun flag, the most-recently-touched one wins
    # instead of an arbitrary/OS-dependent pick.
    longrun_flags.sort(key=os.path.getmtime, reverse=True)
    state_dir = os.path.dirname(longrun_flags[0])

    ralph_path = os.path.join(root, ".claude", "ralph-loop.local.md")
    ralph = parse_frontmatter(read_text(ralph_path))
    sid = ralph.get("session_id") or resolve_session_id_for_state_dir(state_dir)

    wq_path = os.path.join(state_dir, "WORK_QUEUE.%s.md" % sid) if sid else None
    ct_path = os.path.join(state_dir, "CURRENT-TASK.%s.md" % sid) if sid else None
    wq_text = read_text(wq_path)
    ct_text = read_text(ct_path)
    resume_cmd_text = read_text(os.path.join(state_dir, ".resume-cmd.%s.sh" % sid)) if sid else None
    add_dirs = extract_add_dirs(resume_cmd_text)
    checklist = parse_checklist(wq_text)
    current_item = resolve_current_item(wq_text, ct_text)
    task_board = parse_task_board(ct_text)
    # Two independently-updated sources describing the same session can drift apart (found
    # live 2026-07-02: WORK_QUEUE said "next: T0-6" while the mirrored task board already had
    # T0-6 checked off, 60+ items further along) - surface BOTH the direct semantic conflict
    # and, more generally, which file was touched longer ago, so a viewer knows which number
    # in front of them to actually trust.
    item_conflict = current_item_conflict(current_item, task_board)
    wq_mtime = os.path.getmtime(wq_path) if wq_path and os.path.isfile(wq_path) else None
    ct_mtime = os.path.getmtime(ct_path) if ct_path and os.path.isfile(ct_path) else None
    stale_note = freshness_note(wq_mtime, ct_mtime, _now_seconds())

    progress_path = os.path.join(state_dir, ".keep-going.progress.%s" % sid) if sid else None
    progress_raw = read_text(progress_path)
    stall_count = None
    if progress_raw:
        try:
            stall_count = json.loads(progress_raw).get("count")
        except json.JSONDecodeError:
            pass

    sentinels = {
        "need_user": sid and (
            os.path.isfile(os.path.join(state_dir, ".need-user.%s" % sid))
            or os.path.isfile(os.path.join(root, ".need-user.%s" % sid))
        ),
        "no_keepgoing": sid and os.path.isfile(os.path.join(state_dir, ".no-keepgoing.%s" % sid)),
        "stop_autorun": sid and os.path.isfile(os.path.join(root, ".stop-autorun.%s" % sid)),
    }

    keep_going_log = os.path.join(state_dir, ".keep-going.log")
    # A .longrun flag can exist with no resolvable session_id (found live 2026-07-02 on
    # Text-to-Spaceship - ralph-loop.local.md missing/without session_id) - the sid-filtered
    # lookup can't work in that case, but the log still has real content worth showing rather
    # than reporting no signal at all.
    last_line = last_log_line_for(keep_going_log, sid) if sid else last_log_line_any(keep_going_log)
    transcript = find_transcript(sid)
    status, status_detail = derive_status(sentinels, last_line, transcript)
    if status != override_status_if_checklist_finished(status, checklist):
        status = override_status_if_checklist_finished(status, checklist)
        status_detail = "WORK_QUEUE is fully checked off (0 open, 0 in-progress) - overriding a stale activity-derived status"

    # For the "sort by most recent activity" Kanban toggle - the freshest of whatever timestamps
    # this card actually has (transcript write, WORK_QUEUE touch, CURRENT-TASK touch). None only
    # when the card has no timestamped signal at all, never fabricated.
    last_activity_ts = max([t for t in (
        transcript["mtime"] if transcript else None, wq_mtime, ct_mtime,
    ) if t is not None], default=None)

    return {
        "kind": "longrun",
        "root": root,
        "lastActivityTs": last_activity_ts,
        "sessionId": sid,
        "maxIterations": ralph.get("max_iterations"),
        "completionPromise": ralph.get("completion_promise"),
        "checklist": checklist,
        "currentItem": current_item,
        "stallCount": stall_count,
        "stallWarning": bool(stall_count and stall_count >= STALL_COUNT_THRESHOLD),
        "status": status,
        "statusDetail": status_detail,
        "transcript": transcript,
        "transcriptRisk": size_risk(transcript["sizeBytes"]) if transcript else "ok",
        "forkCmd": ("claude --resume %s --fork-session" % sid) if sid else None,
        "keepGoingTail": tail_lines(keep_going_log, 8),
        "taskBoard": task_board,
        "itemConflict": item_conflict,
        "staleNote": stale_note,
        "currentTaskText": (ct_text or "")[-4000:],
        "outputFiles": [p for p in [
            os.path.join(root, "STATUS.md"), os.path.join(root, "LOG.md"),
            wq_path, ct_path,
        ] if p and os.path.isfile(p)],
        "addDirs": add_dirs,
    }


def collect_plain_status(root):
    """A project with the plain-file convention (CURRENT-TASK.md etc at root) but no .longrun
    flag — e.g. a bounded background build dispatched as a single Agent call."""
    ct_path = os.path.join(root, "CURRENT-TASK.md")
    status_path = os.path.join(root, "STATUS.md")
    wq_path = os.path.join(root, "WORK_QUEUE.md")
    log_path = os.path.join(root, "LOG.md")
    if not any(os.path.isfile(p) for p in (ct_path, status_path, wq_path)):
        return None

    ct_text = read_text(ct_path)
    wq_text = read_text(wq_path)
    checklist = parse_checklist(wq_text)
    current_item = resolve_current_item(wq_text, ct_text)
    remaining_none = ct_text and re.search(r"##\s*Remaining steps.*\n+\s*None", ct_text, re.I)

    output_files = [p for p in [status_path, log_path, wq_path, ct_path] if os.path.isfile(p)]
    most_recent_mtime = max((os.path.getmtime(p) for p in output_files), default=None)
    # "continuing" previously meant just "has open/wip checklist items left", with no check for
    # whether anything is actually working on them right now (found live 2026-07-02: a project
    # card showed "continuing" for a subagent whose own recorded text said "the agent dies with
    # this session" - already dead). Distinguish real recent activity from a stale backlog.
    if remaining_none and not checklist["open"] and not checklist["wip"]:
        status, status_detail = "finished", "CURRENT-TASK.md's own Remaining-steps section says None"
    else:
        status, status_detail = plain_project_status(checklist, most_recent_mtime, _now_seconds())

    return {
        "kind": "project",
        "root": root,
        "lastActivityTs": most_recent_mtime,
        "checklist": checklist,
        "currentItem": current_item,
        "status": status,
        "statusDetail": status_detail,
        "logTail": tail_lines(log_path, 6),
        "taskBoard": parse_task_board(ct_text),
        "currentTaskText": (ct_text or "")[-3000:],
        "outputFiles": output_files,
    }


def load_server_configs():
    """Merge every known root's `.claude/launch.json` `configurations` array into one flat
    list. A config's own `cwd` field is honored when present (absolute as-is, relative joined
    against the scan root) - e.g. cad-forge-live-server's launch.json entry needs to run from
    a subdirectory of the scanned root, not the root itself. Falls back to the scan root when
    a config has no `cwd` of its own, so a relative directory argument (e.g. truss-forge-
    preview's "truss-forge") still resolves the same as before for every config that doesn't
    need an override. A missing or malformed launch.json is silently skipped, same as every
    other read in this file - one bad project must never take down the whole list."""
    configs = []
    for root in load_roots():
        lj_path = os.path.join(root, ".claude", "launch.json")
        text = read_text(lj_path)
        if not text:
            continue
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            continue
        for cfg in data.get("configurations", []):
            if not cfg.get("name") or not cfg.get("port"):
                continue
            # Coerce to int at load time (2026-07-03 review, MEDIUM x2: a launch.json with
            # "port" written as a JSON string, e.g. a typo'd "8756", would otherwise silently
            # break /api/servers/stop's `port in known_ports` check - int(x) in {"x"} is always
            # False in Python - and would also crash port_listening/find_pid_on_port downstream
            # with an unhandled TypeError). A config whose port genuinely isn't numeric is
            # skipped, same as the existing name/port truthiness skip just above.
            try:
                port = int(cfg["port"])
            except (TypeError, ValueError):
                continue
            cfg_cwd = cfg.get("cwd")
            if cfg_cwd:
                resolved_cwd = cfg_cwd if os.path.isabs(cfg_cwd) else os.path.join(root, cfg_cwd)
            else:
                resolved_cwd = root
            # Optional `openPath`: the in-app URL the "open" link should land on (e.g.
            # "/dashboard/truss-dashboard.html"), for servers whose useful page isn't the bare
            # root - the dashboard appends it to http://localhost:<port>. Absent -> "/" (default).
            open_path = cfg.get("openPath")
            if open_path and not str(open_path).startswith("/"):
                open_path = "/" + str(open_path)
            configs.append({
                "id": "%s::%s" % (root, cfg["name"]),
                "name": cfg["name"],
                "port": port,
                "runtimeExecutable": cfg.get("runtimeExecutable"),
                "runtimeArgs": cfg.get("runtimeArgs") or [],
                "cwd": resolved_cwd,
                "openPath": open_path or None,
            })
    return configs


def parse_netstat_listening(netstat_output):
    """Parses `netstat -ano` text into a list of (port, pid) for every LISTENING TCP entry -
    real IPv4/IPv6 output shape, no live process call needed for this part."""
    out = []
    for line in netstat_output.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[0] == "TCP" and parts[-2] == "LISTENING":
            local = parts[1]
            try:
                port = int(local.rsplit(":", 1)[1])
                pid = int(parts[-1])
            except (ValueError, IndexError):
                continue
            out.append((port, pid))
    return out


def filter_discovered(listening, known_ports, min_port=1024):
    """Which (port, pid) entries count as a genuinely NEW, undiscovered server: not already
    registered in any known launch.json, and not a low system port (Douglas asked: 'how can you
    make the dashboard auto add new servers, processes or dashboards on this computer?')."""
    return [(p, pid) for p, pid in listening if p not in known_ports and p >= min_port]


def resolve_process_names(pids):
    """One PowerShell call resolving every PID's Name + CommandLine, instead of N separate
    subprocess calls (one per discovered port) - returns {pid: (name, commandLine)}."""
    if not pids:
        return {}
    try:
        r = subprocess.run(
            ["powershell.exe", "-NoProfile", "-WindowStyle", "Hidden", "-Command",
             "Get-CimInstance Win32_Process | Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress"],
            capture_output=True, text=True, timeout=15, creationflags=_NO_WINDOW)  # never flash a console window on the poll
        data = json.loads(r.stdout)
        if isinstance(data, dict):
            data = [data]
    except Exception:
        return {}
    wanted = set(pids)
    return {d["ProcessId"]: (d.get("Name"), d.get("CommandLine"))
            for d in data if d.get("ProcessId") in wanted}


def list_discovered_servers():
    """Every listening port not already covered by a registered launch.json config, with the
    owning process's name + command line resolved. Read-only; never auto-registers anything -
    just surfaces it for a human to look at (and optionally stop)."""
    try:
        r = subprocess.run(["netstat", "-ano"], capture_output=True, text=True, timeout=10, creationflags=_NO_WINDOW)
        netstat_text = r.stdout
    except Exception:
        return []
    listening = parse_netstat_listening(netstat_text)
    known_ports = {c["port"] for c in load_server_configs()}
    discovered = filter_discovered(listening, known_ports)
    if not discovered:
        return []
    proc_info = resolve_process_names([pid for _, pid in discovered])
    out = []
    seen_ports = set()
    for port, pid in sorted(discovered):
        if port in seen_ports:  # a port can appear twice (IPv4 + IPv6 binds) - one row is enough
            continue
        seen_ports.add(port)
        name, cmdline = proc_info.get(pid, (None, None))
        out.append({"port": port, "pid": pid, "processName": name,
                    "commandLine": (cmdline or "")[:200]})
    return out


# ---- live Claude Code sessions (2026-07-07, merged in from Mission Control per Douglas: import
# FROM Mission Control INTO this dashboard, not the other way around) ---------------------------
# This dashboard is a headless Python HTTP server with no ccd_session_mgmt MCP access of its own,
# so it can only READ session transcripts and QUEUE dispatch requests - never inject a message
# into a live session directly. That's the same honest queue-not-inject design Mission Control's
# own ops-server.js already used (POST /api/action appends to ops-actions.jsonl; "an agent with
# the ccd MCP drains it on demand"), recovered from transcript forensics and reused here rather
# than reinvented.
SESSION_ACTIONS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "longrun-dashboard.session-actions.jsonl")
# Hard cap on how many records the shared action-queue file may hold. The queue endpoints are
# unauthenticated localhost POSTs, so without a bound a caller could append without limit and fill
# the disk (and the file is shared with the live watchdog instance) - LR-04, 2026-07-07.
SESSION_ACTIONS_MAX = 1000
# Hard cap on any POST body. These endpoints only ever carry tiny JSON control messages, so a larger
# Content-Length is a mistake or a resource-exhaustion attempt - reject it before reading a byte (LR2-03).
MAX_POST_BODY_BYTES = 1_000_000
SESSION_ACTIVE_SECONDS = 300  # matches the "active" freshness threshold used elsewhere in this file
SESSION_RECENT_DAYS = 2  # Douglas 2026-07-07: a session not touched in 2 days is auto-hidden ("archived")

# A spawned Agent/Workflow subagent gets its own top-level transcript, so the raw scan is flooded with
# them (found live 2026-07-07: ~285 of ~304 recent transcripts were one-shot agent dispatches vs ~19
# real sessions). Douglas: "take out any subagent sessions." Distinguishing them is subtle, and an
# earlier heuristic was too aggressive (adversarial review 2026-07-07): a REAL session can also have a
# single human message (an autonomous /longrun or /goal run) AND can run inside a git worktree, so
# neither the turn count nor the cwd path alone is decisive. The conservative rule that keeps every
# real session: a transcript is a spawned agent ONLY when it has <=1 human message AND that message
# OPENS like an agent dispatch (a role-instruction / structured-output prompt, matched as a PREFIX so a
# real message merely containing the phrase is safe). A multi-turn session is always kept whatever its
# first message says; a single-turn session with a natural human task is kept. cwd dir is not used.
_AGENT_PROMPT_PREFIXES = (
    "you are a rigorous", "you are a skeptical", "you are an expert", "you are a senior",
    "you are a neutral", "you are an autonomous", "you are hardening", "you are a meticulous",
    "you are reviewing", "you will be given", "given this real", "given the following",
    "respond with only", "return only ", "output exactly", "a reviewer (lens", "try hard to refute",
)
# Meta / slash-command plumbing skipped when picking a session's human title (so the card shows the
# real request, not "<local-command-caveat>..." or "<command-name>...").
_TITLE_SKIP_PREFIXES = ("<local-command-caveat>", "<command-name>", "<command-message>",
                        "caveat: the messages below were generated")
# The 7-day scan legitimately turns up hundreds of distinct sessions (found live 2026-07-07: 375
# real, non-duplicate sessions, only 5 active). Dumping all of them is exactly the "wall of text"
# Douglas already rejected once, so the panel shows only the freshest SESSION_DISPLAY_CAP. Because
# the list is sorted newest-first and "active" == freshest mtime, every active session floats to
# the top and is always shown; the cap only ever hides old idle ones. The true total is surfaced in
# the payload so the UI can say "showing N of M" -- never a silent truncation (per Douglas's rule).
SESSION_DISPLAY_CAP = 20

# Rough context window shared by the current Claude models, for the context% gauge. Not model-exact
# (some variants differ), so the gauge is labelled a rough fill indicator, never a precise number.
MODEL_CONTEXT_WINDOW = 200000
# Estimated per-MILLION-token USD prices, keyed by a substring match on the model id. These change
# over time and are NOT authoritative - every cost derived from them is labelled "est." in the UI so
# it never reads as a real invoice. cache_read is ~10% of input and cache_creation ~25% above input,
# per Mission Control's recovered token-pricing model (build-ops.js). Unknown model -> the Sonnet row
# (a safe mid estimate) rather than a fabricated exact figure.
MODEL_PRICING = {
    "opus":   {"input": 15.0, "output": 75.0, "cache_read": 1.5,  "cache_write": 18.75},
    "sonnet": {"input": 3.0,  "output": 15.0, "cache_read": 0.30, "cache_write": 3.75},
    "haiku":  {"input": 0.80, "output": 4.0,  "cache_read": 0.08, "cache_write": 1.0},
}


def _pricing_for(model):
    m = (model or "").lower()
    for key, table in MODEL_PRICING.items():
        if key in m:
            return table
    return MODEL_PRICING["sonnet"]  # safe mid estimate, never a fabricated exact figure


def _num_or_zero(v):
    """A numeric transcript leaf coerced to a number, or 0 for any non-numeric/absent type. A
    malformed transcript whose token field is a str/list/None must never reach the arithmetic in
    session_usage and raise a TypeError out of the wrapper-less do_GET (LR4-01, 2026-07-07) - the
    same 'a malformed transcript must never crash a parser' invariant as LR-02/LR3-01, applied to
    the leaf level the container guards don't cover."""
    return v if isinstance(v, (int, float)) else 0


def session_usage(session_id):
    """Reads a session's transcript and returns {model, contextTokens, contextPct, estCostUsd} for
    the sessions panel's cost/context gauge (merged in from Mission Control's build-ops cost model).
    contextTokens/Pct come from the MOST RECENT assistant usage (how full the window is right now);
    estCostUsd is a cumulative estimate summed across every assistant usage with the per-model price
    table. All figures are best-effort estimates - a transcript with no usage data returns zeros
    rather than a guess. Only ever called on the small capped display set, never all N transcripts."""
    tr = find_transcript(session_id)
    if not tr:
        return {"model": None, "contextTokens": 0, "contextPct": 0.0, "estCostUsd": 0.0}
    model = None
    last_context = 0
    cost = 0.0
    try:
        with open(tr["path"], "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not isinstance(event, dict):
                    continue  # a valid-JSON but non-object line (e.g. a bare scalar/array) has no .get (LR-02)
                msg = event.get("message")
                if not isinstance(msg, dict):
                    continue  # a truthy non-dict `message` (str/list/number/bool) has no .get (LR3-01)
                usage = msg.get("usage")
                if not isinstance(usage, dict):
                    continue
                if msg.get("model"):
                    model = msg.get("model")
                inp = _num_or_zero(usage.get("input_tokens"))   # a non-numeric leaf -> 0, not a TypeError (LR4-01)
                out = _num_or_zero(usage.get("output_tokens"))
                cr = _num_or_zero(usage.get("cache_read_input_tokens"))
                cw = _num_or_zero(usage.get("cache_creation_input_tokens"))
                # Most-recent turn's full context footprint (input + both cache tiers) = window fill.
                last_context = inp + cr + cw
                price = _pricing_for(model)
                cost += (inp * price["input"] + out * price["output"]
                         + cr * price["cache_read"] + cw * price["cache_write"]) / 1_000_000.0
    except OSError:
        return {"model": None, "contextTokens": 0, "contextPct": 0.0, "estCostUsd": 0.0}
    return {
        "model": model,
        # Clamp to >= 0: a transcript with a malformed negative token field would otherwise yield a
        # negative contextTokens/Pct or estCostUsd - min() only bounds the top (probe property
        # counterexample, 2026-07-07).
        "contextTokens": max(0, last_context),
        "contextPct": round(min(1.0, max(0.0, last_context / MODEL_CONTEXT_WINDOW)), 3),
        "estCostUsd": round(max(0.0, cost), 2),
    }


def _title_is_dispatch(title):
    """True when a first message OPENS like an agent dispatch (matched as a prefix)."""
    t = (title or "").lstrip().lower()
    return any(t.startswith(sig) for sig in _AGENT_PROMPT_PREFIXES)


def _session_meta(transcript_path, max_len=80, max_lines=8000):
    """In ONE pass over a transcript's lines: the first genuine human title (skipping meta / slash-
    command plumbing, truncated), the session's cwd, and a human-message count capped at 2. Returns
    (title, cwd, human_turns). Stops early once it has enough to classify: a natural-prompt session is
    kept regardless of turn count, so we stop as soon as title+cwd are known and the title isn't a
    dispatch opener; a dispatch-looking title keeps scanning only until a 2nd human turn proves it's a
    real (multi-turn) session. max_lines bounds a pathological one-turn transcript."""
    title = None
    cwd = None
    human_turns = 0
    try:
        with open(transcript_path, "r", encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i >= max_lines:
                    break
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not isinstance(event, dict):
                    continue  # a valid-JSON but non-object line (e.g. a bare scalar/array) has no .get (LR-02)
                if cwd is None and event.get("cwd"):
                    cwd = event["cwd"]
                if event.get("type") != "user" or event.get("isMeta"):
                    continue
                msg = event.get("message")
                content = msg.get("content") if isinstance(msg, dict) else None  # LR3-01: non-dict message
                text = None
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    if all(isinstance(b, dict) and b.get("type") == "tool_result" for b in content):
                        continue  # a tool_result-only user turn is not a human message
                    for block in content:
                        if isinstance(block, dict) and block.get("type") == "text":
                            text = block.get("text")
                            break
                if not (isinstance(text, str) and text.strip()):  # a non-str `text` leaf -> skip, not a .strip() crash (LR4-01)
                    continue
                text = text.strip()
                if any(text.lower().startswith(p) for p in _TITLE_SKIP_PREFIXES):
                    continue  # meta/command plumbing (e.g. a queued slash command) is not a genuine
                    # human turn either -- a transcript with ONLY these still counted as human_turns>=1
                    # (Douglas 2026-07-08: "3777ffa5..." was hook noise + a queued /usage command, no
                    # real human text, but still showed up as a "real" session with its raw id as title)
                human_turns += 1
                if title is None:
                    title = (text[:max_len] + "...") if len(text) > max_len else text
                # Early exit: enough to classify?
                if title is not None and cwd is not None:
                    if not _title_is_dispatch(title):
                        break  # natural-prompt session -> kept regardless of turn count
                    if human_turns >= 2:
                        break  # dispatch-looking but multi-turn -> a real session, kept
    except OSError:
        return None, None, 0
    return title, cwd, human_turns


def _looks_like_subagent(title, human_turns):
    """A spawned one-shot Agent/Workflow dispatch rather than a real session. Conservative (adversarial
    review 2026-07-07): a session with 2+ human messages is ALWAYS real; a single-message transcript is
    an agent only if that message OPENS like an agent dispatch. Keeps autonomous /longrun runs (one
    natural human message) and worktree sessions; only the classifier/verify agents get dropped.
    Zero human turns (Douglas 2026-07-08: stray debug files and hook-only-noise transcripts with no
    genuine human message were still counting as "real" sessions) is never a real session, regardless
    of title."""
    if human_turns == 0:
        return True
    if human_turns >= 2:
        return False
    return _title_is_dispatch(title)


def _folder_from_cwd(cwd):
    """A clean display folder name from a cwd: the last path segment, or the drive/root token itself
    when the cwd IS a drive/UNC root (basename of 'C:\\' is empty). None only for a missing cwd."""
    if not cwd:
        return None
    trimmed = cwd.rstrip("\\/")
    return os.path.basename(trimmed) or trimmed or cwd


# Per-transcript meta cache keyed by (path, mtime): a done agent/session transcript never changes, so
# its (title, cwd, turns) classification is computed once; only the single growing active transcript is
# re-read each poll. Bounds the turn-count scan cost to one file in steady state.
_SESSION_META_CACHE = {}


def _session_meta_cached(path, mtime):
    ent = _SESSION_META_CACHE.get(path)
    if ent and ent[0] == mtime:
        return ent[1]
    result = _session_meta(path)
    _SESSION_META_CACHE[path] = (mtime, result)
    return result


def _dedupe_resumed_sessions(sessions):
    """/resume or /compact spawns a brand-new session-id transcript that replays the same first human
    message into it, so one logical thread of work gets counted 2-3x as separate "real" sessions
    (Douglas 2026-07-08: confirmed live, e.g. 3 ai-for-cad transcripts sharing an identical opening
    title). Same folder + identical real title collapses to just the most recently active copy. A
    title that fell back to the raw session id (no genuine title found in the transcript) is never
    used as a dedup key -- each such entry is kept as its own session rather than risk collapsing two
    unrelated id-less entries that happen to share a folder. Also guarded to titles of at least 20
    characters: a short generic message ("hi", "ok", "continue") is common across many genuinely
    distinct sessions and must never collapse them together -- only a reasonably specific title match
    is trusted as evidence of the same replayed thread."""
    best_by_key = {}
    keyless = []
    for s in sessions:
        if s["title"] == s["id"] or len(s["title"]) < 20:
            keyless.append(s)
            continue
        key = (s["folder"], s["title"])
        cur = best_by_key.get(key)
        if cur is None or s["lastActivityTs"] > cur["lastActivityTs"]:
            best_by_key[key] = s
    return list(best_by_key.values()) + keyless


def list_claude_sessions():
    """One summary record per REAL Claude Code session transcript under ~/.claude/projects, most
    recently active first: id, title (first user message), folder (the cwd's last path segment,
    for a clean display name), lastActivityTs (transcript mtime), and state. State is ONLY "active"
    (touched within the last 5 minutes) or "idle" - there is deliberately no "waiting on you"
    detection here, since that needs real event-pairing logic; claiming it without that would be the
    kind of fabricated certainty this dashboard's honesty principle forbids. Bounded to the last
    SESSION_RECENT_DAYS (a session untouched longer is auto-hidden), spawned subagent/agent
    transcripts are excluded (Douglas 2026-07-07), and resume/compact duplicates of the same thread
    are collapsed to one (Douglas 2026-07-08)."""
    sessions = []
    if not os.path.isdir(PROJECTS_DIR):
        return sessions
    now = _now_seconds()
    cutoff = now - (SESSION_RECENT_DAYS * 86400)
    seen = set()
    roots = load_roots()
    for project_dir in glob.glob(os.path.join(PROJECTS_DIR, "*")):
        if not os.path.isdir(project_dir):
            continue
        dirname = os.path.basename(project_dir)
        for transcript_path in glob.glob(os.path.join(project_dir, "*.jsonl")):
            try:
                mtime = os.path.getmtime(transcript_path)
            except OSError:
                continue
            if mtime < cutoff:
                continue
            seen.add(transcript_path)
            title, cwd, turns = _session_meta_cached(transcript_path, mtime)
            if _looks_like_subagent(title, turns):
                continue  # spawned one-shot agent dispatch, not a real session
            session_id = os.path.splitext(os.path.basename(transcript_path))[0]
            # Attribute by whichever KNOWN root the session's OWN cwd lines reference most, not just
            # the first cwd frozen at session start (Douglas 2026-07-08) -- falls back to the original
            # frozen-cwd folder when no line ever referenced a known root (a genuinely top-level session).
            dominant_root = _dominant_root_cached(transcript_path, mtime, roots)
            folder = _folder_from_cwd(dominant_root) if dominant_root else (_folder_from_cwd(cwd) or dirname)
            sessions.append({
                "id": session_id,
                "title": title or session_id,
                "folder": folder,
                "cwd": cwd,
                "lastActivityTs": mtime,
                "state": "active" if (now - mtime) < SESSION_ACTIVE_SECONDS else "idle",
            })
    for gone in [p for p in _SESSION_META_CACHE if p not in seen]:
        del _SESSION_META_CACHE[gone]  # bound cache memory to the current in-window set
    for gone in [p for p in _ROOT_ATTR_CACHE if p not in seen]:
        del _ROOT_ATTR_CACHE[gone]
    sessions = _dedupe_resumed_sessions(sessions)
    sessions.sort(key=lambda s: s["lastActivityTs"], reverse=True)
    return sessions


def session_detail(session_id, limit=25):
    """Recent activity for one session (Mission Control's sessionDetail, on-expand): the last
    `limit` meaningful events as {kind, ...} dicts - assistant text, assistant tool_use (tool name +
    a short input preview), and user text. Reads only the transcript tail, so expanding a row is
    cheap. Returns [] for a missing/empty transcript rather than raising."""
    tr = find_transcript(session_id)
    if not tr:
        return []
    try:
        with open(tr["path"], "rb") as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(max(0, size - 131072))  # last 128 KB is plenty for the last ~25 events
            tail = f.read().decode("utf-8", "replace")
    except OSError:
        return []
    events = []
    for line in tail.splitlines():
        if not line.strip():
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue  # a partial first line sliced by the seek
        if not isinstance(ev, dict):
            continue  # a valid-JSON but non-object line (e.g. a bare scalar/array) has no .get (LR-02)
        etype = ev.get("type")
        msg = ev.get("message")
        content = msg.get("content") if isinstance(msg, dict) else None  # LR3-01: non-dict message
        if etype == "user":
            text = content if isinstance(content, str) else None
            if isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "text":
                        text = b.get("text"); break
            if isinstance(text, str) and text.strip():  # a non-str `text` leaf -> skip, not a .strip() crash (LR4-01)
                events.append({"kind": "user", "text": text.strip()[:400]})
        elif etype == "assistant" and isinstance(content, list):
            for b in content:
                if not isinstance(b, dict):
                    continue
                bt = b.get("text")
                if b.get("type") == "text" and isinstance(bt, str) and bt.strip():  # non-str text leaf -> skip (LR4-01)
                    events.append({"kind": "assistant", "text": bt.strip()[:400]})
                elif b.get("type") == "tool_use":
                    inp = b.get("input")
                    inp = inp if isinstance(inp, dict) else {}  # a non-dict `input` leaf -> {}, not a .get() crash (LR4-01)
                    preview = inp.get("command") or inp.get("file_path") or inp.get("pattern") or inp.get("description") or ""
                    events.append({"kind": "tool", "tool": b.get("name") or "?", "input": str(preview)[:120]})
    return events[-limit:]


def session_pending_input(session_id):
    """True only on the CLEAREST honest 'needs you' signal: the transcript's final event is an
    assistant message paused with stop_reason == 'tool_use' (it wants to run a tool and nothing has
    followed - i.e. it's blocked awaiting continuation/approval). Deliberately conservative: it
    does NOT try to infer 'waiting' from an ordinary end_turn (which is ambiguous - could be a
    finished task or an unanswered question), because a false 'waiting on you' would violate the
    dashboard's never-look-more-certain-than-the-data rule. Reads only the file's tail, so it's
    cheap enough to run on the capped display set every poll. Under-detects on purpose; never
    over-claims. This is Nimbalyst's 3rd state (running / waiting-on-you / done) done honestly."""
    tr = find_transcript(session_id)
    if not tr:
        return False
    try:
        with open(tr["path"], "rb") as f:
            f.seek(0, 2)
            size = f.tell()
            f.seek(max(0, size - 16384))
            tail = f.read().decode("utf-8", "replace")
    except OSError:
        return False
    for line in reversed([ln for ln in tail.splitlines() if ln.strip()]):
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue  # a partial first line sliced by the seek - skip to the next complete one
        if not isinstance(event, dict):
            continue  # a valid-JSON but non-object line (e.g. a bare scalar/array) has no .get (LR-02)
        if event.get("type") != "assistant":
            return False  # the true last event isn't an assistant turn -> not paused on us
        msg = event.get("message")  # LR3-01: a truthy non-dict message must read as 'not paused', not crash
        return isinstance(msg, dict) and msg.get("stop_reason") == "tool_use"
    return False


class SessionQueueFull(Exception):
    """Raised when the shared action-queue file has hit SESSION_ACTIONS_MAX records, so an
    unauthenticated caller can't keep appending and fill the disk (LR-04)."""


# The action-queue file is a shared read-modify-write resource: queue_session_action appends, while
# drain_pending_actions reads-then-truncate-rewrites. The server is a ThreadingTCPServer (one thread
# per connection) AND a separate `--drain-actions` process can drain at the same time, so without
# serialization an append landing between a drain's read and its rewrite is silently dropped (lost
# update) and two concurrent drains each read the same pending set and hand the same action out more
# than once (double delivery) - LR3-02, 2026-07-07. _ACTION_QUEUE_LOCK serializes the in-process
# (concurrent-HTTP) races; the OS advisory lock on a sidecar lockfile serializes the cross-process
# `--drain-actions` case (and is auto-released by the OS if the holder dies, so no stale-lock deadlock).
_ACTION_QUEUE_LOCK = threading.Lock()


def _os_lock_file(fh):
    """Best-effort EXCLUSIVE OS advisory lock on an open file handle, for cross-PROCESS serialization.
    A no-op if the platform's lock module is unavailable - the in-process _ACTION_QUEUE_LOCK still holds."""
    try:
        import msvcrt
        fh.seek(0)
        msvcrt.locking(fh.fileno(), msvcrt.LK_LOCK, 1)
        return
    except (ImportError, OSError):
        pass
    try:
        import fcntl
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
    except (ImportError, OSError):
        pass


def _os_unlock_file(fh):
    """Release the lock taken by _os_lock_file (best-effort; the OS also drops it on close/exit)."""
    try:
        import msvcrt
        fh.seek(0)
        msvcrt.locking(fh.fileno(), msvcrt.LK_UNLCK, 1)
        return
    except (ImportError, OSError):
        pass
    try:
        import fcntl
        fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
    except (ImportError, OSError):
        pass


@contextlib.contextmanager
def _action_queue_locked():
    """Serializes the action queue's read-modify-write across BOTH concurrent HTTP threads and the
    separate --drain-actions process (see _ACTION_QUEUE_LOCK's comment). Held only for the brief
    check-then-append / read-then-rewrite critical section. The lockfile path is derived from the
    CURRENT SESSION_ACTIONS_FILE at call time, so the self-test's tmp-file swap is honoured."""
    with _ACTION_QUEUE_LOCK:
        fh = open(SESSION_ACTIONS_FILE + ".lock", "a+")
        try:
            _os_lock_file(fh)
            yield
        finally:
            try:
                _os_unlock_file(fh)
            finally:
                fh.close()


def queue_session_action(session_id, text):
    """Appends a dispatch request to the local queue file - see the module comment above for why
    this can't inject the message directly. Returns the record that was written. Refuses once the
    queue file has reached SESSION_ACTIONS_MAX records (LR-04 disk-fill guard)."""
    import time
    record = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "sessionId": session_id,
        "text": text[:2000],
        "status": "queued",
    }
    # The cap check and the append must be one atomic critical section, else a concurrent drain/append
    # can lose or duplicate the record (LR3-02). _read_all_actions does NOT itself lock, so calling it
    # here does not re-enter the (non-reentrant) lock.
    with _action_queue_locked():
        if len(_read_all_actions()) >= SESSION_ACTIONS_MAX:
            raise SessionQueueFull(
                "the session-action queue is full (%d records) - drain it (POST /api/actions/drain) "
                "before queueing more" % SESSION_ACTIONS_MAX)
        with open(SESSION_ACTIONS_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(record) + "\n")
    return record


def broadcast_session_action(text):
    """Queues the same message to every currently-ACTIVE session (Mission Control's broadcast, over
    the same queue-not-inject mechanism). Returns the list of session ids queued. Targets only
    'active' (touched in the last 5 min) so a broadcast doesn't spam hundreds of dead transcripts."""
    active_ids = [s["id"] for s in list_claude_sessions() if s["state"] == "active"]
    for sid in active_ids:
        queue_session_action(sid, text)
    return active_ids


# ---- hook-back telemetry (the recon "keystone"): a session's own Claude Code hooks POST lifecycle
# events here, so the dashboard learns state by PUSH instead of only by transcript-polling. The
# receiver + store live here; wiring the actual hook is a settings.json change left to Douglas (a
# harness-config edit that must go through his update-config / harness-keying discipline, not be made
# silently by this tool). To wire it, add a Notification + Stop hook that curls:
#   POST http://127.0.0.1:8756/api/session-event  {"sessionId":"$SID","event":"Notification","state":"waiting"}
# Telemetry is intentionally in-memory + ephemeral (live state, not history); it rebuilds as sessions
# post again after any dashboard restart.
_SESSION_EVENTS = {}
_SESSION_EVENTS_LOCK = threading.Lock()
SESSION_TELEMETRY_FRESH_SECONDS = 300
# Hard cap on how many distinct sessions the in-memory telemetry store may hold. The store is reachable
# via the unauthenticated POST /api/session-event, so without a bound a flood of unique sessionIds grows
# process memory forever (the in-memory parallel of the LR-04 on-disk disk-fill guard) - LR3-03, 2026-07-07.
SESSION_EVENTS_MAX = 1000
# Per-field VALUE cap (chars). Bounding only the ENTRY COUNT (above) does not bound MEMORY: the store is
# reachable via the unauthenticated POST /api/session-event, which accepts up to MAX_POST_BODY_BYTES (1MB)
# per request, so a single ~1MB field x SESSION_EVENTS_MAX entries would still cost ~0.6-1GB resident. Cap
# each stored field (including the session_id KEY) to mirror the LR-04 on-disk text[:2000] guard - LR5-02.
SESSION_EVENT_VALUE_MAX = 2000


def record_session_event(session_id, event, state):
    """Stores the latest pushed lifecycle event for a session (thread-safe; the server is threaded).
    Bounds the store (LR3-03): when it exceeds SESSION_EVENTS_MAX, entries already past the freshness
    window are dropped first (latest_session_telemetry ignores those on read anyway), and if it is still
    over the cap the OLDEST by timestamp are evicted - the freshest (the ones actually shown) always win."""
    now = _now_seconds()
    # Cap each field (and the KEY) so one oversized push can't cost ~1MB x SESSION_EVENTS_MAX entries
    # of resident memory - the count bound alone does not bound memory (LR5-02).
    session_id = str(session_id)[:SESSION_EVENT_VALUE_MAX]
    event = str(event)[:SESSION_EVENT_VALUE_MAX]
    state = str(state)[:SESSION_EVENT_VALUE_MAX]
    with _SESSION_EVENTS_LOCK:
        _SESSION_EVENTS[session_id] = {"event": event, "state": state, "ts": now}
        if len(_SESSION_EVENTS) > SESSION_EVENTS_MAX:
            stale_before = now - SESSION_TELEMETRY_FRESH_SECONDS
            for sid in [k for k, v in list(_SESSION_EVENTS.items())
                        if k != session_id and v["ts"] < stale_before]:
                del _SESSION_EVENTS[sid]
            if len(_SESSION_EVENTS) > SESSION_EVENTS_MAX:
                overflow = len(_SESSION_EVENTS) - SESSION_EVENTS_MAX
                for sid, _v in sorted(_SESSION_EVENTS.items(), key=lambda kv: kv[1]["ts"])[:overflow]:
                    if sid != session_id:
                        del _SESSION_EVENTS[sid]
        return _SESSION_EVENTS[session_id]


def latest_session_telemetry(session_id):
    """The most recent pushed event for a session if it's still fresh, else None. A stale telemetry
    entry is ignored rather than trusted - the dashboard never looks more current than its data."""
    with _SESSION_EVENTS_LOCK:
        te = _SESSION_EVENTS.get(session_id)
    if not te:
        return None
    if (_now_seconds() - te["ts"]) > SESSION_TELEMETRY_FRESH_SECONDS:
        return None
    return te


def _read_all_actions():
    """Every action record in the queue file, in order. [] if the file doesn't exist / is unreadable."""
    if not os.path.isfile(SESSION_ACTIONS_FILE):
        return []
    out = []
    try:
        with open(SESSION_ACTIONS_FILE, encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except OSError:
        return []
    return out


def read_pending_actions():
    """Just the still-queued (undelivered) actions - what an agent with the ccd MCP needs to send."""
    return [a for a in _read_all_actions() if a.get("status") == "queued"]


def drain_pending_actions():
    """Returns the pending actions AND marks them delivered (rewriting the queue file so they aren't
    handed out twice). This is the 'an agent drains the queue on demand' step from Mission Control's
    design, made real: the dashboard still can't inject a message itself, but an agent that HAS the
    ccd_session_mgmt MCP calls this, gets the queued messages, and send_message()s each one. Marking
    them delivered here is what stops the same message being sent on the next drain."""
    # The read + mark-delivered + rewrite must be one atomic critical section, else two concurrent
    # drains each read the same pending set and hand the same action out twice (LR3-02).
    with _action_queue_locked():
        all_actions = _read_all_actions()
        pending = [a for a in all_actions if a.get("status") == "queued"]
        if pending:
            for a in all_actions:
                if a.get("status") == "queued":
                    a["status"] = "delivered"
            with open(SESSION_ACTIONS_FILE, "w", encoding="utf-8") as f:
                for a in all_actions:
                    f.write(json.dumps(a) + "\n")
    return pending


class StartLock:
    """Serializes concurrent /api/servers/start requests for the same port (2026-07-03
    adversarial review, HIGH: verified live - a TOCTOU race between the port_listening() check
    and the Popen call let 5 concurrent requests for the same config all pass the check before
    any of them finished launching, spawning 5 independently-listening duplicate processes; a
    single stop call only killed 1 of them, leaving 4 invisible orphans). Only one caller can
    hold a given port's claim at a time; releasing makes it claimable again."""
    def __init__(self):
        self._lock = threading.Lock()
        self._starting = set()

    def try_acquire(self, port):
        with self._lock:
            if port in self._starting:
                return False
            self._starting.add(port)
            return True

    def release(self, port):
        with self._lock:
            self._starting.discard(port)


_START_LOCK = StartLock()


def port_listening(port):
    """True iff something is actually accepting connections on 127.0.0.1:<port> right now."""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(0.3)
    try:
        s.connect(("127.0.0.1", port))
        return True
    except OSError:
        return False
    finally:
        s.close()


def check_http_health(port, timeout=1.5):
    """A TCP-listening port does not mean the process behind it is actually serving anything
    useful - it could be hung, deadlocked, or accepting connections without ever responding.
    Found live 2026-07-06: Douglas asked for a REAL health signal ("connected, functional, and
    working"), not just "is a socket open". Only meaningful to call on a port that already
    passed port_listening - a genuinely stopped server has no need for this, keeping the cost
    of this check limited to whatever's actually running right now, not every configured server
    on every poll. Returns True the moment ANY real HTTP response comes back, even an error
    status (a 404/500 still proves the process is alive and talking); False only on a timeout
    or a connection genuinely refused/reset despite the port appearing open."""
    try:
        urllib.request.urlopen("http://127.0.0.1:%d/" % port, timeout=timeout)
        return True
    except urllib.error.HTTPError:
        return True  # a real HTTP response, even an error one, proves the process is alive
    except Exception:
        return False


# The dashboard's canonical port. is_protected_port shields it from /api/servers/stop even when the
# instance handling the request is bound to a DIFFERENT port, because 8756 is itself registered as a
# stoppable server in a launch.json - so without this a second instance (or a CSRF-driven stop, LR2-01)
# would happily kill the primary dashboard on 8756 (LR2-02, spar round 2, 2026-07-07).
CANONICAL_DASHBOARD_PORT = 8756


def is_protected_port(port, own_port):
    """The dashboard's own listening port must never be stoppable through its own
    /api/servers/stop endpoint (2026-07-03 adversarial review, CRITICAL: verified live -
    POST /api/servers/stop?port=8756 found the dashboard's own PID via netstat and killed the
    very process serving that request, because the dashboard lists itself in launch.json so it
    passes the ordinary known-ports check). own_port is this running instance's actual bound
    port, not a hardcoded default, so this holds even if launched with --port on something other
    than 8756. The canonical port 8756 is ALSO always protected, so a second instance bound to a
    different port (or a CSRF-driven stop) can't kill the primary dashboard (LR2-02, 2026-07-07)."""
    return port == own_port or port == CANONICAL_DASHBOARD_PORT


def resolve_session_id_for_state_dir(state_dir):
    """When ralph-loop.local.md is missing or has no session_id, recover a sid from the state
    dir's own WORK_QUEUE.<sid>.md / CURRENT-TASK.<sid>.md filenames instead of going fully blank
    (2026-07-03 solo-review, CRITICAL: verified live - Text-to-Spaceship has no
    ralph-loop.local.md at all, yet its state dir holds a real, current, needs-Douglas
    WORK_QUEUE the dashboard was silently never reading, showing an empty/misleading card
    instead). If more than one candidate exists, the most-recently-modified one wins."""
    candidates = []
    for pattern in ("WORK_QUEUE.*.md", "CURRENT-TASK.*.md"):
        for p in glob.glob(os.path.join(state_dir, pattern)):
            m = re.match(r"^(?:WORK_QUEUE|CURRENT-TASK)\.(.+)\.md$", os.path.basename(p))
            if m:
                candidates.append((os.path.getmtime(p), m.group(1)))
    if not candidates:
        return None
    candidates.sort(key=lambda c: c[0], reverse=True)
    return candidates[0][1]


# ---- project-based skills coverage --------------------------------------------------------
# "Which of the skills that make sense for most projects have actually been RUN on each project."
# Scoped to a PROJECT: aggregated across ALL of that project's session transcripts, so coverage
# accumulates over the project's whole history and carries across sessions. The master list below was
# seeded from a scan of Douglas's own transcripts (the skills he runs most) + his explicit picks (2026-07-07).
SKILLS_CACHE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "longrun-dashboard.skills-cache.json")
# The server is threaded (one worker per connection), so two /api/skills requests can land at once.
# This serializes the scan+save section below so they don't both run the full cold-start corpus scan
# or interleave their cache writes into corrupt JSON (review 2026-07-07, reproduced 93% corruption).
_SKILLS_LOCK = threading.Lock()
# A cold cache-miss over hundreds of transcripts is CPU-bound Python line-scanning; above this many
# to-scan files, fan the scan out over a process pool (tune C1, 2026-07-07: measured ~5.9s -> ~1.9s
# cold, output verified byte-identical). The incremental steady state (a few changed files) stays
# serial and pays zero spawn/pickle overhead.
_SKILLS_PARALLEL_THRESHOLD = 32

# key      = stable id + the label shown on the chip (Douglas asked "sweep" be shown as "cleanup").
# cat      = grouping for the panel. aliases = the raw invoked-skill / slash-command names that count
# as this skill (namespaced forms like "superpowers:brainstorming" are matched by their bare tail too;
# "impeccable" is matched as a substring so every impeccable:* subcommand counts as the one entry).
SKILL_MASTER = [
    {"key": "brainstorming",                  "label": "brainstorm",           "cat": "Plan & build",     "aliases": ["brainstorming"]},
    {"key": "writing-plans",                  "label": "writing-plans",        "cat": "Plan & build",     "aliases": ["writing-plans"]},
    {"key": "test-driven-development",        "label": "TDD",                  "cat": "Plan & build",     "aliases": ["test-driven-development", "tdd"]},
    {"key": "subagent-driven-development",    "label": "subagent-driven",      "cat": "Plan & build",     "aliases": ["subagent-driven-development"]},
    {"key": "systematic-debugging",           "label": "systematic-debugging", "cat": "Plan & build",     "aliases": ["systematic-debugging"]},
    {"key": "impeccable",                     "label": "impeccable",           "cat": "Design",           "aliases": ["impeccable"]},
    {"key": "solo-review",                    "label": "solo-review",          "cat": "Review & verify",  "aliases": ["solo-review"]},
    {"key": "panel-ultra-review",             "label": "panel-ultra-review",   "cat": "Review & verify",  "aliases": ["panel-ultra-review"]},
    {"key": "requesting-code-review",         "label": "code-review",          "cat": "Review & verify",  "aliases": ["requesting-code-review"]},
    {"key": "verification-before-completion", "label": "verify-before-done",   "cat": "Review & verify",  "aliases": ["verification-before-completion"]},
    {"key": "spar",                           "label": "spar",                 "cat": "Review & verify",  "aliases": ["spar"]},
    {"key": "probe",                          "label": "probe",                "cat": "Review & verify",  "aliases": ["probe"]},
    {"key": "tune",                           "label": "tune",                 "cat": "Review & verify",  "aliases": ["tune"]},
    {"key": "grill-me",                       "label": "grill-me",             "cat": "Review & verify",  "aliases": ["grill-me", "grill"]},
    {"key": "tech-debt-audit",                "label": "tech-debt-audit",      "cat": "Audit",            "aliases": ["tech-debt-audit"]},
    {"key": "executing-plans",                "label": "executing-plans",      "cat": "Plan & build",     "aliases": ["executing-plans"]},
]

_SKILL_VAL_RE = re.compile(r'"skill"\s*:\s*"([^"]+)"')                      # Skill tool: {"skill":"spar"}
_SKILL_CMD_RE = re.compile(r'<command-name>\s*/?\s*([^<]+?)\s*</command-name>')  # slash command
# A Workflow dispatch (spar/tune/probe/...) embeds its whole script -- incl. the required
# `export const meta = {name: '<skill>', ...}` header -- as an escaped string inside the parent
# session's OWN tool_use line (Douglas 2026-07-08: confirmed live, e.g. "name: 'spar'" found on a
# real transcript line that also carries a "cwd"). No separate file discovery needed for this case;
# the parent .jsonl is already scanned, it just needed a marker for the JS-literal shape.
_SKILL_WF_RE  = re.compile(r"export const meta\s*=\s*\{.{0,120}?name:\s*'([^']+)'")
_SKILL_CWD_RE = re.compile(r'"cwd"\s*:\s*"((?:[^"\\]|\\.)*)"')             # per-line cwd (JSON-escaped)
_SKILL_TS_RE  = re.compile(r'"timestamp"\s*:\s*"([^"]+)"')


def _match_skill_key(raw):
    """Map one raw invoked-skill / slash-command name to a master-list key, or None. `impeccable`
    matches any impeccable:* subcommand (substring); everything else matches its full name or its
    bare tail after a namespace prefix (so "superpowers:brainstorming" -> brainstorming)."""
    s = (raw or "").strip().lower()
    if not s:
        return None
    if "impeccable" in s:
        return "impeccable"
    base = s.split(":")[-1]
    for entry in SKILL_MASTER:
        if entry["key"] == "impeccable":
            continue
        for a in entry["aliases"]:
            if s == a or base == a:
                return entry["key"]
    return None


def _root_for_cwd(cwd, roots):
    """The DEEPEST known root that contains `cwd` (longest matching prefix), or None. Deepest so a
    cwd inside ai-for-cad/cad-forge attributes to cad-forge itself rather than its parent folder."""
    if not cwd:
        return None
    cwd_n = os.path.normcase(os.path.normpath(cwd))
    best = None
    for r in roots:
        rn = os.path.normcase(os.path.normpath(r))
        if cwd_n == rn or cwd_n.startswith(rn + os.sep):
            if best is None or len(rn) > len(best[1]):
                best = (r, rn)
    return best[0] if best else None


_ROOT_ATTR_CACHE = {}  # per-transcript cache keyed by (path, mtime), same pattern as _SESSION_META_CACHE


def _dominant_root_for_transcript(path, roots, max_lines=20000):
    """The KNOWN project root most referenced by this transcript's OWN cwd lines, tallied across the
    whole file rather than just the first line seen (Douglas 2026-07-08: a session launched from an
    umbrella folder but whose real work concentrated in a subfolder was attributed to the umbrella
    forever, since the session-folder logic only ever looked at its first cwd). Returns None if no
    line's cwd matched any known root at all -- a genuinely top-level session with zero subfolder
    signal keeps its original frozen-cwd folder rather than being forced onto some unrelated root."""
    counts = {}
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for i, line in enumerate(f):
                if i >= max_lines:
                    break
                if '"cwd"' not in line:
                    continue
                m = _SKILL_CWD_RE.search(line)
                if not m:
                    continue
                cwd = m.group(1).replace('\\\\', '\\').replace('\\"', '"')
                root = _root_for_cwd(cwd, roots)
                if root:
                    counts[root] = counts.get(root, 0) + 1
    except OSError:
        return None
    if not counts:
        return None
    return max(counts.items(), key=lambda kv: kv[1])[0]


def _dominant_root_cached(path, mtime, roots):
    ent = _ROOT_ATTR_CACHE.get(path)
    if ent and ent[0] == mtime and ent[2] == roots:
        return ent[1]
    result = _dominant_root_for_transcript(path, roots)
    _ROOT_ATTR_CACHE[path] = (mtime, result, roots)
    return result


def _scan_transcript_skills(path, roots):
    """Scan ONE transcript for master-list skill invocations, each attributed to the deepest known
    root of the cwd on its line (falling back to the file's dominant root for a line with no cwd).
    Returns {"mtime": m, "agg": {root: {key: {"count": n, "lastTs": iso-or-None}}}} - or None if the
    file vanished. Only lines actually containing a skill/command marker are parsed, so a huge
    transcript costs a cheap substring test per line and a regex only on the few real hits."""
    try:
        mtime = os.path.getmtime(path)
    except OSError:
        return None
    hits, cwds_seen = [], []
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                has_skill = '"skill"' in line
                has_cmd = '<command-name>' in line
                has_wf = 'export const meta' in line
                if not (has_skill or has_cmd or has_wf):
                    continue
                cwd = None
                mcwd = _SKILL_CWD_RE.search(line)
                if mcwd:
                    cwd = mcwd.group(1).replace('\\\\', '\\').replace('\\"', '"')
                    cwds_seen.append(cwd)
                mts = _SKILL_TS_RE.search(line)
                ts = mts.group(1) if mts else None
                raws = (_SKILL_VAL_RE.findall(line) if has_skill else []) + \
                       (_SKILL_CMD_RE.findall(line) if has_cmd else []) + \
                       (_SKILL_WF_RE.findall(line) if has_wf else [])
                for raw in raws:
                    key = _match_skill_key(raw)
                    if key:
                        hits.append((cwd, key, ts))
    except OSError:
        return {"mtime": mtime, "agg": {}}
    if not hits:
        return {"mtime": mtime, "agg": {}}
    file_root = None  # deepest known root across every cwd seen, for lines that carried none
    for cwd in cwds_seen:
        r = _root_for_cwd(cwd, roots)
        if r and (file_root is None or len(r) > len(file_root)):
            file_root = r
    agg = {}
    for cwd, key, ts in hits:
        root = (_root_for_cwd(cwd, roots) if cwd else None) or file_root
        if not root:
            continue
        d = agg.setdefault(root, {}).setdefault(key, {"count": 0, "lastTs": None})
        d["count"] += 1
        if ts and (d["lastTs"] is None or ts > d["lastTs"]):
            d["lastTs"] = ts
    return {"mtime": mtime, "agg": agg}


def load_skills_cache():
    """Per-transcript scan cache {"sig": roots-signature, "files": {path: scan-result}}. A missing
    or corrupt file just means "nothing cached yet"; a roots change invalidates the whole cache so
    no file keeps a stale root attribution."""
    try:
        with open(SKILLS_CACHE_FILE, encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def save_skills_cache(cache):
    """Write atomically (unique temp file + os.replace) so a concurrent writer can never see or
    produce a half-written cache: each writer serializes to its own temp path, then the rename swaps
    it in as one indivisible step."""
    tmp = SKILLS_CACHE_FILE + ".tmp." + str(threading.get_ident())
    try:
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(cache, f)
        os.replace(tmp, SKILLS_CACHE_FILE)
    except OSError:
        try:
            os.remove(tmp)
        except OSError:
            pass


def project_skills_coverage(roots=None):
    """Which master-list skills have been run on each known project, aggregated across ALL of that
    project's session transcripts. Incremental: only transcripts whose mtime changed since the last
    call are re-scanned (the rest reuse the disk cache), so the steady-state cost is one poll's worth
    of the single growing active transcript while the ~2 GB corpus is read once and then served warm. Returns
    {"master": [{key,label,cat}], "projects": [{root, skills: {key: {count,lastTs}}}]} - only
    projects with at least one tracked skill run appear, most-active first."""
    roots = roots if roots is not None else load_roots()
    sig = "|".join(roots)
    with _SKILLS_LOCK:  # serialize scan+save across concurrent /api/skills requests (see the lock's comment)
        raw = load_skills_cache()
        cache = raw.get("files", {}) if raw.get("sig") == sig else {}
        seen, changed = set(), (raw.get("sig") != sig)
        if os.path.isdir(PROJECTS_DIR):
            to_scan = []  # cache-miss transcripts, in the SAME nested order the serial walk visits them
            for project_dir in glob.glob(os.path.join(PROJECTS_DIR, "*")):
                if not os.path.isdir(project_dir):
                    continue
                # Recursive (Douglas 2026-07-08): a flat "*.jsonl" only sees each session's own
                # top-level transcript. It never saw a nested subagent transcript (e.g. solo-review
                # dispatched inside a Workflow's own subagents/workflows/wf_*/agent-*.jsonl), so those
                # skill runs were structurally invisible no matter how fresh the cache was.
                for path in glob.glob(os.path.join(project_dir, "**", "*.jsonl"), recursive=True):
                    seen.add(path)
                    try:
                        mtime = os.path.getmtime(path)
                    except OSError:
                        continue
                    ent = cache.get(path)
                    if ent and ent.get("mtime") == mtime:
                        continue
                    to_scan.append(path)
            # A big cold miss -> process pool (threads wouldn't help; this is GIL-bound line scanning).
            # Results are applied in the SAME path order as the serial walk, so the aggregated output is
            # byte-identical either way. Any pool failure (spawn/pickle/OS) falls back to the serial scan.
            if len(to_scan) > _SKILLS_PARALLEL_THRESHOLD:
                results = None
                try:
                    workers = min(8, (os.cpu_count() or 2))
                    with concurrent.futures.ProcessPoolExecutor(max_workers=workers) as ex:
                        results = list(ex.map(_scan_transcript_skills, to_scan, itertools.repeat(roots)))
                except Exception:
                    results = None
                if results is not None:
                    for path, scanned in zip(to_scan, results):
                        if scanned is not None:
                            cache[path] = scanned
                            changed = True
                    to_scan = []  # handled in parallel; skip the serial pass below
            for path in to_scan:
                scanned = _scan_transcript_skills(path, roots)
                if scanned is not None:
                    cache[path] = scanned
                    changed = True
            # Prune vanished transcripts ONLY inside the walked-the-dir branch: a transient
            # isdir()==False (dir momentarily absent/locked) would otherwise leave `seen` empty and
            # delete every cached entry, forcing a needless full re-scan of the whole corpus next time.
            for gone in [p for p in list(cache) if p not in seen]:
                del cache[gone]
                changed = True
        if changed:
            save_skills_cache({"sig": sig, "files": cache})
    by_root = {}
    for ent in cache.values():
        for root, skills in (ent.get("agg") or {}).items():
            rd = by_root.setdefault(root, {})
            for key, info in skills.items():
                cur = rd.setdefault(key, {"count": 0, "lastTs": None})
                cur["count"] += info.get("count", 0)
                lt = info.get("lastTs")
                if lt and (cur["lastTs"] is None or lt > cur["lastTs"]):
                    cur["lastTs"] = lt
    projects = [{"root": root, "skills": by_root[root]} for root in roots if by_root.get(root)]
    projects.sort(key=lambda p: sum(s["count"] for s in p["skills"].values()), reverse=True)
    master = [{"key": e["key"], "label": e["label"], "cat": e["cat"]} for e in SKILL_MASTER]
    return {"master": master, "projects": projects}


def collect_all():
    out = []
    for root in load_roots():
        if not os.path.isdir(root):
            continue
        try:
            lr = collect_longrun(root)
        except Exception as e:
            out.append({"kind": "error", "root": root, "error": "%s: %s" % (type(e).__name__, e)})
            continue
        if lr:
            out.append(lr)
            continue
        try:
            pr = collect_plain_status(root)
        except Exception as e:
            out.append({"kind": "error", "root": root, "error": "%s: %s" % (type(e).__name__, e)})
            continue
        if pr:
            out.append(pr)
    # Post-pass: a plain-file project card can describe the SAME underlying project as an
    # active longrun card elsewhere (found live 2026-07-02: sme-tacit-frames appeared both as
    # the live a5056bdb longrun card AND as its own stale plain-project card reading
    # sme-tacit-frames/WORK_QUEUE.md directly). Cross-reference so a viewer isn't left thinking
    # these are two independent threads of work.
    longrun_cards = [c for c in out if c.get("kind") == "longrun"]
    for c in out:
        if c.get("kind") == "project":
            # This pass ran OUTSIDE any try/except (2026-07-03 solo-review, HIGH) - a single bad
            # path could 500 the whole /api/longruns response instead of just this one card,
            # reintroducing exactly the single-point-of-failure the per-root isolation above
            # exists to prevent.
            try:
                c["relatedLongrunRoot"] = find_cross_reference(c["root"], longrun_cards)
            except Exception:
                c["relatedLongrunRoot"] = None
    return out


PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>longrun dashboard</title>
<style>
  :root{
    /* Neutral near-black palette (Douglas 2026-07-07: "make the background a type of black, not blue").
       The surfaces are true dark greys with no blue cast; the semantic accents (active/blocked/...) stay. */
    --bg:#0b0b0d; --panel:#151517; --line:#2a2a2e; --ink:#e7e7ea; --muted:#9b9ba3; --well:#101012;
    --active:#45a872; --continuing:#4f8fe0; --blocked:#e07470; --idle:#9b9ba3; --finished:#a681f8; --stalled:#d99a2b;
    /* Fixed rem type scale (impeccable typeset pass, 2026-07-06) - product-register guidance calls
       for a fixed scale over fluid clamp() in app UI, since Douglas views this at one consistent DPI
       on his own machine; a shrinking h1 helps nobody here. Named by role, not by pixel value, so a
       future rebalance changes one line instead of hunting every literal em/px scattered through the
       file (the previous state: 0.72/0.75/0.78/0.8/0.82/0.85/0.88/0.9/0.95em all in play at once,
       none of them meaningfully distinguishable from its neighbors). */
    --text-3xs:0.6875rem; /* 11px - tiny corner tags/badges (session tag, message action, kind tag) */
    --text-2xs:0.75rem;  /* 12px - badges, uppercase eyebrow labels, footnotes */
    --text-xs:0.8125rem; /* 13px - buttons, summaries, secondary detail text */
    --text-sm:0.875rem;  /* 14px - primary in-card UI text: counts, current item, results */
    --text-md:1.125rem;  /* 18px - card headings */
    --text-lg:1.5rem;    /* 24px - the page's one h1 */
    /* A single monospace family for EVERY element used to read as "terminal script" rather than an
       app (Douglas, 2026-07-06: "the font... looks too pirated"). UI chrome (headings, labels, body
       copy, buttons) now uses a native system sans; --font-mono is reserved for genuinely code/data
       content (paths, ports, log/transcript text) via the `code`/`pre` element selectors and the two
       classes below, which is the actual professional-app convention (Linear/Notion/Stripe all draw
       this same line). System fonts load instantly and need no @font-face/layout-shift handling. */
    --font-ui:"Segoe UI Variable Text","Segoe UI",-apple-system,BlinkMacSystemFont,Roboto,"Helvetica Neue",Arial,sans-serif;
    --font-mono:ui-monospace,SFMono-Regular,Consolas,monospace;
    --ease-out-quart:cubic-bezier(0.25,1,0.5,1);
  }
  *{box-sizing:border-box;}
  @media (prefers-reduced-motion: reduce){ *{transition:none !important; animation:none !important;} }
  /* Themed scrollbars (Douglas 2026-07-08: "make the scroll bars look better and have more consistent
     colors") -- every scrollable region (Kanban row, Servers/Discovered lists, pre/code blocks, the
     page itself) gets the SAME neutral thumb-on-well styling instead of the OS default, which reads
     jarring against this near-black theme. CSS only; no scrollable region's own content changes. */
  *{scrollbar-width:thin;scrollbar-color:var(--line) var(--well);}
  ::-webkit-scrollbar{width:10px;height:10px;}
  ::-webkit-scrollbar-track{background:var(--well);}
  ::-webkit-scrollbar-thumb{background:var(--line);border-radius:6px;border:2px solid var(--well);}
  ::-webkit-scrollbar-thumb:hover{background:var(--muted);}
  button:focus-visible, a:focus-visible, summary:focus-visible{outline:2px solid var(--continuing);outline-offset:2px;}
  body{margin:0;background:var(--bg);color:var(--ink);font-family:var(--font-ui);font-size:1rem;line-height:1.55;}
  code,pre{font-family:var(--font-mono);}
  h1{font-size:var(--text-lg);font-weight:700;letter-spacing:-0.01em;margin:0 0 6px;}
  /* Vertical icon-tab layout (Douglas 2026-07-07: "add a vertical tab layout on the side, just logos").
     A sticky left rail of icon-only tabs; the main column holds one tab panel at a time. */
  .app{display:flex;align-items:stretch;min-height:100vh;}
  .tabrail{flex:0 0 auto;display:flex;flex-direction:column;gap:8px;padding:16px 10px;background:var(--panel);
    border-right:1px solid var(--line);position:sticky;top:0;height:100vh;}
  .tab-btn{width:42px;height:42px;display:inline-flex;align-items:center;justify-content:center;border:1px solid transparent;
    border-radius:10px;background:none;color:var(--muted);cursor:pointer;transition:background 0.15s ease,color 0.15s ease,border-color 0.15s ease;}
  .tab-btn:hover{color:var(--ink);background:var(--well);}
  .tab-btn[aria-selected="true"]{color:var(--ink);background:var(--well);border-color:var(--line);}
  .tabmain{flex:1 1 auto;min-width:0;max-width:1360px;margin:0 auto;padding:22px 28px 36px;width:100%;}
  .apphdr{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;margin-bottom:18px;}
  .tabpanel[hidden]{display:none;}
  .help{position:relative;}
  .help > summary{list-style:none;cursor:pointer;width:26px;height:26px;border-radius:50%;border:1px solid var(--line);
    color:var(--muted);display:inline-flex;align-items:center;justify-content:center;font-size:var(--text-sm);font-weight:700;}
  .help > summary::-webkit-details-marker{display:none;}
  .help > summary:hover{color:var(--ink);border-color:var(--continuing);}
  .help-body{position:absolute;right:0;top:32px;width:330px;background:var(--panel);border:1px solid var(--line);
    border-radius:8px;padding:12px 14px;font-size:var(--text-xs);color:var(--muted);line-height:1.5;z-index:20;
    box-shadow:0 10px 30px rgba(0,0,0,0.55);}
  .help-body code{color:var(--ink);}
  @media (max-width:700px){
    .app{flex-direction:column;}
    .tabrail{flex-direction:row;height:auto;position:static;border-right:none;border-bottom:1px solid var(--line);}
  }
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(420px,100%),1fr));gap:20px;}
  .toolbar{display:flex;align-items:center;gap:16px;flex-wrap:wrap;margin-bottom:16px;color:var(--muted);font-size:var(--text-xs);}
  .toolbar label{display:flex;align-items:center;gap:6px;cursor:pointer;user-select:none;}
  .toolbar input[type="checkbox"]{accent-color:var(--continuing);}
  .toolbar-sep{color:var(--muted);opacity:0.7;}
  .col-toggle-group{display:flex;gap:6px;flex-wrap:wrap;}
  .col-toggle-btn{display:inline-flex;align-items:center;gap:6px;font-family:inherit;font-size:var(--text-xs);
    cursor:pointer;border-radius:999px;padding:5px 12px 5px 14px;border:1px solid var(--line);
    background:var(--panel);color:var(--muted);transition:background 0.15s ease,border-color 0.15s ease,color 0.15s ease;}
  .col-toggle-btn:hover{border-color:var(--continuing);color:var(--ink);}
  .col-toggle-btn .col-toggle-count{font-variant-numeric:tabular-nums;font-size:var(--text-2xs);padding:0 6px;
    border-radius:999px;background:var(--well);color:var(--muted);}
  /* Pressed = column visible (the default): a filled, ink-colored pill so "on" reads as present,
     not as an alert color -- this is a filter, not a warning. Unpressed = column hidden: outline-only,
     dimmed, so it reads as "off" at a glance without a checkbox's tiny tick mark to squint at. */
  .col-toggle-btn[aria-pressed="true"]{background:rgba(139,160,191,0.14);border-color:var(--line);color:var(--ink);}
  .col-toggle-btn[aria-pressed="true"] .col-toggle-count{background:var(--panel);color:var(--ink);}
  .col-toggle-btn[aria-pressed="false"]{opacity:0.55;}
  .kanban{display:flex;gap:16px;align-items:flex-start;overflow-x:auto;padding-bottom:4px;}
  .kcol{flex:1 1 300px;min-width:260px;max-width:340px;background:var(--well);border:1px solid var(--line);
    border-radius:8px;padding:12px;}
  .kcol.col-hidden{display:none;}
  .kcol-header{display:flex;align-items:center;justify-content:space-between;margin:0 4px 10px;
    font-size:var(--text-2xs);font-weight:600;color:var(--muted);text-transform:uppercase;letter-spacing:0.04em;}
  .kcol-header .kcount{background:var(--panel);border-radius:10px;padding:1px 8px;font-size:var(--text-xs);
    text-transform:none;letter-spacing:normal;color:var(--ink);font-variant-numeric:tabular-nums;}
  .kcol-body{display:flex;flex-direction:column;gap:14px;min-height:40px;}
  .kcol-body .empty{grid-column:auto;font-size:var(--text-xs);padding:4px 2px;}
  @media (max-width:900px){
    .kanban{flex-direction:column;overflow-x:visible;}
    .kcol{max-width:none;width:100%;}
  }
  /* Top-right corner of the card (2026-07-06, Douglas: "that archive button should be in the top
     right or maybe on the card"; 2026-07-07: "turn that into an icon") -- .card is the positioning
     context (position:relative above), so it reads as a corner action distinct from the summary line;
     the summary reserves space for it via its padding-right. */
  .archive-btn{background:none;border:1px solid var(--line);color:var(--muted);border-radius:6px;
    padding:3px 4px;cursor:pointer;font-family:inherit;position:absolute;top:14px;right:16px;
    display:inline-flex;align-items:center;justify-content:center;line-height:0;z-index:1;}
  .archive-btn:hover{border-color:var(--stalled);color:var(--stalled);}
  .archive-btn svg{display:block;}
  /* Compact/expandable card (2026-07-07, Douglas: "take each card to make it smaller. When I click
     on it once, it expands to what you have it now"). The card is a <details>; its <summary> is the
     collapsed ~1/3-height view (folder name, status, current item, done/open) and the full detail
     lives in .cbody, revealed on click. morphNode skips the `open` attr on every <details>, so a
     card the user expanded stays expanded across every 6s poll. */
  .card > summary.csum{list-style:none;cursor:pointer;display:flex;flex-wrap:wrap;align-items:center;
    gap:7px 10px;padding-right:34px;}
  .card > summary.csum::-webkit-details-marker{display:none;}
  .card > summary.csum::before{content:"";width:6px;height:6px;border-right:2px solid var(--muted);
    border-bottom:2px solid var(--muted);transform:rotate(-45deg);flex-shrink:0;margin-right:1px;
    transition:transform 0.18s var(--ease-out-quart);}
  .card[open] > summary.csum::before{transform:rotate(45deg);}
  .cname{font-size:var(--text-md);font-weight:700;color:var(--ink);overflow-wrap:anywhere;}
  .cmeta{display:flex;gap:12px;margin-left:auto;font-size:var(--text-sm);color:var(--muted);
    flex-shrink:0;font-variant-numeric:tabular-nums;}
  .cmeta b{color:var(--ink);}
  .ccur{flex-basis:100%;color:var(--muted);font-size:var(--text-sm);overflow:hidden;
    text-overflow:ellipsis;white-space:nowrap;max-width:100%;padding-left:13px;}
  .ccur:empty{display:none;}
  .cbody{margin-top:14px;}
  /* A live session is a board card too (Douglas 2026-07-07). A small muted tag marks it apart from a
     project card at a glance, and its Message action sits in the corner where a project card's archive
     icon would. The recessed background is the extra cue that a session card isn't a project card. */
  /* Session cards are deliberately smaller + denser than project cards (Douglas 2026-07-07: "smaller
     title text... make the cards smaller... more fits in less space"). Tighter padding, a small-caps
     title, and 2xs meta/current lines. */
  .scard{background:var(--well);padding:10px 12px;}
  .scard > summary.csum{padding-right:50px;gap:5px 7px;}
  /* Clamp the session title to 2 lines so cards stay short (Douglas: "smaller title... more in less space"). */
  .scard .cname{font-size:var(--text-sm);font-weight:600;line-height:1.3;flex-basis:100%;
    display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;}
  .scard .cmeta{font-size:var(--text-2xs);gap:8px;}
  .scard .ccur{font-size:var(--text-2xs);padding-left:11px;}
  .scard .sfolder{color:var(--muted);}
  .scard .stimer{font-variant-numeric:tabular-nums;color:var(--continuing);}
  .scard .cbody{margin-top:10px;}
  .scard-tag{font-size:var(--text-3xs);text-transform:uppercase;letter-spacing:0.05em;color:var(--muted);
    border:1px solid var(--line);border-radius:999px;padding:1px 6px;flex-shrink:0;}
  .scard-msg{position:absolute;top:10px;right:12px;background:none;border:1px solid var(--line);
    color:var(--muted);border-radius:6px;padding:1px 7px;font-size:var(--text-3xs);cursor:pointer;
    font-family:inherit;z-index:1;}
  .scard-msg:hover{border-color:var(--continuing);color:var(--ink);}
  /* kind tag for project cards: a longrun card carries a "longrun" mark to set it apart from passive
     watcher/plain-build cards (Douglas 2026-07-07: "a longrun tag to distinguish from watchers"). */
  .ktag{font-size:var(--text-3xs);text-transform:uppercase;letter-spacing:0.05em;border-radius:999px;padding:1px 7px;flex-shrink:0;}
  .ktag.longrun{color:var(--active);border:1px solid rgba(69,168,114,0.5);}
  .ktag.watcher{color:var(--muted);border:1px solid var(--line);}
  .sessions-note{color:var(--muted);font-size:var(--text-2xs);}
  .archived-row{display:flex;align-items:center;gap:10px;padding:6px 0;border-bottom:1px solid var(--line);font-size:var(--text-xs);}
  .archived-row:last-child{border-bottom:none;}
  .archived-row .aname{flex:1;min-width:140px;}
  .archived-row button{background:var(--panel);border:1px solid var(--line);color:var(--ink);
    border-radius:6px;padding:4px 12px;cursor:pointer;font-family:inherit;}
  .archived-row button:hover{border-color:var(--continuing);}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:8px;padding:18px 20px;position:relative;
    transition:opacity 0.2s ease, transform 0.2s var(--ease-out-quart);}
  /* Exit feedback for archiving (or any other reason a card leaves the board) - a beat of fade+shrink
     instead of the card just vanishing. animateOutAndRemove (JS) adds this class, then removes the
     node once the transition ends (or a fallback timeout under reduced-motion, where transitions are
     globally disabled by the rule at the top of this stylesheet). */
  .card.card-exiting{ opacity:0; transform:scale(0.97); }
  .badge{display:inline-block;padding:2px 9px;border-radius:12px;font-size:var(--text-2xs);font-weight:600;
    text-transform:uppercase;letter-spacing:0.03em;}
  .badge.active,.badge.continuing{background:rgba(69,168,114,0.16);color:var(--active);}
  .badge.blocked,.badge.stopped{background:rgba(224,116,112,0.16);color:var(--blocked);}
  .badge.idle,.badge.unknown,.badge.dormant{background:rgba(139,160,191,0.16);color:var(--idle);}
  .badge.finished{background:rgba(166,129,248,0.16);color:var(--finished);}
  .badge.stalled{background:rgba(217,154,43,0.18);color:var(--stalled);}
  .conflict-note{border:1px solid var(--stalled);border-radius:8px;background:rgba(217,154,43,0.08);
    color:var(--stalled);font-size:var(--text-xs);padding:8px 10px;margin:8px 0;overflow-wrap:anywhere;}
  .xref-note{border:1px solid var(--line);border-radius:8px;background:rgba(139,160,191,0.08);
    color:var(--muted);font-size:var(--text-xs);padding:8px 10px;margin:8px 0;overflow-wrap:anywhere;}
  .servers-split{display:flex;gap:20px;align-items:flex-start;margin-bottom:20px;}
  .servers-split .servers{flex:1 1 50%;min-width:0;margin-bottom:0;}
  /* Discovered-processes list is capped to the same height as the Servers list and scrolls past that
     (Douglas 2026-07-07: "only as long as the servers section... make it scrollable"). */
  .servers-split .servers > div{max-height:56vh;overflow-y:auto;overscroll-behavior:contain;}
  @media (max-width:900px){ .servers-split{flex-direction:column;} }
  .mem-stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:18px;}
  .mem-stat{background:var(--well);border:1px solid var(--line);border-radius:8px;padding:10px 14px;cursor:help;}
  .mem-stat .mem-stat-label{font-size:var(--text-2xs);text-transform:uppercase;letter-spacing:0.05em;color:var(--muted);}
  .mem-stat .mem-stat-value{font-size:var(--text-md);font-weight:700;margin-top:2px;}
  .mem-stat.warn .mem-stat-value{color:var(--stalled);}
  .mem-stat.critical .mem-stat-value{color:var(--blocked);}
  .mem-trend-growing{color:var(--blocked);}
  .mem-trend-dropping{color:var(--active);}
  .mem-trend-flat,.mem-trend-unknown{color:var(--muted);}
  .mem-buckets{margin-bottom:18px;}
  .mem-bucket-row{display:flex;align-items:center;gap:10px;padding:6px 0 0;font-size:var(--text-sm);}
  .mem-bucket-row .mem-bucket-label{flex:1 1 auto;}
  .mem-bucket-row .mem-bucket-count{color:var(--muted);font-size:var(--text-2xs);}
  .mem-bucket-names{padding:2px 0 8px;margin-bottom:2px;border-bottom:1px solid var(--line);font-size:var(--text-2xs);color:var(--muted);}
  .mem-top table{width:100%;border-collapse:collapse;font-size:var(--text-sm);}
  .mem-top td,.mem-top th{padding:4px 8px;text-align:left;border-bottom:1px solid var(--line);}
  .mem-top th{color:var(--muted);font-size:var(--text-2xs);text-transform:uppercase;letter-spacing:0.05em;font-weight:600;}
  .mem-tag{display:inline-block;padding:1px 7px;border-radius:10px;font-size:var(--text-2xs);font-weight:600;background:rgba(155,155,163,0.16);color:var(--muted);white-space:nowrap;}
  .header-strip{font-size:var(--text-2xs);color:var(--muted);margin-top:4px;display:flex;gap:14px;flex-wrap:wrap;}
  .header-strip .hs-crit{color:var(--blocked);}
  .header-strip .hs-warn{color:var(--stalled);}
  .servers{margin-bottom:14px;}
  .servers + .servers{margin-bottom:32px;}
  .servers summary{cursor:pointer;color:var(--ink);font-weight:600;margin-bottom:10px;}
  .srow{display:flex;align-items:center;gap:10px;padding:6px 0;border-bottom:1px solid var(--line);font-size:var(--text-xs);}
  .srow:last-child{border-bottom:none;}
  .srow .sname{flex:1;min-width:140px;}
  .srow .sport{color:var(--muted);font-family:var(--font-mono);}
  .srow .smem{color:var(--muted);font-size:var(--text-xs);min-width:52px;}
  .sctx,.scost{font-family:var(--font-mono);font-size:var(--text-2xs);color:var(--muted);
    background:var(--panel);border-radius:4px;padding:1px 6px;}
  .sctx{color:var(--continuing);}
  .sdetail{padding:6px 0 8px 8px;border-left:1px solid var(--line);margin:2px 0 6px 4px;}
  .sevent{font-size:var(--text-2xs);color:var(--ink);padding:2px 0;overflow-wrap:anywhere;}
  .sevent .sek{display:inline-block;min-width:56px;color:var(--muted);text-transform:uppercase;letter-spacing:0.04em;font-size:var(--text-2xs);}
  .sevent .sek.tool{color:var(--continuing);}
  .sevent .sek.user{color:var(--active);}
  .srow button{background:var(--panel);border:1px solid var(--line);color:var(--ink);
    border-radius:6px;padding:4px 12px;cursor:pointer;font-family:inherit;}
  .srow button:hover{border-color:var(--continuing);}
  .srow button:disabled{opacity:0.5;cursor:default;}
  .srow button.stop:hover{border-color:var(--blocked);}
  /* --shim drives the in-flight shimmer sweep; registering it as an animatable @property lets a
     plain CSS animation interpolate the gradient position smoothly (a raw custom prop animates as
     a discrete step, not a sweep). Optimistic-controls overdrive pass. */
  @property --shim{ syntax:"<percentage>"; inherits:false; initial-value:0%; }
  .srow{position:relative;}
  /* The shimmer rides an ::after overlay so it never repaints the row's real text/controls, and
     it is pointer-events:none so it can't intercept a click on the button underneath. */
  .srow.inflight::after{
    content:"";position:absolute;inset:0;border-radius:6px;pointer-events:none;
    background:linear-gradient(100deg,
      transparent calc(var(--shim) - 22%),
      rgba(139,160,191,0.14) var(--shim),
      transparent calc(var(--shim) + 22%));
    animation:srow-shimmer 1.15s linear infinite;
  }
  @keyframes srow-shimmer{ from{--shim:-10%;} to{--shim:110%;} }
  /* Reduced-motion: no sweep. A quiet static tint still marks the row as busy so the state is
     never hidden from a viewer who has motion turned off (honesty-over-polish, per PRODUCT.md). */
  @media (prefers-reduced-motion: reduce){
    .srow.inflight::after{ animation:none; background:rgba(139,160,191,0.08); }
  }
  /* The optimistic badge swap springs its scale; the actual damped-spring keyframes are applied
     per-element via the Web Animations API (JS), so nothing here needs to hardcode the curve. */
  .srow .action-result{font-size:var(--text-sm);}
  /* @starting-style entry: the result text starts faded + nudged, then settles, so a real backend
     result arrives with a clean transition instead of a hard pop-in. */
  .srow .action-result.shown{
    opacity:1;transform:translateX(0);
    transition:opacity 0.28s ease, transform 0.28s cubic-bezier(0.22,1,0.36,1);
  }
  @starting-style{
    .srow .action-result.shown{ opacity:0;transform:translateX(-6px); }
  }
  .srow a.open-link{color:var(--continuing);text-decoration:none;font-size:var(--text-sm);}
  .srow a.open-link:hover{text-decoration:underline;}
  .card.flag-stalled{border-color:var(--stalled);}
  /* Status-flip pulse (diff-aware-updates overdrive pass). When a card's STATUS actually changes
     (continuing -> blocked, active -> stalled, anything -> finished), reconcileCards adds
     .status-flip and sets --pulse-target to the NEW status's color. --pulse-target is an @property-
     registered <color> custom property; the keyframes animate border-color base -> --pulse-target ->
     base, so the border swells to the new status color and settles back exactly once. Registering it
     as a typed <color> is what lets the keyframe interpolate the color smoothly rather than stepping.
     One restrained single-shot; the class is stripped on animationend (and, under reduced-motion
     where no animationend fires, by a JS timeout) so a later flip fires it again. Verified rendering
     in a real headless browser (pixel-sampled): a bare number-driven color-mix approach did NOT
     animate here, animating border-color directly does. */
  @property --pulse-target{ syntax:"<color>"; inherits:false; initial-value:transparent; }
  .card.status-flip{
    --pulse-target:var(--line);
    animation:card-status-pulse 0.9s ease-out 1;
  }
  @keyframes card-status-pulse{
    0%{ border-color:var(--line); }
    35%{ border-color:var(--pulse-target); }
    100%{ border-color:var(--line); }
  }
  /* Reduced motion: no animated swell. The flip still reads — the border snaps to the new status
     color for a beat (a plain, non-animated swap), honesty-over-polish per PRODUCT.md — but nothing
     moves or interpolates. The JS timeout in pulseStatusFlip strips the class afterward since no
     animationend event fires when animation is none. */
  @media (prefers-reduced-motion: reduce){
    .card.status-flip{ animation:none; border-color:var(--pulse-target); }
  }
  .detail{color:var(--muted);font-size:var(--text-sm);margin:4px 0 14px;overflow-wrap:anywhere;}
  .detail .rootpath{display:block;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:100%;}
  .bar{height:6px;border-radius:3px;background:var(--well);overflow:hidden;margin:10px 0 6px;}
  .bar-fill{height:100%;background:var(--active);}
  .counts{display:flex;gap:14px;font-size:var(--text-sm);color:var(--muted);margin-bottom:10px;flex-wrap:wrap;}
  .counts b{color:var(--ink);font-variant-numeric:tabular-nums;}
  .current{background:var(--well);border-radius:5px;padding:8px 10px;font-size:var(--text-sm);margin-bottom:14px;overflow-wrap:anywhere;}
  .current .lab{color:var(--muted);font-size:var(--text-2xs);display:block;margin-bottom:3px;text-transform:uppercase;letter-spacing:0.04em;}
  .warn-chip{display:inline-block;padding:1px 7px;border-radius:3px;font-size:var(--text-2xs);margin-left:6px;}
  .warn-chip.warn{background:rgba(217,154,43,0.18);color:var(--stalled);}
  .warn-chip.critical{background:rgba(217,83,79,0.18);color:var(--blocked);}
  .files{font-size:var(--text-xs);color:var(--muted);margin:14px 0 8px;}
  .files div{word-break:break-all;margin-bottom:2px;font-family:var(--font-mono);}
  details{margin-top:8px;}
  .card > details:first-of-type{margin-top:16px;}
  summary{cursor:pointer;font-size:var(--text-xs);color:var(--muted);user-select:none;}
  summary:hover{color:var(--ink);}
  /* Every collapsed section (task board, output files, logs, servers/discovered panels, archived
     boards) is a click-to-reveal disclosure now more than ever after the distill pass -- the reveal
     deserves a real entrance instead of an instant pop-in. Reuses the SAME @starting-style technique
     already proven for .action-result.shown above (animate.md, 2026-07-06): only fires on a genuine
     display:none -> block transition (i.e. an actual user click), never on scroll or page load. */
  details > *:not(summary){
    transition:opacity 0.22s ease, transform 0.22s var(--ease-out-quart);
  }
  @starting-style{
    details[open] > *:not(summary){ opacity:0; transform:translateY(-4px); }
  }
  pre{white-space:pre-wrap;word-break:break-word;margin:6px 0 0;max-height:260px;overflow-y:auto;
    background:var(--well);border-radius:4px;padding:8px 10px;font-size:var(--text-xs);color:#d2d2d8;
    overscroll-behavior:contain;}
  .empty{color:var(--muted);font-style:italic;grid-column:1/-1;}
  .updated-at{color:var(--muted);font-size:var(--text-2xs);margin-bottom:24px;}
  /* Skills-run-per-project panel: one row per project, the 17 master skills as chips. A run skill
     reads as present (filled, ink); a not-run one recedes (outline, dimmed) -- the same present/absent
     visual language the column-toggle pills use, so "which have I run here" is legible at a glance. */
  #skills-list{display:flex;flex-direction:column;gap:12px;margin-top:4px;}
  .skillrow{border:1px solid var(--line);border-radius:8px;padding:10px 12px;background:var(--well);}
  .skillrow-head{display:flex;align-items:baseline;justify-content:space-between;gap:10px;margin-bottom:8px;}
  .skillproj{font-weight:600;font-size:var(--text-sm);color:var(--ink);}
  .skillcov{font-variant-numeric:tabular-nums;font-size:var(--text-2xs);color:var(--muted);
    background:var(--panel);border-radius:999px;padding:2px 9px;flex-shrink:0;}
  .skillchips{display:flex;flex-wrap:wrap;gap:6px;}
  .skillchip{display:inline-flex;align-items:center;gap:5px;font-size:var(--text-2xs);border-radius:999px;
    padding:3px 10px;border:1px solid var(--line);white-space:nowrap;}
  .skillchip.on{background:rgba(69,168,114,0.16);border-color:rgba(69,168,114,0.45);color:var(--ink);}
  .skillchip.on .skn{font-variant-numeric:tabular-nums;background:var(--active);color:#04140b;
    border-radius:999px;padding:0 6px;font-size:10px;font-weight:700;}
  .skillchip.off{opacity:0.4;color:var(--muted);}
</style>
</head>
<body>
<div class="app">
  <nav class="tabrail" role="tablist" aria-label="Views">
    <button class="tab-btn" data-tab="cards" role="tab" aria-selected="true" title="Cards &mdash; projects &amp; live sessions">
      <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><rect x="3" y="4" width="5" height="16" rx="1"/><rect x="9.5" y="4" width="5" height="11" rx="1"/><rect x="16" y="4" width="5" height="14" rx="1"/></svg>
    </button>
    <button class="tab-btn" data-tab="skills" role="tab" aria-selected="false" title="Skills watcher &mdash; which skills ran on each project">
      <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"><path d="M12 3.2l2.5 5.1 5.6.8-4.05 3.95.95 5.6L12 16.9 6.95 19.65l.95-5.6L3.85 9.1l5.6-.8z"/></svg>
    </button>
    <button class="tab-btn" data-tab="servers" role="tab" aria-selected="false" title="Servers &amp; processes">
      <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><rect x="3" y="4.5" width="18" height="6" rx="1.4"/><rect x="3" y="13.5" width="18" height="6" rx="1.4"/><circle cx="6.8" cy="7.5" r="0.95" fill="currentColor" stroke="none"/><circle cx="6.8" cy="16.5" r="0.95" fill="currentColor" stroke="none"/></svg>
    </button>
    <button class="tab-btn" data-tab="memory" role="tab" aria-selected="false" title="Memory &amp; usage">
      <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><rect x="4" y="3" width="16" height="18" rx="1.6"/><path d="M8 8h8M8 12h8M8 16h5"/></svg>
    </button>
  </nav>
  <main class="tabmain">
    <header class="apphdr">
      <div><h1>longrun dashboard</h1><div class="updated-at" id="updated"></div>
        <div class="header-strip" id="header-strip"></div>
      </div>
      <details class="help">
        <summary aria-label="What this dashboard is">?</summary>
        <div class="help-body">Real <code>/longrun</code> armed sessions (<code>.longrun</code> + ralph-loop), bounded
          background builds (plain STATUS/WORK_QUEUE files), and live Claude Code sessions &mdash; polled every few
          seconds, scroll preserved. The Servers tab can start/stop a known server; everything else is read-only.</div>
      </details>
    </header>
    <section class="tabpanel" data-panel="cards" role="tabpanel">
<div class="toolbar">
  <label><input type="checkbox" id="sort-by-date"> sort by most recent activity</label>
  <label><input type="checkbox" id="show-inactive"> show inactive (untouched &gt;1 day)</label>
  <span class="toolbar-sep">columns:</span>
  <div class="col-toggle-group">
    <button type="button" class="col-toggle-btn" data-col="needs-you" aria-pressed="true">Needs You <span class="col-toggle-count">0</span></button>
    <button type="button" class="col-toggle-btn" data-col="active" aria-pressed="true">Active <span class="col-toggle-count">0</span></button>
    <button type="button" class="col-toggle-btn" data-col="stalled" aria-pressed="true">Stalled <span class="col-toggle-count">0</span></button>
    <button type="button" class="col-toggle-btn" data-col="idle" aria-pressed="true">Idle <span class="col-toggle-count">0</span></button>
    <button type="button" class="col-toggle-btn" data-col="finished" aria-pressed="true">Finished <span class="col-toggle-count">0</span></button>
  </div>
  <span class="toolbar-sep">sessions:</span>
  <button type="button" id="broadcast-btn" title="Queue the same message to every currently-active session at once (an agent with ccd drains the queue)">Broadcast to active</button>
  <span class="action-result" id="broadcast-result"></span>
  <span id="sessions-note" class="sessions-note"></span>
</div>
<div class="kanban" id="cards">
  <div class="kcol" data-col="needs-you"><div class="kcol-header" title="Blocked on you (a .need-user sentinel, or the log line itself says so) or keep-going stopped for this session -- needs a decision."><span>Needs You</span><span class="kcount">0</span></div><div class="kcol-body"><p class="empty">loading...</p></div></div>
  <div class="kcol" data-col="active"><div class="kcol-header" title="A session is actively working right now -- forced to continue and the transcript has written within the last 5 minutes."><span>Active</span><span class="kcount">0</span></div><div class="kcol-body"><p class="empty">loading...</p></div></div>
  <div class="kcol" data-col="stalled"><div class="kcol-header" title="Keep-going said continue, but no transcript activity in a while -- may be wedged or waiting on something. Worth a look."><span>Stalled</span><span class="kcount">0</span></div><div class="kcol-body"><p class="empty">loading...</p></div></div>
  <div class="kcol" data-col="idle"><div class="kcol-header" title="Nothing is being forced right now -- dormant, unknown, or quietly idle. No action needed."><span>Idle</span><span class="kcount">0</span></div><div class="kcol-body"><p class="empty">loading...</p></div></div>
  <div class="kcol" data-col="finished"><div class="kcol-header" title="Checklist is fully checked off (or CURRENT-TASK says nothing remains) -- nothing left to do."><span>Finished</span><span class="kcount">0</span></div><div class="kcol-body"><p class="empty">loading...</p></div></div>
</div>
<details class="servers" id="archived-panel">
  <summary>Archived boards</summary>
  <div id="archived-list"><p class="empty">nothing archived</p></div>
</details>
    </section>

    <section class="tabpanel" data-panel="skills" id="skills-panel" role="tabpanel" hidden>
      <div id="skills-list"><p class="empty">loading...</p></div>
    </section>

    <section class="tabpanel" data-panel="servers" role="tabpanel" hidden>
      <div class="servers-split">
        <details class="servers" open>
          <summary>Servers &amp; dashboards</summary>
          <div id="servers-list"><p class="empty">loading...</p></div>
        </details>
        <details class="servers" open>
          <summary title="Listening ports not registered in any launch.json &mdash; read-only.">Discovered processes</summary>
          <div id="discovered-list"><p class="empty">loading...</p></div>
        </details>
      </div>
    </section>

    <section class="tabpanel" data-panel="memory" role="tabpanel" hidden>
      <div class="mem-stats" id="mem-stats"><p class="empty">loading...</p></div>
      <div class="mem-buckets" id="mem-buckets"></div>
      <div class="mem-top" id="mem-top"></div>
    </section>

    <footer style="margin-top:28px;padding-top:14px;border-top:1px solid var(--line);color:var(--muted);font-size:var(--text-2xs)">
      How to (re)start this dashboard by hand: <code id="run-cmd">loading…</code>
    </footer>
  </main>
</div>

<script>
document.getElementById('run-cmd').textContent =
  'python "C:/Users/dmcgowa2/.claude/tools/longrun-dashboard.py" --port ' + (window.location.port || '8756');
function fmtBytes(n){
  if(n == null) return '?';
  if(n > 1e6) return (n/1e6).toFixed(1) + ' MB';
  if(n > 1e3) return (n/1e3).toFixed(0) + ' KB';
  return n + ' B';
}
function fmtAge(ts){
  if(!ts) return '?';
  var s = Math.round(Date.now()/1000 - ts);
  if(s < 60) return s + 's ago';
  if(s < 3600) return Math.round(s/60) + 'm ago';
  if(s < 86400) return Math.round(s/3600) + 'h ago';
  return Math.round(s/86400) + 'd ago';
}
// A precise, live-ticking elapsed for a session's "time since last message" (Douglas 2026-07-07:
// "an actively updated thing"). Seconds resolution near the top so the timer visibly moves.
function fmtElapsed(ts){
  if(!ts) return '?';
  var s = Math.max(0, Math.round(Date.now()/1000 - ts));
  if(s < 60) return s + 's';
  if(s < 3600) return Math.floor(s/60) + 'm ' + (s%60) + 's';
  if(s < 86400) return Math.floor(s/3600) + 'h ' + Math.floor((s%3600)/60) + 'm';
  return Math.floor(s/86400) + 'd ' + Math.floor((s%86400)/3600) + 'h';
}
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
      '<div class="mem-stat' + (availCrit?' critical':availWarn?' warn':'') + '" title="(Total physical RAM &minus; Available) / Total &mdash; the same figure Windows Task Manager shows as its memory percentage.">' +
        '<div class="mem-stat-label">Physical RAM used</div><div class="mem-stat-value">' + fmtPct(d.physicalUsedPct) + '</div></div>' +
      '<div class="mem-stat' + (availCrit?' critical':availWarn?' warn':'') + '"><div class="mem-stat-label">Available RAM</div><div class="mem-stat-value">' + fmtBytesGB(d.availableBytes) + ' <span class="' + trendCls + '">(' + esc(d.trend || 'unknown') + ')</span></div></div>' +
      '<div class="mem-stat' + (commitCrit?' critical':commitWarn?' warn':'') + '" title="Virtual-memory commit CHARGE vs. commit LIMIT (physical RAM + pagefile capacity combined) &mdash; not physical RAM occupancy, so this can differ a lot from Physical RAM used.">' +
        '<div class="mem-stat-label">Commit</div><div class="mem-stat-value">' + fmtPct(d.commitPct) + '</div></div>' +
      '<div class="mem-stat" title="How full the pagefile itself is right now &mdash; the percent of the Windows swap file on disk currently holding paged-out data. Not RAM usage: it can sit near 0% even when memory is tight, since Windows avoids writing pages out until it actually needs the space.">' +
        '<div class="mem-stat-label">Pagefile</div><div class="mem-stat-value">' + fmtPct(d.pagefilePct) + '</div></div>';
    var buckets = (d.groups || []).slice().sort(function(a,b){ return b.privateBytes - a.privateBytes; });
    document.getElementById('mem-buckets').innerHTML = buckets.map(function(g){
      var names = (g.byName || []).map(function(n){ return esc(n.name) + ' &times;' + n.count + ' ' + fmtBytesGB(n.privateBytes); }).join(' &middot; ');
      return '<div class="mem-bucket-row"><span class="mem-bucket-label">' + esc(_memBucketLabel[g.key] || g.key) + '</span>' +
        '<span class="mem-bucket-count">' + g.count + '</span><span>' + fmtBytesGB(g.privateBytes) + '</span></div>' +
        (names ? '<div class="mem-bucket-names">' + names + '</div>' : '');
    }).join('');
    var top = (d.topProcesses || []);
    document.getElementById('mem-top').innerHTML = '<table><thead><tr><th>Process</th><th>Type</th><th>PID</th><th>Private</th><th>Working set</th></tr></thead><tbody>' +
      top.map(function(p){ return '<tr><td>' + esc(p.name) + '</td><td><span class="mem-tag">' + esc(_memBucketLabel[p.bucket] || p.bucket) + '</span></td><td>' + p.pid + '</td><td>' + fmtBytesGB(p.privateBytes) + '</td><td>' + fmtBytesGB(p.workingSetBytes) + '</td></tr>'; }).join('') +
      '</tbody></table>';
    document.getElementById('header-strip').dataset.mem = JSON.stringify({avail: d.availableBytes, commit: d.commitPct, availCrit: availCrit, commitCrit: commitCrit, availWarn: availWarn, commitWarn: commitWarn});
    renderHeaderStrip();
  } catch(e) { /* transient poll failure - next tick retries, matches every other panel's silent-retry convention */ }
}
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
      ' &middot; 7d ' + (usage.sevenDayPct==null?'?':Math.round(usage.sevenDayPct)+'%') +
      ' &middot; today $' + (usage.todayUsd==null?'?':usage.todayUsd.toFixed(2)));
  }
  // Skip the memory clause while ON the Memory tab itself -- it already shows these same figures in
  // its own stat tiles, so repeating them in the header strip is pure duplication there (Douglas
  // 2026-07-08). Still useful as an ambient indicator on the other 3 tabs.
  var onMemoryTab = document.querySelector('.tab-btn[data-tab="memory"]');
  onMemoryTab = onMemoryTab && onMemoryTab.getAttribute('aria-selected') === 'true';
  if(mem && !onMemoryTab){
    var availCls = mem.availCrit ? 'hs-crit' : (mem.availWarn ? 'hs-warn' : '');
    var commitCls = mem.commitCrit ? 'hs-crit' : (mem.commitWarn ? 'hs-warn' : '');
    parts.push('Machine: <span class="' + availCls + '">RAM ' + fmtBytesGB(mem.avail) + ' avail</span>' +
      ' &middot; <span class="' + commitCls + '">commit ' + fmtPct(mem.commit) + '</span>');
  }
  el.innerHTML = parts.join(' &nbsp;|&nbsp; ');
}
function esc(s){
  var d = document.createElement('div');
  d.textContent = s == null ? '' : s;
  return d.innerHTML;
}
function projectName(root){
  var parts = root.split(/[\\\\/]/).filter(Boolean);
  // Last 2 segments — disambiguates same-named project folders under different parents
  // (e.g. "Claude NASA Folder/text-to-truss" vs "Claude GSFC Folder/text-to-truss").
  return parts.slice(-2).join(' / ');
}
var MARKER_LABEL = {'x':'done', ' ':'todo', '~':'in progress', '!':'blocked', '?':'needs Douglas'};
function taskBoardHtml(tb){
  if(!tb || !tb.items || !tb.items.length) return '';
  var rows = tb.items.map(function(it){
    var cls = it.marker === 'x' ? 'active' : (it.marker === '!' || it.marker === '?' ? 'blocked' : (it.marker === '~' ? 'continuing' : 'idle'));
    return '<div style="display:flex;gap:8px;align-items:baseline;padding:2px 0;">' +
      '<span class="badge ' + cls + '" style="min-width:78px;text-align:center;flex-shrink:0">' + esc(MARKER_LABEL[it.marker] || it.marker) + '</span>' +
      '<span style="flex:1;min-width:0;overflow-wrap:anywhere">' + esc(it.text) + '</span></div>';
  }).join('');
  // The done/total count lives IN the summary line itself (not in a separate div below it) so
  // it's visible whether the section is collapsed or expanded -- <summary> content is never
  // hidden by <details>, only the rest of the content is. Found live 2026-07-06 (Douglas: the
  // count should show in both states). This used to be kept out of the summary deliberately,
  // back when the summary TEXT itself doubled as the open/scroll-preservation key across
  // refreshes (a changing count would have changed the key every poll) -- that constraint no
  // longer applies now that reconciliation keys on the stable data-slot="task-board" attribute
  // instead, so the summary text is free to be dynamic.
  var total = tb.counts.x + tb.counts.open + tb.counts.wip + tb.counts.blocked + tb.counts.parked;
  // Starts collapsed (2026-07-06, Douglas: the task board was too noisy expanded by default on
  // every card) - morphNode already skips patching `open` on existing nodes, so this only affects
  // a card's FIRST render; a user who expands it keeps that state across every later poll.
  return '<details data-slot="task-board"><summary>live task board (' + tb.counts.x + '/' + total + ' done)</summary>' +
    '<div style="margin-top:6px">' + rows + '</div></details>';
}
var ARCHIVE_ICON = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><rect x="1.6" y="2.8" width="12.8" height="3.1" rx="0.7"/><path d="M2.7 5.9v6.5a1 1 0 0 0 1 1h8.6a1 1 0 0 0 1-1V5.9"/><path d="M6.3 8.9h3.4"/></svg>';
// Just the last path segment (Douglas, 2026-07-07: the compact card shows "the folder name, but not
// the full path"). projectName (last 2 segments) is still used for the archived panel + the title.
function lastSegment(root){
  var parts = String(root).split(/[\\\\/]/).filter(Boolean);
  return parts.length ? parts[parts.length - 1] : String(root);
}
function cardHtml(c){
  if(c.kind === 'session') return sessionCardHtml(c);  // a live session is a board card too (see below)
  var folder = esc(lastSegment(c.root));
  var openAttr = _openProjects.has(c.root) ? ' open' : '';  // survive a column move (see _openProjects)
  // data-root keys the card across refreshes — several cards share identical inner text, so text
  // alone is NOT a safe key. The archive control is an icon inside the <summary> so it shows in the
  // collapsed view; its click handler preventDefaults so tapping it archives without toggling the card.
  var archiveBtn = '<button class="archive-btn" type="button" data-action="archive" data-root="' + esc(c.root) + '" title="archive" aria-label="archive">' + ARCHIVE_ICON + '</button>';
  if(c.kind === 'error'){
    return '<details class="card" data-root="' + esc(c.root) + '"' + openAttr + '>' +
      '<summary class="csum"><span class="cname" title="' + esc(c.root) + '">' + folder + '</span>' +
      '<span class="badge unknown">dashboard error</span>' + archiveBtn + '</summary>' +
      '<div class="cbody"><div class="detail"><code>' + esc(c.root) + '</code><br>' + esc(c.error) + '</div></div></details>';
  }
  var badge = '<span class="badge ' + c.status + '">' + esc(c.status) + '</span>';
  var cardClass = c.status === 'stalled' ? 'card flag-stalled' : 'card';
  // Compact collapsed view (~1/3 height): folder name, status, done/open, current item. done/open
  // come from the checklist on BOTH card kinds. ccur is ALWAYS rendered (empty when there's no
  // current item) so the summary's child count is constant and the keyless-positional reconciler
  // never smears open/scroll state across a node that appears/vanishes between polls.
  var doneN = (c.checklist && c.checklist.x) || 0;
  var openN = (c.checklist && c.checklist.open) || 0;
  // A real /longrun armed session is tagged "longrun"; a plain background build / watched project is a
  // "watcher" (Douglas 2026-07-07: "a longrun tag to distinguish from watchers").
  var kindTag = c.kind === 'longrun' ? '<span class="ktag longrun">longrun</span>'
              : (c.kind === 'project' ? '<span class="ktag watcher">watcher</span>' : '');
  var summary = '<summary class="csum"><span class="cname" title="' + esc(c.root) + '">' + folder + '</span>' + kindTag + badge +
    '<span class="cmeta"><span><b>' + doneN + '</b> done</span><span><b>' + openN + '</b> open</span></span>' +
    '<span class="ccur"' + (c.currentItem ? ' title="' + esc(c.currentItem) + '"' : '') + '>' + esc(c.currentItem || '') + '</span>' +
    archiveBtn + '</summary>';
  // ---- full detail (.cbody), shown only when expanded — everything the card showed before, minus
  // the heading the summary now carries. The root path stays a truncated one-liner (full path in the
  // title attr) rather than a 2-3 line wall of text; statusDetail wraps as a normal short sentence.
  var html = '<div class="detail"><code class="rootpath" title="' + esc(c.root) + '">' + esc(c.root) + '</code><br>' + esc(c.statusDetail || '') + '</div>';

  if(c.kind === 'longrun'){
    var total = c.checklist.x + c.checklist.open + c.checklist.wip;
    var pct = total ? Math.round(100 * c.checklist.x / total) : 0;
    html += '<div class="counts"><span><b>' + c.checklist.x + '</b> done</span>' +
      '<span><b>' + c.checklist.open + '</b> open</span>' +
      '<span><b>' + c.checklist.wip + '</b> in progress</span>' +
      (c.checklist.parked ? '<span><b>' + c.checklist.parked + '</b> parked (needs you)</span>' : '') +
      (c.checklist.blocked ? '<span style="color:var(--blocked)"><b>' + c.checklist.blocked + '</b> blocked</span>' : '') +
      (c.maxIterations ? '<span>max iter <b>' + esc(c.maxIterations) + '</b></span>' : '') + '</div>';
    html += '<div class="bar"><div class="bar-fill" style="width:' + pct + '%"></div></div>';
    if(c.currentItem) html += '<div class="current" data-slot="current"><span class="lab">current item</span>' + esc(c.currentItem) + '</div>';
    if(c.itemConflict) html += '<div class="conflict-note" data-slot="conflict">&#9888; ' + esc(c.itemConflict) + '</div>';
    if(c.staleNote) html += '<div class="conflict-note" data-slot="stale-note">&#9888; the ' + esc(c.staleNote.stalerSource === 'taskboard' ? 'live task board' : 'WORK_QUEUE counts') +
      ' above have not been touched in ' + Math.round(c.staleNote.ageDiffSeconds / 60) + 'm relative to the other source — may be out of date.</div>';
    if(c.stallWarning) html += '<div class="detail" data-slot="stall-warning" style="color:var(--stalled)">possible stall: same queue state ' + c.stallCount + '+ times in a row</div>';
    if(c.transcript){
      html += '<div class="detail" data-slot="transcript">transcript: ' + fmtBytes(c.transcript.sizeBytes) +
        ' <span class="warn-chip ' + c.transcriptRisk + '">' + (c.transcriptRisk !== 'ok' ? c.transcriptRisk : 'ok') + '</span>' +
        ' &middot; last write ' + fmtAge(c.transcript.mtime) +
        (c.transcriptRisk !== 'ok' ? '<br><span class="detail">fork: <code>' + esc(c.forkCmd) + '</code></span>' : '') + '</div>';
    }
    if(c.outputFiles && c.outputFiles.length){
      html += '<details class="files" data-slot="output-files"><summary>output files (' + c.outputFiles.length + ')</summary>' +
        c.outputFiles.map(function(p){ return '<div>' + esc(p) + '</div>'; }).join('') + '</details>';
    }
    html += taskBoardHtml(c.taskBoard);
    if(c.keepGoingTail){
      html += '<details data-slot="keep-going"><summary>keep-going log (last 8)</summary><pre>' + esc(c.keepGoingTail) + '</pre></details>';
    }
    if(c.currentTaskText){
      html += '<details data-slot="current-task"><summary>CURRENT-TASK.md (output/progress)</summary><pre>' + esc(c.currentTaskText) + '</pre></details>';
    }
  } else {
    var total2 = c.checklist.x + c.checklist.open + c.checklist.wip;
    var blockedChip2 = c.checklist.blocked ? '<span style="color:var(--blocked)"><b>' + c.checklist.blocked + '</b> blocked</span>' : '';
    if(total2){
      var pct2 = Math.round(100 * c.checklist.x / total2);
      html += '<div class="counts" data-slot="counts"><span><b>' + c.checklist.x + '</b> done</span><span><b>' + c.checklist.open + '</b> open</span>' + blockedChip2 + '</div>';
      html += '<div class="bar" data-slot="bar"><div class="bar-fill" style="width:' + pct2 + '%"></div></div>';
    } else if(blockedChip2){
      html += '<div class="counts" data-slot="counts">' + blockedChip2 + '</div>';
    }
    if(c.currentItem) html += '<div class="current" data-slot="current"><span class="lab">current / next item</span>' + esc(c.currentItem) + '</div>';
    if(c.relatedLongrunRoot) html += '<div class="xref-note" data-slot="xref">this project also has an ACTIVE /longrun session driven from <code>' +
      esc(c.relatedLongrunRoot) + '</code> — see that card for the live, up-to-date status; this plain-file view may lag behind it.</div>';
    if(c.outputFiles && c.outputFiles.length){
      html += '<details class="files" data-slot="output-files"><summary>output files (' + c.outputFiles.length + ')</summary>' +
        c.outputFiles.map(function(p){ return '<div>' + esc(p) + '</div>'; }).join('') + '</details>';
    }
    html += taskBoardHtml(c.taskBoard);
    if(c.logTail){
      html += '<details data-slot="log-tail"><summary>LOG.md (last 6)</summary><pre>' + esc(c.logTail) + '</pre></details>';
    }
    if(c.currentTaskText){
      html += '<details data-slot="current-task"><summary>CURRENT-TASK.md (output/progress)</summary><pre>' + esc(c.currentTaskText) + '</pre></details>';
    }
  }
  return '<details class="' + cardClass + '" data-root="' + esc(c.root) + '"' + openAttr + '>' + summary +
    '<div class="cbody">' + html + '</div></details>';
}

// ---- diff-aware card reconciliation -------------------------------------------------------
// Replaces the old full-innerHTML-replace-every-poll with keyed reconciliation. Each card is
// keyed by data-root (the same key preserveScrollAndRender used). Per poll we diff the incoming
// cards against what is on screen and touch ONLY what genuinely changed:
//   1. changed  -> morph just that card's differing text/attribute nodes in place
//   2. unchanged -> a true no-op: the card is never even inspected, so its open <details>, its
//                   <pre> scroll offset, and page scroll are undisturbed BY CONSTRUCTION (no
//                   snapshot/restore dance, which is what could jitter them before)
//   3. added    -> insert the new card element at its array position
//   4. removed  -> remove the vanished card's element
// A reconciliation bug here would make this truth-telling dashboard silently show a stale status,
// so correctness is driven by the FULL rendered output of cardHtml (an exhaustive signature of
// every visible field), never a hand-maintained per-field patch list that could omit a field.

// Cache of the last-rendered HTML string per card key. If cardHtml(c) produces byte-identical
// output to what we last rendered for this key, nothing visible changed -> skip the card entirely.
var _lastCardHtml = {};
// Previously-rendered status per card key, so a status flip (continuing -> blocked, active ->
// stalled, anything -> finished) is detected ONLY when the status actually changes, and the pulse
// is never re-triggered on an unchanged card.
var _lastCardStatus = {};

function parseCardEl(html){
  // Turn a cardHtml() string into a single detached element node.
  var t = document.createElement('template');
  t.innerHTML = html.trim();
  return t.content.firstElementChild;
}

// Recursively morph `oldNode` toward `newNode`, patching only what differs. Both are assumed to
// be the same card (same data-root) so their structure lines up; where it diverges we replace the
// subtree wholesale. Open <details> state and <pre> scroll offsets are preserved because those
// live on the EXISTING nodes we keep — we only ever overwrite attributes/text that actually changed.
function morphNode(oldNode, newNode){
  // Different node types or different tags -> can't patch in place, swap the whole subtree.
  if(oldNode.nodeType !== newNode.nodeType ||
     (oldNode.nodeType === 1 && oldNode.tagName !== newNode.tagName)){
    oldNode.replaceWith(newNode.cloneNode(true));
    return;
  }
  if(oldNode.nodeType === 3){ // text node
    if(oldNode.nodeValue !== newNode.nodeValue) oldNode.nodeValue = newNode.nodeValue;
    return;
  }
  if(oldNode.nodeType !== 1) return; // comments etc — leave alone
  // Sync attributes (skip `open` on <details>: that reflects the user's own toggle, not server
  // state, and the template never carries a meaningful open value except the task board default
  // which is only honored on first insert).
  var isDetails = oldNode.tagName === 'DETAILS';
  var oldAttrs = oldNode.attributes, newAttrs = newNode.attributes;
  for(var i = oldAttrs.length - 1; i >= 0; i--){
    var an = oldAttrs[i].name;
    if(isDetails && an === 'open') continue;
    if(!newNode.hasAttribute(an)) oldNode.removeAttribute(an);
  }
  for(var j = 0; j < newAttrs.length; j++){
    var na = newAttrs[j];
    if(isDetails && na.name === 'open') continue;
    if(oldNode.getAttribute(na.name) !== na.value) oldNode.setAttribute(na.name, na.value);
  }
  // A node marked data-lazy owns its own children: they're fetched + rendered client-side after the
  // first paint (a session card's recent-activity detail, loaded on expand). Sync its own attributes
  // but never reconcile INTO it, or the very next 6s poll would wipe the lazily-loaded content.
  if(oldNode.getAttribute('data-lazy') != null) return;
  reconcileChildren(oldNode, newNode);
}

// Reconcile oldNode's children toward newNode's. A card's VARIABLE middle blocks (current item,
// conflict/stale/stall notes, transcript, output files, task board, keep-going / LOG / CURRENT-TASK
// panels) each carry a stable data-slot naming what they ARE, because they conditionally appear and
// disappear between polls as live data changes. Matching them by data-slot (not raw DOM position)
// is what keeps a <details>'s user-toggled `open` state and a <pre>'s scroll offset pinned to the
// LOGICAL panel they belong to — if we matched by position, a middle block vanishing (e.g.
// currentItem -> null) would shift every later slot by one and smear the wrong panel's open/scroll
// state onto its neighbour (the bug this replaced). Keyless children (the always-present h2 / detail
// header, plus text and whitespace nodes) have no data-slot and stay reconciled positionally among
// themselves, so the fast common path is unchanged and a true no-op poll still mutates nothing.
function reconcileChildren(oldNode, newNode){
  var oldKids = Array.prototype.slice.call(oldNode.childNodes);
  var newKids = Array.prototype.slice.call(newNode.childNodes);
  function slotOf(node){
    return (node.nodeType === 1 && node.getAttribute) ? node.getAttribute('data-slot') : null;
  }
  // Index old element children that carry a data-slot so we can find them by logical identity.
  var oldBySlot = {};
  var keylessOld = [];
  oldKids.forEach(function(o){
    var s = slotOf(o);
    if(s != null) oldBySlot[s] = o; else keylessOld.push(o);
  });
  var keylessIdx = 0;
  var ordered = [];          // the old nodes we keep, in new-render order
  var kept = new Set();
  newKids.forEach(function(nk){
    var s = slotOf(nk);
    var match;
    if(s != null){
      match = oldBySlot[s];                 // same logical panel across polls, wherever it now sits
    } else {
      // Consume keyless old children in order — pair like structural node with like (skip already
      // slot-claimed ones; those never land in keylessOld). Require same node type to avoid morphing
      // a text node against an element.
      while(keylessIdx < keylessOld.length && keylessOld[keylessIdx].nodeType !== nk.nodeType) keylessIdx++;
      match = keylessOld[keylessIdx++];
    }
    if(match){
      morphNode(match, nk);
      ordered.push(match);
      kept.add(match);
    } else {
      // No old counterpart (a slot newly appeared, or an extra keyless node) -> fresh clone.
      ordered.push(nk.cloneNode(true));
    }
  });
  // Remove old children that no longer have a counterpart (a slot vanished, or a trailing keyless
  // node was dropped).
  oldKids.forEach(function(o){ if(!kept.has(o)) o.remove(); });
  // Place the kept/new children into new-render order, touching the DOM only where the sequence is
  // actually wrong. We walk the target order and insertBefore each node ahead of the current cursor
  // only when it is not already there — so a change that keeps the same child order (e.g. only a
  // count's text changed) performs ZERO structural moves, and open/scroll on every retained <details>
  // stays exactly as the user left it. insertBefore on an already-present node moves it (no clone, no
  // state loss); a freshly-cloned node is inserted at its logical spot.
  var cursor = oldNode.firstChild;
  ordered.forEach(function(node){
    if(cursor === node){ cursor = cursor.nextSibling; return; } // already in place
    oldNode.insertBefore(node, cursor);
  });
}

// Fade+shrink a card out before actually removing it (archived, moved to another column, or its
// root vanished), instead of an instant vanish. Guards against the reinstatement race: if THIS SAME
// element gets legitimately reused as an active card again before the animation finishes (found by
// reasoning through it, not by luck -- a card can come back within one poll cycle), morphNode's own
// attribute sync already strips .card-exiting when it patches the class list to match the new render,
// so checking for the class's presence at removal time is what stops a live, just-reinstated card
// from being deleted out from under itself.
function animateOutAndRemove(el){
  el.classList.add('card-exiting');
  var done = false;
  function finish(){
    if(done) return;
    done = true;
    el.removeEventListener('transitionend', finish);
    if(el.classList.contains('card-exiting')) el.remove();
  }
  el.addEventListener('transitionend', finish);
  setTimeout(finish, 300); // fallback under prefers-reduced-motion (no transitionend ever fires)
}

function pulseStatusFlip(cardEl, status){
  // One-shot restrained border-color pulse in the NEW status's color. The animated swell is defined
  // in CSS via the @property-registered --pulse custom prop; here we set the target color and add
  // the trigger class, then strip it so a future flip can fire it again.
  if(!cardEl) return;
  var colorVar = STATUS_COLOR_VAR[status] || '--line';
  cardEl.style.setProperty('--pulse-target', 'var(' + colorVar + ')');
  cardEl.classList.remove('status-flip');
  void cardEl.offsetWidth; // reflow so re-adding the class restarts the animation
  cardEl.classList.add('status-flip');
  // Cleanup on animationend when the animation actually runs. Under prefers-reduced-motion the CSS
  // sets animation:none, so NO animationend ever fires — without an unconditional timed fallback the
  // class (and its status-colored border) would stick permanently. A single timeout longer than the
  // 0.9s animation always removes it, and clears the animationend listener if that already ran.
  var done = false;
  function cleanup(){
    if(done) return;
    done = true;
    cardEl.classList.remove('status-flip');
    cardEl.removeEventListener('animationend', onEnd);
  }
  function onEnd(){ cleanup(); }
  cardEl.addEventListener('animationend', onEnd);
  setTimeout(cleanup, 1100);
}

// Maps a status label to the CSS color variable the badge already uses, so a flip pulses in the
// exact color the card is about to read as. Unknown -> the neutral idle color, never a hard fail.
var STATUS_COLOR_VAR = {
  active:'--active', continuing:'--continuing', blocked:'--blocked', stopped:'--blocked',
  idle:'--idle', unknown:'--idle', dormant:'--idle', finished:'--finished', stalled:'--stalled'
};

// Kanban columns are a direct relabeling of the five status-color groups the badge CSS (and
// STATUS_COLOR_VAR above) already uses - not a new invented taxonomy, just the existing grouping
// laid out as columns instead of a same-color badge (2026-07-06, Douglas: "more of a kanban style").
var KANBAN_COLUMNS = [
  {key:'needs-you', title:'Needs You', statuses:['blocked','stopped','waiting']},
  {key:'active', title:'Active', statuses:['active','continuing']},
  {key:'stalled', title:'Stalled', statuses:['stalled']},
  {key:'idle', title:'Idle', statuses:['idle','unknown','dormant']},
  {key:'finished', title:'Finished', statuses:['finished']},
];
var STATUS_TO_COLUMN = {};
KANBAN_COLUMNS.forEach(function(col){ col.statuses.forEach(function(s){ STATUS_TO_COLUMN[s] = col.key; }); });
// A status this map doesn't know about (or the 'error' kind's "unknown" badge) falls into Idle,
// matching how the badge CSS itself already groups 'unknown' with idle/dormant.
function kanbanColumnFor(status){ return STATUS_TO_COLUMN[status] || 'idle'; }

var _sortByDate = false; // flipped on from localStorage before the first render, see bottom of script
var _showInactive = false; // ditto - see the show-inactive wiring near the bottom of the script

function reconcileCardList(host, cards, emptyMessage){
  // Empty result: forget cached state for whatever WAS in this column (same cleanup case 4 below
  // does), then show the empty message — a card that reappears here later, or moves to another
  // column, is treated as a genuinely fresh insert rather than diffing against a stale cache entry.
  if(!cards.length){
    Array.prototype.slice.call(host.querySelectorAll('[data-root]')).forEach(function(el){
      var key = el.getAttribute('data-root');
      delete _lastCardHtml[key];
      delete _lastCardStatus[key];
    });
    // A column can start out showing the STATIC "loading..." placeholder from the initial page HTML
    // and then genuinely have zero cards on the very first real poll - that placeholder already has
    // class="empty", so checking only "does .empty exist" would leave "loading..." on screen forever
    // (found live 2026-07-06, screenshotted: Needs You/Active stuck on "loading..." indefinitely with
    // an otherwise-correct "0" count in the column header). Compare the TEXT too, not just presence.
    var existingEmpty = host.querySelector('.empty');
    if(!existingEmpty || existingEmpty.textContent !== emptyMessage){
      host.innerHTML = '<p class="empty">' + esc(emptyMessage) + '</p>';
    }
    return;
  }
  // If the host currently holds only the empty placeholder, clear it before inserting real cards.
  var placeholder = host.querySelector('.empty');
  if(placeholder) placeholder.remove();

  var seen = {};
  var prevEl = null; // the previously-placed card, to keep DOM order matching the array order
  cards.forEach(function(c){
    var key = c.root;
    seen[key] = true;
    var newHtml = cardHtml(c);
    var status = c.status;
    var existing = host.querySelector('[data-root="' + (window.CSS && CSS.escape ? CSS.escape(key) : key) + '"]');

    if(!existing){
      // CASE 3 — newly added card: build and insert at the right position.
      var el = parseCardEl(newHtml);
      if(prevEl && prevEl.nextSibling){ host.insertBefore(el, prevEl.nextSibling); }
      else if(prevEl){ host.appendChild(el); }
      else if(host.firstChild){ host.insertBefore(el, host.firstChild); }
      else { host.appendChild(el); }
      _lastCardHtml[key] = newHtml;
      _lastCardStatus[key] = status;
      prevEl = el;
      return;
    }

    // Ensure DOM order tracks array order even when a middle card was inserted/removed.
    if(prevEl && prevEl.nextSibling !== existing){ host.insertBefore(existing, prevEl ? prevEl.nextSibling : host.firstChild); }
    else if(!prevEl && host.firstChild !== existing){ host.insertBefore(existing, host.firstChild); }

    if(_lastCardHtml[key] === newHtml){
      // CASE 2 — nothing changed: a complete no-op on this card's DOM. Open <details>, <pre>
      // scroll, and page scroll are untouched because we never touch the node at all.
      prevEl = existing;
      return;
    }

    // CASE 1 — the card genuinely changed: morph only the differing nodes in place.
    var fresh = parseCardEl(newHtml);
    morphNode(existing, fresh);
    _lastCardHtml[key] = newHtml;

    // Status flip -> one restrained pulse in the new color, only when it ACTUALLY changed.
    if(_lastCardStatus[key] !== status){
      pulseStatusFlip(existing, status);
      _lastCardStatus[key] = status;
    }
    prevEl = existing;
  });

  // CASE 4 — cards that were present before but are gone from the array now: animate them out
  // (archived, moved to another column, or the root vanished) instead of an instant vanish.
  Array.prototype.slice.call(host.querySelectorAll('[data-root]')).forEach(function(el){
    var key = el.getAttribute('data-root');
    if(!seen[key]){
      animateOutAndRemove(el);
      delete _lastCardHtml[key];
      delete _lastCardStatus[key];
    }
  });
}

// A card is "inactive" only when it HAS a real lastActivityTs and that timestamp is genuinely
// stale (>1 day) - a card with no timestamp signal at all (null) is left visible rather than
// silently assumed inactive, since we don't actually know how old it is (never look more certain
// than the underlying data, per PRODUCT.md). This is a client-side classification, not persisted
// anywhere and not the same thing as archive - it flips back automatically the moment real
// activity resumes, with no manual restore step.
var INACTIVE_AGE_SECONDS = 86400;
function isInactive(c){
  return c.lastActivityTs != null && (Date.now() / 1000 - c.lastActivityTs) > INACTIVE_AGE_SECONDS;
}

// Buckets the flat card array into the 5 Kanban columns and reconciles each column's body
// independently (reconcileCardList above). A card whose status changes column between polls is
// removed from its old column's host and freshly inserted into the new one — a real structural
// move, not the destructive-rebuild race this reconciliation exists to avoid (see reconcileCardList).
function reconcileCards(cards){
  // Session cards used to be exempt from this filter so the toolbar's "N of M sessions shown" note
  // couldn't disagree with the board (review 2026-07-07) -- but that meant yesterday's idle sessions
  // counted as visible forever, inflating the apparent session count (Douglas 2026-07-08). Fixed by
  // computing the toolbar note itself post-filter instead (refreshSessions), so hiding old sessions
  // here is no longer a disagreement -- it's what "hidden" means.
  if(!_showInactive) cards = cards.filter(function(c){ return !isInactive(c); });
  var byColumn = {};
  KANBAN_COLUMNS.forEach(function(col){ byColumn[col.key] = []; });
  cards.forEach(function(c){ byColumn[kanbanColumnFor(c.status)].push(c); });
  if(_sortByDate){
    KANBAN_COLUMNS.forEach(function(col){
      byColumn[col.key].sort(function(a, b){ return (b.lastActivityTs || 0) - (a.lastActivityTs || 0); });
    });
  }
  KANBAN_COLUMNS.forEach(function(col){
    var colEl = document.querySelector('.kcol[data-col="' + col.key + '"]');
    if(!colEl) return;
    var bucket = byColumn[col.key];
    var countText = String(bucket.length);
    colEl.querySelector('.kcount').textContent = countText;
    // The toolbar's own toggle button mirrors the same count, so Douglas can tell how many cards
    // are in a column even while deciding whether to show or hide it (2026-07-06: "There should be
    // a number for each one so I can tell where it is").
    var toggleCount = document.querySelector('.col-toggle-btn[data-col="' + col.key + '"] .col-toggle-count');
    if(toggleCount) toggleCount.textContent = countText;
    reconcileCardList(colEl.querySelector('.kcol-body'), bucket, 'nothing here');
  });
}

var _lastCardsData = [];    // project/longrun cards from /api/longruns
var _lastSessionCards = [];  // live-session cards from /api/sessions (merged onto the same board)
// The board is the union of project cards and session cards. Each poller updates its own slice then
// calls this, so a sessions refresh and a longruns refresh never clobber each other's cards.
function renderBoard(){ reconcileCards(_lastCardsData.concat(_lastSessionCards)); }

// Sequence guard (same pattern as _serversFetchSeq below, for the same reason): the archive button
// now calls refresh() directly right after its POST, on top of the existing periodic 6s poll -- two
// /api/longruns fetches can be in flight at once, and without this an OLDER periodic response
// resolving AFTER the archive-triggered one could silently resurrect the just-archived card until
// the next tick. Added 2026-07-06 specifically because the archive feature introduced this second
// caller; refresh() had no other caller whose correctness depended on ordering before it existed.
var _longrunsFetchSeq = 0;
async function refresh(){
  var mySeq = ++_longrunsFetchSeq;
  try {
    var cards = await (await fetch('/api/longruns')).json();
    if(mySeq !== _longrunsFetchSeq) return; // a newer refresh has started since; this one is stale
    _lastCardsData = cards;
    renderBoard();
    document.getElementById('updated').textContent = 'last updated ' + new Date().toLocaleTimeString();
  } catch(e) { console.error('dashboard refresh failed', e); }
}

// One-line, source-grounded description per known server name, for the hover tooltip Douglas
// asked for (2026-07-06: "I don't fully understand all these things"). A name not in this map
// gets a generic fallback rather than a fabricated guess.
var SERVER_DESCRIPTIONS = {
  'ops': "Engineer harness ops dashboard backend, over the Obsidian vault's Claude/Engineer folder.",
  'dashboard-test': 'Throwaway static file server for testing the dashboard system itself, not a real project.',
  'dpm-kit-explorable': "Static preview of the dpm-agent-kit's explorable demo.",
  'dash': 'Static HTML dashboard for the AI for CAD vault content.',
  'tacit': 'Tacit Knowledge Capture explorer SPA (tacit-explorer).',
  'longrun-dashboard': 'This dashboard itself.',
  'sme-tacit-retrieval': 'SME tacit-frames retrieval/chat backend over the sme-tacit-frames corpus.',
  'model-review-compare': 'Model comparison review tool (ai-for-cad).',
  'cad-forge-live-server': 'Live-reloading viewer for the Text-to-Satellite/CubeSat dashboards AND the Interface Extractor Viewer (hole/bolt-pattern detection on STEP parts) -- serves the whole AI for CAD vault html/ folder, auto-refreshes on build changes.',
  'vault-engineer-preview': "Static preview of the Obsidian vault's Claude/Engineer folder.",
  'truss-dashboard': 'The live Text-to-Truss dashboard (truss-forge/dashboard/dashboard_server.py) — build status, babysit decisions, and per-build CAD export; opens at /dashboard/truss-dashboard.html.',
  'build-log-preview': 'The ai-for-cad build log (build-log/serve.py); opens at /direction-c-converged.html.',
};
function serverDescription(name){
  return SERVER_DESCRIPTIONS[name] || 'No description recorded for this server yet.';
}
function serverRowHtml(s){
  // openPath (from the config) lands the "open" link on the server's real page instead of bare
  // root -- e.g. the truss dashboard's /dashboard/truss-dashboard.html or the build log's
  // /direction-c-converged.html, whose root either redirects or isn't the page Douglas wants.
  var url = 'http://localhost:' + s.port + (s.openPath || '/');
  // .sbadge is a stable hook the optimistic click handler grabs to spring toward the target state.
  // data-slot on the variable children (badge/action/result/open-link) is what lets reconcileServers
  // patch this row in place across a periodic poll instead of tearing it down -- without it, an
  // in-flight optimistic click's own resultEl/badge references would go stale the moment a routine
  // refresh rebuilt the row underneath it (found live 2026-07-06: this exact race made a genuinely
  // successful Start silently show "stopped" with no message, because the periodic poll fired mid-
  // click and its full-rebuild replaced the very node the click handler was about to write its
  // result into).
  var statusBadge;
  if(!s.running) statusBadge = '<span class="badge idle sbadge" data-slot="badge">stopped</span>';
  else if(s.health === 'unhealthy') statusBadge = '<span class="badge stalled sbadge" data-slot="badge">unresponsive</span>';
  else statusBadge = '<span class="badge active sbadge" data-slot="badge">running</span>';
  var actionBtn = s.running ?
    '<button class="stop" data-action="stop" data-port="' + s.port + '" data-name="' + esc(s.name) + '" data-slot="action">Stop</button>' :
    '<button data-action="start" data-id="' + esc(s.id) + '" data-name="' + esc(s.name) + '" data-slot="action">Start</button>';
  var openLink = s.running ? '<a class="open-link" href="' + url + '" target="_blank" data-slot="open-link">open &#8599;</a>' : '';
  var memText = s.memory ? fmtBytesGB(s.memory.privateBytes) : '&mdash;';
  return '<div class="srow" data-server-id="' + esc(s.id) + '" title="' + esc(serverDescription(s.name)) + '"><span class="sname">' + esc(s.name) + '</span>' +
    '<span class="sport">:' + s.port + '</span>' + statusBadge + '<span class="smem">' + memText + '</span>' + actionBtn +
    '<span class="action-result" data-slot="result"></span>' + openLink + '</div>';
}

function reconcileServers(host, servers){
  if(!servers.length){
    if(!host.querySelector('.empty')){
      host.innerHTML = '<p class="empty">no launch.json server configs found under the configured roots</p>';
    }
    return;
  }
  var placeholder = host.querySelector('.empty');
  if(placeholder) placeholder.remove();

  var seen = {};
  var prevEl = null;
  servers.forEach(function(s){
    var key = s.id;
    seen[key] = true;
    var newHtml = serverRowHtml(s);
    var existing = host.querySelector('[data-server-id="' + (window.CSS && CSS.escape ? CSS.escape(key) : key) + '"]');

    if(!existing){
      var el = parseCardEl(newHtml);
      if(prevEl && prevEl.nextSibling){ host.insertBefore(el, prevEl.nextSibling); }
      else if(prevEl){ host.appendChild(el); }
      else if(host.firstChild){ host.insertBefore(el, host.firstChild); }
      else { host.appendChild(el); }
      prevEl = el;
      return;
    }

    if(prevEl && prevEl.nextSibling !== existing){ host.insertBefore(existing, prevEl ? prevEl.nextSibling : host.firstChild); }
    else if(!prevEl && host.firstChild !== existing){ host.insertBefore(existing, host.firstChild); }

    // Patch in place -- this is the fix: the row's DOM node (and its .action-result / badge
    // children, keyed by data-slot) survives every periodic refresh, so a click handler holding
    // a reference to them never goes stale mid-action.
    morphNode(existing, parseCardEl(newHtml));
    prevEl = existing;
  });

  Array.prototype.slice.call(host.querySelectorAll('[data-server-id]')).forEach(function(el){
    if(!seen[el.getAttribute('data-server-id')]) el.remove();
  });
}
function sleep(ms){ return new Promise(function(resolve){ setTimeout(resolve, ms); }); }

function prefersReducedMotion(){
  return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}
// A damped-harmonic-oscillator spring sampled into scale keyframes, applied to the badge via the
// Web Animations API so the optimistic state-swap arrives with real mass/tension/damping overshoot
// instead of a linear fade. Falls back to no animation under prefers-reduced-motion.
function springBadge(badge){
  if(!badge || !badge.animate) return;
  if(prefersReducedMotion()) return;
  var mass = 1, tension = 210, damping = 18;   // a lively-but-settled spring
  var w0 = Math.sqrt(tension / mass);
  var zeta = damping / (2 * Math.sqrt(tension * mass));  // ~0.62 -> underdamped, one soft overshoot
  var wd = w0 * Math.sqrt(1 - zeta * zeta);
  var frames = [];
  var steps = 40;
  var durationMs = 520;
  for(var i = 0; i <= steps; i++){
    var t = (i / steps) * (durationMs / 1000);
    // displacement of an underdamped spring released from -1 (undershoot) settling to 0
    var env = Math.exp(-zeta * w0 * t);
    var disp = env * Math.cos(wd * t);        // 1 -> 0 with overshoot
    var scale = 1 + 0.16 * disp;              // peak ~1.16 at t=0, settling to 1.0
    frames.push({ transform: 'scale(' + scale.toFixed(4) + ')' });
  }
  badge.animate(frames, { duration: durationMs, easing: 'linear', fill: 'none' });
}
// Repaint one badge in place toward a target state (start -> running, stop -> stopped), reusing the
// exact class + label the server-side renderer uses, so the optimistic view is byte-identical to
// what the next real refresh will draw.
function setBadgeState(badge, running){
  if(!badge) return;
  badge.className = running ? 'badge active sbadge' : 'badge idle sbadge';
  badge.textContent = running ? 'running' : 'stopped';
}

// Multiple /api/servers fetches can be in flight at once (the 6s periodic poll, plus each click
// handler's own trailing refresh), and network responses can arrive out of order -- an older
// request's stale "stopped" snapshot resolving AFTER a newer request's correct "running" one would
// otherwise overwrite it, even with reconcileServers patching nodes correctly in place (found live
// 2026-07-06: this is what made a genuinely successful Start intermittently flash back to "stopped"
// -- a real request-ordering race, distinct from the node-identity issue reconcileServers already
// fixes). Only the most-recently-STARTED refresh is allowed to apply its result.
var _serversFetchSeq = 0;
async function refreshServers(){
  var mySeq = ++_serversFetchSeq;
  try {
    var servers = await (await fetch('/api/servers')).json();
    if(mySeq !== _serversFetchSeq) return; // a newer refresh has started since; this one is stale
    var host = document.getElementById('servers-list');
    reconcileServers(host, servers);
  } catch(e) { console.error('servers refresh failed', e); }
}

function discoveredRowHtml(d){
  var url = 'http://localhost:' + d.port + '/';
  return '<div class="srow"><span class="sname">' + esc(d.processName || '(unknown process)') +
    '</span><span class="sport">:' + d.port + '</span>' +
    '<span class="detail" style="margin:0;flex:2;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="' +
    esc(d.commandLine || '') + '">' + esc((d.commandLine || '').slice(0, 70)) + '</span>' +
    '<a class="open-link" href="' + url + '" target="_blank">open &#8599;</a></div>';
}

async function refreshDiscovered(){
  try {
    var discovered = await (await fetch('/api/discovered')).json();
    var host = document.getElementById('discovered-list');
    host.innerHTML = discovered.length ? discovered.map(discoveredRowHtml).join('') :
      '<p class="empty">nothing listening right now beyond the registered servers above</p>';
  } catch(e) { console.error('discovered refresh failed', e); }
}

// Merged in from Mission Control (2026-07-07): every live Claude Code session transcript, most
// recent first. Read-mostly like discoveredRowHtml above (plain rebuild-on-poll, no keyed
// reconciliation) - the only interactive bit is "Message", which QUEUES a dispatch request rather
// than injecting it (this dashboard has no ccd_session_mgmt MCP access of its own; see
// queue_session_action's docstring in the Python side for why).
function sessionStateClass(state){
  return state === 'active' ? 'active' : (state === 'waiting' ? 'blocked' : 'idle');
}
// Open-session set + detail cache, so an expanded session's recent-activity panel survives the 10s
// poll rebuild (the sessions list is a plain innerHTML rebuild; without this an open detail would
// collapse every tick). Mirrors Mission Control's OPEN/DETAIL approach.
var _openSessions = new Set();
var _sessionDetail = {};
// Expanded PROJECT cards, keyed by root, mirroring _openSessions. Without this a card the user
// expanded collapses the moment its status changes kanban column (a fresh re-insert rebuilds it from
// cardHtml, and morphNode's open-skip only preserves expansion for same-column polls) -- exactly at
// the interesting transition. cardHtml re-emits `open` for roots in this set (review 2026-07-07).
var _openProjects = new Set();
// A live session is a card on the same board as the projects (Douglas 2026-07-07: "have the live
// sessions on this cardboard"). Same compact-summary shape as a project card: title as the name,
// state badge, ctx%/cost as the meta, project + last-activity as the current-line, and a Message
// action in the corner. The body is lazily loaded on expand (data-lazy so the poll's reconcile never
// wipes it) and shows recent transcript activity. context%/est cost come from session_usage; cost is
// always "~$"/est-labelled so it never reads as a real invoice figure.
function sessionCardHtml(c){
  var ctx = (typeof c.contextPct === 'number' && c.contextPct > 0)
    ? '<span class="sctx" title="rough context-window fill from the most recent turn">' + Math.round(c.contextPct * 100) + '%</span>' : '';
  var cost = (typeof c.estCostUsd === 'number' && c.estCostUsd > 0)
    ? '<span class="scost" title="estimated cumulative cost (not authoritative)">~$' + c.estCostUsd.toFixed(2) + '</span>' : '';
  var badge = '<span class="badge ' + sessionStateClass(c.state) + '">' + esc(c.state) + '</span>';
  var openAttr = _openSessions.has(c.id) ? ' open' : '';
  var detail = _sessionDetail[c.id] || '<p class="detail" style="margin:6px 0 0">expand to load recent activity…</p>';
  return '<details class="card scard" data-root="' + esc(c.root) + '" data-sid="' + esc(c.id) + '"' + openAttr + '>' +
    '<summary class="csum"><span class="cname" title="' + esc(c.title) + '">' + esc(c.title) + '</span>' +
    '<span class="scard-tag">session</span>' + badge +
    '<span class="cmeta">' + ctx + cost + '</span>' +
    '<span class="ccur"><span class="sfolder">' + esc(c.folder || '') + '</span> &middot; ' +
      '<span class="stimer" data-ts="' + (c.lastActivityTs || 0) + '" title="time since the last message">' + esc(fmtElapsed(c.lastActivityTs)) + '</span></span>' +
    '<button class="scard-msg" type="button" data-action="message" data-sid="' + esc(c.id) + '" title="queue a message for this session">msg</button>' +
    '<span class="action-result"></span></summary>' +
    '<div class="cbody sdetail" data-slot="sdetail" data-lazy>' + detail + '</div></details>';
}
// Transform the /api/sessions payload into board-card objects: kind=session, a synthetic root key
// (never a real path, so it can't collide with a project card), and status=state so kanbanColumnFor
// routes waiting->Needs You, active->Active, idle->Idle.
function sessionsToCards(data){
  return ((data && data.sessions) || []).map(function(s){
    return Object.assign({}, s, {kind: 'session', root: 'session::' + s.id, status: s.state});
  });
}
function fmtSessionEvents(events){
  if(!events || !events.length) return '<p class="detail" style="margin:6px 0 0">no recent activity captured.</p>';
  return events.map(function(e){
    if(e.kind === 'tool') return '<div class="sevent"><span class="sek tool">tool</span><b>' + esc(e.tool) + '</b> <span style="color:var(--muted)">' + esc(e.input || '') + '</span></div>';
    return '<div class="sevent"><span class="sek ' + esc(e.kind) + '">' + esc(e.kind) + '</span>' + esc(e.text || '') + '</div>';
  }).join('');
}
async function loadSessionDetail(sid, host){
  try {
    var d = await (await fetch('/api/session/' + encodeURIComponent(sid))).json();
    var html = fmtSessionEvents(d.events);
    _sessionDetail[sid] = html;
    if(host) host.innerHTML = html;
  } catch(e) { console.error('session detail failed', e); }
}

var _sessionsFetchSeq = 0;
async function refreshSessions(){
  // Sequence guard, same as refresh()/refreshServers(): refreshSessions has three overlapping callers
  // (the 10s interval + the visibilitychange + focus handlers, which fire together on alt-tab-back), and
  // /api/sessions does variable per-session transcript I/O, so an older response can resolve after a
  // newer one and leave _lastSessionCards holding a stale slice until the next poll (review 2026-07-07).
  var mySeq = ++_sessionsFetchSeq;
  try {
    var data = await (await fetch('/api/sessions')).json();
    if(mySeq !== _sessionsFetchSeq) return; // a newer refresh has started since; this response is stale
    _lastSessionCards = sessionsToCards(data);
    renderBoard();  // sessions now live on the kanban alongside project cards
    // Honest "showing N of M" note whenever the cap hid something -- never a silent truncation
    // (Douglas's no-silent-caps rule). Active/waiting sessions sort to the top and are always shown,
    // so the hidden ones are only older idle sessions.
    var note = document.getElementById('sessions-note');
    if(note){
      // Counts what's actually visible on the board (post client-side inactive-filter), not just what
      // the capped fetch returned -- else this note and the board disagree once old sessions are hidden.
      var shown = _showInactive ? (data.sessions || []).length
        : (data.sessions || []).filter(function(s){ return !isInactive(s); }).length;
      note.textContent = (data.total > shown)
        ? (shown + ' of ' + data.total + ' sessions shown (older idle hidden)')
        : (shown + ' session' + (shown === 1 ? '' : 's'));
    }
    // Keep any expanded session card's recent-activity live without collapsing it across the poll.
    _openSessions.forEach(function(sid){
      var d = document.querySelector('.scard[data-sid="' + (window.CSS && CSS.escape ? CSS.escape(sid) : sid) + '"] .sdetail');
      if(d) loadSessionDetail(sid, d);
    });
  } catch(e) { console.error('sessions refresh failed', e); }
}
// A session card lazily loads its recent activity on first expand (toggle doesn't bubble -> capture).
// Lives on #cards now that sessions are board cards; ignores the project cards' own toggles.
document.getElementById('cards').addEventListener('toggle', function(ev){
  var d = ev.target;
  if(!d || d.tagName !== 'DETAILS') return;
  if(d.classList.contains('scard')){
    var sid = d.getAttribute('data-sid');
    if(d.open){ _openSessions.add(sid); loadSessionDetail(sid, d.querySelector('.sdetail')); }
    else { _openSessions.delete(sid); }
  } else if(d.classList.contains('card')){
    // A project card: remember its expanded state by root so a column move (which re-inserts the card
    // fresh) keeps it open. Nested <details> (task board, logs, output files) carry neither class.
    var root = d.getAttribute('data-root');
    if(d.open) _openProjects.add(root); else _openProjects.delete(root);
  }
}, true);
document.getElementById('broadcast-btn').addEventListener('click', async function(){
  var text = window.prompt('Broadcast a message to every ACTIVE session (queued for an agent to drain -- not injected immediately):');
  if(!text) return;
  var btn = this, resultEl = document.getElementById('broadcast-result');
  btn.disabled = true;
  try {
    var res = await (await fetch('/api/sessions/broadcast', {
      method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({text: text}),
    })).json();
    showActionResult(resultEl, res.ok ? ('queued to ' + res.count + ' active session' + (res.count === 1 ? '' : 's')) : (res.error || 'failed'), !!res.ok);
  } catch(e) {
    showActionResult(resultEl, 'request failed', false);
    console.error('broadcast failed', e);
  } finally {
    btn.disabled = false;
  }
});
document.getElementById('cards').addEventListener('click', async function(ev){
  var btn = ev.target.closest('button[data-action="message"]');
  if(!btn) return;
  ev.preventDefault();   // the button lives in a card <summary>; don't let the click toggle the card
  ev.stopPropagation();
  var text = window.prompt('Message to queue for this session (an agent with ccd_session_mgmt drains it on demand -- this does not inject it immediately):');
  if(!text) return;
  var sum = btn.closest('.csum');
  var resultEl = sum ? sum.querySelector('.action-result') : null;
  btn.disabled = true;
  try {
    var res = await (await fetch('/api/sessions/action', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({sessionId: btn.dataset.sid, text: text}),
    })).json();
    showActionResult(resultEl, res.ok ? 'queued' : (res.error || 'failed'), !!res.ok);
  } catch(e) {
    showActionResult(resultEl, 'request failed', false);
    console.error('session dispatch failed', e);
  } finally {
    btn.disabled = false;
  }
});

// Show a real backend result in the row, animating it in cleanly via the .shown/@starting-style
// pair (toggling the class off then on next frame re-triggers the entry transition on repeat clicks).
function showActionResult(resultEl, text, ok){
  if(!resultEl) return;
  resultEl.textContent = text;
  resultEl.style.color = ok ? 'var(--active)' : 'var(--blocked)';
  resultEl.classList.remove('shown');
  void resultEl.offsetWidth;  // reflow so removing then re-adding .shown restarts the entry anim
  resultEl.classList.add('shown');
}

document.getElementById('servers-list').addEventListener('click', async function(ev){
  var btn = ev.target.closest('button[data-action]');
  if(!btn) return;
  var action = btn.dataset.action;
  var name = btn.dataset.name || 'this server';
  // Confirm-before-Stop is preserved exactly; nothing optimistic happens until it is accepted.
  if(action === 'stop' && !window.confirm('Stop ' + name + ' on :' + btn.dataset.port + '? This kills the OS process.')) return;
  var srow = btn.closest('.srow');
  var resultEl = srow.querySelector('.action-result');
  var badge = srow.querySelector('.sbadge');
  var wasRunning = action === 'stop';          // the state the row is springing AWAY from
  var targetRunning = action === 'start';       // the optimistic state we spring TOWARD

  // Optimistic move: repaint the badge to the target state and spring it, mark the row in-flight so
  // the shimmer runs, and silently guard against a double-fire (no dead text-swap on the button).
  setBadgeState(badge, targetRunning);
  springBadge(badge);
  srow.classList.add('inflight');
  btn.disabled = true;
  if(resultEl){ resultEl.classList.remove('shown'); resultEl.textContent = ''; }

  var res;
  try {
    var url = action === 'start' ?
      '/api/servers/start?id=' + encodeURIComponent(btn.dataset.id) :
      '/api/servers/stop?port=' + encodeURIComponent(btn.dataset.port);
    res = await (await fetch(url, {method: 'POST'})).json();
  } catch(e) {
    res = {ok: false, error: 'request failed'};
    console.error('server action request failed', e);
  }
  srow.classList.remove('inflight');

  if(res.ok){
    // Success: the optimistic badge state stands; just confirm it inline.
    showActionResult(resultEl, action === 'start' ? 'started' : 'stopped', true);
  } else {
    // Failure: the optimism must never desync from the real backend result — spring the badge back
    // to where it actually still is, then show the error.
    setBadgeState(badge, wasRunning);
    springBadge(badge);
    showActionResult(resultEl, res.error || 'failed', false);
    console.error('server action failed', res.error);
  }
  // The next real refresh is authoritative and reconciles the optimistic view with true backend
  // state either way (this is the desync backstop the whole optimistic layer sits on top of).
  await sleep(900);
  await refreshServers();
});

// ---- sort-by-date toggle (Kanban columns, persisted across reloads) ----------------------
var _sortToggleEl = document.getElementById('sort-by-date');
_sortByDate = localStorage.getItem('kanbanSortByDate') === '1';
_sortToggleEl.checked = _sortByDate;
_sortToggleEl.addEventListener('change', function(){
  _sortByDate = _sortToggleEl.checked;
  localStorage.setItem('kanbanSortByDate', _sortByDate ? '1' : '0');
  renderBoard(); // instant re-render from cached data (projects + sessions), no re-fetch needed
});

// ---- show-inactive toggle (Douglas, 2026-07-06: "put it in an inactive classification and don't
// show it on my dashboard... it can be a toggle") - default OFF, same persist-and-instant-rerender
// pattern as sort-by-date. Nothing is archived or written to disk; this is a pure client-side filter
// on lastActivityTs, so a card flips back into view the instant it has real activity again.
var _inactiveToggleEl = document.getElementById('show-inactive');
_showInactive = localStorage.getItem('kanbanShowInactive') === '1';
_inactiveToggleEl.checked = _showInactive;
_inactiveToggleEl.addEventListener('change', function(){
  _showInactive = _inactiveToggleEl.checked;
  localStorage.setItem('kanbanShowInactive', _showInactive ? '1' : '0');
  renderBoard();
});

// ---- column visibility toggle (Douglas, 2026-07-06: "toggle which columns you have on and the
// columns auto-adjust") - display:none on a hidden .kcol removes it from the flex layout entirely,
// so the remaining visible columns grow to fill the freed space for free; no manual width math needed.
var _hiddenColumns = new Set(JSON.parse(localStorage.getItem('kanbanHiddenColumns') || '[]'));
function applyColumnVisibility(){
  document.querySelectorAll('.col-toggle-btn').forEach(function(btn){
    var key = btn.dataset.col;
    var hidden = _hiddenColumns.has(key);
    btn.setAttribute('aria-pressed', hidden ? 'false' : 'true');
    var colEl = document.querySelector('.kcol[data-col="' + key + '"]');
    if(colEl) colEl.classList.toggle('col-hidden', hidden);
  });
}
applyColumnVisibility();
document.querySelectorAll('.col-toggle-btn').forEach(function(btn){
  btn.addEventListener('click', function(){
    var nowPressed = btn.getAttribute('aria-pressed') !== 'true'; // clicking flips current state
    if(nowPressed) _hiddenColumns.delete(btn.dataset.col); else _hiddenColumns.add(btn.dataset.col);
    localStorage.setItem('kanbanHiddenColumns', JSON.stringify(Array.from(_hiddenColumns)));
    applyColumnVisibility();
  });
});

// ---- archive / unarchive --------------------------------------------------------------------
// Archive is a simple fire-and-forget action (not a live-polled control like server start/stop),
// so the safe, simple move is: POST, then let the ALREADY-hardened refresh()/reconcileCards() path
// pull the card out of the board — no bespoke optimistic DOM surgery that could reintroduce a race.
document.getElementById('cards').addEventListener('click', async function(ev){
  var btn = ev.target.closest('button[data-action="archive"]');
  if(!btn) return;
  // The archive icon lives inside the card's <summary>; without this a click would ALSO toggle the
  // card open/closed. preventDefault stops the disclosure toggle; stopPropagation keeps it off the
  // summary. Don't overwrite the button's contents (it's now an SVG icon) — just disable it; refresh()
  // pulls the archived card off the board a beat later anyway.
  ev.preventDefault();
  ev.stopPropagation();
  btn.disabled = true;
  try {
    await fetch('/api/longruns/archive?root=' + encodeURIComponent(btn.dataset.root), {method: 'POST'});
  } catch(e) { console.error('archive request failed', e); }
  await refresh();
});

function archivedRowHtml(c){
  return '<div class="archived-row" data-root="' + esc(c.root) + '">' +
    '<span class="aname">' + esc(projectName(c.root)) + ' <span class="badge ' + esc(c.status) + '">' + esc(c.status) + '</span></span>' +
    '<button type="button" data-action="unarchive" data-root="' + esc(c.root) + '">Unarchive</button></div>';
}

// The archived panel is collapsed by default and rarely touched, so it deliberately does NOT join
// the periodic poll loop below — it only fetches when opened, which sidesteps the whole class of
// poll-vs-click race this dashboard has already been bitten by twice (see reconcileServers /
// _serversFetchSeq above). A plain rebuild on open, and a direct row removal on Unarchive, are both
// safe here precisely because nothing else is concurrently mutating this list underneath them.
var _archivedPanel = document.getElementById('archived-panel');
async function refreshArchived(){
  var host = document.getElementById('archived-list');
  try {
    var archived = await (await fetch('/api/longruns/archived')).json();
    host.innerHTML = archived.length ?
      archived.map(archivedRowHtml).join('') :
      '<p class="empty">nothing archived</p>';
  } catch(e) { console.error('archived refresh failed', e); }
}
_archivedPanel.addEventListener('toggle', function(){ if(_archivedPanel.open) refreshArchived(); });
document.getElementById('archived-list').addEventListener('click', async function(ev){
  var btn = ev.target.closest('button[data-action="unarchive"]');
  if(!btn) return;
  btn.disabled = true;
  btn.textContent = '...';
  try {
    await fetch('/api/longruns/unarchive?root=' + encodeURIComponent(btn.dataset.root), {method: 'POST'});
    var row = btn.closest('.archived-row');
    if(row) row.remove();
    if(!document.querySelector('#archived-list .archived-row')){
      document.getElementById('archived-list').innerHTML = '<p class="empty">nothing archived</p>';
    }
  } catch(e) { console.error('unarchive request failed', e); btn.disabled = false; btn.textContent = 'Unarchive'; return; }
  await refresh(); // the un-archived board reappears on the kanban immediately, not after 6s
});

// ---- skills run per project ---------------------------------------------------------------
// Relative age of an ISO timestamp, reusing fmtAge (which takes epoch seconds). Bad/absent -> ''.
function skillAge(ts){ var t = ts ? Date.parse(ts) : NaN; return isNaN(t) ? '' : fmtAge(t/1000); }
// Absolute local date+time of an ISO timestamp, for "see when that skill was run" on hover.
function skillWhen(ts){ var d = ts ? new Date(ts) : null; return (d && !isNaN(d)) ? d.toLocaleString() : ''; }
function skillsPanelHtml(data){
  if(!data || !data.projects || !data.projects.length) return '<p class="empty">no tracked skills run yet</p>';
  var master = data.master;
  return data.projects.map(function(p){
    var ran = 0;
    var chips = master.map(function(m){
      var info = p.skills[m.key];
      if(info){
        ran++;
        var age = skillAge(info.lastTs);
        var when = skillWhen(info.lastTs);
        var tip = m.key + ' — ' + info.count + ' run' + (info.count > 1 ? 's' : '') +
          (when ? ' · last run ' + when + (age ? ' (' + age + ')' : '') : '');
        return '<span class="skillchip on" title="' + esc(tip) + '">' + esc(m.label) + '<span class="skn">' + info.count + '</span></span>';
      }
      return '<span class="skillchip off" title="' + esc(m.key + ' — not run in this project') + '">' + esc(m.label) + '</span>';
    }).join('');
    return '<div class="skillrow"><div class="skillrow-head"><span class="skillproj">' + esc(projectName(p.root)) +
      '</span><span class="skillcov" title="skills run / master list">' + ran + '/' + master.length + '</span></div>' +
      '<div class="skillchips">' + chips + '</div></div>';
  }).join('');
}
async function refreshSkills(){
  var host = document.getElementById('skills-list');
  if(!host) return;
  try {
    var data = await (await fetch('/api/skills')).json();
    host.innerHTML = skillsPanelHtml(data);  // static display, no per-poll interactive state to preserve
  } catch(e) { console.error('skills refresh failed', e); }
}

// ---- vertical tab switching (icon rail) ----------------------------------------------------
(function(){
  var rail = document.querySelector('.tabrail');
  var panels = Array.prototype.slice.call(document.querySelectorAll('.tabpanel'));
  function show(tab){
    Array.prototype.slice.call(document.querySelectorAll('.tab-btn')).forEach(function(b){
      b.setAttribute('aria-selected', b.getAttribute('data-tab') === tab ? 'true' : 'false');
    });
    panels.forEach(function(p){ p.hidden = (p.getAttribute('data-panel') !== tab); });
    try { localStorage.setItem('dashActiveTab', tab); } catch(e){}
    renderHeaderStrip();  // memory clause hides/shows immediately on switching to/from the Memory tab
  }
  rail.addEventListener('click', function(ev){
    var b = ev.target.closest('.tab-btn');
    if(b) show(b.getAttribute('data-tab'));
  });
  var saved = 'cards';
  try { saved = localStorage.getItem('dashActiveTab') || 'cards'; } catch(e){}
  if(!document.querySelector('.tabpanel[data-panel="' + saved + '"]')) saved = 'cards';
  show(saved);
})();
// The "?" help popover is a native <details>, which only closes when its own summary is clicked.
// Add normal popover dismissal: a click outside it, or Escape, closes it.
(function(){
  var help = document.querySelector('details.help');
  if(!help) return;
  document.addEventListener('click', function(ev){ if(help.open && !help.contains(ev.target)) help.open = false; });
  document.addEventListener('keydown', function(ev){ if(ev.key === 'Escape' && help.open) help.open = false; });
})();
// ---- live "time since last message" ticker on session cards --------------------------------
// Updates every second so the elapsed on each session card visibly moves between the 10s polls.
setInterval(function(){
  Array.prototype.slice.call(document.querySelectorAll('.stimer')).forEach(function(el){
    var ts = +el.getAttribute('data-ts');
    if(ts) el.textContent = fmtElapsed(ts);
  });
}, 1000);

refresh();
refreshServers();
refreshDiscovered();
refreshSessions();
refreshSkills();
setInterval(refresh, 6000);
setInterval(refreshServers, 6000);
setInterval(refreshDiscovered, 15000);  // a live netstat+PowerShell scan is heavier than the other polls
setInterval(refreshSessions, 10000);  // transcript scan across every project; not as cheap as a poll on one file
setInterval(refreshSkills, 30000);  // incremental + disk-cached, but only the active transcript changes between polls
refreshMemory();
setInterval(refreshMemory, 20000);  // live PowerShell/CIM shell-out each poll - same cost class as Discovered
refreshUsage();
setInterval(refreshUsage, 60000);  // reads existing files (cheap), but the source data itself only
                                    // changes when a usage:sample run happens - no need to poll fast
// Chrome throttles setInterval hard in an occluded/background tab (can drop to ~once/minute) —
// exactly the "I don't see it updating" symptom for a dashboard left in a background tab while
// working elsewhere. Force an immediate catch-up refresh the moment the tab regains visibility
// or focus, rather than waiting for the next (possibly throttled) interval tick.
document.addEventListener('visibilitychange', function(){ if(!document.hidden){ refresh(); refreshServers(); refreshDiscovered(); refreshSessions(); refreshSkills(); refreshMemory(); refreshUsage(); } });
window.addEventListener('focus', function(){ refresh(); refreshServers(); refreshDiscovered(); refreshSessions(); refreshSkills(); refreshMemory(); refreshUsage(); });
</script>
</body>
</html>
"""


# ---- self-test --------------------------------------------------------------------
def self_test():
    ok = 0
    total = 0

    # 1) parse_checklist: BLOCKED keyword in an otherwise-open item recategorizes it
    total += 1
    counts = parse_checklist("- [ ] Component 07: multi-source fusion — BLOCKED on new data\n- [ ] Track A: extend test\n")
    assert counts == {"x": 0, "open": 1, "wip": 0, "parked": 0, "blocked": 1}, \
        "an open item whose text says BLOCKED must be counted as blocked, not open: got %r" % counts
    ok += 1; print("  PASS parse_checklist: BLOCKED keyword recategorizes an open item")

    # 2) current_item_conflict: current item text already checked off in the task board -> flagged
    total += 1
    tb_done = {"items": [{"marker": "x", "text": "T0-6: merge_worst_case inconsistent (B1)"}], "counts": {}}
    conflict = current_item_conflict("T0-6 merge_worst_case inconsistent (B1) — worst-case merge logic disagrees", tb_done)
    assert conflict is not None and "T0-6" in conflict, \
        "a current item already marked done in the task board must be flagged: got %r" % conflict
    ok += 1; print("  PASS current_item_conflict: flags an item already done in the live task board")

    total += 1
    tb_open = {"items": [{"marker": " ", "text": "T0-6: merge_worst_case inconsistent (B1)"}], "counts": {}}
    conflict2 = current_item_conflict("T0-6 merge_worst_case inconsistent (B1)", tb_open)
    assert conflict2 is None, "a current item still open in the task board must NOT be flagged: got %r" % conflict2
    ok += 1; print("  PASS current_item_conflict: no false positive when the item is genuinely still open")

    total += 1
    conflict3 = current_item_conflict(None, tb_done)
    assert conflict3 is None, "no current item text at all must not crash or false-flag: got %r" % conflict3
    ok += 1; print("  PASS current_item_conflict: no crash / no false positive with no current item text")

    # 3) freshness_note: a big mtime gap between the two sources names the staler one
    total += 1
    now = 2_000_000_000.0
    note = freshness_note(now, now - 3600, now)
    assert note is not None and note["stalerSource"] == "taskboard", \
        "task board mtime is an hour older -> it must be flagged stale: got %r" % note
    ok += 1; print("  PASS freshness_note: flags the older source when the gap is large")

    total += 1
    note2 = freshness_note(now - 3600, now, now)
    assert note2 is not None and note2["stalerSource"] == "checklist", \
        "checklist mtime is an hour older -> it must be flagged stale: got %r" % note2
    ok += 1; print("  PASS freshness_note: flags checklist as stale when IT is the older one")

    total += 1
    note3 = freshness_note(now, now - 30, now)
    assert note3 is None, "a 30s gap is normal edit-order noise, must not be flagged: got %r" % note3
    ok += 1; print("  PASS freshness_note: no false positive on a small, normal gap")

    total += 1
    note4 = freshness_note(None, now, now)
    assert note4 is None, "a missing mtime must not crash or produce a bogus note: got %r" % note4
    ok += 1; print("  PASS freshness_note: no crash when one mtime is unavailable")

    # 4) plain_project_status: dormant vs continuing based on real recent file activity
    total += 1
    st, _ = plain_project_status({"x": 1, "open": 2, "wip": 0}, now - 60, now)
    assert st == "continuing", "an output file touched 60s ago with open items left must read as continuing: got %r" % st
    ok += 1; print("  PASS plain_project_status: recent activity + open items -> continuing")

    total += 1
    st2, _ = plain_project_status({"x": 1, "open": 2, "wip": 0}, now - 3 * 3600, now)
    assert st2 == "dormant", \
        "an output file untouched for 3 hours with open items left must read as dormant, not continuing: got %r" % st2
    ok += 1; print("  PASS plain_project_status: stale activity + open items -> dormant, not continuing")

    total += 1
    st3, _ = plain_project_status({"x": 5, "open": 0, "wip": 0}, now - 3 * 3600, now)
    assert st3 == "finished", "no open/wip items left must read as finished regardless of activity recency: got %r" % st3
    ok += 1; print("  PASS plain_project_status: no open items -> finished, independent of activity recency")

    total += 1
    st4, _ = plain_project_status({"x": 1, "open": 1, "wip": 0}, None, now)
    assert st4 == "unknown", "no output file at all means we genuinely can't tell -> unknown, not continuing: got %r" % st4
    ok += 1; print("  PASS plain_project_status: no mtime signal at all -> honest unknown, not a false continuing")

    # 5) find_cross_reference: a plain project root that a longrun card is actively writing into
    total += 1
    longrun_cards = [{"kind": "longrun", "root": "C:\\W", "outputFiles": ["C:\\W\\sub\\STATUS.md", "C:\\W\\sub\\LOG.md"]}]
    xref = find_cross_reference("C:\\W\\sub", longrun_cards)
    assert xref == "C:\\W", \
        "a plain project whose files are being written by an active longrun card must cross-reference it: got %r" % xref
    ok += 1; print("  PASS find_cross_reference: detects an active longrun writing into this exact project folder")

    total += 1
    xref2 = find_cross_reference("C:\\Unrelated", longrun_cards)
    assert xref2 is None, "an unrelated project must not get a false cross-reference: got %r" % xref2
    ok += 1; print("  PASS find_cross_reference: no false positive for an unrelated root")

    total += 1
    xref3 = find_cross_reference("C:\\W2\\subproject", longrun_cards)
    assert xref3 is None, \
        "a root that merely shares a text prefix with an unrelated path must NOT false-match: got %r" % xref3
    ok += 1; print("  PASS find_cross_reference: a shared string prefix alone is not a match (path-boundary safe)")

    # 5b) extract_add_dirs + find_cross_reference via addDirs: the sme-tacit-frames case found
    #     live 2026-07-02 - the session's OWN tracked output files (STATUS/LOG/WORK_QUEUE) live
    #     under the workspace root's .claude/state/ dir, nowhere near the project folder whose
    #     actual work (retrieval_agent.py etc) it's driving via `--add-dir`, so the outputFiles-
    #     only check above can't catch this case at all - only the add-dir path can.
    total += 1
    dirs = extract_add_dirs(
        'bash gen-claude.sh --resume abc123 --add-dir "C:\\Users\\x\\sme-tacit-frames" -p "hi"')
    assert dirs == ["C:\\Users\\x\\sme-tacit-frames"], \
        "must extract the --add-dir path out of a resume-cmd script: got %r" % dirs
    ok += 1; print("  PASS extract_add_dirs: pulls --add-dir paths out of a resume-cmd script")

    total += 1
    longrun_with_adddir = [{"kind": "longrun", "root": "C:\\Workspace",
                             "outputFiles": ["C:\\Workspace\\.claude\\state\\p\\STATUS.md"],
                             "addDirs": ["C:\\Workspace\\sme-tacit-frames"]}]
    xref4 = find_cross_reference("C:\\Workspace\\sme-tacit-frames", longrun_with_adddir)
    assert xref4 == "C:\\Workspace", \
        "a project only reachable via --add-dir (not shared output files) must still cross-reference: got %r" % xref4
    ok += 1; print("  PASS find_cross_reference: also matches via a session's --add-dir path, not just output files")

    # 6) derive_status: a completion-token line means finished, not unknown
    total += 1
    status, detail = derive_status({}, "... ALLOW  completion-promise loop: completion token detected — done", None)
    assert status == "finished", "a completion-token log line must read as finished, not unknown: got %r" % status
    ok += 1; print("  PASS derive_status: recognizes a completion-token line as finished")

    # 7) last_log_line_any: when a ralph-loop's session_id can't be resolved (found live
    #    2026-07-02 on Text-to-Spaceship: a .longrun flag with no session_id in its
    #    ralph-loop.local.md), last_log_line_for(log, None) can't filter by sid and returns
    #    None even though the log clearly has a final line - fall back to the log's real last
    #    line, sid-unfiltered, rather than reporting no signal at all.
    total += 1
    import tempfile
    tmp = tempfile.mkdtemp()
    try:
        log_path = os.path.join(tmp, "keep-going.log")
        with open(log_path, "w", encoding="utf-8") as f:
            f.write("2026-07-02T10:00:00Z sid=aaa ALLOW  no queue/task file for this session\n")
            f.write("2026-07-02T21:38:21Z sid=bbb ALLOW  completion-promise loop: completion token detected — done\n")
        assert last_log_line_for(log_path, None) is None, \
            "sanity: the existing sid-filtered lookup genuinely can't work with no sid"
        line = last_log_line_any(log_path)
        assert line is not None and "completion token detected" in line, \
            "with no resolvable sid, the fallback must still surface the log's real last line: got %r" % line
    finally:
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)
    ok += 1; print("  PASS last_log_line_any: sid-unfiltered fallback surfaces the real last line when sid is unresolvable")

    # 8) load_server_configs: merges every root's launch.json configurations into one flat
    #    list, each carrying its own root as cwd (relative runtimeArgs directories, like
    #    truss-forge-preview's "truss-forge", only resolve if launched from the right cwd).
    total += 1
    import tempfile, shutil
    tmp = tempfile.mkdtemp()
    try:
        root_a = os.path.join(tmp, "rootA")
        root_b = os.path.join(tmp, "rootB")
        root_c = os.path.join(tmp, "rootC_no_launch_json")
        sub_dir = os.path.join(root_a, "subproj")
        os.makedirs(os.path.join(root_a, ".claude"))
        os.makedirs(os.path.join(root_b, ".claude"))
        os.makedirs(root_c)
        os.makedirs(sub_dir)
        with open(os.path.join(root_a, ".claude", "launch.json"), "w", encoding="utf-8") as f:
            json.dump({"configurations": [
                {"name": "server-a", "port": 9001,
                 "runtimeExecutable": "python", "runtimeArgs": ["-m", "http.server", "9001"]},
                # A config with its OWN cwd override (e.g. cad-forge-live-server's real launch.json
                # entry, which points at a subdirectory of the scanned root) - found live 2026-07-06:
                # load_server_configs used to hard-code cwd=root for every config regardless of this
                # field, so this server's script was launched from the wrong directory and died
                # instantly ("can't open file ...\\live_server.py") - reported as "stopped" with no
                # clue why, since the real error only ever reached the per-port launch log.
                {"name": "server-a-subdir", "port": 9002,
                 "runtimeExecutable": "python", "runtimeArgs": ["script.py"], "cwd": sub_dir},
                # A config with an `openPath` whose useful page isn't the bare root (e.g. the truss
                # dashboard's /dashboard/truss-dashboard.html) - must propagate to the server object
                # so the "open" link lands on the real page. A path missing its leading slash is
                # normalized to have one.
                {"name": "server-a-openpath", "port": 9003,
                 "runtimeExecutable": "python", "runtimeArgs": ["s.py"], "openPath": "dashboard/x.html"},
            ]}, f)
        with open(os.path.join(root_b, ".claude", "launch.json"), "w", encoding="utf-8") as f:
            f.write("{ not valid json ]")  # malformed - must be skipped, not crash the whole load
        old_load_roots = globals()["load_roots"]
        try:
            globals()["load_roots"] = lambda: [root_a, root_b, root_c]
            configs = load_server_configs()
        finally:
            globals()["load_roots"] = old_load_roots
        names = [c["name"] for c in configs]
        assert names == ["server-a", "server-a-subdir", "server-a-openpath"], \
            "must include all of root A's real configs, skip root B's malformed json and root C's missing file: got %r" % names
        assert configs[0]["cwd"] == root_a, \
            "a config with NO cwd override must carry its own root as cwd so relative paths resolve: got %r" % configs[0]["cwd"]
        assert configs[0]["port"] == 9001
        assert configs[1]["cwd"] == sub_dir, \
            "a config's OWN cwd override must be honored, not silently replaced by the scan root: got %r" % configs[1]["cwd"]
        assert configs[0]["openPath"] is None, \
            "a config with no openPath must carry openPath=None (link falls back to bare root): got %r" % configs[0]["openPath"]
        assert configs[2]["openPath"] == "/dashboard/x.html", \
            "openPath must propagate and be normalized to a leading slash: got %r" % configs[2]["openPath"]
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    ok += 1; print("  PASS load_server_configs: merges valid configs, skips malformed JSON and missing files, keeps cwd + normalized openPath")

    # 9) port_listening: real socket, no mocks - bind a real port, confirm it reads as running,
    #    close it, confirm it reads as not running.
    total += 1
    probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    probe.bind(("127.0.0.1", 0))
    free_port = probe.getsockname()[1]
    probe.listen(1)
    try:
        assert port_listening(free_port) is True, "a genuinely bound+listening port must read as running"
    finally:
        probe.close()
    assert port_listening(free_port) is False, "after closing the socket the port must read as not running"
    ok += 1; print("  PASS port_listening: true positive on a real bound port, true negative after closing it")

    # 10) checklist_says_finished + status override: found live 2026-07-02 - a5056bdb's own
    #     WORK_QUEUE went to 7/7 done via work completed OUTSIDE the tracked keep-going/resume
    #     mechanism (a headless resume attempt hallucinated "queue already empty" and did
    #     nothing real; the actual work was done directly in the main session instead), so the
    #     keep-going log's last entry stayed a stale BLOCK/no-followup-activity signal even
    #     though the checklist itself is unambiguous, stronger evidence of real completion.
    total += 1
    assert checklist_says_finished({"x": 7, "open": 0, "wip": 0, "parked": 0, "blocked": 0}) is True
    assert checklist_says_finished({"x": 0, "open": 7, "wip": 0, "parked": 0, "blocked": 0}) is False
    assert checklist_says_finished({"x": 3, "open": 0, "wip": 1, "parked": 0, "blocked": 0}) is False
    assert checklist_says_finished({"x": 0, "open": 0, "wip": 0, "parked": 0, "blocked": 0}) is False, \
        "an EMPTY checklist (nothing ever tracked) must not be confused with a completed one"
    ok += 1; print("  PASS checklist_says_finished: true only when items exist AND none remain open/wip")

    total += 1
    assert override_status_if_checklist_finished("stalled", {"x": 7, "open": 0, "wip": 0}) == "finished", \
        "a fully-checked-off WORK_QUEUE must override a stale stalled/continuing/idle/unknown status"
    assert override_status_if_checklist_finished("blocked", {"x": 7, "open": 0, "wip": 0}) == "blocked", \
        "an explicit .need-user sentinel (blocked) must NOT be overridden by checklist completion"
    assert override_status_if_checklist_finished("stopped", {"x": 7, "open": 0, "wip": 0}) == "stopped", \
        "an explicit stop sentinel must NOT be overridden by checklist completion"
    assert override_status_if_checklist_finished("continuing", {"x": 2, "open": 5, "wip": 0}) == "continuing", \
        "an incomplete checklist must never be overridden to finished"
    ok += 1; print("  PASS override_status_if_checklist_finished: overrides only the activity-derived "
                   "statuses, never an explicit sentinel state or a genuinely incomplete checklist")

    # 11) resolve_current_item: WORK_QUEUE saying "nothing left" must not fall through to a
    #     possibly-stale CURRENT-TASK task-board mirror (found live 2026-07-02: a5056bdb's
    #     WORK_QUEUE went to 7/7 done, but its own CURRENT-TASK mirror still showed phase-2's
    #     "Component 03 in progress" line, which the old fallback logic surfaced as if current).
    total += 1
    wq_all_done = "- [x] one\n- [x] two\n"
    ct_stale = "- [~] an old phase-2 item still shown here\n"
    assert resolve_current_item(wq_all_done, ct_stale) is None, \
        "WORK_QUEUE with nothing open/wip must win over a stale CURRENT-TASK snapshot: got %r" \
        % resolve_current_item(wq_all_done, ct_stale)
    wq_has_open = "- [x] one\n- [ ] two\n"
    assert resolve_current_item(wq_has_open, ct_stale) == "two", \
        "WORK_QUEUE's own open item must still be used when it has one"
    assert resolve_current_item(None, ct_stale) == "an old phase-2 item still shown here", \
        "with NO WORK_QUEUE at all, falling back to CURRENT-TASK is correct (only signal available)"
    ok += 1; print("  PASS resolve_current_item: WORK_QUEUE's own 'nothing left' wins over a stale mirror")

    # 12) wait_for_server_start (Long-run #7): a real bound port is detected promptly; a port
    # that never opens correctly times out and returns False rather than hanging.
    total += 1
    probe2 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    probe2.bind(("127.0.0.1", 0))
    free_port2 = probe2.getsockname()[1]
    probe2.listen(1)
    try:
        assert wait_for_server_start(free_port2, timeout=2, interval=0.05) is True, \
            "a port that's already listening must be detected promptly, not time out"
    finally:
        probe2.close()
    never_port = free_port2  # now closed - guaranteed nothing listens here
    assert wait_for_server_start(never_port, timeout=0.3, interval=0.05) is False, \
        "a port that never opens must time out and return False, not hang forever"
    ok += 1; print("  PASS wait_for_server_start: detects a real listening port promptly, times out cleanly when nothing opens")

    # 13) is_protected_port (2026-07-03 adversarial review, CRITICAL): the dashboard's own port
    # (or any other currently-listening tracked server, e.g. mid-request) must never be
    # stoppable via its own /api/servers/stop endpoint just because it happens to also appear in
    # a launch.json - verified live: POST /api/servers/stop?port=8756 actually killed the
    # dashboard process serving that very request.
    total += 1
    assert is_protected_port(8756, own_port=8756) is True, \
        "the dashboard's own listening port must always be protected from its own stop endpoint"
    assert is_protected_port(8790, own_port=8756) is False, \
        "a DIFFERENT tracked server's port must still be stoppable normally"
    ok += 1; print("  PASS is_protected_port: the dashboard can never be told to kill its own port")

    # 13b) plain_project_status must not report finished while parked/blocked items remain
    # either (same bug, other function - 2026-07-03 solo-review HIGH).
    total += 1
    st5, detail5 = plain_project_status({"x": 37, "open": 0, "wip": 0, "parked": 2, "blocked": 2}, now, now)
    assert st5 != "finished", \
        "parked/blocked items remaining must not read as finished in the plain-project path either: got %r" % st5
    ok += 1; print("  PASS plain_project_status: parked/blocked items also block a false 'finished' verdict")

    # 14) checklist_says_finished must not report finished while parked/blocked items remain
    # (2026-07-03 solo-review, HIGH x2: verified live on sme-tacit-frames - 0 open/wip but 2
    # parked + 2 blocked items, real needs-Douglas decisions, still read "finished").
    total += 1
    assert checklist_says_finished({"x": 37, "open": 0, "wip": 0, "parked": 2, "blocked": 0}) is False, \
        "parked (needs-Douglas) items remaining must NOT count as fully finished"
    assert checklist_says_finished({"x": 37, "open": 0, "wip": 0, "parked": 0, "blocked": 2}) is False, \
        "blocked items remaining must NOT count as fully finished"
    assert checklist_says_finished({"x": 37, "open": 0, "wip": 0, "parked": 0, "blocked": 0}) is True, \
        "genuinely zero remaining items of any kind must still count as finished"
    ok += 1; print("  PASS checklist_says_finished: parked/blocked items block the 'finished' override, matching the real sme-tacit-frames case")

    # 15) resolve_session_id_for_state_dir (2026-07-03 solo-review, CRITICAL): when
    # ralph-loop.local.md is missing/has no session_id, derive sid from the state dir's own
    # WORK_QUEUE/CURRENT-TASK filenames instead of going fully blank - verified live: Text-to-
    # Spaceship has no ralph-loop.local.md at all, yet its state dir holds a real, current,
    # needs-Douglas WORK_QUEUE the dashboard was silently never reading.
    total += 1
    tmp13 = tempfile.mkdtemp()
    try:
        assert resolve_session_id_for_state_dir(tmp13) is None, \
            "an empty state dir has no sid to recover - must return None, not crash"
        open(os.path.join(tmp13, "WORK_QUEUE.sid-old.md"), "w").close()
        os.utime(os.path.join(tmp13, "WORK_QUEUE.sid-old.md"), (1000, 1000))
        assert resolve_session_id_for_state_dir(tmp13) == "sid-old", \
            "a single WORK_QUEUE.<sid>.md must have its sid recovered"
        open(os.path.join(tmp13, "WORK_QUEUE.sid-new.md"), "w").close()
        os.utime(os.path.join(tmp13, "WORK_QUEUE.sid-new.md"), (2000, 2000))
        assert resolve_session_id_for_state_dir(tmp13) == "sid-new", \
            "with multiple candidates, the MOST RECENTLY MODIFIED one must win, not an arbitrary one"
    finally:
        shutil.rmtree(tmp13, ignore_errors=True)
    ok += 1; print("  PASS resolve_session_id_for_state_dir: recovers a real sid from state-dir filenames when ralph-loop.local.md can't provide one")

    # 16) parse_task_board must not be vulnerable to catastrophic regex backtracking (2026-07-03
    # adversarial review, HIGH: verified live - a crafted 200KB CURRENT-TASK.md with many
    # repeated unterminated "<!-- TASKS:AUTO START" fragments made a single /api/longruns
    # request take 8.97s). A real board still parses correctly (positive control).
    total += 1
    import time as _t
    adversarial = "<!-- TASKS:AUTO START" * 8000  # ~176KB, matches the live-reproduced 200KB case
    t0 = _t.time()
    result = parse_task_board(adversarial)
    elapsed = _t.time() - t0
    assert elapsed < 2.0, \
        "parse_task_board must not catastrophically backtrack on many unterminated START markers - took %.2fs" % elapsed
    assert result is None, "no closing END marker anywhere -> no board found, not a crash"
    real_board = ("<!-- TASKS:AUTO START (mirrored) -->\n"
                  "- [x] done item\n- [ ] open item\n"
                  "<!-- TASKS:AUTO END -->\n")
    real_result = parse_task_board(real_board)
    assert real_result is not None and len(real_result["items"]) == 2, \
        "a genuine, well-formed task board must still parse correctly: got %r" % real_result
    ok += 1; print("  PASS parse_task_board: immune to catastrophic backtracking, still parses a real board correctly")

    # 17) StartLock: a TOCTOU race on /api/servers/start let concurrent requests all pass the
    # port_listening() check before any of them finished launching, spawning duplicate untracked
    # orphan processes (2026-07-03 adversarial review, HIGH: verified live - 5 concurrent start
    # requests for the same config produced 5 independently-listening processes on the same
    # port; a single stop call only killed 1, leaving 4 invisible zombies). Real threads, no mocks.
    total += 1
    import threading as _threading
    lock17 = StartLock()
    results = []
    results_mu = _threading.Lock()
    def claim_worker():
        got = lock17.try_acquire(9999)
        with results_mu:
            results.append(got)
        if got:
            _t.sleep(0.2)  # hold the claim briefly, like a real launch would
            lock17.release(9999)
    threads = [_threading.Thread(target=claim_worker) for _ in range(5)]
    for th in threads: th.start()
    for th in threads: th.join(timeout=3)
    assert sum(1 for r in results if r) == 1, \
        "exactly ONE of 5 concurrent claims for the same port must succeed, not all 5: got %r" % results
    ok += 1; print("  PASS StartLock: only one of several concurrent start attempts for the same port can proceed")

    total += 1
    lock17b = StartLock()
    assert lock17b.try_acquire(1111) is True
    lock17b.release(1111)
    assert lock17b.try_acquire(1111) is True, "after release, the SAME port must be claimable again (not permanently locked)"
    lock17b.release(1111)
    ok += 1; print("  PASS StartLock: releases cleanly, a port isn't stuck locked forever")

    # 18) filter_discovered: a listening port not in any launch.json, not a low system port,
    # counts as "discovered"; an already-registered port or a system port (< 1024) does not.
    total += 1
    listening18 = [(22, 100), (8756, 200), (9123, 300), (5555, 400)]
    known18 = {8756, 8790}
    disc = filter_discovered(listening18, known18)
    assert disc == [(9123, 300), (5555, 400)], \
        "must exclude registered ports (8756) and system ports (<1024, e.g. 22): got %r" % disc
    ok += 1; print("  PASS filter_discovered: excludes registered + system ports, keeps genuinely new ones")

    # 19) parse_netstat_listening: parses a real netstat -ano-shaped text blob into (port, pid) pairs
    total += 1
    sample_netstat = (
        "\n  Proto  Local Address          Foreign Address        State           PID\n"
        "  TCP    0.0.0.0:135            0.0.0.0:0              LISTENING       900\n"
        "  TCP    127.0.0.1:8756         0.0.0.0:0              LISTENING       33964\n"
        "  TCP    0.0.0.0:9999           0.0.0.0:0              ESTABLISHED     55\n"  # not LISTENING -> excluded
        "  TCP    [::]:8790              [::]:0                 LISTENING       12345\n"
    )
    parsed = parse_netstat_listening(sample_netstat)
    assert (8756, 33964) in parsed and (9999, 55) not in parsed, \
        "must extract LISTENING TCP (port, pid) pairs and skip non-LISTENING states: got %r" % parsed
    ok += 1; print("  PASS parse_netstat_listening: extracts LISTENING (port, pid) pairs from real netstat -ano output shape")

    # 20) current_item_conflict must NOT false-positive on a short shared boilerplate clause
    # inside two otherwise-different task descriptions (2026-07-03 solo-review, MEDIUM: verified
    # live with the project's own real SR1/SR2 adjacent items - "run solo review and apply fixes"
    # is a literal 32-char substring of a much longer, unrelated done-item's text).
    total += 1
    tb_boilerplate = {"items": [{"marker": "x", "text":
        "sr1 run the solo review skill on the cad forge codebase after the gate passes sr2 run "
        "solo review and apply fixes it surfaces verify with playwright"}], "counts": {}}
    conflict20 = current_item_conflict("run solo review and apply fixes", tb_boilerplate)
    assert conflict20 is None, \
        "a short shared boilerplate clause inside a much longer, unrelated done-item must NOT " \
        "false-positive as a drifted duplicate: got %r" % conflict20
    ok += 1; print("  PASS current_item_conflict: no false positive on a short shared boilerplate clause")

    # 21) derive_status must treat an explicit "needs Douglas" phrase IN THE LOG LINE ITSELF as an
    # equal-strength blocked signal, even when no .need-user sentinel file exists (2026-07-03
    # solo-review, MEDIUM: verified live on Text-to-Spaceship - the real .keep-going.log line said
    # "needs Douglas: loosens 8 verdicts" but no .need-user.* sentinel had been dropped anywhere).
    total += 1
    label21, detail21 = derive_status({}, "2026-07-03 BLOCK 1 left; next: C1b - fastening BoJ-req "
                                       "fold-in (needs Douglas: loosens 8 verdicts)", None)
    assert label21 == "blocked", \
        "an explicit 'needs Douglas' phrase in the log line must read as blocked even with no " \
        "sentinel file: got %r / %r" % (label21, detail21)
    ok += 1; print("  PASS derive_status: 'needs Douglas' text in the log line is an equal-strength blocked signal")

    # 22) find_cross_reference must match paths that differ only in case (2026-07-03 solo-review,
    # MEDIUM: this project's own Text-to-Spaceship root is capitalized on disk while its
    # .claude/state/ subdir is keyed lowercase "text-to-spaceship" - a real, observed case
    # mismatch on the only filesystem this script runs on, which is case-insensitive).
    total += 1
    cards22 = [{"root": "C:\\W\\LiveProject", "outputFiles":
                ["c:\\w\\liveproject\\.claude\\state\\foo\\WORK_QUEUE.abc.md"], "addDirs": []}]
    xref22 = find_cross_reference("C:\\W\\LiveProject", cards22)
    assert xref22 == "C:\\W\\LiveProject", \
        "paths differing only in case (as they do in the wild on this Windows-only deployment) " \
        "must still cross-reference: got %r" % xref22
    ok += 1; print("  PASS find_cross_reference: matches paths that differ only in case (Windows is case-insensitive)")

    # 23) wait_for_port_stop must report False while a real socket is still listening, and True
    # once it's actually closed - the post-condition stop_port needs to stop reporting ok:true
    # before a taskkill actually took effect (2026-07-03 solo-review, MEDIUM: the old stop_port
    # returned True as soon as a PID was merely FOUND, never checking whether taskkill actually
    # succeeded - a permission-denied or already-exited-process failure was reported as success).
    total += 1
    probe23 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    probe23.bind(("127.0.0.1", 0))
    probe23.listen(5)
    probe_port23 = probe23.getsockname()[1]
    probe23.settimeout(0.2)
    stop_accepting23 = threading.Event()
    def _accept_loop23():
        # Real servers always drain their accept queue - without this, repeated probing connects
        # with nothing ever accepting them exhausts the OS backlog and makes port_listening()
        # falsely report "not listening" even though the socket is still bound (a test-realism
        # bug, not an implementation bug: found while writing this very test).
        while not stop_accepting23.is_set():
            try:
                conn, _ = probe23.accept()
                conn.close()
            except OSError:
                pass
    accept_thread23 = threading.Thread(target=_accept_loop23, daemon=True)
    accept_thread23.start()
    still_up23 = wait_for_port_stop(probe_port23, timeout=0.4, interval=0.1)
    assert still_up23 is False, "must report False while the port is still genuinely listening: got %r" % still_up23
    stop_accepting23.set()
    probe23.close()
    accept_thread23.join(timeout=1)
    now_down23 = wait_for_port_stop(probe_port23, timeout=2.0, interval=0.1)
    assert now_down23 is True, "must report True once the port is actually closed: got %r" % now_down23
    ok += 1; print("  PASS wait_for_port_stop: real socket-backed confirm, not a fire-and-forget guess")

    # 24) start_server_config must fail fast on a relative --directory that doesn't exist under
    # cfg['cwd'], instead of silently launching and only surfacing a generic "port never came up"
    # after the full health-check timeout (2026-07-03 solo-review, LOW).
    total += 1
    import tempfile as _tempfile
    tmp_cwd24 = _tempfile.mkdtemp()
    cfg24 = {"cwd": tmp_cwd24, "runtimeArgs": ["-m", "http.server", "--directory", "does-not-exist"]}
    missing24 = _find_missing_relative_directory(cfg24)
    assert missing24 is not None and "does-not-exist" in missing24, \
        "a relative --directory that doesn't exist under cwd must be caught before launch: got %r" % missing24
    os.makedirs(os.path.join(tmp_cwd24, "does-not-exist"))
    assert _find_missing_relative_directory(cfg24) is None, \
        "once the directory genuinely exists, it must NOT be flagged as missing"
    ok += 1; print("  PASS _find_missing_relative_directory: catches a missing relative --directory before Popen, clears once it exists")

    # 25) resolve_port_arg must turn a missing/non-numeric --port value into a clear ValueError
    # instead of letting an IndexError/bare ValueError escape main() as a raw traceback
    # (2026-07-03 solo-review, LOW).
    total += 1
    assert resolve_port_arg(["prog"]) == 8756, "no --port at all must fall back to the default"
    assert resolve_port_arg(["prog", "--port", "9001"]) == 9001, "a valid --port value must parse"
    try:
        resolve_port_arg(["prog", "--port"])
        raise AssertionError("--port with no following value must raise ValueError, not IndexError")
    except ValueError:
        pass
    try:
        resolve_port_arg(["prog", "--port", "not-a-number"])
        raise AssertionError("a non-numeric --port value must raise ValueError")
    except ValueError:
        pass
    ok += 1; print("  PASS resolve_port_arg: clear ValueError on bad/missing --port value, never a raw IndexError")

    # 26) try_bind_server must translate a genuine "port already in use" OSError into a clear
    # RuntimeError instead of letting main() crash with a raw traceback (2026-07-03 solo-review,
    # LOW) - a real occupied port, not a mock.
    total += 1
    occupied26 = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    occupied26.bind(("127.0.0.1", 0))
    occupied26.listen(1)
    occupied_port26 = occupied26.getsockname()[1]
    try:
        try_bind_server(occupied_port26, Handler)
        raise AssertionError("binding an already-occupied port must raise, not silently succeed")
    except RuntimeError as e:
        assert "already" in str(e).lower() or "in use" in str(e).lower() or str(occupied_port26) in str(e), \
            "the RuntimeError should be an actionable message naming the port/conflict: got %r" % e
    finally:
        occupied26.close()
    ok += 1; print("  PASS try_bind_server: a genuinely-occupied port raises a clear RuntimeError, not a raw OSError traceback")

    # 27) read_text must WARN (not stay silent) when a file genuinely exceeds max_bytes, while
    # returning the exact same truncated content as before (no behavior change for consumers) -
    # 2026-07-03 solo-review, LOW: previously zero signal anywhere that displayed checklist counts
    # were undercounting the real file.
    total += 1
    import io as _io
    tmp_big27 = _tempfile.mktemp()
    with open(tmp_big27, "w", encoding="utf-8") as f:
        f.write("x" * 30)
    captured27 = _io.StringIO()
    _orig_stderr27 = sys.stderr
    sys.stderr = captured27
    try:
        result27 = read_text(tmp_big27, max_bytes=10)
    finally:
        sys.stderr = _orig_stderr27
    os.remove(tmp_big27)
    assert result27 == "x" * 10, "truncation behavior itself must be unchanged: got %r" % result27
    assert "WARNING" in captured27.getvalue() and tmp_big27 in captured27.getvalue(), \
        "a genuinely-truncated read must warn, naming the file: got %r" % captured27.getvalue()
    ok += 1; print("  PASS read_text: warns on genuine truncation instead of staying silent, same truncated content returned")

    # 28) The served page's <script> block must be syntactically valid JS. Found live 2026-07-04
    # while trying to verify the blocked-count-chip fix in a real browser: PAGE is a plain (non-
    # raw) triple-quoted Python string, so a stray "\'" written into one JS string literal (meant
    # to escape an apostrophe FOR the JS layer) was instead consumed by PYTHON's own string
    # escaping and silently dropped, leaving a bare unescaped apostrophe in the actual served
    # bytes - a real syntax error that broke the ENTIRE <script> block in every real browser this
    # whole time (no refresh(), no click handlers, nothing - self_test() never caught it because
    # it only ever exercised the Python-side functions, never the JS actually served). Skips
    # gracefully if Node isn't on PATH rather than making self-test depend on it.
    total += 1
    script_match = re.search(r"<script>(.*)</script>", PAGE, re.S)
    assert script_match, "PAGE must contain a <script> block to validate"
    js_source = script_match.group(1)
    try:
        import tempfile as _tempfile28
        js_path = _tempfile28.mktemp(suffix=".js")
        with open(js_path, "w", encoding="utf-8") as f:
            f.write(js_source)
        node_check = subprocess.run(["node", "--check", js_path], capture_output=True, text=True, timeout=15, creationflags=_NO_WINDOW)
        os.remove(js_path)
        assert node_check.returncode == 0, \
            "the served <script> block has a JS syntax error (would break the WHOLE frontend in " \
            "every real browser): %s" % node_check.stderr
        ok += 1; print("  PASS PAGE's <script> block: valid JS syntax (node --check)")
    except FileNotFoundError:
        total -= 1
        print("  SKIP PAGE's <script> block JS-syntax check: node not found on PATH")

    # 29) The optimistic-server-controls overdrive layer must actually be present AND wired in the
    # served PAGE - all of: the animatable @property that drives the in-flight shimmer, the
    # .inflight shimmer overlay, its prefers-reduced-motion guard (a busy row must never depend on
    # motion to read as busy), the @starting-style entry for the inline result, the spring +
    # optimistic-swap JS helpers, and the .sbadge hook the handler grabs. A regression that quietly
    # strips any one of these would otherwise pass every Python-side check and the JS-syntax check
    # while silently reverting the feature (the same class of "self_test never exercised the served
    # layer" gap that let a real syntax error hide in the browser for a whole session, see #28).
    total += 1
    required_markers = [
        "@property --shim",                 # animatable custom prop -> smooth shimmer sweep
        ".srow.inflight::after",            # the in-flight shimmer overlay itself
        "srow-shimmer",                     # the shimmer keyframes
        "@starting-style",                  # clean entry for the inline result text
        "function springBadge",             # the damped-spring badge animation (WAAP)
        "function setBadgeState",           # the optimistic in-place badge repaint
        "prefersReducedMotion",             # spring is skipped under reduced motion
        "sbadge",                           # the stable badge hook the handler springs
    ]
    for marker in required_markers:
        assert marker in PAGE, \
            "optimistic-controls overdrive marker missing from served PAGE (feature silently " \
            "reverted?): %r" % marker
    # The shimmer must be gated by reduced-motion somewhere after it is defined - assert the guard
    # exists and the shimmer selector appears inside a reduced-motion block, not just anywhere.
    rm_block = re.search(r"@media \(prefers-reduced-motion: reduce\)\{[^}]*\.srow\.inflight::after",
                         PAGE, re.S)
    assert rm_block, \
        "the in-flight shimmer must be neutralized inside a prefers-reduced-motion media block"
    ok += 1; print("  PASS PAGE optimistic-controls: shimmer/@property/spring/@starting-style/reduced-motion all present and wired")

    # 30) Keyed child reconciliation, structural guard. Found live 2026-07-04: morphNode reconciled a
    # card's children by RAW POSITIONAL INDEX on the false assumption that a card's child shape is
    # fixed. It isn't - cardHtml() conditionally emits middle blocks (current item, conflict/stale/
    # stall notes, transcript, output files, task board, keep-going / LOG / CURRENT-TASK panels) that
    # appear and disappear as live data changes between polls. When a middle block vanished (e.g.
    # currentItem -> null), every later child shifted one slot, and because morphNode deliberately
    # does NOT sync a <details>'s user-toggled `open` attribute, an open+scrolled panel's state
    # smeared onto whatever DIFFERENT panel now sat in its old slot (keep-going the user opened went
    # closed; CURRENT-TASK spuriously opened). The fix keys each conditional block with a stable
    # data-slot and reconciles children by that key (reconcileChildren), so open/scroll stays pinned
    # to the LOGICAL panel. The full behavioral proof is a real-DOM Playwright rig (RED-then-GREEN,
    # run out-of-tree so the self-test keeps no browser dependency); here we assert the two structural
    # preconditions that make the corruption impossible, either of which a revert would break:
    #   (a) every conditionally-rendered block carries a data-slot naming what it is, and
    #   (b) reconcileChildren keys children on that data-slot rather than raw position.
    # A pure DOM shim for morphNode's full recursive node API would be a worse abstraction than these
    # invariants (it would re-implement the DOM the real bug lives in), so the behavioral test stays
    # in the out-of-tree Playwright rig and these fast source-level invariants stand guard in-suite.
    total += 1
    required_slots = [
        'data-slot="current"', 'data-slot="conflict"', 'data-slot="stale-note"',
        'data-slot="stall-warning"', 'data-slot="transcript"', 'data-slot="output-files"',
        'data-slot="task-board"', 'data-slot="keep-going"', 'data-slot="current-task"',
        'data-slot="xref"', 'data-slot="log-tail"', 'data-slot="counts"', 'data-slot="bar"',
    ]
    for slot in required_slots:
        assert slot in PAGE, \
            "a conditionally-rendered card block lost its data-slot marker (%s) - keyed child " \
            "reconciliation would fall back to raw position and mis-attribute open/scroll state " \
            "to the wrong panel again (see morphNode/reconcileChildren)" % slot
    assert "function reconcileChildren" in PAGE, \
        "reconcileChildren is gone - children would be reconciled by raw position again"
    assert re.search(r"reconcileChildren[\s\S]{0,900}getAttribute\('data-slot'\)", PAGE), \
        "reconcileChildren must key children by data-slot, not raw position"
    # Guard the historical regression it must NOT reintroduce: the removed positional walk's own
    # comment must be gone, so a silent revert to positional reconciliation is caught.
    assert "Structural shape is deterministic for a given card kind" not in PAGE, \
        "the old raw-positional child reconcile (and its false 'deterministic shape' premise) is back"
    ok += 1; print("  PASS keyed child reconciliation: every conditional block carries a data-slot and reconcileChildren keys on it (no positional smearing)")

    # 30) check_http_health: a real health signal, not just "is the port open" - found live
    #     2026-07-06 (Douglas: "make sure the dashboards are connected, functional, and working").
    #     A TCP-listening port with nothing actually answering HTTP must read as unhealthy, not
    #     healthy - the whole point of this check is to catch exactly that gap.
    total += 1
    import http.server as _hs, threading as _th
    class _OKHandler(_hs.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200); self.end_headers()
        def log_message(self, *a): pass
    ok_srv = _hs.HTTPServer(("127.0.0.1", 0), _OKHandler)
    ok_port = ok_srv.server_address[1]
    ok_thread = _th.Thread(target=ok_srv.serve_forever, daemon=True); ok_thread.start()
    hung_listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    hung_listener.bind(("127.0.0.1", 0)); hung_listener.listen(1)
    hung_port = hung_listener.getsockname()[1]
    try:
        assert check_http_health(ok_port) is True, \
            "a real HTTP server that responds must read as healthy"
        assert check_http_health(hung_port, timeout=0.3) is False, \
            "a TCP-listening port that never answers HTTP must read as UNHEALTHY, not healthy - " \
            "that gap is the entire reason this check exists"
    finally:
        ok_srv.shutdown(); ok_srv.server_close()
        hung_listener.close()
    ok += 1; print("  PASS check_http_health: a hung listener (port open, no HTTP response) reads as unhealthy, not just \"running\"")

    # 31) refreshServers must reconcile in place (data-server-id keyed), never blow the whole list
    #     away with a raw innerHTML replace. Found live 2026-07-06: the periodic 6s poll destroying
    #     and rebuilding every server row raced with an in-flight optimistic Start/Stop click -- the
    #     click handler's captured .action-result/badge references went stale the instant a routine
    #     refresh fired mid-action, so a genuinely SUCCESSFUL start silently showed "stopped" with no
    #     message at all (Douglas hit this live). A regression back to the old
    #     `host.innerHTML = servers.map(serverRowHtml).join('')` pattern would reintroduce that race
    #     silently, passing every other check -- assert the safe path is what's actually wired.
    total += 1
    assert "function reconcileServers(" in PAGE, \
        "reconcileServers must exist - server rows need keyed in-place patching, not full rebuild"
    assert re.search(r"reconcileServers\(host,\s*servers\)", PAGE), \
        "refreshServers must call reconcileServers, not rebuild #servers-list wholesale"
    assert "host.innerHTML = servers.length ? servers.map(serverRowHtml)" not in PAGE, \
        "refreshServers must not have regressed to the destructive full-rebuild pattern"
    assert 'data-server-id="' in PAGE, \
        "each server row needs a stable data-server-id key for reconciliation to find it across polls"
    for slot in ['data-slot="badge"', 'data-slot="action"', 'data-slot="result"', 'data-slot="open-link"']:
        assert slot in PAGE, "server row's variable children must carry %r for safe in-place patching" % slot
    # The "open" link must honor a config's openPath (e.g. the truss dashboard's real page) instead
    # of always hitting bare root - a regression back to a hard-coded "/" would silently send Douglas
    # to the wrong page for every server whose useful entry point isn't the root.
    assert "s.openPath || '/'" in PAGE, \
        "serverRowHtml must build the open URL from s.openPath (falling back to '/'), not a hard-coded root"
    ok += 1; print("  PASS reconcileServers: server rows patch in place (data-server-id keyed), open link honors openPath, no destructive rebuild race")

    # 32) refreshServers must guard against out-of-order responses - a stale /api/servers fetch
    #     resolving after a newer one must never overwrite it, even though reconcileServers patches
    #     nodes correctly (found live 2026-07-06: a real, intermittent request-ordering race, distinct
    #     from the node-identity bug #31 already fixes).
    total += 1
    assert "_serversFetchSeq" in PAGE, \
        "refreshServers needs a monotonic sequence guard against out-of-order /api/servers responses"
    seq_guard = re.search(r"async function refreshServers\(\)\{.*?if\(mySeq !== _serversFetchSeq\)", PAGE, re.S)
    assert seq_guard, "refreshServers must check its own sequence number before applying a response"
    ok += 1; print("  PASS refreshServers stale-response guard: an out-of-order /api/servers response can't overwrite a newer one")

    # 33) load_archived/save_archived: round-trips a set of root paths through the JSON side file,
    #     and a missing/corrupt file reads as "nothing archived" rather than crashing (2026-07-06,
    #     Douglas: "allow me to archive longrun boards").
    total += 1
    import tempfile as _tempfile33
    tmp33 = _tempfile33.mktemp(suffix=".json")
    old_archive_file = globals()["ARCHIVE_FILE"]
    try:
        globals()["ARCHIVE_FILE"] = tmp33
        assert load_archived() == set(), "a missing archive file must read as an empty set, not crash"
        save_archived({"C:/proj/a", "C:/proj/b"})
        assert load_archived() == {"C:/proj/a", "C:/proj/b"}, "must round-trip exactly what was saved"
        with open(tmp33, "w", encoding="utf-8") as f:
            f.write("{ not valid json")
        assert load_archived() == set(), "a corrupt archive file must read as empty, not crash the dashboard"
    finally:
        globals()["ARCHIVE_FILE"] = old_archive_file
        if os.path.isfile(tmp33):
            os.remove(tmp33)
    ok += 1; print("  PASS load_archived/save_archived: round-trips real data, degrades to empty on missing/corrupt file")

    # 34) partition_archived: splits collect_all()-shaped cards into (active, archived) by root
    #     membership, and a card whose root was never archived stays active.
    total += 1
    fake_cards = [{"root": "C:/proj/a"}, {"root": "C:/proj/b"}, {"root": "C:/proj/c"}]
    active34, archived34 = partition_archived(fake_cards, {"C:/proj/b"})
    assert [c["root"] for c in active34] == ["C:/proj/a", "C:/proj/c"], \
        "archived roots must be excluded from the active list"
    assert [c["root"] for c in archived34] == ["C:/proj/b"], \
        "only the archived root should appear in the archived list"
    ok += 1; print("  PASS partition_archived: splits cards by archived-root membership, order preserved")

    # 35) lastActivityTs: both card kinds must expose a real, non-fabricated last-activity
    #     timestamp for the Kanban "sort by most recent activity" toggle to use.
    total += 1
    import tempfile as _tempfile35, shutil as _shutil35
    tmp35 = _tempfile35.mkdtemp()
    try:
        wq_path35 = os.path.join(tmp35, "WORK_QUEUE.md")
        ct_path35 = os.path.join(tmp35, "CURRENT-TASK.md")
        with open(wq_path35, "w", encoding="utf-8") as f:
            f.write("- [ ] todo item\n")
        with open(ct_path35, "w", encoding="utf-8") as f:
            f.write("goal: test\n")
        older = _now_seconds() - 3600
        newer = _now_seconds() - 60
        os.utime(wq_path35, (older, older))
        os.utime(ct_path35, (newer, newer))
        card35 = collect_plain_status(tmp35)
        assert card35 is not None, "fixture must be recognized as a plain-status project"
        assert card35["lastActivityTs"] is not None, "lastActivityTs must be populated when output files exist"
        assert abs(card35["lastActivityTs"] - newer) < 2, \
            "lastActivityTs must be the MOST RECENT output-file mtime (CURRENT-TASK.md), not the oldest: got %r" % card35["lastActivityTs"]
    finally:
        _shutil35.rmtree(tmp35, ignore_errors=True)
    ok += 1; print("  PASS lastActivityTs: plain-status card exposes the freshest real output-file mtime")

    # 36) taskBoardHtml must start collapsed (Douglas, 2026-07-06) - a regression back to
    #     `<details open data-slot="task-board">` would silently re-expand every card's task board.
    total += 1
    assert '<details data-slot="task-board">' in PAGE, \
        "taskBoardHtml must render a COLLAPSED <details> by default"
    assert '<details open data-slot="task-board">' not in PAGE, \
        "taskBoardHtml must not hardcode open=true - that was the exact regression Douglas flagged"
    ok += 1; print("  PASS taskBoardHtml: task board starts collapsed on first render")

    # 37) Kanban columns: the flat #cards grid must be 5 status-grouped columns (the SAME grouping
    #     STATUS_COLOR_VAR already uses for badge colors, not a new invented taxonomy), each with its
    #     own reconciled body, so a poll can never blow away one column while patching another.
    total += 1
    for col_key in ("needs-you", "active", "stalled", "idle", "finished"):
        assert 'data-col="%s"' % col_key in PAGE, "missing Kanban column %r" % col_key
    assert "function kanbanColumnFor(status)" in PAGE, "kanbanColumnFor must exist to route a card to its column"
    assert "function reconcileCardList(host, cards, emptyMessage)" in PAGE, \
        "the per-host reconcile logic must be a reusable function, callable once per Kanban column"
    assert re.search(r"function reconcileCards\(cards\)\{[\s\S]*?KANBAN_COLUMNS\.forEach", PAGE), \
        "reconcileCards must bucket cards into the Kanban columns, not render a single flat list"
    ok += 1; print("  PASS Kanban columns: 5 status-grouped columns wired, each reconciled independently")

    # 38) sort-by-date toggle: must persist across reloads (localStorage) and re-render from the
    #     cached last-fetched data instantly, not force a re-fetch just to reorder what's on screen.
    total += 1
    assert "localStorage.getItem('kanbanSortByDate')" in PAGE and "localStorage.setItem('kanbanSortByDate'" in PAGE, \
        "the sort-by-date toggle must persist its state in localStorage"
    assert re.search(r"_sortToggleEl\.addEventListener\('change',[\s\S]*?renderBoard\(\)", PAGE), \
        "toggling sort-by-date must re-render immediately from cached data (renderBoard), not wait for the next poll"
    ok += 1; print("  PASS sort-by-date toggle: persisted via localStorage, re-renders instantly from cached data")

    # 39) archive / unarchive: every card must carry an archive control, and the archived panel must
    #     NOT join the periodic poll loop (2026-07-06 lesson: a background poll racing a click is
    #     exactly what caused the two real server-management bugs earlier this session).
    total += 1
    assert 'data-action="archive"' in PAGE, "every card needs an archive button"
    assert 'id="archived-panel"' in PAGE and 'id="archived-list"' in PAGE, "the archived-boards panel must exist"
    assert "_archivedPanel.addEventListener('toggle'" in PAGE, \
        "the archived panel must fetch on open, not eagerly on page load"
    assert "setInterval(refreshArchived" not in PAGE, \
        "the archived panel must NOT be on a periodic poll - it only refreshes on open/unarchive, by design"
    ok += 1; print("  PASS archive/unarchive: archive control on every card, archived panel fetch-on-open only (no poll race)")

    # 40) refresh() needs the same stale-response guard as refreshServers() - the archive button
    #     added a SECOND caller of refresh() (right after its POST) alongside the periodic 6s poll,
    #     so an out-of-order /api/longruns response could otherwise resurrect a just-archived card.
    total += 1
    assert "_longrunsFetchSeq" in PAGE, \
        "refresh() needs a monotonic sequence guard now that the archive button also calls it directly"
    guard40 = re.search(r"async function refresh\(\)\{.*?if\(mySeq !== _longrunsFetchSeq\)", PAGE, re.S)
    assert guard40, "refresh() must check its own sequence number before applying a response"
    ok += 1; print("  PASS refresh() stale-response guard: an out-of-order /api/longruns response can't overwrite a newer one")

    # 41) typeset pass: a fixed rem type scale (product register - Douglas views this dashboard at
    #     one consistent DPI on his own machine, so a shrinking clamp() heading serves nobody) replaces
    #     the old muddy scatter of ~10 near-identical em/px sizes. Guards against a regression back to
    #     ad-hoc values that made same-role text inconsistent across the page.
    total += 1
    for token in ("--text-2xs", "--text-xs", "--text-sm", "--text-md", "--text-lg"):
        assert token in PAGE, "missing type-scale token %r" % token
    assert not re.search(r"font-size:\s*clamp\(", PAGE), \
        "product-register typeset guidance: fixed rem scale, not fluid clamp() headings, at consistent DPI"
    assert not re.search(r"font-size:\s*0\.\d\d?em\b", PAGE), \
        "a raw ad-hoc em font-size regressed back in - route it through a --text-* token instead"
    ok += 1; print("  PASS typeset: fixed rem type scale (--text-2xs..--text-lg) replaces the old ad-hoc em/px scatter")

    # 42) A Kanban column that starts out showing the static "loading..." placeholder must actually
    #     switch to the real per-column empty message once real (empty) data arrives - found live
    #     2026-07-06, screenshotted: Needs You/Active columns were stuck reading "loading..." forever
    #     because checking only "does .empty exist" treated the static placeholder as already correct.
    total += 1
    assert "existingEmpty.textContent !== emptyMessage" in PAGE, \
        "reconcileCardList's empty branch must compare the placeholder's TEXT, not just whether a " \
        ".empty element exists - otherwise the initial \"loading...\" text never gets corrected"
    ok += 1; print("  PASS reconcileCardList empty state: the static \"loading...\" placeholder is replaced by the real empty message, not left stuck")

    # 43) Overflow fix: the task-board row's text span and the note/detail boxes that can hold a
    #     long unbroken path/identifier must be able to shrink/wrap inside their container. Found
    #     live 2026-07-06, screenshotted: task items and long project paths overflowed past the
    #     card's right border.
    total += 1
    assert "style=\"flex:1;min-width:0;overflow-wrap:anywhere\"" in PAGE, \
        "taskBoardHtml's item-text span must be flex:1;min-width:0 (flex items default to " \
        "min-width:auto and refuse to shrink below their content, which is exactly what overflowed)"
    for cls in (".detail{", ".current{", ".conflict-note{", ".xref-note{"):
        block = re.search(re.escape(cls) + r"[^}]*\}", PAGE)
        assert block and "overflow-wrap:anywhere" in block.group(0), \
            "%s must allow a long unbroken path/identifier to wrap instead of overflowing the card" % cls
    ok += 1; print("  PASS overflow fix: task-board rows and note/detail text wrap inside their card instead of overflowing it")

    # 44) Font: a single monospace family applied to EVERY element read as "terminal script, not an
    #     app" (Douglas, 2026-07-06). UI chrome now uses a system sans (--font-ui); --font-mono is
    #     reserved for genuinely code/data content via the global code/pre selectors.
    total += 1
    assert "--font-ui:" in PAGE and "--font-mono:" in PAGE, "the sans/mono token split must exist"
    assert "font-family:var(--font-ui)" in PAGE, "body must use the UI sans stack, not monospace"
    assert "code,pre{font-family:var(--font-mono);}" in PAGE, \
        "code/pre must stay monospace - that's the reserved code/data half of the split"
    ok += 1; print("  PASS font split: UI chrome uses a system sans, code/data stays monospace")

    # 45) Column visibility toggle: one pill button per Kanban column (each showing that column's
    #     live count, not a bare checkbox), persisted, and hiding a column must remove it from the
    #     flex layout (display:none) so the rest auto-adjust to fill the freed space - Douglas asked
    #     for exactly this "nicer than a checkbox... number for each one... columns auto-adjust".
    total += 1
    assert PAGE.count('class="col-toggle-btn"') == 5, "every one of the 5 Kanban columns needs its own visibility toggle button"
    assert PAGE.count('class="col-toggle-count"') == 5, "every column toggle button needs its own live count, not just a label"
    assert ".kcol.col-hidden{display:none;}" in PAGE, \
        "a hidden column must be display:none (removed from the flex layout), not just visually dimmed"
    assert "localStorage.getItem('kanbanHiddenColumns')" in PAGE and "localStorage.setItem('kanbanHiddenColumns'" in PAGE, \
        "column visibility must persist across reloads, same as the sort-by-date toggle"
    assert "toggleCount.textContent = countText" in PAGE, \
        "the toolbar toggle button's count must actually be kept in sync with the column's real count each render"
    ok += 1; print("  PASS column visibility toggle: 5 checkboxes, persisted, hidden columns free their space for the rest")

    # 46) Column clarity: Douglas said he couldn't tell Active/Watch/Idle apart. Every column header
    #     needs an explanatory tooltip, and the ambiguous "Watch" label is renamed to "Stalled" (the
    #     literal underlying status name - no translation step left for the reader to guess at).
    total += 1
    assert "Watch</span>" not in PAGE and 'data-col="watch"' not in PAGE, \
        "the ambiguous \"Watch\" column name must be renamed to \"Stalled\""
    assert PAGE.count('class="kcol-header" title="') == 5, \
        "every one of the 5 Kanban column headers needs an explanatory tooltip"
    ok += 1; print("  PASS column clarity: Watch renamed to Stalled, every column header has an explanatory tooltip")

    # 47) Overall width: the main tab column must not stretch edge-to-edge on a wide monitor - Douglas
    #     asked for it to be "a little bit thinner" (the max-width moved from body to .tabmain when the
    #     vertical tab rail was added, so the rail itself is flush-left and only the content is capped).
    total += 1
    assert re.search(r"\.tabmain\{[^}]*max-width:\d+px", PAGE), "the main tab column needs a max-width so content doesn't sprawl on wide monitors"
    ok += 1; print("  PASS overall width: the main tab column has a max-width instead of stretching edge-to-edge")

    # 48) Distill pass: the always-visible root path used to wrap 2-3 lines on every card (the
    #     biggest single contributor to "wall of text" per card); it must now be a truncated single
    #     line with the full path recoverable via title. Output files must be expand-on-demand, not
    #     an always-open list - the information stays reachable, just not up-front by default.
    total += 1
    assert 'class="rootpath" title="' in PAGE, "the root path needs the truncate+title treatment, not a full always-wrapping line"
    assert ".rootpath{display:block;overflow:hidden;text-overflow:ellipsis" in PAGE, \
        "the rootpath class needs the actual ellipsis-truncation CSS, not just the class name"
    assert "'<details class=\"files\" data-slot=\"output-files\"><summary>output files (' + c.outputFiles.length + ')</summary>'" in PAGE, \
        "output files must be an expand-on-demand <details>, not an always-visible list"
    ok += 1; print("  PASS distill: root path truncates to one line (full value in title), output files collapse behind a details toggle")

    # 49) Servers & dashboards / Discovered processes sit side by side at ~half width each
    #     (Douglas, 2026-07-06: "make that a section that takes up only half the screen").
    total += 1
    assert 'class="servers-split"' in PAGE, "Servers & Dashboards and Discovered processes must share a split container"
    assert ".servers-split .servers{flex:1 1 50%" in PAGE, "each half must actually be sized to ~50%, not just visually near each other"
    ok += 1; print("  PASS servers-split: Servers & dashboards and Discovered processes sit at ~half width each")

    # 50) The card is a collapsible <details> whose <summary> is the compact (~1/3-height) view, and
    #     the archive control is an SVG ICON in the top-right corner (Douglas, 2026-07-06: "top right
    #     or on the card"; 2026-07-07: "turn that into an icon" + "take each card to make it smaller,
    #     click to expand to what you have now"). Structural preconditions a revert would break.
    total += 1
    card_block = re.search(r"\.card\{[^}]*\}", PAGE)
    assert card_block and "position:relative" in card_block.group(0), \
        ".card must be the positioning context for the absolutely-positioned corner icon"
    assert re.search(r"\.archive-btn\{[^}]*position:absolute;top:\d+px;right:\d+px", PAGE), \
        "the archive button must be absolutely positioned in the card's corner"
    assert "<details class=\"' + cardClass" in PAGE, \
        "a card must render as a <details> so a single click collapses/expands it"
    assert '<summary class="csum">' in PAGE and "'<div class=\"cbody\">' + html" in PAGE, \
        "the compact summary and the expandable body wrapper must both exist"
    assert "ARCHIVE_ICON =" in PAGE and "ARCHIVE_ICON + '</button>'" in PAGE and "<svg" in PAGE, \
        "the archive control must be an SVG icon injected into the button, not a text label"
    assert ".card > summary.csum{" in PAGE and "padding-right:34px" in PAGE, \
        "the compact summary must reserve corner space so its text doesn't run under the icon"
    ok += 1; print("  PASS compact card: collapsible <details> with compact summary + expandable body, archive as a corner SVG icon")

    # 50b) The compact summary must carry EXACTLY Douglas's six fields (folder name only, status,
    #      current/next item, done, open, archive icon) and nothing that makes it un-reconcilable:
    #      the folder is the LAST path segment (not the full path / not projectName's 2 segments),
    #      done/open read off the checklist, and the current-item slot is ALWAYS emitted (empty when
    #      absent) so the summary's child count is constant across polls. Also the archive click must
    #      preventDefault so tapping the in-summary icon archives without toggling the card.
    total += 1
    assert "function lastSegment(root)" in PAGE and "lastSegment(c.root)" in PAGE, \
        "the summary must show only the folder name via lastSegment, not the full path"
    assert "parts[parts.length - 1]" in PAGE, "lastSegment must return the final path segment"
    assert "(c.checklist && c.checklist.x)" in PAGE and "(c.checklist && c.checklist.open)" in PAGE, \
        "the summary's done/open counts must read off the checklist for BOTH card kinds"
    assert "<span class=\"ccur\"" in PAGE and "esc(c.currentItem || '')" in PAGE, \
        "the current-item slot must always render (empty when absent) so child count stays constant"
    assert re.search(r'closest\(.button\[data-action="archive"\][\s\S]{0,600}ev\.preventDefault\(\)', PAGE), \
        "the archive handler must preventDefault so the in-summary icon doesn't toggle the card open"
    ok += 1; print("  PASS compact summary fields: folder-name-only, checklist done/open, always-present current-item slot, archive doesn't toggle")

    # 50c) Live sessions live ON the board now (Douglas 2026-07-07: "have the live sessions on this
    #      cardboard... as well"). A session becomes a board card via sessionCardHtml (kind=session,
    #      a synthetic session:: root key, status=state so it routes by kanban column), waiting maps
    #      to Needs You, the board is the UNION of project + session cards (renderBoard), the card's
    #      lazily-loaded detail is protected from the poll reconcile by the data-lazy morphNode guard,
    #      and the old standalone sessions panel is gone (Broadcast + the honest count moved to the toolbar).
    total += 1
    assert "function sessionCardHtml(c)" in PAGE and "function sessionsToCards(data)" in PAGE, \
        "sessions must render as board cards (sessionCardHtml) built from the payload (sessionsToCards)"
    assert "if(c.kind === 'session') return sessionCardHtml(c);" in PAGE, \
        "cardHtml must delegate a session card to sessionCardHtml so it flows through reconcileCards"
    assert "'<details class=\"card scard\" data-root=\"' + esc(c.root)" in PAGE and "data-sid=" in PAGE, \
        "a session card must be a .card (so it sits on the board) keyed by its synthetic root + data-sid"
    assert "kind: 'session', root: 'session::' + s.id, status: s.state" in PAGE, \
        "sessionsToCards must key by a synthetic root and set status=state for column routing"
    assert "{key:'needs-you', title:'Needs You', statuses:['blocked','stopped','waiting']}" in PAGE, \
        "a waiting session must route to the Needs You column"
    assert "function renderBoard(){ reconcileCards(_lastCardsData.concat(_lastSessionCards)); }" in PAGE, \
        "the board must be the union of project cards and session cards"
    assert "data-slot=\"sdetail\" data-lazy" in PAGE and "getAttribute('data-lazy') != null) return;" in PAGE, \
        "the session card's lazily-loaded detail must be protected from the poll reconcile by the data-lazy guard"
    assert 'id="sessions-list"' not in PAGE, "the old standalone sessions panel must be gone (sessions are on the board now)"
    assert 'id="broadcast-btn"' in PAGE and 'id="sessions-note"' in PAGE, "Broadcast + the honest session count moved to the toolbar"
    ok += 1; print("  PASS sessions on board: session cards flow through the kanban (waiting->Needs You), union render, lazy detail guarded, old panel removed")

    # 51) Inactive classification: a card untouched >1 day is hidden by default (client-side filter
    #     on lastActivityTs, never persisted/archived) with a toggle to reveal it - Douglas explicitly
    #     retracted "auto-archive" mid-request in favor of exactly this lighter, reversible mechanism.
    total += 1
    assert "function isInactive(c)" in PAGE, "isInactive must exist as the single source of truth for the >1-day rule"
    assert "c.lastActivityTs != null && (Date.now() / 1000 - c.lastActivityTs) > INACTIVE_AGE_SECONDS" in PAGE, \
        "a card with NO lastActivityTs signal must NOT be assumed inactive - only a genuinely stale timestamp counts"
    assert "if(!_showInactive) cards = cards.filter(function(c){ return !isInactive(c); });" in PAGE, \
        "the inactive filter must run before bucketing into columns, on ALL cards incl. sessions (Douglas 2026-07-08), so hidden-by-default is the real behavior"
    assert "localStorage.getItem('kanbanShowInactive')" in PAGE and "localStorage.setItem('kanbanShowInactive'" in PAGE, \
        "show-inactive must persist across reloads, same as the other toggles"
    assert "filter(function(s){ return !isInactive(s); }).length" in PAGE, \
        "the sessions-note count must be computed post inactive-filter (Douglas 2026-07-08), else it disagrees with what the board actually shows once old sessions are hidden"
    ok += 1; print("  PASS inactive classification: cards untouched >1 day hidden by default (incl. sessions), toggle reveals them, toolbar note matches what's actually shown")

    # 52) Animate pass: a disclosure opening gets a real fade+rise entrance (reusing the same
    #     @starting-style technique already proven for .action-result.shown, not a new fragile
    #     mechanism), and a card leaving the board gets a fade+shrink exit instead of vanishing --
    #     with a reduced-motion-safe fallback timeout so removal can never get stuck if no
    #     transitionend ever fires (transitions are globally disabled under prefers-reduced-motion
    #     by the rule already at the top of this stylesheet).
    total += 1
    assert "details > *:not(summary){" in PAGE and "transition:opacity 0.22s ease" in PAGE, \
        "disclosure content needs a real transition, not an instant pop-in"
    assert re.search(r"@starting-style\{\s*details\[open\] > \*:not\(summary\)\{ opacity:0;", PAGE), \
        "the disclosure entrance must use @starting-style so it only fires on a genuine open, never on load/scroll"
    assert "function animateOutAndRemove(el)" in PAGE, "card removal needs a real exit animation, not a bare el.remove()"
    assert "if(el.classList.contains('card-exiting')) el.remove();" in PAGE, \
        "the removal guard must check card-exiting is STILL set - a card reinstated mid-animation must not be deleted out from under itself"
    assert "setTimeout(finish, 300)" in PAGE, "a reduced-motion fallback timeout is required since transitionend never fires when transitions are disabled"
    assert "animateOutAndRemove(el);" in PAGE and "el.remove();\n      delete _lastCardHtml" not in PAGE, \
        "reconcileCardList's removal case must actually call the animated helper, not the old bare remove"
    ok += 1; print("  PASS animate: disclosure entrance fades+rises in, card removal fades+shrinks out with a reduced-motion-safe fallback")

    # 53) _session_meta: in one pass, the first genuine human title (skipping non-user events, non-text
    #     blocks, tool_result-only turns, isMeta, and slash-command/caveat plumbing, truncated), the
    #     cwd, and a human-turn count. Plus _folder_from_cwd (drive-root -> the drive, not a hash).
    total += 1
    import tempfile as _tempfile53
    tmp53 = _tempfile53.mktemp(suffix=".jsonl")
    tmp53b = _tempfile53.mktemp(suffix=".jsonl")
    try:
        with open(tmp53, "w", encoding="utf-8") as f:
            f.write(json.dumps({"type": "system", "message": {"content": "session start"}}) + "\n")
            f.write(json.dumps({"type": "assistant", "cwd": "C:\\proj\\thing", "message": {"content": [{"type": "text", "text": "hello, how can I help?"}]}}) + "\n")
            f.write(json.dumps({"type": "user", "message": {"content": [{"type": "tool_result", "content": "ignore me"}]}}) + "\n")
            f.write(json.dumps({"type": "user", "isMeta": True, "message": {"content": "<local-command-caveat>Caveat: ...</local-command-caveat>"}}) + "\n")
            f.write(json.dumps({"type": "user", "cwd": "C:\\proj\\thing", "message": {"content": "fix the login bug please, it happens on every retry"}}) + "\n")
        title, cwd, turns = _session_meta(tmp53, max_len=20)
        assert title == "fix the login bug pl...", \
            "must find the FIRST real human text (skipping system/assistant/tool_result/isMeta) and truncate: got %r" % title
        assert cwd == "C:\\proj\\thing", "must surface the cwd for the display folder name: got %r" % cwd
        assert turns >= 1, "must count the human turn: got %r" % turns
        assert _session_meta(os.path.join(tmp53 + "-missing")) == (None, None, 0), \
            "a missing file must return (None, None, 0), not raise"
        # plumbing-first: a slash-command wrapper must be skipped so the title is the real request.
        with open(tmp53b, "w", encoding="utf-8") as f:
            f.write(json.dumps({"type": "user", "message": {"content": "<command-name>longrun</command-name>"}}) + "\n")
            f.write(json.dumps({"type": "user", "message": {"content": "actually build the truss now"}}) + "\n")
        t2, _c2, _n2 = _session_meta(tmp53b)
        assert t2 == "actually build the truss now", "must skip the <command-name> wrapper and title on the real request: got %r" % t2
        assert _folder_from_cwd("C:\\") == "C:" and _folder_from_cwd("C:\\a\\b\\") == "b" and _folder_from_cwd(None) is None, \
            "a drive-root cwd must fold to the drive token, not an empty basename"
    finally:
        for _p in (tmp53, tmp53b):
            if os.path.isfile(_p):
                os.remove(_p)
    ok += 1; print("  PASS _session_meta: human title (skips meta/command plumbing) + cwd + turn count in one pass; _folder_from_cwd handles a drive root")

    # 54) list_claude_sessions: active/idle by mtime, 2-day cutoff, sorted newest-first, no crash on a
    #     missing dir - and the CONSERVATIVE subagent filter (adversarial review 2026-07-07): a spawned
    #     one-shot dispatch is excluded, but a REAL session is kept even when it runs in a worktree or
    #     opens with a dispatch-looking phrase but is multi-turn (the exact regressions the review found).
    total += 1
    import tempfile as _tempfile54, shutil as _shutil54
    tmp54 = _tempfile54.mkdtemp()
    try:
        _SESSION_META_CACHE.clear()
        proj_a = os.path.join(tmp54, "proj-a-hash")
        proj_wt = os.path.join(tmp54, "C--Users-x--claude-worktrees-zealous-carson")  # a REAL worktree session lives here
        os.makedirs(proj_a)
        os.makedirs(proj_wt)
        now54 = _now_seconds()
        def _w(path, cwd, msgs, age):
            with open(path, "w", encoding="utf-8") as f:
                for m in msgs:
                    f.write(json.dumps({"type": "user", "cwd": cwd, "message": {"content": m}}) + "\n")
            os.utime(path, (now54 - age, now54 - age))
        _w(os.path.join(proj_a, "sess-recent.jsonl"), "C:\\Users\\d\\Documents\\Claude NASA Folder\\ai-for-cad", ["recent work"], 60)          # active, natural -> keep
        _w(os.path.join(proj_a, "sess-idle.jsonl"), "C:\\Users\\d\\Documents\\Claude NASA Folder\\text-to-truss", ["idle work"], 3600)          # idle, natural -> keep
        _w(os.path.join(proj_a, "sess-stale.jsonl"), "C:\\proj", ["old work"], 3 * 86400)                                                       # 3 days -> cutoff excludes
        _w(os.path.join(proj_a, "sess-agent.jsonl"), "C:\\proj", ["Given this real git commit message, respond with ONLY a JSON object"], 120)  # 1-turn dispatch -> exclude
        _w(os.path.join(proj_wt, "sess-wt.jsonl"), "C:\\Users\\d\\Documents\\Claude NASA Folder\\.claude\\worktrees\\zc", ["hardening the hooks, TP=11 FP=4, walk me through it"], 120)  # REAL worktree session -> keep
        _w(os.path.join(proj_a, "sess-primed.jsonl"), "C:\\proj", ["You are an expert reviewer, help me here", "ok now also check the second file"], 120)  # dispatch-looking BUT multi-turn -> keep
        _w(os.path.join(proj_a, "sess-autorun.jsonl"), "C:\\proj", ["build the cubesat structure autonomously"], 120)  # 1-turn autonomous /longrun, natural -> keep
        with open(os.path.join(proj_a, "sess-zeroturn.jsonl"), "w", encoding="utf-8") as _fz:
            _fz.write(json.dumps({"type": "system", "cwd": "C:\\proj"}) + "\n")  # hook/mode noise, zero human turns -> exclude
        os.utime(os.path.join(proj_a, "sess-zeroturn.jsonl"), (now54 - 120, now54 - 120))
        # only-plumbing (Douglas 2026-07-08, real live example "3777ffa5..."): the ONLY "user" lines are
        # skip-prefixed command plumbing (a queued slash command), no genuine human text anywhere -> must
        # still exclude, even though the OLD code counted this as human_turns>=1 (title fell back to id).
        _w(os.path.join(proj_a, "sess-onlyplumbing.jsonl"), "C:\\proj", ["<command-name>usage</command-name>"], 120)
        _w(os.path.join(proj_a, "sess-dup-old.jsonl"), "C:\\proj", ["identical resumed opening message here"], 300)  # resume/compact duplicate, OLDER -> collapsed away
        _w(os.path.join(proj_a, "sess-dup-new.jsonl"), "C:\\proj", ["identical resumed opening message here"], 60)   # same thread, NEWER -> the copy that survives
        old_projects_dir = globals()["PROJECTS_DIR"]
        try:
            globals()["PROJECTS_DIR"] = tmp54
            sessions = list_claude_sessions()
        finally:
            globals()["PROJECTS_DIR"] = old_projects_dir
        ids = set(s["id"] for s in sessions)
        assert ids == {"sess-recent", "sess-idle", "sess-wt", "sess-primed", "sess-autorun", "sess-dup-new"}, \
            "keep real sessions (incl. worktree, multi-turn dispatch-title, autonomous 1-turn, the newer of a resume-duplicate pair); drop the 3-day stale, the 1-turn dispatch, the zero-turn noise file, and the older duplicate: got %r" % sorted(ids)
        byid = {s["id"]: s for s in sessions}
        assert byid["sess-recent"]["state"] == "active" and byid["sess-idle"]["state"] == "idle"
        assert byid["sess-recent"]["folder"] == "ai-for-cad" and byid["sess-idle"]["folder"] == "text-to-truss", \
            "folder must be the cwd's LAST segment: got %r" % [(s["id"], s["folder"]) for s in sessions]
        assert byid["sess-wt"]["folder"] == "zc", "a real worktree session must still appear (worktree dir is NOT a subagent signal)"
        # the conservative classifier, directly:
        assert _looks_like_subagent("Given this real git commit message, respond with ONLY a JSON object", 1) is True, "a 1-turn dispatch is an agent"
        assert _looks_like_subagent("you are a rigorous reviewer", 1) is True, "a 1-turn role-prompt is an agent"
        assert _looks_like_subagent("you are a rigorous reviewer", 2) is False, "2+ human turns is ALWAYS a real session"
        assert _looks_like_subagent("please fix the login bug", 1) is False, "a natural 1-turn message is a real session"
        assert _looks_like_subagent("build the cubesat autonomously", 1) is False, "a 1-turn autonomous run with a natural prompt is a real session"
        assert _looks_like_subagent(None, 0) is True, "zero human turns is never a real session, regardless of title"
        assert _looks_like_subagent("please fix the login bug", 0) is True, "zero human turns overrides even a natural-looking title"
        # _dedupe_resumed_sessions, directly:
        _da = {"id": "a-old", "title": "same opener message shared across resumes", "folder": "f", "lastActivityTs": 100}
        _db = {"id": "a-new", "title": "same opener message shared across resumes", "folder": "f", "lastActivityTs": 200}
        _dc = {"id": "c", "title": "a completely different long opener text", "folder": "f", "lastActivityTs": 150}
        _dshort1 = {"id": "s1", "title": "hi", "folder": "f", "lastActivityTs": 70}   # short generic title -> never collapsed, even if shared
        _dshort2 = {"id": "s2", "title": "hi", "folder": "f", "lastActivityTs": 80}
        _dnone1 = {"id": "n1", "title": "n1", "folder": "f", "lastActivityTs": 50}   # title fell back to id -> never collapsed
        _dnone2 = {"id": "n2", "title": "n2", "folder": "f", "lastActivityTs": 60}
        _dres = _dedupe_resumed_sessions([_da, _db, _dc, _dshort1, _dshort2, _dnone1, _dnone2])
        _dres_ids = set(s["id"] for s in _dres)
        assert _dres_ids == {"a-new", "c", "s1", "s2", "n1", "n2"}, \
            "same folder+specific-title collapses to the newest copy; short (<20 char) or id-fallback titles are never collapsed: got %r" % sorted(_dres_ids)
        old_projects_dir2 = globals()["PROJECTS_DIR"]
        try:
            globals()["PROJECTS_DIR"] = os.path.join(tmp54, "does-not-exist")
            assert list_claude_sessions() == [], "a missing PROJECTS_DIR must return an empty list, not crash"
        finally:
            globals()["PROJECTS_DIR"] = old_projects_dir2
    finally:
        _shutil54.rmtree(tmp54, ignore_errors=True)
    ok += 1; print("  PASS list_claude_sessions: active/idle, 2-day cutoff, folder-name from cwd, subagent+worktree excluded, newest-first, no crash")

    # 55) queue_session_action: appends one real JSONL record per call, round-trips the exact
    #     sessionId/text, and never overwrites a prior queued action.
    total += 1
    import tempfile as _tempfile55
    tmp55 = _tempfile55.mktemp(suffix=".jsonl")
    old_actions_file = globals()["SESSION_ACTIONS_FILE"]
    try:
        globals()["SESSION_ACTIONS_FILE"] = tmp55
        rec1 = queue_session_action("sess-aaa", "first message")
        rec2 = queue_session_action("sess-bbb", "second message")
        assert rec1["sessionId"] == "sess-aaa" and rec1["text"] == "first message" and rec1["status"] == "queued"
        with open(tmp55, encoding="utf-8") as f:
            lines = [json.loads(ln) for ln in f if ln.strip()]
        assert len(lines) == 2, "each call must APPEND a new record, never overwrite the file: got %d lines" % len(lines)
        assert lines[0]["sessionId"] == "sess-aaa" and lines[1]["sessionId"] == "sess-bbb"
    finally:
        globals()["SESSION_ACTIONS_FILE"] = old_actions_file
        if os.path.isfile(tmp55):
            os.remove(tmp55)
    ok += 1; print("  PASS queue_session_action: appends real JSONL records, round-trips sessionId/text, never overwrites")

    # 56) Sessions panel wiring: the API routes and frontend must actually be connected, and the
    #     dispatch mechanism must stay honestly framed as a QUEUE (this dashboard has no
    #     ccd_session_mgmt MCP access of its own to inject a message directly - Douglas's "merge
    #     Mission Control in" must not silently overclaim a capability that isn't real). Checked
    #     against this file's own source (not PAGE, which is JS/HTML only - the routes live in
    #     the surrounding Python).
    total += 1
    with open(__file__, encoding="utf-8") as _f56:
        source56 = _f56.read()
    assert 'elif parsed.path == "/api/sessions":' in source56, "GET /api/sessions must be wired into do_GET"
    assert 'elif parsed.path == "/api/sessions/action":' in source56, "POST /api/sessions/action must be wired into do_POST"
    assert "queue_session_action(session_id, text)" in source56, "the POST handler must actually call queue_session_action"
    assert "function refreshSessions()" in PAGE and "function sessionCardHtml(c)" in PAGE, \
        "the frontend needs the sessions refresh loop and the session-card renderer"
    assert "setInterval(refreshSessions," in PAGE, "sessions must be on the periodic poll loop like the other panels"
    assert "can't inject the message directly" in source56 or "can only READ session transcripts and QUEUE" in source56, \
        "the queue-not-inject limitation must be documented in the source, not silently implied"
    ok += 1; print("  PASS sessions panel wiring: GET/POST routes connected, frontend renders + polls, dispatch honestly framed as a queue")

    # 56b) Skills-run-per-project panel: the /api/skills route, the panel + list container, the
    #      renderer/refresh loop, and the poll wiring must all be connected end to end (2026-07-07,
    #      Douglas: a project-based tracker showing which master-list skills have run on each project).
    total += 1
    with open(__file__, encoding="utf-8") as _f56b:
        source56b = _f56b.read()
    assert 'elif parsed.path == "/api/skills":' in source56b, "GET /api/skills must be wired into do_GET"
    assert "project_skills_coverage()" in source56b, "the /api/skills handler must call project_skills_coverage"
    assert 'id="skills-panel"' in PAGE and 'id="skills-list"' in PAGE, "the skills panel + its list container must exist"
    assert "function skillsPanelHtml(data)" in PAGE and "async function refreshSkills()" in PAGE, \
        "the frontend needs the skills renderer and its refresh function"
    assert "fetch('/api/skills')" in PAGE, "refreshSkills must fetch /api/skills"
    assert "refreshSkills();" in PAGE and "setInterval(refreshSkills," in PAGE, "skills must run on load AND on the periodic poll"
    assert ".skillchip.on" in PAGE and ".skillchip.off" in PAGE, "run vs not-run chips need distinct styling"
    ok += 1; print("  PASS skills panel wiring: /api/skills route + panel + renderer + poll loop connected, run/not-run chips styled")

    # 57) Session display cap: the /api/sessions payload must be {total, sessions} with sessions
    #     capped to SESSION_DISPLAY_CAP, and the frontend must surface the true total (found live
    #     2026-07-07: a 7-day scan returns hundreds of real sessions -- a silent full dump would be
    #     the exact wall-of-text Douglas already rejected, and a silent CAP would violate his
    #     no-silent-truncation rule).
    total += 1
    assert 'self._json({"total": len(all_sessions), "sessions": all_sessions[:SESSION_DISPLAY_CAP]})' in source56, \
        "GET /api/sessions must return {total, sessions} with sessions capped, not the full raw list"
    assert isinstance(SESSION_DISPLAY_CAP, int) and 0 < SESSION_DISPLAY_CAP <= 50, \
        "SESSION_DISPLAY_CAP must be a small positive bound, not effectively unlimited"
    assert "data.total > shown" in PAGE and "' of ' + data.total + ' sessions shown" in PAGE, \
        "the frontend must show an honest 'N of M' note whenever the cap hid older sessions"
    ok += 1; print("  PASS session display cap: payload is {total, sessions}, capped, with an honest 'showing N of M' note")

    # 58) session_usage: context% from the MOST RECENT usage, cumulative cost estimate across all
    #     turns using the per-model price table, model detected from the transcript. A transcript
    #     with no usage data returns zeros, never a fabricated figure.
    total += 1
    import tempfile as _tempfile58, shutil as _shutil58
    tmp58 = _tempfile58.mkdtemp()
    try:
        proj58 = os.path.join(tmp58, "proj-hash")
        os.makedirs(proj58)
        sid58 = "usage-test-session"
        with open(os.path.join(proj58, sid58 + ".jsonl"), "w", encoding="utf-8") as f:
            f.write(json.dumps({"type": "user", "message": {"content": "start"}}) + "\n")
            # First assistant turn: 10k input, 1k output, opus.
            f.write(json.dumps({"type": "assistant", "message": {"model": "claude-opus-4-8",
                "usage": {"input_tokens": 10000, "output_tokens": 1000, "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}}}) + "\n")
            # Second (latest) assistant turn: 20k input + 100k cache_read -> context = 120k of 200k = 60%.
            f.write(json.dumps({"type": "assistant", "message": {"model": "claude-opus-4-8",
                "usage": {"input_tokens": 20000, "output_tokens": 2000, "cache_read_input_tokens": 100000, "cache_creation_input_tokens": 0}}}) + "\n")
        old_projects58 = globals()["PROJECTS_DIR"]
        try:
            globals()["PROJECTS_DIR"] = tmp58
            u = session_usage(sid58)
        finally:
            globals()["PROJECTS_DIR"] = old_projects58
        assert u["model"] == "claude-opus-4-8", "model must be read from the transcript: got %r" % u["model"]
        assert u["contextTokens"] == 120000, "contextTokens must be the LATEST turn's (input+cache): got %r" % u["contextTokens"]
        assert u["contextPct"] == 0.6, "120k of a 200k window must be 0.6: got %r" % u["contextPct"]
        # opus: (10000*15 + 1000*75 + 20000*15 + 2000*75 + 100000*1.5)/1e6 = (150000+75000+300000+150000+150000)/1e6 = 0.825
        assert u["estCostUsd"] == 0.82 or u["estCostUsd"] == 0.83, \
            "cumulative opus cost estimate must sum every turn's usage: got %r" % u["estCostUsd"]
        # No-usage transcript -> zeros, not a guess.
        sid_empty = "empty-usage-session"
        with open(os.path.join(proj58, sid_empty + ".jsonl"), "w", encoding="utf-8") as f:
            f.write(json.dumps({"type": "user", "message": {"content": "hi"}}) + "\n")
        try:
            globals()["PROJECTS_DIR"] = tmp58
            u2 = session_usage(sid_empty)
        finally:
            globals()["PROJECTS_DIR"] = old_projects58
        assert u2 == {"model": None, "contextTokens": 0, "contextPct": 0.0, "estCostUsd": 0.0}, \
            "a transcript with no usage must return zeros, never a fabricated estimate: got %r" % u2
    finally:
        _shutil58.rmtree(tmp58, ignore_errors=True)
    ok += 1; print("  PASS session_usage: context% from latest turn, cumulative cost estimate, model detected, zeros when no data")

    # 59) session_pending_input: True ONLY when the transcript's final event is an assistant message
    #     paused on a tool_use; conservatively False for a plain end_turn or a trailing user/tool
    #     event (never a fabricated "waiting on you").
    total += 1
    import tempfile as _tempfile59, shutil as _shutil59
    tmp59 = _tempfile59.mkdtemp()
    try:
        proj59 = os.path.join(tmp59, "proj-hash")
        os.makedirs(proj59)
        def _write_tr(sid, last_event):
            p = os.path.join(proj59, sid + ".jsonl")
            with open(p, "w", encoding="utf-8") as f:
                f.write(json.dumps({"type": "user", "message": {"content": "do a thing"}}) + "\n")
                f.write(json.dumps(last_event) + "\n")
            return sid
        pending = _write_tr("pending-sess", {"type": "assistant", "message": {"stop_reason": "tool_use", "content": [{"type": "tool_use", "name": "Bash"}]}})
        done = _write_tr("done-sess", {"type": "assistant", "message": {"stop_reason": "end_turn", "content": [{"type": "text", "text": "all done"}]}})
        user_last = _write_tr("userlast-sess", {"type": "user", "message": {"content": "here you go"}})
        old_projects59 = globals()["PROJECTS_DIR"]
        try:
            globals()["PROJECTS_DIR"] = tmp59
            assert session_pending_input(pending) is True, "a final assistant tool_use pause must read as waiting-on-you"
            assert session_pending_input(done) is False, "a plain end_turn must NOT be claimed as waiting (ambiguous)"
            assert session_pending_input(user_last) is False, "a trailing user event means the ball isn't in the user's court"
            assert session_pending_input("no-such-session") is False, "a missing transcript must return False, not raise"
        finally:
            globals()["PROJECTS_DIR"] = old_projects59
    finally:
        _shutil59.rmtree(tmp59, ignore_errors=True)
    ok += 1; print("  PASS session_pending_input: waiting-on-you only on a real paused tool_use, never a fabricated end_turn guess")

    # 60) broadcast_session_action: queues the message to every ACTIVE session (and only active
    #     ones), one queue record each, and the POST route + frontend button are wired.
    total += 1
    import tempfile as _tempfile60, shutil as _shutil60
    tmp60 = _tempfile60.mkdtemp()
    tmp60_queue = _tempfile60.mktemp(suffix=".jsonl")
    old_projects60 = globals()["PROJECTS_DIR"]
    old_queue60 = globals()["SESSION_ACTIONS_FILE"]
    try:
        proj60 = os.path.join(tmp60, "proj-hash")
        os.makedirs(proj60)
        now60 = _now_seconds()
        act1 = os.path.join(proj60, "bcast-active-1.jsonl")
        act2 = os.path.join(proj60, "bcast-active-2.jsonl")
        idle60 = os.path.join(proj60, "bcast-idle.jsonl")
        for p in (act1, act2, idle60):
            with open(p, "w", encoding="utf-8") as f:
                f.write(json.dumps({"type": "user", "message": {"content": "hi"}}) + "\n")
        os.utime(act1, (now60 - 30, now60 - 30))
        os.utime(act2, (now60 - 60, now60 - 60))
        os.utime(idle60, (now60 - 3600, now60 - 3600))  # idle -> must NOT receive the broadcast
        globals()["PROJECTS_DIR"] = tmp60
        globals()["SESSION_ACTIONS_FILE"] = tmp60_queue
        ids = broadcast_session_action("all hands: re-run the gate")
        assert sorted(ids) == ["bcast-active-1", "bcast-active-2"], \
            "broadcast must target every ACTIVE session and NO idle one: got %r" % ids
        with open(tmp60_queue, encoding="utf-8") as f:
            queued = [json.loads(ln) for ln in f if ln.strip()]
        assert len(queued) == 2 and all(q["text"] == "all hands: re-run the gate" for q in queued), \
            "each active session must get exactly one queued record with the broadcast text"
    finally:
        globals()["PROJECTS_DIR"] = old_projects60
        globals()["SESSION_ACTIONS_FILE"] = old_queue60
        _shutil60.rmtree(tmp60, ignore_errors=True)
        if os.path.isfile(tmp60_queue):
            os.remove(tmp60_queue)
    with open(__file__, encoding="utf-8") as _f60:
        source60 = _f60.read()
    assert 'elif parsed.path == "/api/sessions/broadcast":' in source60, "the broadcast POST route must be wired"
    assert "id=\"broadcast-btn\"" in PAGE and "getElementById('broadcast-btn')" in PAGE, \
        "the frontend needs the broadcast button and its handler"
    ok += 1; print("  PASS broadcast_session_action: queues to every active session only, route + button wired")

    # 61) Multi-instance guard: try_bind_server must REFUSE to start when a live dashboard is already
    #     answering HTTP on the port (found live 2026-07-07: 10 instances co-bound :8756 via Windows
    #     SO_REUSEADDR, round-robining requests so stale-code copies silently answered).
    total += 1
    import http.server as _hs61, threading as _th61
    class _Live61(_hs61.BaseHTTPRequestHandler):
        def do_GET(self): self.send_response(200); self.end_headers()
        def log_message(self, *a): pass
    live_srv = _hs61.HTTPServer(("127.0.0.1", 0), _Live61)
    live_port = live_srv.server_address[1]
    _th61.Thread(target=live_srv.serve_forever, daemon=True).start()
    try:
        raised = False
        try:
            try_bind_server(live_port, Handler)
        except RuntimeError as e:
            raised = "already serving" in str(e)
        assert raised, "try_bind_server must refuse (RuntimeError) when a live instance already answers on the port"
    finally:
        live_srv.shutdown(); live_srv.server_close()
    ok += 1; print("  PASS multi-instance guard: try_bind_server refuses to start a 2nd live instance on an occupied port")

    # 62) session_detail: extracts recent user text / assistant text / assistant tool_use (with a
    #     short input preview) from the transcript tail, honors the limit, and returns [] for a
    #     missing transcript. Plus the /api/session/:id route + frontend expand wiring exist.
    total += 1
    import tempfile as _tempfile62, shutil as _shutil62
    tmp62 = _tempfile62.mkdtemp()
    try:
        proj62 = os.path.join(tmp62, "proj-hash")
        os.makedirs(proj62)
        sid62 = "detail-test"
        with open(os.path.join(proj62, sid62 + ".jsonl"), "w", encoding="utf-8") as f:
            f.write(json.dumps({"type": "user", "message": {"content": "please fix the bug"}}) + "\n")
            f.write(json.dumps({"type": "assistant", "message": {"content": [{"type": "text", "text": "on it"}]}}) + "\n")
            f.write(json.dumps({"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash", "input": {"command": "pytest -q", "description": "run tests"}}]}}) + "\n")
        old_projects62 = globals()["PROJECTS_DIR"]
        try:
            globals()["PROJECTS_DIR"] = tmp62
            evs = session_detail(sid62)
            assert evs == [
                {"kind": "user", "text": "please fix the bug"},
                {"kind": "assistant", "text": "on it"},
                {"kind": "tool", "tool": "Bash", "input": "pytest -q"},
            ], "session_detail must extract user/assistant/tool events with a tool input preview: got %r" % evs
            assert session_detail(sid62, limit=1) == [{"kind": "tool", "tool": "Bash", "input": "pytest -q"}], \
                "limit must keep only the most recent N events"
            assert session_detail("no-such") == [], "a missing transcript must return [], not raise"
        finally:
            globals()["PROJECTS_DIR"] = old_projects62
    finally:
        _shutil62.rmtree(tmp62, ignore_errors=True)
    with open(__file__, encoding="utf-8") as _f62:
        source62 = _f62.read()
    assert 'parsed.path.startswith("/api/session/")' in source62, "the /api/session/:id detail route must be wired"
    assert "function loadSessionDetail(sid, host)" in PAGE and "_openSessions" in PAGE, \
        "the frontend needs lazy detail loading + an open-session set that survives polls"
    ok += 1; print("  PASS session_detail: recent user/assistant/tool events from the tail, limit honored, route + expand wired")

    # 63) Queue drainer: read_pending_actions lists only queued items; drain_pending_actions returns
    #     them AND marks them delivered so a second drain returns nothing (no double-send). This is
    #     what makes Message/Broadcast actually DELIVERABLE by an agent with the ccd MCP.
    total += 1
    import tempfile as _tempfile63
    tmp63 = _tempfile63.mktemp(suffix=".jsonl")
    old_queue63 = globals()["SESSION_ACTIONS_FILE"]
    try:
        globals()["SESSION_ACTIONS_FILE"] = tmp63
        queue_session_action("sess-1", "first")
        queue_session_action("sess-2", "second")
        assert len(read_pending_actions()) == 2, "both freshly-queued actions must read as pending"
        drained = drain_pending_actions()
        assert [a["sessionId"] for a in drained] == ["sess-1", "sess-2"], "drain must return the queued actions in order"
        assert read_pending_actions() == [], "after a drain, nothing must still be pending (no double-send)"
        assert drain_pending_actions() == [], "a second drain must return nothing"
        # The delivered records must still be ON DISK (audit trail), just no longer 'queued'.
        all_after = _read_all_actions()
        assert len(all_after) == 2 and all(a["status"] == "delivered" for a in all_after), \
            "drained actions must be retained with status=delivered, not deleted"
        # A brand-new queue after draining is pending again (delivered ones stay delivered).
        queue_session_action("sess-3", "third")
        assert [a["sessionId"] for a in read_pending_actions()] == ["sess-3"], \
            "a newly queued action after a drain must be the only pending one"
    finally:
        globals()["SESSION_ACTIONS_FILE"] = old_queue63
        if os.path.isfile(tmp63):
            os.remove(tmp63)
    with open(__file__, encoding="utf-8") as _f63:
        source63 = _f63.read()
    assert 'elif parsed.path == "/api/actions/pending":' in source63 and 'elif parsed.path == "/api/actions/drain":' in source63, \
        "the pending (GET) and drain (POST) action routes must be wired"
    assert '"--drain-actions" in sys.argv' in source63, "a --drain-actions CLI mode must exist for an agent to deliver queued messages"
    ok += 1; print("  PASS queue drainer: pending list + drain-marks-delivered (no double-send), retained as audit trail, routes + CLI wired")

    # 64) Hook-back telemetry: a pushed event is stored and returned while fresh, ignored once stale
    #     (never trusted past its freshness window), and the receiver route exists. This is the recon
    #     keystone's dashboard half (the hook that posts is a separate, Douglas-owned settings edit).
    total += 1
    with _SESSION_EVENTS_LOCK:
        _SESSION_EVENTS.clear()
    rec = record_session_event("tele-sess", "Notification", "waiting")
    assert rec["event"] == "Notification" and rec["state"] == "waiting", "the event must be stored as posted"
    te = latest_session_telemetry("tele-sess")
    assert te and te["state"] == "waiting", "a just-pushed event must read back while fresh"
    assert latest_session_telemetry("never-posted") is None, "a session with no telemetry returns None"
    # Force it stale and confirm it's ignored (never trusted past the freshness window).
    with _SESSION_EVENTS_LOCK:
        _SESSION_EVENTS["tele-sess"]["ts"] = _now_seconds() - (SESSION_TELEMETRY_FRESH_SECONDS + 10)
    assert latest_session_telemetry("tele-sess") is None, "stale telemetry must be ignored, not shown as current"
    with _SESSION_EVENTS_LOCK:
        _SESSION_EVENTS.clear()
    with open(__file__, encoding="utf-8") as _f64:
        source64 = _f64.read()
    assert 'elif parsed.path == "/api/session-event":' in source64, "the telemetry receiver route must be wired"
    assert "record_session_event(sid," in source64, "the receiver must actually record the pushed event"
    ok += 1; print("  PASS hook-back telemetry: pushed events stored + returned while fresh, ignored when stale, receiver route wired")

    # 40) project_skills_coverage: aliases map correctly (impeccable:* -> impeccable, grill -> grill-me,
    #     namespaced superpowers -> bare key); each invocation attributes to the DEEPEST known root of
    #     its line's cwd; counts + a most-recent timestamp aggregate across a project's transcripts;
    #     the per-file cache reuses unchanged files and invalidates on a roots change; only projects
    #     with a real run appear. Built against a synthetic transcript, no mocks of the thing tested.
    total += 1
    assert _match_skill_key("impeccable:typeset") == "impeccable" and _match_skill_key("impeccable") == "impeccable"
    assert _match_skill_key("superpowers:brainstorming") == "brainstorming"
    assert _match_skill_key("grill") == "grill-me" and _match_skill_key("grill-me") == "grill-me"
    assert _match_skill_key("solo-review") == "solo-review"
    assert _match_skill_key("deep-search") is None, "a skill NOT on the master list must not be counted"
    assert _match_skill_key("cleanup") is None and _match_skill_key("historian") is None, \
        "cleanup + historian were removed from the master list (Douglas 2026-07-07)"
    root_parent = os.path.normpath("/proj/parent")
    root_child = os.path.normpath("/proj/parent/child")
    assert _root_for_cwd(os.path.normpath("/proj/parent/child/x"), [root_parent, root_child]) == root_child, \
        "a cwd inside the nested root must attribute to the DEEPEST root, not the parent"
    import tempfile, shutil
    tmp = tempfile.mkdtemp()
    try:
        proj_dir = os.path.join(tmp, "projects", "encoded-cwd")
        os.makedirs(proj_dir)
        tr = os.path.join(proj_dir, "sess1.jsonl")
        # cwd is JSON-escaped exactly like a real transcript (doubled backslashes on Windows paths).
        pj = json.dumps(root_parent)[1:-1]  # inner (escaped) form of the path string
        cj = json.dumps(root_child)[1:-1]
        with open(tr, "w", encoding="utf-8") as f:
            # two runs in the parent, one impeccable subcommand in the child, one off-list skill ignored
            f.write('{"type":"assistant","cwd":"%s","timestamp":"2026-07-01T10:00:00Z","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"solo-review"}}]}}\n' % pj)
            f.write('{"type":"assistant","cwd":"%s","timestamp":"2026-07-03T10:00:00Z","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"superpowers:brainstorming"}}]}}\n' % pj)
            f.write('{"type":"assistant","cwd":"%s","timestamp":"2026-07-05T10:00:00Z","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"impeccable:typeset"}}]}}\n' % cj)
            f.write('{"type":"user","cwd":"%s","timestamp":"2026-07-06T10:00:00Z","message":{"content":"<command-name>grill-me</command-name>"}}\n' % cj)
            f.write('{"type":"assistant","cwd":"%s","timestamp":"2026-07-07T10:00:00Z","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"deep-search"}}]}}\n' % pj)
        old_pd, old_cf, old_lr = globals()["PROJECTS_DIR"], globals()["SKILLS_CACHE_FILE"], globals()["load_roots"]
        try:
            globals()["PROJECTS_DIR"] = os.path.join(tmp, "projects")
            globals()["SKILLS_CACHE_FILE"] = os.path.join(tmp, "skills-cache.json")
            globals()["load_roots"] = lambda: [root_parent, root_child]
            cov = project_skills_coverage()
            master_keys = [m["key"] for m in cov["master"]]
            assert master_keys == [e["key"] for e in SKILL_MASTER], "master list must be the full ordered SKILL_MASTER"
            byroot = {p["root"]: p["skills"] for p in cov["projects"]}
            assert root_parent in byroot and root_child in byroot, "both nested roots must appear as their own project"
            assert set(byroot[root_parent].keys()) == {"solo-review", "brainstorming"}, \
                "parent must have exactly its two on-list runs (deep-search excluded): got %r" % set(byroot[root_parent])
            assert byroot[root_child]["impeccable"]["count"] == 1 and byroot[root_child]["grill-me"]["count"] == 1, \
                "child must credit the impeccable subcommand and the grill->grill-me run: got %r" % byroot[root_child]
            assert byroot[root_parent]["brainstorming"]["lastTs"] == "2026-07-03T10:00:00Z", "lastTs must be the most recent run"
            assert os.path.isfile(globals()["SKILLS_CACHE_FILE"]), "the scan must persist a cache file"
            with open(globals()["SKILLS_CACHE_FILE"], encoding="utf-8") as _cf:
                assert json.load(_cf).get("files"), "the persisted cache must be valid JSON with the scanned files"
            # Unchanged file -> second call reuses the cache and returns an identical result.
            cov2 = project_skills_coverage()
            assert cov2 == cov, "an unchanged corpus must yield a byte-identical coverage result on the 2nd call"
            # Review 2026-07-07 fix: a transient missing PROJECTS_DIR must NOT purge the whole cache
            # (seen would be empty and every entry would look "vanished"). Point it at a non-existent
            # dir and confirm the cached coverage survives rather than forcing a full re-scan.
            globals()["PROJECTS_DIR"] = os.path.join(tmp, "does-not-exist")
            cov3 = project_skills_coverage()
            assert cov3 == cov, "a momentarily-absent projects dir must reuse the cache, not wipe it and re-scan to empty"
            with open(globals()["SKILLS_CACHE_FILE"], encoding="utf-8") as _cf:
                assert json.load(_cf).get("files"), "the cache file must still hold entries after an absent-dir call"
        finally:
            globals()["PROJECTS_DIR"], globals()["SKILLS_CACHE_FILE"], globals()["load_roots"] = old_pd, old_cf, old_lr
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    ok += 1; print("  PASS project_skills_coverage: alias mapping, deepest-root attribution, counts+lastTs aggregate, cache reuse, off-list excluded")

    # 40d) Recursive discovery (Douglas 2026-07-08): a flat top-level "*.jsonl" glob never saw a
    # subagent transcript nested under subagents/workflows/, and never detected a Workflow dispatch
    # (spar/tune/probe) whose embedded script only carries "export const meta = {name: '<skill>'}",
    # not a literal "skill" JSON key. Both were structurally invisible regardless of cache freshness.
    total += 1
    tmp40d = tempfile.mkdtemp()
    try:
        proj2_dir = os.path.join(tmp40d, "projects", "nested-proj")
        nested_dir = os.path.join(proj2_dir, "sess2", "subagents", "workflows", "wf_test-1")
        os.makedirs(nested_dir)
        root2 = os.path.normpath("/proj/two")
        rj2 = json.dumps(root2)[1:-1]
        with open(os.path.join(nested_dir, "agent-abc123.jsonl"), "w", encoding="utf-8") as f:
            f.write('{"type":"assistant","cwd":"%s","timestamp":"2026-07-08T09:00:00Z","message":{"content":[{"type":"tool_use","name":"Skill","input":{"skill":"solo-review"}}]}}\n' % rj2)
        script_val = "export const meta = {\n  name: 'spar',\n  description: 'x',\n}\nphase('Break')"
        script_j = json.dumps(script_val)[1:-1]
        with open(os.path.join(proj2_dir, "sess2.jsonl"), "w", encoding="utf-8") as f:
            f.write('{"type":"assistant","cwd":"%s","timestamp":"2026-07-08T09:05:00Z","message":{"content":[{"type":"tool_use","name":"Workflow","input":{"script":"%s"}}]}}\n' % (rj2, script_j))
        old_pd4, old_cf4, old_lr4 = globals()["PROJECTS_DIR"], globals()["SKILLS_CACHE_FILE"], globals()["load_roots"]
        try:
            globals()["PROJECTS_DIR"] = os.path.join(tmp40d, "projects")
            globals()["SKILLS_CACHE_FILE"] = os.path.join(tmp40d, "skills-cache.json")
            globals()["load_roots"] = lambda: [root2]
            cov4 = project_skills_coverage()
            byroot4 = {p["root"]: p["skills"] for p in cov4["projects"]}
            assert root2 in byroot4, "the nested project must appear at all: got %r" % cov4
            assert byroot4[root2].get("solo-review", {}).get("count") == 1, \
                "a transcript nested under subagents/workflows/ must be discovered and counted: got %r" % byroot4.get(root2)
            assert byroot4[root2].get("spar", {}).get("count") == 1, \
                "a Workflow dispatch's embedded \"export const meta ... name: 'spar'\" must be detected on the parent transcript's own line: got %r" % byroot4.get(root2)
        finally:
            globals()["PROJECTS_DIR"], globals()["SKILLS_CACHE_FILE"], globals()["load_roots"] = old_pd4, old_cf4, old_lr4
    finally:
        shutil.rmtree(tmp40d, ignore_errors=True)
    ok += 1; print("  PASS skills recursive discovery: nested subagent transcript + Workflow-dispatch script name both detected")

    # 40e) _discover_child_roots (Douglas 2026-07-08): auto-discovers real project subfolders instead
    # of requiring every one hand-added to roots.txt. A subfolder qualifies only if it directly
    # contains a marker (.git/CURRENT-TASK.md/package.json); junk dirs and dotfolders are never
    # descended into; a nested grandchild is found via BFS without hardcoding depth.
    total += 1
    tmp40e = tempfile.mkdtemp()
    try:
        umbrella40e = os.path.join(tmp40e, "umbrella")
        child_a = os.path.join(umbrella40e, "child-a")          # marker: .git dir
        child_b = os.path.join(umbrella40e, "child-b")          # marker: package.json
        grandchild = os.path.join(child_a, "grandchild")        # marker: CURRENT-TASK.md (nested 2 levels)
        junk_nm = os.path.join(umbrella40e, "node_modules")     # skip-listed dir name -> never descended
        junk_hidden = os.path.join(umbrella40e, ".hidden")      # dotfolder -> never descended
        plain = os.path.join(umbrella40e, "plain-folder")       # no marker -> not a root
        for d in (child_a, child_b, grandchild, junk_nm, junk_hidden, plain):
            os.makedirs(d)
        os.makedirs(os.path.join(child_a, ".git"))
        with open(os.path.join(child_b, "package.json"), "w", encoding="utf-8") as f:
            f.write("{}")
        with open(os.path.join(grandchild, "CURRENT-TASK.md"), "w", encoding="utf-8") as f:
            f.write("# task")
        with open(os.path.join(junk_nm, "package.json"), "w", encoding="utf-8") as f:
            f.write("{}")  # even WITH a marker, a skip-listed dir name must never be descended into
        discovered = set(_discover_child_roots([umbrella40e]))
        assert discovered == {umbrella40e, child_a, child_b, grandchild}, \
            "must discover marked children + nested grandchild, exclude junk/dotfolder/unmarked: got %r" % sorted(discovered)
    finally:
        shutil.rmtree(tmp40e, ignore_errors=True)
    ok += 1; print("  PASS _discover_child_roots: marker-based discovery, BFS nesting, junk/dotfolder/unmarked excluded")

    # 40f) Session folder attribution now looks at EVERY cwd line, not just the first (Douglas
    # 2026-07-08): a session launched from an umbrella folder whose real work concentrated in a known
    # child root must be attributed to that child, not the umbrella. A session that never leaves the
    # umbrella (which is itself a registered root, same as DEFAULT_ROOTS does in production for e.g.
    # "Claude GSFC Folder") correctly keeps attributing to the umbrella -- the legitimate top-level case.
    total += 1
    tmp40f = tempfile.mkdtemp()
    try:
        proj40f = os.path.join(tmp40f, "proj-x")
        os.makedirs(proj40f)
        umbrella_cwd = os.path.normpath("C:/Users/d/Documents/Umbrella Folder")
        child_cwd = os.path.normpath("C:/Users/d/Documents/Umbrella Folder/real-project")
        uj = json.dumps(umbrella_cwd)[1:-1]
        cj = json.dumps(child_cwd)[1:-1]
        # first line is the umbrella (session launched there); every later line is the real subfolder.
        with open(os.path.join(proj40f, "sess-reattr.jsonl"), "w", encoding="utf-8") as f:
            f.write('{"type":"user","cwd":"%s","message":{"content":"start here"}}\n' % uj)
            for i in range(5):
                f.write('{"type":"assistant","cwd":"%s","message":{"content":[{"type":"text","text":"working %d"}]}}\n' % (cj, i))
            f.write('{"type":"user","cwd":"%s","message":{"content":"second real message so it is not a 1-turn dispatch"}}\n' % cj)
        now40f = _now_seconds()
        os.utime(os.path.join(proj40f, "sess-reattr.jsonl"), (now40f - 60, now40f - 60))
        # a genuinely top-level session: every line stays at the umbrella, no child ever referenced.
        with open(os.path.join(proj40f, "sess-topline.jsonl"), "w", encoding="utf-8") as f:
            f.write('{"type":"user","cwd":"%s","message":{"content":"just a top-level chat"}}\n' % uj)
            f.write('{"type":"user","cwd":"%s","message":{"content":"still at the top, second turn"}}\n' % uj)
        os.utime(os.path.join(proj40f, "sess-topline.jsonl"), (now40f - 90, now40f - 90))
        old_pd40f, old_cf40f, old_lr40f = globals()["PROJECTS_DIR"], globals().get("SKILLS_CACHE_FILE"), globals()["load_roots"]
        _SESSION_META_CACHE.clear(); _ROOT_ATTR_CACHE.clear()
        try:
            globals()["PROJECTS_DIR"] = tmp40f
            globals()["load_roots"] = lambda: [umbrella_cwd, child_cwd]
            sessions40f = list_claude_sessions()
        finally:
            globals()["PROJECTS_DIR"], globals()["load_roots"] = old_pd40f, old_lr40f
        byid40f = {s["id"]: s for s in sessions40f}
        assert byid40f["sess-reattr"]["folder"] == "real-project", \
            "a session whose real work concentrated in a known child root must attribute there, not the umbrella it launched from: got %r" % byid40f["sess-reattr"]["folder"]
        assert byid40f["sess-topline"]["folder"] == "Umbrella Folder", \
            "a session with zero known-child cwd references must keep its original umbrella folder: got %r" % byid40f["sess-topline"]["folder"]
    finally:
        shutil.rmtree(tmp40f, ignore_errors=True)
    ok += 1; print("  PASS session folder re-attribution: most-referenced known child root wins over the frozen first cwd; genuine top-level sessions unaffected")

    # 40b) Adversarial-review fixes (2026-07-07). Each guards a CONFIRMED defect from the multi-lens
    #      review of this session's changes; a revert of any one would reintroduce it.
    total += 1
    with open(__file__, encoding="utf-8") as _f40b:
        src40b = _f40b.read()
    # Fix 1: the skills cache is written atomically (unique temp + os.replace) and the scan is
    # serialized by a lock, so two concurrent /api/skills requests on the threaded server can't
    # interleave into corrupt JSON or both run the cold-start corpus scan.
    assert "os.replace(tmp, SKILLS_CACHE_FILE)" in src40b and 'SKILLS_CACHE_FILE + ".tmp." + str(threading.get_ident())' in src40b, \
        "save_skills_cache must write to a unique temp file and os.replace it in (atomic, no interleave)"
    assert "_SKILLS_LOCK = threading.Lock()" in src40b and "with _SKILLS_LOCK:" in src40b, \
        "project_skills_coverage must serialize its scan+save under a lock"
    # Fix 4: the vanished-file prune lives inside the isdir() branch so a transient absent dir can't wipe the cache.
    assert re.search(r"if os\.path\.isdir\(PROJECTS_DIR\):[\s\S]*?for gone in \[p for p in list\(cache\) if p not in seen\]", src40b), \
        "the vanished-file prune must run only when the projects dir was actually walked"
    # Fix 2 (superseded 2026-07-08): session cards were exempted from the inactive filter to keep the
    # toolbar's "N of M" note honest -- but that let old sessions inflate the apparent count, so the
    # exemption is now GONE and the note is computed post-filter instead (see check 51/57 below).
    assert "c.kind === 'session' || !isInactive(c)" not in PAGE, \
        "the session-card inactive-filter exemption must stay removed (Douglas 2026-07-08: it was inflating the apparent session count)"
    # Fix 3: expanded PROJECT cards survive a column move via _openProjects + an emitted open attr.
    assert "var _openProjects = new Set();" in PAGE and "_openProjects.has(c.root) ? ' open' : ''" in PAGE, \
        "a project card must re-emit open from _openProjects so a column move doesn't collapse it"
    assert "_openProjects.add(root)" in PAGE and "_openProjects.delete(root)" in PAGE, \
        "the #cards toggle handler must track a project card's expanded state by root"
    # Fix 5: the session card's action-result carries no data-lazy (it has no lazy children; data-lazy
    # would strip its class/style on the poll while leaving stale text).
    assert '<span class="action-result"></span></summary>' in PAGE and '<span class="action-result" data-lazy>' not in PAGE, \
        "the session card's action-result must reconcile normally, not carry data-lazy"
    # Fix 6: refreshSessions has a fetch-sequence guard against out-of-order responses.
    assert "var _sessionsFetchSeq = 0;" in PAGE and "if(mySeq !== _sessionsFetchSeq) return;" in PAGE, \
        "refreshSessions needs a monotonic sequence guard like refresh()/refreshServers()"
    # Fix 7: the banned 'X, not Y' antithesis is gone from the skills UI copy + comment.
    assert "not session-based" not in PAGE, "the 'project-based, not session-based' antithesis must be gone from the UI"
    ok += 1; print("  PASS review fixes: atomic+locked skills cache, prune-guard, session inactive-exempt, project open-persist, action-result reconcile, sessions seq-guard, antithesis removed")

    # 40c) Tabs / theme / session overhaul (Douglas 2026-07-07): the whole batch of UI + data changes.
    total += 1
    # Skills master trimmed to 15 (cleanup + historian removed), then 16 after adding executing-plans.
    _skill_keys = [e["key"] for e in SKILL_MASTER]
    assert "cleanup" not in _skill_keys and "historian" not in _skill_keys, "cleanup + historian must be off the master list"
    assert "executing-plans" in _skill_keys, "executing-plans must be tracked (Douglas 2026-07-08: it never was)"
    assert len(SKILL_MASTER) == 16, "master list must be 16 skills after the trim + executing-plans: got %d" % len(SKILL_MASTER)
    # Sessions: 2-day cutoff.
    assert SESSION_RECENT_DAYS == 2, "a session untouched >2 days is auto-hidden (Douglas): got %r" % SESSION_RECENT_DAYS
    # Vertical icon-tab rail + three tabs + switching + persistence.
    assert 'class="tabrail"' in PAGE and PAGE.count('class="tab-btn"') == 4, \
        "the vertical rail needs exactly 4 icon tabs (cards/skills/servers/memory, added 2026-07-08)"
    for tab in ('data-tab="cards"', 'data-tab="skills"', 'data-tab="servers"', 'data-tab="memory"'):
        assert tab in PAGE, "missing tab %s" % tab
    assert "localStorage.setItem('dashActiveTab'" in PAGE and "localStorage.getItem('dashActiveTab')" in PAGE, \
        "the active tab must persist across reloads"
    assert 'class="tabpanel"' in PAGE and 'data-panel="cards"' in PAGE, "content must be split into tab panels"
    # Theme: true near-black background, no blue cast.
    assert "--bg:#0b0b0d" in PAGE, "the background must be a neutral near-black (Douglas: 'a type of black, not blue')"
    # Commentary removed -> ? help popover; the old always-on intro paragraph is gone.
    assert 'class="help"' in PAGE and 'class="help-body"' in PAGE, "the ? help popover must replace the intro commentary"
    assert 'Polls every 6s (scroll position preserved on refresh)' not in PAGE, "the always-on intro commentary paragraph must be gone"
    # Session cards: folder name (not full path), live timer, smaller title, longrun/watcher tag.
    assert "esc(c.folder || '')" in PAGE and "function fmtElapsed(ts)" in PAGE, "session card shows the folder name + a live elapsed timer"
    assert 'class="stimer" data-ts=' in PAGE and "querySelectorAll('.stimer')" in PAGE, "the 'time since last message' timer must tick live every second"
    assert "-webkit-line-clamp:2" in PAGE, "the session title must be clamped so cards stay compact"
    assert '<span class="ktag longrun">longrun</span>' in PAGE and '<span class="ktag watcher">watcher</span>' in PAGE, \
        "project cards need a longrun/watcher tag to tell real /longrun apart from watchers"
    # Discovered list capped to the servers list height + scrollable.
    assert re.search(r"\.servers-split \.servers > div\{[^}]*max-height:[^}]*overflow-y:auto", PAGE), \
        "the discovered list must be height-capped + scrollable, matching the servers list"
    # Skill hover surfaces WHEN it last ran.
    assert "function skillWhen(ts)" in PAGE and "last run ' + when" in PAGE, "hovering a skill chip must show when it last ran"
    ok += 1; print("  PASS tabs/theme/session overhaul: 15 skills, 2-day cutoff, 3-tab rail+persist, black theme, ? popover, folder-name+live-timer+longrun-tag, scrollable discovered, skill-when hover")

    # 40d) Round-2 adversarial-review fixes (2026-07-07): the tabs/overhaul review found 9 defects,
    #      the subagent filter ones already covered by tests 53/54; these guard the 3 UI/layout fixes.
    total += 1
    # Footer moved INSIDE .tabmain (it was ejected after .app, sprawling below a forced 100vh).
    assert re.search(r'How to \(re\)start this dashboard by hand[\s\S]{0,120}</footer>\s*</main>', PAGE), \
        "the footer must sit inside <main class=tabmain> (before </main>), not as a sibling after .app"
    # The help "?" popover gets outside-click + Escape dismissal (native <details> alone won't close).
    assert "if(help.open && !help.contains(ev.target)) help.open = false;" in PAGE and "ev.key === 'Escape'" in PAGE, \
        "the ? popover needs click-away + Escape dismissal"
    # The orphaned .sub rule is gone (its only element was the deleted intro paragraph).
    assert ".sub{color:var(--muted);margin:0 0 20px" not in PAGE, "the orphaned .sub CSS rule must be removed"
    ok += 1; print("  PASS round-2 review fixes: footer inside tabmain, help popover click-away+Escape dismissal, orphaned .sub CSS removed")

    # 64) LR-01 (2026-07-07): find_transcript must reject a session id that isn't a bare filename stem,
    #     so a caller-supplied absolute path / drive letter / '..' / glob metacharacter can't escape
    #     PROJECTS_DIR or inject a glob (an absolute-path sid was reading ANY .jsonl on disk, and a bare
    #     '*' dumped the newest transcript with no id known). A legit id must still resolve.
    total += 1
    import tempfile as _tf64, shutil as _sh64
    tmp64 = _tf64.mkdtemp()
    canary64 = _tf64.mkdtemp()   # a dir OUTSIDE the projects tree, holding a file that must stay unread
    try:
        proj64 = os.path.join(tmp64, "proj-hash"); os.makedirs(proj64)
        with open(os.path.join(proj64, "good-64.jsonl"), "w", encoding="utf-8") as f:
            f.write(json.dumps({"type": "user", "message": {"content": "hi"}}) + "\n")
        with open(os.path.join(canary64, "canary-64.jsonl"), "w", encoding="utf-8") as f:
            f.write(json.dumps({"type": "user", "message": {"content": "SHOULD NOT BE READ"}}) + "\n")
        old_pd64 = globals()["PROJECTS_DIR"]
        try:
            globals()["PROJECTS_DIR"] = tmp64
            assert find_transcript("good-64") is not None, "a normal bare session id must still resolve"
            abs_sid64 = os.path.join(canary64, "canary-64").replace("\\", "/")
            assert find_transcript(abs_sid64) is None, "an absolute-path sid must be refused, not read (LR-01)"
            assert find_transcript("*") is None, "a glob-metacharacter sid must be refused (LR-01)"
            assert find_transcript("../good-64") is None, "a '..'/separator sid must be refused (LR-01)"
            assert find_transcript("a/b") is None and find_transcript("a\\b") is None, \
                "a path-separator sid must be refused (LR-01)"
        finally:
            globals()["PROJECTS_DIR"] = old_pd64
    finally:
        _sh64.rmtree(tmp64, ignore_errors=True); _sh64.rmtree(canary64, ignore_errors=True)
    ok += 1; print("  PASS LR-01: find_transcript rejects absolute/traversal/glob session ids, a legit stem still resolves")

    # 65) LR-02 (2026-07-07): a transcript line that is valid JSON but NOT an object (a bare scalar or
    #     array) must be SKIPPED by every transcript parser, not crash it with AttributeError - live, a
    #     '[1,2,3]' line broke /api/session and a '42' line broke the whole /api/sessions response.
    total += 1
    import tempfile as _tf65, shutil as _sh65
    tmp65 = _tf65.mkdtemp()
    try:
        proj65 = os.path.join(tmp65, "proj-hash"); os.makedirs(proj65)
        with open(os.path.join(proj65, "bad-65.jsonl"), "w", encoding="utf-8") as f:
            f.write("[1,2,3]\n")   # a valid-JSON array (no .get)
            f.write("42\n")        # a valid-JSON scalar (no .get)
            f.write(json.dumps({"type": "user", "message": {"content": "the real message"}}) + "\n")
        old_pd65 = globals()["PROJECTS_DIR"]
        try:
            globals()["PROJECTS_DIR"] = tmp65
            evs = session_detail("bad-65")
            assert evs == [{"kind": "user", "text": "the real message"}], \
                "session_detail must skip non-object lines and return the good event: got %r" % evs
            u = session_usage("bad-65")
            assert isinstance(u, dict) and "estCostUsd" in u, "session_usage must not crash on a non-object line"
            assert session_pending_input("bad-65") in (True, False), "session_pending_input must not crash"
            ls = list_claude_sessions()
            assert any(s["id"] == "bad-65" for s in ls), \
                "list_claude_sessions (-> _session_meta) must still list a session that has a non-object line"
        finally:
            globals()["PROJECTS_DIR"] = old_pd65
    finally:
        _sh65.rmtree(tmp65, ignore_errors=True)
    ok += 1; print("  PASS LR-02: non-object JSON lines are skipped by session_detail/usage/pending/list, no AttributeError")

    # 66) LR-03 (2026-07-07): the request handler must set a positive socket timeout so a half-open /
    #     slowloris client (partial headers, never terminated) is dropped instead of pinning a worker
    #     thread forever. Guard the real config AND prove the mechanism (a 1s subclass keeps it fast).
    total += 1
    assert isinstance(Handler.timeout, (int, float)) and Handler.timeout > 0, \
        "Handler must set a positive socket timeout so a slow/half-open client can't pin a thread forever (LR-03)"
    import socket as _sk66, threading as _th66, socketserver as _ss66, time as _t66
    class _FastHandler66(Handler):
        timeout = 1  # fast behavioral proof; the real Handler.timeout is asserted just above
    class _Srv66(_ss66.ThreadingTCPServer):
        allow_reuse_address = True; daemon_threads = True
    srv66 = _Srv66(("127.0.0.1", 0), _FastHandler66); port66 = srv66.server_address[1]
    _th66.Thread(target=srv66.serve_forever, daemon=True).start()
    try:
        c66 = _sk66.socket(_sk66.AF_INET, _sk66.SOCK_STREAM)
        c66.connect(("127.0.0.1", port66))
        c66.sendall(b"GET / HTTP/1.1\r\nHost: x\r\n")  # NB: no terminating blank line -> half-open
        c66.settimeout(6)  # client ceiling well above the server's 1s timeout
        t0_66 = _t66.time()
        try:
            c66.recv(4096)  # server should time out near 1s and close -> b'' (or an error response)
        except _sk66.timeout:
            raise AssertionError("half-open connection was NOT dropped within 6s - no server timeout in effect (LR-03)")
        elapsed66 = _t66.time() - t0_66
        c66.close()
        assert elapsed66 < 5, "the half-open connection must be dropped near the 1s timeout, not held: took %.1fs" % elapsed66
    finally:
        srv66.shutdown(); srv66.server_close()
    ok += 1; print("  PASS LR-03: Handler sets a positive socket timeout; a half-open connection is dropped, not held")

    # 67) LR-04 (2026-07-07): POST /api/sessions/action must reject a non-string sessionId/text instead
    #     of silently str()-coercing a dict/list into the shared queue, and queue_session_action must
    #     refuse once the queue file hits SESSION_ACTIONS_MAX (unauthenticated disk-fill guard).
    total += 1
    import threading as _th67, socketserver as _ss67, http.client as _hc67, tempfile as _tf67
    class _Srv67(_ss67.ThreadingTCPServer):
        allow_reuse_address = True; daemon_threads = True
    tmpq67 = _tf67.mktemp(suffix=".jsonl")
    old_q67 = globals()["SESSION_ACTIONS_FILE"]
    srv67 = _Srv67(("127.0.0.1", 0), Handler); port67 = srv67.server_address[1]
    _th67.Thread(target=srv67.serve_forever, daemon=True).start()
    try:
        globals()["SESSION_ACTIONS_FILE"] = tmpq67
        def _post67(payload):
            c = _hc67.HTTPConnection("127.0.0.1", port67, timeout=8)
            c.request("POST", "/api/sessions/action", body=json.dumps(payload),
                      headers={"Content-Type": "application/json"})
            r = c.getresponse(); b = json.loads(r.read().decode("utf-8")); c.close(); return b
        bad67 = _post67({"sessionId": {"a": 1}, "text": ["x"]})
        assert bad67.get("ok") is False, \
            "a non-string sessionId/text must be rejected, not coerced+written: got %r" % bad67
        assert (not os.path.isfile(tmpq67)) or _read_all_actions() == [], \
            "a rejected action must not append anything to the queue file"
        good67 = _post67({"sessionId": "sess-x", "text": "hi"})
        assert good67.get("ok") is True and good67["queued"]["sessionId"] == "sess-x", \
            "a valid string action must still be queued: got %r" % good67
    finally:
        globals()["SESSION_ACTIONS_FILE"] = old_q67
        srv67.shutdown(); srv67.server_close()
        if os.path.isfile(tmpq67): os.remove(tmpq67)
    # queue cap: queue_session_action refuses once the file reaches SESSION_ACTIONS_MAX records
    tmpq67b = _tf67.mktemp(suffix=".jsonl")
    old_q67b = globals()["SESSION_ACTIONS_FILE"]; old_max67 = globals()["SESSION_ACTIONS_MAX"]
    try:
        globals()["SESSION_ACTIONS_FILE"] = tmpq67b
        globals()["SESSION_ACTIONS_MAX"] = 3
        for i in range(3):
            queue_session_action("s%d" % i, "t")
        raised67 = False
        try:
            queue_session_action("overflow", "t")
        except SessionQueueFull:
            raised67 = True
        assert raised67, "queue_session_action must raise SessionQueueFull once the queue hits the cap (LR-04)"
        assert len(_read_all_actions()) == 3, \
            "the over-cap append must NOT have been written: got %d records" % len(_read_all_actions())
    finally:
        globals()["SESSION_ACTIONS_FILE"] = old_q67b; globals()["SESSION_ACTIONS_MAX"] = old_max67
        if os.path.isfile(tmpq67b): os.remove(tmpq67b)
    ok += 1; print("  PASS LR-04: non-string sessionId/text rejected (not coerced), queue refuses past SESSION_ACTIONS_MAX")

    # 68) LR2-02 (2026-07-07 spar round 2): is_protected_port must shield the CANONICAL dashboard port
    #     (8756) even when THIS instance is bound to a different port, because 8756 is itself a
    #     stoppable server in a launch.json - otherwise a second instance (or a CSRF-driven stop) kills
    #     the primary dashboard.
    total += 1
    assert is_protected_port(CANONICAL_DASHBOARD_PORT, own_port=8799) is True, \
        "the canonical dashboard port must be protected even from a non-canonical instance (LR2-02)"
    assert is_protected_port(9123, own_port=8799) is False, \
        "an unrelated port is still stoppable from a non-canonical instance"
    ok += 1; print("  PASS LR2-02: is_protected_port shields the canonical 8756 even from a non-8756 instance")

    # 69) LR2-01 (2026-07-07 spar round 2): a state-changing POST carrying a cross-origin Origin/Referer
    #     must be refused (CSRF/DNS-rebind), while a same-origin Origin and a non-browser (no-Origin)
    #     request are accepted. Defends the process start/stop + queue endpoints against a malicious page
    #     open in Douglas's browser.
    total += 1
    import threading as _th69, socketserver as _ss69, http.client as _hc69, tempfile as _tf69
    class _Srv69(_ss69.ThreadingTCPServer):
        allow_reuse_address = True; daemon_threads = True
    srv69 = _Srv69(("127.0.0.1", 0), Handler); port69 = srv69.server_address[1]
    _th69.Thread(target=srv69.serve_forever, daemon=True).start()
    tmpq69 = _tf69.mktemp(suffix=".jsonl"); old_q69 = globals()["SESSION_ACTIONS_FILE"]
    try:
        globals()["SESSION_ACTIONS_FILE"] = tmpq69
        def _post69(headers):
            c = _hc69.HTTPConnection("127.0.0.1", port69, timeout=8)
            h = {"Content-Type": "application/json"}; h.update(headers)
            c.request("POST", "/api/sessions/action", body=json.dumps({"sessionId": "s", "text": "hi"}), headers=h)
            r = c.getresponse(); code = r.status; b = json.loads(r.read().decode("utf-8")); c.close(); return code, b
        code_evil, b_evil = _post69({"Origin": "http://evil.example"})
        assert code_evil == 403 and b_evil.get("ok") is False, \
            "a cross-origin Origin must be refused with 403 (LR2-01): got %s %r" % (code_evil, b_evil)
        code_ref, b_ref = _post69({"Referer": "http://attacker.test/x"})
        assert code_ref == 403 and b_ref.get("ok") is False, \
            "a cross-origin Referer must be refused (LR2-01): got %s %r" % (code_ref, b_ref)
        code_ok, b_ok = _post69({"Origin": "http://127.0.0.1:%d" % port69})
        assert code_ok == 200 and b_ok.get("ok") is True, \
            "a same-origin Origin must be accepted (LR2-01): got %s %r" % (code_ok, b_ok)
        code_none, b_none = _post69({})
        assert code_none == 200 and b_none.get("ok") is True, \
            "a non-browser request with no Origin/Referer must still work (LR2-01): got %s %r" % (code_none, b_none)
    finally:
        globals()["SESSION_ACTIONS_FILE"] = old_q69
        srv69.shutdown(); srv69.server_close()
        if os.path.isfile(tmpq69): os.remove(tmpq69)
    ok += 1; print("  PASS LR2-01: cross-origin Origin/Referer refused (403); same-origin + non-browser accepted")

    # 70) LR2-03 (2026-07-07 spar round 2): an oversized or negative Content-Length must be refused
    #     BEFORE the body is read, so a huge/absent body can't pin a worker or exhaust memory.
    total += 1
    import socket as _sk70, threading as _th70, socketserver as _ss70, time as _t70
    class _Srv70(_ss70.ThreadingTCPServer):
        allow_reuse_address = True; daemon_threads = True
    srv70 = _Srv70(("127.0.0.1", 0), Handler); port70 = srv70.server_address[1]
    _th70.Thread(target=srv70.serve_forever, daemon=True).start()
    try:
        def _raw70(cl_header):
            c = _sk70.socket(); c.connect(("127.0.0.1", port70)); c.settimeout(6)
            req = ("POST /api/sessions/action HTTP/1.1\r\nHost: 127.0.0.1:%d\r\n"
                   "Origin: http://127.0.0.1:%d\r\nContent-Type: application/json\r\n"
                   "Content-Length: %s\r\nConnection: close\r\n\r\n{}" % (port70, port70, cl_header))
            c.sendall(req.encode()); t0 = _t70.time(); data = b""
            try:
                while True:
                    chunk = c.recv(4096)
                    if not chunk: break
                    data += chunk
            except _sk70.timeout:
                pass
            c.close(); return (_t70.time() - t0), data
        el_big, data_big = _raw70(str(MAX_POST_BODY_BYTES + 1))
        assert b"too large" in data_big and el_big < 5, \
            "an oversized Content-Length must be refused fast, not read/hung (LR2-03): %.1fs %r" % (el_big, data_big[:120])
        el_neg, data_neg = _raw70("-1")
        assert b"negative" in data_neg and el_neg < 5, \
            "a negative Content-Length must be refused fast, not read-to-EOF (LR2-03): %.1fs %r" % (el_neg, data_neg[:120])
    finally:
        srv70.shutdown(); srv70.server_close()
    ok += 1; print("  PASS LR2-03: oversized/negative Content-Length refused before read (no hang)")

    # 71) LR2-04 (2026-07-07 spar round 2): a deeply-nested JSON body raises RecursionError (a
    #     RuntimeError, NOT a ValueError), which the old except missed - the worker died and the client
    #     got a dropped connection. It must now return a normal {"ok": false} response.
    total += 1
    import threading as _th71, socketserver as _ss71, http.client as _hc71
    class _Srv71(_ss71.ThreadingTCPServer):
        allow_reuse_address = True; daemon_threads = True
    srv71 = _Srv71(("127.0.0.1", 0), Handler); port71 = srv71.server_address[1]
    _th71.Thread(target=srv71.serve_forever, daemon=True).start()
    try:
        nested71 = "[" * 100000 + "]" * 100000
        body71 = '{"sessionId":"x","text":' + nested71 + '}'
        c71 = _hc71.HTTPConnection("127.0.0.1", port71, timeout=8)
        c71.request("POST", "/api/sessions/action", body=body71,
                    headers={"Content-Type": "application/json", "Origin": "http://127.0.0.1:%d" % port71})
        r71 = c71.getresponse(); b71 = json.loads(r71.read().decode("utf-8")); c71.close()
        assert b71.get("ok") is False, \
            "deeply-nested JSON must return a clean error, not crash the worker (LR2-04): %r" % b71
    finally:
        srv71.shutdown(); srv71.server_close()
    ok += 1; print("  PASS LR2-04: deeply-nested JSON returns a clean error (RecursionError caught), no dropped connection")

    # 72) derive_status boundary/label coverage (probe mutation survivors, 2026-07-07): the core status
    #     gate had only 2 of ~9 branches tested, so boundary flips (>= vs >) and label swaps survived
    #     mutation. Pin the age-threshold decisions and the ALLOW/completion/blocked labels.
    total += 1
    import time as _t72
    def _tr72(age_s):
        return {"mtime": _t72.time() - age_s}
    assert derive_status({}, "keep-going: BLOCK forced", _tr72(10))[0] == "continuing", \
        "BLOCK + fresh transcript (<300s) -> continuing"
    assert derive_status({}, "keep-going: BLOCK forced", _tr72(STALL_AGE_SECONDS + 60))[0] == "stalled", \
        "BLOCK + age at/past STALL_AGE_SECONDS -> stalled (kills the >= boundary mutant)"
    assert derive_status({}, "keep-going: BLOCK forced", _tr72((300 + STALL_AGE_SECONDS) // 2))[0] == "idle", \
        "BLOCK + age between 300 and STALL_AGE_SECONDS -> idle"
    assert derive_status({}, "keep-going: ALLOW", _tr72(10))[0] == "idle", \
        "ALLOW -> idle (kills the 'idle'->'active' label mutant)"
    assert derive_status({}, "queue empty; work complete", _tr72(10))[0] == "finished", \
        "the 'queue empty; work complete' recognition string -> finished"
    assert derive_status({"need_user": True}, "anything", _tr72(10))[0] == "blocked", \
        "the need_user sentinel -> blocked"
    ok += 1; print("  PASS derive_status: age-threshold + ALLOW/completion/blocked branches pinned (kills 3 mutation survivors)")

    # 73) BUG-A (probe property counterexample, 2026-07-07): session_usage must never return a negative
    #     contextPct/contextTokens/estCostUsd even if a transcript carries a malformed negative token
    #     field - the old min(1.0, ...) bounded only the top.
    total += 1
    import tempfile as _tf73, shutil as _sh73
    tmp73 = _tf73.mkdtemp()
    try:
        proj73 = os.path.join(tmp73, "proj-hash"); os.makedirs(proj73)
        with open(os.path.join(proj73, "neg-73.jsonl"), "w", encoding="utf-8") as f:
            f.write(json.dumps({"type": "assistant", "message": {"model": "claude-sonnet-4-6",
                    "usage": {"input_tokens": -100, "output_tokens": -5}}}) + "\n")
        old_pd73 = globals()["PROJECTS_DIR"]
        try:
            globals()["PROJECTS_DIR"] = tmp73
            u73 = session_usage("neg-73")
            assert u73["contextPct"] >= 0.0 and u73["contextTokens"] >= 0 and u73["estCostUsd"] >= 0.0, \
                "session_usage must clamp a malformed negative-token transcript to >= 0: got %r" % u73
        finally:
            globals()["PROJECTS_DIR"] = old_pd73
    finally:
        _sh73.rmtree(tmp73, ignore_errors=True)
    ok += 1; print("  PASS BUG-A: session_usage clamps a malformed negative-token transcript to non-negative")

    # 74) tune C1 (2026-07-07): the parallel cold-scan path must produce output byte-identical to the
    #     serial scan. Build a temp corpus above the threshold, run coverage forcing parallel (low
    #     threshold) vs forcing serial (huge threshold), and assert the two are identical.
    total += 1
    import tempfile as _tf74, shutil as _sh74
    tmp74 = _tf74.mkdtemp()
    old_pd74 = globals()["PROJECTS_DIR"]; old_cf74 = globals()["SKILLS_CACHE_FILE"]
    old_thr74 = globals()["_SKILLS_PARALLEL_THRESHOLD"]
    try:
        proj74 = os.path.join(tmp74, "C--proj-alpha"); os.makedirs(proj74)
        root74 = old_pd74  # any stable string is a valid "root"; used for cwd attribution
        for i in range(40):  # > the real threshold, so a low test threshold forces the parallel path
            with open(os.path.join(proj74, "s%02d.jsonl" % i), "w", encoding="utf-8") as f:
                if i % 5 == 0:
                    f.write('{"cwd": %s, "timestamp": "2026-07-07T00:00:%02dZ", "skill": "spar"}\n'
                            % (json.dumps(root74), i))
                else:
                    f.write(json.dumps({"type": "user", "message": {"content": "hi"}}) + "\n")
        globals()["PROJECTS_DIR"] = tmp74
        def _cov74(threshold):
            globals()["_SKILLS_PARALLEL_THRESHOLD"] = threshold
            globals()["SKILLS_CACHE_FILE"] = os.path.join(tmp74, "cache-%d.json" % threshold)
            return json.dumps(project_skills_coverage(roots=[root74]), sort_keys=True)
        parallel_out74 = _cov74(1)       # threshold 1 -> 40 files > 1 -> parallel path engages
        serial_out74 = _cov74(10_000)    # threshold huge -> serial path
        assert parallel_out74 == serial_out74, \
            "parallel cold-scan output must be byte-identical to serial (tune C1):\nP=%s\nS=%s" \
            % (parallel_out74[:300], serial_out74[:300])
        assert '"spar"' in parallel_out74, "the temp corpus's spar runs must actually be counted (sanity)"
    finally:
        globals()["PROJECTS_DIR"] = old_pd74; globals()["SKILLS_CACHE_FILE"] = old_cf74
        globals()["_SKILLS_PARALLEL_THRESHOLD"] = old_thr74
        _sh74.rmtree(tmp74, ignore_errors=True)
    ok += 1; print("  PASS tune C1: parallel cold-scan output is byte-identical to serial (40-file temp corpus)")

    # 75) probe mutation survivors (2026-07-07): pin the remaining boundary/label comparisons the suite
    #     missed, so a >=/> flip, a case change, or a dropped disjunct is caught.
    total += 1
    assert parse_checklist("- [x] done\n- [ ] todo")["x"] == 1, \
        "parse_checklist must count the lowercase '- [x]' prefix (a '- [X]' mutant would miss it)"
    assert size_risk(CRIT_BYTES) == "critical", \
        "size_risk at exactly CRIT_BYTES must be 'critical' (the >= boundary is inclusive)"
    assert (1024, 7) in filter_discovered([(1024, 7)], set(), min_port=1024), \
        "filter_discovered must include a port == min_port (>= boundary is inclusive)"
    assert (1023, 7) not in filter_discovered([(1023, 7)], set(), min_port=1024), \
        "filter_discovered must exclude a port below min_port"
    _now75 = 1_000_000
    assert freshness_note(_now75, _now75 - FRESHNESS_GAP_SECONDS, _now75) is not None, \
        "freshness_note at a gap of exactly FRESHNESS_GAP_SECONDS must return a note (strict < boundary)"
    assert freshness_note(_now75, _now75 - 10, _now75) is None, "a tiny gap must return no note"
    assert plain_project_status({"open": 0, "wip": 0, "parked": 1, "blocked": 0}, _now75, _now75)[0] == "continuing", \
        "a parked-only checklist must NOT read 'finished' (parked stays in the has_remaining OR-chain)"
    _board75 = {"items": [{"marker": "x", "text": "alpha beta gamma"}]}
    assert current_item_conflict("alpha beta gamma", _board75) is not None, \
        "an exact 3-word match must flag a conflict (the >= 3 shared-words boundary is inclusive)"
    _board75b = {"items": [{"marker": "x", "text": "alpha beta gamma delta epsilon zeta eta theta iota"}]}
    assert current_item_conflict("alpha beta gamma delta", _board75b) is None, \
        "a 4/9 = 0.44 shared-word fraction is below 0.5 and must NOT flag (the >= 0.5 boundary)"
    ok += 1; print("  PASS probe survivors: parse_checklist/size_risk/filter_discovered/freshness_note/plain_project_status/current_item_conflict boundaries pinned")

    # 76) LR3-01 (2026-07-07): a transcript line that IS a valid JSON object (so it passes the LR-02
    #     top-level isinstance(event, dict) guard) but whose nested `message` is a TRUTHY non-dict
    #     (a string / non-empty list / non-zero number / True) must not crash the parsers. The old
    #     `(event.get("message") or {}).get(...)` idiom let the non-dict through `or {}` and then
    #     .get raised AttributeError - which propagated out of the wrapper-less do_GET, aborted the
    #     request with no HTTP response, and (because _session_meta runs on EVERY transcript in the
    #     window) broke the entire /api/sessions poll on a single malformed transcript anywhere.
    total += 1
    import tempfile as _tf76, shutil as _sh76
    tmp76 = _tf76.mkdtemp()
    old_pd76 = globals()["PROJECTS_DIR"]
    try:
        proj76 = os.path.join(tmp76, "C--proj-76"); os.makedirs(proj76)
        sid76 = "deadbeefcafe76"
        path76 = os.path.join(proj76, sid76 + ".jsonl")
        globals()["PROJECTS_DIR"] = tmp76
        for _bad76 in ('"a bare string, not a dict"', "[1,2,3]", "42", "true"):
            # type=user exercises _session_meta/session_detail/session_usage's message access
            with open(path76, "w", encoding="utf-8") as _f76:
                _f76.write('{"type":"user","message":%s}\n' % _bad76)
            session_detail(sid76); session_usage(sid76); _session_meta(path76)
            session_pending_input(sid76)
            # type=assistant is what reaches session_pending_input's message.get("stop_reason")
            with open(path76, "w", encoding="utf-8") as _f76:
                _f76.write('{"type":"assistant","message":%s}\n' % _bad76)
            assert session_pending_input(sid76) is False, \
                "a non-dict assistant message must read as 'not paused', not crash (%s)" % _bad76
            session_detail(sid76); session_usage(sid76); _session_meta(path76)
    finally:
        globals()["PROJECTS_DIR"] = old_pd76
        _sh76.rmtree(tmp76, ignore_errors=True)
    ok += 1; print("  PASS LR3-01: parsers survive a truthy non-dict `message` (str/list/number/bool), no AttributeError")

    # 77) LR3-02 (2026-07-07): the shared action-queue file's read-modify-write had NO lock (unlike the
    #     telemetry store and skills cache). On the ThreadingTCPServer + the separate --drain-actions
    #     process this raced two ways: (A) concurrent drains each read the same pending set before any
    #     rewrote 'delivered', so the SAME action was handed out multiple times (double delivery); and
    #     (B) an append landing between a drain's read and its truncating rewrite was silently dropped
    #     (lost update). _action_queue_locked() now serializes queue_session_action + drain.
    total += 1
    import tempfile as _tf77, threading as _th77
    from collections import Counter as _Ctr77
    old_q77 = globals()["SESSION_ACTIONS_FILE"]; old_max77 = globals()["SESSION_ACTIONS_MAX"]
    tmp77 = _tf77.mktemp(suffix=".jsonl")
    try:
        globals()["SESSION_ACTIONS_FILE"] = tmp77
        globals()["SESSION_ACTIONS_MAX"] = 10_000_000
        # (A) no double-delivery: K threads all drain at once behind a barrier
        N77 = 300; K77 = 6
        for _i77 in range(N77):
            queue_session_action("s", "d-%d" % _i77)
        counts77 = _Ctr77(); clock77 = _th77.Lock(); barrier77 = _th77.Barrier(K77)
        def _drain77():
            barrier77.wait()
            d = drain_pending_actions()
            with clock77:
                for a in d:
                    counts77[a["text"]] += 1
        ts77 = [_th77.Thread(target=_drain77) for _ in range(K77)]
        for t in ts77: t.start()
        for t in ts77: t.join()
        assert sum(counts77.values()) == N77 and len(counts77) == N77, \
            "each queued action must be delivered exactly once across concurrent drains (no double-" \
            "delivery): total=%d distinct=%d" % (sum(counts77.values()), len(counts77))
        # (B) no lost-update: a producer appends while a drainer loops
        if os.path.isfile(tmp77): os.remove(tmp77)
        produced77 = ["p-%d" % _i for _i in range(300)]
        got77 = []; gotlock77 = _th77.Lock(); stop77 = _th77.Event()
        def _prod77():
            for _t in produced77:
                queue_session_action("s", _t)
        def _dr77():
            while not stop77.is_set():
                d = drain_pending_actions()
                with gotlock77:
                    got77.extend(a["text"] for a in d)
        pth77 = _th77.Thread(target=_prod77); dth77 = _th77.Thread(target=_dr77)
        pth77.start(); dth77.start(); pth77.join(); stop77.set(); dth77.join()
        got77.extend(a["text"] for a in drain_pending_actions())
        still77 = {a["text"] for a in _read_all_actions() if a.get("status") == "queued"}
        delivered77 = _Ctr77(got77)
        lost77 = [t for t in produced77 if delivered77[t] == 0 and t not in still77]
        dbl77 = [t for t, c in delivered77.items() if c > 1]
        assert not lost77 and not dbl77, \
            "no produced action may be lost or double-delivered: lost=%d doubled=%d" % (len(lost77), len(dbl77))
    finally:
        globals()["SESSION_ACTIONS_FILE"] = old_q77; globals()["SESSION_ACTIONS_MAX"] = old_max77
        for _p77 in (tmp77, tmp77 + ".lock"):
            if os.path.isfile(_p77):
                try: os.remove(_p77)
                except OSError: pass
    ok += 1; print("  PASS LR3-02: action-queue read-modify-write serialized (no lost-update, no double-delivery under concurrency)")

    # 78) LR3-03 (2026-07-07): the in-memory telemetry store _SESSION_EVENTS grew without bound. It is
    #     reachable via the unauthenticated POST /api/session-event, so a flood of unique sessionIds grew
    #     process memory without limit (the in-memory parallel of the LR-04 on-disk disk-fill guard).
    #     record_session_event now caps the store at SESSION_EVENTS_MAX (stale entries first, then oldest).
    total += 1
    with _SESSION_EVENTS_LOCK:
        _SESSION_EVENTS.clear()
    for _i78 in range(SESSION_EVENTS_MAX + 500):
        record_session_event("flood-%d" % _i78, "e", "s")
    assert len(_SESSION_EVENTS) <= SESSION_EVENTS_MAX, \
        "the telemetry store must stay bounded under a unique-sessionId flood (LR3-03): %d > %d" \
        % (len(_SESSION_EVENTS), SESSION_EVENTS_MAX)
    assert latest_session_telemetry("flood-%d" % (SESSION_EVENTS_MAX + 499)) is not None, \
        "the most-recent push must survive the cap (eviction drops the OLDEST, never the newest)"
    with _SESSION_EVENTS_LOCK:
        _SESSION_EVENTS.clear()
    ok += 1; print("  PASS LR3-03: in-memory telemetry store bounded at SESSION_EVENTS_MAX (stale-then-oldest eviction)")

    # 79) LR4-01 (2026-07-07): the LR-02/LR3-01 hardening guarded the CONTAINER levels (event/message/
    #     usage are dicts) but the LEAF values were still used unguarded. A transcript line that is a
    #     valid JSON object with a valid dict message/usage/content, but whose leaf has the wrong TYPE
    #     (a str/list token count, a numeric `text`, a str tool_use `input`), raised TypeError/
    #     AttributeError in a code path OUTSIDE each parser's OSError/JSONDecodeError try - propagating
    #     out of the wrapper-less do_GET and dropping the client connection, the exact LR-02 failure
    #     signature. session_usage runs on the display set; _session_meta runs on EVERY transcript in
    #     the window, so one bad file crashed the whole /api/sessions poll. The leaf reads now coerce/
    #     skip by type (_num_or_zero for tokens; isinstance(text,str) / isinstance(input,dict) guards).
    total += 1
    import tempfile as _tf79, shutil as _sh79
    tmp79 = _tf79.mkdtemp()
    old_pd79 = globals()["PROJECTS_DIR"]
    try:
        proj79 = os.path.join(tmp79, "C--proj-79"); os.makedirs(proj79)
        sid79 = "deadbeefcafe79"
        path79 = os.path.join(proj79, sid79 + ".jsonl")
        globals()["PROJECTS_DIR"] = tmp79
        def _w79(obj):
            with open(path79, "w", encoding="utf-8") as _f:
                _f.write(json.dumps(obj) + "\n")
        # session_usage: a non-numeric token leaf must coerce to 0, never raise TypeError.
        for _bad_tok in ("100", [1, 2, 3], None, {"n": 1}):
            _w79({"type": "assistant", "message": {"usage": {"input_tokens": _bad_tok,
                  "cache_read_input_tokens": _bad_tok}}})
            u79 = session_usage(sid79)
            assert u79["contextTokens"] == 0 and u79["estCostUsd"] >= 0.0, \
                "a non-numeric token leaf must coerce to 0, not crash (LR4-01): %r -> %r" % (_bad_tok, u79)
        # session_detail: a non-str `text` leaf and a non-dict tool_use `input` leaf must be skipped.
        for _bad in (
            {"type": "assistant", "message": {"content": [{"type": "text", "text": 123}]}},
            {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash", "input": "not-a-dict"}]}},
            {"type": "user", "message": {"content": [{"type": "text", "text": 999}]}},
        ):
            _w79(_bad)
            assert isinstance(session_detail(sid79), list), \
                "session_detail must return a list, not crash, on a wrong-typed leaf (LR4-01): %r" % _bad
        # _session_meta runs on EVERY transcript in the window: a numeric user `text` must not crash it.
        _w79({"type": "user", "cwd": "C:/x", "message": {"content": [{"type": "text", "text": 42}]}})
        assert _session_meta(path79)[0] is None, \
            "a numeric `text` leaf yields no title, not an AttributeError (LR4-01)"
        # Control: a well-typed transcript still parses correctly (the guards don't drop valid data).
        _w79({"type": "assistant", "message": {"model": "claude-sonnet-4-6",
              "usage": {"input_tokens": 10, "cache_read_input_tokens": 5},
              "content": [{"type": "text", "text": "real assistant text"}]}})
        assert session_usage(sid79)["contextTokens"] == 15, "a valid token leaf must still sum (control)"
        assert any(e.get("text") == "real assistant text" for e in session_detail(sid79)), \
            "a valid text leaf must still be surfaced (control)"
    finally:
        globals()["PROJECTS_DIR"] = old_pd79
        _sh79.rmtree(tmp79, ignore_errors=True)
    ok += 1; print("  PASS LR4-01: parsers survive wrong-TYPED leaf values (str/list token, numeric text, str tool_use input)")

    # 80) LR4-02 (2026-07-07): the embedded JS in the PAGE literal used `\/` (an invalid Python string
    #     escape), so a fresh direct run emitted a SyntaxWarning that a future Python may promote to a
    #     SyntaxError. Guard the whole file's source against ANY invalid escape by compiling it with
    #     SyntaxWarning raised as an error - re-introducing a bad escape anywhere now fails the suite.
    total += 1
    import warnings as _w80
    with open(os.path.abspath(__file__), "r", encoding="utf-8") as _f80:
        _src80 = _f80.read()
    with _w80.catch_warnings():
        _w80.simplefilter("error", SyntaxWarning)
        compile(_src80, os.path.abspath(__file__), "exec")  # raises on any invalid escape sequence
    assert r"String(root).split(/[\\/]/)" in PAGE, \
        "the lastSegment regex must still receive the byte-identical /[\\/]/ char-class (LR4-02)"
    ok += 1; print("  PASS LR4-02: file source compiles with no SyntaxWarning; PAGE regex byte-identical")

    # 81) LR5-01 (2026-07-07): POST /api/longruns/archive|unarchive did an UNSYNCHRONIZED load->mutate->
    #     save of the archived-roots file. On the ThreadingTCPServer, two concurrent archive/unarchive
    #     POSTs each read the same set, mutated a private copy, and the last writer clobbered the other's
    #     change (lost update) - a card the user archived silently stayed visible. set_archived() now
    #     serializes the read-modify-write behind _ARCHIVE_LOCK (structurally identical to the LR3-02
    #     action-queue fix; the archive file has no cross-process writer, so an in-process Lock suffices).
    total += 1
    import tempfile as _tf81, threading as _th81
    old_af81 = globals()["ARCHIVE_FILE"]
    tmp81 = _tf81.mktemp(suffix=".json")
    try:
        globals()["ARCHIVE_FILE"] = tmp81
        if os.path.isfile(tmp81):
            os.remove(tmp81)
        # (A) no lost-update on concurrent archive: N distinct roots added at once behind a barrier.
        N81 = 200
        barrier81 = _th81.Barrier(N81)
        def _arch81(i):
            barrier81.wait()
            set_archived("root-%03d" % i, True)
        ts81 = [_th81.Thread(target=_arch81, args=(i,)) for i in range(N81)]
        for t in ts81: t.start()
        for t in ts81: t.join()
        present81 = load_archived()
        lost81 = [i for i in range(N81) if ("root-%03d" % i) not in present81]
        assert not lost81, \
            "every concurrent archive must survive (no lost update, LR5-01): %d/%d lost, sample=%s" \
            % (len(lost81), N81, sorted(lost81)[:8])
        # (B) concurrent unarchive of that same set must remove all of them, none clobbered back in.
        barrier81b = _th81.Barrier(N81)
        def _unarch81(i):
            barrier81b.wait()
            set_archived("root-%03d" % i, False)
        ts81b = [_th81.Thread(target=_unarch81, args=(i,)) for i in range(N81)]
        for t in ts81b: t.start()
        for t in ts81b: t.join()
        assert load_archived() == set(), \
            "concurrent unarchive must remove every root (no lost update, LR5-01): survivors=%r" \
            % sorted(load_archived())[:8]
    finally:
        globals()["ARCHIVE_FILE"] = old_af81
        if os.path.isfile(tmp81):
            try: os.remove(tmp81)
            except OSError: pass
    ok += 1; print("  PASS LR5-01: archive/unarchive read-modify-write serialized (no lost update under concurrency)")

    # 82) LR5-02 (2026-07-07): the in-memory telemetry store bounded ENTRY COUNT (LR3-03) but not per-entry
    #     VALUE SIZE. /api/session-event accepts up to MAX_POST_BODY_BYTES (1MB) per request, so ~1MB fields
    #     x SESSION_EVENTS_MAX entries could cost ~0.6-1GB resident - the count bound did NOT bound memory.
    #     record_session_event now caps each stored field AND the session_id key at SESSION_EVENT_VALUE_MAX.
    total += 1
    with _SESSION_EVENTS_LOCK:
        _SESSION_EVENTS.clear()
    big82 = "X" * 1000000
    rec82 = record_session_event("sid" + big82, big82, big82)
    key82 = next(iter(_SESSION_EVENTS))
    assert len(key82) <= SESSION_EVENT_VALUE_MAX, \
        "the session_id KEY must be capped (LR5-02): %d > %d" % (len(key82), SESSION_EVENT_VALUE_MAX)
    assert len(rec82["event"]) <= SESSION_EVENT_VALUE_MAX and len(rec82["state"]) <= SESSION_EVENT_VALUE_MAX, \
        "event/state fields must be capped (LR5-02): event=%d state=%d > %d" \
        % (len(rec82["event"]), len(rec82["state"]), SESSION_EVENT_VALUE_MAX)
    # Control: an ordinary-length push round-trips byte-for-byte (the cap doesn't truncate real data).
    with _SESSION_EVENTS_LOCK:
        _SESSION_EVENTS.clear()
    rec82b = record_session_event("real-sid", "Notification", "waiting")
    assert rec82b == {"event": "Notification", "state": "waiting", "ts": rec82b["ts"]} \
        and latest_session_telemetry("real-sid") is not None, \
        "a normal-length event must be stored unchanged (LR5-02 control)"
    with _SESSION_EVENTS_LOCK:
        _SESSION_EVENTS.clear()
    ok += 1; print("  PASS LR5-02: telemetry field values + session_id key capped at SESSION_EVENT_VALUE_MAX")

    # 107) Memory tracker (2026-07-08): sample_memory() must degrade gracefully when node isn't on
    #      PATH, never raise, and never fabricate numbers.
    total += 1
    old_path107 = globals().get("MEMORY_RECORDER_PATH")
    globals()["MEMORY_RECORDER_PATH"] = os.path.join(os.path.dirname(os.path.abspath(__file__)), "does-not-exist-107.mjs")
    old_which107 = shutil.which
    shutil.which = lambda name: None  # force the "node not found" path deterministically
    try:
        result107 = sample_memory()
        assert result107.get("available") is False, "sample_memory must report unavailable when node is missing, not raise"
        assert "reason" in result107, "an unavailable result must say WHY"
    finally:
        shutil.which = old_which107
        if old_path107 is not None:
            globals()["MEMORY_RECORDER_PATH"] = old_path107
    ok += 1; print("  PASS memory tracker: sample_memory() degrades to available=False when node is missing (no raise)")

    # 108) Memory tracker: bucket classifier matches Douglas's exact 5 groups, first-match-wins order,
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

    # 109) Memory tracker: classify_trend compares latest vs OLDEST sample in the ring (not vs the
    #      immediately-prior one), using the decided +-2pp commitPct threshold; <2 samples -> unknown.
    total += 1
    ring109 = collections.deque(maxlen=8)
    assert classify_trend(ring109) == "unknown", "an empty ring must report unknown, not guess"
    ring109.append({"commitPct": 0.50})
    assert classify_trend(ring109) == "unknown", "a single sample must report unknown, not guess"
    ring109.append({"commitPct": 0.53})
    assert classify_trend(ring109) == "growing", "a +3pp delta must read as growing (threshold is +-2pp)"
    ring109.append({"commitPct": 0.51})  # oldest is still 0.50 -> delta vs oldest = +1pp = flat
    assert classify_trend(ring109) == "flat", "must compare vs the OLDEST in-ring sample, not the prior one"
    ring109b = collections.deque([{"commitPct": 0.60}, {"commitPct": 0.55}], maxlen=8)
    assert classify_trend(ring109b) == "dropping", "a -5pp delta must read as dropping"
    ok += 1; print("  PASS memory tracker: classify_trend compares vs oldest-in-ring, +-2pp threshold, unknown under 2 samples")

    # 110) Memory tracker: memory_alerts applies Douglas's exact thresholds (available <6GB warn, <3GB
    #      critical; commit >85% warn, >92% crisis), boundary-inclusive, multiple alerts can co-occur.
    total += 1
    GB110 = 1024 ** 3
    assert memory_alerts({"availableBytes": 10 * GB110, "commitPct": 0.50}) == []
    assert memory_alerts({"availableBytes": 6 * GB110, "commitPct": 0.50}) == [], "exactly 6GB must NOT warn (boundary is < not <=)"
    assert "available_warn" in memory_alerts({"availableBytes": 5.9 * GB110, "commitPct": 0.50})
    assert "available_critical" in memory_alerts({"availableBytes": 2.9 * GB110, "commitPct": 0.50})
    assert "available_critical" not in memory_alerts({"availableBytes": 3 * GB110, "commitPct": 0.50}), "exactly 3GB must NOT be critical"
    assert "commit_warn" in memory_alerts({"availableBytes": 10 * GB110, "commitPct": 0.86})
    assert "commit_crisis" in memory_alerts({"availableBytes": 10 * GB110, "commitPct": 0.93})
    both110 = memory_alerts({"availableBytes": 2 * GB110, "commitPct": 0.95})
    assert "available_critical" in both110 and "commit_crisis" in both110, "both alerts must be able to co-occur"
    ok += 1; print("  PASS memory tracker: memory_alerts applies exact thresholds, boundary-correct, co-occurring alerts")

    # 111) Memory tracker: _tail_last_jsonl_line reads only the LAST line of a JSONL file without
    #      parsing the whole file (usage-samples.jsonl can be thousands of lines) - empty/missing file
    #      returns None, not a crash.
    total += 1
    import tempfile as _tf111
    path111 = _tf111.mktemp(suffix=".jsonl")
    assert _tail_last_jsonl_line(path111) is None, "a missing file must return None"
    with open(path111, "w", encoding="utf-8") as _f111:
        _f111.write('{"a":1}\n{"a":2}\n{"a":3}\n')
    assert _tail_last_jsonl_line(path111) == {"a": 3}, "must return the LAST record, parsed"
    with open(path111, "w", encoding="utf-8") as _f111:
        _f111.write("")
    assert _tail_last_jsonl_line(path111) is None, "an empty file must return None, not crash"
    with open(path111, "w", encoding="utf-8") as _f111:
        _f111.write('{"a":1}\n{"a":2}\n')  # no trailing newline on last line
    assert _tail_last_jsonl_line(path111) == {"a": 2}, "must handle a file with no trailing newline"
    os.remove(path111)
    ok += 1; print("  PASS memory tracker: _tail_last_jsonl_line reads only the last record, handles missing/empty/no-trailing-newline")

    # 112) Memory tracker: build_memory_payload merges a raw sample_memory()-shaped dict into the full
    #      API shape (groups/topProcesses/trend/alerts), independent of the live subprocess call, and
    #      handles available=False without crashing.
    total += 1
    fake_sample112 = {
        "available": True, "schemaVersion": 1, "timestamp": "2026-07-08T00:00:00Z",
        "physicalTotalBytes": 34000000000, "availableBytes": 2000000000, "physicalUsedPct": 0.9412,
        "commitBytes": 40000000000, "commitLimitBytes": 65000000000,
        "commitPct": 0.93, "pagefilePct": 0.05,
        "pagedPoolBytes": 1, "nonpagedPoolBytes": 1, "cacheBytes": 1,
        "processes": [
            {"name": "claude", "pid": 1, "privateBytes": 9_000_000_000, "workingSetBytes": 6_000_000_000},
            {"name": "node", "pid": 2, "privateBytes": 1_000_000_000, "workingSetBytes": 1_000_000_000},
            {"name": "node", "pid": 3, "privateBytes": 500_000_000, "workingSetBytes": 500_000_000},
            {"name": "python", "pid": 5, "privateBytes": 300_000_000, "workingSetBytes": 300_000_000},
            {"name": "weird_unmatched_proc", "pid": 4, "privateBytes": 1, "workingSetBytes": 1},
        ],
    }
    with _MEMORY_RING_LOCK:
        _MEMORY_RING.clear()
    payload112 = build_memory_payload(fake_sample112)
    assert payload112["available"] is True
    assert payload112["physicalUsedPct"] == 0.9412, "physicalUsedPct must pass through from the sample unchanged"
    group_keys112 = {g["key"] for g in payload112["groups"]}
    assert {"agent_apps", "dev_runtimes", "other"}.issubset(group_keys112), "buckets present in the sample must appear in groups"
    node_group112 = next(g for g in payload112["groups"] if g["key"] == "dev_runtimes")
    assert node_group112["count"] == 3 and node_group112["privateBytes"] == 1_800_000_000, "the two node PIDs + one python PID must be summed into one group row"
    by_name112 = {n["name"]: n for n in node_group112["byName"]}
    assert by_name112["node"]["count"] == 2 and by_name112["node"]["privateBytes"] == 1_500_000_000, \
        "byName must break the bucket down per process NAME so node/python are individually visible: got %r" % node_group112["byName"]
    assert by_name112["python"]["count"] == 1 and by_name112["python"]["privateBytes"] == 300_000_000
    assert node_group112["byName"][0]["name"] == "node", "byName must be sorted biggest-first"
    assert len(payload112["topProcesses"]) == 5, "topProcesses lists individual processes, not grouped"
    top_by_pid112 = {p["pid"]: p for p in payload112["topProcesses"]}
    assert top_by_pid112[1]["bucket"] == "agent_apps" and top_by_pid112[2]["bucket"] == "dev_runtimes", \
        "each top-process row must be tagged with its bucket key: got %r" % payload112["topProcesses"]
    assert "available_critical" in payload112["alerts"] and "commit_crisis" in payload112["alerts"]
    assert payload112["trend"] == "unknown", "first sample ever pushed to the ring must read as unknown, not a guess"
    unavailable112 = build_memory_payload({"available": False, "reason": "node not found on PATH"})
    assert unavailable112["available"] is False and unavailable112["reason"] == "node not found on PATH"
    assert unavailable112["groups"] == [] and unavailable112["topProcesses"] == [], "an unavailable sample must return empty collections, not crash"
    ok += 1; print("  PASS memory tracker: build_memory_payload groups/sums/tops/alerts/trend correctly, degrades cleanly when unavailable")

    # 113) Memory tracker: /api/memory and /api/memory/events are actually routed and reachable over a
    #      real HTTP request (not just present in source) - stub sample_memory/sample_memory_events so
    #      this doesn't depend on node actually being available in the test environment.
    total += 1
    import threading as _th113, socketserver as _ss113, http.client as _hc113
    class _Srv113(_ss113.ThreadingTCPServer):
        allow_reuse_address = True; daemon_threads = True
    srv113 = _Srv113(("127.0.0.1", 0), Handler); port113 = srv113.server_address[1]
    _th113.Thread(target=srv113.serve_forever, daemon=True).start()
    old_sm113 = globals()["sample_memory"]; old_sme113 = globals()["sample_memory_events"]
    globals()["sample_memory"] = lambda: {"available": True, "commitPct": 0.5, "availableBytes": 10 * 1024**3, "processes": [{"name": "x", "pid": 1, "privateBytes": 100, "workingSetBytes": 100}]}
    globals()["sample_memory_events"] = lambda: {"available": True, "events": []}
    try:
        c113 = _hc113.HTTPConnection("127.0.0.1", port113, timeout=8)
        c113.request("GET", "/api/memory"); r113 = c113.getresponse(); b113 = json.loads(r113.read()); c113.close()
        assert r113.status == 200 and b113["available"] is True and "groups" in b113 and "trend" in b113, \
            "/api/memory must be reachable and return the full built payload: %r" % b113
        c113b = _hc113.HTTPConnection("127.0.0.1", port113, timeout=8)
        c113b.request("GET", "/api/memory/events"); r113b = c113b.getresponse(); b113b = json.loads(r113b.read()); c113b.close()
        assert r113b.status == 200 and b113b["available"] is True and b113b["events"] == [], \
            "/api/memory/events must be reachable: %r" % b113b
    finally:
        globals()["sample_memory"] = old_sm113; globals()["sample_memory_events"] = old_sme113
        srv113.shutdown(); srv113.server_close()
    ok += 1; print("  PASS memory tracker: /api/memory and /api/memory/events are live-reachable over real HTTP")

    # 114) Memory tracker: build_usage_payload reads latest-rate-limits.json + tails usage-samples.jsonl
    #      WITHOUT touching state.json (the 18MB raw event ledger) - honest about staleness, never
    #      fabricates a percentage that isn't there.
    total += 1
    import tempfile as _tf114, shutil as _sh114
    dir114 = _tf114.mkdtemp()
    try:
        limits_path114 = os.path.join(dir114, "latest-rate-limits.json")
        samples_path114 = os.path.join(dir114, "usage-samples.jsonl")
        with open(limits_path114, "w", encoding="utf-8") as _f114:
            json.dump({"available": True, "fiveHour": {"usedPercentage": 42.5}, "sevenDay": {"usedPercentage": 18.0},
                       "capturedAt": "2026-07-08T00:00:00Z"}, _f114)
        with open(samples_path114, "w", encoding="utf-8") as _f114:
            _f114.write(json.dumps({"tokenUsage": {"today": {"total": {"apiEquivalentUsd": 3.21}}}}) + "\n")
        payload114 = build_usage_payload(limits_path114, samples_path114)
        assert payload114["fiveHourPct"] == 42.5 and payload114["sevenDayPct"] == 18.0
        assert payload114["todayUsd"] == 3.21
        assert "ageSeconds" in payload114, "must report how stale the reading is, not imply it's live"
        missing114 = build_usage_payload(os.path.join(dir114, "nope.json"), os.path.join(dir114, "nope2.jsonl"))
        assert missing114["available"] is False, "missing usage-estimator files must degrade cleanly, not crash"
    finally:
        _sh114.rmtree(dir114, ignore_errors=True)
    ok += 1; print("  PASS memory tracker: build_usage_payload reads rate-limits+tail-sample honestly, degrades on missing files")

    # 115) Memory tracker: when latest-rate-limits.json is missing/unavailable, build_usage_payload
    #      falls back to ~/.claude/usage-state.json (the same 2-tier fallback claude-usage-recorder.mjs's
    #      own loadBestRateLimits already uses) rather than reporting unavailable when real data exists
    #      in the fallback source.
    total += 1
    import tempfile as _tf115, shutil as _sh115
    dir115 = _tf115.mkdtemp()
    try:
        limits_path115 = os.path.join(dir115, "latest-rate-limits.json")  # deliberately absent
        state_path115 = os.path.join(dir115, "usage-state.json")
        with open(state_path115, "w", encoding="utf-8") as _f115:
            json.dump({"available": True, "five_hour": {"used_percentage": 33.0}}, _f115)
        payload115 = build_usage_payload(limits_path115, os.path.join(dir115, "usage-samples.jsonl"),
                                          usage_state_path=state_path115)
        assert payload115["available"] is True and payload115["fiveHourPct"] == 33.0, \
            "must fall back to usage-state.json when latest-rate-limits.json is missing: %r" % payload115
        with open(state_path115, "w", encoding="utf-8") as _f115:
            json.dump({"available": False}, _f115)
        payload115b = build_usage_payload(limits_path115, os.path.join(dir115, "usage-samples.jsonl"),
                                           usage_state_path=state_path115)
        assert payload115b["available"] is False, "an unavailable fallback must still report unavailable, not fabricate"
    finally:
        _sh115.rmtree(dir115, ignore_errors=True)
    ok += 1; print("  PASS memory tracker: build_usage_payload falls back to usage-state.json (matches claude-usage-recorder.mjs's own 2-tier pattern)")

    # 116) Memory tracker: attach_server_memory resolves each config's PID via find_pid_on_port and
    #      merges memory in via ONE batched --pids call (not one call per server) - a server with no
    #      resolvable PID gets memory=None, never a crash or a fabricated number.
    total += 1
    def _fake_find_pid116(port):
        return {9001: 111, 9002: 222}.get(port)
    def _fake_pids_sample116(pids):
        assert sorted(pids) == [111, 222], "must batch ALL resolved PIDs into one call, not one per server: got %r" % pids
        return {"available": True, "processes": [
            {"pid": 111, "name": "a", "privateBytes": 500, "workingSetBytes": 600},
            {"pid": 222, "name": "b", "privateBytes": 700, "workingSetBytes": 800},
        ]}
    configs116 = [{"id": "x::a", "port": 9001}, {"id": "x::b", "port": 9002}, {"id": "x::c", "port": 9003}]
    old_fpp116 = globals()["find_pid_on_port"]
    globals()["find_pid_on_port"] = _fake_find_pid116
    try:
        out116 = attach_server_memory(configs116, sample_pids_fn=_fake_pids_sample116)
    finally:
        globals()["find_pid_on_port"] = old_fpp116
    by_id116 = {c["id"]: c for c in out116}
    assert by_id116["x::a"]["memory"]["privateBytes"] == 500
    assert by_id116["x::b"]["memory"]["privateBytes"] == 700
    assert by_id116["x::c"]["memory"] is None, "a server with no resolvable PID must get memory=None, not crash or a fake 0"
    ok += 1; print("  PASS memory tracker: attach_server_memory batches PIDs into one call, unresolvable server -> memory=None")

    # 117) Memory tracker: the 4th tab exists, is wired into the poll loop, and the render function
    #      uses labels/data only (no explanatory prose, per Douglas's standing no-commentary-text rule).
    total += 1
    assert 'data-tab="memory"' in PAGE, "the tab rail needs a 4th Memory tab button"
    assert 'data-panel="memory"' in PAGE, "a memory tabpanel section must exist"
    assert "function refreshMemory(" in PAGE, "a refreshMemory JS function must exist"
    assert re.search(r"setInterval\(refreshMemory,\s*\d+\)", PAGE), "refreshMemory must be on the periodic poll loop like the other panels"
    assert "This dashboard shows" not in PAGE and "This panel displays" not in PAGE, \
        "no explanatory commentary text in the memory tab (Douglas's standing no-commentary-text rule)"
    ok += 1; print("  PASS memory tracker: Memory tab wired into rail + poll loop, no commentary text")

    # 117b) Memory tab additions (Douglas 2026-07-08): a real Physical RAM used% tile distinct from
    # Commit%, a plain-English pagefile tooltip, per-bucket process-name breakdown, bucket tags on the
    # top-processes table, and the header strip's memory clause suppressed while ON the Memory tab.
    total += 1
    assert "mem-stat-label\">Physical RAM used" in PAGE and "fmtPct(d.physicalUsedPct)" in PAGE, \
        "a Physical RAM used% tile (matching Task Manager) must exist, distinct from Commit%"
    assert "swap file on disk currently holding paged-out data" in PAGE, \
        "the Pagefile tile needs a plain-English tooltip explaining what it measures"
    assert "not physical RAM occupancy" in PAGE, \
        "the Commit tile needs a tooltip distinguishing it from physical RAM usage (the source of Douglas's Task-Manager-mismatch confusion)"
    assert "g.byName || []" in PAGE and "mem-bucket-names" in PAGE, \
        "each bucket row must render its per-process-name breakdown (e.g. node vs python), not just the bucket total"
    assert 'class="mem-tag">' in PAGE and "_memBucketLabel[p.bucket]" in PAGE, \
        "each top-process row must show its bucket as a visible tag"
    assert "var onMemoryTab = document.querySelector" in PAGE and "if(mem && !onMemoryTab)" in PAGE, \
        "the header strip's memory clause must be suppressed while the Memory tab itself is active (it would just repeat the tab's own tiles)"
    ok += 1; print("  PASS memory tab v2: physical RAM% tile, pagefile/commit tooltips, per-bucket name breakdown, top-process bucket tags, header dedup on Memory tab")

    # 117c) Themed scrollbars (Douglas 2026-07-08): CSS-only, applies globally so every scrollable
    # region matches the theme instead of the OS default; no scrollable region's own markup/text changes.
    total += 1
    assert "::-webkit-scrollbar{" in PAGE and "::-webkit-scrollbar-thumb{" in PAGE and "::-webkit-scrollbar-track{" in PAGE, \
        "themed scrollbar rules must exist for Chromium/Edge/WebView"
    assert "scrollbar-color:var(--line) var(--well);" in PAGE, "Firefox's scrollbar-color must use the same theme variables"
    ok += 1; print("  PASS themed scrollbars: consistent thumb/track colors across every scrollable region, CSS-only")

    # 117d) impeccable layout+typeset pass (Douglas 2026-07-08, "make the sizing more consistent"):
    # the 3 corner-tag elements (.scard-tag/.scard-msg/.ktag) used a bare 9px value outside the type
    # scale entirely -- named as --text-3xs so every tiny badge draws from the same token instead of a
    # magic number repeated 3x. Memory tab's stat tiles moved from flex-wrap to a grid (consistent
    # column widths instead of an uneven wrap) per the layout pass's "numbers... more consistent" ask.
    total += 1
    assert "font-size:9px" not in PAGE, "no bare 9px font-size may remain outside the named type scale"
    assert "--text-3xs:0.6875rem" in PAGE, "the tiny-badge size must be a named scale token, not a magic number"
    assert PAGE.count("font-size:var(--text-3xs)") == 3, \
        "all 3 corner-tag elements (scard-tag/scard-msg/ktag) must share the one --text-3xs token: got %d" % PAGE.count("font-size:var(--text-3xs)")
    assert "grid-template-columns:repeat(auto-fit,minmax(150px,1fr))" in PAGE, \
        "mem-stats must be a responsive grid, not an uneven flex-wrap, for consistent tile widths"
    ok += 1; print("  PASS impeccable layout+typeset: tiny-badge size named on-scale (--text-3xs), Memory stat tiles on a consistent grid")

    # 118) Memory tracker: the header strip is present and GLOBAL (outside any single tabpanel, so it's
    #      visible on every tab per Douglas's 'one place to decide' requirement); server rows show memory.
    total += 1
    apphdr_block118 = re.search(r'<header class="apphdr">.*?</header>', PAGE, re.S)
    assert apphdr_block118 and 'id="header-strip"' in apphdr_block118.group(0), \
        "the header strip must live inside <header class=\"apphdr\"> (outside all tabpanels) so it's visible on every tab"
    assert "function renderHeaderStrip(" in PAGE and "function refreshUsage(" in PAGE, \
        "the header strip needs its render function + a refreshUsage poller"
    assert "s.memory" in PAGE and 'class="smem"' in PAGE, \
        "server row rendering must reference and display the memory field"
    ok += 1; print("  PASS memory tracker: header strip is global (in apphdr, not inside a tabpanel), server rows show memory")

    print("\n%d/%d self-test cases passed" % (ok, total))
    return 0 if ok == total else 1


MEMORY_RECORDER_PATH = os.path.normpath(os.path.join(
    os.path.expanduser("~"), "Documents", "Codex NASA Folder", "scripts", "memory-recorder.mjs"))


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
                            capture_output=True, text=True, timeout=10, creationflags=_NO_WINDOW)
    except subprocess.TimeoutExpired:
        return {"available": False, "reason": "memory-recorder.mjs timed out after 10s"}
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


MEMORY_AVAILABLE_WARN_BYTES = 6 * 1024 ** 3
MEMORY_AVAILABLE_CRITICAL_BYTES = 3 * 1024 ** 3
MEMORY_COMMIT_WARN_PCT = 0.85
MEMORY_COMMIT_CRISIS_PCT = 0.92


def memory_alerts(sample):
    """Douglas's exact thresholds: available RAM <6GB warn, <3GB critical; commit >85% warn, >92%
    crisis. Boundary-exclusive (< / >, not <= / >=) so a value sitting exactly on the line does not
    alert. Returns a list so more than one alert can co-occur (e.g. both available_critical and
    commit_crisis)."""
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
        g = group_totals.setdefault(key, {"key": key, "count": 0, "privateBytes": 0, "workingSetBytes": 0, "byName": {}})
        g["count"] += 1
        g["privateBytes"] += p.get("privateBytes", 0)
        g["workingSetBytes"] += p.get("workingSetBytes", 0)
        nm = p.get("name") or "?"
        nb = g["byName"].setdefault(nm, {"name": nm, "count": 0, "privateBytes": 0})
        nb["count"] += 1
        nb["privateBytes"] += p.get("privateBytes", 0)
    label_by_key = {k: label for k, label, _needles in MEMORY_BUCKETS}
    label_by_key["other"] = "Other"
    groups = []
    for key, g in group_totals.items():
        g["label"] = label_by_key.get(key, key)
        # Per-process-name breakdown within the bucket (Douglas 2026-07-08: "active trackers for the
        # python/node processes" -- lumped into one "Dev runtimes" total, node vs python vs powershell
        # were indistinguishable), sorted biggest-first.
        g["byName"] = sorted(g["byName"].values(), key=lambda n: n["privateBytes"], reverse=True)
        groups.append(g)
    groups.sort(key=lambda g: g["privateBytes"], reverse=True)
    # Each top-process row is tagged with its bucket (Douglas 2026-07-08: "make the different types of
    # apps ... tags ... so I can see the things there") so the table doesn't need a separate legend.
    top_processes = [
        dict(p, bucket=classify_memory_bucket(p.get("name")))
        for p in sorted(processes, key=lambda p: p.get("privateBytes", 0), reverse=True)[:MEMORY_TOP_PROCESSES_N]
    ]
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
                            capture_output=True, text=True, timeout=10, creationflags=_NO_WINDOW)
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


USAGE_ESTIMATOR_DIR = os.path.join(os.path.expanduser("~"), ".claude", "usage-estimator")


USAGE_STATE_PATH = os.path.join(os.path.expanduser("~"), ".claude", "usage-state.json")


def _read_json_or_none(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def build_usage_payload(limits_path=None, samples_path=None, usage_state_path=None):
    """Read-only surfacing of the ALREADY-CAPTURED usage history in ~/.claude/usage-estimator/ - never
    parses the 18MB state.json raw event ledger, never triggers a new capture. Two-tier source fallback,
    matching claude-usage-recorder.mjs's OWN loadBestRateLimits: prefer latest-rate-limits.json (camelCase
    fields, an ISO capturedAt), fall back to ~/.claude/usage-state.json (snake_case fields, a Unix `ts`)
    when the first is missing/unavailable - the same two-source pattern the recorder script already
    uses internally, so a real reading in EITHER source surfaces instead of a needlessly false
    'unavailable' when data does exist in the fallback. limits_path/samples_path/usage_state_path are
    injectable for testing; production calls use the real default paths. Reports ageSeconds honestly so
    the frontend can show 'last sampled Xm ago' rather than implying live data - nothing here keeps
    `usage:watch` running."""
    limits_path = limits_path or os.path.join(USAGE_ESTIMATOR_DIR, "latest-rate-limits.json")
    samples_path = samples_path or os.path.join(USAGE_ESTIMATOR_DIR, "usage-samples.jsonl")
    usage_state_path = usage_state_path or USAGE_STATE_PATH

    five_pct = seven_pct = age_seconds = None
    limits = _read_json_or_none(limits_path)
    if limits and limits.get("available"):
        five_pct = (limits.get("fiveHour") or {}).get("usedPercentage")
        seven_pct = (limits.get("sevenDay") or {}).get("usedPercentage")
        captured_at = limits.get("capturedAt")
        if captured_at:
            try:
                import datetime as _dt
                parsed = _dt.datetime.fromisoformat(captured_at.replace("Z", "+00:00"))
                age_seconds = max(0, int((_dt.datetime.now(_dt.timezone.utc) - parsed).total_seconds()))
            except ValueError:
                pass
    else:
        state = _read_json_or_none(usage_state_path)
        if state and state.get("available"):
            five_pct = (state.get("five_hour") or {}).get("used_percentage")
            seven_pct = (state.get("seven_day") or {}).get("used_percentage")
            ts = state.get("ts")
            if isinstance(ts, (int, float)):
                import time as _time
                age_seconds = max(0, int(_time.time() - ts))

    if five_pct is None and seven_pct is None:
        return {"available": False, "fiveHourPct": None, "sevenDayPct": None, "todayUsd": None, "ageSeconds": None}

    last_sample = _tail_last_jsonl_line(samples_path)
    today_usd = None
    if last_sample:
        today_usd = (((last_sample.get("tokenUsage") or {}).get("today") or {}).get("total") or {}).get("apiEquivalentUsd")
    return {
        "available": True,
        "fiveHourPct": five_pct,
        "sevenDayPct": seven_pct,
        "todayUsd": today_usd,
        "ageSeconds": age_seconds,
    }


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
                            capture_output=True, text=True, timeout=10, creationflags=_NO_WINDOW)
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


def find_pid_on_port(port):
    """PID of whatever process is LISTENING on 127.0.0.1:<port>, via `netstat -ano` (no extra
    dependency like psutil needed). Returns None if nothing is listening there."""
    try:
        r = subprocess.run(["netstat", "-ano"], capture_output=True, text=True, timeout=10, creationflags=_NO_WINDOW)
    except Exception:
        return None
    for line in r.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 5 and parts[0] == "TCP" and parts[3] == "LISTENING":
            local = parts[1]
            if local.endswith(":%d" % port):
                try:
                    return int(parts[-1])
                except ValueError:
                    return None
    return None


def server_launch_log_path(port):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), ".server-launch.%d.log" % port)


def _find_missing_relative_directory(cfg):
    """If runtimeArgs references a relative directory via `--directory` (e.g. truss-forge-
    preview's "truss-forge", resolved against cfg['cwd']) and that directory doesn't exist,
    return the bad absolute path so the caller can fail fast with a specific message - instead of
    launching anyway and only surfacing a generic "port never came up" after the full
    wait_for_server_start timeout (2026-07-03 solo-review, LOW). Returns None when nothing's
    wrong (including when there's no --directory arg, or it's already absolute)."""
    args = cfg.get("runtimeArgs") or []
    for i, a in enumerate(args):
        if a == "--directory" and i + 1 < len(args):
            target = args[i + 1]
            if not os.path.isabs(target):
                full = os.path.join(cfg["cwd"], target)
                if not os.path.isdir(full):
                    return full
    return None


def start_server_config(cfg):
    """Launch a server EXACTLY as its own launch.json describes it - never an arbitrary
    caller-supplied command. Detached so it outlives the dashboard process, same philosophy as
    every other detached launch in this toolset. stdout/stderr go to a per-port log file (not
    DEVNULL) so a failed launch has a real diagnostic to show, not just a bare exit code
    (Long-run #7: "two separate live-dashboard restart attempts failed outright with only 'exit
    code 1,' no stderr, no retry")."""
    cmd = [cfg["runtimeExecutable"]] + list(cfg["runtimeArgs"])
    creationflags = 0
    if sys.platform == "win32":
        creationflags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP
    log_path = server_launch_log_path(cfg["port"])
    # `with` guarantees log_f is closed even if Popen raises (e.g. a launch.json config missing
    # runtimeExecutable) - found live 2026-07-03 (solo-review, HIGH): the old bare open() leaked
    # one file handle per failed launch attempt, a slow resource leak on this long-lived process.
    # Popen dup()s the fd, so closing our copy right after is safe for a successful launch too.
    with open(log_path, "w", encoding="utf-8") as log_f:
        subprocess.Popen(cmd, cwd=cfg["cwd"], creationflags=creationflags,
                          stdout=log_f, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL)


def wait_for_server_start(port, timeout=5.0, interval=0.2):
    """Polls port_listening(port) until it comes up or timeout elapses. Returns True/False -
    used right after a start request so the caller can report a REAL health signal instead of
    just "the launch command didn't immediately error.\""""
    import time as _time
    deadline = _time.time() + timeout
    while _time.time() < deadline:
        if port_listening(port):
            return True
        _time.sleep(interval)
    return port_listening(port)


def wait_for_port_stop(port, timeout=5.0, interval=0.2):
    """Polls port_listening(port) until it stops listening or timeout elapses. Returns True/False -
    the inverse of wait_for_server_start's shape, giving stop_port a REAL post-condition check
    instead of just "we found a PID and tried.\""""
    import time as _time
    deadline = _time.time() + timeout
    while _time.time() < deadline:
        if not port_listening(port):
            return True
        _time.sleep(interval)
    return not port_listening(port)


def stop_port(port):
    """Kill whatever process is listening on `port`. Returns True only once the port is
    CONFIRMED no longer listening (2026-07-03 solo-review, MEDIUM: the old version returned True
    as soon as a PID was merely FOUND, before taskkill's own success/failure was ever checked - a
    permission-denied or already-exited-process taskkill failure was reported to the browser as
    ok:true while the process could still be running). Mirrors wait_for_server_start's
    poll-for-real-state shape, inverted."""
    pid = find_pid_on_port(port)
    if pid is None:
        return False
    subprocess.run(["taskkill", "/PID", str(pid), "/F"], capture_output=True, timeout=10, creationflags=_NO_WINDOW)
    return wait_for_port_stop(port)


class Handler(http.server.BaseHTTPRequestHandler):
    # A per-connection socket read timeout. BaseHTTPRequestHandler leaves this None, so a half-open
    # client (partial headers, never terminated) or a POST whose Content-Length never arrives blocks
    # the worker thread in rfile.readline/read forever - and since the server spawns one unbounded
    # daemon thread per connection, that is a slowloris-style thread-exhaustion path (LR-03,
    # 2026-07-07). With this set, socketserver calls socket.settimeout(timeout) so a stalled read
    # raises and handle_one_request closes the connection instead of pinning the thread. 30s is far
    # above any real localhost request yet finite.
    timeout = 30

    def log_message(self, fmt, *args):
        pass

    def _json(self, obj, status=200):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json_body(self):
        """Read + parse a JSON POST body with a hard size cap. Returns (obj, None) on success or
        (None, error_str). Rejects a negative or oversized Content-Length BEFORE reading a byte
        (LR2-03), and catches the RecursionError a deeply-nested body raises - which the plain
        (ValueError, JSONDecodeError) except missed because RecursionError is a RuntimeError, so the
        worker died and the client got a dropped connection instead of a clean error (LR2-04)."""
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except (TypeError, ValueError):
            return None, "bad Content-Length header"
        if length < 0:
            return None, "negative Content-Length"
        if length > MAX_POST_BODY_BYTES:
            return None, "request body too large (max %d bytes)" % MAX_POST_BODY_BYTES
        raw = self.rfile.read(length) if length else b"{}"
        try:
            return json.loads(raw or b"{}"), None
        except (ValueError, json.JSONDecodeError, RecursionError):
            return None, "bad request body"

    def _reject_cross_origin(self):
        """CSRF / DNS-rebind guard for state-changing POSTs. A browser attaches an Origin (and usually
        a Referer) on any cross-origin POST, so if either is present and its host:port is not this
        server's own localhost origin, the request came from another site open in Douglas's browser and
        is refused (LR2-01) - shielding the process start/stop + action-queue endpoints. A request with
        NO Origin/Referer is a non-browser client (curl, a local hook) and is allowed; the same-origin
        dashboard UI always sends a matching Origin. Returns True (and sends a 403) if it must refuse."""
        own_port = self.server.server_address[1]
        allowed_hosts = {"127.0.0.1", "localhost", "::1"}
        for hdr in ("Origin", "Referer"):
            val = self.headers.get(hdr)
            if not val:
                continue
            try:
                u = urllib.parse.urlparse(val)
                host = (u.hostname or "").lower()
                port = u.port or (443 if u.scheme == "https" else 80)
            except ValueError:
                self._json({"ok": False, "error": "malformed %s header" % hdr}, status=403)
                return True
            if host not in allowed_hosts or port != own_port:
                self._json({"ok": False, "error": "cross-origin request refused (%s: %s)" % (hdr, val)},
                           status=403)
                return True
            return False  # a same-origin Origin/Referer is sufficient proof of same-origin
        return False

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/" or parsed.path == "/index.html":
            body = PAGE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif parsed.path == "/api/longruns":
            active, _archived = partition_archived(collect_all(), load_archived())
            self._json(active)
        elif parsed.path == "/api/longruns/archived":
            _active, archived = partition_archived(collect_all(), load_archived())
            self._json(archived)
        elif parsed.path == "/api/servers":
            configs = load_server_configs()
            for c in configs:
                c["running"] = port_listening(c["port"])
                # Only spend the HTTP round-trip on ports that are already listening - a
                # genuinely stopped server is just "stopped", no deeper check needed, so this
                # never slows the endpoint down for the (usual) majority that aren't running.
                c["health"] = "healthy" if (c["running"] and check_http_health(c["port"])) else \
                               ("unhealthy" if c["running"] else "stopped")
            attach_server_memory(configs)
            self._json(configs)
        elif parsed.path == "/api/discovered":
            self._json(list_discovered_servers())
        elif parsed.path == "/api/memory":
            self._json(build_memory_payload(sample_memory()))
        elif parsed.path == "/api/memory/events":
            self._json(sample_memory_events())
        elif parsed.path == "/api/usage":
            self._json(build_usage_payload())
        elif parsed.path == "/api/skills":
            self._json(project_skills_coverage())
        elif parsed.path == "/api/sessions":
            all_sessions = list_claude_sessions()
            shown = all_sessions[:SESSION_DISPLAY_CAP]
            # Enrich ONLY the small displayed set (each needs a transcript read) - doing it for all
            # N would make the poll read hundreds of files every tick. Cost/context from the full
            # read; the "waiting on you" upgrade from a cheap tail read.
            for s in shown:
                s.update(session_usage(s["id"]))
                if s["state"] != "active" and session_pending_input(s["id"]):
                    s["state"] = "waiting"
                # Fresh hook-back telemetry is a direct push from the session itself, so it's more
                # authoritative than the transcript heuristic - if present and it carries an explicit
                # state, it wins.
                te = latest_session_telemetry(s["id"])
                if te:
                    s["telemetry"] = te
                    if te.get("state"):
                        s["state"] = te["state"]
            self._json({"total": len(all_sessions), "sessions": shown})
        elif parsed.path.startswith("/api/session/"):
            sid = urllib.parse.unquote(parsed.path[len("/api/session/"):])
            self._json({"id": sid, "events": session_detail(sid)})
        elif parsed.path == "/api/actions/pending":
            self._json({"pending": read_pending_actions()})
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        # Every POST route here changes state (starts/stops processes, queues actions, edits archive
        # state), so a blanket cross-origin refusal is correct and simplest (LR2-01, 2026-07-07).
        if self._reject_cross_origin():
            return
        qs = urllib.parse.parse_qs(parsed.query)
        if parsed.path == "/api/longruns/archive" or parsed.path == "/api/longruns/unarchive":
            root = (qs.get("root") or [""])[0]
            # Only ever accept a root that's actually one of the configured watch roots - never an
            # arbitrary string a caller happens to pass, even though the archive file is harmless
            # local state (no process spawn/kill risk like /api/servers below).
            if root not in load_roots():
                self._json({"ok": False, "error": "not a configured root: %r" % root})
                return
            set_archived(root, parsed.path == "/api/longruns/archive")
            self._json({"ok": True})
        elif parsed.path == "/api/servers/start":
            name = (qs.get("id") or [None])[0]
            cfg = next((c for c in load_server_configs() if c["id"] == name), None)
            if not cfg:
                self._json({"ok": False, "error": "no such server config: %r" % name})
                return
            if port_listening(cfg["port"]):
                self._json({"ok": True, "note": "already running"})
                return
            missing_dir = _find_missing_relative_directory(cfg)
            if missing_dir:
                self._json({"ok": False, "error": "runtimeArgs references a directory that "
                            "doesn't exist: %s" % missing_dir})
                return
            if not _START_LOCK.try_acquire(cfg["port"]):
                self._json({"ok": False, "error": "a start for port %d is already in progress "
                            "(concurrent request) - wait for it to finish" % cfg["port"]})
                return
            try:
                try:
                    start_server_config(cfg)
                except Exception as e:
                    self._json({"ok": False, "error": "%s: %s" % (type(e).__name__, e)})
                    return
                healthy = wait_for_server_start(cfg["port"])
                if not healthy:
                    tail = read_text(server_launch_log_path(cfg["port"])) or ""
                    self._json({"ok": False, "error": "launched, but port %d never came up within 5s. "
                                "Last output:\n%s" % (cfg["port"], tail[-1000:])})
                    return
                self._json({"ok": True})
            finally:
                _START_LOCK.release(cfg["port"])
        elif parsed.path == "/api/servers/stop":
            try:
                port = int((qs.get("port") or [""])[0])
            except ValueError:
                self._json({"ok": False, "error": "bad or missing port"})
                return
            if is_protected_port(port, self.server.server_address[1]):
                self._json({"ok": False, "error": "refusing to stop the dashboard's own port (%d) - "
                            "this would kill the server answering this very request" % port})
                return
            # Only ever stop a port that's actually named in a known launch.json - never an
            # arbitrary port a caller happens to ask for.
            known_ports = {c["port"] for c in load_server_configs()}
            if port not in known_ports:
                self._json({"ok": False, "error": "port %d is not a known dashboard/server" % port})
                return
            found = stop_port(port)
            self._json({"ok": found})
        elif parsed.path == "/api/sessions/action":
            body, err = self._read_json_body()
            if err:
                self._json({"ok": False, "error": err})
                return
            if not isinstance(body, dict):
                self._json({"ok": False, "error": "body must be a JSON object"})
                return
            session_id = body.get("sessionId")
            text = body.get("text")
            # Require real strings: a dict/list would otherwise be silently str()-coerced and written
            # to the shared queue as e.g. "{'a': 1}" (LR-04).
            if not isinstance(session_id, str) or not session_id.strip() \
                    or not isinstance(text, str) or not text.strip():
                self._json({"ok": False, "error": "sessionId and text must both be non-empty strings"})
                return
            try:
                record = queue_session_action(session_id, text)
            except SessionQueueFull as e:
                self._json({"ok": False, "error": str(e)})
                return
            self._json({"ok": True, "queued": record})
        elif parsed.path == "/api/sessions/broadcast":
            body, err = self._read_json_body()
            if err:
                self._json({"ok": False, "error": err})
                return
            if not isinstance(body, dict):
                self._json({"ok": False, "error": "body must be a JSON object"})
                return
            text = body.get("text")
            if not isinstance(text, str) or not text.strip():
                self._json({"ok": False, "error": "text must be a non-empty string"})
                return
            try:
                ids = broadcast_session_action(text)
            except SessionQueueFull as e:
                self._json({"ok": False, "error": str(e)})
                return
            self._json({"ok": True, "count": len(ids), "sessionIds": ids})
        elif parsed.path == "/api/actions/drain":
            drained = drain_pending_actions()
            self._json({"ok": True, "count": len(drained), "actions": drained})
        elif parsed.path == "/api/session-event":
            body, err = self._read_json_body()
            if err:
                self._json({"ok": False, "error": err})
                return
            if not isinstance(body, dict):
                self._json({"ok": False, "error": "body must be a JSON object"})
                return
            sid = str(body.get("sessionId") or "")
            if not sid:
                self._json({"ok": False, "error": "sessionId is required"})
                return
            rec = record_session_event(sid, str(body.get("event") or ""), str(body.get("state") or ""))
            self._json({"ok": True, "recorded": rec})
        else:
            self.send_response(404)
            self.end_headers()


def resolve_port_arg(argv, default=CANONICAL_DASHBOARD_PORT):
    """Parses --port N out of argv, raising a clear ValueError (usage-style message) on a missing
    value or non-numeric value, instead of letting a raw IndexError/ValueError escape main() as an
    unguarded traceback (2026-07-03 solo-review, LOW)."""
    if "--port" not in argv:
        return default
    idx = argv.index("--port")
    if idx + 1 >= len(argv):
        raise ValueError("--port requires a value, e.g. --port 8756")
    try:
        return int(argv[idx + 1])
    except ValueError:
        raise ValueError("--port value must be numeric, got %r" % argv[idx + 1])


def try_bind_server(port, handler_cls):
    """Constructs the ThreadingServer, translating a genuine "address already in use" OSError
    (including a stale prior instance of THIS very script still holding the port) into a clear,
    actionable RuntimeError instead of letting a raw traceback surface (2026-07-03 solo-review,
    LOW) - this script's own docstring positions restarting it by hand as a very plausible real
    operator action, exactly the context where a one-line message matters most."""
    # ThreadingTCPServer, not plain TCPServer: found live 2026-07-02 — a single stale/half-open
    # connection (e.g. a browser tab left over from a prior server restart) can wedge a
    # single-threaded server so EVERY new request hangs, even though the OS socket still shows
    # LISTENING. One thread per connection means a stuck client can't block anyone else.
    class ThreadingServer(socketserver.ThreadingTCPServer):
        allow_reuse_address = True
        daemon_threads = True

    # Active pre-bind guard against multi-instance (found live 2026-07-07: TEN copies of this
    # dashboard were simultaneously bound to :8756, because Windows SO_REUSEADDR - which
    # allow_reuse_address above enables, and which is genuinely wanted for quick restarts through a
    # TIME_WAIT socket - ALSO lets two LIVE instances co-bind the same port on Windows, unlike
    # Linux. Requests then round-robin across instances, so stale-code copies silently answer and a
    # freshly-edited one appears not to take effect). allow_reuse_address stays (legit restarts need
    # it); this guard is what stops a SECOND live instance from piling on: if something is already
    # LISTENING and actually answering HTTP, that's a live dashboard, not a TIME_WAIT ghost - refuse.
    if port_listening(port) and check_http_health(port):
        raise RuntimeError(
            "a live dashboard is already serving on port %d - refusing to start a second instance "
            "(that would silently round-robin requests across both on Windows). Stop the existing "
            "one first: for PID in netstat -ano | findstr :%d -> taskkill /PID <pid> /F" % (port, port))

    try:
        return ThreadingServer(("127.0.0.1", port), handler_cls)
    except OSError as e:
        raise RuntimeError(
            "could not start on port %d (%s) - is another copy of this dashboard already "
            "running? check with: netstat -ano | findstr :%d" % (port, e, port)) from e


def main():
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    if "--drain-actions" in sys.argv:
        # For an agent WITH the ccd_session_mgmt MCP: prints the queued dispatch messages (and marks
        # them delivered) so the agent can send_message() each one. This is the deliver half of the
        # queue-not-inject design - the dashboard queues, an agent drains here and actually delivers.
        drained = drain_pending_actions()
        if not drained:
            print("no pending session actions to drain.")
        else:
            print("%d pending session action(s) - deliver each via ccd_session_mgmt.send_message:" % len(drained))
            for a in drained:
                print("  -> session %s : %s" % (a.get("sessionId"), a.get("text")))
        sys.exit(0)
    try:
        port = resolve_port_arg(sys.argv)
    except ValueError as e:
        print("usage error: %s" % e, file=sys.stderr)
        sys.exit(1)
    try:
        httpd = try_bind_server(port, Handler)
    except RuntimeError as e:
        print(e, file=sys.stderr)
        sys.exit(1)
    with httpd:
        print("longrun dashboard: http://127.0.0.1:%d" % port)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
