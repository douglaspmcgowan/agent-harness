---
name: panel-ultra-review
description: Ultra-thorough multi-model PANEL review of a codebase. Buckets the repo + adds a cross-bucket SEAMS dimension, runs a diverse cross-family model panel with raw/open uncapped exhaustive prompts, layers reviewer-miss + adversarial verify, then merges to a found-by-N consensus with an interactive report. READ-ONLY by default (issues + fix PLANS, not edits). Use when Douglas says "panel ultra review", "run the panel on <repo>", "ultra review this codebase", "/panel-ultra-review".
---

# Panel Ultra Review

Replicates the multi-model, multi-view code review: partition the codebase, review each part with a
diverse panel of frontier models AND agentic subagents, add a dedicated cross-bucket seams pass, verify
adversarially, and merge to a found-by-N consensus. Generalized to run on ANY codebase.

**Default posture: strictly READ-ONLY.** No agent edits the reviewed code. The deliverable is *issues + fix
plans*, not applied fixes. (A parallel session may be doing the fixes; never collide with it.) A "forge" mode
that actually applies fixes is a separate, explicit opt-in — do NOT do it under this skill unless asked.

## Why it works (keep these or you lose the value)

- **Raw/open uncapped FIND.** The single biggest lever is an exhaustive, unstructured prompt ("find as many as
  you can, don't stop at N, don't cap length"), no leading "views"/priming. Structure at the find step (a rubric,
  a top-N cap, a code-review skill) *trims the long tail* — round data: ~40% of issues were found by exactly one
  model even uncapped. Keep the finder raw; put skills only AROUND it (miss/verify/fix).
- **Diverse cross-family panel + found-by-N.** Divergence is mostly path-dependent sampling plus some lens
  differences, so each model adds a fresh sample AND a lens. Running every model on every bucket yields a
  found-by-N consensus count = a free confidence/severity signal (found-by-all = load-bearing; found-by-one =
  real, verify). Prefer cross-family models over near-siblings.
- **The SEAMS dimension.** Buckets partition the code, so per-bucket reviewers are blind to issues BETWEEN
  buckets (producer/consumer schema drift, duplicated sources of truth, verdict signals that can disagree,
  incomplete dependency graphs) — which are often the worst. A dedicated seams pass whose whole job is the
  boundaries catches them. This is where the highest-severity findings usually come from.
- **Budget never caps thinking/output.** Reasoning models spend most of `max_tokens` on hidden thinking; a low
  ceiling starves the text and you get empty/truncated cells. Give a large ceiling (64k–200k) and detect
  truncation, re-running incomplete cells. Never let the budget restrict a review.
- **Freeze the target.** Snapshot the repo read-only so a parallel editing session can't churn it and so every
  model sees a byte-identical target.

## Procedure (make one todo per step)

1. **Scope & bucket.** Read the repo's map (AGENTS.md/README/dir tree). Partition the code into 4–8 functional
   BUCKETS (by subsystem / pipeline stage / dataflow), each sized to review in one pass (roughly ≤1500 lines of
   the files that matter; exclude vendored/generated/test-fixture bulk unless in scope). Add a **B_seams** bucket
   whose files are the boundary-defining modules (the ones that write/read shared artifacts or define contracts).
   If you can't tell, list the top-level packages and group by import clusters.
2. **Freeze.** Copy the source to review into `<target>/_panel_review/_frozen/` (source files + any data
   artifacts reviewers should see). Point everything at the frozen copy. Never write into it after freezing.
3. **Configure.** Write `<target>/_panel_review/panel_config.json` and `review_grid.py` (both templates below).
   Fill `buckets`, `models`, `endpoint`, `seams_map`. Smoke-test: `python review_grid.py --dry` prints per-bucket
   prompt sizes + endpoint reachability.
4. **Run the panel — AGENTIC FIRST.** Prefer agentic (tool-using) runs for every model that supports it. Agentic
   runs **auto-continue when context fills, never truncate, and go as long as they need**, and — critically — they
   can grep/read/verify across the repo, so they confirm a contradiction by *loading the actual artifact* instead
   of only reasoning over pasted text. That verification power is what produces the strongest findings (e.g. a
   seams reviewer proving `gate.passed=false` vs `accept.passed=true` on the same build by opening both JSONs).
   - **Anthropic-format endpoints (incl. a GEN proxy):** a headless CLI session per (model × bucket) with
     read-only tools, pointed at the frozen copy — reasoning models never truncate this way. Pattern in the
     `run_agentic.py` template below (uses a `gen-claude.sh`-style launcher; override the model via env).
   - **Native-OpenAI models** (GPT etc., which reject the Anthropic body): their own agentic harness, e.g. the
     Codex CLI in read-only sandbox.
   - **Your own platform's model:** subagents (Read/Grep/Glob only).
   - Always include **one whole-repo agentic SEAMS reviewer** — that's where the highest-severity findings come from.
5. **One-shot API fallback (cheap mode).** When agentic isn't available or worth it, the read-based driver (below)
   pastes each bucket's source and calls the endpoint once, writing `results/<bucket>__<model>.txt`. Give reasoning
   models a large ceiling (64k–200k); it auto-detects truncation (a complete review ends with the `CHECK:` trailer)
   and `--empties` re-runs missing/blank/errored/truncated cells. Prefer agentic (step 4) for reasoning models —
   it removes truncation entirely instead of fighting the ceiling.
6. **Budgets/truncation.** If cells come back empty/`stop=max_tokens`, raise `GRID_MAXTOK` (try 64000, then
   200000 — reasoning models legitimately need that) and `--empties` again. If one model's hidden thinking is
   effectively unbounded (never emits text within a large ceiling/timeout), swap its non-thinking sibling in and
   note the swap rather than dropping the seat.
7. **Superpower layer (AROUND the finder, never inside it).**
   - `/reviewer-miss` (or an equivalent pass) framed on the boundaries: "what did the per-bucket reviews miss
     because each saw only one bucket?"
   - **Adversarial verify:** for each candidate finding, a skeptic tries to REFUTE it against the real code;
     keep only survivors. Default to refuted-if-uncertain. Use `verification-before-completion` discipline.
8. **Merge → found-by-N.** Dedupe across all models by (file, root-cause), tally how many models found each
   issue, rank by severity × consensus. A found-by-1 survives only if it passed verify. **If the merge is
   dispatched as a synthesis agent (Workflow or Agent tool) rather than done by you directly, chunk its output —
   see "Large-output subagent stalls" below. This is not optional for a bucket over ~100 raw findings; it is
   the single most common failure mode of this whole procedure.**
9. **Outputs** (read-only artifacts):
   - `REVIEW_DETAILED.md` — every critical/high issue: What / How-found / Root-cause `file:line` / Fix (real
     code) / Regression test / Risk, grouped by bucket, plus a medium/low table.
   - An **interactive HTML** comparison (matrix issues×models, by-model, by-consensus, by-bucket) — reuse the
     `impeccable` skill for craft.
   - Optionally `FIX_HANDOFF.md` — an ordered, rule-bound fix plan for a *separate* session (branch/worktree;
     never loosen a threshold; re-verify each fix). Do NOT apply fixes here.

## Model panel guidance

- 3–5 **cross-family** models (e.g. a GPT, an Anthropic Opus, an Anthropic Sonnet, plus one more family) beat 2
  near-siblings — same sample count, more lens spread. Cheap seats are fine; they still add unique tail findings.
- Scale to the ask: "find any bugs" → 2–3 models, single-vote verify. "ultra / exhaustive / audit" → the full
  grid (every model × every bucket + seams), reviewer-miss, 3-vote adversarial verify, synthesis.
- On any bucket still producing new uniques, a same-model re-run with a permuted reading order (loop-until-dry)
  mops up the tail more cheaply than hunting an exotic model.

## Read-only guarantee (enforce it)

- Freeze + point reviewers at the frozen copy; agentic reviewers get Read/Grep/Glob only and an explicit "do NOT
  edit/write/move/delete any file" instruction.
- The driver only reads source, calls the API, and writes result text files under `_panel_review/results/`.
- If a parallel session owns fixes, keep all review scratch under `_panel_review/` (never touch the repo's own
  CURRENT-TASK/WORK_QUEUE) so you can't collide.
- **The instruction is not self-enforcing.** An agentic reviewer with Bash access can still run the target
  repo's OWN sanctioned scripts (a test runner, a rebuild, an accept/gate script) even when told not to —
  observed live: a multi-hour agentic bucket review ran `accept_X.py --all` and a dashboard rebuild, regenerating
  derived artifacts from an otherwise-untouched source tree. Not a source edit, but still an instruction
  violation. Disclose it plainly in the output doc if it happens (don't retroactively minimize it), and don't
  invent a more dramatic story than what actually happened (e.g. don't write "was blocked from stopping it" if
  you simply chose not to attempt a stop).
- **If you need to stop a background review process mid-run** (found it violating the read-only instruction,
  or it's clearly stuck), stop it via its own tracked handle — `TaskStop` on a `run_in_background: true` Bash
  job, or the Workflow run's own stop mechanism — never by scanning `ps`/`ps aux` for a name match and guessing
  a PID. On a shared machine there can be many unrelated same-named processes; a wrong guess kills something
  else. If you can't confidently identify the right tracked handle, say so and leave it running rather than
  guessing.

## Large-output subagent stalls (the merge/synthesis step's biggest failure mode)

Confirmed root cause (from reading the actual failed subagent transcripts, not guessed): a synthesis agent
(merge, or a detail-doc write-up) that tries to emit ALL of its output — a large merged JSON array, or a long
markdown document — in ONE continuous tool call reliably triggers `API Error: Response stalled mid-stream`, an
infrastructure-level stream break. It is strongly correlated with output SIZE: buckets whose synthesized output
was small (~50-75 issues, one modest JSON blob) completed cleanly; buckets needing a much larger single write
(~150-220 raw findings to merge) failed 10/10 attempts across two independent dispatch rounds, on the exact same
5 buckets both times — this is deterministic given the task shape, not random flakiness a plain retry will fix.

**The fix, tested and confirmed 9/9 across a merge-synthesis pass and a detail-doc-writing pass on 5 different
previously-100%-failing buckets:** instruct the agent to write output INCREMENTALLY across MANY SMALL tool
calls instead of one big `Write`:
1. `Write` the file with just its opening structure (e.g. `{"bucket": "...", "issues": [` for JSON, or the H1 +
   intro + first section header for markdown).
2. Then `Bash`-append small batches (≤10 JSON issues, or 1-3 markdown write-ups, per call — aim for each
   individual tool call's new content staying well under ~2000 characters) via
   `open(path, "a", encoding="utf-8").write(chunk)`.
3. For JSON specifically: after all batches, fix the trailing comma and close the structure, then
   `python -c "import json; json.load(open(path))"` to verify it parses before declaring done.
4. Tell the agent to keep its own reasoning between tool calls short too — a long paragraph of thinking right
   before the write is part of the same continuous-generation risk.

Put this instruction directly in the merge/detail-doc agent's prompt, not just in your own plan — it's the
agent's own tool-call pattern that has to change.

## Model-specific reliability notes (update as you observe more)

- **One-shot HTTP timeouts must be generous per-model, not uniform.** Observed: on an identical script/proxy/
  prompt/max_tokens, GPT-5.5, GPT-5.4, and Opus-4.8-thinking all completed reliably in 100-500s; Claude
  Sonnet-4.6-thinking failed 7/7 cells at a 900s cap (5 timeouts landing right at the wall, 2 gateway 502s) —
  a transport-timeout problem specific to that model on that proxy for that prompt size, confirmed NOT a
  capability problem because its agentic channel (no fixed HTTP timeout) completed the same work cleanly for
  6/7 buckets. Default the one-shot timeout to 1800s (already reflected in the `review_grid.py` template
  above); if a specific model still can't complete one-shot within that, prefer its agentic channel entirely
  rather than continuing to raise the ceiling.
- **A "completed" agentic run can still be garbage — check the output length/shape before trusting it.**
  Observed: an agentic review session that printed no error and returned exit 0 nonetheless produced only a
  966-character truncated fragment (started mid-sentence) for one bucket while producing 20-35K characters of
  real, substantive output for six others in the same run. Sanity-check every agentic result's length/structure
  before folding it into the merge — don't assume rc=0 means usable output.
- **Watch cumulative proxy/API budget on a long review session.** A heavy multi-hour session (a full grid +
  an agentic run + synthesis + detail-doc writing, all on the same key) can exhaust a team/account usage budget
  partway through, surfacing as a fast `HTTP 400: Budget has been exceeded` on whatever call happens to run
  next — a different failure mode from a timeout or a stall, and not fixable by retrying sooner than the budget
  resets. If you hit it mid-review, finish what you can with the data already gathered and disclose the gap
  rather than hammering the endpoint with more attempts.

## Templates

### `panel_config.json` (fill per target repo)

```json
{
  "src_root": "ABS/PATH/TO/_panel_review/_frozen",
  "max_tokens": 64000,
  "endpoint": {
    "url": "https://your-proxy/v1/messages",
    "key_env": "GEN_API_KEY",
    "header": "x-api-key",
    "version": "2023-06-01"
  },
  "models": ["gpt-5.5", "gpt-5.4", "claude-opus-4.8-thinking", "claude-sonnet-4.6"],
  "repo_map": "One paragraph: what this codebase is + its pipeline stages, so a reviewer has context. Name known issues and say 'find NEW ones beyond these'.",
  "seams_map": "SHARED ARTIFACTS (producer -> consumers) ... | THINGS THAT ALL CLAIM X (check they agree) ... | DEPENDENCY GRAPH completeness ...   (repo-specific; author from the code)",
  "buckets": {
    "B1_name": {"what": "one line on what this group is", "files": ["pkg/a.py", "pkg/b*.py"]},
    "B_seams": {"what": "the SEAMS between modules; your job is cross-module inconsistency", "files": ["pkg/contract1.py", "pkg/contract2.py"], "seams": true}
  }
}
```

Notes: `models` must be ids the endpoint accepts (Anthropic messages format; a LiteLLM/OpenAI-compatible proxy
usually translates for GPT models). For a native OpenAI endpoint set `"header": "Authorization"` and prefix the
key with `Bearer ` in the driver, or add a small chat/completions adapter. Agentic-only models (your own
platform's) are NOT in this list — run them as subagents (step 5).

### `review_grid.py` (generalized driver — read-only)

```python
"""Generalized panel-review driver. READ-ONLY: reads source, calls an Anthropic-format /messages endpoint,
writes results/<bucket>__<model>.txt. Config in panel_config.json. Modes: (default) run all; --empties re-run
only missing/blank/errored/truncated cells; --dry print prompt sizes + endpoint reachability. Budget via env
GRID_MAXTOK, models via env GRID_MODELS (comma-sep) to override the config for a targeted re-run."""
import os, sys, json, time, glob, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = os.path.dirname(os.path.abspath(__file__))
CFG = json.load(open(os.path.join(HERE, "panel_config.json"), encoding="utf-8"))
SRC = CFG["src_root"]
RESULTS = os.path.join(HERE, "results"); os.makedirs(RESULTS, exist_ok=True)
EP = CFG["endpoint"]
BUCKETS = CFG["buckets"]
REPO_MAP = CFG.get("repo_map", "")
SEAMS_MAP = CFG.get("seams_map", "")
MODELS = os.environ.get("GRID_MODELS", ",".join(CFG["models"])).split(",")
MAXTOK = int(os.environ.get("GRID_MAXTOK", str(CFG.get("max_tokens", 64000))))

def _key():
    v = os.environ.get(EP["key_env"])
    if v: return v
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as k:
            return winreg.QueryValueEx(k, EP["key_env"])[0]
    except Exception: return None
KEY = _key()

RAW_HEAD = (
    "You are a rigorous, skeptical senior engineer doing an EXHAUSTIVE, open-ended code + design review of one "
    "module-group from the codebase described below. Read the full source and search it however you see fit. Find "
    "AS MANY distinct, real issues as you can, of ANY kind: correctness bugs, logic errors, off-by-one, wrong "
    "math/units/signs; silent failures (bare except, swallowed errors, default-on-missing that hides a problem); "
    "validation/gate BLIND SPOTS (a check that can be fooled or doesn't test what it claims); stale-data / ordering "
    "/ race hazards; unsafe exec/injection; places where code does NOT do what its docstring/name claims; "
    "producer/consumer contract mismatches; dead/unreachable code; fragile assumptions. Do NOT stop at a fixed "
    "number and do NOT cap your length. Completeness beats brevity. For EACH issue output a block exactly:\n"
    "ID: <short-slug>\nSEVERITY: critical|high|medium|low\nWHERE: <file>:<line-or-function>\nISSUE: <what is wrong>\n"
    "WHY: <why it matters>\nFIX: <a concrete fix>\nThen finish with TOP: (the single most important fix) and CHECK: "
    "(what you'd verify that you couldn't from the code alone). No preamble; start with the first issue.\n\n")

SEAMS_HEAD = (
    "You are a skeptical senior SYSTEMS engineer doing a CROSS-MODULE SEAM review of the codebase below. Do NOT "
    "report a single file's internal bug — report ONLY issues in the SEAMS BETWEEN modules: a producer whose output "
    "schema/units/naming a consumer misreads; two modules that both claim to be the source of truth and disagree; a "
    "'done'/verdict signal that can say PASS while another says FAIL on the same input; a dependency list that omits "
    "code that actually changes the artifact; a fallback chain that crosses a module boundary and loses intent. Use "
    "the SEAMS MAP to find the edges, then read BOTH sides of each edge. Find AS MANY as you can; do NOT cap length. "
    "For EACH: ID / SEVERITY / WHERE: <fileA:line> <-> <fileB:line> / ISSUE (the mismatch) / WHY / FIX. Finish with "
    "TOP and CHECK. No preamble.\n\n")

def read_group(name):
    parts = []
    for pat in BUCKETS[name]["files"]:
        for p in sorted(glob.glob(os.path.join(SRC, pat))):
            src = open(p, encoding="utf-8", errors="replace").read()
            rel = os.path.relpath(p, SRC)
            body = "\n".join("%4d  %s" % (i + 1, ln) for i, ln in enumerate(src.splitlines()))
            parts.append("===== FILE: %s =====\n%s" % (rel, body))
    return "\n\n".join(parts)

def build_prompt(name):
    b = BUCKETS[name]
    if b.get("seams"):
        hdr = "GROUP: %s\n%s\n\nREPO: %s\n\n----- SEAMS MAP -----\n%s\n----- SOURCE -----\n\n" % (name, b["what"], REPO_MAP, SEAMS_MAP)
        return SEAMS_HEAD + hdr + read_group(name)
    hdr = "GROUP: %s — %s\n\nREPO: %s\n\n----- SOURCE -----\n\n" % (name, b["what"], REPO_MAP)
    return RAW_HEAD + hdr + read_group(name)

def call(model, prompt, max_tokens=None):
    max_tokens = max_tokens or MAXTOK
    body = {"model": model, "max_tokens": max_tokens, "messages": [{"role": "user", "content": prompt}]}
    headers = {"content-type": "application/json"}
    if EP["header"] == "x-api-key":
        headers["x-api-key"] = KEY; headers["anthropic-version"] = EP.get("version", "2023-06-01")
    else:
        headers["Authorization"] = "Bearer " + KEY
    req = urllib.request.Request(EP["url"], data=json.dumps(body).encode(), headers=headers, method="POST")
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=1800) as r:
            d = json.load(r)
    except urllib.error.HTTPError as e:
        return {"err": "HTTP %s: %s" % (e.code, e.read()[:200].decode("utf-8", "ignore")), "secs": round(time.time() - t0, 1)}
    except Exception as e:
        return {"err": repr(e)[:200], "secs": round(time.time() - t0, 1)}
    blocks = d.get("content", []) or []
    text = "".join(b.get("text", "") for b in blocks if isinstance(b, dict) and b.get("type") in (None, "text"))
    return {"text": text.strip(), "stop": d.get("stop_reason"), "secs": round(time.time() - t0, 1)}

def _path(name, model):
    return os.path.join(RESULTS, "%s__%s.txt" % (name, model.replace(".", "").replace("-", "_")))

def _needs_run(name, model):
    p = _path(name, model)
    if not os.path.exists(p): return True
    t = open(p, encoding="utf-8", errors="replace").read().strip()
    return (len(t) == 0) or t.startswith("ERROR") or ("CHECK:" not in t[-4000:])  # blank/err/truncated

def cell(name, model):
    r = call(model, build_prompt(name))
    if r.get("err"):
        open(_path(name, model), "w", encoding="utf-8").write("ERROR: " + r["err"])
        return name, model, "ERR " + r["err"][:70], r["secs"]
    open(_path(name, model), "w", encoding="utf-8").write(r["text"])
    return name, model, "ok len=%d issues~%d stop=%s" % (len(r["text"]), r["text"].count("ID:"), r.get("stop")), r["secs"]

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else None
    if mode == "--dry":
        for n in BUCKETS: print("%-24s prompt_chars=%d" % (n, len(build_prompt(n))))
        print("endpoint key set:", bool(KEY), "| models:", MODELS, "| maxtok:", MAXTOK); return
    jobs = [(n, m) for n in BUCKETS for m in MODELS]
    if mode == "--empties":
        jobs = [(n, m) for (n, m) in jobs if _needs_run(n, m)]
    print("running %d cells" % len(jobs), flush=True)
    with ThreadPoolExecutor(max_workers=4) as ex:
        futs = {ex.submit(cell, n, m): (n, m) for (n, m) in jobs}
        for f in as_completed(futs):
            n, m, status, secs = f.result()
            print("DONE %-24s %-28s %ss %s" % (n, m, secs, status), flush=True)
    print("GRID COMPLETE -> results/", flush=True)

if __name__ == "__main__":
    main()
```

### Merge helper (found-by-N)

After the grid + subagents finish, ask a synthesis agent (or do it yourself) to read every `results/*.txt` plus
the subagent outputs and the SEAMS MAP, then: (a) dedupe by (file, root-cause) across models, (b) tag each issue
with the set of models that found it (found-by-N), (c) run the adversarial verify (a skeptic tries to refute each
against the frozen code; drop the refuted), (d) emit the canonical issue list ranked by severity × consensus. Feed
that list into `REVIEW_DETAILED.md` and the interactive HTML. Track everything in `_panel_review/WORK_QUEUE.md`.

---

*Tracked copy: also save this file to `claude-global-config/commands/panel-ultra-review.md` (per the skills-are-
tracked convention) after a NASA scrub.*

