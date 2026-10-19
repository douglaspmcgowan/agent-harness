# Prose writing guide

This guide covers prose an agent writes for a human reader: docs, READMEs, briefs, reports, status pages and chat. Prose Douglas will publish or send in his own name also follows the vault's `Codex\voice.md`, which wins where the two disagree.

Most rules below exist because current models drift toward them by default. Sources are listed at the end. Where a rule is a house judgment and no study backs it, the rule says so.

## Directness and jargon

- Say the thing. Lead with the answer, the finding or the instruction, then give the reason.
- Use the precise term. When a reader may not know it, define it in a clause the first time it appears ("a worktree, a second checkout of the same repository"), then use it without apology.
- Don't swap a precise term for a vague friendly one. "Fewer moving parts" is worse than "two services instead of five."
- Name sources, numbers, dates, paths and people. "Some users report" becomes "three issues on #53454 report."
- Take a position when you have one. "While X, Y may also be true" balancing is a model default, not caution.

## Headings

Nobody has published a controlled study of AI-written versus human-written headings. The rules here combine professional style guides, the Wikipedia AI Cleanup project's observations, and patterns seen in this harness's own output.

**Write labels.** A heading names the topic so a scanning reader can find it. Put the key noun first. Good: `Hardware`, `Workbench and camera views`, `Install the driver`, `Known issues`.

- Concept sections get noun phrases: `Camera coverage`, `Data retention`.
- Task sections get a bare imperative verb: `Calibrate the camera`. Avoid a leading `-ing` form ("Calibrating the camera").
- Follow the document's existing case convention. Sentence case is the default (Google, Python docs); a document already in Title Case stays in Title Case.
- One H1 per page. Don't repeat the page title as the first heading. Don't skip heading levels. Don't add a heading that holds only subheadings.

**Avoid these patterns, which read as generated:**

| Pattern | Example | Use instead |
|---|---|---|
| Meta-label describing the section's job | `What this is`, `How this works`, `What this looks like`, `Why it matters`, `The short version` | Name the topic: `Overview` only if nothing better exists, otherwise `Lab hardware`, `Capture pipeline` |
| Deictic `this`/`it` in a heading | `How this works` | The noun `this` stands for |
| Wh-clause headings in a row | `What X is`, `How Y works`, `Why Z matters` | Mix in noun labels; most sections need none of these |
| Coined, cute or metaphorical phrase | `The bench and what can see what`, `The load-bearing part` | `Workbench and camera views` |
| Claim or punchline stuffed into a heading | `Hardware: one bench, two cameras`, `The left bench is a blind spot` | Put the claim in the first sentence under a plain label |
| Formulaic pairs and closers | `Awards and recognition`, `Challenges and future directions`, `Key takeaways`, `Conclusion` | Only when the content is really that |
| Every heading built on one template | four `What/How` headings in one doc | Vary by content; a short doc may need no headings |

Test: read only the headings. They should work as a table of contents a stranger could navigate. They should not read as a sequence of teasers.

## Sentences

- Prefer verbs to nominalizations. "We migrated the database and logins failed less often" beats "The implementation of the database migration resulted in a reduction in authentication failures." Instruction-tuned models use nominalizations at 1.5–2× the human rate (Reinhart et al.).
- Cut trailing participle clauses that add commentary: "…, highlighting the need for…", "…, underscoring its importance." Models use present-participle clauses at 2–5× the human rate.
- Vary sentence length on purpose. A run of sentences of the same length is a tell. So is a run of short declarative fragments.
- Punctuate like a person. Commas, semicolons and parentheses are fine; models now underuse them and chain clauses with "and" instead (Economist, 2026).
- Don't write "it is not X, it is Y", "not just X but Y", or the reversed "Y rather than X" as rhetoric. State Y.
- Replace a bare "this" or "it" at the start of a sentence with its noun.

## Words and phrases

Vocabulary tells rotate with each model generation. Removing one tell tends to bring in the next, so treat this list as an example set. A banlist is no substitute for specific content.

- Announcers and value tags: `this matters`, `here's the thing`, `here's where it gets interesting`, `the key insight`, `the honest answer`, `it's worth noting`, `let's break it down`.
- Current tic words: `load-bearing`, `genuinely`, `quietly`, `crucially`, `fundamentally`, `seamless`, `robust`, `leverage`, `multifaceted`.
- Older tic words: `delve`, `tapestry`, `testament`, `showcasing`, `fostering`, `underscore`, `pivotal`, `realm`, `meticulous`, `commendable`, `intricate`.
- Staccato rhythm like `No X. No Y. Just Z.`
- Summary closers that repeat the paragraph: `In short, …`, `Ultimately, …`, `By doing X, we achieve Y.`

## Paragraphs, lists and formatting

- Use a paragraph when ideas depend on each other. Save bullets for parallel, independent items.
- Avoid bold-term lists (`**Term:** explanation`) unless the content is a glossary.
- Bold only what a skimmer must not miss, at most a few times per page.
- Give space in proportion to difficulty. Uniform coverage of easy and hard parts reads as generated.
- End a section when the content ends. Don't add a recap.

## Checks before handing prose over

1. Read the headings alone. Each one should name a topic. If one describes what the section does, rewrite it.
2. Search the draft for the phrases above, and for `this` at the start of a sentence or heading.
3. Read a paragraph aloud. Fix it if the rhythm is even or it says little.
4. Check that every claim carries a name, a number or a source.
5. For a measured comparison against Douglas's own writing, run `/voice`; the script behind it is `commands/attune-stylometry.py`.

## Sources

- Wikipedia, *Signs of AI writing* (WikiProject AI Cleanup): https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing
- Google developer documentation style guide, *Headings*: https://developers.google.com/style/headings
- Reinhart et al., *Do LLMs write like humans?*, PNAS 2025: https://www.pnas.org/doi/10.1073/pnas.2422455122
- Kobak et al., *Delving into LLM-assisted writing in biomedical publications through excess vocabulary*: https://arxiv.org/abs/2406.07016
- Liang et al., *Monitoring AI-Modified Content at Scale*, ICML 2024: https://arxiv.org/abs/2403.07183
- Juzek and Ward, *Why does ChatGPT "delve" so much?*, COLING 2025: https://arxiv.org/abs/2412.11385
- Paech et al., *Antislop*, ICLR 2026: https://arxiv.org/abs/2510.15061
- Shreya Shankar, *Writing in the age of LLMs*: https://www.sh-reya.com/blog/ai-writing/
- Graphite study, reported by Gizmodo (2026-10-02): https://gizmodo.com/this-matters-researchers-identify-thousands-of-new-tells-in-ai-writing-2000820447
- Economist study, reported by Daring Fireball (2026-08-11): https://daringfireball.net/linked/2026/08/11/economist-ai-writing
- Claudisms banlist: https://claudisms.ai/
