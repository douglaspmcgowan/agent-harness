---
name: video-cut
description: "Transcript-aligned video cutting with ffmpeg: silence/pause removal cross-checked against word timestamps, text-addressed cuts ('cut from X to Y'), automatic seam verification by re-transcribing around every cut, rename + optional zip packaging, and a logged cut plan for one-command undo. Replaces the multi-round manual seam-trimming loop from the capstone videos. Uses /groq-transcribe's Whisper call as the timestamp source. Use when Douglas says 'cut these clips', 'remove the pauses', 'trim the video', 'chunk this recording', or '/video-cut'."
---

# /video-cut [file-or-folder] [instructions]

Cuts a screen recording or talking-head video the way the capstone videos were cut by hand: find the dead
air, cut it without clipping words, verify every seam, package the result. The transcript drives the cuts;
ffmpeg executes them; a re-transcription pass around each seam replaces the manual review round.

This is a solid v1 — `/ultraskill improve video-cut` can deepen it (scene-aware cuts, filler-word removal,
crossfade seams) when the evidence warrants.

## What this is NOT

- **Not `/groq-transcribe`.** That skill produces a cleaned transcript as its deliverable. Here the
  transcription is Step 1's raw material — word-level timestamps that address the cuts. If Douglas only
  wants the text, run `/groq-transcribe` and stop.
- **Not an editor.** No titles, color, music, speed ramps, or creative re-sequencing. Cuts only. If the ask
  drifts into creative editing, say so and hand back.
- **Not a compressor/converter.** Resolution, codec, and bitrate stay as close to source as re-encoding
  allows. "Make this file smaller" is a plain ffmpeg one-liner, and this skill declines it.

## Gate — when NOT to run (check before anything expensive)

1. **No resolvable video file.** If ARGUMENTS names nothing and no recent video is obvious from the
   conversation, ask for the path. Never guess among multiple candidates.
2. **Sensitive content.** Step 1 sends AUDIO to Groq's external API. If the recording contains
   NASA-internal / CUI / ITAR material, STOP — silence-only mode (Step 2 without transcript cross-check,
   fully local) is the fallback to offer, with the caveat that breath-protection and seam-verify need the
   transcript and are lost.
3. **File is open in an editor** (Premiere, Clipchamp, OBS still recording — check for the process or a
   growing file size). Ask Douglas to close it first; a mid-write read produces a corrupt cut.
4. **No ffmpeg.** Check `ffmpeg -version`. A portable no-admin build is already on this machine at
   `C:/Users/dmcgowa2/tools/ffmpeg/ffmpeg-master-latest-win64-gpl/bin` (ffmpeg/ffprobe .exe) — probe that
   path before concluding it's absent, since it isn't on PATH. Only if neither is present does downloading a
   fresh portable build apply, and that needs Douglas's explicit OK; ask, never fetch silently.

## Steps

### 1 — Transcribe with word-level timestamps

Extract audio locally first (videos routinely exceed Groq's 25 MB cap; audio alone rarely does):
`ffmpeg -i in.mp4 -vn -ac 1 -ar 16000 -c:a flac audio.flac`. Then reuse `/groq-transcribe`'s curl call with
`response_format="verbose_json"` plus `-F "timestamp_granularities[]=word"` (model `whisper-large-v3-turbo`,
`GROQ_API_KEY` from env — never echoed). Save the full JSON; the `words` array is the address space for
everything below. Verify: word count > 0 and last word's end time within ~2s of the video duration
(`ffprobe -show_entries format=duration`). Whisper's word times are a DTW post-hoc estimate, not ground
truth — commonly 100–400 ms off the true boundary. Flag any word shorter than ~0.13 s or longer than ~2 s
as a likely misalignment; treat its timestamps as low-confidence downstream (they lean on silencedetect,
below, for the actual cut point).

### 2 — Silence-cut candidates, cross-checked so breaths survive

Run `ffmpeg -i audio.flac -af silencedetect=noise=-35dB:d=0.8 -f null -` and parse the
`silence_start`/`silence_end` pairs (defaults: -35 dB floor, 0.8 s minimum; take overrides from ARGUMENTS).
A detected silence becomes a cut candidate ONLY when the transcript agrees: the gap between the word ending
before it and the word starting after it must also exceed the threshold. A breath or beat inside a sentence
that silencedetect flags but the transcript spans stays in. The cut's actual timestamps come from
silencedetect's `silence_start`/`silence_end` (frame-accurate — verified sub-millisecond against a known gap),
NOT the word `end`/`start` times (which carry Whisper's 100–400 ms error); the transcript is the veto on
whether a cut is allowed at all, silencedetect sets where it lands. Trim each kept cut inward 0.2 s on both
ends so speech onset is never touched.

### 3 — Text-addressed cuts

For "cut from X to Y" / "remove the part about Z": find the phrase in the transcript (normalize case and
punctuation; fuzzy-match if needed), map to the first word's `start` and last word's `end`, pad 0.15 s
outward to the neighboring word boundaries. Because those word times carry Whisper's 100–400 ms error, snap
each mapped boundary to the nearest silencedetect edge when one falls within ~0.3 s, so the cut lands on the
real audio gap instead of a guessed word time. If a phrase matches more than once, list the matches with
timestamps and ask which one — never pick silently. If it matches nowhere, say so; never cut on a guess.

### 4 — Cut plan + log (undo path)

Merge Steps 2–3 into keep-segments. Then de-stutter: if a cut leaves an isolated kept fragment shorter than
~0.5 s (overridable) between two cuts, that micro-segment reads as a jarring flicker — either drop it (merge
the neighboring cuts through it) or keep the pause; default is to keep the pause, since re-adding a beat is
less jarring than a flash-frame. This is the min-clip-length guard auto-editor and AutoCut use to stop
aggressive silence removal from turning into choppy jump cuts. Write `<name>.cuts.json` next to the output: source path, every cut
with before/after timestamps and its reason (`silence` / `text: "..."`), the keep-segment list, and the
exact ffmpeg command. Undo = the original file, which is never modified; re-running with an edited
cuts.json is the redo path.

### 5 — Execute with ffmpeg

Extract each keep-segment by re-encoding (`-c:v libx264 -crf 18 -c:a aac`); stream-copy snaps to keyframes
and clips words, so accuracy wins over speed here. Place `-ss`/`-to` AFTER `-i` (output seeking) — with
re-encode that decodes to the exact frame, where `-ss` before `-i` fast-seeks and can miss by a few frames,
the one thing this skill exists to prevent. Concat the segments with
the concat demuxer. Output is `<name>_cut.mp4` — the original stays untouched.

### 6 — Seam-verify (the step that replaces the manual review round)

For EVERY seam in the output: extract ±2 s around it, transcribe that window, and check the boundary words
against the transcript — the last kept word before the cut and the first kept word after it must both appear
whole. A clipped or missing word fails the seam: nudge that boundary outward 0.2 s, re-cut, re-verify, max
3 attempts, then flag it as UNVERIFIED in the report rather than silently shipping it. Also confirm output
duration equals source minus logged cuts (±1 s).

### 7 — Package

Rename per the convention Douglas gives (or keep `<name>_cut.mp4`). If he asked for a zip:
`Compress-Archive` (stdlib, no new dependency). Multiple input files repeat Steps 1–6 per file, one
cuts.json each.

## Safety constraints (every run, no exceptions)

- **Never modify or delete the original.** All output goes to new files; the original plus cuts.json IS the
  undo mechanism. No `-y` overwrite onto any pre-existing file.
- **Sensitivity gate before any Groq upload** (Gate item 2). Audio leaves the machine in Step 1 only; video
  never does. NASA-internal / CUI / ITAR content goes to no external API, period.
- **No silent downloads.** ffmpeg absent → ask before fetching (Gate item 4).
- **Never echo `GROQ_API_KEY`** or any secret, even partially.
- **Temp hygiene, originals excluded.** Clean up extracted audio and segment files after packaging; keep
  cuts.json and the output. Never sweep a directory pattern that could match the source.

## Final report (honest register)

- **Cuts made** — each with before/after timestamps and reason, plus total duration removed
  (source → output).
- **Seams verified** — N of M passed; any UNVERIFIED seam named with its timestamp so Douglas can spot-check
  that one instead of re-watching everything. Never claim "all pauses removed" — report the thresholds used
  and note that quieter pauses below them remain.
- **Files** — full absolute paths: output video (NEW), cuts.json (NEW), zip if made (NEW), original
  (unchanged, referenced).
- **Undo line** — the one command / re-run that restores or revises, verbatim.

---

*Tracked copy: also save this file to `claude-global-config/commands/video-cut.md` (per the skills-are-tracked
convention) after a NASA scrub.*
