---
name: project-agent-fleet
description: "Doug is building several apps and wants to coordinate a fleet of coding agents off his Claude Max subscription (no API), on Windows 11."
metadata:
  node_type: memory
  type: project
  originSessionId: a952c80d-9804-4a76-a082-953433f59f08
---

Doug runs a **Claude Max subscription** (consumer plan, not API) on **Windows 11** and wants to build several apps while coordinating many coding agents — testing, verifying, and self-generating apps — across versions/branches and "online" (cloud).

**Why:** He wants to drive everything off his subscription seat rather than pay per-token API, and manage agentic workflows well without over-engineering.

**How to apply:**

- Recommend tools that **wrap the official `claude` CLI** (ride the Max login) over tools that need an API key or raw OAuth (those are metered/ToS-risky).
- Default to **native Claude Code** (git worktrees + subagents + Agent Teams) + one Windows GUI (Nimbalyst or Vibe Kanban) + Claude Code on the web for cloud parallelism. Avoid Mac-only (Conductor, Sculptor) and tmux-only (Claude Squad, uzi → need WSL2) tools.
- Key constraint: the **June 15, 2026** billing split moves SDK/`claude -p`/GitHub Actions/third-party-OAuth usage to a small metered credit pool; interactive sessions stay on the fat Max pool. Re-verify live state after that date.
- Practitioner consensus: 2–5 concurrent agents max; human review throughput is the bottleneck. Push specs + verification gates over agent count.
- Detailed research reports live in `Documents/General Claude/agent-research/` (3 files). Note: web-sourced billing/limit specifics decay fast — re-check before relying.
