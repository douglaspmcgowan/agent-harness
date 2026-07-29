---
name: edge-case-tests-default
description: "Any new web app's v1 Playwright suite must include the 10-class edge-case checklist from playwright-playbook.md Phase 4"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c5df5718-91a3-4d0a-baf3-631c2f647901
---

When writing a v1 Playwright test suite for a new web app, don't stop at happy-path tests. Default to including the 10-class edge-case checklist.

**Why:** Happy-path-only suites miss the bugs that actually cause production incidents. Established after several regressions that Playwright would have caught with broader coverage.

**How to apply:** Check Phase 4 of `G:\My Drive\UC Berkeley\Research\Claude Research Folder\playwright-playbook.md` for the 10-item checklist: bounds, long text, special chars, persistence, empty state, quota, multi-tab, keyboard, mobile, print. At minimum add a comment in the test file with which classes are covered and which are deferred.
