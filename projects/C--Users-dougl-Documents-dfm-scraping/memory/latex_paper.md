---
name: latex_paper
description: LaTeX paper formatting preferences, ASME conference template gotchas, table design patterns
type: feedback
---

## Document Setup
- Paper uses `asmeconf.cls` (ASME conference template v1.46) -- two-column format
- Main file: `main.tex`, bib file: `asmeconf-sample.bib`
- Already loaded: `booktabs`, `dblfloatfix`
- May need to add: `tabularx`, `makecell` for tables

## Table Preferences

**Do NOT use `\multirow`** for section labels in tables. It causes phantom numbers (e.g., `6*`, `4*`) when the row span doesn't fit. Instead, put the section label in the first row and leave subsequent rows empty in that column.

**Structure preferences:**
- KnowledgeFrame schema table: organize into 4 sections (Post Metadata, Knowledge Content, Frame Metadata, Human Review) -- each field in its own row
- Every field should get its own row, even in grouped sections (post metadata, human review) -- don't lump fields into a single cell
- Use `\cmidrule(l){2-3}` between fields within a section for light visual separation
- Use `\midrule` between sections
- Section labels should be **bold**
- For enum values, list them inline in the Purpose/Description column (e.g., `\texttt{risk}, \texttt{heuristic}, ...`) rather than in a separate Type/Values column
- If a separate values column IS used and has many values, use a two-column mini `\begin{tabular}[t]{@{}l@{\hspace{6pt}}l@{}}` inside the cell -- never a single tall list
- Use `table*` for tables that span both columns
- Use `tabularx` with `X` column for description text that should fill remaining width
- `\footnotesize` + `\renewcommand{\arraystretch}{1.2}` for readable density

**Why:** User wants clean, professional tables. Multirow artifacts look broken. Individual rows per field are clearer than grouped cells. Inline enum values read better than a separate column when there are only a few.

**How to apply:** When building any LaTeX table for this paper, follow the flat structure (section label in first row, empty below, cmidrule between fields, midrule between sections). Never use multirow.

## BibTeX Format
- Uses ASME bib style -- supports `@article`, `@book`, `@incollection`, `@inproceedings`
- `@inproceedings` supports: `venue`, `eventdate`, `number` (for paper number like DETC2025-99532)
- Include `doi` when available

## ASME Class Gotchas
- `asmeconf.cls` defines `\subsubsection` with negative after-skip (`{-0.5em}`), making it a **run-in heading** -- text continues on the same line as the heading
- To force a newline after `\subsubsection`, add `\par\noindent` immediately after the call
- `\paragraph` also runs inline; do NOT rely on `\paragraph` for numbered sub-sub-subheadings
- `\setcounter{secnumdepth}{4}` does NOT reliably number `\paragraph` in ASME class
- Do NOT override `\subsubsection` or `\paragraph` formatting with `titlesec` -- may violate ASME template guidelines
- For un-numbered indented component headings within a subsubsection, use a custom command:
  ```latex
  \newcommand{\componenthead}[1]{\vspace{1.5ex}\hspace{\parindent}\textbf{#1}\hspace{0.5em}}
  ```
  This produces an indented bold run-in heading. Text follows inline on the same line.

## Appendix Structure (DFM Agent Output)
- Hierarchy: `\section` (A) -> `\subsection` (A.1 Summary, A.2 Disciplines, A.3 Design Rules, A.4 Knowledge Gaps) -> `\subsubsection` (A.2.1 Machining Process, A.2.2 Machine Capability, etc.) -> `\componenthead` (First-Principles, Formulas, Evidence, Chains)
- `\componenthead` text runs inline (same line as heading) -- do NOT force newline
- `\subsubsection` needs `\par\noindent` after it to separate from first `\componenthead`
- Source labels: use `{\small\sffamily\bfseries[KG]}` etc. inline -- check ASME font compatibility before using `\sffamily`
- Evidence tables: `\begin{tabularx}{\columnwidth}{@{} X l @{}}` with Claim + Frame columns
- Design rules table: use `table*` with 4 columns: Design Rule, Frame metadata, Source Quote, Main Point
- Frame metadata in design rules: use mini `\begin{tabular}[t]{@{}l@{}}` for ID/type/author/credibility stacked vertically
- Reasoning chain tables: chain label as `\multicolumn{3}{@{}l}{\emph{...}}` header row, then role+claim rows with `\cmidrule`

## DFM Report Section Data Sources
- **Summary**: LLM-generated synthesis (KG+LLM) -- produced after all evidence retrieved and ranked
- **First-Principles Rationale**: LLM-generated from general engineering knowledge (LLM) -- clearly labeled as inference
- **Governing Formulas**: LLM-generated (LLM) -- equations the LLM deems relevant, not from frames
- **Evidence claims**: directly from knowledge frames (KG) -- each claim restates a frame's main_point under relevant discipline
- **Reasoning Chains**: graph traversal over semantic edges (KG) -- causal sequences connecting frames via CAUSAL_LINK, MITIGATES, etc.
- **Design Rules**: LLM synthesis constrained to cite frames (KG+LLM) -- transforms frame observations into actionable CAD-stage decisions
- **Knowledge Gaps**: LLM identifies missing evidence (LLM) -- areas where graph lacks frames to fully answer query
- **Backfill**: LLM fills gaps from general knowledge (LLM) -- explicitly labeled as not from KG
- Evidence claims vs design rules: same frame can appear in both. Evidence = "what the KG says" (descriptive). Design rules = "what the designer should do about it" (actionable). Prompt constrains design rules to CAD/drawing-stage decisions only.

## Key References Already Identified
- Fillmore 1982 (Frame Semantics) -- `@incollection`
- Hyland 1998 (Hedging in Scientific Research Articles) -- `@book`, doi: 10.1075/pbns.54
- Toulmin 1958 (The Uses of Argument) -- `@book`
- Minsky 1974 (Framework for Representing Knowledge) -- MIT AI Lab Memo
- Nonaka & Takeuchi 1995 (SECI Model) -- `@book`
