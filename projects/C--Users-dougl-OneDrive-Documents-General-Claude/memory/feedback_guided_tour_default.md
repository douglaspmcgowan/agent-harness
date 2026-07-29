---
name: guided-tour-default
description: Any new web app with state should ship with a guided tour + help modal; pointer to the build-playbook Phase 6 pattern
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c5df5718-91a3-4d0a-baf3-631c2f647901
---

For any new web app that has meaningful state or non-obvious UX, default to including a guided tour, tutorial flow, and help modal as part of the v1 deliverable — not a "nice to have."

**Why:** Apps without onboarding create confusion at handoff and demo time. This was established after several shipped apps that needed a tutorial retrofit.

**How to apply:** When writing a new web app, check Phase 6 of `G:\My Drive\UC Berkeley\Research\Claude Research Folder\playbooks\build-playbook.md` for the tour + tutorial + help modal pattern before considering the app "done." Applies to any app with: multiple views, local storage state, or non-obvious button actions.
