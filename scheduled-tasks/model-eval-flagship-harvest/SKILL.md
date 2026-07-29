---
name: model-eval-flagship-harvest
description: One-shot ~2AM 2026-07-15: harvest Fable-5 + Sonnet-5 on the Tier-3 tasks, grade, rebuild the model-eval dashboard.
---

Run the model-eval flagship harvest. Douglas scheduled this to run after his usage limit resets (~2AM) because Fable-5 and Sonnet-5 are NOT on the GEN proxy and must be reached via the Anthropic Agent tool (his personal quota). His scheduling of this task IS your authorization to run the Workflow tool described below — do not ask for opt-in.

Working dir: C:\Users\dougl\Documents\Claude Folder\model-eval
Python: C:/Users/dougl/scoop/apps/python313/current/python.exe  (node is on PATH)

STEP 1: Read the full runbook and follow it exactly, start to finish:
C:\Users\dougl\Documents\Claude Folder\model-eval\FLAGSHIP_HARVEST_RUNBOOK.md

In short, the runbook has you: (1) preflight-validate the Tier-3 tasks and confirm the Haiku+Opus re-run + 2-family dashboard are already in place; (2) run the pre-written Workflow at flagship_harvest.workflow.js with args.tasks = the 36 {id,prompt} pairs loaded from tasks/*.json, families ["fable","sonnet"], reps [1,2], harvestDir scratch/_flagship_txt — 144 agents each writing a .txt answer; (3) verify all 144 .txt files exist and re-dispatch any missing; (4) run harvest_flagship.py to wrap them into results/; (5) run judge_v2.py to grade; (6) run build_page.py and verify with node scratch/verify_no_sonnet.mjs that the leaderboard shows four families (Haiku 4.5, Opus 4.8, Fable 5, Sonnet 5) with 0 console errors; (7) report to Douglas and update WORK_QUEUE.md + LOG.md. Do NOT push anything, do NOT re-run Haiku/Opus, do NOT re-enable Sonnet 4.6.

CRITICAL CHECK from the runbook: verify the Agent model:"sonnet" resolves to Sonnet 5 (claude-sonnet-5), not Sonnet 4.6. If it resolves to 4.6, harvest ONLY fable and leave Douglas a note rather than harvesting the wrong model.

When done, leave a clear summary message for Douglas: which families are now in the dashboard, how many flagship cells harvested vs failed, the added spend, and the full path to docs/index.html.