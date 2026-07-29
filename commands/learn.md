---
name: learn
description: "Learn how to DO something by absorbing practitioner craft — not a factual research report, but an internalizable techniques cheatsheet you apply to your own work. Two modes. AUTO: given a topic (e.g. 'making better dashboards'), find and mine the GOOD practitioner sources — specific handwritten/personal articles (not top-of-Google SEO listicles) and technical YouTube breakdowns (not ad-driven review channels) — and synthesize a durable note of techniques, do's/don'ts, sources-with-why, skills/references to add, and concrete changes to make. FEED: Douglas hands over specific YouTube videos he knows are useful but hasn't watched; the skill ingests each (transcript-first — it mines the transcript/description/comments, it never claims to have watched) and pulls out the teachings and concrete adjustments. For visual videos it can run an optional frame-sampling VISION pass that actually reads the screen (silent demos, on-screen UI/numbers, before/after). Writes a vault note under Claude/Learn/<topic>.md. Use when Douglas says 'help me learn X', 'I want to get better at X', 'learn how to do X', 'pull the lessons from these videos', 'here are videos I don't have time to watch', 'mine these for what I should know', or '/learn'."
---

# /learn [topic | --feed <video URLs>]

Booked skills and top-of-Google results tell you the generic version of a craft. The real technique lives in
what individual practitioners wrote up after doing it a hundred times — a personal blog post, a technical
breakdown on YouTube — and in the videos Douglas has already flagged as worth watching but never had time for.
This command does the watching-and-reading he doesn't have time to do, and turns it into a short, applicable
set of techniques he can actually use — honest about the fact that for video it reads the transcript, it does
not watch.

## What this is NOT

- **Not `/deep-search`.** deep-search answers a specific QUESTION with a cited report and stops when every
  sub-question has ≥2 sources. `/learn` isn't answering a question — it builds a repeatable how-to-DO-it
  cheatsheet meant to change future behavior (techniques / do's-don'ts), and it REUSES deep-search's
  human-source search mechanics as a subroutine, not its output shape.
- **Not `/recon`.** recon maps a landscape of tools/approaches to help Douglas DECIDE whether to adopt
  something, mirrored against his setup (Have/Partial/Gap). `/learn` isn't an adopt-decision — it's absorbing
  craft technique into an internalizable note. (Its "skills/references to add" section borrows recon's instinct
  lightly, and routes any real build idea through `/overlap` first — but that's a footnote, not the job.)
- **Not `/news-digest`.** news-digest tracks a persistent, dated, pruned corpus refreshed on a cadence.
  `/learn` has no corpus, no staleness model, no "new since last run" — it's a one-shot (AUTO) or a
  per-video-batch (FEED) technique extraction.
- **Not `/ingest-event`.** ingest-event documents event materials Douglas already holds (transcript PDFs,
  decks) into a people/topics/presentations note set. `/learn` FEED mode borrows its per-source extraction
  discipline but is lighter (no people/org fan-out, no canvas) and works on video URLs, not event folders.
- **Not `/groq-transcribe`.** groq-transcribe turns a Drive AUDIO FILE into a transcript. `/learn` may *reuse*
  its Whisper step as a last-resort fallback for a caption-less video, but `/learn`'s job is the learning
  synthesis on top, not the transcription.

## Modes

- **AUTO** (default): a topic in → a mined technique note out. Full search + ingest + synthesize.
- **FEED** (`--feed` + URLs, or Douglas pastes a list of videos): no search phase — ingest each supplied video
  and report the concrete teachings/adjustments. Built for handing over a watch-later backlog.

## Steps

### Step 0 — Resolve mode, subject, and the video-ingestion path

- **Mode + subject**: AUTO takes a topic; FEED takes the specific URLs Douglas supplies. If he pasted videos,
  it's FEED; if he named a topic, it's AUTO; if both, do FEED on the URLs and AUTO-augment with a search.
- **Transcript path — INSTALLED and verified on this machine (2026-07-14).** Invoke yt-dlp as a python module
  (the console script isn't on PATH): the python is
  `C:\Users\dmcgowa2\scoop\apps\python313\current\python.exe`.
  1. **Primary (captions):**
     `python -m yt_dlp --write-auto-sub --write-sub --sub-lang en --skip-download --sub-format vtt -o "<slug>.%(ext)s" "<url>"`
     → parse the `.vtt` (strip timestamps + dedupe repeated auto-caption lines). Covers ~all practitioner
     videos (verified working end-to-end).
  2. **Caption-less fallback (audio → Whisper):** `python -m yt_dlp -x --audio-format mp3 --ffmpeg-location
     "<ffmpeg>" -o "<slug>.%(ext)s" "<url>"` where `<ffmpeg>` comes from
     `python -c "import imageio_ffmpeg,sys; sys.stdout.write(imageio_ffmpeg.get_ffmpeg_exe())"` (imageio-ffmpeg
     is installed; scoop ffmpeg is NASA-MSI-blocked, so use this static binary), then feed the mp3 through the
     Whisper step of `/groq-transcribe` (reuse its transcription engine, not its Drive-search wrapper).
  3. YouTube-transcript MCP servers exist (hancengiz, jkawamoto, ergut, …) but the 2026-07-14 recon
     (`_ultraskill/learn-video-recon.md`) found every one strictly NARROWER than the yt-dlp path above (no
     audio fallback, no description/comments) and worse egress posture on a NASA machine — **do not adopt one**
     unless a future need clears that bar.
  - **Transcript is the cheap DEFAULT; a real vision pass is available when the value is visual.** Transcript
    mining reads what is SAID. When a video's value is SHOWN — a silent demo, a Figma canvas, on-screen
    numbers/UI, before/after design work — run the **optional vision pass (Step 3.6): frame-sample the video and
    feed the frames to a vision model**, which genuinely reads the screen (proven 2026-07-14: it read card
    values, tier-list priority placements, chart axes, and before/after states the transcript never mentioned).
    This is the ecosystem-standard "watch a video" approach (recon: `_ultraskill/watch-recon.md`). It's opt-in
    because of token cost, not a hard limit. **Three distinct jobs, don't conflate them:** transcript mining
    (Step 3, cheap, default), the vision pass (Step 3.6, opt-in, reads pixels), and illustrating the note with
    stills/diagrams (Step 4.5, for the reader).
  - **The one true remaining ceiling — NATIVE video.** No frontier Claude model accepts raw video as input yet
    (Anthropic feature request closed "not planned" as of the recon); Gemini does (and even it samples ~1fps
    under the hood). So "watching" here always means frame-sampling, never native-video comprehension — which
    is why the honesty tag below still holds.
  - Still **never claim "watched"** — every video-derived claim is tagged with its true source (auto-caption /
    manual captions / Whisper / **frame-sampled vision @<sec>s**). Frame-sampling is perception of sampled
    stills, not native-video comprehension — say "read from sampled frames," never "watched." If a future
    machine lacks yt-dlp, do NOT auto-install (env-mutation is gated):
    do the ARTICLE half in AUTO mode and, in FEED mode, surface the one-time `pip install yt-dlp imageio-ffmpeg`
    command in Douglas's own shell.

### Step 1 — GATE: is this actually a learn-a-craft task?

Classify before spending effort:
- A **factual/answerable question** ("what's the best charting library") → this is `/deep-search`, not `/learn`.
- An **adopt-this-tool decision** ("should I switch to Grafana") → this is `/recon`.
- A **learn-to-DO-it craft** ("get better at designing dashboards", "learn motion design") → proceed.
If it's a misfit, say so and route to the right skill rather than forcing a technique note out of a question.

### Step 2 — (AUTO only) Find the GOOD sources, not the generic ones

Reuse `/deep-search`'s human-source bias verbatim, sharpened for craft:
- Practitioner blogs and named voices in the niche; `site:reddit.com`, `site:news.ycombinator.com`,
  `site:lobste.rs` + topic; follow outbound links from the first genuinely good post (practitioners cross-link).
- Bias queries toward first-person confessional framing that SEO farms don't use: append `"what I learned"`,
  `"lessons learned"`, `"how I actually"`, `"postmortem"`, `intitle:"blog"`.
- YouTube: technical practitioner breakdowns, NOT ad-driven review/round-up channels. Prefer a named
  practitioner walking through their own real work over a high-view listicle video.
- De-prioritize SEO listicles, AI-generated summary sites, content farms.
- Verify a source is real before trusting it (render/fetch it; don't cite a link you haven't opened — the
  verify-links-before-sharing rule).

### Step 3 — Ingest each source (transcript-first for video; honest about it)

- **Articles**: `WebFetch` the real page; read the substance, not the chrome.
- **Videos**: pull the transcript via the Step-0 path (captions preferred; audio+Whisper only if caption-less).
  Also pull the description and, where useful, top comments (often the real Q&A). **Never say "watched."** Every
  video-derived claim is tagged with its true source: "auto-generated transcript" / "manual captions" /
  "Whisper transcription of the audio." **If the video's value is visual, add the optional vision pass (Step
  3.6) — it reads the on-screen content the transcript can't.**
- **Clean the `.vtt` first**: strip the WEBVTT header + cue timestamps and dedupe the rolling duplicated lines
  auto-captions emit (keep each spoken line once) — but keep a cue→timestamp map so a technique can be
  reattached to its nearest timestamp for the `?t=` link.
- **Long transcripts (90+ min lectures)**: chunk by token budget and extract per chunk, then merge — a single
  pass over a very long transcript silently drops the tail (Chapter-Llama / TDS long-video pattern). Short
  practitioner videos (the common case) need no chunking.
- **Fan out per source** (embedded Workflow below): one subagent per video/article extracts to a per-source
  analysis file on disk; only the distilled units return to the main context (keeps bulk out of the thread).

### Step 3.6 — Optional vision pass: "watch" the video (frame-sampling perception)

When a video's value is **visual** — silent demos, Figma/CAD canvases, on-screen numbers/UI, before/after
design work, diagrams — the transcript misses most of it. This pass reads the screen. **Opt-in** (token cost),
**transcript-guided** (run it on the visual-heavy or caption-sparse videos/segments, not every second of every
video). Built + proven 2026-07-14; prior-art recon in `_ultraskill/watch-recon.md`.

- **One command** (transcript-anchored by default), reusable scripts in `Claude NASA Folder\_ultraskill\`:
  `python watch_video.py <id|url> --from-transcript --frames-dir frames --out <notes>.md`
  `--from-transcript` is the **completeness method**: it scans the captions for visual-reference language
  ("you can see", "this card", "move it", "before/after", left/right/top) and screenshots *exactly those
  moments* — the narration is the index of where the visual value lives — with the scene-detect floor
  underneath catching cuts the narration never announces. (`--segments "90-210,..."` names spans by hand;
  omitting both walks `--seg-len` windows.) `--frames-dir` **persists the kept frames** so the illustrative
  ones can be embedded (Step 4.5). `watch_batch.py` runs it over a list of videos (resumable, skip-existing).
  Under the hood: pull transcript → **hybrid-sample keyframes** (ffmpeg scene-detect `thresh≈0.22` + uniform
  floor `≈12s` + temporal dedup + **512px** + per-window `cap≈14`) → interleave each timestamp-prefixed frame
  with the transcript window → **GEN vision** (`claude-opus-4-8`, image-capable — verified). Runs FOREGROUND
  (a backgrounded process gets no ffmpeg network to the stream host — verified: it pulls 0 frames).
- **Extract the craft DECISION via a topic-matched LENS, not the screen contents.** The transcript is the
  narrator's stated INTENT; the frame is the RESULT — read *how* it was executed, as a reusable lesson, and
  IGNORE incidental data (placeholder values, demo names, fake numbers). **The lens must match the video's
  craft** — a dashboard video and a motion video need different eyes. Set it with `--lens <preset>`
  (`dashboard`/`ui`/`motion`/`cad`/`code`/`typography`/`illustration`/`editing`), a free-text lens
  (`--lens "the exact tool panels and shortcuts used"`), or `--topic "<what the video is about>"` to
  **auto-generate** a craft-specific lens via one GEN call. Add `--teaches "<one line>"` to orient the pass.
  (Dashboard lens looks for hierarchy/color-roles/chart-choice; motion lens for easing/timing/choreography.)
  Units read `@<sec>s — <the lesson>`. (Prompt + lens presets live in `watch_segment.py`; re-aimed 2026-07-14
  from an OCR-shaped first pass — reading "$16,073.49" off a card is worthless; the lesson is "one accent
  reserved for the active series". Made topic-adaptive so /learn works on any craft, not just dashboards.)
- **Frame the pass by three questions, and read UNBIASED.** Before extracting, fix in mind: (1) what is THIS
  video trying to teach, (2) what is the purpose of the visual content on screen, (3) what does Douglas want
  to learn from it — then extract against *that*, not a generic checklist. Read each frame for what is
  ACTUALLY there; never force the template or report a decision the frame doesn't show — on a skeletal or
  off-topic frame (a sponsor tour, a transition slate) say "this frame doesn't show it" rather than inventing.
- **Why hybrid sampling** (not uniform, not pure scene-detect): screencasts change *gradually* (scrolling,
  typing), so pure scene-detect under-samples (measured: 4 cuts vs 35 at a small threshold change over the same
  2 min) — the uniform floor backstops it, dedup removes near-duplicates, 512px + cap keep tokens down.
- **Cost (measured):** ~**1.7k tokens per minute** of video on GEN (~340 tok / 512px frame); a 20-min video is
  ~35k tokens. Cheap enough for selected videos; still don't blanket-run it on a 20-video playlist.
- **Feed the design-decision units back into Step 4** as real technique units, each tagged `(visual,
  frame-sampled @<sec>s)` so provenance stays honest. Because `--frames-dir` kept the exact frame each unit was
  read from, the Step-4.5 embed is *that* frame — the one that demonstrably shows the point — not a re-hunted
  approximation. This is what makes the "every visual point has a demonstrating screenshot" rule cheap to keep.
- **Skip / say so** when the model can't read small on-screen text, or when a segment is just a talking head —
  never invent screen text you can't actually read (the don't-fabricate rule applies to pixels too).

### Step 4 — Extract technique UNITS, capturing the *why*, not just the *what*

For each source, pull discrete, actionable units — and specifically the reasoning behind a technique, not only
its name (craft-extraction research finds generic summarization drops exactly the force/timing/tension detail
that makes a technique usable — (De)composing Craft, arXiv 2506.10891). Each unit:
- states the technique as an imperative Douglas could act on,
- carries the *why* (when/why it applies, the failure it prevents),
- is traced to its source, and flagged `[single source]` where only one source backs it.
Never invent a technique a source didn't actually state (don't-fabricate).

**Extraction discipline (from Daniel Miessler's Fabric `extract_wisdom` — the canonical prior art for this
exact job):** pull a real minimum (≥5 units per substantive source when the content supports it — a floor
against lazy 1-2-bullet skims); do NOT start multiple units with the same words (forces genuinely distinct
techniques, not rephrasings); prefer the concrete over the generic. **For video, record an approximate
timestamp** (seconds, from the nearest transcript cue) with each unit so its citation becomes a clickable
`https://youtu.be/<id>?t=<seconds>` deep-link — this directly serves the "never re-watch to use it" goal.

### Step 4.5 — Illustrate the note (screenshots + diagrams), especially for visual crafts

A learn-note about anything visual (dashboards, UI, motion, layout, typography) is far more useful with pictures
next to the techniques. **Rule (not optional): every visual point in the note must be paired with an image that
actually demonstrates it** — a real frame that shows the technique in the wild, or, for a pure concept a frame
can't show cleanly, an authored diagram. A visual technique left text-only is an incomplete unit: find the frame
that shows it (the vision pass already saved it via `--frames-dir`) or author the diagram — don't skip it. The
image must genuinely show the claim (a "give the hero prominence" point needs a frame where one element clearly
dominates), not just sit nearby as decoration. Honesty bar is the same as the text: never embed an image you
haven't looked at, never imply you "watched." Two kinds:

- **Real frames from the source videos** — best pulled from *review/demo* videos where real product UI is on
  screen, not talking-head tutorials. Reusable tooling (built 2026-07-14, in `Claude NASA Folder\_ultraskill\`):
  - `contact_sheet.py jobs.json <out>` — for each anchor `{id, center, prefix, offsets}` it extracts a *window*
    of frames around the cited second and tiles them into one contact sheet. **This exists because transcript
    timestamps land on the moment a concept is SPOKEN, which is very often a transition slide, a talking head,
    or a different visual than the caption promises** (verified: a naive grab-at-timestamp hit ~1 in 3). Sample
    a window (default `[-6,0,6,12,18,24]`s; widen for build-alongs), then **view each SHEET and pick the one
    good frame** — the individual frames are saved as `<prefix>_<sec>.png`.
  - `grab_frames.py jobs.json <out>` — single frame per `{id,t,out}` once you know the exact good second.
  - Both use yt-dlp for a direct stream URL (no full download) + the imageio-ffmpeg static binary; no MSI.
  - **Vet every frame by actually reading the PNG.** Discard talking-heads, transition slides, and anything
    that doesn't illustrate the technique. Caption with the source video title + the (now frame-verified)
    timestamp. Do NOT reuse a transcript caption that describes a *different* moment than the frame shows.
- **Authored concept diagrams** — for pure concepts a frame can't show cleanly (type scale, spacing scale,
  color roles, grid, a picker matrix, a before/after), author a clean **SVG** (Obsidian renders SVG embeds
  inline). Follow the anti-AI-ism rules ([[feedback_frontend_ai_isms]]): one accent, real type scale, no
  gradient text, no decorative side-stripes; give each an explicit white background rect so it's legible in
  either Obsidian theme; keep captions inside the viewBox width or they clip. **Verify SVGs actually render**
  before embedding — compose an HTML index and screenshot it headless with Playwright (`_ultraskill\_shot.mjs`
  pattern: `createRequire` from `C:/Users/dmcgowa2/tools/nodejs/node_modules/` → `@playwright/test`; the in-app
  browser screenshot times out on this machine, [[feedback_screenshot_fallbacks]]).

Store images in `Claude\Learn\_attachments\` with unique `<topic>-`prefixed names; embed with `![[name]]` +
an italic caption line. **Before done, cross-check every `![[]]` resolves to a real file** (a quick script that
diffs the note's embeds against the folder). Add an "About the images" line to the note's provenance banner
distinguishing the two kinds (frame-verified stills vs. authored diagrams). Frames stay a personal-reference
use — keep the source attribution in every caption.

### Step 5 — Synthesize the note (stands alone from the sources)

Write it so Douglas never has to re-watch/re-read the source to use it — rephrase in his own applicable terms,
not pasted quotes (Zettelkasten discipline). Structure:

```markdown
---
tags: [learn, <topic-slug>]
type: learn-note
mode: auto | feed
researched: <date>
sources_provenance: <"N articles + M transcripts (K auto-caption, J Whisper); no video path available">
---
# Learning: <topic>

> Provenance banner. **About the images** (when the note has any, per Step 4.5): photographic frames are stills
> pulled from the cited videos and looked at before keeping (captioned source + frame-verified timestamp);
> diagrams are my own illustrations of the technique, from no video.

## Techniques (the how — with the why)   <!-- interleave frames + diagrams next to the technique each shows -->
## Do's / Don'ts
## Sources — with why each is good
## Skills / references worth adding to my harness   <!-- route any real build idea through /overlap first -->
## Concrete changes to apply to my own work          <!-- tie to an active project/file where possible -->
## Open questions / gaps                              <!-- mark [single source] where only 1 source covered it -->
```

### Step 6 — Write it where it lives, and report

Write to `NASA_GSFC_Vault_1\Claude\Learn\<topic>.md` (create the `Claude\Learn\` folder if absent; never
overwrite a prior note — version the filename). Report to chat: a short TL;DR of the top techniques, the
source-provenance line (how many articles vs transcripts, and which transcription method — so the honesty is
visible), and the full absolute path per the Files-list convention.

## Safety constraints

- **Never auto-install anything.** yt-dlp/pip is env-mutation-gated and is Douglas's explicit call — surface
  the command in his shell, never run it or route around the hook.
- **Never claim to have watched a video.** Transcript/description/comments only; state the true source on every
  video-derived claim.
- **Open web is fine for public/personal learning topics.** If a topic is NASA-internal/CUI, do NOT web-egress
  (the block-nasa-web-egress hook enforces this; don't test it) — a NASA-internal craft topic would be
  local-sources-only.
- Read-only except the vault note and the per-source analysis files; no commits.
- Keep bulk transcripts/articles out of the main thread — per-source subagents, summaries back, full text to
  disk.

## Workflow script (fan out per-source ingestion + extraction; synthesize once)

`args.mode` = 'auto'|'feed'; `args.sources` = `[{ kind:'video'|'article', url, note }]` (FEED: the supplied
URLs; AUTO: the sources found in Step 2); `args.topic`; `args.videoPath` = the resolved Step-0 capability
('yt-dlp'|'mcp'|'none').

```js
export const meta = {
  name: 'learn-run',
  description: 'Mine practitioner sources for craft technique: per-source ingest+extract -> synthesize a learn note',
  phases: [
    { title: 'Ingest' },
    { title: 'Synthesize' },
  ],
}

const TOPIC = args.topic
const MODE = args.mode || 'auto'
const SOURCES = args.sources || []
const VIDEO_PATH = args.videoPath || 'none'

const UNIT_SCHEMA = {
  type: 'object',
  properties: {
    source_url: { type: 'string' },
    source_kind: { type: 'string', enum: ['video', 'article'] },
    provenance: { type: 'string' },   // "auto-caption transcript" | "manual captions" | "whisper" | "article text"
    credible_why: { type: 'string' }, // why this source is worth trusting (track record / hands-on)
    techniques: { type: 'array', items: {
      type: 'object',
      properties: {
        technique: { type: 'string' },      // imperative Douglas can act on
        why: { type: 'string' },            // when/why it applies, the failure it prevents
        single_source: { type: 'boolean' },
      },
      required: ['technique', 'why'],
    } },
  },
  required: ['source_url', 'source_kind', 'provenance', 'techniques'],
}

// Phase 1 — one subagent per source: ingest (transcript-first for video) + extract technique units.
const perSource = await parallel(SOURCES.map(s => () =>
  agent(
    `${s.kind === 'video'
      ? `Ingest the YouTube video ${s.url} for topic "${TOPIC}". Use the ${VIDEO_PATH} transcript path ` +
        `(captions preferred; audio+Whisper only if caption-less). You are reading the TRANSCRIPT + ` +
        `description + top comments — you did NOT watch it; label provenance truthfully.`
      : `Fetch and read the article ${s.url} for topic "${TOPIC}".`} ` +
    `Extract discrete, actionable technique UNITS — capture the WHY behind each (when/why it applies, the ` +
    `failure it prevents), not just the name. Flag any unit only this source supports. Do NOT invent a ` +
    `technique the source didn't state. Save your full analysis to disk; return only the structured units.`,
    { phase: 'Ingest', schema: UNIT_SCHEMA, label: `${s.kind}:${(s.url || '').slice(-11)}` })
))
const units = perSource.filter(Boolean)

// Phase 2 — synthesize the standalone learn note from all extracted units.
const note = await agent(
  `Synthesize a standalone learn-note for "${TOPIC}" from these per-source technique units. Sections: ` +
  `Techniques (how + why) / Do's-Don'ts / Sources-with-why / Skills-references-to-add (route real build ` +
  `ideas through /overlap) / Concrete-changes-to-my-work / Open-questions (mark [single source]). Rephrase ` +
  `in Douglas's own applicable terms — the note must stand alone without re-reading the sources. Include the ` +
  `source-provenance line (article vs transcript counts + transcription method). No fabricated techniques.\n` +
  JSON.stringify(units),
  { phase: 'Synthesize', label: 'synthesize-note', model: 'opus' })

return { units, note }
```

## Final report — honest register

Report what was actually mined: how many articles vs transcripts, and for videos the true transcription method
(so "I read the auto-caption transcript" is never dressed up as "I watched it"). Name what's `[single source]`
or unverified. If the video path was unavailable, say the note is article-only and give the one-time
enablement command. Banned: "comprehensive", "everything you need to know", "mastered" — a learn note is the
techniques found in the sources read this pass, and Douglas extends it as he learns more.

---

*Tracked copy: also save this file to `claude-global-config/commands/learn.md` (per the skills-are-tracked
convention) after a NASA scrub.*
