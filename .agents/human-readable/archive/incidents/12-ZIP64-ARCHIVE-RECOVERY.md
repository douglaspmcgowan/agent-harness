# ZIP64 archive recovery note

Verified: 2026-07-26

## Completed extraction

- Original: `C:\Users\dougl\Downloads\FOR-DOUGLAS.zip`
- SHA-256: `0E7DD2C5CD624E3A597C648BA6F34EC200105C61D7071F0D53DEDA2C40F1F1ED`
- Extracted local copy: `C:\Users\dougl\Data\Imports\FOR-DOUGLAS.extracted`
- Verified files: 22,267
- Verified expanded bytes: 12,078,109,028
- Original archive preserved: yes

The extraction initially completed under Downloads, then moved outside the configured Google Drive folders because the archive contains a `personal-internal` tree.

`C:\Users\dougl\Downloads\FOR-DOUGLAS.zip` is a valid ZIP64 archive. Windows Explorer’s compressed-folder handler fails to enumerate it because the central-directory offset exceeds the classic 32-bit ZIP boundary.

Verified properties:

- size: 11,556,642,601 bytes;
- entries: 24,998;
- encrypted entries: zero;
- duplicate names: zero;
- unsafe traversal or absolute names: zero;
- CRC failures: zero;
- paths longer than 260 characters: two.

`tar.exe`, .NET `ZipArchive`, and Python `zipfile.testzip()` all read the archive successfully. The original remained unchanged.

Extract in PowerShell:

```powershell
New-Item -ItemType Directory -Path 'C:\Users\dougl\Downloads\FOR-DOUGLAS.extracted'
tar.exe -xf 'C:\Users\dougl\Downloads\FOR-DOUGLAS.zip' -C 'C:\Users\dougl\Downloads\FOR-DOUGLAS.extracted'
```

A current 7-Zip installation can also extract it. An Explorer-compatible delivery would require several archives kept below the classic ZIP size boundary and approximately another 12 GB of temporary disk space.
