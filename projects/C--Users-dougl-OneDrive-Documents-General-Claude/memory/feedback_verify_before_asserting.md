---
name: Verify before asserting — search first
description: Must WebSearch before answering any factual question about tools, products, specs, or features that could have changed since training
type: feedback
originSessionId: c13fd098-2b6d-4d92-a1d7-3b34da85692c
---
Search before asserting any fact about tools, products, features, versions, or capabilities — especially Claude Code itself. Do not answer from memory and then search only after the user calls it out.

**Why:** CLAUDE.md explicitly requires WebSearch/WebFetch before asserting anything that could have changed since the knowledge cutoff. Doug has flagged this failure multiple times. The failure mode is answering confidently from stale training data, then correcting after being challenged.

**How to apply:** The moment a question involves a specific product feature, version, capability, or anything time-sensitive — stop, search, then answer. This applies even for questions about Claude Code and Anthropic products, where training data may be months behind the current state.
