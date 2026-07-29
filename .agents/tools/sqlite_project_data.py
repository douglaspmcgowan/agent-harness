#!/usr/bin/env python3
"""Create and restore transactionally consistent SQLite snapshots."""

from __future__ import annotations

import argparse
from contextlib import closing
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import stat
import sys
import tempfile
import uuid


RESERVED_WINDOWS_NAMES = re.compile(
    r"^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$", re.IGNORECASE
)


def utc_stamp() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def validate_project_name(name: str) -> str:
    if (
        not name
        or name in {".", ".."}
        or name.rstrip(" .") != name
        or "/" in name
        or "\\" in name
        or re.search(r'[<>:"|?*\x00-\x1f]', name)
        or RESERVED_WINDOWS_NAMES.match(name)
    ):
        raise ValueError("unsafe project name")
    return name


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_reparse_point(path: Path) -> bool:
    try:
        attributes = getattr(path.lstat(), "st_file_attributes", 0)
    except FileNotFoundError:
        return False
    return bool(attributes & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0))


def assert_plain_ancestors(path: Path, label: str) -> None:
    absolute = Path(os.path.abspath(path))
    existing: list[Path] = []
    current = absolute
    while True:
        if current.exists() or current.is_symlink():
            existing.append(current)
        if current.parent == current:
            break
        current = current.parent
    for candidate in reversed(existing):
        if candidate.is_symlink() or is_reparse_point(candidate):
            raise ValueError(f"{label} contains a reparse-point ancestor")


def assert_contained(path: Path, root: Path, label: str) -> None:
    path_absolute = Path(os.path.abspath(path))
    root_absolute = Path(os.path.abspath(root))
    try:
        common = Path(os.path.commonpath((path_absolute, root_absolute)))
    except ValueError as error:
        raise ValueError(f"{label} is outside its declared root") from error
    if os.path.normcase(str(common)) != os.path.normcase(str(root_absolute)):
        raise ValueError(f"{label} is outside its declared root")


def sqlite_backup(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    source_uri = source.resolve().as_uri() + "?mode=ro"
    with closing(sqlite3.connect(source_uri, uri=True)) as source_db:
        with closing(sqlite3.connect(destination)) as destination_db:
            source_db.backup(destination_db)
            result = destination_db.execute("pragma integrity_check").fetchone()
            if not result or result[0] != "ok":
                raise RuntimeError("SQLite integrity check failed")


def write_atomic_text(path: Path, content: str) -> None:
    temporary = path.with_name(path.name + f".partial-{uuid.uuid4().hex}")
    temporary.write_text(content, encoding="utf-8")
    os.replace(temporary, path)


def snapshot_directory(sync_root: Path, project_name: str, database: Path) -> Path:
    safe_database_name = database.name.replace(" ", "-")
    return sync_root / project_name / "sqlite" / safe_database_name


def snapshot_created_utc(snapshot: Path) -> dt.datetime:
    metadata_path = snapshot.with_suffix(snapshot.suffix + ".json")
    try:
        created = json.loads(metadata_path.read_text(encoding="utf-8"))["createdUtc"]
        parsed = dt.datetime.fromisoformat(str(created).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone(dt.timezone.utc)
    except (KeyError, TypeError, ValueError, json.JSONDecodeError):
        match = re.match(r"^(\d{8}T\d{6}Z)-", snapshot.name)
        if not match:
            raise RuntimeError(f"snapshot creation time is invalid: {snapshot.name}")
        return dt.datetime.strptime(match.group(1), "%Y%m%dT%H%M%SZ").replace(
            tzinfo=dt.timezone.utc
        )


def list_snapshots(directory: Path) -> list[Path]:
    if not directory.is_dir():
        return []
    snapshots = (
        path
        for path in directory.glob("*.sqlite3")
        if not path.name.endswith(".partial.sqlite3")
        and path.with_suffix(path.suffix + ".sha256").is_file()
        and path.with_suffix(path.suffix + ".json").is_file()
    )
    return sorted(
        snapshots,
        key=lambda path: (
            snapshot_created_utc(path),
            path.with_suffix(path.suffix + ".json").stat().st_mtime_ns,
            path.stat().st_ctime_ns,
        ),
        reverse=True,
    )


def prune_snapshots(
    directory: Path, daily: int, weekly: int, monthly: int, apply: bool = False
) -> dict[str, object]:
    snapshots = list_snapshots(directory)
    retained: set[Path] = {snapshots[0]} if snapshots else set()
    daily_buckets: set[tuple[int, int]] = set()
    weekly_buckets: set[tuple[int, int]] = set()
    monthly_buckets: set[tuple[int, int]] = set()

    for snapshot in snapshots:
        created = snapshot_created_utc(snapshot)
        daily_key = (created.year, created.timetuple().tm_yday)
        iso_year, iso_week, _ = created.isocalendar()
        weekly_key = (iso_year, iso_week)
        monthly_key = (created.year, created.month)

        if daily > 0 and daily_key not in daily_buckets and len(daily_buckets) < daily:
            daily_buckets.add(daily_key)
            retained.add(snapshot)
        if weekly > 0 and weekly_key not in weekly_buckets and len(weekly_buckets) < weekly:
            weekly_buckets.add(weekly_key)
            retained.add(snapshot)
        if monthly > 0 and monthly_key not in monthly_buckets and len(monthly_buckets) < monthly:
            monthly_buckets.add(monthly_key)
            retained.add(snapshot)

    deleted = [snapshot for snapshot in snapshots if snapshot not in retained]
    restore_verified = False
    if apply and deleted:
        newest = snapshots[0]
        verified_snapshot(newest)
        with tempfile.TemporaryDirectory(prefix="sqlite-restore-proof-") as probe_root:
            restore_probe = Path(probe_root) / "restored.sqlite3"
            sqlite_backup(newest, restore_probe)

        restore_verified = True
        for snapshot in deleted:
            for artifact in (
                snapshot,
                snapshot.with_suffix(snapshot.suffix + ".sha256"),
                snapshot.with_suffix(snapshot.suffix + ".json"),
            ):
                if artifact.exists():
                    artifact.unlink()

    return {
        "Applied": apply and bool(deleted),
        "RestoreVerified": restore_verified,
        "Retain": [str(snapshot) for snapshot in snapshots if snapshot in retained],
        "Delete": [str(snapshot) for snapshot in deleted],
    }


def export_snapshot(args: argparse.Namespace) -> dict[str, object]:
    local_root = Path(args.local_root)
    sync_root = Path(args.sync_root)
    database = Path(args.database)
    assert_plain_ancestors(local_root, "local project-data root")
    assert_plain_ancestors(sync_root, "project-data sync root")
    assert_plain_ancestors(database, "SQLite database path")
    assert_contained(database, local_root, "SQLite database path")
    database = database.resolve()
    if not database.is_file():
        raise FileNotFoundError("local SQLite database is missing")
    directory = snapshot_directory(
        sync_root.resolve(), validate_project_name(args.project), database
    )
    assert_plain_ancestors(directory, "SQLite snapshot destination")
    directory.mkdir(parents=True, exist_ok=True)
    nonce = uuid.uuid4().hex[:8]
    snapshot = directory / f"{utc_stamp()}-{nonce}.sqlite3"
    temporary = snapshot.with_name(snapshot.name + f".partial-{uuid.uuid4().hex}")
    try:
        sqlite_backup(database, temporary)
        checksum = sha256(temporary)
        os.replace(temporary, snapshot)
        checksum_path = snapshot.with_suffix(snapshot.suffix + ".sha256")
        metadata_path = snapshot.with_suffix(snapshot.suffix + ".json")
        write_atomic_text(checksum_path, checksum + "\n")
        metadata = {
            "schemaVersion": 1,
            "project": args.project,
            "createdUtc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "databaseFile": database.name,
            "snapshotFile": snapshot.name,
            "sha256": checksum,
            "sizeBytes": snapshot.stat().st_size,
        }
        write_atomic_text(metadata_path, json.dumps(metadata, indent=2) + "\n")
        prune_inventory = prune_snapshots(
            directory, args.daily, args.weekly, args.monthly, apply=False
        )
        return {
            "Action": "Export",
            "ProjectName": args.project,
            "SnapshotPath": str(snapshot),
            "ChecksumPath": str(checksum_path),
            "MetadataPath": str(metadata_path),
            "SnapshotCount": len(list_snapshots(directory)),
            "Retention": {
                "Daily": args.daily,
                "Weekly": args.weekly,
                "Monthly": args.monthly,
            },
            "PruneInventory": prune_inventory,
        }
    finally:
        if temporary.exists():
            temporary.unlink()


def verified_snapshot(snapshot: Path) -> None:
    checksum_path = snapshot.with_suffix(snapshot.suffix + ".sha256")
    if not checksum_path.is_file():
        raise RuntimeError("snapshot checksum file is missing")
    expected = checksum_path.read_text(encoding="utf-8").strip().lower()
    actual = sha256(snapshot)
    if not expected or actual != expected:
        raise RuntimeError("snapshot checksum mismatch")
    with closing(
        sqlite3.connect(snapshot.resolve().as_uri() + "?mode=ro", uri=True)
    ) as database:
        result = database.execute("pragma integrity_check").fetchone()
        if not result or result[0] != "ok":
            raise RuntimeError("snapshot SQLite integrity check failed")


def restore_snapshot(args: argparse.Namespace) -> dict[str, object]:
    local_root = Path(args.local_root)
    sync_root = Path(args.sync_root)
    database = Path(args.database)
    assert_plain_ancestors(local_root, "local project-data root")
    assert_plain_ancestors(sync_root, "project-data sync root")
    assert_plain_ancestors(database, "SQLite database path")
    assert_contained(database, local_root, "SQLite database path")
    database = database.resolve()
    directory = snapshot_directory(
        sync_root.resolve(), validate_project_name(args.project), database
    )
    assert_plain_ancestors(directory, "SQLite snapshot directory")
    snapshots = list_snapshots(directory)
    snapshot = Path(args.snapshot) if args.snapshot else (snapshots[0] if snapshots else None)
    if snapshot is None or not snapshot.is_file():
        raise FileNotFoundError("no SQLite snapshot is available")
    assert_plain_ancestors(snapshot, "SQLite snapshot path")
    assert_contained(snapshot, directory, "snapshot path")
    snapshot = snapshot.resolve()
    try:
        snapshot.relative_to(directory.resolve())
    except ValueError as error:
        raise ValueError("snapshot path is outside the project sync directory") from error
    verified_snapshot(snapshot)

    database.parent.mkdir(parents=True, exist_ok=True)
    pre_restore_backup: Path | None = None
    if database.exists():
        backup_directory = database.parent / "_pre_restore"
        pre_restore_backup = backup_directory / (
            f"{database.stem}-{utc_stamp()}-{uuid.uuid4().hex[:8]}{database.suffix}"
        )
        sqlite_backup(database, pre_restore_backup)

    temporary = database.with_name(database.name + f".restore-{uuid.uuid4().hex}.partial")
    try:
        sqlite_backup(snapshot, temporary)
        os.replace(temporary, database)
    finally:
        if temporary.exists():
            temporary.unlink()

    return {
        "Action": "Restore",
        "ProjectName": args.project,
        "SnapshotPath": str(snapshot),
        "DatabasePath": str(database),
        "PreRestoreBackupPath": str(pre_restore_backup) if pre_restore_backup else None,
    }


def status(args: argparse.Namespace) -> dict[str, object]:
    local_root = Path(args.local_root)
    sync_root = Path(args.sync_root)
    database = Path(args.database)
    assert_plain_ancestors(local_root, "local project-data root")
    assert_plain_ancestors(sync_root, "project-data sync root")
    assert_plain_ancestors(database, "SQLite database path")
    assert_contained(database, local_root, "SQLite database path")
    database = database.resolve()
    directory = snapshot_directory(
        sync_root.resolve(), validate_project_name(args.project), database
    )
    assert_plain_ancestors(directory, "SQLite snapshot directory")
    snapshots = list_snapshots(directory)
    return {
        "Action": "Status",
        "ProjectName": args.project,
        "DatabasePath": str(database),
        "LocalDatabaseExists": database.is_file(),
        "SnapshotDirectory": str(directory),
        "SnapshotCount": len(snapshots),
        "LatestSnapshotPath": str(snapshots[0]) if snapshots else None,
    }


def prune(args: argparse.Namespace) -> dict[str, object]:
    local_root = Path(args.local_root)
    sync_root = Path(args.sync_root)
    database = Path(args.database)
    assert_plain_ancestors(local_root, "local project-data root")
    assert_plain_ancestors(sync_root, "project-data sync root")
    assert_plain_ancestors(database, "SQLite database path")
    assert_contained(database, local_root, "SQLite database path")
    database = database.resolve()
    directory = snapshot_directory(
        sync_root.resolve(), validate_project_name(args.project), database
    )
    assert_plain_ancestors(directory, "SQLite snapshot directory")
    inventory = prune_snapshots(
        directory,
        args.daily,
        args.weekly,
        args.monthly,
        apply=args.apply_retention_prune,
    )
    return {
        "Action": "Prune",
        "ProjectName": args.project,
        "SnapshotDirectory": str(directory),
        **inventory,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--action", choices=("Export", "Restore", "Status", "Prune"), required=True
    )
    parser.add_argument("--project", required=True)
    parser.add_argument("--database", required=True)
    parser.add_argument("--local-root", required=True)
    parser.add_argument("--sync-root", required=True)
    parser.add_argument("--snapshot")
    parser.add_argument("--daily", type=int, default=3)
    parser.add_argument("--weekly", type=int, default=4)
    parser.add_argument("--monthly", type=int, default=3)
    parser.add_argument("--apply-retention-prune", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        if min(args.daily, args.weekly, args.monthly) < 0:
            raise ValueError("retention values must be non-negative")
        if args.action == "Export":
            result = export_snapshot(args)
        elif args.action == "Restore":
            result = restore_snapshot(args)
        elif args.action == "Prune":
            result = prune(args)
        else:
            result = status(args)
        print(json.dumps(result))
        return 0
    except Exception as error:
        print(f"SQLite project-data operation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
