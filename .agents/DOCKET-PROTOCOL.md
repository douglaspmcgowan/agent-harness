# Cross-platform Docket protocol

Last verified: 2026-07-29

## Purpose and authority

Docket is the shared review queue for briefs, review items, and decisions produced by Claude, Codex, and Cursor.

- Source repository: `C:\Users\dougl\projects\docket`
- Canonical local store: `C:\Users\dougl\.docket-local\docket.sqlite3`
- Portable local exports: `items.json`, `results.json`, `tickets.json`, and `reads.json` beside the database
- Loopback board: `http://127.0.0.1:8471`
- Authenticated cloud board: `https://vault-review-mobile.vercel.app`

The local adapter uses SQLite as its authority and writes readable JSON exports in the same mutation path. Vercel uses its own private Blob persistence. Local and cloud storage remain separate, with explicit authenticated synchronization between them.

## Verified state

The local store contains 162 cards. Two cards have archived results, leaving 160 unresolved cards eligible for authenticated cloud publication.

Authenticated publication is pending the Bitwarden `REVIEW_SECRET` setup and matching Vercel `APP_SECRET`. The repository contains credential names and value-free configuration only.

## Card rules

- Reuse the existing Docket repository, client, card schema, groups, and stable IDs.
- Use one card for each independently reviewable brief, artifact, or decision.
- Give repeated content the same stable ID so later writes update the living card.
- Mark a card blocking only when its answer gates active work, then record `[?] docket <id> - <title>` in project task state.
- Keep secret values, session tokens, recovery keys, and private-record content out of cards.
- Treat the existing `sensitive` field as historical metadata. It does not filter authenticated personal publication.

## Local-to-cloud flow

1. An agent creates or updates a validated card through `enqueue.js` or the local loopback service.
2. The local adapter commits the mutation to SQLite and refreshes its JSON export.
3. `sync-cloud.js` reads local `items.json` and `results.json`.
4. Every local card ID already present in `results.json` is excluded from the outbound set.
5. The authenticated sync pushes the unresolved set and pulls newer decisions.
6. Pulled decisions are accepted only for known local card IDs and merged into local durable state.

This policy currently yields 160 outbound unresolved cards from 162 total cards and 2 archived results.

## Strict archive acknowledgement

Use `enqueue.js --archive <id>` to retire a card already present in the cloud board. The command reports success only when the cloud response:

- succeeds at the HTTP layer;
- returns the requested card ID;
- returns `success:true`;
- returns `archived:true`; and
- includes a non-empty answer timestamp.

Any mismatch fails the archive operation.

## Credential boundary

- `REVIEW_URL` is the non-secret cloud endpoint.
- Bitwarden holds the hidden `REVIEW_SECRET` field.
- Vercel receives the same bearer value as `APP_SECRET`.
- `BLOB_READ_WRITE_TOKEN` is a separate provider-managed storage credential.
- The full-tuple broker injects `REVIEW_SECRET` into the approved Docket process environment for one exact command.
- Credential values stay outside files, command arguments, logs, Git, and transcripts.

## Verification

Run these offline checks after changing the Docket client or sync policy:

```powershell
node "C:\Users\dougl\projects\docket\enqueue.js" --selftest
node "C:\Users\dougl\projects\docket\sync-cloud.js" --selftest
```

A publication claim also requires an authenticated client response and the returned card ID.
