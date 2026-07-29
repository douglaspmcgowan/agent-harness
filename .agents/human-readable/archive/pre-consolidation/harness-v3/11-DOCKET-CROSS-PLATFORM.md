# Docket cross-platform review workflow

Last runtime verification recorded: 2026-07-27

Runtime, deployment, scheduled-task, card-count, and credential-readiness claims below are dated evidence. Recheck their owning services before presenting them as current.

## 2026-07-26 recovery update

The ZIP64 recovery restored the complete Docket source and Git bundle. The canonical runtime clone is `C:\Users\dougl\projects\docket`; the old workspace copy remains the writable source for this active session.

The private Git authority is `https://github.com/douglaspmcgowan/docket`. The loopback-authentication repair is published on `master` at commit `33b00f4`.

The 157 Skills Audit cards remain in the local outbox. Publishing requires `REVIEW_SECRET` or a Bitwarden-managed equivalent; no matching Process, User, or Machine environment variable is currently present.

## What Docket is

Docket is the persistent phone-friendly review board at `https://vault-review-mobile.vercel.app`. It stores briefs, review items, and structured decisions. Claude, Codex, and Cursor should produce the same card schema and stable identifiers.

## Dated verified state

- The cloud application returns HTTP 200.
- The board requires a passcode.
- The local SQLite authority is `C:\Users\dougl\.docket-local\docket.sqlite3`.
- The limited-privilege `DocketDaemon` scheduled task starts the canonical clone at logon.
- The loopback UI and API listen on `127.0.0.1:8471`.
- The local API validates the peer socket and adds an in-process trust marker; an HTTP header cannot spoof it.
- Cloud authentication still fails closed when `APP_SECRET` is absent.

The 2026-07-27 record says the cloud board remained usable for human triage and automated publication was paused pending credential setup. Brief 09 now carries the current Password Manager Login-item and Hidden-field decision for multi-project local secrets.

## Durable outbox

Agents generate credential-free cards under:

```text
C:\Users\dougl\Data\Projects\agent-harness\docket-outbox\
```

`Build-SkillsDocket.cmd` converts per-skill audit JSONL into one card per skill. Cards use project `Skills Audit` and sets derived from portability status and severity. The builder owns an exclusive outbox lock for the complete write-and-archive transaction; a concurrent builder fails closed before changing cards.

## Cross-platform contract

1. Classify sensitivity.
2. Build a self-contained card with stable ID.
3. Validate it locally.
4. Publish through a reviewed credentialed client.
5. Verify the returned ID.
6. Record blocking cards in task state.
7. Pull decisions and update the durable source file.

Harness and skill-audit cards may be public/personal. Credential details, recovery keys, restricted records, NASA-internal material, CUI, and ITAR remain local.

## Restore path

Restore the client from the private `douglaspmcgowan/docket` repository. Restore local review state from the current or previous JSON export when SQLite recovery is needed. The publisher refuses cloud transmission for sensitive cards, accepts secrets only at runtime, binds an exact executable and argument list, verifies response IDs, and preserves stable-ID updates.

## Local SQLite and GitHub state

The Codex GitHub connector and GitHub CLI can operate on the existing private repository. The CLI stores its authorization in the Windows keyring, and `gh auth setup-git` configures reusable Git HTTPS credentials for later sessions.

The laptop-local backend uses SQLite as its authority. Every successful mutation writes a current portable JSON export and keeps the immediately previous export. Existing JSON stores import lazily on first read. Vercel keeps private Blob persistence because serverless local files are ephemeral.

The SQLite patch was also replayed in an isolated worktree. All 67 tests passed, Gitleaks found zero leaks, and the temporary worktree and branch were removed cleanly.

The Skills Docket publisher needs the Docket review credential. `REVIEW_SECRET`, `BW_SESSION`, and `BWS_ACCESS_TOKEN` are absent from process, user, and machine environment scopes.

The installed Secrets Manager broker has one exact Docket approval: Node running `sync-cloud.js`. After Douglas creates the Bitwarden secret and provides a current-process `BWS_ACCESS_TOKEN`, an agent can run that broker to push the explicitly public local cards and pull decisions. The Docket child cannot inherit the bootstrap token.

## Local Skills Docket

`import-outbox.js` validates a card directory, merges cards by stable ID, and writes through Docket’s local SQLite adapter. The final 157-card audit is imported into `C:\Users\dougl\.docket-local\docket.sqlite3`; `items.json` is the readable recovery export. The loopback-only server returned HTTP 200 at `http://127.0.0.1:8471/` during verification.

The importer and loopback trust boundary have unit and integration coverage. The complete Node suite has 73 passing tests. The local store contains 162 cards: 157 skill-audit cards and five setup handoffs.

The limited-privilege `DocketDaemon` scheduled task starts the loopback-only server from `C:\Users\dougl\projects\docket` at logon.
