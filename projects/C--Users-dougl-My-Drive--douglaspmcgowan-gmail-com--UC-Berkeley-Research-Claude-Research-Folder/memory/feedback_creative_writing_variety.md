---
name: Offer varied options for creative writing
description: For taglines/naming/copy/voice-driven prose, default to 5-10 varied options across tones rather than one best-effort draft
type: feedback
originSessionId: 5e350b40-10f3-4b8b-8c78-4a709aebdb61
---
For taglines, naming, marketing copy, product names, slogans, blog titles, or any prose where voice and tone matter more than factual correctness: default to offering 5–10 varied options across different tones (e.g. playful, serious, absurd, minimal, technical). Do not return a single best-effort draft unless the user explicitly asked for one. If no tone or constraint was given, ask briefly before drafting.

**Why:** Opus 4.7 is tuned toward literal, precise output and tends to produce flat, safe prose on creative tasks that 4.6 used to handle with more voice. Offering a spread of varied options lets the user pick and remix rather than edit a flat draft — this recovers most of the creative-writing regression in 4.7.

**How to apply:** Triggers on requests for taglines, names, slogans, marketing/product copy, blog/post titles, social captions, or any short prose where voice matters. Does NOT apply to: code comments, technical documentation, factual summaries, academic writing, or any task where precision beats personality.
