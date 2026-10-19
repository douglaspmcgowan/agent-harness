# Heading guide

This guide covers headings in docs, READMEs, briefs, reports and status pages. `WRITING.md` covers the prose under them.

No published study compares AI-written and human-written headings directly. These rules combine the Google developer documentation style guide, the Wikipedia AI Cleanup project's observations, usability guidance on scanning, and patterns seen in this harness's own output. The last group is marked as a house judgment.

## Rules

1. **A heading is a label.** It names the topic so a scanning reader can find it. It is not a teaser, a summary, or a claim.
2. **Key noun first.** Readers scan the first two or three words. `Camera coverage` beats `Notes on what the cameras cover`.
3. **Two shapes cover almost everything:**
   - Concept or reference sections: a noun phrase. `Hardware`, `Data retention`, `Known issues`.
   - Task sections: a bare imperative verb. `Install the driver`, `Calibrate the camera`.
4. **No leading `-ing` form.** `Configure logging` beats `Configuring logging`. Standing nouns like `Billing` and `Pricing` are fine.
5. **Short.** One to five words is normal. Seven is long.
6. **Match the document's case.** Sentence case is the default. A document already in Title Case stays in Title Case. An ampersand is fine in a short label (`Workbench & Camera Views`).
7. **Structure.** One H1 per page. Don't repeat the page title as the first heading. Don't skip levels. Don't add a heading that holds only subheadings. Don't number headings unless order matters.
8. **Fewer headings.** A page under about 300 words rarely needs any. A section of one or two sentences usually belongs in the section before it.

## Patterns that read as generated

Wikipedia AI Cleanup and the Google style guide document the first four. The rest are a house judgment from 2026 model output in this harness.

| Pattern | Bad | Good |
|---|---|---|
| Title repeated as first heading | `# Snapdate` then `## Snapdate` | `# Snapdate` then the first paragraph |
| Stock pairs and closers | `Awards and recognition`, `Challenges and future directions`, `Key takeaways` | Name the actual content: `Prizes`, `Open problems` |
| Leading `-ing` | `Getting started`, `Understanding the config` | `Install`, `Configuration` |
| Empty parent heading | `## Setup` holding only `### Install` and `### Configure` | Promote the children or add text under the parent |
| Meta-label describing the section's job | `What this is`, `How this works`, `What this looks like`, `Why it matters`, `The short version` | `Overview` (only if nothing better exists), `Lab hardware`, `Capture pipeline` |
| Deictic `this` or `it` | `How it works`, `Why this exists` | The noun it stands for: `Capture pipeline`, `Motivation` |
| Wh-clause headings in sequence | `What X is` / `How Y works` / `Why Z matters` | Noun labels: `X`, `Y internals`, `Z tradeoffs` |
| Coined or metaphorical phrase | `The bench and what can see what`, `The load-bearing part`, `Where the bodies are buried` | `Workbench and camera views`, `Core module`, `Known issues` |
| Claim or punchline in the heading | `Hardware: one bench, two cameras`, `The left bench is a blind spot` | `Hardware`, with the claim in the first sentence below it |
| Colon subtitles | `Storage: why we chose SQLite` | `Storage`, with the reason below |
| Question headings used as hooks | `So what actually happens?` | `Request lifecycle` |
| Every heading built on one template | four `What/How` headings in one doc | Mix noun and verb labels according to content |

## Worked examples

| Bad | Good |
|---|---|
| What this lab is | Overview, or the lab's name |
| The bench and what can see what | Workbench and camera views |
| What this looks like | Screenshots, or Example output |
| How this works | Architecture, or Capture pipeline |
| Why it matters | Motivation, or cut it |
| Getting started with Snapdate | Install |
| Understanding configuration options | Configuration |
| Hardware: one bench, two cameras | Hardware |
| The honest version | Limitations |
| Where things stand | Status |
| What's next | Next steps, or Roadmap |
| The one thing to know before you run it | Prerequisites, or Warning |
| Key takeaways | cut it; the summary goes in the first paragraph |
| Challenges and future directions | Open problems |
| A note on safety | Safety |

## Check

Read the headings alone, top to bottom. They should work as a table of contents a stranger could navigate. If one only makes sense after reading its section, or describes what the section does instead of naming what it covers, rewrite it.

## Sources

- Google developer documentation style guide, *Headings*: https://developers.google.com/style/headings
- Wikipedia, *Signs of AI writing*, formatting section: https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing
- Loranger, *Headings are pick-up lines* (Nielsen Norman Group), on front-loading keywords for scanners: https://www.nngroup.com/articles/headings-pickup-lines/
