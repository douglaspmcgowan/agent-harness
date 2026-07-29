---
name: tune
description: "Ingest new writing samples Douglas supplies and recalibrate his two persistent voice-guide files — ~/.claude/voice.md (compact core rules) and ~/.claude/voice-detail.md (sentence-level calibration) — which his global CLAUDE.md already loads before any publishable prose. Runs a mandatory classification GATE first (incremental update with new samples / audit-only with none / samples too thin for real statistics), maintains a running register-diverse sample corpus, computes real stylometric features (sentence-length distribution, TTR/MTLD, function-word frequency, punctuation ratios, paragraph shape) with a stdlib-only Python script and diffs them against the ranges the voice files already claim, proposes specific edits as a reviewable diff, audits the kill list for overcorrection/flatness (scoring a recent piece against the corpus with Cosine Delta stylometric distance), and backs up each file to a timestamped copy before any write (never a git worktree — ~/.claude is not a repo). Use when Douglas says 'attune', 'attune my voice', 'update my voice files', 'tune my voice', 'recalibrate my writing voice', 'tune', or '/tune'."
---

# /tune [samples] [--mode incremental|audit|auto] [--propose-only] [--recent-piece <path>]

Sounding like Douglas is a measured claim. His two voice files were built by hand and they read right, but they
carry zero computed numbers, so drift stays invisible until a piece comes out flat. This command turns "does this
still sound like me" into a measurement: it ingests new writing samples, curates them for register spread, computes
real stylometric features and diffs them against the ranges the files already claim, proposes specific edits as a
reviewable diff, and audits the kill list for the overcorrection that a long banned-word list can quietly cause. It
backs up each file to a timestamped copy before it writes, and it shows every change.

## Mode (read this first)

**Default: APPLY, with a backup and a shown diff.** Because every write is preceded by a timestamped backup and
every change is surfaced as an explicit diff, an applied edit is fully reversible and fully visible — so `/tune`
applies its proposed edits to the real `voice.md` / `voice-detail.md` by default, the same way `/hone` applies a
verified keep. Nothing is silently overwritten and nothing is hidden.

**`--propose-only`** (alt phrasing Douglas may use: "just show me the diff," "don't write anything yet," "propose,
don't apply"): stops at the diff. The corpus still gets updated and the features still get measured, but the two
voice files are left untouched — the proposed edits are reported as a diff for Douglas to apply himself. No backup
is made in this mode because nothing is written. Reach for it when he wants to eyeball a recalibration before it
lands.

If ARGUMENTS doesn't say which, use **Apply** (backup + diff + write).

## What this is NOT

- **Not `/recon`.** `/recon` maps a landscape and helps Douglas *decide* what to build or adopt — it produced the
  brief that informed this very skill (`Claude/Briefs/ai-voice-training-recon.md`). It does not itself touch or
  calibrate the voice files. `/tune` is the active tool that acts on the decision `/recon` surfaced.
- **Not `/ultraskill`.** `/ultraskill` *built* this skill (research-then-synthesize a new tool). It runs once, at
  authoring time. `/tune` is the per-use tool that skill produced; running `/tune` never re-runs `/ultraskill`.
- **Not `impeccable`.** `impeccable` is UI/visual-design critique and polish — a different domain entirely. It has
  nothing to do with prose voice.
- **Not the passive global-CLAUDE.md "Voice" rule.** That rule is the read-before-you-write behavior every session
  already performs (open `voice.md` + `voice-detail.md`, match the voice). `/tune` is the active tool that
  *updates the files that rule reads*. One consumes the files every session; this one refreshes them against new
  evidence.
- **Not `superpowers:writing-skills`.** That builds Claude Code *skills*. `/tune` calibrates Douglas's personal
  *writing style* — a different sense of the word "writing."
- **`/tune` does NOT ghostwrite or edit Douglas's actual documents, essays, or emails.** It only calibrates the
  two persistent voice-guide files. If he wants a specific piece written or de-AI-ified, that is ordinary prose work
  governed by those files; this command only calibrates them.

## Procedure

### Step 0 — Resolve inputs from ARGUMENTS

Needs enough that a subagent with ZERO conversation context could act alone:
- **The new samples** — paths to files, a pasted block of text, or a folder. Note for each (or infer) which
  register it belongs to: **casual/persuasive** (essays, reflections, fellowship answers, journal, recommendation
  letters, outreach) or **academic/technical** (thesis, research descriptions, formal reviews). This matches the
  dual-mode split the voice files are already built around.
- **`--mode`** — `incremental` (new samples supplied), `audit` (no new samples; just check the existing files for
  drift and overcorrection), or `auto` (default: let the Gate classify from what was actually supplied).
- **`--propose-only`** — per the Mode section. Default off (Apply).
- **`--recent-piece <path>`** — one recent piece of Douglas's *actual* output (something a prior session wrote for
  him in his voice) for the overcorrection audit in Step 5. If absent, the audit phase asks for one; if he has none
  handy, it says so and skips the overcorrection half plainly rather than inventing a target.

If the samples aren't given and can't be inferred from the conversation, ask which samples and which register before
proceeding — don't guess at a corpus.

### Step 1 — The classification GATE (mandatory, FIRST, before any measurement)

This is the cheap short-circuit that runs before any expensive stylometry. Classify the session into exactly one:

1. **`incremental`** — new samples supplied, and there is enough new material (**500 total words** of new writing
   is the enforced minimum; ~500–1000 is comfortable) to support a meaningful quantitative pass. Proceed through
   corpus → stylometry → audit → distill → apply.
2. **`audit_only`** — no new samples supplied. Skip corpus-ingest and new-sample stylometry. Run the
   overcorrection/kill-list audit (Step 5) and a drift read of the existing files, and propose only edits the audit
   itself justifies (e.g. retiring a kill-list entry that's causing flatness). This is the "just check my voice
   files are still healthy" path.
3. **`too_thin`** — samples supplied, but under the 500-word floor. A few sentences cannot support a
   reliable sentence-length distribution, and MTLD is unstable below ~50 tokens. **Say so plainly and fall back to a
   qualitative-only read** — fold the samples into the corpus for later, note the representative sentences by hand,
   run the audit, but do NOT compute or report statistics as if they were reliable. Never fabricate a distribution
   from too little data. (The run block invokes the stylometry script only on an `incremental` classification, so
   the script's own floor checks — the `reliable: false` flag under 500 words, the null MTLD under 50 tokens — are
   a backstop that catches a Gate misclassification, if a too-thin batch ever slips through as `incremental`.)

Report which classification fired and why. In `auto`, decide from the measured word count of what was supplied.

### Step 2 — Corpus handling (curate the corpus for register diversity)

`voice.md` references a sample corpus at `[[VOICE_DUMP.md]]`, but that file **does not exist anywhere on disk**
(confirmed by search of both the vault and `~/.claude`). This step fills that gap with a real, maintained corpus.

- Maintain a running corpus under `~/.claude/voice-corpus/`, split by register: `casual.md` and `academic.md`, plus
  a short `index.md` noting each sample's source, register, approximate word count, and date added.
- Append the new samples to the correct register file, each under a clear header tagging its register/mode and
  source.
- **Curate for register DIVERSITY across topics and modes.** The recon found that narrowing a sample set to one
  topic or register can *reduce* style-matching signal (topic-similarity retrieval shrinks stylistic range), and the
  stylometry literature is firmer still: random samples spread across a corpus beat contiguous excerpts, and
  topic-similar exemplar selection actively hurts style signal (Eder 2015, DSH; arXiv 2509.14543). Sample across
  time and topics; never cluster on one topic. So do
  not simply append-and-keep-the-newest. If one register or topic is starting to dominate the corpus, keep older samples that
  preserve range and note the balance explicitly. Any sample dropped to keep balance is reported, with the reason —
  never silently pruned by age.
- **Two floors, two jobs.** The Gate's 500-word floor is the per-update minimum — the least new material worth
  measuring as a batch at all. The established reliability floor for a computed stylometric *profile* is higher:
  **~5,000 words per register** (Eder 2015, DSH). Until a register's accumulated corpus reaches that, treat its
  computed ranges as provisional and label them so in the report.
- The Distill step (Step 4) should propose fixing `voice.md`'s dangling `[[VOICE_DUMP.md]]` reference to point at
  this real corpus, as one of its edits.

### Step 3 — Stylometric feature extraction (real numbers, stdlib Python)

`voice-detail.md` is entirely qualitative today — it observes patterns but computes no numbers. This step adds the
measured layer. Run the **embedded stylometry script** (see "Embedded stylometry script" below — stdlib-only, no
external package) once per register over that register's corpus, computing:

- **Sentence-length distribution** — mean, median, min, max, standard deviation, and the share of "punchy" 3–8-word
  sentences.
- **Vocabulary richness** — type-token ratio (TTR) and **MTLD** (length-robust; reimplemented directly from the
  standard McCarthy–Jarvis definition rather than pulled from `faststylometry`/`pystylometry`, since one has a known
  numpy-compatibility issue and the other's maintenance is unclear).
- **Function-word frequency** — the most frequent function words per 1000 words (a classic authorship signal).
- **Punctuation-habit ratios** — em-dashes, semicolons, colons, parentheses, and commas per 1000 words. This maps
  directly onto `voice-detail.md` §1's punctuation claims (semicolons in both modes; em-dashes casual-only;
  parentheses as the casual aside vehicle).
- **Paragraph shape** — mean sentences per paragraph and the share of single-sentence paragraphs.

**Then compute the delta against the ranges the files already claim.** `voice-detail.md` currently asserts
casual/persuasive sentences run **12–25 words** (with punchy drops of **3–8**) and academic/technical **18–35
words**. Pass those as the claimed range to the script (`--claim-min` / `--claim-max`) so it reports the share of
sentences within range and whether the measured mean still sits inside it. This is the whole point: it turns "does
this still sound like me" into a measured diff instead of a vibe check. Report every drift, however small.

A per-sample caution: a single short sample resists profiling even when the population-level signal is strong
(PromptPrint, arXiv 2606.06755: population separability d′ = 0.95, yet only 24.9% top-1 attribution on
prompt-length texts, with ~10 samples the stabilization threshold). That is why each run measures a register's
ACCUMULATED corpus; a lone new sample gets folded into the corpus first and measured as part of it.

### Step 4 — Distillation: propose specific edits as a reviewable diff

An agent reads the new samples, the measured feature deltas, and the current `voice.md` / `voice-detail.md`, and
proposes **specific, evidence-backed edits** — never a silent full rewrite. Each proposed edit names the file, the
section, the exact before/after text, and the evidence that drives it (which sample, which measured number). The
kinds of edit it may propose:

- **Updated numeric ranges** where the measured distribution has drifted from the claimed 12–25 / 18–35 / 3–8
  bounds.
- **New representative sentences** pulled verbatim from the real new samples, to refresh `voice-detail.md`'s
  representative-sentence and reference-paragraph examples. Cap the curated exemplars at **3–5 per register**:
  style-imitation gains plateau at ~4–5 examples, and past ~4 a model starts responding to the examples rather
  than absorbing them (arXiv 2509.14543, with practitioner convergence). The corpus feeds the measured profile;
  the voice files get the 3–5 curated exemplars.
- **New recurring words/phrases** that show up across the new samples and belong in the "recurring words/phrases"
  lists.
- **Kill-list additions or retirements** — a new AI-default tell to ban, or an existing entry to retire if the audit
  (Step 5) shows it's causing more harm than good.
- **Reference fixes** — e.g. repointing the dangling `[[VOICE_DUMP.md]]` link at the real corpus.

Two phrasing rules for the edits themselves, both measured. State the measured feature VALUES explicitly in
`voice-detail.md` rather than leaving a qualitative gloss — numeric grounding lifted authorship attribution from
0.681 to 0.827 (the SALA pattern, arXiv 2602.23079). And phrase feature atoms imperatively ("uses semicolons in
both modes," "prefers 12–25-word sentences") — the Style-Eliciting Prompts pattern (arXiv 2606.05716), which beat
imitate-this-text baselines by 12.9–26.1% on style control.

This mirrors the strongest technique the recon found — the interview-built voice profile (Every.to's method).
Douglas's files already *are* that artifact; this step refreshes them against new evidence rather than replacing the
approach. Output is an explicit unified diff across both files, reviewable before anything is written.

### Step 5 — Overcorrection / kill-list audit (both directions)

A long banned-word list carries a real, evidenced risk. A 2026 arXiv paper ("Semantic Gravity Wells") found via
logit-lens analysis that *naming* a forbidden token in a prompt can measurably RAISE its incidence, and multiple
independent practitioner sources describe a whack-a-mole dynamic where banning one known "AI tell" just shifts
output to the next detectable one. Douglas's kill list (`voice-detail.md` §8 + its RED FLAGS) is already long and
rigorous, so this audit checks BOTH directions:

- **Kill-list violations** — run one recent real piece of Douglas's actual output (from `--recent-piece`, or ask him
  for one) through a check for every banned term, phrase, and construction, reporting each hit with its snippet.
- **Overcorrection / flatness** — in the SAME piece, check for the signs that the list is over-suppressing: a
  suspiciously *uniform* sentence-length distribution (low standard deviation — the RED FLAGS' own "uniform sentence
  length" concern, now measured), stilted substitutes standing in for banned words, or prose that reads scrubbed and
  lifeless. Report these too.

**How to score the piece — the published-best validation stack** (arXiv 2509.14543) combines three signals: an
authorship-verification check, a stylometric distance between the generated piece and the authentic corpus, and an
AI-detector score as a human-likeness proxy; LLM-as-judge alone was explicitly rejected as self-biased. Scoped to
what a session can actually run: the distance metric is **Cosine Delta** (the vector-normalized Delta variant —
classic Burrows' Delta is magnitude-sensitive and less robust; Evert 2017), computable here from the embedded
script's function-word frequencies over the piece and the matching register corpus. The AV classifier and the AI
detector are external tools — run them when available, and name them as unrun when they aren't; the in-session
floor is the Cosine Delta plus the two-direction read above.

Report both halves honestly. If the audit finds a kill-list entry that's inducing flatness more than it's
preventing a tell, Step 4 may propose retiring it. If no recent piece is available, say so and run only the
drift/flatness read that doesn't need one — don't manufacture a target.

### Step 6 — Backup, then apply (the safety mechanism)

`~/.claude` is **not a git repository** (verified), so the worktree isolation `/spar`, `/hone`, and `/probe` use is
a category error here — do not invent it for these files. The safety mechanism is Douglas's own standing rule
("never overwrite user files in place"):

- **Before writing ANY change** to `voice.md` or `voice-detail.md`, copy the current file to a timestamped backup at
  `~/.claude/backups/<name>.BACKUP_<yyyyMMdd_HHmmss>.md`, **in the same turn as the write**, and confirm the backup
  exists before touching the original. Never skip this. Never silently overwrite.
- Then apply the Step-4 edits to the real files, and report both the backup paths and the applied diff.
- In `--propose-only` mode, make no backup and no write — just hand back the diff.

### Step 7 — The honest final report (see "Final report" below)

## Safety constraints (apply every run, no exceptions)

- **The safety mechanism is a timestamped backup.** `~/.claude` is not a git repo, so the worktree isolation
  `/spar`, `/hone`, and `/probe` use has no analogue here, and inventing one for these files would be a category
  error. Before any write to `voice.md` /
  `voice-detail.md`, copy the current version to `~/.claude/backups/<name>.BACKUP_<yyyyMMdd_HHmmss>.md` in the same
  turn, confirm it exists, then write. A future session must NOT "fix" this skill by adding worktree logic for the
  real voice files — this note is the guard against that.
- **Never fabricate statistics from too little data.** If the Gate fired `too_thin`, the report is a qualitative
  read with an explicit insufficiency caveat — no invented distributions, no MTLD reported below its reliability
  floor, no confident numbers off a handful of sentences.
- **The corpus is Douglas's real personal writing** (the recon notes it includes personal/ministry material). It
  stays local: never send corpus text to a web tool or to the GEN endpoint, and keep `~/.claude/voice-corpus/`
  OUT of the tracked `claude-global-config` mirror. Only the skill file itself is tracked; the corpus of his private
  writing is not.
- **Never run with elevated/bypass permissions.** A generic "update my voice" ask does not justify disabling the
  permission system; run at default tool permissions. If a safety layer blocks an action mid-run, that is a correct
  block — narrow scope, don't route around it.
- **Propose edits; never a silent full rewrite.** Every change to the voice files is an explicit, evidence-backed
  edit shown as a diff. No wholesale regeneration of a file, no edit without a sample or a measured number behind it.
- **No commits.** `~/.claude` isn't a repo, so there is nothing to commit there anyway. The tracked skill copy in
  `claude-global-config` is a separate repo; do not auto-commit or push it — a commit there needs Douglas's
  say-so and a NASA scrub gate.
- **Make only the edits the evidence supports.** No unrelated cleanup of the voice files, no reformatting, no
  drive-by restructuring beyond what a proposed edit requires.

## Procedure (how to run it)

1. Resolve inputs per Step 0 (samples + register, mode, `--propose-only`, `--recent-piece`).
2. **Call the `Workflow` tool** with the script below verbatim, passing
   `args: { samples: "<paths or pasted text + register for each>", mode: "<incremental|audit|auto>", proposeOnly: <true if --propose-only, else false>, recentPiece: "<path/text of a recent real piece, or ''>" }`.
   This is an explicit skill-triggered Workflow use (per the Workflow tool's own rule) — no separate opt-in.
   - **The Gate, Distill, and Audit phases run on `model: 'opus'`** — the load-bearing judgment calls (classifying
     the session, deciding which edits the evidence actually supports, reading a piece for both violations and
     overcorrection). The mechanical Corpus, Stylometry, and Apply phases stay on the default model.
   - The Stylometry phase bootstraps the embedded Python script to a stable path
     (`~/.claude/commands/attune-stylometry.py`) on first run if it isn't already there, then runs it.
3. **Report the result** per Step 7 / "Final report" below. Never claim the voice is "fully captured" — report what
   was measured this pass and what remains.

## Embedded stylometry script (stdlib-only; bootstrapped on first run)

The Stylometry phase writes this exact script to `~/.claude/commands/attune-stylometry.py` if it does not already
exist, then runs it once per register with the claimed range for that register. It has no external dependency (no
`numpy`, no `nltk`, no `faststylometry`/`pystylometry`); the metrics are reimplemented directly.

```python
#!/usr/bin/env python3
# attune-stylometry.py -- stdlib-only stylometric feature extraction for /tune.
# Reimplements the well-established metrics directly (no faststylometry / pystylometry:
# one has a known numpy-compatibility issue, the other's maintenance is unclear).
# Usage:  python attune-stylometry.py <mode_label> [--claim-min N] [--claim-max N]
#                                     [--compare REF_FILE] file1 [file2 ...]
#         (or pipe text on stdin and pass no files)
# --compare: also report cosine similarity (function words + char 3-grams) between
#            the measured text and REF_FILE (e.g. a register corpus) -- the light
#            in-session stand-in for Cosine Delta authorship distance.
# --impostor FILE (repeatable): with --compare, runs the impostor-method verification:
#            the measured text's similarity to the Douglas corpus is ranked against its
#            similarity to each impostor text. Rank 1 of N on both feature sets =
#            consistent with Douglas. Needs 2+ impostors to mean anything.
# Output: one JSON object of measured features for that register, on stdout.
import sys, re, json, math, statistics
from collections import Counter

FUNCTION_WORDS = set("""
a an the of to in for on with at by from up about into over after under
and or but nor so yet because although though while if unless since as than
i you he she it we they me him her us them my your his its our their
this that these those is are was were be been being am do does did
have has had will would can could should may might must shall
not no there here what which who whom whose when where why how then
""".split())

# Douglas's signature markers (voice-detail.md recurring words/phrases + transcript profile)
MARKER_PHRASES = [
    "i think", "i don't think", "honestly", "the thing is", "the truth is",
    "in sum", "the goal is", "fundamentally", "basically", "go ahead and",
    "keep reading", "this entails", "make sure", "in fact",
]
# Hype/intensifier tells (he never writes hype -- a rising rate here is drift)
HYPE_WORDS = set("""
very truly incredibly extremely amazing exciting remarkable revolutionary
transformative thrilled delighted stunning phenomenal
""".split())

def sentences(text):
    # a markdown table would merge into one giant pseudo-sentence and corrupt the
    # sentence-length stdev -- drop table rows ('|'-led) and ---/=== separator rules first
    kept = []
    for ln in text.split('\n'):
        s = ln.strip()
        if s.startswith('|') or re.fullmatch(r'[-=|:\s]{3,}', s):
            continue
        kept.append(ln)
    t = '\n'.join(kept)
    # protect decimals (551.7) and a few abbreviations from the sentence splitter
    t = re.sub(r'(\d)\.(\d)', r'\1<DOT>\2', t)
    t = re.sub(r'\b(Mr|Mrs|Ms|Dr|vs|etc|Fig|Eq|e\.g|i\.e)\.',
               lambda m: m.group(0).replace('.', '<DOT>'), t)
    out = []
    # a blank-line paragraph break ends a sentence even without terminal punctuation
    for p in re.split(r'(?<=[.!?])\s+|\n\s*\n', t):
        p = p.replace('<DOT>', '.').strip()
        if p and re.search(r'[A-Za-z0-9]', p):
            out.append(p)
    return out

def words(text):
    return re.findall(r"[A-Za-z']+", text)

def _mtld_pass(tokens, threshold=0.72):
    factors, types, count = 0.0, set(), 0
    for tok in tokens:
        count += 1
        types.add(tok)
        if count and len(types) / count <= threshold:
            factors += 1
            types, count = set(), 0
    if count > 0:                                   # partial trailing factor
        ttr = len(types) / count
        denom = 1 - threshold
        factors += (1 - ttr) / denom if denom else 0
    return len(tokens) / factors if factors > 0 else float('nan')

def mtld(tokens):
    # MTLD is unreliable below ~50 tokens -- return null rather than fabricate a number
    if len(tokens) < 50:
        return None
    f = _mtld_pass(tokens)
    b = _mtld_pass(list(reversed(tokens)))
    return round((f + b) / 2, 1)

def sentence_openers(sents):
    # First-word distribution: measures the "This + verb" backbone, "But" contrast,
    # claim-first openings -- the strongest qualitative claims in voice-detail.md, counted.
    firsts = []
    for s in sents:
        ws = words(s)
        if ws:
            firsts.append(ws[0].lower())
    n = len(firsts) or 1
    top = Counter(firsts).most_common(8)
    return {
        'per_100_sentences': {w: round(100 * c / n, 1) for w, c in top},
        'pct_this': round(100 * firsts.count('this') / n, 1),
        'pct_but': round(100 * firsts.count('but') / n, 1),
        'pct_i': round(100 * firsts.count('i') / n, 1),
        'pct_however': round(100 * firsts.count('however') / n, 1),
    }

def rhythm(slens):
    # Sequence, beyond the distribution: his signature is a long setup followed by a
    # blunt short verdict. AI drafts regress toward even alternation; flat rhythm is
    # the overcorrection tell the audit looks for.
    if len(slens) < 2:
        return None
    pairs = list(zip(slens, slens[1:]))
    punches = sum(1 for a, b in pairs if a >= 20 and b <= 8)
    return {
        'long_to_short_punch_per_100_pairs': round(100 * punches / len(pairs), 1),
        'mean_abs_successive_diff': round(statistics.mean(abs(a - b) for a, b in pairs), 1),
    }

def marker_rates(text, toks):
    low = ' ' + re.sub(r'\s+', ' ', text.lower()) + ' '
    total = len(toks) or 1
    phrases = {p: round(low.count(' ' + p + ' ') / total * 1000, 2) for p in MARKER_PHRASES}
    phrases = {p: v for p, v in phrases.items() if v > 0}
    contractions = sum(1 for t in toks if "'" in t and len(t) > 2)
    hype = sum(1 for t in toks if t in HYPE_WORDS)
    return {
        'marker_phrases_per_1000': phrases,
        'contractions_per_1000': round(contractions / total * 1000, 2),
        'hype_intensifiers_per_1000': round(hype / total * 1000, 2),
        'exclamations_per_1000': round(text.count('!') / total * 1000, 2),
    }

LATINATE_SUFFIX = re.compile(
    r"(tion|sion|ity|ment|ance|ence|ize|ise|ise|ate|ous|ify|ology|ical|ative|itude)$")
# common be+participle pairs that are adjectival, never passive
NOT_PASSIVE_PART = set("""
interested concerned excited tired married located situated based supposed
used called named known open closed done finished
""".split())

def diction(toks):
    # Tests voice-detail's Anglo-Saxon-vs-Latinate diction claim ("make" over "create",
    # "use" over "utilize") as a measured dial, via suffix rate + word length.
    total = len(toks) or 1
    latinate = sum(1 for t in toks if len(t) > 6 and LATINATE_SUFFIX.search(t))
    return {
        'latinate_suffix_per_1000': round(latinate / total * 1000, 2),
        'mean_word_length': round(sum(len(t) for t in toks) / total, 2),
        'pct_words_7plus_chars': round(100 * sum(1 for t in toks if len(t) >= 7) / total, 1),
    }

PASSIVE_RE = re.compile(
    r"\b(is|are|was|were|been|being|be|am)\s+(?:(?:not|also|often|already|then|thus|"
    r"still|never|being)\s+)?(\w+(?:ed|en))\b", re.IGNORECASE)

def passive_rate(sents):
    # Regex approximation (be-form + past participle, common adjectival pairs excluded).
    # Overcounts irregular adjectives and misses get-passives -- treat as a register
    # comparator, never an absolute grammar count.
    if not sents:
        return None
    hits = 0
    for s in sents:
        for m in PASSIVE_RE.finditer(s):
            if m.group(2).lower() not in NOT_PASSIVE_PART:
                hits += 1
                break                                   # count sentences, once each
    return {
        'pct_sentences_passive': round(100 * hits / len(sents), 1),
        'note': 'regex estimate (be + past participle); comparator across registers, '
                'never an absolute grammar count',
    }

def char3_counts(text):
    t = re.sub(r'\s+', ' ', text.lower())
    t = re.sub(r"[^a-z0-9 .,;:()\-']", '', t)
    return Counter(t[i:i + 3] for i in range(len(t) - 2))

def cosine(c1, c2):
    keys = set(c1) | set(c2)
    dot = sum(c1.get(k, 0) * c2.get(k, 0) for k in keys)
    n1 = math.sqrt(sum(v * v for v in c1.values()))
    n2 = math.sqrt(sum(v * v for v in c2.values()))
    return round(dot / (n1 * n2), 4) if n1 and n2 else None

def fw_vector(toks):
    total = len(toks) or 1
    return {w: c / total for w, c in Counter(t for t in toks if t in FUNCTION_WORDS).items()}

def main():
    argv = sys.argv[1:]
    mode = argv[0] if argv else 'unlabeled'
    claim_min = claim_max = None
    compare_file = None
    impostors = []
    files, i = [], 1
    while i < len(argv):
        if argv[i] == '--claim-min':
            claim_min = float(argv[i + 1]); i += 2
        elif argv[i] == '--claim-max':
            claim_max = float(argv[i + 1]); i += 2
        elif argv[i] == '--compare':
            compare_file = argv[i + 1]; i += 2
        elif argv[i] == '--impostor':
            impostors.append(argv[i + 1]); i += 2
        else:
            files.append(argv[i]); i += 1

    if files:
        text = "\n\n".join(open(f, encoding='utf-8', errors='replace').read() for f in files)
    else:
        text = sys.stdin.read()

    sents = sentences(text)
    slens = [len(words(s)) for s in sents if words(s)]
    toks = [w.lower() for w in words(text)]
    paras = [p for p in re.split(r'\n\s*\n', text.strip()) if p.strip()]
    para_counts = [len(sentences(p)) for p in paras]
    total = len(toks) or 1

    punct = {
        'em_dash': text.count('—'),
        'semicolon': text.count(';'),
        'colon': text.count(':'),
        'parenthesis_open': text.count('('),
        'comma': text.count(','),
    }
    fw = Counter(t for t in toks if t in FUNCTION_WORDS)

    para_q = 0
    for p in paras:
        ps = sentences(p)
        if ps and ps[0].rstrip().endswith('?'):
            para_q += 1

    result = {
        'mode': mode,
        'files': files or ['<stdin>'],
        'word_count': len(toks),
        'sentence_count': len(slens),
        'reliable': len(toks) >= 500,               # the 500-word floor for a meaningful pass
        'sentence_length': {
            'mean': round(statistics.mean(slens), 1) if slens else None,
            'median': statistics.median(slens) if slens else None,
            'min': min(slens) if slens else None,
            'max': max(slens) if slens else None,
            'stdev': round(statistics.pstdev(slens), 1) if len(slens) > 1 else None,
            'pct_punchy_3_8': round(100 * sum(1 for L in slens if 3 <= L <= 8) / len(slens), 1) if slens else None,
        },
        'sentence_openers': sentence_openers(sents),
        'rhythm': rhythm(slens),
        'ttr': round(len(set(toks)) / total, 3),
        'ttr_note': 'TTR is length-sensitive; compare only across similar-length texts. MTLD is the length-robust measure.',
        'mtld': mtld(toks),
        'function_word_per_1000': {w: round(c / total * 1000, 2) for w, c in fw.most_common(15)},
        'punctuation_per_1000_words': {k: round(v / total * 1000, 2) for k, v in punct.items()},
        'em_dash_check': {
            'count': punct['em_dash'],
            'target': 0,
            'pass': punct['em_dash'] == 0,
            'note': 'Hard gate per Douglas 2026-07-08: em-dashes are zero in every register. '
                    'Nonzero here is a fail regardless of register or corpus baseline.',
        },
        'diction': diction(toks),
        'passive_voice': passive_rate(sents),
        'markers': marker_rates(text, toks),
        'paragraph': {
            'count': len(paras),
            'mean_sentences': round(statistics.mean(para_counts), 1) if para_counts else None,
            'pct_single_sentence': round(100 * sum(1 for c in para_counts if c == 1) / len(para_counts), 1) if para_counts else None,
            'pct_question_opener': round(100 * para_q / len(paras), 1) if paras else None,
        },
    }
    if claim_min is not None and claim_max is not None and slens:
        within = sum(1 for L in slens if claim_min <= L <= claim_max)
        result['claimed_range'] = {
            'min': claim_min,
            'max': claim_max,
            'pct_within': round(100 * within / len(slens), 1),
            'mean_in_range': bool(claim_min <= statistics.mean(slens) <= claim_max),
        }
    if compare_file:
        ref_text = open(compare_file, encoding='utf-8', errors='replace').read()
        ref_toks = [w.lower() for w in words(ref_text)]
        result['compare'] = {
            'reference': compare_file,
            'cosine_similarity_function_words': cosine(fw_vector(toks), fw_vector(ref_toks)),
            'cosine_similarity_char3': cosine(char3_counts(text), char3_counts(ref_text)),
            'note': 'Cosine similarity over relative-frequency vectors (1.0 = identical profile). '
                    'A lightweight stand-in for Cosine Delta: true Delta z-scores need a multi-document '
                    'reference set, which a single corpus file cannot provide.',
        }
        if impostors:
            # Impostor method (Koppel & Winter 2014, adapted): raw cosine alone has no
            # threshold, so calibrate by RANK -- is the piece closer to the Douglas
            # corpus than to each distractor text?
            my_fw, my_c3 = fw_vector(toks), char3_counts(text)
            candidates = [('DOUGLAS_CORPUS', ref_text)]
            for imp in impostors:
                candidates.append((imp, open(imp, encoding='utf-8', errors='replace').read()))
            scored = []
            for name, ctext in candidates:
                ctoks = [w.lower() for w in words(ctext)]
                scored.append({
                    'candidate': name,
                    'cosine_fw': cosine(my_fw, fw_vector(ctoks)),
                    'cosine_char3': cosine(my_c3, char3_counts(ctext)),
                })
            rank_fw = sorted(scored, key=lambda d: -(d['cosine_fw'] or 0))
            rank_c3 = sorted(scored, key=lambda d: -(d['cosine_char3'] or 0))
            pos_fw = 1 + [d['candidate'] for d in rank_fw].index('DOUGLAS_CORPUS')
            pos_c3 = 1 + [d['candidate'] for d in rank_c3].index('DOUGLAS_CORPUS')
            n = len(scored)
            result['impostor_verification'] = {
                'candidates': scored,
                'douglas_rank_function_words': f'{pos_fw} of {n}',
                'douglas_rank_char3': f'{pos_c3} of {n}',
                'consistent_with_douglas': bool(pos_fw == 1 and pos_c3 == 1),
                'note': 'Rank-calibrated verdict (impostor method): the piece is scored '
                        'consistent only if the Douglas corpus outranks every impostor on '
                        'BOTH feature sets. Confidence grows with impostor count; under 2 '
                        'impostors this is weak evidence either way.',
            }
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
```

## Workflow script (pass verbatim; only `args` changes per invocation)

```js
export const meta = {
  name: 'tune',
  description: 'Ingest new writing samples -> gate (incremental / audit-only / too-thin) -> curate a register-diverse corpus -> measure stylometric features (stdlib Python) vs the ranges the voice files claim -> overcorrection/kill-list audit -> propose specific edits as a reviewable diff -> timestamped backup + apply. No git worktree (~/.claude is not a repo); the safety mechanism is backup-before-write.',
  phases: [
    { title: 'Gate' },
    { title: 'Corpus' },
    { title: 'Stylometry' },
    { title: 'Audit' },
    { title: 'Distill' },
    { title: 'Apply' },
  ],
}

const SAMPLES = args.samples || ''
const MODE = ['incremental', 'audit', 'auto'].includes(args.mode) ? args.mode : 'auto'
const PROPOSE_ONLY = args.proposeOnly === true
const RECENT_PIECE = args.recentPiece || ''

const VOICE = 'C:/Users/dmcgowa2/.claude/voice.md'
const VOICE_DETAIL = 'C:/Users/dmcgowa2/.claude/voice-detail.md'
const CORPUS_DIR = 'C:/Users/dmcgowa2/.claude/voice-corpus'
const BACKUP_DIR = 'C:/Users/dmcgowa2/.claude/backups'
const STYLO = 'C:/Users/dmcgowa2/.claude/commands/attune-stylometry.py'
const PY = 'C:/Users/dmcgowa2/scoop/apps/python313/current/python.exe'
// voice-detail.md's currently-claimed sentence-length ranges (the comparison baseline)
const CLAIMED = { casual: { min: 12, max: 25 }, academic: { min: 18, max: 35 } }

// --- Phase schemas (JSON-schema-validated agent output, spar.md/hone.md/probe.md pattern) ---

const GATE_SCHEMA = {
  type: 'object',
  properties: {
    classification: { type: 'string', enum: ['incremental', 'audit_only', 'too_thin'] },
    new_word_count: { type: 'integer' },
    per_register_word_count: { type: 'object' },   // e.g. { casual: 800, academic: 0 }
    registers_present: { type: 'array', items: { type: 'string', enum: ['casual', 'academic'] } },
    can_quantify: { type: 'boolean' },             // false for too_thin / audit_only-with-no-corpus
    reason: { type: 'string' },
  },
  required: ['classification', 'new_word_count', 'can_quantify', 'reason'],
}

const CORPUS_SCHEMA = {
  type: 'object',
  properties: {
    corpus_dir: { type: 'string' },
    files_written: { type: 'array', items: { type: 'string' } },
    per_register: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          register: { type: 'string' },
          samples_added: { type: 'integer' },
          total_samples: { type: 'integer' },
          total_words: { type: 'integer' },
        },
        required: ['register', 'samples_added'],
      },
    },
    diversity_note: { type: 'string' },            // how balance was kept (NOT just newest-kept)
    dropped_for_balance: { type: 'array', items: { type: 'string' } },
  },
  required: ['corpus_dir', 'files_written', 'diversity_note'],
}

const STYLO_SCHEMA = {
  type: 'object',
  properties: {
    script_path: { type: 'string' },
    script_bootstrapped: { type: 'boolean' },       // true if the phase had to write the script out this run
    per_register: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          register: { type: 'string' },
          reliable: { type: 'boolean' },            // false when under the 500-word floor
          measured: { type: 'object' },             // the raw JSON the script emitted
          claimed_range: { type: 'object' },        // { min, max } from CLAIMED
          deltas: {                                  // the measured diff vs the claimed qualitative rules
            type: 'array',
            items: {
              type: 'object',
              properties: {
                feature: { type: 'string' },
                claimed: { type: 'string' },
                measured: { type: 'string' },
                drift: { type: 'string' },
              },
              required: ['feature', 'measured', 'drift'],
            },
          },
        },
        required: ['register', 'reliable', 'measured'],
      },
    },
    caveats: { type: 'string' },                    // small-sample / null-MTLD honesty
  },
  required: ['per_register'],
}

const DISTILL_SCHEMA = {
  type: 'object',
  properties: {
    proposed_edits: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          file: { type: 'string' },
          section: { type: 'string' },
          kind: { type: 'string', enum: ['numeric_range', 'representative_sentence', 'recurring_phrase', 'kill_list_add', 'kill_list_retire', 'fix_reference', 'other'] },
          before: { type: 'string' },
          after: { type: 'string' },
          evidence: { type: 'string' },             // which sample / which measured number drives it
        },
        required: ['file', 'section', 'kind', 'after', 'evidence'],
      },
    },
    diff: { type: 'string' },                        // an explicit unified diff across both files
    nothing_to_change: { type: 'boolean' },
    note: { type: 'string' },
  },
  required: ['proposed_edits', 'nothing_to_change'],
}

const AUDIT_SCHEMA = {
  type: 'object',
  properties: {
    piece_source: { type: 'string' },               // path/desc used, or 'none_supplied'
    kill_list_violations: {
      type: 'array',
      items: {
        type: 'object',
        properties: { term: { type: 'string' }, snippet: { type: 'string' } },
        required: ['term', 'snippet'],
      },
    },
    overcorrection_signals: {
      type: 'array',
      items: {
        type: 'object',
        properties: { signal: { type: 'string' }, evidence: { type: 'string' } },
        required: ['signal', 'evidence'],
      },
    },
    sentence_length_stdev: { type: 'number' },       // low value = suspiciously uniform (a flatness signal)
    gravity_well_note: { type: 'string' },           // the arXiv finding: is the list itself inducing flatness?
    verdict: { type: 'string' },                     // the honest both-directions read
  },
  required: ['piece_source', 'kill_list_violations', 'overcorrection_signals', 'verdict'],
}

const APPLY_SCHEMA = {
  type: 'object',
  properties: {
    propose_only: { type: 'boolean' },
    backups: {                                        // made BEFORE any write, same turn
      type: 'array',
      items: {
        type: 'object',
        properties: { file: { type: 'string' }, backup_path: { type: 'string' }, confirmed_exists: { type: 'boolean' } },
        required: ['file', 'backup_path', 'confirmed_exists'],
      },
    },
    applied: {
      type: 'array',
      items: {
        type: 'object',
        properties: { file: { type: 'string' }, applied: { type: 'boolean' }, edits_count: { type: 'integer' } },
        required: ['file', 'applied'],
      },
    },
    diff_shown: { type: 'boolean' },
    reason_not_applied: { type: 'string' },
  },
  required: ['propose_only', 'backups', 'applied', 'diff_shown'],
}

// --- Prompts ---

function gatePrompt(samples, mode) {
  return `You are running the mandatory classification GATE for a voice-file recalibration, BEFORE any expensive ` +
    `stylometry. This is the cheap short-circuit.\n\n` +
    `NEW SAMPLES SUPPLIED (paths and/or pasted text, with register tags where given): ${samples || '(none)'}\n` +
    `REQUESTED MODE: ${mode}\n\n` +
    `Measure the total word count of the NEW material actually supplied, split by register (casual/persuasive vs ` +
    `academic/technical -- the two modes Douglas's voice files are built around). Then classify into exactly one:\n` +
    `1. incremental -- new samples supplied AND >= 500 total words (the enforced floor; ~500-1000 is ` +
    `comfortable): enough for a meaningful quantitative pass. can_quantify=true.\n` +
    `2. audit_only -- NO new samples supplied: only the drift/overcorrection audit and a read of the existing ` +
    `files should run. can_quantify=false (no new material to measure).\n` +
    `3. too_thin -- samples supplied but under the 500-word floor: too little for a reliable sentence-length ` +
    `distribution, and MTLD is unstable below ~50 tokens. can_quantify=false -- fall back to a QUALITATIVE-only ` +
    `read. Do NOT fabricate statistics from too little data.\n\n` +
    `Report classification, new_word_count, per_register_word_count, registers_present, can_quantify, and a ` +
    `plain-language reason. In 'auto', decide purely from the measured word count.`
}

function corpusPrompt(samples, gate) {
  return `Maintain Douglas's running writing-sample corpus under ${CORPUS_DIR} (create it if absent). This fills a ` +
    `real gap: voice.md references a corpus at [[VOICE_DUMP.md]] that does not exist on disk.\n\n` +
    `NEW SAMPLES: ${samples}\nGATE RESULT: ${JSON.stringify(gate)}\n\n` +
    `Structure: casual.md and academic.md (split by register), plus index.md logging each sample's source, ` +
    `register, approx word count, and date added. Append each new sample under a clear header tagging its ` +
    `register and source.\n\n` +
    `CURATE FOR REGISTER DIVERSITY ACROSS TOPICS AND MODES. Narrowing the corpus to one topic/register measurably HURTS ` +
    `style-matching signal (topic-similarity retrieval shrinks stylistic range). Random samples spread across a ` +
    `corpus beat contiguous excerpts, and topic-similar selection actively hurts style signal (Eder 2015, DSH; ` +
    `arXiv 2509.14543) -- sample across time and topics, never cluster on one topic. Do NOT simply append-and-keep-` +
    `newest. If one register or topic is starting to dominate, keep older samples that preserve range and say so. ` +
    `Any sample you drop to keep balance must be reported with its reason -- never silently pruned by age.\n\n` +
    `IMPORTANT: this corpus is Douglas's private writing (includes personal/ministry material). Keep it strictly ` +
    `under ${CORPUS_DIR}; never copy it into the tracked claude-global-config mirror, and never send its text to a ` +
    `web tool. Report corpus_dir, files_written, per_register counts, diversity_note, and anything dropped_for_balance.`
}

function styloPrompt(gate) {
  return `Compute REAL stylometric features over the corpus, one run per register, using the stdlib-only script ` +
    `embedded in the /tune skill file.\n\n` +
    `1. If ${STYLO} does not already exist, write it out VERBATIM from the skill's "Embedded stylometry script" ` +
    `block (it is stdlib-only -- no numpy/nltk/faststylometry), then use it. Set script_bootstrapped accordingly.\n` +
    `2. Run it once per register over that register's corpus file, passing the claimed sentence-length range so it ` +
    `computes the diff automatically:\n` +
    `   casual:   "${PY}" "${STYLO}" casual --claim-min ${CLAIMED.casual.min} --claim-max ${CLAIMED.casual.max} "${CORPUS_DIR}/casual.md"\n` +
    `   academic: "${PY}" "${STYLO}" academic --claim-min ${CLAIMED.academic.min} --claim-max ${CLAIMED.academic.max} "${CORPUS_DIR}/academic.md"\n` +
    `   (If python313 is unavailable, fall back to any python3 on PATH -- the script needs only the standard library.)\n\n` +
    `GATE RESULT: ${JSON.stringify(gate)}\n\n` +
    `For each register, capture the raw JSON the script emits into 'measured', and build 'deltas' comparing the ` +
    `computed numbers against what voice-detail.md currently CLAIMS: casual sentences 12-25 words (punchy drops ` +
    `3-8), academic 18-35 words; semicolons in both modes; em-dashes casual-only; parentheses as the casual aside ` +
    `vehicle. Flag every drift, however small. If a register's word count is under the 500-word floor (script ` +
    `'reliable' is false) or MTLD came back null, set reliable=false and say so in caveats -- do NOT report those ` +
    `numbers as if they were trustworthy. Separately: if a register's ACCUMULATED corpus is still under ~5,000 ` +
    `words (the reliability floor for a computed stylometric profile -- Eder 2015, DSH), mark that register's ` +
    `computed ranges as provisional in caveats even when this batch cleared the 500-word gate floor.`
}

function distillPrompt(samples, stylo, gate, audit) {
  return `Propose SPECIFIC, evidence-backed edits to Douglas's voice files -- never a silent full rewrite. Read the ` +
    `new samples, the measured feature deltas, the overcorrection audit, and the CURRENT contents of both files.\n\n` +
    `FILES: ${VOICE} (compact core rules) and ${VOICE_DETAIL} (sentence-level calibration).\n` +
    `NEW SAMPLES: ${samples}\nGATE: ${JSON.stringify(gate)}\nSTYLOMETRY: ${JSON.stringify(stylo)}\nAUDIT: ${JSON.stringify(audit)}\n\n` +
    `Read both files first. Then propose edits, each naming file, section, exact before/after text, and the ` +
    `evidence behind it (which sample, which measured number). Allowed kinds:\n` +
    `- numeric_range: update a claimed sentence-length bound (12-25 / 18-35 / 3-8) where the measured distribution ` +
    `has genuinely drifted. Only when the sample was reliable (over the floor).\n` +
    `- representative_sentence: refresh voice-detail.md's representative sentences / reference paragraphs with ` +
    `lines pulled VERBATIM from the real new samples. Cap curated exemplars at 3-5 per register -- style-imitation ` +
    `gains plateau at ~4-5 examples, and past ~4 a model starts responding to the examples rather than absorbing ` +
    `them (arXiv 2509.14543). The corpus feeds the measured profile; the voice files get the 3-5 exemplars.\n` +
    `- recurring_phrase: add a word/phrase that recurs across the new samples to the recurring-words lists.\n` +
    `- kill_list_add: a new AI-default tell worth banning. kill_list_retire: an existing entry the audit shows is ` +
    `causing flatness more than preventing a tell.\n` +
    `- fix_reference: repoint voice.md's dangling [[VOICE_DUMP.md]] link at the real ${CORPUS_DIR} corpus.\n\n` +
    `Phrasing rules for the edits, both measured: state measured feature VALUES explicitly in voice-detail.md ` +
    `rather than a qualitative gloss (numeric grounding lifted authorship attribution 0.681 -> 0.827 -- the SALA ` +
    `pattern, arXiv 2602.23079), and phrase feature atoms imperatively ("uses X", "prefers Y") -- the ` +
    `Style-Eliciting Prompts pattern (arXiv 2606.05716), which beat imitate-this-text baselines by 12.9-26.1% on ` +
    `style control.\n\n` +
    `If the gate was too_thin or audit_only, propose ONLY qualitative edits the evidence supports (representative ` +
    `sentences, a fix_reference, an audit-driven retirement) -- do NOT invent numeric_range changes off an ` +
    `unreliable sample. If nothing is warranted this pass, set nothing_to_change=true and say so -- that is a ` +
    `valid outcome. Output the proposed_edits AND an explicit unified diff across both files. Do NOT write the ` +
    `files here; that is the Apply phase's job.`
}

function auditPrompt(recentPiece) {
  return `Audit Douglas's kill list in BOTH directions. His list (voice-detail.md section 8 + its RED FLAGS) is ` +
    `already long and rigorous, and a 2026 arXiv finding ("Semantic Gravity Wells") shows via logit-lens analysis ` +
    `that NAMING a forbidden token can measurably RAISE its incidence, with practitioners independently reporting ` +
    `a whack-a-mole dynamic (ban one tell, the next emerges). So do not only hunt violations -- check for ` +
    `overcorrection too.\n\n` +
    `RECENT REAL PIECE TO AUDIT (a piece of Douglas's actual output a prior session wrote in his voice): ` +
    `${recentPiece || '(none supplied)'}\n\n` +
    `If a piece is supplied:\n` +
    `1. VIOLATIONS -- scan it for every banned term, phrase, and construction in voice-detail.md (the kill list, ` +
    `the filler/hedge/transition bans, the RED FLAGS, and the "it's X, not Y" antithesis). Report each hit with ` +
    `its snippet.\n` +
    `2. OVERCORRECTION / FLATNESS -- in the SAME piece, look for signs the list is over-suppressing: a ` +
    `suspiciously UNIFORM sentence-length distribution (compute the stdev; low = flat -- this is the RED FLAGS' ` +
    `own "uniform sentence length" concern, now measured), stilted substitutes standing in for banned words, or ` +
    `prose that reads scrubbed and lifeless. Report each with evidence.\n` +
    `3. DISTANCE -- if the register corpus exists, also compute the lightweight stylometric distance from the ` +
    `published validation stack (arXiv 2509.14543): Cosine Delta (the vector-normalized Delta variant; classic ` +
    `Burrows' Delta is magnitude-sensitive and less robust -- Evert 2017) over the embedded script's ` +
    `function-word frequencies, piece vs the matching register corpus, and fold it into the verdict. AV ` +
    `classifiers and AI detectors are external and optional -- name them as unrun if unavailable. Do not rely on ` +
    `LLM-as-judge impressions alone; that same paper rejected LLM-as-judge as self-biased.\n\n` +
    `If NO piece is supplied, set piece_source='none_supplied', run only the read that doesn't need one (a ` +
    `qualitative look at whether the kill list itself has grown to a size likely to induce flatness), and say so ` +
    `plainly -- do NOT invent a target. Report kill_list_violations, overcorrection_signals, sentence_length_stdev, ` +
    `gravity_well_note, and an honest both-directions verdict.`
}

function applyPrompt(distill, proposeOnly) {
  const writeClause = proposeOnly
    ? `PROPOSE-ONLY MODE: make NO backup and NO write. Simply present the proposed diff for Douglas to apply ` +
      `himself. Set propose_only=true, backups=[], applied entries all applied=false, diff_shown=true.`
    : `APPLY MODE: for EACH file you will change, FIRST copy the current file to ` +
      `${BACKUP_DIR}/<name>.BACKUP_<yyyyMMdd_HHmmss>.md and CONFIRM the backup exists (set confirmed_exists=true) ` +
      `BEFORE writing anything to the original -- same turn, never skipped, never a silent overwrite. ${BACKUP_DIR} ` +
      `already exists. Then apply the proposed edits to the real file. Report each backup_path and each applied ` +
      `file with its edits_count, and set diff_shown=true (the applied diff goes in the final report).`
  return `Apply the proposed voice-file edits under Douglas's file-safety rule. NOTE: ~/.claude is NOT a git repo, ` +
    `so there is no worktree here -- the safety mechanism is a timestamped backup before each write. Do not attempt ` +
    `any git worktree isolation for these files.\n\n` +
    `PROPOSED EDITS + DIFF: ${JSON.stringify(distill)}\n\n` +
    `${writeClause}\n\n` +
    `If distill.nothing_to_change is true, write nothing regardless of mode and report that plainly. Never edit ` +
    `beyond the proposed edits. Do NOT commit or touch the tracked claude-global-config mirror.`
}

// --- Run ---

log(`Gate: classifying the session (samples supplied? enough for real statistics?) before any measurement`)
const gate = await agent(gatePrompt(SAMPLES, MODE), { phase: 'Gate', schema: GATE_SCHEMA, label: 'gate', model: 'opus' })

const classification = gate ? gate.classification : 'audit_only'
const canQuantify = !!(gate && gate.can_quantify)
const doCorpus = classification !== 'audit_only'   // fold new samples in for incremental AND too_thin
const doStylo = classification === 'incremental' && canQuantify

let corpus = null
if (doCorpus) {
  log(`Corpus: folding the new samples into the register-diverse corpus (classification=${classification})`)
  corpus = await agent(corpusPrompt(SAMPLES, gate), { phase: 'Corpus', schema: CORPUS_SCHEMA, label: 'corpus' })
} else {
  log('Corpus: skipped (audit_only -- no new samples to ingest)')
}

let stylo = null
if (doStylo) {
  log('Stylometry: computing real features per register and diffing them against the claimed ranges')
  stylo = await agent(styloPrompt(gate), { phase: 'Stylometry', schema: STYLO_SCHEMA, label: 'stylometry' })
} else {
  log(`Stylometry: skipped quantitative pass (classification=${classification}, can_quantify=${canQuantify}) -- qualitative read only, no fabricated statistics`)
}

// The overcorrection/kill-list audit is the standing check -- it runs in EVERY classification.
log('Audit: checking a recent real piece for BOTH kill-list violations and overcorrection/flatness')
const audit = await agent(auditPrompt(RECENT_PIECE), { phase: 'Audit', schema: AUDIT_SCHEMA, label: 'audit', model: 'opus' })

log('Distill: proposing specific, evidence-backed edits as a reviewable diff (never a silent rewrite)')
const distill = await agent(distillPrompt(SAMPLES, stylo, gate, audit), { phase: 'Distill', schema: DISTILL_SCHEMA, label: 'distill', model: 'opus' })

let apply = null
if (distill && distill.nothing_to_change) {
  log('Apply: distill found nothing warranted this pass -- writing nothing')
} else {
  log(PROPOSE_ONLY ? 'Apply: propose-only -- handing back the diff, no backup, no write'
                   : 'Apply: backing up each file to a timestamped copy, then applying the edits')
  apply = await agent(applyPrompt(distill, PROPOSE_ONLY), { phase: 'Apply', schema: APPLY_SCHEMA, label: 'apply' })
}

return {
  mode: MODE,
  proposeOnly: PROPOSE_ONLY,
  classification,
  can_quantify: canQuantify,
  gate,
  corpus,
  stylometry: stylo,
  audit,
  distill,
  apply,
  note: 'Voice recalibration is a reading for this pass; never report the voice as "fully captured" or otherwise final.',
}
```

## Final report (what to tell Douglas)

Report in the measured, non-fabricating register of `/spar`, `/hone`, and `/probe`:

- **Gate outcome first.** Which classification fired (`incremental` / `audit_only` / `too_thin`) and why, including
  the measured new-word count. If `too_thin`, state the insufficiency caveat plainly and present only the
  qualitative read.
- **Corpus update** — which register files were touched, how many samples were added, and the register-balance
  note (what was kept for diversity, anything dropped and why). Confirm the corpus stayed out of the tracked mirror.
- **Measured feature deltas** — per register, the computed sentence-length distribution, TTR/MTLD, function-word
  and punctuation ratios, and paragraph shape, each diffed against the range the voice files claim (12–25 casual /
  18–35 academic / 3–8 punchy). Name every drift. If a metric was unreliable on the sample size, say so instead of
  reporting it.
- **Proposed / applied edits** — each with its file, section, before→after, and the evidence behind it. In Apply
  mode, confirm the timestamped backup path for each file written and show the applied diff. In `--propose-only`
  mode, hand back the diff and state plainly that nothing was written.
- **Overcorrection audit result** — both halves: kill-list violations found in the recent piece, AND any
  overcorrection/flatness signals (uniform sentence length, stilted substitutes), plus the Cosine Delta distance
  against the register corpus when it was computable. If no recent piece was available, say so.
- **Honest close.** Mirror `/spar`'s "no new issues found across the last 2 rounds," `/hone`'s "nothing material to
  keep this pass," and `/probe`'s refusal to say "fully tested." Acceptable closes: "no drift past the existing
  ranges this pass," "nothing warranted an edit," "corpus updated, recalibration deferred until more samples land."
  **NEVER** claim the voice is "fully captured," "perfectly calibrated," "complete," or any absolute — a stylometric
  measurement is a reading for this pass, and treating it as a certificate is exactly the overclaim to avoid.
- Full absolute path(s) of every file created or changed (voice files, backups, corpus, the bootstrapped script),
  per the standing Files-list convention, each tagged NEW/UPDATED.

---

*Tracked copy: also save this file to `claude-global-config/commands/tune.md` (per the skills-are-tracked
convention) after a NASA scrub. The `~/.claude/voice-corpus/` corpus is NOT tracked — it holds Douglas's private
writing and stays local.*
