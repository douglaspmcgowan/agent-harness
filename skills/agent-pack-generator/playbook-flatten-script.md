# Playbook — Obsidian → flat/ flatten script

For packs whose source is an Obsidian vault folder. Drop this script at `<pack-root>/_flatten.py` and customize the prefix mapping at the bottom.

The script handles the three things that go wrong on Windows:

1. **Wikilinks.** `[[X|Y]]` → `Y`, `[[X]]` → `X`. Pack-shipped files must be self-contained.
2. **Long paths.** Obsidian vault paths + symposium / project folder names + per-talk subfolders frequently exceed `MAX_PATH` (260 chars). The `\\?\` prefix bypasses that.
3. **Filename slugs.** Source notes are titled in human-readable casing with em-dashes; pack files are lowercase kebab-case.

## Script

```python
"""One-shot flattener: source Obsidian folders → <pack-root>/flat/ with prefix tags + wikilinks stripped."""
import os
import re
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent  # source vault folder (parent of <pack-root>)
DEST = pathlib.Path(__file__).resolve().parent / "flat"
DEST.mkdir(parents=True, exist_ok=True)


def slugify(s: str) -> str:
    s = s.lower()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def strip_wl(txt: str) -> str:
    txt = re.sub(r"\[\[([^|\]]+)\|([^\]]+)\]\]", r"\2", txt)
    txt = re.sub(r"\[\[([^\]]+)\]\]", r"\1", txt)
    return txt


def _long(p: pathlib.Path) -> str:
    """Windows MAX_PATH workaround. Required when vault path + filename approaches 260 chars."""
    s = str(p)
    if not s.startswith("\\\\?\\"):
        s = "\\\\?\\" + s
    return s


def copy(src: pathlib.Path, prefix: str, base: str):
    slug = slugify(base)
    out = DEST / f"{prefix}-{slug}.md"
    with open(_long(src), "r", encoding="utf-8") as f:
        txt = f.read()
    with open(_long(out), "w", encoding="utf-8") as f:
        f.write(strip_wl(txt))


# ─── customize per pack ───────────────────────────────────────────────────────
# Folder name in the source vault → file prefix in flat/. Add / remove as needed.
FLAT_FOLDERS = [
    ("People", "person"),
    ("Topics", "topic"),
]

# Talk-style folders (a folder per item, with one .md inside).
NESTED_FOLDERS = [
    ("Presentations", "talk"),
]
# ──────────────────────────────────────────────────────────────────────────────


def main():
    n = 0
    for folder, prefix in FLAT_FOLDERS:
        for f in (ROOT / folder).iterdir():
            if f.suffix == ".md":
                copy(f, prefix, f.stem)
                n += 1
    for folder, prefix in NESTED_FOLDERS:
        for d in (ROOT / folder).iterdir():
            if d.is_dir():
                for f in d.iterdir():
                    if f.suffix == ".md":
                        copy(f, prefix, f.stem)
                        n += 1
    print(f"copied {n} files; flat now has {len(list(DEST.iterdir()))}")


if __name__ == "__main__":
    main()
```

## Run

```bash
PYTHONIOENCODING=utf-8 PYTHONUTF8=1 python <pack-root>/_flatten.py
```

`PYTHONUTF8=1` is required on Windows to handle em-dashes and other non-CP-1252 characters in file paths.

## What the script does NOT do

- It does **not** generate `core-*` files. Those are hand-authored.
- It does **not** handle non-Obsidian sources (papers, transcripts, deck text). For those, write the prefix-tagged files directly.
- It does **not** strip frontmatter. Pack files keep their YAML — the agent ignores it but it documents provenance.
- It does **not** handle attachments / images. If the agent should be able to see images, copy them by hand into `flat/` with descriptive names.

## When the slugifier collides

If two source notes slugify to the same filename (e.g. "MBSE — Strategy" and "MBSE Strategy"), the second write silently clobbers the first. The script does not protect against this. Run the flatten, then `ls flat/ | wc -l` and compare to the source count — if numbers don't match, find the collisions and rename the source notes.
