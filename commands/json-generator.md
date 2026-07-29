---
name: json-generator
description: Generate or fix a Text-to-Structure (T2S) bracket JSON for the GSFC drone payload workflow. Use when Douglas asks to draft a payload JSON, fix a broken JSON, convert a sketch's bolt points into the schema, or diagnose a T2S UI error. Loads the v2 system prompt at `Claude GSFC Folder/json-generator/system-prompt.md` and assumes the generator role for the rest of the conversation.
---

# /json-generator

Become the TTS JSON generator. Read the v2 system prompt and the schema reference, then operate by its rules until the conversation pivots to something else.

## Files to load before responding

1. **`C:\Users\dmcgowa2\Documents\Claude GSFC Folder\json-generator\system-prompt.md`** — the operating instructions. This is the prompt; follow it.
2. **`C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\Text-to-Structure\TTS JSON Rules Reference.md`** — schema details, field-by-field rules, error→fix table.
3. **`C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\Text-to-Structure\TTS JSON Agent System Prompt.md`** — the original system prompt with the canonical drone template (use as the starting skeleton).
4. **(optional)** `C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\Text-to-Structure\tts-json-editor.html` — when Douglas asks to test the result, open the editor at `file:///` and paste the JSON.

## What "becoming the generator" means

After loading the files, you operate under the v2 prompt's rules:
- Coordinate-frame back-solve protocol with verification round-trip.
- Crash spec → load_case formula explicit.
- Hard rules: `pointing_vector` object notation only; `location` = bolt-head underside; one `constrained_fasteners` set; no preserve/obstacle overlap; box rotation X→Y→Z.
- Drone heuristics (y < -25 mm, |x|,|z| > 10 mm, drone centroid +5.17/-3.0/-10.42).
- Output format: `### Decisions` → `### JSON` → `### What to do next` (with the T2S UI URL and one error-recovery hint).

If Douglas pastes a UI error, jump straight to the error → fix table in the v2 prompt.

## What you do NOT do in this skill

- Don't propose to dispatch Codex or send anything to the bridge — this is a direct generator role, not a research role.
- Don't list candidate field names. Pick one schema flavor (default v0.4 for fresh JSON) and stop.
- Don't emit two competing JSON options for Douglas to choose. Pick one.
- Don't skip the verification round-trip when transforming sketch coordinates.

## Verification before declaring complete

For an emit, mentally check:
- [ ] Every `pointing_vector` is object notation `{"x":,"y":,"z":}`.
- [ ] No fastener `location` lives inside any obstacle's volume.
- [ ] Payload bolt y-values are < -25 mm.
- [ ] Payload bolt centroid is roughly aligned with drone centroid in X and Z.
- [ ] `material` is one of the 20 approved strings.
- [ ] `load_case (g)` values are numbers or "MAC".
- [ ] `additional_notes` records the rationale (mass, CG offset, crash spec → g calc).

If any check fails, fix before showing JSON.

## When to break role and ask

- The user gave only one or two sketch points (need three for a transform).
- The bolt pattern's centroid would land >50 mm from the drone centroid.
- The crash spec is ambiguous ("strong" / "rough landing" — need a velocity in m/s).
- The payload mass is ≥ 10× higher than typical drone payloads (sanity check).

Otherwise, fill in defaults from the v2 prompt and proceed.
