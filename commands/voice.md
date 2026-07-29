---
name: voice
description: Take one piece of writing and rewrite it to sound like Douglas, using ~/.claude/voice.md (core rules) and ~/.claude/voice-detail.md (sentence-level calibration + §12 measured baselines + kill list) as the spec, then verify the rewrite with attune-stylometry.py (cosine similarity to the register corpus, the measured dials, and a kill-list/antithesis scan) before handing it back. Preserves meaning, facts, numbers, and his specifics — it re-voices existing content and never invents claims. Backs up before any in-place write. Use when Douglas says 'voice', '/voice', 'voice this', 'put this in my voice', 'make this sound like me', 'rewrite this in my voice', 'de-AI this draft', or 'match my voice'.
tags: [claude, voice, writing, rewrite, stylometry]
---

# /voice [piece] [--register casual|academic|refined] [--in-place] [--diff-only]

Take a piece of writing and bring it to Douglas's voice. The two voice files (`voice.md`, `voice-detail.md`) are the spec; this skill applies them to one concrete piece — a rough draft of his own, or a draft that reads like a model wrote it — and rewrites it so it sounds like him. It measures the piece before and after with the stylometry script, so the claim "this now sounds like you" is a number, not a vibe. It preserves the content: same meaning, same facts, same specific values. It re-voices; it does not ghostwrite new material.

## What this is NOT

- **Not `/tune`** (the voice-calibration skill, renamed from the old `/voice`). `/tune` UPDATES the two voice-guide files from new writing samples. `/voice` CONSUMES those files to rewrite one piece. One maintains the spec, the other applies it. If a rewrite surfaces a genuine new voice pattern worth recording, say so and suggest a `/tune` run; do not edit the voice files here.
- **Not the passive CLAUDE.md read-before-prose rule.** That rule governs Claude DRAFTING new prose for Douglas from scratch. `/voice` takes an EXISTING piece and moves it to his voice.
- **Not a ghostwriter.** It re-voices content that already exists. It never adds claims, invents facts, or changes numbers. Anti-flattening is a hard rule: keep his specifics, his cadence, his asides.
- **Not `impeccable`.** That is UI and visual-design work, a different domain.
- **Not `/hone`, `/spar`, or `/probe`.** Those act on code (performance, break-fix, test quality). This acts on prose.

## Step 0 — Resolve inputs from ARGUMENTS

- **The piece** — a file path, or pasted text. If neither is present and nothing in the conversation is clearly the target, ask which piece, then stop.
- **`--register`** — `casual` (essays, statements, reflections, fellowship answers, letters), `academic` (papers, thesis, formal reviews), or `refined` (outreach emails, post text, slide text). If not given, infer from the piece and its destination: an essay or statement is casual/persuasive; a paper or thesis is academic/technical; an email, slide, or post is refined-conversational. State the inferred register in one line and proceed.
- **Output mode** — default: return the rewritten text in chat, and if the source was a file, also write a NEW versioned file next to it (never overwrite). `--in-place`: back up the source first, then overwrite it. `--diff-only`: report the measured drift and the specific changes you WOULD make, and stop without producing the full rewrite.

## Step 1 — The GATE (first, before rewriting anything)

Measure before you rewrite, and classify into exactly one:

1. **`needs-rewrite`** — the piece is prose meant to sound like him, and it carries AI tells, kill-list terms, any em-dash, the "X, not Y" antithesis, filler preambles, uniform rhythm, or diction off the register baseline. Run the full rewrite.
2. **`already-close`** — the piece is already clean: no kill-list hits, no antithesis, dials near the §12 baseline for the register, high cosine to the corpus. Say so, make only minimal touch-ups, and do not churn a clean piece into a different-but-not-better one.
3. **`not-prose`** — the input is an outline, bullet notes, code, or data, not prose to be voiced. Say that plainly and stop; do not invent prose around it.

To classify, run the stylometry script on the piece (Step 3's measurement) and scan it against the kill list and the antithesis rule. Report which classification fired and why. This mirrors the gate-first discipline in `/tune` and `/probe`: no expensive rewriting on a piece that does not need it.

## Step 2 — Read the spec

Read both voice files in full as the rewrite spec:
- `C:\Users\dmcgowa2\.claude\voice.md` — core rules, hard nos (the antithesis ban at the top), the two-mode split, the few-shot exemplars.
- `C:\Users\dmcgowa2\.claude\voice-detail.md` — sentence architecture, diction, hedging, transitions, the full kill list, the RED FLAGS list, §12 measured baselines (the target numbers per register), and the reference paragraph for the target register.

For `refined`, also read §11 (Refined Conversational Register). There is no dedicated corpus for refined; use the §11 rules plus the casual dials as a loose reference.

## Step 3 — Measure the input (before-numbers)

Run the stylometry script on the piece, for the target register, comparing against that register's corpus:

`C:/Users/dmcgowa2/scoop/apps/python313/current/python.exe "C:/Users/dmcgowa2/.claude/commands/attune-stylometry.py" <register> --claim-min <lo> --claim-max <hi> --compare "<corpus file>" "<piece file>"`

Register mapping:
- `casual` → claim 12 / 25 → corpus `C:\Users\dmcgowa2\Documents\Claude NASA Folder\voice\corpus\casual.md`
- `academic` → claim 18 / 35 → corpus `C:\Users\dmcgowa2\Documents\Claude NASA Folder\voice\corpus\academic.md`
- `refined` → claim 12 / 25 → casual corpus (loose reference)

If the piece is pasted text rather than a file, write it to a temp file first, or pipe it on stdin (the script reads stdin when no file is passed). Record the before-values: cosine similarity to the corpus (function words and char 3-grams), latinate-suffix rate, passive rate, punchy share, sentence-length stdev, hype rate, and every kill-list and antithesis hit found by hand.

## Step 4 — Rewrite to his voice

Rewrite the piece against the spec. The rules that matter most:

- **Preserve the content.** Same meaning, same facts, same numbers, same argument order. Do not add claims or examples that were not there. Do not drop his specifics — the specific number, the concrete analogy, the aside is often the thing that makes it sound like him.
- **Match the register's architecture.** Casual: short-to-medium subject-leading sentences with punchy drops, parentheticals doing real work, first person, "This"+verb transitions, rhetorical-question-then-answer, single-sentence paragraphs for emphasis. Academic: longer info-packed sentences, third-person framing, "However"/"Furthermore" as formal pivots, no personality asides, passive allowed where it reads naturally.
- **Fix the diction.** Casual leans Anglo-Saxon and concrete ("make" over "create", "use" over "utilize"). Academic uses precise Latinate terms only where they are the right technical word.
- **Remove every tell.** Delete kill-list terms and constructions, filler preambles ("it is worth noting"), impersonal hedges ("it could be argued"), and the "X, not Y" antithesis in all its forms (this is the single most important cut). State the positive claim and stop.
- **Em-dashes: zero.** Convert every em-dash to a colon, a period, or a real clause. Applies uniformly across casual, academic, and refined registers — this is a hard gate, checked mechanically in Step 5, not a dial to trend toward.
- **Fix flat rhythm.** If sentences run uniform, add short punches after longer setups. Do not overcorrect into a different flatness.

## Step 5 — Verify the rewrite (before claiming done)

Re-run the stylometry script on the rewritten text, same register and same `--compare` corpus. Report before → after for: cosine similarity to the corpus (should rise or hold high), latinate rate and passive rate and punchy share moving toward the §12 register baseline, hype rate at or near zero, kill-list hits at zero, antithesis at zero, em-dash count at zero (check the script's `em_dash_check.pass` field directly). Self-audit the rewrite against voice.md's RED FLAGS list.

If a dial moved the wrong way, or a kill-list or antithesis hit survived, iterate once and re-measure. The em-dash count is a hard gate: any nonzero count after the rewrite is a fail, iterate until `em_dash_check.pass` reads true. Watch the sentence-length standard deviation: if it collapsed well below the register baseline (~8+ for both modes), the rewrite flattened the rhythm and needs variation put back. Do not claim the piece matches his voice if the after-numbers do not support it — report what improved and what still reads off.

## Step 6 — Output

- Hand back the rewritten piece.
- A short list of the notable changes and why (which tells were cut, what diction shifted, where rhythm was fixed) — brief, a few lines, not a lecture.
- The before → after measurement table.
- **File handling.** If the source was a file: by default write the rewrite to a NEW versioned file next to it (e.g. `<name>.voiced.md`), and give the full path. With `--in-place`: first copy the original to `<folder>/_backups/<name>.BACKUP_<yyyyMMdd_HHmmss>.<ext>`, confirm the backup exists, then overwrite. For `.docx`/`.pptx`/`.xlsx` the `protect-authored-docs.js` hook enforces write-new-file — obey it and write a new versioned file rather than overwriting.

## Safety constraints

- **Never invent content.** Preserve meaning, facts, numbers, and his specifics. Anti-flattening is a hard rule.
- **Never the "X, not Y" antithesis** in the output — Douglas's #1 AI tell, banned in all forms.
- **Back up before any in-place write.** Never overwrite a source file without a timestamped backup confirmed first. Obey the Office-doc write-new-file hook.
- **This skill does not edit `voice.md` / `voice-detail.md`.** That is `/tune`'s job. Suggest a `/tune` run if a new pattern is worth recording; do not touch the voice files here.
- **The corpus is private.** The compare step reads the local corpus files. Never send the corpus or the piece to a web tool or the GEN endpoint.
- **Never run with elevated or bypass permissions.** If a safety layer blocks an action mid-run, that is a correct block — narrow scope, do not route around it.

## Final report

Report honestly, in the measured register of `/tune`, `/spar`, and `/probe`: what the gate classified and why, the before → after numbers, the specific changes made, and what still reads off if anything does. Never claim the piece is "perfectly in his voice" — report what the measurement supports this pass and what remains.

---

*Tracked copy: also save this file to `claude-global-config/commands/voice.md` (per the skills-are-tracked convention) after a NASA scrub.*
