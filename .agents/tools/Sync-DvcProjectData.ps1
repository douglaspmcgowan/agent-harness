[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Inspect', 'Publish', 'Retrieve', 'Verify')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9._-]*$')]
    [string]$AssetId,

    [Parameter(Mandatory = $true)]
    [string]$RelativeDestination,

    [string]$DataRoot = $env:PROJECT_DATA_ROOT,
    [string]$SyncRoot = $env:PROJECT_DATA_SYNC_ROOT,
    [string]$ExpectedMetadataSha256,
    [string]$DvcCommand
)

$ErrorActionPreference = 'Stop'

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )
    $base = (Resolve-FullPath $BasePath) + [IO.Path]::DirectorySeparatorChar
    $baseUri = [Uri]$base
    $targetUri = [Uri](Resolve-FullPath $TargetPath)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('/', '\')
}

function Assert-ContainedPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $fullRoot = Resolve-FullPath $Root
    $fullCandidate = Resolve-FullPath $Candidate
    $prefix = $fullRoot + [IO.Path]::DirectorySeparatorChar
    if ($fullCandidate -ne $fullRoot -and -not $fullCandidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label escapes its declared root."
    }
}

function Assert-NoReparsePoint {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Candidate
    )
    $fullRoot = Resolve-FullPath $Root
    $cursor = Resolve-FullPath $Candidate
    Assert-ContainedPath $fullRoot $cursor 'Path'
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Reparse-point path is not allowed: $cursor"
            }
        }
        $parent = Split-Path $cursor -Parent
        if (-not $parent -or $parent -eq $cursor) {
            break
        }
        $cursor = $parent
    }
}

function Assert-NoNestedReparsePoint {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return
    }
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push((Resolve-FullPath $Path))
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Nested reparse-point content is not allowed: $($item.FullName)"
            }
            if ($item.PSIsContainer) {
                $pending.Push($item.FullName)
            }
        }
    }
}

function Resolve-DvcExecutable {
    function Test-Candidate {
        param([string]$Path)
        if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return $false
        }
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & $Path --version 2>&1 | Out-Null
            return $LASTEXITCODE -eq 0
        }
        catch {
            return $false
        }
        finally {
            $ErrorActionPreference = $previousPreference
        }
    }

    if ($DvcCommand) {
        $declared = Resolve-FullPath $DvcCommand
        if (-not (Test-Candidate $declared)) {
            throw 'The declared DVC path does not contain a runnable DVC executable.'
        }
        return $declared
    }

    $candidates = [Collections.Generic.List[string]]::new()
    Get-Command dvc.exe -All -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.Source) {
                [void]$candidates.Add($_.Source)
            }
        }
    if ($env:USERPROFILE) {
        $pipxCandidate = Join-Path $env:USERPROFILE '.local\bin\dvc.exe'
        if (Test-Path -LiteralPath $pipxCandidate -PathType Leaf) {
            [void]$candidates.Add($pipxCandidate)
        }
    }
    if ($env:APPDATA) {
        Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'Python') -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName 'Scripts\dvc.exe' } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
            ForEach-Object { [void]$candidates.Add($_) }
    }
    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if (Test-Candidate $candidate) {
            return (Resolve-FullPath $candidate)
        }
    }
    throw 'DVC is unavailable. Install it in an isolated user tool environment and ensure dvc.exe resolves in a fresh user process.'
}

function Invoke-Dvc {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $script:DvcExecutable @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($exitCode -ne 0) {
        $detail = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
        throw "DVC $($Arguments[0]) failed with exit code $exitCode. $detail"
    }
    return $output
}

function Invoke-GitForResult {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & git -C $repositoryPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    return @{
        ExitCode = $exitCode
        Output = (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
    }
}

function Get-ContentSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $null
    }

    Assert-NoNestedReparsePoint $Path
    $root = Resolve-FullPath $Path
    $lines = Get-ChildItem -LiteralPath $root -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
            $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            "$hash  $relative`n"
        }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join ''))
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Copy-Atomically {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    $parent = Split-Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporary = Join-Path $parent ('.' + [IO.Path]::GetFileName($Destination) + '.incoming-' + [Guid]::NewGuid().ToString('N'))
    try {
        Copy-Item -LiteralPath $Source -Destination $temporary -Recurse
        Move-Item -LiteralPath $temporary -Destination $Destination
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Recurse -Force
        }
    }
}

if (-not $DataRoot) {
    throw 'PROJECT_DATA_ROOT is unset.'
}
if (-not $SyncRoot) {
    throw 'PROJECT_DATA_SYNC_ROOT is unset.'
}
if ([IO.Path]::IsPathRooted($RelativeDestination) -or
    $RelativeDestination -notmatch '^(inputs|runtime|outputs|private)[\\/]' -or
    (($RelativeDestination -split '[\\/]') -contains '..')) {
    throw 'RelativeDestination must remain under inputs, runtime, outputs, or private.'
}
if ($ExpectedMetadataSha256 -and $ExpectedMetadataSha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw 'ExpectedMetadataSha256 must be a complete SHA-256 value.'
}

$repositoryPath = Resolve-FullPath $Repository
if (-not (Test-Path -LiteralPath (Join-Path $repositoryPath '.git'))) {
    throw 'Repository must be a Git working tree.'
}
$projectDataRoot = Join-Path (Resolve-FullPath $DataRoot) $Project
$destinationPath = Join-Path $projectDataRoot $RelativeDestination
$syncProjectRoot = Join-Path (Resolve-FullPath $SyncRoot) $Project
$remoteRoot = Join-Path (Join-Path $syncProjectRoot 'dvc') $AssetId
$claimDigestAlgorithm = [Security.Cryptography.SHA256]::Create()
try {
    $claimDigestBytes = $claimDigestAlgorithm.ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($remoteRoot.ToLowerInvariant())
    )
    $claimDigest = ([BitConverter]::ToString($claimDigestBytes)).Replace('-', '').ToLowerInvariant()
}
finally {
    $claimDigestAlgorithm.Dispose()
}
$firstPublishClaimPath = Join-Path (Join-Path ([IO.Path]::GetTempPath()) 'agent-harness-dvc-first-publish') ($claimDigest + '.lock')
$stageRoot = Join-Path $repositoryPath '.dvc-data'
$stagePath = Join-Path $stageRoot $AssetId
$metadataPath = $stagePath + '.dvc'
$metadataRelative = (Get-RelativePath $repositoryPath $metadataPath).Replace('\', '/')

Assert-ContainedPath $DataRoot $destinationPath 'Project data path'
Assert-ContainedPath $SyncRoot $remoteRoot 'DVC remote path'
Assert-ContainedPath $repositoryPath $stagePath 'DVC staging path'
Assert-NoReparsePoint $DataRoot $destinationPath
Assert-NoReparsePoint $SyncRoot $remoteRoot
Assert-NoReparsePoint $repositoryPath $stagePath

$script:DvcExecutable = Resolve-DvcExecutable
$script:FirstPublishClaimStream = $null

function Acquire-LocalFirstPublishClaim {
    $claimParent = Split-Path $firstPublishClaimPath -Parent
    New-Item -ItemType Directory -Path $claimParent -Force | Out-Null
    try {
        $script:FirstPublishClaimStream = [IO.FileStream]::new(
            $firstPublishClaimPath,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::None,
            1,
            [IO.FileOptions]::DeleteOnClose
        )
    }
    catch [IO.IOException] {
        throw 'Rejected concurrent first publication in this Windows session. Retry after the other local publisher finishes.'
    }
}

function Release-LocalFirstPublishClaim {
    if ($script:FirstPublishClaimStream) {
        $script:FirstPublishClaimStream.Dispose()
        $script:FirstPublishClaimStream = $null
    }
    if (Test-Path -LiteralPath $firstPublishClaimPath -PathType Leaf) {
        Remove-Item -LiteralPath $firstPublishClaimPath -Force -ErrorAction SilentlyContinue
    }
}

function Initialize-DvcRemote {
    param([switch]$FirstPublication)
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryPath '.dvc') -PathType Container)) {
        Push-Location $repositoryPath
        try {
            Invoke-Dvc @('init') | Out-Null
        }
        finally {
            Pop-Location
        }
    }
    if ($FirstPublication) {
        Acquire-LocalFirstPublishClaim
    }
    if (-not (Test-Path -LiteralPath $remoteRoot -PathType Container)) {
        if (-not $FirstPublication) {
            throw 'The DVC remote is unavailable. Wait for Google Drive Desktop to sync the declared project-data remote.'
        }
        New-Item -ItemType Directory -Path $remoteRoot -Force | Out-Null
    }
    Push-Location $repositoryPath
    try {
        Invoke-Dvc @('remote', 'add', '--local', '--force', '--default', 'project-data', $remoteRoot) | Out-Null
    }
    finally {
        Pop-Location
    }
}

function New-Evidence {
    param([string]$Operation, [bool]$RemoteInSync = $false)
    $metadataHash = if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
        (Get-FileHash -LiteralPath $metadataPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    else {
        $null
    }
    $contentHash = Get-ContentSha256 $stagePath
    [pscustomobject]@{
        action = $Operation
        project = $Project
        asset_id = $AssetId
        metadata_path = $metadataPath
        metadata_sha256 = $metadataHash
        content_sha256 = $contentHash
        destination_present = [bool](Test-Path -LiteralPath $destinationPath)
        remote_in_sync = $RemoteInSync
    } | ConvertTo-Json -Compress
}

switch ($Action) {
    'Inspect' {
        New-Evidence 'Inspect'
        break
    }
    'Publish' {
        if (-not (Test-Path -LiteralPath $destinationPath)) {
            throw 'The declared project-data source does not exist.'
        }
        Assert-NoNestedReparsePoint $destinationPath
        $isFirstPublication = -not (Test-Path -LiteralPath $metadataPath -PathType Leaf)
        if (-not $isFirstPublication) {
            $actualMetadataHash = (Get-FileHash -LiteralPath $metadataPath -Algorithm SHA256).Hash.ToLowerInvariant()
            if (-not $ExpectedMetadataSha256 -or
                $actualMetadataHash -ne $ExpectedMetadataSha256.ToLowerInvariant()) {
                throw 'Rejected stale publish: inspect the current metadata checksum and retry from the current Git revision.'
            }
            $dirtyMetadata = & git -C $repositoryPath status --porcelain -- $metadataRelative
            if ($LASTEXITCODE -ne 0) {
                throw 'Unable to inspect the Git state of DVC metadata.'
            }
            if ($dirtyMetadata) {
                throw 'Rejected publish because the current DVC metadata has uncommitted changes.'
            }
        }
        $upstream = Invoke-GitForResult @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}')
        if ($upstream.ExitCode -eq 0) {
            $branch = Invoke-GitForResult @('rev-parse', '--abbrev-ref', 'HEAD')
            $remote = if ($branch.ExitCode -eq 0) {
                Invoke-GitForResult @('config', '--get', "branch.$($branch.Output).remote")
            }
            else {
                @{ ExitCode = 1; Output = '' }
            }
            if ($remote.ExitCode -ne 0 -or -not $remote.Output) {
                throw 'Unable to resolve the tracked Git remote before DVC publication.'
            }
            if ($remote.Output -ne '.') {
                $fetch = Invoke-GitForResult @('fetch', '--quiet', '--prune', $remote.Output)
                if ($fetch.ExitCode -ne 0) {
                    throw 'Unable to refresh the upstream Git revision before DVC publication.'
                }
            }
            $counts = Invoke-GitForResult @('rev-list', '--left-right', '--count', 'HEAD...@{upstream}')
            if ($counts.ExitCode -ne 0 -or $counts.Output -notmatch '^(?<ahead>\d+)\s+(?<behind>\d+)$') {
                throw 'Unable to compare the local and upstream Git revisions before DVC publication.'
            }
            if ([int]$Matches.behind -gt 0) {
                throw 'Rejected stale publish because the upstream Git revision advanced. Pull the guarded project update first.'
            }
        }

        $dvcDirectory = Join-Path $repositoryPath '.dvc'
        $dvcConfigLocalPath = Join-Path $dvcDirectory 'config.local'
        $dvcIgnorePath = Join-Path $repositoryPath '.dvcignore'
        $stageIgnorePath = Join-Path $stageRoot '.gitignore'
        $dvcDirectoryExisted = Test-Path -LiteralPath $dvcDirectory -PathType Container
        $dvcConfigLocalExisted = Test-Path -LiteralPath $dvcConfigLocalPath -PathType Leaf
        $dvcIgnoreExisted = Test-Path -LiteralPath $dvcIgnorePath -PathType Leaf
        $stageRootExisted = Test-Path -LiteralPath $stageRoot -PathType Container
        $stageIgnoreExisted = Test-Path -LiteralPath $stageIgnorePath -PathType Leaf
        $stageIgnoreBackup = $stageIgnorePath + '.prior'
        $dvcIgnoreBackup = $dvcIgnorePath + '.prior'
        $dvcConfigLocalBackup = $dvcConfigLocalPath + '.prior'
        $incoming = Join-Path $stageRoot ('.incoming-' + [Guid]::NewGuid().ToString('N'))
        $prior = Join-Path $stageRoot ('.prior-' + [Guid]::NewGuid().ToString('N'))
        $metadataBackup = $metadataPath + '.prior'
        try {
            if ($stageIgnoreExisted) {
                Copy-Item -LiteralPath $stageIgnorePath -Destination $stageIgnoreBackup
            }
            if ($dvcIgnoreExisted) {
                Copy-Item -LiteralPath $dvcIgnorePath -Destination $dvcIgnoreBackup
            }
            if ($dvcConfigLocalExisted) {
                Copy-Item -LiteralPath $dvcConfigLocalPath -Destination $dvcConfigLocalBackup
            }
            Initialize-DvcRemote -FirstPublication:$isFirstPublication
            if (-not (Test-Path -LiteralPath $stageRoot -PathType Container)) {
                New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
            }
            Copy-Item -LiteralPath $destinationPath -Destination $incoming -Recurse
            if (Test-Path -LiteralPath $stagePath) {
                Move-Item -LiteralPath $stagePath -Destination $prior
            }
            if (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
                Copy-Item -LiteralPath $metadataPath -Destination $metadataBackup
            }
            Move-Item -LiteralPath $incoming -Destination $stagePath
            Push-Location $repositoryPath
            try {
                Invoke-Dvc @('add', (Get-RelativePath $repositoryPath $stagePath)) | Out-Null
                Invoke-Dvc @('push', '--remote', 'project-data', $metadataRelative) | Out-Null
                Invoke-Dvc @('status', '--cloud', '--quiet', '--remote', 'project-data', $metadataRelative) | Out-Null
            }
            finally {
                Pop-Location
            }
        }
        catch {
            if (Test-Path -LiteralPath $stagePath) {
                Remove-Item -LiteralPath $stagePath -Recurse -Force
            }
            if (Test-Path -LiteralPath $prior) {
                Move-Item -LiteralPath $prior -Destination $stagePath
            }
            if (Test-Path -LiteralPath $metadataBackup -PathType Leaf) {
                Copy-Item -LiteralPath $metadataBackup -Destination $metadataPath -Force
            }
            elseif (Test-Path -LiteralPath $metadataPath -PathType Leaf) {
                Remove-Item -LiteralPath $metadataPath -Force
            }
            if ($stageIgnoreExisted -and (Test-Path -LiteralPath $stageIgnoreBackup -PathType Leaf)) {
                Copy-Item -LiteralPath $stageIgnoreBackup -Destination $stageIgnorePath -Force
            }
            elseif (Test-Path -LiteralPath $stageIgnorePath -PathType Leaf) {
                Remove-Item -LiteralPath $stageIgnorePath -Force
            }
            if ($dvcIgnoreExisted -and (Test-Path -LiteralPath $dvcIgnoreBackup -PathType Leaf)) {
                Copy-Item -LiteralPath $dvcIgnoreBackup -Destination $dvcIgnorePath -Force
            }
            elseif (Test-Path -LiteralPath $dvcIgnorePath -PathType Leaf) {
                Remove-Item -LiteralPath $dvcIgnorePath -Force
            }
            if ($dvcConfigLocalExisted -and (Test-Path -LiteralPath $dvcConfigLocalBackup -PathType Leaf)) {
                Copy-Item -LiteralPath $dvcConfigLocalBackup -Destination $dvcConfigLocalPath -Force
            }
            elseif (Test-Path -LiteralPath $dvcConfigLocalPath -PathType Leaf) {
                Remove-Item -LiteralPath $dvcConfigLocalPath -Force
            }
            if (-not $dvcDirectoryExisted -and (Test-Path -LiteralPath $dvcDirectory -PathType Container)) {
                Remove-Item -LiteralPath $dvcDirectory -Recurse -Force
            }
            throw
        }
        finally {
            foreach ($temporaryPath in @($incoming, $prior, $metadataBackup, $stageIgnoreBackup, $dvcIgnoreBackup, $dvcConfigLocalBackup)) {
                if (Test-Path -LiteralPath $temporaryPath) {
                    Remove-Item -LiteralPath $temporaryPath -Recurse -Force
                }
            }
            if (-not $stageRootExisted -and
                (Test-Path -LiteralPath $stageRoot -PathType Container) -and
                @(Get-ChildItem -LiteralPath $stageRoot -Force).Count -eq 0) {
                Remove-Item -LiteralPath $stageRoot -Force
            }
            Release-LocalFirstPublishClaim
        }
        New-Evidence 'Publish' $true
        break
    }
    'Retrieve' {
        if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
            throw 'The Git revision does not declare DVC metadata for this asset.'
        }
        Initialize-DvcRemote
        Push-Location $repositoryPath
        try {
            Invoke-Dvc @('pull', '--remote', 'project-data', $metadataRelative) | Out-Null
        }
        finally {
            Pop-Location
        }
        $retrievedHash = Get-ContentSha256 $stagePath
        if (-not $retrievedHash) {
            throw 'DVC did not retrieve the declared content.'
        }
        if (Test-Path -LiteralPath $destinationPath) {
            Assert-NoNestedReparsePoint $destinationPath
            $destinationHash = Get-ContentSha256 $destinationPath
            if ($destinationHash -ne $retrievedHash) {
                throw 'Rejected retrieve because the local project-data path is a dirty destination.'
            }
        }
        else {
            Copy-Atomically $stagePath $destinationPath
        }
        New-Evidence 'Retrieve' $true
        break
    }
    'Verify' {
        if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
            throw 'The Git revision does not declare DVC metadata for this asset.'
        }
        Initialize-DvcRemote
        Push-Location $repositoryPath
        try {
            Invoke-Dvc @('status', '--cloud', '--quiet', '--remote', 'project-data', $metadataRelative) | Out-Null
            Invoke-Dvc @('status', '--quiet', $metadataRelative) | Out-Null
        }
        finally {
            Pop-Location
        }
        $stageHash = Get-ContentSha256 $stagePath
        if (-not $stageHash) {
            throw 'The local DVC workspace content is missing.'
        }
        if (Test-Path -LiteralPath $destinationPath) {
            Assert-NoNestedReparsePoint $destinationPath
            $destinationHash = Get-ContentSha256 $destinationPath
            if ($stageHash -ne $destinationHash) {
                throw 'The local project-data content differs from the Git-linked DVC version.'
            }
        }
        New-Evidence 'Verify' $true
        break
    }
}
