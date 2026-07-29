[CmdletBinding()]
param(
    [string]$SourceRepository = 'C:\Users\dougl\projects\agent-harness',
    [string]$BackupRoot = 'C:\Users\dougl\Documents\Agent Backups\Harness'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath (Join-Path $SourceRepository '.git'))) {
    throw "Harness repository is missing: $SourceRepository"
}

$safePath = $SourceRepository.Replace('\', '/')
$status = @(git -c "safe.directory=$safePath" -C $SourceRepository status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect the harness repository.'
}
if ($status.Count) {
    throw 'The harness repository has uncommitted changes. Commit or remove them before export.'
}

& gitleaks dir --no-banner --redact --exit-code 1 $SourceRepository
if ($LASTEXITCODE -ne 0) {
    throw 'Gitleaks blocked the backup pointer export.'
}

$head = (git -c "safe.directory=$safePath" -C $SourceRepository rev-parse HEAD).Trim()
$origin = (git -c "safe.directory=$safePath" -C $SourceRepository remote get-url origin).Trim()
$remoteHeads = @(git ls-remote $origin 'refs/heads/master')
if ($LASTEXITCODE -ne 0 -or -not ($remoteHeads -match "^$head\s")) {
    throw 'The current harness commit has not been verified on the remote master branch.'
}

New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
$manifest = [ordered]@{
    schemaVersion = 1
    verifiedAt = (Get-Date).ToUniversalTime().ToString('o')
    sourceRepository = $SourceRepository
    offsiteAuthority = $origin
    branch = 'master'
    commit = $head
    backupRole = 'Value-free recovery pointer for the curated Agent Backups folder'
    coverage = @(
        'shared cross-agent contracts and portable principles',
        'repository bootstrap, worktree, feedback, secrets, and verification tools',
        'reviewed Claude skill adapters and projection provenance'
    )
    excluded = @(
        'credentials and secret values',
        'machine-specific settings and permissions',
        'session history and runtime state',
        'project databases and restricted project data'
    )
}

$target = Join-Path $BackupRoot 'harness-backup.json'
[System.IO.File]::WriteAllText(
    $target,
    ($manifest | ConvertTo-Json -Depth 6) + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

[pscustomobject]@{
    Manifest = $target
    Commit = $head
    RemoteVerified = $true
}
