# BitLocker, Device Encryption, and Gitleaks

Last verified: 2026-07-26

## Verified machine state

Windows reports:

- edition: Home/Core;
- display version: 25H2;
- build: 26200.

The non-elevated audit could not read TPM, Secure Boot, volume encryption status, or recovery-key state. Encryption status is therefore unknown.

The unresolved enablement and recovery-readiness work is parked in the General Security project backlog at `taskstate\general security\BACKBURNER.md`.

Windows Home supports Device Encryption on qualifying hardware. The fuller BitLocker Drive Encryption control panel is available on Pro, Enterprise, and Education. [Device Encryption](https://support.microsoft.com/en-US/Windows/Security/Encryption/device-encryption-in-windows), [BitLocker Drive Encryption](https://support.microsoft.com/en-US/Windows/Security/encryption/bitlocker-drive-encryption).

## Douglas's Device Encryption setup

1. Sign in with an administrator account.
2. Open **Settings → Privacy & security → Device encryption**.
3. If the page exists, inspect the current toggle.
4. Before enabling it, open [Microsoft recovery keys](https://aka.ms/myrecoverykey) from another device or browser session and confirm you can access the account.
5. Enable Device Encryption.
6. Wait for Windows to finish encryption.
7. Verify that a recovery key appears for this device.
8. Create an additional recovery copy on a USB drive or printed paper stored separately from the computer.
9. Perform a recovery-readiness check from another device: sign in, locate the matching key ID, and stop before exposing the value in any agent transcript.

If **Device encryption** is absent, run **System Information as administrator** and inspect **Device Encryption Support**. Microsoft lists TPM, WinRE, Secure Boot/PCR7, and account/admin state as common prerequisites. [Microsoft Device Encryption guidance](https://support.microsoft.com/en-US/Windows/Security/Encryption/device-encryption-in-windows).

The recovery key can unlock the drive. Keep it outside the computer and outside agent-visible files. Microsoft cannot recreate a lost key. [Find your BitLocker recovery key](https://support.microsoft.com/en-us/windows/finding-your-bitlocker-recovery-key-in-windows-6b71ad27-0b89-ea08-f143-056f5ab347d6), [Back up your recovery key](https://support.microsoft.com/en-US/Windows/Security/Encryption/back-up-your-bitlocker-recovery-key).

## What BitLocker protects

Drive encryption protects data when someone removes the disk or boots outside the authorized Windows session. Once Douglas signs in and the volume is unlocked, applications and agents operate through normal Windows permissions. Restricted folders and credential boundaries still matter.

## Gitleaks installation

Installed and checksum-verified:

```text
C:\Users\dougl\Tools\gitleaks\gitleaks.exe
Version 8.30.1
```

Gitleaks scans Git history, working directories, and staged content for recognizable secrets. [Gitleaks](https://github.com/gitleaks/gitleaks).

## Automatic layers

### Future repositories

Git's global `init.templateDir` points to `C:\Users\dougl\.agents\git-template`. New `git init` and `git clone` repositories receive a pre-commit hook that runs:

```powershell
gitleaks git --pre-commit --staged --redact --no-banner
```

### Bootstrapped projects

`Initialize-AgentProject.cmd` adds:

- `.gitleaks.toml`, extending Gitleaks defaults;
- `.github\workflows\gitleaks.yml`;
- the local pre-commit hook.

### Existing repositories

Run:

```powershell
C:\Users\dougl\.agents\tools\Enable-Gitleaks.cmd -Repository C:\path\to\repo
```

Use `-HookOnly` when the repository owner wants commit protection before adopting tracked CI/configuration files. The tool preserves existing hooks and requires manual integration when one already exists.

Adoption status on 2026-07-26:

- `boundaries-reader`: hook installed; full redacted repository scan passed.
- `claude-global-config`: hook installed; full redacted repository scan passed.
- `flight-tracker\base-flight-finder`: deliberately deferred because another Codex task was actively working there.
- folders under `C:\Users\dougl\projects` found during the audit were ordinary project folders rather than initialized Git repositories; the global Git template will apply when they are initialized.

## What happens on a finding

The staged commit is blocked and output is redacted. Inspect the named file and rule. False positives should use the narrowest documented allow mechanism with a reason. A real credential is revoked or rotated before repository-history cleanup.

Gitleaks catches recognizable secret patterns. It does not inspect an unlocked vault, govern runtime authorization, or prove that a repository is free of every sensitive value.
