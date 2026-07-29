---
name: boss-update
description: "Synthesize your daily reports over a date range into an UPWARD status update for a boss or research advisor/professor — outcome-only, no process. First brings the daily reports current to the nearest date (runs /daily-activity catch-up to backfill missing days), then reads each day's report and rolls it up into what you'd actually tell a manager: what you did, what changed, the big things, what you learned, what's interesting, how you're doing, deliverables, and open questions/asks. Strips the internal process detail (debugging arcs, playbook edits, automation candidates, commit tables). Use when Douglas says 'boss update', 'update for my boss', 'research update', 'work update', 'professor update', 'advisor update', 'status update for my boss', or '/boss-update'."
---

# /boss-update [date-range] [--for boss|advisor]

You are writing what a busy manager or research advisor actually wants: outcomes, not process. This rolls up
your own daily reports across a range into a short upward update — what got done, what changed, what's
interesting, how it's going, what you shipped, and what you need from them. It reads the daily reports as the
source of truth (bringing them current first), then reports *outcomes* and drops the internal mechanics.

## What this is NOT

- **Not `/daily-activity`** (or the other machine's `/daily-review`). Those write the per-day INTERNAL report
  — activity threads plus a review appendix of debugging arcs, auto-applied playbook edits, and automation
  candidates. `/boss-update` is the opposite direction: it CONSUMES many of those days and produces one
  UPWARD, outcome-only summary for someone else, deliberately stripping the process detail those reports carry.
- **Not `/handoff`.** `/handoff` hands your work to the next *session* (internal continuity). `/boss-update`
  hands a summary to a *person above you* (external-facing).
- **Not `/consolidate` / `/save-context`.** Those maintain internal durable state. This produces a sendable
  status update.

## Steps

### 0 — Resolve the range and the audience
- **Range.** Accept an explicit range ("last week", "June 1–13", "since my last update") or default to **since
  the last `/boss-update` note** (check the Updates folder below); if none exists, default to the **last 7
  days**. Compute concrete start/end dates and use them consistently.
- **Audience** (`--for boss|advisor`, or infer from the ask). **Boss/manager** → weight deliverables, status,
  and asks. **Advisor/professor** → weight what you learned, what's interesting/novel, and open research
  questions. Default to boss if unstated. Ask only if the range is genuinely ambiguous.

### 1 — Bring the daily reports current (to the nearest date)
Run the `/daily-activity` **catch-up** so the range has complete data up to the nearest available date:
backfill every missing day from the last report through today. `/daily-activity`'s own guard confirms with
Douglas before scanning more than 14 missing days, so honor that. Then list the
`C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\Daily Reports\YYYY-MM-DD.md` files that fall in the resolved
range (ignore `.vN` variants; today's may be partial — use it anyway and note it's partial).

### 2 — Read each day and extract only the boss-relevant signal
Read each daily report in range. For a range longer than ~10 days, dispatch a subagent per chunk to extract
the signal so the main context stays lean, then merge. From each day pull ONLY:
- **Accomplishments** — the activity threads' what+why (in outcome terms), grouped by project/theme.
- **Decisions & pivots** — direction changes, choices made (from thread descriptions and loose ends).
- **Deliverables** — concrete outputs: decks, sites/deploys, tools, agent packs, papers, vault notes.
- **Learnings & interesting findings** — memory writes and any notable result worth surfacing.
- **Open questions / blockers** — unresolved loose ends, anything needing a decision.

**Drop the internal mechanics**: debugging arcs, auto-applied playbook edits, automation candidates, commit
tables, session-size notes. Those are for you, never for a boss.

### 3 — Synthesize the upward update
Before drafting the prose, read `~/.claude/voice.md` (this is copy Douglas will send — publishable-prose rules
and the "X, not Y" antithesis ban apply). Write it concise and outcome-first, in these sections (rename/merge
to fit the specific update; keep it skimmable in under two minutes):

- **Headline** — 1–2 sentences: the big picture and how it's going.
- **What I did** — accomplishments, grouped by theme, phrased as outcomes.
- **What changed** — decisions, pivots, direction shifts.
- **The big things** — the 2–4 items that actually matter this period.
- **What I learned** — findings/lessons worth sharing.
- **What's interesting** — things genuinely worth their attention.
- **How I'm doing** — status/health: on-track, ahead, behind, or blocked, said plainly.
- **Deliverables** — concrete outputs with links/paths.
- **Questions & asks** — open questions and decisions/things you need from them.

Cut a section if there's nothing real for it — an empty section is worse than a missing one. No process
minutiae, no editorializing, no smoothing over a slow week.

### 4 — Write it where it lives, and report
Write to `C:\Users\dmcgowa2\Documents\NASA_GSFC_Vault_1\Updates\<start>_to_<end> <boss|advisor> update.md`
(create the `Updates` folder if needed; never overwrite a prior update — version the filename). Then output to
chat: a 3–5 line TL;DR of the update plus the full absolute path, per the standing Files-list convention.

## Constraints
- **Read-only over the daily reports** themselves. The only writes are (a) the `/daily-activity` catch-up it
  triggers, which writes/backfills daily reports by design, and (b) the new update note.
- **Never overwrite Douglas's authored files.** The update note is a new, versioned file.
- **Outcomes over process, every time.** If a section is drifting into "here's how I debugged X," cut it.
- **Honest status.** Name a slow period or a blocker plainly; do not inflate a thin week into a strong one.
