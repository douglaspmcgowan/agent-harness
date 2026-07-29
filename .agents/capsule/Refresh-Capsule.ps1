[CmdletBinding()]
param(
    [string]$CapsuleRoot = (Join-Path $env:USERPROFILE 'My Drive\Capsule'),
    [string]$HarnessRepository = (Join-Path $env:USERPROFILE 'projects\agent-harness'),
    [string]$AccountMapPath,
    [string]$ObsidianVaultRoot,
    [string]$ObsidianRegistryPath = (Join-Path $env:APPDATA 'obsidian\obsidian.json'),
    [string]$GitleaksPath,
    [switch]$SkipObsidianConfig
)

$ErrorActionPreference = 'Stop'
if ($PSBoundParameters.ContainsKey('ObsidianVaultRoot') -or
    $PSBoundParameters.ContainsKey('ObsidianRegistryPath')) {
    throw 'Capsule refresh never reads live Obsidian configuration. Run Capture-ApprovedObsidianConfig.ps1, review and commit the snapshot, then refresh Capsule.'
}
$sourceCapsuleRoot = $PSScriptRoot
$sourceParent = Split-Path -Parent $PSScriptRoot
if (
    [string]::Equals((Split-Path -Leaf $PSScriptRoot), 'tools', [StringComparison]::OrdinalIgnoreCase) -and
    (Test-Path -LiteralPath (Join-Path $sourceParent 'README.md') -PathType Leaf)
) {
    $sourceCapsuleRoot = $sourceParent
}
if (-not $AccountMapPath) {
    foreach ($candidate in @(
        (Join-Path $sourceCapsuleRoot 'manifests\accounts.json'),
        (Join-Path $sourceCapsuleRoot 'templates\accounts.template.json')
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $AccountMapPath = $candidate
            break
        }
    }
}

function Copy-Tree {
    param([string]$Source, [string]$Destination)

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Required source folder is unavailable: $Source"
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($file in @(Get-ChildItem -LiteralPath $Source -File -Recurse -Force)) {
        $relative = $file.FullName.Substring($Source.Length).TrimStart('\')
        $target = Join-Path $Destination $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }
}

function Copy-RequiredFile {
    param([string]$Source, [string]$Destination)

    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Required source file is unavailable: $Source"
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination
}

function Resolve-SourceTool {
    param([string]$Name)

    foreach ($candidate in @(
        (Join-Path $sourceCapsuleRoot "tools\$Name"),
        (Join-Path $sourceCapsuleRoot $Name)
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    throw "Required Capsule tool is unavailable: $Name"
}

function Write-CapsuleIntegrity {
    param([string]$Root)

    $integrityPath = Join-Path $Root 'manifests\integrity.json'
    $records = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force |
        Where-Object { $_.FullName -ne $integrityPath } |
        Sort-Object FullName |
        ForEach-Object {
            [ordered]@{
                path = $_.FullName.Substring($Root.Length).TrimStart('\').Replace('\', '/')
                bytes = $_.Length
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        })
    [System.IO.File]::WriteAllText(
        $integrityPath,
        (([ordered]@{
            schemaVersion = 1
            generatedAt = (Get-Date).ToUniversalTime().ToString('o')
            files = $records
        }) | ConvertTo-Json -Depth 6) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    return $records
}

function Assert-SafeCapsuleTarget {
    param([string]$Path)

    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $root = [System.IO.Path]::GetPathRoot($full).TrimEnd('\')
    if ([string]::Equals($full, $root, [StringComparison]::OrdinalIgnoreCase) -or
        [string]::IsNullOrWhiteSpace((Split-Path -Leaf $full))) {
        throw "Capsule target is too broad: $full"
    }
    $parent = Split-Path -Parent $full
    if ([string]::IsNullOrWhiteSpace($parent)) {
        throw "Capsule target has no safe parent: $full"
    }
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    return $full
}

function Assert-NoReparseAncestors {
    param([string]$Path, [string]$Label)

    $full = [System.IO.Path]::GetFullPath($Path)
    $pathRoot = [System.IO.Path]::GetPathRoot($full)
    $current = $pathRoot
    $relative = $full.Substring($pathRoot.Length).Trim('\')
    foreach ($candidate in @($pathRoot) + @($relative -split '\\' | Where-Object { $_ })) {
        if (-not [string]::Equals($candidate, $pathRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $current = Join-Path $current $candidate
        }
        if (-not (Test-Path -LiteralPath $current)) {
            break
        }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label contains a reparse-point ancestor: $current"
        }
    }
}

function Remove-ExactTree {
    param([string]$Path, [string]$ExpectedParent)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $parent = [System.IO.Path]::GetFullPath((Split-Path -Parent $full)).TrimEnd('\')
    if (-not [string]::Equals(
        $parent,
        [System.IO.Path]::GetFullPath($ExpectedParent).TrimEnd('\'),
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to remove a Capsule tree outside its exact parent: $full"
    }
    $item = Get-Item -LiteralPath $full -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing to remove a reparse-point Capsule tree: $full"
    }
    Remove-Item -LiteralPath $full -Recurse -Force
}

function Assert-SafeFileName {
    param([string]$Path)

    $leaf = Split-Path -Leaf $Path
    if ($leaf -in @(
        'credential-command-allowlist.json',
        'credential-command-policy.json',
        'bws-command-allowlist.json',
        '.env.example'
    )) {
        return
    }
    if ($leaf -match '^(?i)(\.env($|\.)|credentials?($|\.)|tokens?($|\.)|passwords?($|\.)|passcodes?($|\.)|recovery.?keys?($|\.)|cookies?($|\.))') {
        throw "A forbidden secret-like filename was found: $Path"
    }
}

function Enter-CapsuleRefreshLock {
    param([string]$Root)

    $lockDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'AgentHarness-CapsuleLocks'
    New-Item -ItemType Directory -Path $lockDirectory -Force | Out-Null
    $lockDirectoryItem = Get-Item -LiteralPath $lockDirectory -Force
    if (($lockDirectoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Capsule refresh lock directory must not be a reparse point: $lockDirectory"
    }

    $normalized = [System.IO.Path]::GetFullPath($Root).TrimEnd('\').ToLowerInvariant()
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = ([BitConverter]::ToString(
            $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($normalized))
        )).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
    $lockPath = Join-Path $lockDirectory ($hash + '.lock')
    if (Test-Path -LiteralPath $lockPath) {
        $lockItem = Get-Item -LiteralPath $lockPath -Force
        if (($lockItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Capsule refresh lock must not be a reparse point: $lockPath"
        }
    }
    try {
        return [System.IO.File]::Open(
            $lockPath,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
    }
    catch {
        throw "Another Capsule refresh is active for $normalized"
    }
}

function Invoke-GitText {
    param(
        [string]$Repository,
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        throw 'Git is required to establish Capsule provenance.'
    }
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git.exe -C $Repository @Arguments 2>&1)
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Git provenance command failed: $($output -join [Environment]::NewLine)"
    }
    return (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()
}

function ConvertTo-CanonicalGitRemote {
    param([string]$Remote)

    $value = $Remote.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'The harness Git origin is empty.'
    }
    if ($value -match '^git@(?<host>[^:]+):(?<path>.+)$') {
        $value = "https://$($Matches.host)/$($Matches.path)"
    }
    elseif ($value -match '^ssh://git@(?<host>[^/]+)/(?<path>.+)$') {
        $value = "https://$($Matches.host)/$($Matches.path)"
    }
    if ($value -match '^https?://') {
        $uri = [Uri]$value
        $normalizedPath = $uri.AbsolutePath.TrimEnd('/')
        if ($normalizedPath.EndsWith('.git', [StringComparison]::OrdinalIgnoreCase)) {
            $normalizedPath = $normalizedPath.Substring(0, $normalizedPath.Length - 4)
        }
        return "$($uri.Scheme.ToLowerInvariant())://$($uri.Host.ToLowerInvariant())$normalizedPath"
    }
    if ($value -match '^file://') {
        return ([Uri]$value).LocalPath.TrimEnd('\')
    }
    if ([System.IO.Path]::IsPathRooted($value)) {
        return [System.IO.Path]::GetFullPath($value).TrimEnd('\')
    }
    return $value.TrimEnd('/', '\')
}

function Get-HarnessGitProvenance {
    param([string]$Repository)

    $repositoryFull = [System.IO.Path]::GetFullPath($Repository)
    if (-not (Test-Path -LiteralPath $repositoryFull -PathType Container)) {
        throw "The trusted harness repository is unavailable: $repositoryFull"
    }
    Assert-NoReparseAncestors -Path $repositoryFull -Label 'Harness repository'
    $inside = Invoke-GitText -Repository $repositoryFull rev-parse --is-inside-work-tree
    if ($inside -ne 'true') {
        throw "The harness source is not a Git worktree: $repositoryFull"
    }
    $revision = (Invoke-GitText -Repository $repositoryFull rev-parse HEAD).ToLowerInvariant()
    $treeHash = (Invoke-GitText -Repository $repositoryFull rev-parse 'HEAD:.agents').ToLowerInvariant()
    $remote = ConvertTo-CanonicalGitRemote (
        Invoke-GitText -Repository $repositoryFull remote get-url origin
    )
    $tags = @((Invoke-GitText -Repository $repositoryFull tag --points-at HEAD) -split "`n" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object)
    $releaseIdentifier = if ($tags.Count) {
        [string]$tags[0]
    }
    else {
        'commit-' + $revision.Substring(0, 12)
    }
    return [ordered]@{
        remote = $remote
        revision = $revision
        releaseIdentifier = $releaseIdentifier
        treeHash = $treeHash
    }
}

function Export-TrackedHarnessAgents {
    param(
        [string]$Repository,
        [string]$Revision,
        [string]$Destination
    )

    $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
        'Capsule-Harness-Export-' + [Guid]::NewGuid().ToString('N')
    )
    $archivePath = Join-Path $temporaryRoot 'harness.zip'
    $expandedPath = Join-Path $temporaryRoot 'expanded'
    try {
        New-Item -ItemType Directory -Path $expandedPath -Force | Out-Null
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = @(& git.exe -C $Repository archive `
                --format=zip `
                "--output=$archivePath" `
                $Revision `
                .agents 2>&1)
        }
        finally {
            $ErrorActionPreference = $previousPreference
        }
        if ($LASTEXITCODE -ne 0) {
            throw "The committed harness payload could not be reconstructed: $($output -join [Environment]::NewLine)"
        }
        Expand-Archive -LiteralPath $archivePath -DestinationPath $expandedPath
        Copy-Tree -Source (Join-Path $expandedPath '.agents') -Destination $Destination
    }
    finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

function Assert-ApprovedObsidianSnapshot {
    param([string]$SnapshotRoot)

    $filesRoot = Join-Path $SnapshotRoot 'files'
    $manifestPath = Join-Path $SnapshotRoot 'snapshot.json'
    if (-not (Test-Path -LiteralPath $filesRoot -PathType Container) -or
        -not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw 'The committed approved Obsidian configuration snapshot is unavailable.'
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([int]$manifest.schemaVersion -ne 1) {
        throw 'The committed approved Obsidian configuration snapshot schema is unsupported.'
    }
    $declared = @()
    foreach ($record in @($manifest.files)) {
        $relative = [string]$record.path
        if ([string]::IsNullOrWhiteSpace($relative) -or
            [System.IO.Path]::IsPathRooted($relative) -or
            (($relative -split '[\\/]') -contains '..')) {
            throw "The approved Obsidian snapshot contains an unsafe path: $relative"
        }
        $path = [System.IO.Path]::GetFullPath((Join-Path $filesRoot $relative))
        $prefix = [System.IO.Path]::GetFullPath($filesRoot).TrimEnd('\') + '\'
        if (-not $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "The approved Obsidian snapshot file is unavailable: $relative"
        }
        if ((Get-Item -LiteralPath $path).Length -ne [long]$record.bytes -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne
                [string]$record.sha256) {
            throw "The approved Obsidian snapshot digest differs: $relative"
        }
        $declared += $relative.Replace('\', '/')
    }
    $actual = @(Get-ChildItem -LiteralPath $filesRoot -File -Recurse -Force |
        ForEach-Object { $_.FullName.Substring($filesRoot.Length).TrimStart('\').Replace('\', '/') })
    if (Compare-Object -ReferenceObject $declared -DifferenceObject $actual) {
        throw 'The approved Obsidian snapshot inventory differs from its digest manifest.'
    }
}

Assert-NoReparseAncestors -Path $CapsuleRoot -Label 'Capsule target path'
$CapsuleRoot = Assert-SafeCapsuleTarget -Path $CapsuleRoot
Assert-NoReparseAncestors -Path $CapsuleRoot -Label 'Capsule target path'
$capsuleParent = Split-Path -Parent $CapsuleRoot
$capsuleName = Split-Path -Leaf $CapsuleRoot
$stageRoot = Join-Path $capsuleParent ('.c-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
$previousRoot = $null
$installed = $false
$refreshLock = Enter-CapsuleRefreshLock -Root $CapsuleRoot

try {
    $harnessProvenance = Get-HarnessGitProvenance -Repository $HarnessRepository
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
    foreach ($doc in @(
        'AGENT-START.md',
        'START-HERE.md',
        'SYSTEM-MAP.md',
        'DATA-SYNC-AND-RETENTION.md',
        'SECRETS-BITWARDEN.md',
        'NEXT-STEPS.md'
    )) {
        Copy-RequiredFile `
            -Source (Join-Path $sourceCapsuleRoot $doc) `
            -Destination (Join-Path $stageRoot $doc)
    }
    foreach ($entrypoint in @(
        'README.md',
        'Harness.ps1',
        'DOCKET.md'
    )) {
        Copy-RequiredFile `
            -Source (Join-Path $sourceCapsuleRoot $entrypoint) `
            -Destination (Join-Path $stageRoot $entrypoint)
    }
    foreach ($tool in @(
        'Bootstrap-Capsule.ps1',
        'Bootstrap-Capsule.cmd',
        'Verify-Capsule.ps1',
        'Verify-Capsule.cmd',
        'Set-CapsuleAccounts.ps1',
        'Set-CapsuleAccounts.cmd',
        'Refresh-Capsule.ps1',
        'Refresh-Integrity.ps1',
        'Refresh-Integrity.cmd',
        'Export-ObsidianConfig.ps1',
        'Restore-ObsidianConfig.ps1',
        'Set-ProjectDataEnvironment.ps1'
    )) {
        Copy-RequiredFile `
            -Source (Resolve-SourceTool -Name $tool) `
            -Destination (Join-Path $stageRoot "tools\$tool")
    }

    if (-not (Test-Path -LiteralPath $AccountMapPath -PathType Leaf)) {
        throw "Account map is unavailable: $AccountMapPath"
    }
    Copy-RequiredFile -Source $AccountMapPath -Destination (Join-Path $stageRoot 'manifests\accounts.json')
    $softwareMap = Join-Path $sourceCapsuleRoot 'templates\software.json'
    if (-not (Test-Path -LiteralPath $softwareMap -PathType Leaf)) {
        $softwareMap = Join-Path $sourceCapsuleRoot 'manifests\software.json'
    }
    Copy-RequiredFile -Source $softwareMap -Destination (Join-Path $stageRoot 'manifests\software.json')

    $harnessAgents = Join-Path $HarnessRepository '.agents'
    if (-not (Test-Path -LiteralPath (Join-Path $harnessAgents 'AGENTS.md') -PathType Leaf)) {
        throw "The shared harness source is incomplete: $harnessAgents"
    }
    Export-TrackedHarnessAgents `
        -Repository $HarnessRepository `
        -Revision ([string]$harnessProvenance.revision) `
        -Destination (Join-Path $stageRoot 'payload\harness\.agents')
    $committedCapsuleRoot = Join-Path $stageRoot 'payload\harness\.agents\capsule'
    foreach ($projectedFile in @(
        'AGENT-START.md',
        'START-HERE.md',
        'SYSTEM-MAP.md',
        'DATA-SYNC-AND-RETENTION.md',
        'SECRETS-BITWARDEN.md',
        'NEXT-STEPS.md',
        'README.md',
        'Harness.ps1',
        'DOCKET.md'
    )) {
        Copy-RequiredFile `
            -Source (Join-Path $committedCapsuleRoot $projectedFile) `
            -Destination (Join-Path $stageRoot $projectedFile)
    }
    foreach ($projectedTool in @(
        'Bootstrap-Capsule.ps1',
        'Bootstrap-Capsule.cmd',
        'Verify-Capsule.ps1',
        'Verify-Capsule.cmd',
        'Set-CapsuleAccounts.ps1',
        'Set-CapsuleAccounts.cmd',
        'Refresh-Capsule.ps1',
        'Refresh-Integrity.ps1',
        'Refresh-Integrity.cmd',
        'Export-ObsidianConfig.ps1',
        'Restore-ObsidianConfig.ps1',
        'Set-ProjectDataEnvironment.ps1'
    )) {
        Copy-RequiredFile `
            -Source (Join-Path $committedCapsuleRoot $projectedTool) `
            -Destination (Join-Path $stageRoot "tools\$projectedTool")
    }

    $obsidianRelativePath = $null
    if (-not $SkipObsidianConfig) {
        $obsidianRelativePath = 'payload\obsidian\config'
        $approvedSnapshot = Join-Path $committedCapsuleRoot 'approved-obsidian-config'
        Assert-ApprovedObsidianSnapshot -SnapshotRoot $approvedSnapshot
        Copy-Tree `
            -Source (Join-Path $approvedSnapshot 'files') `
            -Destination (Join-Path $stageRoot $obsidianRelativePath)
    }

    $manifest = [ordered]@{
        schemaVersion = 3
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        payloadKind = 'global-harness'
        harnessRelativePath = 'payload\harness\.agents'
        obsidianConfigRelativePath = $obsidianRelativePath
        secretsAuthority = 'Bitwarden Secrets Manager'
        harness = $harnessProvenance
        obsidian = if ($obsidianRelativePath) {
            [ordered]@{
                approvedSnapshotRelativePath = 'capsule/approved-obsidian-config'
                snapshotManifestSha256 = (
                    Get-FileHash `
                        -LiteralPath (Join-Path $committedCapsuleRoot 'approved-obsidian-config\snapshot.json') `
                        -Algorithm SHA256
                ).Hash.ToLowerInvariant()
            }
        }
        else {
            $null
        }
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $stageRoot 'manifests\capsule.json'),
        ($manifest | ConvertTo-Json -Depth 5) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    foreach ($file in @(Get-ChildItem -LiteralPath $stageRoot -File -Recurse -Force)) {
        Assert-SafeFileName -Path $file.FullName
    }
    $gitleaksCommand = $null
    if ($GitleaksPath) {
        if ((Split-Path -Leaf $GitleaksPath) -notin @('gitleaks', 'gitleaks.exe') -or
            -not (Test-Path -LiteralPath $GitleaksPath -PathType Leaf)) {
            throw 'Gitleaks is required before a Capsule can be published.'
        }
        $gitleaksCommand = Get-Item -LiteralPath $GitleaksPath
    }
    else {
        $gitleaksCommand = Get-Command gitleaks.exe -CommandType Application -ErrorAction SilentlyContinue
        if (-not $gitleaksCommand) {
            $gitleaksCommand = Get-Command gitleaks -CommandType Application -ErrorAction SilentlyContinue
        }
    }
    if (-not $gitleaksCommand) {
        throw 'Gitleaks is required before a Capsule can be published.'
    }
    $gitleaksExecutable = if ($GitleaksPath) {
        $gitleaksCommand.FullName
    }
    else {
        $gitleaksCommand.Source
    }
    & $gitleaksExecutable dir --no-banner --redact --exit-code 1 $stageRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Gitleaks blocked the Capsule.'
    }
    $records = @(Write-CapsuleIntegrity -Root $stageRoot)
    & (Join-Path $stageRoot 'tools\Verify-Capsule.ps1') `
        -CapsuleRoot $stageRoot `
        -TrustedHarnessRepository $HarnessRepository | Out-Null

    if (Test-Path -LiteralPath $CapsuleRoot) {
        $existing = Get-Item -LiteralPath $CapsuleRoot -Force
        if (($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Capsule target must not be a reparse point: $CapsuleRoot"
        }
        $previousRoot = Join-Path $capsuleParent ('.p-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        Move-Item -LiteralPath $CapsuleRoot -Destination $previousRoot
    }
    try {
        Move-Item -LiteralPath $stageRoot -Destination $CapsuleRoot
        $installed = $true
    }
    catch {
        if ($previousRoot -and
            -not (Test-Path -LiteralPath $CapsuleRoot) -and
            (Test-Path -LiteralPath $previousRoot)) {
            Move-Item -LiteralPath $previousRoot -Destination $CapsuleRoot
        }
        throw
    }

    & (Join-Path $CapsuleRoot 'tools\Verify-Capsule.ps1') `
        -CapsuleRoot $CapsuleRoot `
        -TrustedHarnessRepository $HarnessRepository | Out-Null
    if ($previousRoot) {
        Remove-ExactTree -Path $previousRoot -ExpectedParent $capsuleParent
        $previousRoot = $null
    }

    [pscustomobject]@{
        Result = 'PASS'
        CapsuleRoot = $CapsuleRoot
        PayloadKind = 'global-harness'
        Files = $records.Count + 1
        ObsidianConfigIncluded = -not $SkipObsidianConfig
    }
}
finally {
    if ($refreshLock) {
        $refreshLock.Dispose()
    }
    if (-not $installed -and (Test-Path -LiteralPath $stageRoot)) {
        Remove-ExactTree -Path $stageRoot -ExpectedParent $capsuleParent
    }
}
