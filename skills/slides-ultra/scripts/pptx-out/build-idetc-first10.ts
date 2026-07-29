import pptxgen from 'pptxgenjs';
// Import only the modules we use, bypassing main.js's re-export of text.ts
// (text.ts pulls in skia-canvas, whose native binary fails to load on this Windows box).
import { createTheme, resolveFont } from './theme.js';
import { imageSizingContain } from './image.js';
import { validateDeck } from './validation.js';

const h = { createTheme, resolveFont, imageSizingContain, validateDeck };

// ---------------------------------------------------------------------------
// IDETC 2026 — first 10 slides, native editable PPTX
// Content source: Obsidian_Vault/Presentations/IDETC 2026 - Ultimate Slides.md
// No invented facts — every string traces to the source markdown.
// ---------------------------------------------------------------------------

const IMG = 'C:/Users/dougl/Documents/Claude Folder/IDETC-ultra-decks/_images';
const OUT =
  'C:/Users/dougl/Documents/Claude Folder/IDETC-ultra-decks/v6-pptx/IDETC-first10.pptx';

const pptx = new pptxgen();
pptx.layout = 'LAYOUT_16x9'; // 10" x 5.625"

// Re-express the source deck's dark look as a PptxGenJS theme.
// (The HTML token themes do not carry over; this is a hand-mapped equivalent.)
const theme = h.createTheme({
  bg: { primary: '0a0a0a', secondary: '161616' },
  text: { primary: 'f2f2f2', secondary: 'a8a8a8' },
  accent: '4a9eff',
  accentSecondary: 'ff6b6b',
  font: { heading: 'Arial', body: 'Arial', mono: 'Consolas' },
});

const HEAD = h.resolveFont(theme, 'heading');
const BODY = h.resolveFont(theme, 'body');
const BG = theme.bg.primary;
const FG = theme.text.primary;
const FG2 = theme.text.secondary;
const ACCENT = theme.accent;

// ---- small helpers ---------------------------------------------------------

function heading(slide: any, text: string, opts: { fontSize?: number; align?: any } = {}) {
  slide.addText(text, {
    x: 0.5,
    y: 0.3,
    w: 9,
    h: 0.8,
    fontSize: opts.fontSize ?? 30,
    fontFace: HEAD,
    color: FG,
    bold: true,
    align: opts.align ?? 'left',
  });
  slide.addShape(pptx.shapes.LINE, {
    x: 0.5,
    y: 1.12,
    w: 2,
    h: 0,
    line: { color: ACCENT, width: 3 },
  });
}

type Bullet = { text: string; level?: number; bold?: boolean };

function bulletList(
  slide: any,
  items: Bullet[],
  region: { x: number; y: number; w: number; h: number; fontSize?: number }
) {
  const runs = items.map((it) => ({
    text: it.text,
    options: {
      fontSize: it.level && it.level > 0 ? (region.fontSize ?? 16) - 2 : region.fontSize ?? 16,
      fontFace: BODY,
      color: it.level && it.level > 0 ? FG2 : FG,
      bold: it.bold ?? false,
      bullet: { code: '2022', indent: 14 },
      indentLevel: it.level ?? 0,
      breakLine: true,
      paraSpaceAfter: 5,
    },
  }));
  slide.addText(runs, {
    x: region.x,
    y: region.y,
    w: region.w,
    h: region.h,
    valign: 'top',
    lineSpacing: (region.fontSize ?? 16) * 1.25,
  });
}

function imageContain(
  slide: any,
  file: string,
  box: { x: number; y: number; w: number; h: number }
) {
  const path = `${IMG}/${file}`;
  const sizing = h.imageSizingContain(path, box.x, box.y, box.w, box.h);
  slide.addImage({ path, ...sizing });
}

// ===========================================================================
// SLIDE 1 — Title
// ===========================================================================
{
  const s = pptx.addSlide();
  s.background = { color: BG };

  s.addText('Capturing Tacit Design Knowledge', {
    x: 0.5,
    y: 1.5,
    w: 9,
    h: 1.0,
    fontSize: 40,
    fontFace: HEAD,
    color: FG,
    bold: true,
    align: 'center',
  });
  s.addText('from Unstructured Discourse', {
    x: 0.5,
    y: 2.5,
    w: 9,
    h: 0.7,
    fontSize: 26,
    fontFace: HEAD,
    color: ACCENT,
    align: 'center',
  });
  s.addText('Douglas P. McGowan  ·  Kosa Goucher-Lambert  —  UC Berkeley', {
    x: 0.5,
    y: 3.6,
    w: 9,
    h: 0.5,
    fontSize: 18,
    fontFace: BODY,
    color: FG,
    align: 'center',
  });
  s.addText('ASME IDETC 2026', {
    x: 0.5,
    y: 4.2,
    w: 9,
    h: 0.5,
    fontSize: 16,
    fontFace: BODY,
    color: FG2,
    align: 'center',
  });

  s.addNotes(
    [
      'set discussion-first tone upfront',
      'invite questions at any point',
      'only planned to speak for a fraction of the time',
    ].join('\n')
  );
}

// ===========================================================================
// SLIDE 2 — About Me (text-left, image-right)
// ===========================================================================
{
  const s = pptx.addSlide();
  s.background = { color: BG };
  heading(s, 'About Me');

  s.addText('Douglas McGowan — Engineering Intern, NASA local', {
    x: 0.5,
    y: 1.25,
    w: 5.3,
    h: 0.4,
    fontSize: 16,
    fontFace: BODY,
    color: FG,
    bold: true,
  });
  s.addText('UC Berkeley Mechanical Engineering · Co-Design Lab (Kosa Goucher-Lambert)', {
    x: 0.5,
    y: 1.65,
    w: 5.3,
    h: 0.5,
    fontSize: 13,
    fontFace: BODY,
    color: FG2,
  });

  bulletList(
    s,
    [
      { text: 'Research', bold: true },
      { text: 'Context engineering & knowledge management', level: 1 },
      { text: 'At NASA local — Text-To-Spaceship', bold: true },
      { text: 'With Ryan McClelland – AI workflows for system development', level: 1 },
      { text: 'AI Immersion Week:', level: 1 },
      { text: 'example-project (LLMs + … + Generative Design)', level: 2 },
      { text: 'Text-to-concept (example-service)', level: 2 },
      { text: 'Text-to-satellite', level: 1 },
      { text: 'Applying my research', level: 1 },
    ],
    { x: 0.5, y: 2.25, w: 5.3, h: 3.1, fontSize: 14 }
  );

  imageContain(s, 'slide_2_0.jpg', { x: 6.1, y: 1.25, w: 3.4, h: 3.9 });

  s.addNotes(
    [
      'NASA local via Air Force internship',
      'PhD at UC Berkeley, mechanical engineering',
      'Co-Design Lab, Professor Kosa Goucher-Lambert',
      'focus: context engineering and knowledge management',
    ].join('\n')
  );
}

// ===========================================================================
// SLIDE 3 — The Co-Design Lab @ UC Berkeley (text-left, image-right)
// ===========================================================================
{
  const s = pptx.addSlide();
  s.background = { color: BG };
  heading(s, 'The Co-Design Lab @ UC Berkeley', { fontSize: 28 });

  s.addText('Cognition & Computation in Design Lab', {
    x: 0.5,
    y: 1.25,
    w: 5.3,
    h: 0.4,
    fontSize: 16,
    fontFace: BODY,
    color: FG,
    bold: true,
  });
  s.addText('Prof. Kosa Goucher-Lambert · UC Berkeley Mechanical Engineering', {
    x: 0.5,
    y: 1.65,
    w: 5.3,
    h: 0.4,
    fontSize: 13,
    fontFace: BODY,
    color: FG2,
  });
  s.addText('How can humans and computers excel at design tasks?', {
    x: 0.5,
    y: 2.05,
    w: 5.3,
    h: 0.5,
    fontSize: 14,
    fontFace: BODY,
    color: ACCENT,
    italic: true,
  });

  bulletList(
    s,
    [
      { text: 'Master of Design program' },
      { text: 'Collaborations: Autodesk Research, CMU, MIT, NASA Glenn + Langley' },
      { text: 'Venues: ASME IDETC/CIE, JMD, JCISE; ACM CHI, DIS, CSCW, ICED' },
      { text: 'codesign.berkeley.edu' },
    ],
    { x: 0.5, y: 2.7, w: 5.3, h: 2.6, fontSize: 15 }
  );

  imageContain(s, 'slide_3_0.jpg', { x: 6.1, y: 1.25, w: 3.4, h: 3.9 });

  s.addNotes(
    [
      'Cognition and Computation and Design',
      'how humans and computers excel at design tasks',
      'broad collaborations — Autodesk, NASA centers, many venues',
      'Kevin Ma study: human-AI collab at NASA Langley, early-stage design',
    ].join('\n')
  );
}

// ===========================================================================
// SLIDE 4 — CoDesign Lab × NASA (2-column table)
// ===========================================================================
{
  const s = pptx.addSlide();
  s.background = { color: BG };
  heading(s, 'CoDesign Lab × NASA');

  const headerOpts = {
    fontFace: HEAD,
    color: 'ffffff',
    bold: true,
    fill: { color: '1f3a5f' },
    valign: 'middle' as const,
    align: 'left' as const,
  };
  const cellOpts = {
    fontFace: BODY,
    color: FG,
    fill: { color: '161616' },
    valign: 'top' as const,
    align: 'left' as const,
  };

  const rows: any[] = [
    [
      { text: 'Kevin Ma · NASA Langley', options: { ...headerOpts, fontSize: 15 } },
      { text: 'Douglas McGowan · NASA local', options: { ...headerOpts, fontSize: 15 } },
    ],
    [
      { text: 'Co-Design Lab Ph.D. candidate', options: { ...cellOpts, fontSize: 13 } },
      { text: 'This paper:', options: { ...cellOpts, fontSize: 13, bold: true } },
    ],
    [
      {
        text: 'Three strategies of human-AI collaboration · IDETC 2024',
        options: { ...cellOpts, fontSize: 13 },
      },
      {
        text: 'Extracting practitioner DFM knowledge for design systems',
        options: { ...cellOpts, fontSize: 13 },
      },
    ],
    [
      { text: 'Ethnographic study of a NASA design team', options: { ...cellOpts, fontSize: 13 } },
      { text: '', options: { ...cellOpts, fontSize: 13 } },
    ],
    [
      {
        text: 'With Vikram Shyam (NASA Glenn), Eric Brubaker (NASA Langley)',
        options: { ...cellOpts, fontSize: 13 },
      },
      { text: '', options: { ...cellOpts, fontSize: 13 } },
    ],
    [
      {
        text: 'Simulating C-K design theory with LLM agents · IDETC 2025 / JMD 2026',
        options: { ...cellOpts, fontSize: 13 },
      },
      { text: '', options: { ...cellOpts, fontSize: 13 } },
    ],
    [
      { text: 'With Eric Brubaker (NASA Langley)', options: { ...cellOpts, fontSize: 13 } },
      { text: '', options: { ...cellOpts, fontSize: 13 } },
    ],
  ];

  s.addTable(rows, {
    x: 0.5,
    y: 1.35,
    w: 9,
    h: 3.7,
    colW: [4.5, 4.5],
    border: { type: 'solid', color: '333333', pt: 1 },
    margin: 0.08,
  });

  s.addNotes(
    [
      'text-to-spaceship vision — structure, concept, satellite',
      'AI Immersion Week exercises — that was my work',
      'drone demonstration and parts — also my work',
      'now building text-to-satellite, applying this research',
    ].join('\n')
  );
}

// ===========================================================================
// SLIDE 5 — Knowledge Graph (image-full)
// ===========================================================================
{
  const s = pptx.addSlide();
  s.background = { color: '000000' };

  s.addText('Knowledge Graph — Main Output', {
    x: 0.5,
    y: 0.2,
    w: 9,
    h: 0.6,
    fontSize: 26,
    fontFace: HEAD,
    color: FG,
    bold: true,
    align: 'center',
  });

  imageContain(s, 'slide_5_0.png', { x: 0.3, y: 0.95, w: 9.4, h: 4.45 });

  s.addNotes(
    [
      'main output: the knowledge graph',
      '7,800 nodes, 13,000 edges',
      'pulled from a relatively small corpus — scale would grow',
    ].join('\n')
  );
}

// ===========================================================================
// SLIDE 6 — Problem Statement
// ===========================================================================
{
  const s = pptx.addSlide();
  s.background = { color: BG };
  heading(s, 'Problem Statement: tacit DFM knowledge is invisible', { fontSize: 24 });

  s.addText(
    'Much of design-for-manufacturing expertise is tacit — implicit and/or experiential',
    {
      x: 0.5,
      y: 1.25,
      w: 9,
      h: 0.5,
      fontSize: 15,
      fontFace: BODY,
      color: ACCENT,
      italic: true,
    }
  );

  bulletList(
    s,
    [
      { text: 'Tacit knowledge lives in:', bold: true },
      { text: 'Shop-floor experience', level: 1 },
      { text: 'Rules-of-thumb', level: 1 },
      { text: 'The minds of practitioners', level: 1 },
      { text: 'Decision-making depends on both tabulated specs and informal heuristics' },
      { text: 'Existing knowledge bases capture the explicit portion and miss the tacit portion' },
      { text: 'Designers struggle to access & understand this knowledge & context' },
      { text: 'Creates: clunky communication & costly rebuilds', level: 1 },
      { text: 'This same phenomenon occurs in other disciplines' },
    ],
    { x: 0.6, y: 1.85, w: 8.8, h: 3.5, fontSize: 14 }
  );

  s.addNotes(
    [
      'DFM knowledge is tacit — implicit, experiential, invisible',
      'lives in shop-floor experience, rules of thumb, practitioner minds',
      'explicit knowledge bases exist but miss the tacit portion',
      "designers can't access what's outside their discipline",
      'costly late-stage rebuilds that could have been caught earlier',
    ].join('\n')
  );
}

// ===========================================================================
// SLIDE 7 — Proposed Solution: Agentic Knowledge Capture
// ===========================================================================
{
  const s = pptx.addSlide();
  s.background = { color: BG };
  heading(s, 'Proposed Solution: Agentic Knowledge Capture', { fontSize: 24 });

  bulletList(
    s,
    [
      { text: 'Collect data, wherever available' },
      { text: 'Use LLMs for large-scale distillation' },
      { text: 'Design knowledge base for the team & environment' },
      { text: 'Create & validate knowledge base from distilled data' },
      { text: 'Develop outputs:' },
      { text: 'Simple querying', level: 1 },
      { text: 'Agentic retrieval', level: 1 },
      { text: 'Surfacing to humans', level: 1 },
      { text: 'Result — Naturally occurring data used to:' },
      { text: 'Capture and preserve "difficult" knowledge', level: 1 },
      { text: 'Provide better context for AI', level: 1 },
      { text: 'Bridge gaps in understanding & communication', level: 1 },
    ],
    { x: 0.6, y: 1.35, w: 8.8, h: 4.0, fontSize: 13.5 }
  );

  s.addNotes(
    [
      'agentic knowledge capture — the whole paper in one slide',
      "if you're double-booked, listen to this one and head out",
      'collect, distill with LLMs, design the knowledge base, validate',
      'surfacing to humans is often the hardest part',
    ].join('\n')
  );
}

// ===========================================================================
// SLIDE 8 — Solution overview
// ===========================================================================
{
  const s = pptx.addSlide();
  s.background = { color: BG };
  heading(s, 'Solution overview');

  s.addText(
    [
      { text: 'The problem: ', options: { bold: true, color: FG } },
      {
        text: 'tacit DFM knowledge is locked in unstructured forum discourse',
        options: { color: FG2 },
      },
    ],
    { x: 0.5, y: 1.2, w: 9, h: 0.4, fontSize: 14, fontFace: BODY }
  );

  s.addText('Four stages', {
    x: 0.5,
    y: 1.65,
    w: 9,
    h: 0.35,
    fontSize: 15,
    fontFace: BODY,
    color: FG,
    bold: true,
  });

  const stage = (label: string, rest: string) => ({
    text: [
      { text: `${label}: `, options: { bold: true, color: ACCENT } },
      { text: rest, options: { color: FG } },
    ],
  });

  s.addText(
    [
      {
        text: 'Collect: ',
        options: { bold: true, color: ACCENT, fontSize: 13.5, bullet: { code: '2022' }, breakLine: true, paraSpaceAfter: 6 },
      },
      {
        text: '12,805 Stack Exchange threads filtered to 1,936 relevant practitioner posts',
        options: { color: FG, fontSize: 13.5, breakLine: true, paraSpaceAfter: 6 },
      },
      {
        text: 'Extract: ',
        options: { bold: true, color: ACCENT, fontSize: 13.5, bullet: { code: '2022' } },
      },
      {
        text: 'an LLM extracts 3,879 knowledge frames, the discrete typed units of design and manufacturing knowledge',
        options: { color: FG, fontSize: 13.5, breakLine: true, paraSpaceAfter: 6 },
      },
      {
        text: 'Validate: ',
        options: { bold: true, color: ACCENT, fontSize: 13.5, bullet: { code: '2022' } },
      },
      {
        text: "experts plus an LLM-as-judge confirm quality (92% rated good; Gwet's AC1 = 0.84)",
        options: { color: FG, fontSize: 13.5, breakLine: true, paraSpaceAfter: 6 },
      },
      {
        text: 'Connect: ',
        options: { bold: true, color: ACCENT, fontSize: 13.5, bullet: { code: '2022' } },
      },
      {
        text: 'frames link into a knowledge graph (7,864 nodes, typed edges) that an agent can query',
        options: { color: FG, fontSize: 13.5, breakLine: true, paraSpaceAfter: 6 },
      },
      {
        text: 'Retrieve: ',
        options: { bold: true, color: ACCENT, fontSize: 13.5, bullet: { code: '2022' } },
      },
      {
        text: 'build AI agent to test retrieval and knowledge surfacing for end users',
        options: { color: FG, fontSize: 13.5, breakLine: true, paraSpaceAfter: 6 },
      },
      {
        text: 'Result: ',
        options: { bold: true, color: ACCENT, fontSize: 13.5, bullet: { code: '2022' } },
      },
      {
        text: 'a traceable, scope-aware knowledge layer designers can consult',
        options: { color: FG, fontSize: 13.5, breakLine: true },
      },
    ],
    { x: 0.6, y: 2.1, w: 8.8, h: 3.3, fontFace: BODY, valign: 'top', lineSpacing: 18 }
  );

  s.addNotes(
    [
      'four stages: collect, extract frames, validate, connect to graph',
      'final result: traceable scope-aware knowledge layer',
      'naturally occurring data preserves difficult knowledge',
      'bridges gaps across scientists, engineers, technical workers',
    ].join('\n')
  );
}

// ===========================================================================
// SLIDE 9 — Data Source: Online Forums (table + two images)
// ===========================================================================
{
  const s = pptx.addSlide();
  s.background = { color: BG };
  heading(s, 'Data Source: Online Forums', { fontSize: 26 });

  s.addText('Selected site: Stack Exchange', {
    x: 0.5,
    y: 1.25,
    w: 5.3,
    h: 0.4,
    fontSize: 16,
    fontFace: BODY,
    color: FG,
    bold: true,
  });

  bulletList(
    s,
    [
      { text: 'Thousands of practitioner exchanges about shop-floor problems' },
      {
        text: 'Diverse and informal reasoning — distinct from curated consensus and textbook examples',
      },
    ],
    { x: 0.5, y: 1.7, w: 5.3, h: 1.4, fontSize: 14 }
  );

  const headerOpts = {
    fontFace: HEAD,
    color: 'ffffff',
    bold: true,
    fill: { color: '1f3a5f' },
    valign: 'middle' as const,
    align: 'left' as const,
    fontSize: 13,
  };
  const cellOpts = {
    fontFace: BODY,
    color: FG,
    fill: { color: '161616' },
    valign: 'top' as const,
    align: 'left' as const,
    fontSize: 12.5,
  };
  s.addTable(
    [
      [{ text: 'Rationale', options: headerOpts }],
      [
        {
          text: 'LLMs make large-scale structured extraction feasible',
          options: cellOpts,
        },
      ],
      [
        {
          text: 'No prior work systematically structures practitioner discourse for DFM knowledge',
          options: cellOpts,
        },
      ],
    ],
    {
      x: 0.5,
      y: 3.2,
      w: 5.3,
      h: 1.8,
      colW: [5.3],
      border: { type: 'solid', color: '333333', pt: 1 },
      margin: 0.08,
    }
  );

  // Two images stacked on the right
  imageContain(s, 'slide_9_0.png', { x: 6.2, y: 1.3, w: 3.3, h: 1.7 });
  imageContain(s, 'slide_9_1.png', { x: 6.2, y: 3.2, w: 3.3, h: 1.9 });

  s.addNotes(
    [
      'Stack Exchange — most feasible to pull from as a student',
      'thousands of threads filtered down',
      'informal diverse reasoning, conflicts, things textbooks skip',
      'LLMs make large-scale structured extraction feasible now',
      "this discourse type hasn't been studied much before",
    ].join('\n')
  );
}

// ===========================================================================
// SLIDE 10 — Knowledge Frame: The Idea (2-col table + examples)
// ===========================================================================
{
  const s = pptx.addSlide();
  s.background = { color: BG };
  heading(s, 'Knowledge Frame: The Idea', { fontSize: 26 });

  s.addText('Marvin Minsky · "A Framework for Representing Knowledge" · 1975', {
    x: 0.5,
    y: 1.2,
    w: 9,
    h: 0.35,
    fontSize: 13,
    fontFace: BODY,
    color: FG2,
    italic: true,
  });

  const headerOpts = {
    fontFace: HEAD,
    color: 'ffffff',
    bold: true,
    fill: { color: '1f3a5f' },
    valign: 'middle' as const,
    align: 'left' as const,
    fontSize: 12,
  };
  const cellOpts = {
    fontFace: BODY,
    color: FG,
    fill: { color: '161616' },
    valign: 'top' as const,
    align: 'left' as const,
    fontSize: 10.5,
  };
  s.addTable(
    [
      [
        { text: 'What a frame is', options: headerOpts },
        { text: 'Why it works', options: headerOpts },
      ],
      [
        {
          text: 'A structured packet for a stereotyped situation',
          options: cellOpts,
        },
        {
          text: 'Mirrors how experts read a situation — recognize the type, recall its structure',
          options: cellOpts,
        },
      ],
      [
        { text: "Slots hold the situation's typical attributes", options: cellOpts },
        {
          text: 'Turns informal language into discrete, comparable units',
          options: cellOpts,
        },
      ],
      [
        {
          text: 'Default values stand in for missing information',
          options: cellOpts,
        },
        {
          text: 'Composable and reusable — frames link into larger systems',
          options: cellOpts,
        },
      ],
      [
        {
          text: 'You recall a frame and adapt it to the case at hand',
          options: cellOpts,
        },
        { text: '', options: cellOpts },
      ],
    ],
    {
      x: 0.5,
      y: 1.6,
      w: 9,
      h: 2.0,
      colW: [4.5, 4.5],
      border: { type: 'solid', color: '333333', pt: 1 },
      margin: 0.06,
    }
  );

  s.addText(
    [
      { text: 'Example – Variables', options: { bold: true, color: ACCENT, fontSize: 11.5, breakLine: true } },
      {
        text: '1st learned formula is different from 200th learned formula',
        options: { color: FG, fontSize: 11, bullet: { code: '2022' }, breakLine: true },
      },
      {
        text: 'Equation, variables, applicability, caveats, units, configurations…',
        options: { color: FG, fontSize: 11, bullet: { code: '2022' }, breakLine: true },
      },
    ],
    { x: 0.5, y: 3.75, w: 4.5, h: 1.1, fontFace: BODY, valign: 'top', lineSpacing: 14 }
  );
  s.addText(
    [
      { text: 'Example – Mathematical Concepts', options: { bold: true, color: ACCENT, fontSize: 11.5, breakLine: true } },
      {
        text: '1st hard math class is different from 7th hard math class',
        options: { color: FG, fontSize: 11, bullet: { code: '2022' }, breakLine: true },
      },
      {
        text: 'Formulas, common errors, visualization techniques, example problems…',
        options: { color: FG, fontSize: 11, bullet: { code: '2022' }, breakLine: true },
      },
    ],
    { x: 5.1, y: 3.75, w: 4.4, h: 1.1, fontFace: BODY, valign: 'top', lineSpacing: 14 }
  );

  s.addText(
    'LINEAGE: Schemas → Scripts → Semantic networks → Object-oriented design → Knowledge graphs',
    {
      x: 0.5,
      y: 5.0,
      w: 9,
      h: 0.4,
      fontSize: 11,
      fontFace: h.resolveFont(theme, 'mono'),
      color: FG2,
      align: 'center',
    }
  );

  s.addNotes(
    [
      'Minsky 1975 — representing knowledge paper',
      'experts recognize a type and recall its structure',
      'formula analogy: first formula vs. 200th formula',
      'the second you see a formula you know what to look for',
      'sought to mimic this in digital form for AI',
    ].join('\n')
  );
}

// ---- validate + write ------------------------------------------------------
const report = h.validateDeck(pptx);
console.log(`\nvalidateDeck: passed=${report.passed}  slides=${report.stats.slideCount}  ` +
  `avgFont=${report.stats.avgFontSize}  minFont=${report.stats.minFontSize}`);
report.issues.forEach((i: any) => console.error(`[issue] ${i.message}`));
report.warnings.forEach((w: any) => console.warn(`[warn]  ${w.message}`));

await pptx.writeFile({ fileName: OUT });
console.log(`\nwrote ${OUT}`);
