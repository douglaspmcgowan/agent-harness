---
name: Onboarding — tour + tutorial + help modal by default
description: Pointer to the Onboarding Trio playbook. Every new web app with state ships with all three onboarding paths reachable from a single "?" button in the masthead.
type: feedback
originSessionId: e3c49699-5ef3-4f60-a0cf-989663e728be
---

**Canonical:** [`playbooks/build-playbook.md`](../../../../../G:/My Drive/UC Berkeley/Research/Claude Research Folder/playbooks/build-playbook.md) → "Phase 6: Onboarding Trio". Follow that doc; this memory is just the auto-load hook.

**The rule in one line:** Every new web app I scaffold for Doug ships with three onboarding paths — first-run tour, opt-in tutorial, help modal — all reached from a single "?" button.

**Why:** Doug asked for a tour first, then later asked for a separate full tutorial that walks through the *mindset* of the tool with the user filling in real data as they go. He also wanted the "?" button to behave like other apps' help icons — opening a "What is this?" panel rather than re-running the tour. The three are not interchangeable.

**How to apply:**
- When scaffolding a new app with state, open the build-playbook Phase 6 section and follow it.
- "?" wires to the modal, **not** directly to the tour. Modal hands off to whichever flow the user picks.
- Reuse one spotlight/tooltip engine for both tour and tutorial; differentiate via an `interactive` class and different step arrays.

**Reference implementation:** `~/168-audit/server.js` — search for `tourSteps`, `tutorialSteps`, `openHelpModal`.

**Doesn't apply to:** tiny single-form utilities or content-only sites (docs, blogs, marketing pages).
