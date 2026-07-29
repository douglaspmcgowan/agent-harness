---
name: schema-research
description: Research-ground a Schema Studio extraction schema for a document GENRE before authoring it. Given a document type (meetings, standards, forums, CAD drawings, design reports, discourse...), it researches how that genre is ACTUALLY structured using public sources, derives a frame-type vocabulary + field set WITH citations, emits a draft schema JSON that validates against Schema Studio's meta-schema, then validates it against a real sample via a MAMA-style coverage-and-ambiguity loop (Pustejovsky & Stubbs) before shipping. Use when the user says "research a schema for X", "the X schema is too thin", "ground the X schema in how X documents really work", or "/schema-research X". Guards against the failure mode this exists to kill: inventing a 2-frame-type schema from intuition when the genre has an established discourse taxonomy.
---

# /schema-research [document-type]

Author a Schema Studio schema that is grounded in how the document GENRE is really
structured, not in a first guess. Every frame type and field must trace to a source
you actually fetched. **Never invent a citation** — if you cannot find the taxonomy,
say so and fall back to a sample-driven derivation, labelled as such.

## Argument

The document genre to schema. Minimum useful input:

> "research a schema for engineering standards"
> "the meetings schema is too thin — ground it"

If just `/schema-research` with no argument, ask which genre and for one sample document.

---

## Phase 0 — Read the meta-schema (ALWAYS FIRST)

Read `<schema-studio>/data/meta-schema.json`. It is the contract the draft must satisfy:

- `field_types` — the ONLY allowed field types (currently `string`, `text`, `enum`,
  `number`, `boolean`, `list`). Never emit a type outside this list.
- `field_props` — the allowed props per field (`name` must match `^[a-z][a-z0-9_]*$`;
  `enum` is a list, shown only when `type: enum`; `required` is boolean; `description`
  and `hint` are text).
- `config_props` — the header props (`name`, `description`, `data_type` from its enum).

If the genre needs a type the meta-schema lacks, note it as a meta-schema gap — do NOT
smuggle in an unsupported type.

---

## Phase 1 — Research the genre's real structure

Goal: find the genre's **established discourse / annotation / provision taxonomy** — the
categories domain experts already use to segment these documents. Reach for `WebSearch`
+ `WebFetch` (public topic — allowed). Source priority, highest authority first:

1. **The genre's governing drafting standard or established annotation scheme.** Use the
   pointer table below as the starting map — it names the authoritative taxonomy per genre.
2. **Academic annotation schemes / corpora** for the genre (search "<genre> annotation
   scheme", "<genre> discourse taxonomy", "<genre> rhetorical structure").
3. **Practitioner conventions** (style guides, templates) for what actually recurs.

**Genre → taxonomy pointer table.** The known authoritative taxonomy per genre — start here,
then confirm by fetching the primary source (do not cite the table itself):

| Genre | Authoritative taxonomy | Core categories it names |
|---|---|---|
| Standards / specs | **ISO/IEC Directives, Part 2** (verbal forms) | requirement (shall), recommendation (should), permission (may), possibility/capability (can), statement of fact, external constraint (must), note, example, term & definition |
| Requirements / design specs | **Glinz 2007 concern-based NFR taxonomy**; NoRBERT/PROMISE-NFR corpus classes | functional, performance, specific-quality (usability/security/reliability/...), constraint |
| Meetings / minutes | Robert's Rules motion types; MoM conventions; ISO 24617-2 (SWBD-)DAMSL dialogue acts | decision, action-item, discussion-point, motion, information |
| Forums / discourse | Argumentation-mining schemes: IAT/Inference-Anchoring, Toulmin (claim/warrant/rebuttal); dialogue acts | claim, premise, rebuttal, question, agreement |
| Scientific / design reports | **Argumentative Zoning** (Teufel); Rhetorical Structure Theory (RST); IMRaD | background, aim/own, method, result, contrast/other |
| CAD drawings | **ASME Y14.5 GD&T** annotation categories | dimension, tolerance, datum, note, title-block field |

If the genre isn't in the table, search for its scheme by the queries in priority 2. A genre
with no established taxonomy is a real finding — fall back to sample-driven derivation, labelled.

Fetch the primary source, don't rely on the search blurb. Record each source as
`| URL | what it establishes |`. If a fetch 403s or a source can't be confirmed, say so
explicitly and do not cite it.

**Output of this phase:** a short evidence table — the candidate frame-type categories,
each with the source that establishes it and the exact term/verbal-form it uses.

---

## Phase 2 — Derive the vocabulary + fields (with citations)

Turn the evidence into the schema, mapping each category to a `frame_type` enum value:

- **frame_type enum** = the genre's provision/discourse categories, snake_case, each
  justified by a Phase-1 source. Prefer the source's own term. Don't collapse distinct
  categories the taxonomy separates (the whole point — a standards schema with only
  `requirement`/`definition` drops recommendation/permission/note/example, which the
  Directives treat as first-class).
- **fields** = what an extractor must capture per frame. Cover: the frame's core content
  (`text`), where it sits in the document (clause/section id), what it applies to, and
  any genre-specific structured facets (verification method, verbal form, cross-refs,
  normative-vs-informative status). Every field's `type` MUST be in meta-schema
  `field_types`; every `name` MUST match the pattern.
- Put extraction guidance in `hint`; put "what this captures" in `description`.
- Set `data_type` from the meta-schema's `config_props` enum.

Keep it lean (ponytail): add a field only if the extractor would genuinely fill it. No
speculative facets. Mark anything you added past the source evidence and say why.

### When NOT to add a frame type (granularity discipline, from FrameNet)

Distinct categories the taxonomy separates stay distinct — but two failure directions are real:

- **Don't split what is one scene seen from two angles.** FrameNet keeps `Commerce_buy` and
  `Commerce_sell` as *perspectives* on one `Commerce_goods-transfer` frame, not two unrelated
  frames. If two candidate frame types share the same participants and fields and differ only in
  vantage/emphasis, make them ONE frame type with a facet field (e.g. a `perspective` or `polarity`
  enum), not two enum values. Split into separate frame types only when the core fields genuinely
  differ — new participants, a new required facet, a different verification method.
- **Don't add a category the sample never exercises.** A frame type no span in Phase 4 lands in is
  dead weight — drop it or fold it, and say which source named it so the omission is traceable.
- **Granularity trade-off, stated:** finer categories capture more distinctions but raise annotator
  ambiguity (Phase 4's IAA-style check is where that shows up) and empty-field risk. Prefer the
  coarsest vocabulary that still separates every category the taxonomy treats as first-class.

### Multi-label provisions (overlapping categories)

Real provisions belong to more than one category at once — a requirements sentence can be
functional AND a performance NFR ("provide asynchronous messaging to reduce overhead" is both;
Glinz 2007). Single-label `frame_type` forces a lossy choice. Handle it explicitly:

- If the genre's taxonomy has genuine category overlap, make `frame_type` a `list` (of enum-style
  values) rather than a single `enum`, OR keep `frame_type` single and add a secondary
  `frame_type_secondary` / tag `list` field for the overlap — pick per the meta-schema's allowed
  types (`list` is allowed; a list-of-enum is expressed as a `list` field with the values in `hint`).
- State the tie-break rule the extractor uses when only one primary label is allowed (e.g. "primary
  = the provision's dominant verbal form; secondary = the quality concern it also touches").

---

## Phase 3 — Emit the draft schema JSON

Emit a record that matches the meta-schema and Schema Studio's record shape:

```json
{
  "name": "...",
  "description": "One sentence telling the extractor what a frame IS for this genre.",
  "data_type": "<from config_props enum>",
  "fields": [
    { "name": "frame_type", "type": "enum", "enum": ["..."], "required": true,
      "description": "..." }
  ]
}
```

Self-check before moving on: every `type` ∈ `field_types`; every `name` matches the
pattern; `enum` present only on `enum` fields; `description` says what the value chosen
means. If updating an EXISTING record via the store API
(`GET/PUT http://localhost:8804/api/store/schemas`), fetch the full list, modify ONLY the
target record, PUT the whole list back, then GET again and diff to prove exactly one
record changed. Bump the target's version note honestly.

---

## Phase 4 — Validate against a real sample: the MAMA loop (REQUIRED)

A schema is unproven until it survives a real document. This phase is a LOOP, not a one-shot
check — Pustejovsky & Stubbs' MAMA cycle (Model→Annotate→Model→Annotate) refines the scheme on
pilot annotations BEFORE it's called ready. A failed gate below sends you back to Phase 1/2 to
revise the vocabulary, then re-run this phase. Do not ship on the first pass if any gate fails.

Take one representative sample of the genre (ask the user for one if none is available). Then:

1. **Sample N and tag.** Pull N = 15–20 real provisions/spans from the sample and tag each with a
   `frame_type` value.
2. **Coverage gate (hard).** EVERY one of the N spans must land in a frame type. Even one span you
   can't classify means a missing category — go back to Phase 1, don't invent one from intuition.
   Conversely, any frame type zero spans used is dead weight → drop or fold it (Phase 2 rule).
3. **Ambiguity / inter-annotator-style gate.** Re-tag the same N spans a second time from scratch
   (a second pass stands in for a second annotator). Any span that lands in a DIFFERENT frame type
   the second time, or that plausibly fits two frame types at once, marks an ambiguous category
   boundary — the reliability signal IAA studies exist to surface. For each such span: either the
   two categories should merge (they're one scene from two angles — Phase 2), or the guidance in
   `hint` needs a sharper decision rule, or it's a genuine multi-label provision (Phase 2). Resolve
   it; don't ship a vocabulary two honest passes disagree on.
4. **Field gate.** For a handful of tagged frames, actually fill the required fields from the text.
   An always-empty required field is wrong — demote it to optional or cut it.
5. **Format-noise / language check.** Confirm the sample includes the genre's real messiness — OCR'd
   CAD annotations, tables, non-English standards. Verbal-form cues (shall/should/may) are
   English-specific; if the genre appears in other languages, note that the frame_type cues won't
   transfer and the schema is validated for English only unless a multilingual sample was used.
6. **Report** the tag distribution, any span that resisted or flipped classification, and how many
   MAMA passes it took to stabilize.

Only after every gate passes with no unresolved span report the schema as ready.

---

## Methodology grounding (sources for this skill's own procedure)

The loop above folds in established annotation-scheme methodology:

- **MAMA / MATTER cycle** — Pustejovsky & Stubbs, *Natural Language Annotation for Machine Learning*
  (O'Reilly 2012): iterate model↔pilot-annotation before full annotation; missing category or low
  agreement sends you back to modeling.
- **Frame granularity & perspective** — Ruppenhofer et al., *FrameNet II: Extended Theory and
  Practice* (2016): core vs non-core elements; perspective (buy/sell on one transfer frame) as the
  split-or-merge criterion.
- **Inter-annotator agreement as the reliability gate** — standard corpus-annotation practice;
  disagreement is a signal that locates scheme ambiguity, not just a score.
- **Multi-label / overlapping categories** — Glinz 2007 concern-based NFR taxonomy and the
  requirements-classification corpora (a provision is often functional AND a quality NFR at once).

---

## Output contract

Report, in this order:

1. **Sources** — the URLs you actually fetched and what each establishes (no others).
2. **Frame-type vocabulary** — before → after enum, each new value tied to its source.
3. **Fields** — the field set with types, flagging anything added beyond the evidence.
4. **Draft/updated schema JSON** (or the PUT diff proving one record changed).
5. **Validation** — the sample used, the tag distribution, any unclassifiable or classification-
   flipped spans, and how many MAMA passes it took to stabilize.

Never claim "grounded" for a value with no source behind it. If a category is your own
judgment call rather than from a taxonomy, label it as such.
