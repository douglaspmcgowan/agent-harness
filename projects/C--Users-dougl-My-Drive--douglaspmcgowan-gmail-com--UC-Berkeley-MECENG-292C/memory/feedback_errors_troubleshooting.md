---
name: Errors and troubleshooting for ME 292C project
description: Technical errors encountered and fixes during semantic analysis, doc generation, and Python/Node work on Windows
type: feedback
---

### Python environment
- **Python path:** `/c/Users/dougl/AppData/Local/Python/bin/python.exe` (Python 3.14.3)
- **sklearn TSNE:** Uses `max_iter` not `n_iter` (changed in newer sklearn). Fix: rename parameter.
- **matplotlib:** Not pre-installed. Fix: `pip install matplotlib`.
- **hdbscan pip package:** Fails on Windows — requires Microsoft Visual C++ 14.0 build tools. Fix: Use `sklearn.cluster.HDBSCAN` instead (available since scikit-learn 1.3+). Same API.
- **Unicode print errors:** Windows cp1252 encoding can't print `>=` symbols. Fix: use ASCII alternatives in print statements, or set `PYTHONIOENCODING=utf-8`.

### Node.js docx generation
- **npm global modules:** Must run with `NODE_PATH="$(npm root -g)"` to find globally installed `docx` package.
- **EBUSY errors:** Google Drive sync or having the file open in Word/Google Docs locks the .docx file. Fix: write to a new filename (v2, v3, etc.) instead of overwriting.
- **csv-parse not available:** Don't import `csv-parse/sync` — write a simple CSV parser inline instead.

### Google Drive / file paths
- **Parentheses in paths:** Bash on Windows chokes on `(` in paths like `My Drive (douglaspmcgowan@gmail.com)`. Always double-quote the entire path.
- **File locks from Google Drive sync:** Files can be locked even when not open in any app. Writing to a new filename is the safest approach.

### LibreOffice PDF conversion
- **Works for visual inspection:** `soffice.exe --headless --convert-to pdf` works on Windows. The "Could not find platform independent libraries" warning is harmless.
- **Always visually inspect:** PDF conversion + Read tool lets you verify the doc looks right before declaring done.

### Plotly image export
- **`scale=2` for crisp PNGs:** Always use `fig.write_image(..., scale=2)` for high-DPI output suitable for Word docs.
- **Text size for Word embeds:** Default Plotly text sizes (7pt) are too small when images are embedded in Word at 6.5" width. Use 9-10pt for labels.

**How to apply:** Check these before running scripts. When something fails, check this list before debugging from scratch.
