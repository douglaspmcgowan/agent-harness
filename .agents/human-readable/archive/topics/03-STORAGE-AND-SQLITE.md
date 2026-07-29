# Storage, local data, and SQLite

Last verified: 2026-07-26

## Recommended model

```text
C:\Users\dougl\projects\<project>              versioned source and project instructions
C:\Users\dougl\Data\Projects\<project>         valuable local application data
C:\Users\dougl\Data\Restricted\<project>       data needing tighter access and explicit approval
C:\Users\dougl\Worktrees\<repository>\<task>   manual isolated source work
```

Project data remains grouped by project. The separate `Data\Projects\<project>` root gives every worktree one stable address, avoids copying a live database into every worktree, and allows distinct backup and retention rules.

An ignored `data` subfolder inside a repository is useful for disposable cache and small local fixtures. It is a fragile sole home for valuable records because repository cleanup, deletion, worktree duplication, and agent searches all operate near it.

## What belongs in GitHub

Commit source, tests, documentation, schemas, migrations, manifests, and small safe fixtures.

Keep credentials, real personal records, mutable application databases, large corpora, proprietary inputs, and generated output archives outside Git. `.gitignore` tells Git to leave matching files untracked. It does not hide, encrypt, back up, or protect those files.

## Plain files

Use ordinary files when humans work with each object directly:

- Markdown notes;
- PDFs, images, audio, and documents;
- JSON/YAML configuration;
- immutable datasets;
- exported CSV;
- append-only logs.

Files remain easy to inspect, copy, sync, and restore.

## SQLite

SQLite is a library and file format for a local relational database. The installed CLI is:

```text
C:\Users\dougl\Tools\sqlite\sqlite3.exe
Version 3.53.4
```

Use SQLite when an app needs transactions, relationships, uniqueness rules, indexes, repeated queries, or coordinated changes across multiple records. SQLite's own guidance highlights local application storage and low-writer-concurrency use. [Appropriate Uses for SQLite](https://www.sqlite.org/whentouse.html), [SQLite CLI](https://sqlite.org/cli.html).

### Example app

A fellowship tracker may contain:

- fellowships;
- organizations;
- contacts;
- application deadlines;
- application status history;
- required documents;
- reminders;
- notes and links.

SQLite can answer “show open applications due in the next 30 days whose recommendation letters are incomplete,” enforce one status history record per event, and update an application and reminder together in one transaction. The actual PDFs and essays remain ordinary files; the database stores paths and structured metadata.

### Why files alone become awkward

Separate JSON files can work for small prototypes. As relationships and concurrent edits grow, the application must reimplement locking, atomic writes, indexing, migrations, validation, and recovery. SQLite supplies those features while keeping the database in one local file.

### Required database practices

- Store the live database under `Data\Projects\<project>\runtime`.
- Keep schema migrations in the repository.
- Use a task-specific test database in each worktree.
- Export critical records to a portable format periodically.
- Back up the database using a SQLite-safe method.
- Test restoration.
- Keep real-record databases out of Git.

## Restricted data

Restricted data includes records whose exposure would create meaningful privacy, legal, contractual, identity, or security harm. Place it in `Data\Restricted\<project>`, narrow Windows permissions, exclude it from Git and ordinary cloud sync, and require task-specific approval before an agent accesses it.

The label is a handling boundary. Each project manifest explains the specific reason and permitted uses without copying sensitive content into the manifest.

