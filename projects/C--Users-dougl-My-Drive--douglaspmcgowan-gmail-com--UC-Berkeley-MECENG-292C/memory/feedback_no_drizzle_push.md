---
name: Never use drizzle-kit push on production databases
description: drizzle-kit push will drop columns and truncate tables to match schema — use manual SQL migrations instead
type: feedback
---

Never recommend `drizzle-kit push` on a database with existing data. It compares the Drizzle schema to the live database and destructively syncs by dropping columns, truncating tables, and deleting data.

**Why:** User almost lost 4 users and 22 workout sessions when drizzle-kit push tried to drop the `score_tier` and `deductions` columns and delete the `session` table. This was on the AI-Fit-Hub project on Replit.

**How to apply:** When new columns are needed, always provide manual `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` SQL statements instead. Only use `drizzle-kit push` on a fresh/empty database.
