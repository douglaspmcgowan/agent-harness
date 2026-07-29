# /sync-obsidian

Sync the Google Drive Claude folder into the local Obsidian vault's Claude subfolder.

## Steps

1. Detect the local vault path using this priority order:
   - **Yoga 7** (this machine): `C:\Users\dougl\Main\Yoga 7 Local_John 14_12\Claude`
   - **Other computer**: read path from `$env:USERPROFILE\.claude\obsidian-vault-path.txt` if it exists
   - If neither found: print an error explaining the user should create `~/.claude/obsidian-vault-path.txt` containing the full path to their Obsidian vault's Claude subfolder, then stop.

2. Run this PowerShell to sync:

```powershell
$src = "G:\My Drive\Obsidian\Claude"
$yogaVault = "C:\Users\dougl\Main\Yoga 7 Local_John 14_12\Claude"
$configFile = "$env:USERPROFILE\.claude\obsidian-vault-path.txt"

if (Test-Path $yogaVault) {
    $dest = $yogaVault
} elseif (Test-Path $configFile) {
    $dest = (Get-Content $configFile -Raw).Trim()
} else {
    Write-Host "No vault path found. Create $configFile with the full path to your Obsidian Claude subfolder."
    exit 1
}

robocopy $src $dest /E /XO /NP
```

3. Report: how many files were copied, skipped, and the destination path used.
