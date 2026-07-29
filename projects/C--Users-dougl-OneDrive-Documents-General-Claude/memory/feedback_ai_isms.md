---
name: feedback_ai_isms
description: "AI-isms (generated-content tells) to avoid in Doug's web/UI and prose work — running list"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c5cef235-881d-4903-a37f-560e8d0ce93c
---

Avoid these "AI-isms" — patterns that read as machine-generated. Doug notices them and wants them gone. **Core principle: the tell is the unintentional default, not the technique.** Any one of these is fine inside a deliberate, coherent design language (e.g. the brutalist/zine `client-portal` uses all-caps labels and a badge-above-title on purpose). It's an AI-ism when it's the reflexive default with no design rationale. Default to intentional choices; when unsure, do the opposite of the LLM default.

## Flagged by Doug (highest priority)

1. **One-sentence descriptive subtitle under a title.** No supporting sentence beneath a heading/hero ("A private workspace where I post…"). Humans write the title and move on — applies to heroes AND every card/panel/section heading. Use labels, placeholders, and button text for instruction, not a prose sentence.
2. **Highlighting/marking short one-liner phrases.** No accent-background "marker" on a few words of a headline (the `<span class="mark">` treatment); no serif-italic on a single accent word in a sans headline. Titles stand on their own.

## Color & effects

3. **Purple/indigo → blue gradients** ("VibeCode purple") as the safe default — in heroes, CTAs, backgrounds. Pick a deliberate palette instead.
4. **Gradient pill CTAs**, oversized colored glows, colored box-shadows, and blur/glassmorphism used as "premium" decoration with no function.
5. **Reflexive dark mode** with low-contrast medium-grey body text. **Also: a blue/purple-tinted "dark" mode.** Real dark modes are near-neutral (GitHub `#0d1117`, Linear/Vercel near-black greys, VS Code `#1e1e1e`) — true dark, not navy. The AI tell is background greys whose blue channel sits noticeably above red/green (e.g. `#181a21`, `#1f222b`). Neutralize the ramp: keep R≈G≈B (`#0d0d0d`, `#141414`, `#1a1a1a`…). A faint _warm_ cast is fine; a cool/blue cast reads as generated.
6. **Colorized inline text to "explain" things.** Real apps keep body/help/onboarding text near-monochrome. Emphasis comes from **weight** (bold in the _same_ color), not hue; **inline `code` is neutral** (muted/near-white mono on a subtle chip — GitHub/Notion/Stripe), never a saturated accent; links get **one** accent color. Don't tint every keyword/term gold/accent to make it "pop" — that reads decorative, not designed (practitioner consensus: emphasize with weight/decoration, not color). Reserve a colored word only when the color **is** the information (showing an actual status/AI color inline). Flagged by Doug 2026-06-14 (REDLINE help panel: gold inline-code chips read as colorful).

## Typography

7. **Inter (or Geist/Space Grotesk) as the unexamined default** with only a system-sans fallback. Choose a distinctive display font + a deliberate two-font (headline/body) pairing. The AI sans/serif "slop font" set to treat as a tell: **Inter** (the #1), **Geist**, **Space Grotesk**, **Instrument Serif** (esp. paired w/ Inter), **DM Sans**, **Plus Jakarta Sans**, **Syne**, **Fraunces**. Fine in isolation; the tell is reaching for them as the no-direction default.
8. **Monospace as a decorative UI font.** This is the loudest font tell. **Outlaw JetBrains Mono / Space Mono / Cascadia Code (and any mono) in UI chrome** — nav, buttons, tabs/toggles, section headers, field labels, badges, eyebrows, stat numbers, body copy, headlines. Real apps (GitHub, Linear, Stripe, Vercel) use mono _only_ where the content is technical: (a) code & terminal output; (b) IDs / hashes / refs (Linear `ENG-2703`, commit SHAs, API keys); (c) keyboard shortcuts (`<kbd>`); (d) file paths & shell commands; (e) literal markup/token placeholders. **For aligning numbers, do NOT switch to a mono font** — use `font-variant-numeric: tabular-nums` on the regular sans. Mono on a label/heading/nav = vibe-coded. Flagged by Doug 2026-06-14 on the REDLINE IDE.

## Layout & components

9. **Everything centered** — centered hero headline, centered everything.
10. **Card-nesting**: wrapping everything in cards, cards inside cards; uniform 16px radius, identical padding and card heights everywhere. Vary spacing/sizing to build real hierarchy.
11. **Identical feature cards with an icon on top**, three-across.
12. **Numbered "1·2·3" step sequences** and **stat-banner rows** ("10k+ users · 99.9% uptime") as filler.
13. **Sparkle/emoji badges** (✨) and emoji used as UI icons / bullet points. **Never use emoji as icons in any app — use SVG only.** Emoji render at inconsistent sizes/weights across OS and look like a generated app; inline SVG or an SVG sprite is always the substitute.
14. **Colored left-strip/border on list items or cards** — the reflexive `border-left: 3px solid var(--accent)` on every item. Use background tints, icon color, or row-level hierarchy instead. Flagged explicitly by Doug 2026-06-14 on the REDLINE IDE.

## Copy

15. **Vague aspirational headlines**: "Build the future," "Your all-in-one platform," "Scale without limits," "Unlock your potential." Write specific, concrete, founder-voice copy.
16. **Generic superlatives + hedging** padding throughout.
17. **Em dashes are a _contested, weak_ tell — do NOT reflexively purge them.** As of mid-2026 the "em dash = AI" claim is widespread (Reddit/LinkedIn) but heavily pushed back on by writers (McSweeney's, The Ringer, many "in defence of the em dash" pieces); AI overuses them precisely _because_ good human writers always did, and OpenAI added a toggle to suppress them (Nov 2025). So: the em dash itself is not the tell — **high _density_ + uniform rhythm is.** Keep em dashes where they're earned; the fix for "AI feel" is varied sentence structure and a real POV, not banning a centuries-old punctuation mark. (Exception: the **design-taste skill bans em dashes in landing-page/marketing copy** specifically — honor that there.) The deeper tells are structural: flat affect, formulaic sentences, no original idea. Asked by Doug 2026-06-14.

## Imagery

18. **"Diverse team around a laptop in an impossibly well-lit office"** stock photos; **too-smooth, plastic AI illustrations.** Prefer real product screenshots / real photos.

## Motion

19. **Uniform generic fade-ins** with no purpose; missing hover states / buttons that snap instead of ease. Motion should signal state or direct attention.

**Why:** these are the giveaways of vibe-coded sites — they make work look generated, not designed.

Related fuller references: Doug's `web-design-guide` repo and `app-aesthetics-guide`; voice kill-list in `<vault>/Claude/voice.md`. Researched from practitioner sources (925studios "AI slop web design," adriankrebs "design-slop" Show HN scoring, prg.sh "purple gradient," BSWEN anti-patterns). #1–2 first flagged 2026-06-13 on the [[project_client_portal]] landing page. Running list — add new tells as Doug flags them.
