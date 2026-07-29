---
name: build-tracker
description: Build a new personal deadline/application tracker from the conference-tracker reference implementation. Use when the user says "build a tracker for X", "make a fellowship tracker", "job application tracker", "create a deadline tracker", or any domain that involves tracking items with deadlines, status, and personal notes. Adapts the conference-tracker architecture (calendar, cards, table, map views + iCal + localStorage notes) to a new domain.
---

# /build-tracker [domain description]

## Argument

The user passes a description of the domain. Minimum useful input:

> "Job applications — companies, role, apply deadline, interview date"

If they just say `/build-tracker` with no argument, go to Phase 1 to gather it.

---

## Phase 1 — Clarify the domain (skip if argument is complete)

Ask in a single message — do not ping-pong:

1. **What are the items?** (conferences, fellowships, jobs, grants, journal submissions…)
2. **What's the primary deadline field?** (apply deadline, submission deadline, review deadline…)
3. **What's the main taxonomy?** (job → field/type/company tier; fellowship → funding body/field; journal → field/impact tier)
4. **How many items do you expect to track?** (10–30 / 50–150 / 200+)
5. **Do you want a geographic map view?** Only useful if items have city/country locations.

If input is enough to answer these, skip directly to Phase 2.

---

## Phase 2 — Read the reference files

Read both in parallel before writing any code:

```
Read: Claude Research Folder/dashboard-tracker-playbook.md
Read: Claude Research Folder/conference-tracker/server.js
```

The playbook has the architecture decisions. The server.js is the actual template — every component (CSS tokens, card HTML, modal, calendar, tooltip, filters) is already working code. Do not invent from scratch; adapt from the source.

Key sections of server.js to internalize before touching anything:

- CSS variables block (`--accent`, `--ink`, `--paper`, `--dur-in`, etc.) — copy verbatim
- `getCSS()` function — all styling; carry over token system intact
- `buildPage()` — masthead, view tabs, filter bar HTML structure
- `FIELDS` object — replace field names/colors for the new domain
- `renderCards()`, `renderTimeline()`, `renderTable()`, `renderMap()` — adapt data field references only; keep rendering logic intact
- `openDetail()` modal — update which fields are shown in the detail panel
- `buildICS()` — update field references for deadline dates

---

## Phase 3 — Define the domain model

Before writing any code, write out the adapted data shape in chat for the user to confirm:

```js
// [Domain] item shape
{
  id: "[slug]-[year]",          // e.g. "google-swe-2026"
  name: "",                      // short display name
  fullName: "",                  // full organization/program name
  year: 2026,
  fields: ["[FieldA]"],          // canonical taxonomy tags
  tier: "A*",                    // adapt tier labels to domain
  deadline: "2026-09-11",        // primary deadline
  // domain-specific extra fields:
  [extraField1]: "",
  [extraField2]: "",
  location: { city: "", country: "" },
  link: "",
  fit: "",                       // "why this item matters to me" note
  confidence: "verified"
}
```

Map the domain to the field taxonomy. Use 6–12 fields max. Pick colors that don't clash — use the same hue/saturation range as conference-tracker's FIELDS object.

Show the proposed field map and tier labels. Wait for a thumbs-up before Phase 4.

---

## Phase 4 — Scaffold the new tracker

### 4a. Create directory structure

```
[domain-name]-tracker/
├── server.js            ← adapted from conference-tracker
├── data/items.js        ← generated or stub
├── scripts/
│   └── refresh-data.js  ← adapted merge script
├── research/
│   └── agent-1-stub.md  ← stub or real research
├── tests/
│   └── verify-live.mjs  ← adapted Playwright suite
├── vercel.json
└── package.json
```

### 4b. Adapt server.js — the only changes needed

Copy conference-tracker/server.js and make **only** these substitutions:

| What to change        | How                                                                                                                                   |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Page title + eyebrow  | Update `buildPage()` title/brand strings                                                                                              |
| `FIELDS` object       | Replace with domain field names + colors                                                                                              |
| Tier labels           | Update `normTier()` in refresh script; update chip labels in HTML                                                                     |
| Data field references | In `renderCards()`, `renderTable()`, `openDetail()`: swap `c.deadline`, `c.conferenceStart`, `c.location` etc. for domain field names |
| iCal events           | In `buildICS()`: update which date fields generate VEVENTs, update summary strings                                                    |
| Stats line            | Update the `#stats` innerText to show domain-appropriate counts                                                                       |
| Favicon SVG           | Optionally swap the compass crosshair for a domain-appropriate icon (keep same structure)                                             |
| Filter chips          | Update `#fieldChips` and `#tierChips` to use domain taxonomy                                                                          |
| `window.__DATA__`     | Rename `conferences` → `items` (or keep for minimal diff)                                                                             |

Do **not** change: CSS token values, hover timing, modal structure, calendar rendering, tooltip logic, hash-state system, localStorage keys pattern, iCal RFC structure.

### 4c. Adapt data/items.js

If the user has data ready: parse it into the domain model and write `data/items.js`.

If starting from scratch: write a stub with 3–5 sample items so the UI renders during dev. Note which fields are `null` / `"TBA"`.

### 4d. Adapt scripts/refresh-data.js

Copy conference-tracker/scripts/refresh-data.js. Update:

- `fieldMap` and `canon()` for the new taxonomy
- `normTier()` if tier labels changed
- Field names in the `cleaned` map function
- The `fields` object at the bottom

### 4e. Adapt tests/verify-live.mjs

Copy conference-tracker/tests/verify-live.mjs. Update:

- Title string check
- Brand eyebrow check
- `dataInfo.confs` → use domain plural (`dataInfo.items`)
- Stats regex
- Any domain-specific filter chip test (swap `data-field="HCI"` → domain equivalent)

---

## Phase 5 — Verify locally

```
npm install
node server.js
# → http://localhost:[port]
node tests/verify-live.mjs http://localhost:[port]
```

All checks should pass. Fix any that fail before proceeding.

If a check fails that's cosmetic (wrong count assertion in test), update the test assertion — don't ship broken tests.

---

## Phase 6 — Initial data (if starting from scratch)

If the user needs real data and doesn't have it, offer to run a deep-research pass:

> "Want me to populate the initial dataset? I can run parallel research agents for each field category and generate the research/\*.md files, then merge them into data/items.js."

If yes: dispatch parallel `general-purpose` agents — one per field cluster — with this brief:

> "Research [domain] items in the [field] category. For each item found, produce a JSON object matching this schema: [paste domain model]. Return a JSON block at the end of the file. Aim for 15–30 items with complete deadline dates. Mark confidence 'verified' only if you found the deadline on an official source."

Merge with `node scripts/refresh-data.js`.

---

## Phase 7 — Deploy

```bash
git init && git add -A && git commit -m "init: [domain] tracker"
gh repo create [domain]-tracker --public --source=. --push
npx vercel --yes --prod --name [domain]-tracker
```

Verify: `curl -s -o /dev/null -w "%{http_code}" https://[domain]-tracker.vercel.app`

---

## Guardrails

- **Never** change the CSS token values — `--accent`, `--ink`, `--paper`, the timing variables. These are the design system. Changing them makes the site inconsistent with the rest of the family.
- **Never** add a build step, a bundler, or a framework. The entire point of the pattern is zero-config deploy.
- **Never** rewrite rendering functions from scratch — adapt them. The calendar, gantt, and tooltip logic have subtle interactions that take time to debug.
- If a view doesn't make sense for the domain (e.g., map is useless because all items are remote), disable it with a hidden `view-tab` rather than deleting the code. Easier to re-enable.

---

## Output contract

When done, report:

1. Path to the new tracker directory
2. Whether tests pass and how many checks
3. Live URL if deployed
4. Which fields were left as stubs / need real data
5. Whether a `/schedule` biweekly data refresh routine was set up
