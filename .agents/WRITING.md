# Prose writing guide

This guide covers prose an agent writes for a human reader: docs, READMEs, briefs, reports, status pages and chat. Prose Douglas will publish or send in his own name also follows the vault's `Codex\voice.md`, which wins where the two disagree.

Most rules below exist because current models drift toward them by default. Sources are listed at the end. Where a rule is a house judgment and no study backs it, the rule says so.

**Evidence status (checked 2026-10-19).** Each rule was checked against 12 pieces each from Claude Opus, Sonnet and Haiku 5.5 and an equal-size human sample (Brown corpus). The human sample is 1960s news and essays and the model prompts were casual, so genre explains part of every gap.
- **Confirmed on 5.5:** very few semicolons and parentheses (0.2–0.8 per 1,000 words against 3.3 for humans); more colons (1.8–5.5 against 1.7); shorter, more uniform sentences (spread 9.2–9.6 words against 12.4); `quiet` and `here's`; the same openings across models; pieces clustered tightly (rarity percentile 0.35–0.47 against 0.82 for human pieces).
- **Not reproduced on 5.5:** noun-heavy prose (models used about half the human nominalization rate), low vocabulary variety (MTLD was higher than human), "and" chaining, and repeated sentence frames for Opus and Sonnet (12–15% of sentences against 31% human; Haiku 33%). Those rules came from 2023–2025 models. Keep them as readability preferences, not as AI tells.
- **Obsolete as a tell:** em dashes. None of the three 5.5 models used one in 12,000 words. Douglas's own em-dash ban still applies in `/voice`.

## Directness and jargon

- Say the thing. Lead with the answer, the finding or the instruction, then give the reason.
- Use the precise term. When a reader may not know it, define it in a clause the first time it appears ("a worktree, a second checkout of the same repository"), then use it without apology.
- Don't swap a precise term for a vague friendly one. "Fewer moving parts" is worse than "two services instead of five."
- Name sources, numbers, dates, paths and people. "Some users report" becomes "three issues on #53454 report."
- Take a position when you have one. "While X, Y may also be true" balancing is a model default, not caution.

## Headings

Follow `HEADINGS.md`. In short, a heading is a topic label (`Hardware`, `Workbench and camera views`, `Install the driver`). It is not a meta-label like "How this works", a coined phrase, or a claim.

## Sentences

- Prefer verbs to nominalizations (a readability rule; the AI-tell evidence is from 2024 models). "We migrated the database and logins failed less often" beats "The implementation of the database migration resulted in a reduction in authentication failures." Reinhart et al. measured 1.5–2× the human rate in GPT-4o and Llama 3; the 5.5 samples did not show it.
- Cut trailing participle clauses that add commentary: "…, highlighting the need for…", "…, underscoring its importance." Reinhart et al. measured 2–5× the human rate; the 5.5 samples ran 1.3–2× (2.3–3.8 per 100 sentences against 1.8).
- Vary sentence length on purpose. A run of sentences of the same length is a tell. So is a run of short declarative fragments.
- Use semicolons and parentheses. Join two closely linked clauses with a semicolon instead of "and" or a full stop; put a real aside (a unit, an exception, a source) in parentheses. Current models almost never use either (Economist, 2026; Gude et al., 2026; the 5.5 check above).
- Don't write "it is not X, it is Y", "not just X but Y", or the reversed "Y rather than X" as rhetoric. State Y.
- Replace a bare "this" or "it" at the start of a sentence with its noun.

## Words and phrases

**Banned outright (Douglas, 2026-10-19):** `here's` in any use ("here's the thing", "here's how", "here's what I found") and `quietly`. Rewrite the sentence so neither is needed.

Vocabulary tells rotate with each model generation. Removing one tell tends to bring in the next, so treat this list as an example set. A banlist is no substitute for specific content.

- Announcers and value tags: `this matters`, `here's the thing`, `here's where it gets interesting`, `the key insight`, `the honest answer`, `it's worth noting`, `let's break it down`.
- Current tic words: `load-bearing`, `genuinely`, `quiet` used as mood ("the gulls had gone quiet"), `crucially`, `fundamentally`, `seamless`, `robust`, `leverage`, `multifaceted`.
- Older tic words (2023–2025 models; mostly gone from current output): `delve`, `tapestry`, `testament`, `showcasing`, `fostering`, `underscore`, `pivotal`, `realm`, `meticulous`, `commendable`, `intricate`.
- Staccato rhythm like `No X. No Y. Just Z.`
- Summary closers that repeat the paragraph: `In short, …`, `Ultimately, …`, `By doing X, we achieve Y.`

## Paragraphs, lists and formatting

- Use a paragraph when ideas depend on each other. Save bullets for parallel, independent items.
- Avoid bold-term lists (`**Term:** explanation`) unless the content is a glossary.
- Bold only what a skimmer must not miss, at most a few times per page.
- Give space in proportion to difficulty. Uniform coverage of easy and hard parts reads as generated.
- End a section when the content ends. Don't add a recap.

## Structure and argument

Detectors now separate AI from human writing by structure as well as wording. Structural features alone flag AI-written business posts at 97% accuracy, even after rewording (SlopShape, 2026). Plot features flag AI stories at 93% (StoryScope, 2026).

- Don't announce the structure ("In this post, we'll cover three fixes…") and don't close by restating the thesis. Both are the strongest AI-leaning features in SlopShape.
- Don't frame the subject against "the old way" or as "next-generation." Use specific dates and history instead.
- Prefer the concrete, topic-specific argument over the safe general one. In public-debate essays, 65% of human main arguments were unique within a debate, against 3% of LLM arguments (Argument Collapse, 2026).
- Let the shape follow the material. A tidy single-track arc that over-explains its theme is the default AI story and essay shape.
### Default paths to avoid

Current models take these paths by default and people usually don't. When a draft follows one, pick a different route on purpose.

| Default path | Example from current models | A route people take more often |
|---|---|---|
| Thesis, then support, then a policy proposal | Essays that close on "employers should pair each new hire with a mentor". In public-debate essays, 29% of LLM support passages led straight into a proposal, against 12% of human ones. | Stay with the evidence; close on a consequence, a case or an open question |
| Concede, then pivot to a middle position | "Basic hygiene matters, but Americans should abandon the neurotic pursuit of total sterility" (all five models in one debate) | Commit to one side, or argue a position nobody in the room is taking |
| Close on "it depends" | "Remote work is not good or bad for junior employees in the abstract. It is good when…" (Haiku 5.5) | Say which way it usually goes and why |
| Generic authority instead of a case | "Research indicates…", "experts note…" | Name the study, the case, the date: "the Hurricane Sandy flood studies" |
| Abstract concept as the argument | "Security failures create significant externalities…" | Show one concrete instance and let the concept follow |
| Everyone reaches for the same supporting example | All three 5.5 models argued that remote juniors miss overhearing a senior colleague on a call | Use the example only you would think of: your own experience, a specific number, an odd case |
| The same opening frame | "The first [thing/week/month] I…" (all three 5.5 personal essays); "The storm had…" (two of three stories) | Open mid-scene, on a detail, or on the claim itself |
| Announce the structure, then restate it at the end | "In this post, we'll cover three fixes…", then a summary conclusion | Start with the first point; stop when the last one is made |
| Old way against new way | "Unlike legacy approaches, next-generation…" | Give the actual history with dates |
| Tidy single-track story with flat escalation | One plot line, the theme explained outright, tension that never rises (Claude's StoryScope fingerprint) | Subplots, unexplained motives, rising stakes, moral ambiguity, time jumps |

Sources: Argument Collapse (2026), SlopShape (2026), StoryScope (2026), and the 2026-10-19 Claude 5.5 sample check.

- When revising someone's draft, keep their pronouns, contractions, examples and stance. LLM revision strips first-person pronouns and contractions, adds longer words, and nudges claims toward neutral even under "grammar only" prompts (van Nuenen, 2026; "How LLMs distort our written language", 2026).

## Research papers and technical writing

Academic prose has different human norms, so some rules above relax and others tighten.

- **Nouns and passives are normal here.** Human academic writing is itself noun-heavy and uses the passive. Keep the technical nouns; cut only stacked nominalizations where a verb reads cleaner ("we measured X" over "the measurement of X was performed"). Judge against a corpus of papers in the same field, not against casual prose.
- **Hedge to the evidence.** Calibrated hedging ("suggests", "in our sample") is correct in a paper. The tell is uniform hedging on every claim, or no hedging on a weak one.
- **Watch the documented paper vocabulary.** Abstract and review studies found these words rose sharply after 2023: `delve`, `intricate`, `meticulous`, `commendable`, `notably`, `comprehensive`, `pivotal`, `underscore`, `showcase`, `landscape`, `shed light on`, `pave the way` (Kobak et al.; Liang et al.).
- **Cut value framing and contribution signalling.** Phrases like "a novel and comprehensive framework" and "significantly advances the field" grew fastest in PubMed abstracts from 2018 to 2025. State what the method does and the measured result.
- **Keep vocabulary varied and words short where possible.** LLM-edited papers from 2020–2024 use longer words and fewer distinct words than the originals (Miletić and Falk, LREC 2026); unverified on current models.
- **Don't over-signpost.** Skip "In this section, we…" openers and end-of-section recaps; the heading already says where the reader is.
- **Every citation must exist.** Check each reference against its DOI or arXiv ID. Fabricated or mangled citations are the most damaging tell in a paper.

## Checks before handing prose over

1. Run the check in `HEADINGS.md`.
2. Search the draft for `here's`, `quietly` and the other phrases above, and for `this` at the start of a sentence or heading.
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
- Gude et al., *More aligned, less diverse? Analyzing the grammar and lexicon of two generations of LLMs*, 2026: https://arxiv.org/abs/2605.06030
- Madler, *SlopShape: identifying AI-generated commercial web content*, 2026: https://arxiv.org/abs/2609.15369
- Russell et al., *StoryScope: investigating idiosyncrasies in AI fiction*, COLM 2026: https://arxiv.org/abs/2604.03136
- *Argument collapse: LLMs flatten long-form public debate*, 2026: https://arxiv.org/abs/2606.01736
- van Nuenen, *Voice under revision*, 2026: https://arxiv.org/abs/2604.22142
- *How LLMs distort our written language*, 2026: https://arxiv.org/abs/2603.18161
- Shaib et al., *Detection and measurement of syntactic templates in generated text*, EMNLP 2024: https://arxiv.org/abs/2407.00211
- Miletić and Falk, *What are LLMs doing to scientific communication?*, LREC 2026: https://arxiv.org/abs/2605.19936
