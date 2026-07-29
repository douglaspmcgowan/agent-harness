# Product

## Register

product

## Users

Douglas — a single engineer running this on his own laptop. He's the only user, viewing it
locally (`http://localhost:8756/`) between long stretches of other work, to answer one question at a
glance: which of his long-running dev servers and projects are up, healthy, or need him.

## Product Purpose

A personal ops dashboard: tracks the health of long-running dev servers (start/stop/health-check) and
the status of active longrun/project work (finished, active, blocked, stalled, idle), including
cross-references between related logs and staleness/conflict checks. Success is a correct at-a-glance
read he can trust without opening a terminal — if the dashboard says something is blocked or stale, it
actually is.

## Brand Personality

Terminal-native, honest, utilitarian. Dark monospace palette; plainspoken copy that admits uncertainty
rather than projecting false confidence ("needs Douglas", "nothing appears to be actively driving this
right now"). It should read as a tool an engineer built for himself, not a product demo.

## Anti-references

No generic SaaS dashboard: no hero-metric tiles, no gradient accents, no identical card grids, no
corporate polish for its own sake. Nothing that trades honesty about system state for a more
reassuring-looking UI.

## Design Principles

- Never look more certain than the underlying data is — a stale or conflicting signal must read as
  stale or conflicting, not be smoothed over.
- Read at a glance, act with confidence — anything actionable (start/stop) needs a clear, truthful
  result, not silence.
- Build for an audience of one — no onboarding, no marketing surfaces, no features that only make
  sense with multiple users.
- Match the tool's own register: monospace, dark, plain language over icons/jargon.

## Accessibility & Inclusion

No formal accessibility program — this is a personal, single-user tool and Douglas isn't prioritizing
it as a compliance target. Baseline good practice (readable contrast, keyboard-operable controls) is
still worth maintaining as ordinary quality, not as an accessibility initiative.
