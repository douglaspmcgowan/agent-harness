[CmdletBinding()]
param(
    [string]$Owner = 'douglaspmcgowan',
    [string]$Topic = 'agent-project',
    [string]$ProjectsRoot = (Join-Path $env:USERPROFILE 'projects'),
    [string]$RepositoryJsonPath,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedRemote {
    param([Parameter(Mandatory)][string]$Value)
    $trimmed = $Value.Trim().TrimEnd('/')
    if ([System.IO.Path]::IsPathRooted($trimmed)) {
        return [System.IO.Path]::GetFullPath($trimmed).TrimEnd('\').ToLowerInvariant()
    }
    $lower = $trimmed.ToLowerInvariant()
    foreach ($pattern in @(
        '^git@github\.com:(.+)$',
        '^ssh://git@github\.com/(.+)$',
        '^https?://github\.com/(.+)$'
    )) {
        if ($lower -match $pattern) {
            return 'github.com/' + ($Matches[1] -replace '\.git$', '').TrimEnd('/')
        }
    }
    return ($lower -replace '\.git$', '')
}

function Invoke-Git {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure
    )
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git.exe @Arguments 2>&1)
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    $exitCode = $LASTEXITCODE
    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed."
    }
    [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output | ForEach-Object { [string]$_ })
    }
}

function Get-Catalog {
    if ($RepositoryJsonPath) {
        if (-not (Test-Path -LiteralPath $RepositoryJsonPath -PathType Leaf)) {
            throw "Repository catalog fixture is missing: $RepositoryJsonPath"
        }
        $parsed = Get-Content -LiteralPath $RepositoryJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($repository in $parsed) { $repository }
        return
    }

    $gh = Get-Command gh.exe -ErrorAction SilentlyContinue
    if (-not $gh) { $gh = Get-Command gh -ErrorAction SilentlyContinue }
    if (-not $gh) { throw 'GitHub CLI is required for repository discovery.' }
    $json = @(
        & $gh.Source repo list $Owner `
            --topic $Topic `
            --source `
            --no-archived `
            --limit 1000 `
            --json name,nameWithOwner,url,defaultBranchRef 2>&1
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'GitHub repository discovery failed.'
    }
    $parsed = ($json -join "`n") | ConvertFrom-Json
    foreach ($repository in $parsed) { $repository }
}

function New-Result {
    param(
        [object]$Repository,
        [string]$Target,
        [string]$Action,
        [string]$Reason,
        [bool]$Applied
    )
    [pscustomobject][ordered]@{
        Name = [string]$Repository.name
        Repository = [string]$Repository.nameWithOwner
        Target = $Target
        Action = $Action
        Reason = $Reason
        Applied = $Applied
    }
}

$rootFull = [System.IO.Path]::GetFullPath($ProjectsRoot)
$catalog = @(Get-Catalog | Sort-Object { [string]$_.name })
if ($Apply -and -not (Test-Path -LiteralPath $rootFull -PathType Container)) {
    New-Item -ItemType Directory -Path $rootFull -Force | Out-Null
}

foreach ($repository in $catalog) {
    $name = [string]$repository.name
    if ([string]::IsNullOrWhiteSpace($name) -or
        $name -ne [System.IO.Path]::GetFileName($name) -or
        $name -in @('.', '..') -or
        $name.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $name.EndsWith('.') -or
        $name.EndsWith(' ') -or
        $name -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$') {
        throw "Unsafe repository name returned by catalog: $name"
    }

    $target = Join-Path $rootFull $name
    $expectedRemote = [string]$repository.url
    $branch = [string]$repository.defaultBranchRef.name
    if ([string]::IsNullOrWhiteSpace($branch)) { $branch = 'master' }

    if (-not (Test-Path -LiteralPath $target)) {
        if (-not $Apply) {
            New-Result -Repository $repository -Target $target -Action 'clone' -Reason 'missing' -Applied $false
            continue
        }
        $clone = Invoke-Git -Arguments @('clone', '--branch', $branch, '--single-branch', $expectedRemote, $target) -AllowFailure
        if ($clone.ExitCode -ne 0) {
            New-Result -Repository $repository -Target $target -Action 'attention' -Reason 'clone-failed' -Applied $false
        }
        else {
            New-Result -Repository $repository -Target $target -Action 'clone' -Reason 'missing' -Applied $true
        }
        continue
    }

    if (-not (Test-Path -LiteralPath (Join-Path $target '.git'))) {
        New-Result -Repository $repository -Target $target -Action 'attention' -Reason 'target-is-not-repository' -Applied $false
        continue
    }

    $originResult = Invoke-Git -Arguments @('-C', $target, 'remote', 'get-url', 'origin') -AllowFailure
    if ($originResult.ExitCode -ne 0 -or -not $originResult.Output.Count) {
        New-Result -Repository $repository -Target $target -Action 'attention' -Reason 'origin-missing' -Applied $false
        continue
    }
    $origin = $originResult.Output[-1].Trim()
    if ((Get-NormalizedRemote $origin) -ne (Get-NormalizedRemote $expectedRemote)) {
        New-Result -Repository $repository -Target $target -Action 'attention' -Reason 'origin-mismatch' -Applied $false
        continue
    }

    $status = Invoke-Git -Arguments @('-C', $target, 'status', '--porcelain=v1')
    if ($status.Output.Count -gt 0) {
        New-Result -Repository $repository -Target $target -Action 'attention' -Reason 'dirty' -Applied $false
        continue
    }

    $currentBranch = (Invoke-Git -Arguments @('-C', $target, 'branch', '--show-current')).Output -join ''
    if ($currentBranch.Trim() -ne $branch) {
        New-Result -Repository $repository -Target $target -Action 'attention' -Reason 'non-default-branch' -Applied $false
        continue
    }

    if (-not $Apply) {
        New-Result -Repository $repository -Target $target -Action 'pull' -Reason 'clean-default-branch' -Applied $false
        continue
    }

    $pull = Invoke-Git -Arguments @('-C', $target, 'pull', '--ff-only', 'origin', $branch) -AllowFailure
    if ($pull.ExitCode -ne 0) {
        New-Result -Repository $repository -Target $target -Action 'attention' -Reason 'pull-not-fast-forward' -Applied $false
        continue
    }
    $remoteLine = (Invoke-Git -Arguments @('ls-remote', $expectedRemote, "refs/heads/$branch")).Output | Select-Object -First 1
    $remoteHead = if ($remoteLine) { ($remoteLine -split '\s+')[0] } else { '' }
    $localHead = ((Invoke-Git -Arguments @('-C', $target, 'rev-parse', 'HEAD')).Output -join '').Trim()
    if (-not $remoteHead -or $localHead -ne $remoteHead) {
        New-Result -Repository $repository -Target $target -Action 'attention' -Reason 'local-ahead-or-diverged' -Applied $false
        continue
    }
    New-Result -Repository $repository -Target $target -Action 'pull' -Reason 'fast-forwarded' -Applied $true
}
