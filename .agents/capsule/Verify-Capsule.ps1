[CmdletBinding()]
param(
    [string]$CapsuleRoot,
    [string]$TrustedHarnessRepository = (Join-Path $env:USERPROFILE 'projects\agent-harness')
)

$ErrorActionPreference = 'Stop'
if (-not $CapsuleRoot) {
    $CapsuleRoot = Split-Path -Parent $PSScriptRoot
}
$CapsuleRoot = [System.IO.Path]::GetFullPath($CapsuleRoot)

function Resolve-ContainedCapsulePath {
    param([string]$Root, [string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        (($RelativePath -split '[\\/]') -contains '..')) {
        throw "Capsule manifest path is unsafe: $RelativePath"
    }
    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    if (-not $candidate.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Capsule manifest path resolves outside the Capsule: $RelativePath"
    }
    return $candidate
}

function Test-PortableObsidianPath {
    param([string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        (($RelativePath -split '[\\/]') -contains '..')) {
        return $false
    }
    $normalized = $RelativePath.Replace('/', '\')
    if ($normalized -in @(
        'app.json',
        'appearance.json',
        'core-plugins.json',
        'hotkeys.json',
        'graph.json',
        'types.json',
        'community-plugins.json'
    )) {
        return $true
    }
    if ($normalized -match '^snippets\\[^\\]+\.css$') {
        return $true
    }
    return $normalized -match '^themes\\[^\\]+\\(manifest\.json|theme\.css)$'
}

function Get-PlainTreeItems {
    param([string]$Root)

    $pending = [System.Collections.Generic.Stack[string]]::new()
    $items = [System.Collections.Generic.List[object]]::new()
    $pending.Push([System.IO.Path]::GetFullPath($Root))
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Capsule contains a reparse point: $current"
        }
        $items.Add($item)
        if ($item.PSIsContainer) {
            foreach ($child in @(Get-ChildItem -LiteralPath $current -Force)) {
                $pending.Push($child.FullName)
            }
        }
    }
    return @($items)
}

function Invoke-GitText {
    param(
        [string]$Repository,
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        throw 'Git is required to verify Capsule provenance.'
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
        throw "Trusted Git provenance command failed: $($output -join [Environment]::NewLine)"
    }
    return (($output | ForEach-Object { [string]$_ }) -join "`n").Trim()
}

function ConvertTo-CanonicalGitRemote {
    param([string]$Remote)

    $value = $Remote.Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw 'The trusted harness Git origin is empty.'
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

function Assert-NoReparseAncestors {
    param([string]$Path, [string]$Label)

    $full = [System.IO.Path]::GetFullPath($Path)
    $pathRoot = [System.IO.Path]::GetPathRoot($full)
    $current = $pathRoot
    foreach ($segment in @($full.Substring($pathRoot.Length).Trim('\') -split '\\' |
        Where-Object { $_ })) {
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) {
            break
        }
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label contains a reparse-point ancestor: $current"
        }
    }
}

function Get-TreeFileRecords {
    param([string]$Root)

    return @(Get-PlainTreeItems -Root $Root |
        Where-Object { -not $_.PSIsContainer } |
        ForEach-Object {
            [pscustomobject]@{
                Path = $_.FullName.Substring($Root.Length).TrimStart('\').Replace('\', '/')
                Bytes = $_.Length
                Hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        } |
        Sort-Object Path)
}

function Assert-HarnessProvenance {
    param(
        [object]$Manifest,
        [string]$PayloadRoot,
        [string]$Repository
    )

    foreach ($property in @('remote', 'revision', 'releaseIdentifier', 'treeHash')) {
        if (-not ($Manifest.PSObject.Properties.Name -contains $property) -or
            [string]::IsNullOrWhiteSpace([string]$Manifest.$property)) {
            throw "Capsule harness provenance is incomplete: $property"
        }
    }
    if ([string]$Manifest.revision -notmatch '^[0-9a-fA-F]{40,64}$' -or
        [string]$Manifest.treeHash -notmatch '^[0-9a-fA-F]{40,64}$') {
        throw 'Capsule harness provenance contains an invalid Git object identifier.'
    }

    $repositoryFull = [System.IO.Path]::GetFullPath($Repository)
    if (-not (Test-Path -LiteralPath $repositoryFull -PathType Container)) {
        throw "The external trusted harness repository is unavailable: $repositoryFull"
    }
    Assert-NoReparseAncestors -Path $repositoryFull -Label 'Trusted harness repository'
    if ((Invoke-GitText -Repository $repositoryFull rev-parse --is-inside-work-tree) -ne 'true') {
        throw "The external trusted harness source is not a Git worktree: $repositoryFull"
    }

    $trustedRevision = ([string]$Manifest.revision).ToLowerInvariant()
    $catFileArguments = @('cat-file', '-e', ($trustedRevision + '^{commit}'))
    Invoke-GitText -Repository $repositoryFull @catFileArguments | Out-Null
    $refArguments = @(
        'for-each-ref',
        '--format=%(refname)',
        '--contains',
        $trustedRevision,
        'refs/remotes/origin'
    )
    $containingRefs = Invoke-GitText -Repository $repositoryFull @refArguments
    if ([string]::IsNullOrWhiteSpace($containingRefs)) {
        throw 'Capsule harness provenance revision is absent from the trusted origin refs.'
    }
    $trustedTreeHash = (
        Invoke-GitText -Repository $repositoryFull rev-parse ($trustedRevision + ':.agents')
    ).ToLowerInvariant()
    $trustedRemote = ConvertTo-CanonicalGitRemote (
        Invoke-GitText -Repository $repositoryFull remote get-url origin
    )
    $trustedTags = @((Invoke-GitText -Repository $repositoryFull tag --points-at $trustedRevision) -split "`n" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object)
    $trustedRelease = if ($trustedTags.Count) {
        [string]$trustedTags[0]
    }
    else {
        'commit-' + $trustedRevision.Substring(0, 12)
    }

    if ((ConvertTo-CanonicalGitRemote ([string]$Manifest.remote)) -ne $trustedRemote) {
        throw 'Capsule harness provenance remote differs from the external trusted repository.'
    }
    if ([string]$Manifest.treeHash -ne $trustedTreeHash) {
        throw 'Capsule harness provenance tree differs from the external trusted repository.'
    }
    if ([string]$Manifest.releaseIdentifier -ne $trustedRelease) {
        throw 'Capsule harness provenance release identifier differs from the external trusted repository.'
    }

    $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
        'Capsule-Provenance-' + [Guid]::NewGuid().ToString('N')
    )
    $archivePath = Join-Path $temporaryRoot 'trusted-harness.zip'
    $expandedPath = Join-Path $temporaryRoot 'expanded'
    try {
        New-Item -ItemType Directory -Path $expandedPath -Force | Out-Null
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $archiveOutput = @(& git.exe -C $repositoryFull archive `
                --format=zip `
                "--output=$archivePath" `
                $trustedRevision `
                .agents 2>&1)
        }
        finally {
            $ErrorActionPreference = $previousPreference
        }
        if ($LASTEXITCODE -ne 0) {
            throw "Trusted harness reconstruction failed: $($archiveOutput -join [Environment]::NewLine)"
        }
        Expand-Archive -LiteralPath $archivePath -DestinationPath $expandedPath
        $trustedAgents = Join-Path $expandedPath '.agents'
        $trustedRecords = @(Get-TreeFileRecords -Root $trustedAgents)
        $payloadRecords = @(Get-TreeFileRecords -Root $PayloadRoot)
        $differences = @(Compare-Object `
            -ReferenceObject $trustedRecords `
            -DifferenceObject $payloadRecords `
            -Property Path, Bytes, Hash)
        if ($differences.Count) {
            $summary = @($differences | Select-Object -First 5 | ForEach-Object {
                "$($_.SideIndicator) $($_.Path) $($_.Bytes) $($_.Hash)"
            }) -join '; '
            throw "Capsule harness payload differs from the external trusted Git revision: $summary"
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

function Assert-CanonicalCapsuleProjection {
    param(
        [string]$Root,
        [string]$HarnessRoot
    )

    $projectedFiles = @(
        'AGENT-START.md',
        'START-HERE.md',
        'SYSTEM-MAP.md',
        'DATA-SYNC-AND-RETENTION.md',
        'SECRETS-BITWARDEN.md',
        'NEXT-STEPS.md',
        'README.md',
        'Harness.ps1',
        'DOCKET.md',
        'tools\Bootstrap-Capsule.cmd',
        'tools\Bootstrap-Capsule.ps1',
        'tools\Verify-Capsule.cmd',
        'tools\Verify-Capsule.ps1',
        'tools\Set-CapsuleAccounts.cmd',
        'tools\Set-CapsuleAccounts.ps1',
        'tools\Refresh-Capsule.ps1',
        'tools\Refresh-Integrity.cmd',
        'tools\Refresh-Integrity.ps1',
        'tools\Export-ObsidianConfig.ps1',
        'tools\Restore-ObsidianConfig.ps1',
        'tools\Set-ProjectDataEnvironment.ps1'
    )
    foreach ($relative in $projectedFiles) {
        $capsulePath = Join-Path $Root $relative
        $sourceRelative = if ($relative.StartsWith('tools\', [StringComparison]::OrdinalIgnoreCase)) {
            'capsule\' + (Split-Path -Leaf $relative)
        }
        else {
            'capsule\' + $relative
        }
        $trustedPath = Join-Path $HarnessRoot $sourceRelative
        if (-not (Test-Path -LiteralPath $trustedPath -PathType Leaf)) {
            throw "The trusted harness revision lacks a projected Capsule file: $sourceRelative"
        }
        if ((Get-FileHash -LiteralPath $capsulePath -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $trustedPath -Algorithm SHA256).Hash) {
            throw "A Capsule entrypoint or instruction differs from the external trusted Git revision: $relative"
        }
    }
}

function Assert-ApprovedObsidianProjection {
    param(
        [object]$Manifest,
        [string]$PayloadRoot,
        [string]$HarnessRoot
    )

    if (-not $Manifest -or
        [string]$Manifest.approvedSnapshotRelativePath -ne 'capsule/approved-obsidian-config') {
        throw 'Capsule Obsidian provenance does not name the committed approved snapshot.'
    }
    $snapshotRoot = Join-Path $HarnessRoot 'capsule\approved-obsidian-config'
    $snapshotManifestPath = Join-Path $snapshotRoot 'snapshot.json'
    $trustedFilesRoot = Join-Path $snapshotRoot 'files'
    if (-not (Test-Path -LiteralPath $snapshotManifestPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $trustedFilesRoot -PathType Container)) {
        throw 'The trusted harness revision lacks the approved Obsidian configuration snapshot.'
    }
    $snapshotManifestHash = (
        Get-FileHash -LiteralPath $snapshotManifestPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ([string]$Manifest.snapshotManifestSha256 -ne $snapshotManifestHash) {
        throw 'Capsule Obsidian provenance digest differs from the trusted Git revision.'
    }
    $snapshot = Get-Content -LiteralPath $snapshotManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([int]$snapshot.schemaVersion -ne 1) {
        throw 'The approved Obsidian configuration snapshot schema is unsupported.'
    }
    $declared = @()
    foreach ($record in @($snapshot.files)) {
        $relative = [string]$record.path
        if ([string]::IsNullOrWhiteSpace($relative) -or
            [System.IO.Path]::IsPathRooted($relative) -or
            (($relative -split '[\\/]') -contains '..')) {
            throw "The approved Obsidian snapshot contains an unsafe path: $relative"
        }
        $path = [System.IO.Path]::GetFullPath((Join-Path $trustedFilesRoot $relative))
        $prefix = [System.IO.Path]::GetFullPath($trustedFilesRoot).TrimEnd('\') + '\'
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
    $trustedRecords = @(Get-TreeFileRecords -Root $trustedFilesRoot)
    $payloadRecords = @(Get-TreeFileRecords -Root $PayloadRoot)
    if (Compare-Object `
        -ReferenceObject $trustedRecords `
        -DifferenceObject $payloadRecords `
        -Property Path, Bytes, Hash) {
        throw 'Capsule Obsidian payload differs from the approved snapshot in the trusted Git revision.'
    }
    if (Compare-Object -ReferenceObject $declared -DifferenceObject @($trustedRecords.Path)) {
        throw 'The approved Obsidian snapshot inventory differs from its digest manifest.'
    }
}

$integrityPath = Join-Path $CapsuleRoot 'manifests\integrity.json'
$pointerPath = Join-Path $CapsuleRoot 'manifests\capsule.json'
foreach ($required in @(
    'AGENT-START.md',
    'START-HERE.md',
    'SYSTEM-MAP.md',
    'DATA-SYNC-AND-RETENTION.md',
    'SECRETS-BITWARDEN.md',
    'NEXT-STEPS.md',
    'README.md',
    'Harness.ps1',
    'DOCKET.md',
    'tools\Bootstrap-Capsule.ps1',
    'tools\Verify-Capsule.ps1',
    'tools\Refresh-Capsule.ps1',
    'tools\Export-ObsidianConfig.ps1',
    'tools\Restore-ObsidianConfig.ps1',
    'tools\Set-ProjectDataEnvironment.ps1',
    'manifests\integrity.json',
    'manifests\capsule.json'
)) {
    $path = Join-Path $CapsuleRoot $required
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Capsule file is missing: $required"
    }
}

$capsuleItems = @(Get-PlainTreeItems -Root $CapsuleRoot)
$integrity = Get-Content -LiteralPath $integrityPath -Raw -Encoding UTF8 | ConvertFrom-Json
$recordPaths = @()
foreach ($record in @($integrity.files)) {
    $path = Resolve-ContainedCapsulePath -Root $CapsuleRoot -RelativePath ([string]$record.path)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Integrity file is missing: $($record.path)"
    }
    $file = Get-Item -LiteralPath $path
    if ($file.Length -ne [long]$record.bytes) {
        throw "Integrity size mismatch: $($record.path)"
    }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne [string]$record.sha256) {
        throw "Integrity hash mismatch: $($record.path)"
    }
    $recordPaths += [string]$record.path
}
$actualPaths = @($capsuleItems |
    Where-Object { -not $_.PSIsContainer -and $_.FullName -ne $integrityPath } |
    ForEach-Object { $_.FullName.Substring($CapsuleRoot.Length).TrimStart('\').Replace('\', '/') })
if (Compare-Object -ReferenceObject $recordPaths -DifferenceObject $actualPaths) {
    throw 'Capsule integrity manifest and file inventory differ.'
}
$allowedCapsuleFiles = @(
    'AGENT-START.md',
    'START-HERE.md',
    'SYSTEM-MAP.md',
    'DATA-SYNC-AND-RETENTION.md',
    'SECRETS-BITWARDEN.md',
    'NEXT-STEPS.md',
    'README.md',
    'Harness.ps1',
    'DOCKET.md',
    'manifests/accounts.json',
    'manifests/capsule.json',
    'manifests/software.json',
    'tools/Bootstrap-Capsule.cmd',
    'tools/Bootstrap-Capsule.ps1',
    'tools/Verify-Capsule.cmd',
    'tools/Verify-Capsule.ps1',
    'tools/Set-CapsuleAccounts.cmd',
    'tools/Set-CapsuleAccounts.ps1',
    'tools/Refresh-Capsule.ps1',
    'tools/Refresh-Integrity.cmd',
    'tools/Refresh-Integrity.ps1',
    'tools/Export-ObsidianConfig.ps1',
    'tools/Restore-ObsidianConfig.ps1',
    'tools/Set-ProjectDataEnvironment.ps1'
)
foreach ($relativePath in $actualPaths) {
    if ($relativePath -like 'payload/*' -or $relativePath -in $allowedCapsuleFiles) {
        continue
    }
    throw "Capsule contains an undeclared top-level file: $relativePath"
}

$pointer = Get-Content -LiteralPath $pointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$pointer.schemaVersion -ne 3 -or [string]$pointer.payloadKind -ne 'global-harness') {
    throw 'Capsule manifest does not declare the global-harness-only boundary.'
}
foreach ($retiredProperty in @('workspaceRelativePath', 'snapshotName', 'projectDataRelativePath')) {
    if ($pointer.PSObject.Properties.Name -contains $retiredProperty) {
        throw "Capsule manifest contains retired workspace state: $retiredProperty"
    }
}
foreach ($retiredPath in @('payload\workspace', 'payload\projects')) {
    if (Test-Path -LiteralPath (Join-Path $CapsuleRoot $retiredPath)) {
        throw "Capsule contains retired project or workspace payload: $retiredPath"
    }
}
if (Test-Path -LiteralPath (Join-Path $CapsuleRoot 'tools\Restore-AgentWorkspace.ps1')) {
    throw 'Capsule root tools still package project workspace restoration.'
}

$harness = Resolve-ContainedCapsulePath `
    -Root $CapsuleRoot `
    -RelativePath ([string]$pointer.harnessRelativePath)
if (-not [string]::Equals(
    ([string]$pointer.harnessRelativePath).Replace('/', '\'),
    'payload\harness\.agents',
    [StringComparison]::OrdinalIgnoreCase
)) {
    throw 'Capsule harness payload path differs from the global contract.'
}
if (-not (Test-Path -LiteralPath (Join-Path $harness 'AGENTS.md') -PathType Leaf)) {
    throw 'Capsule shared harness payload is incomplete.'
}
Assert-HarnessProvenance `
    -Manifest $pointer.harness `
    -PayloadRoot $harness `
    -Repository $TrustedHarnessRepository
Assert-CanonicalCapsuleProjection -Root $CapsuleRoot -HarnessRoot $harness

$allowedObsidianPaths = @()
if (-not [string]::IsNullOrWhiteSpace([string]$pointer.obsidianConfigRelativePath)) {
    if (-not [string]::Equals(
        ([string]$pointer.obsidianConfigRelativePath).Replace('/', '\'),
        'payload\obsidian\config',
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw 'Capsule Obsidian payload path differs from the safe configuration contract.'
    }
    $obsidianRoot = Resolve-ContainedCapsulePath `
        -Root $CapsuleRoot `
        -RelativePath ([string]$pointer.obsidianConfigRelativePath)
    $obsidianManifestPath = Join-Path $obsidianRoot 'manifest.json'
    if (-not (Test-Path -LiteralPath $obsidianManifestPath -PathType Leaf)) {
        throw 'Capsule portable Obsidian configuration manifest is unavailable.'
    }
    Assert-ApprovedObsidianProjection `
        -Manifest $pointer.obsidian `
        -PayloadRoot $obsidianRoot `
        -HarnessRoot $harness
    $obsidianManifest = Get-Content -LiteralPath $obsidianManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($relative in @($obsidianManifest.files)) {
        if (-not (Test-PortableObsidianPath -RelativePath ([string]$relative))) {
            throw "Capsule portable Obsidian configuration contains an unsafe path: $relative"
        }
        $file = Resolve-ContainedCapsulePath -Root $obsidianRoot -RelativePath ([string]$relative)
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "Capsule portable Obsidian configuration file is unavailable: $relative"
        }
        $allowedObsidianPaths += ([string]$relative).Replace('\', '/')
    }
    $actualObsidianPaths = @($capsuleItems |
        Where-Object {
            -not $_.PSIsContainer -and
            $_.FullName.StartsWith(
                [System.IO.Path]::GetFullPath($obsidianRoot).TrimEnd('\') + '\',
                [StringComparison]::OrdinalIgnoreCase
            )
        } |
        ForEach-Object {
            $_.FullName.Substring($obsidianRoot.Length).TrimStart('\').Replace('\', '/')
        })
    $expectedObsidianPaths = @($allowedObsidianPaths) + 'manifest.json'
    if (Compare-Object -ReferenceObject $expectedObsidianPaths -DifferenceObject $actualObsidianPaths) {
        throw 'Capsule portable Obsidian configuration contains undeclared files.'
    }
    $communityPluginsPath = Join-Path $obsidianRoot 'community-plugins.json'
    if (Test-Path -LiteralPath $communityPluginsPath -PathType Leaf) {
        $communityPluginsRaw = Get-Content -LiteralPath $communityPluginsPath -Raw -Encoding UTF8
        if (-not $communityPluginsRaw.Trim().StartsWith('[') -or
            -not $communityPluginsRaw.Trim().EndsWith(']')) {
            throw 'Capsule community plugin configuration must be a JSON array of IDs.'
        }
        $decodedPluginIds = $communityPluginsRaw | ConvertFrom-Json
        foreach ($pluginId in @($decodedPluginIds)) {
            if ($pluginId -isnot [string] -or
                [string]::IsNullOrWhiteSpace([string]$pluginId) -or
                [string]$pluginId -notmatch '^[A-Za-z0-9._-]+$') {
                throw 'Capsule community plugin configuration contains a non-ID value.'
            }
        }
    }
}

foreach ($relativePath in $actualPaths) {
    if ($relativePath -notlike 'payload/*') {
        continue
    }
    if ($relativePath.StartsWith('payload/harness/.agents/', [StringComparison]::OrdinalIgnoreCase)) {
        continue
    }
    if ($relativePath.StartsWith('payload/obsidian/config/', [StringComparison]::OrdinalIgnoreCase) -and
        -not [string]::IsNullOrWhiteSpace([string]$pointer.obsidianConfigRelativePath)) {
        continue
    }
    throw "Capsule contains an undeclared payload file: $relativePath"
}

foreach ($directory in @($capsuleItems | Where-Object PSIsContainer)) {
    if ([string]::Equals(
        [System.IO.Path]::GetFullPath($directory.FullName).TrimEnd('\'),
        $CapsuleRoot.TrimEnd('\'),
        [StringComparison]::OrdinalIgnoreCase
    )) {
        continue
    }
    $relativeDirectory = $directory.FullName.Substring($CapsuleRoot.Length).TrimStart('\').Replace('\', '/')
    if ($relativeDirectory -notlike 'payload*') {
        if ($relativeDirectory -in @('manifests', 'tools')) {
            continue
        }
        throw "Capsule contains an undeclared top-level directory: $relativeDirectory"
    }
    if ($relativeDirectory -in @(
        'payload',
        'payload/harness',
        'payload/harness/.agents',
        'payload/obsidian',
        'payload/obsidian/config',
        'payload/obsidian/config/snippets',
        'payload/obsidian/config/themes'
    ) -or
        $relativeDirectory.StartsWith('payload/harness/.agents/', [StringComparison]::OrdinalIgnoreCase) -or
        $relativeDirectory -match '^payload/obsidian/config/themes/[^/]+$') {
        continue
    }
    throw "Capsule contains an undeclared payload directory: $relativeDirectory"
}

[pscustomobject]@{
    Result = 'PASS'
    CapsuleRoot = $CapsuleRoot
    PayloadKind = 'global-harness'
    VerifiedFiles = @($integrity.files).Count
    ObsidianConfigIncluded = -not [string]::IsNullOrWhiteSpace([string]$pointer.obsidianConfigRelativePath)
}
