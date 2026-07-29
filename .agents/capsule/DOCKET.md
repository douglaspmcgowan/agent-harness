# Docket integration

Source inspected: the tracked Docket repository under `C:\Users\dougl\projects\docket`.

## Credential names

| Boundary | Variable | Purpose |
|---|---|---|
| Publisher and sync client | `REVIEW_SECRET` | Bearer credential sent by `enqueue.js`, `sync-cloud.js`, and `sync.js` |
| Vercel API | `APP_SECRET` | Server-side copy of the same bearer credential, checked by `api/_auth.js` |
| Vercel Blob | `BLOB_READ_WRITE_TOKEN` | Provider-managed storage credential used by the cloud store |
| Optional client endpoint | `REVIEW_URL` | Docket base URL; this is configuration rather than a secret |

The repository reveals the required key name: `REVIEW_SECRET`. A credential value cannot be reconstructed from Git history because the repository contains only variable names and lookup code. Put one bearer value in Bitwarden under hidden field `REVIEW_SECRET`, then map that same value into Vercel under environment-variable name `APP_SECRET`. Keep `BLOB_READ_WRITE_TOKEN` separate. Do not create a duplicate `APP_SECRET` Bitwarden field.

## Reviewed upload path

Use `sync-cloud.js` for bulk publication from the local Docket store:

1. It reads the local store.
2. It selects every valid unresolved personal card with a non-empty string ID.
3. It excludes IDs already resolved or archived in the local store.
4. It sends `POST /api/sync?op=push` with `Authorization: Bearer ...` and body `{ "items": [...] }`.
5. The API upserts cards by stable `id` and reports `pushed` and `refused` counts.
6. It calls `GET /api/sync?op=pull`.
7. It accepts only well-formed, timestamped decisions for cards already present in the local item store.
8. It merges a cloud decision only when it is newer than the local decision.

This is the personal Docket. Every valid unresolved personal card may publish to its password-protected cloud board. Local resolved or archived IDs remain excluded. The old `sensitive` field remains readable for backward compatibility and no longer blocks authenticated bulk sync. New unresolved cards publish to the cloud by default.

The personal cloud-sync changes are merged through Docket pull request #2 at commit `32d2346`. The current reconciliation found 162 local items, archived two stale setup cards, and left 160 cards outbound.

The browser records decisions through `POST /api/submit`. Producers retrieve those decisions through `GET /api/sync?op=pull`; the decisions are not separate card uploads.

## Verify

From the Docket repository:

```powershell
node .\enqueue.js --selftest
node .\sync-cloud.js --selftest
npm.cmd test
```

Use `node .\enqueue.js --archive <id>` for a reviewed archival decision. The command strictly verifies cloud archival before accepting the operation.

## Authenticated publication gate

Publication requires:

1. Bitwarden Login item `project:docket:production`.
2. Hidden field `REVIEW_SECRET`.
3. Hidden field `BLOB_READ_WRITE_TOKEN` for the separate Vercel Blob credential.
4. The reviewed bearer credential configured in Vercel as `APP_SECRET`.
5. The storage credential configured in Vercel as `BLOB_READ_WRITE_TOKEN`.
6. A reviewed broker tuple that injects `REVIEW_SECRET` only into the exact Node command for `sync-cloud.js`.

The existing policy authority is `C:\Users\dougl\.agents\tools\credential-command-policy.json`; extend that file instead of creating another policy. The value-free tuple is:

| Field | Value |
|---|---|
| Bitwarden item | the non-secret item ID for `project:docket:production` |
| Hidden field | `REVIEW_SECRET` |
| Destination environment variable | `REVIEW_SECRET` |
| Executable | the resolved absolute path returned for `node.exe` |
| Only argument | `C:\Users\dougl\projects\docket\sync-cloud.js` |

After the tuple is registered, run the existing credential broker for that tuple. The resulting `sync-cloud.js` pass publishes every valid unresolved personal card and pulls guarded decisions. Local resolved or archived IDs remain excluded. The bearer credential remains outside the repository, Capsule, command arguments, and transcripts.
