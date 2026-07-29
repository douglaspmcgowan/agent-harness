---
name: gallery
description: "Generate a gallery of design options and push them into the Decide side of the Workbench for Douglas to preview, pick, and annotate. Given a design brief, it fans out the GEN API for N self-contained HTML design variants (reusing the Decide app's own gen.js engine — claude-opus-4-8, 1–8 variants, tight/balanced/divergent diversity), writes each variant into the decisions previews/ folder, and enqueues an option-select decision item via the shared enqueue core (lib/enqueue.js). The Decide side then renders each variant as a live sandboxed-iframe preview with Expand / Pick / Regenerate / note. This is the routing consumer of the workbench CLI for visual-design decisions. Use when Douglas says 'generate design options', 'make me a gallery of options for X', 'design options for X', 'give me N variations of this UI/layout/page', 'option gallery', or '/gallery'. NOT for a plain approve/reject (that is a Review item) or a text tradeoff/reasoning decision (that is a decision-server type via `workbench decide add`)."
---

# /gallery [design brief] [--n 3] [--diversity balanced] [--title T] [--mock]

A design decision is easier to make when you can see the options side by side and live, rather than imagine
them from a description. This skill turns a design brief into a gallery of N real, self-contained HTML variants
generated on GEN, and drops them into the **Decide** side of the Workbench (http://127.0.0.1:8471/decide) as an
`option-select` decision — where each variant renders in its own sandboxed iframe with **Expand**, **Pick**, a
**Regenerate** control, and an optional note. It is the visual-design sister of the reviewer: instead of
approve/reject, it is choose-among-rendered-options.

## What it is NOT

- **Not a Review item.** A plain approve / reject / edit / answer belongs on the Review side (`workbench review
  add`). Reach for `/gallery` only when the decision is *choosing among visual options*.
- **Not a text decision.** A tradeoff table, reversibility call, reasoning tree, diff, or critique is a
  decision-server type pushed with `workbench decide add`. `/gallery` is specifically the option-select /
  variant-preview flow.
- **Not the in-app Generate button.** The Decide UI's own "✦ Generate options" button hits the server's
  same-origin, CSRF-gated `/api/generate`. `/gallery` is the CLI/agent path: it reuses the same `gen.js`
  engine and the shared enqueue core directly, so it works from any shell, subagent, or GEN session without
  weakening that gate.

## Procedure

1. **Resolve the brief.** Establish the design problem to generate for (the prompt), and pick sensible values
   for `--n` (default 3, bounded 1–8) and `--diversity` (`tight` | `balanced` | `divergent`, default
   `balanced`). A `--title` is optional (defaults to the first ~80 chars of the brief). If Douglas gave a clear
   brief, proceed; if it is a one-word ask, state your working interpretation in one line and generate.
2. **Run the engine** (node by absolute path on this machine — the Bash tool's PATH is broken here):

   ```
   C:/Users/dmcgowa2/tools/nodejs/node.exe "C:/Users/dmcgowa2/Documents/Claude NASA Folder/bin/gallery-gen.js" --prompt "<brief>" --n 3 --diversity balanced --json
   ```

   - Long or structured briefs: write the brief to a temp `.json` (`{prompt, title?, n?, diversity?, source?,
     blocking?}`) and pass `--file <path>`, or pipe it on stdin with `--stdin`.
   - `--source "<name>"` groups the item into a named set on the Decide hub (default `Gallery`).
   - `--blocking` marks it a blocking decision.
   - `--mock` skips GEN and emits N placeholder variants — use it only to exercise the pipeline without
     spending GEN, never for a real design ask.
   - Exit codes: `0` success (prints the decision id; with `--json`, `{id,file,variants,failed,previews}`),
     `2` usage error, `1` runtime error (generation failed, I/O, validation).
3. **Report the result.** Give Douglas the decision id and the URL to view it:
   **http://127.0.0.1:8471/decide** → the **Gallery** set (or the `--source` set you named). If `failed > 0`,
   say how many variants GEN dropped. If the server is not running, tell him to start it with
   `node server.js` from `C:\Users\dmcgowa2\Documents\Claude NASA Folder` (port 8471).

## Requirements & constraints

- **GEN credentials** — `gen.js` reads `GEN_API_KEY` + `GEN_BASE_URL` from the environment (never logged, never
  written to disk). If they are unset, `gallery-gen` exits `1` with `credentials not configured`; surface that
  plainly rather than retrying.
- **NASA / GEN policy** — GEN is for NASA-work and public design generation with no live-web dependency (per
  DELEGATE.md). A personal / non-work design ask uses the same engine but is a normal generation, not a policy
  concern. Nothing in this flow sends content to the open web.
- **Zero new dependencies** — the engine is `bin/gallery-gen.js` over `decision-app/gen.js` + `lib/enqueue.js`.
  Do not add a package or a second generation path.

## Wiring (where this lives)

- Engine: `C:\Users\dmcgowa2\Documents\Claude NASA Folder\bin\gallery-gen.js`
- Reuses: `decision-app/gen.js` (GEN fan-out) + `lib/enqueue.js` (shared enqueue core, atomic write into
  `~/.decisions/incoming/`).
- Surfaces on: the Decide side of the unified Workbench (`server.js`, :8471, `/decide`).
