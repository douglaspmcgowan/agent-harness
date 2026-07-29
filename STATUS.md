# Status

## Working

- The shared harness source lives in this repository and installs to `C:\Users\dougl\.agents`.
- Claude, Codex, and Cursor receive one portable project contract through repository adapters.
- `TASK.md` is the single active task queue; `STATUS.md`, `LOG.md`, and `BACKBURNER.md` hold durable state, completed work, and parked work.
- GitHub topic `agent-project` drives project discovery, safe cloning, and clean-repository pulls.
- External project data is declared per repository in `data-manifest.yaml`; adapters handle its provider and recovery workflow.
- The Capsule contains the global harness and approved Obsidian configuration for receiving-computer reconstruction.
- Bitwarden Secrets Manager access is constrained through the exact-command broker and a per-computer machine token.
- The human-readable guide lives in `.agents\human-readable\README.md` with an HTML mirror.
- Docket uses the hardened Vercel Blob authority with conditional writes, complete export/restore, and phone access.
- Large versioned project data uses DVC metadata in Git and immutable content-addressed bytes in Google Drive.
- The verified global harness is installed at `C:\Users\dougl\.agents`; the verified Google Drive Capsule contains 482 global-harness and approved-Obsidian files.

## Known limits

- The Bitwarden `Agent Runtime` project and read-only machine token require one credential-bearing setup step by Douglas.
- macOS and Linux installation adapters are deferred; the verified receiving-computer scope is Windows 10/11.
