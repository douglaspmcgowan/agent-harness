---
name: groq-transcribe
description: Download the most recent audio file from Google Drive, transcribe it with Groq Whisper, auto-format the transcript, and trim anything after the speaker shifts to personal thoughts/feelings. Requires GROQ_API_KEY in environment.
---

# /groq-transcribe

Transcribe the most recent audio file from Google Drive using Groq's Whisper API, clean up the formatting, and cut everything after the speaker starts talking about their own personal thoughts and feelings.

---

## Step 1 — Find the most recent audio file in Google Drive

Use the `mcp__8d2261a9-765d-4f08-91c9-a312ae9d3457__search_files` tool with query:
```
mimeType contains 'audio/'
```
Set `pageSize` to 5 and `excludeContentSnippets` to true. Sort is by recency by default. Take the first result (most recent file). Note its `id`, `title`, and `fileSize`.

---

## Step 2 — Download the audio file

Use `mcp__8d2261a9-765d-4f08-91c9-a312ae9d3457__download_file_content` with the file's `id`. This returns base64-encoded audio content.

Decode and save the file to a temp path:
```bash
# The MCP returns base64 content — decode it to a local temp file
echo "<base64_content>" | base64 -d > /tmp/groq_audio_input.wav
```

---

## Step 3 — Send to Groq Whisper API

Check that `GROQ_API_KEY` is set:
```bash
printenv GROQ_API_KEY > /dev/null 2>&1 && echo "KEY FOUND" || echo "ERROR: GROQ_API_KEY not set — add it to ~/.claude/settings.json under env"
```

Send to Groq using `whisper-large-v3-turbo` (fastest, near-identical accuracy):
```bash
curl -s https://api.groq.com/openai/v1/audio/transcriptions \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -F model="whisper-large-v3-turbo" \
  -F file="@/tmp/groq_audio_input.wav" \
  -F response_format="verbose_json" \
  -F language="en"
```

Parse the `text` field from the JSON response. This is the raw transcript.

---

## Step 4 — Format the transcript

Apply these formatting rules to the raw transcript:

1. **Sentence boundaries**: Break into proper sentences with correct capitalization and punctuation.
2. **Paragraph breaks**: Group related ideas into paragraphs (every 3–5 sentences or at natural topic shifts).
3. **Remove filler words**: Strip "um", "uh", "like", "you know", "sort of", "kind of" where they don't add meaning.
4. **Fix run-ons**: Split run-on sentences at natural clause boundaries.
5. **Preserve content**: Do not paraphrase, summarize, or change meaning — only clean up delivery artifacts.

---

## Step 5 — Output

Print the final formatted transcript. Add a one-line note at the end indicating:
- File transcribed (title + date)
- Word count of final transcript

---

## Notes

- Groq free tier: 2,000 requests/day, 7,200 audio seconds/hour, 25 MB max file size
- Model: `whisper-large-v3-turbo` (228× real-time, ~8.4% WER, best for clean speech)
- If file exceeds 25 MB, use `whisper-large-v3` (100 MB limit on paid tier) or split the audio
- GROQ_API_KEY must be set in `~/.claude/settings.json` under the `env` key
