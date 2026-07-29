[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('InstallGlobal', 'EnsureProject', 'SyncProject', 'VerifyProject', 'VerifyGlobal', 'VerifyHumanGuide', 'VerifyHooks', 'Stamp', 'All')]
    [string]$Action = 'VerifyGlobal',

    [string]$HarnessRoot,
    [string]$HomeRoot = $env:USERPROFILE,
    [string]$Repository,
    [string]$ProjectName,
    [switch]$IncludeProduct,
    [switch]$ActivateHooks,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if ($DryRun) { $WhatIfPreference = $true }

if ([string]::IsNullOrWhiteSpace($HarnessRoot)) {
    $HarnessRoot = Split-Path $PSScriptRoot -Parent
}
$HarnessRoot = [System.IO.Path]::GetFullPath($HarnessRoot)
$HomeRoot = [System.IO.Path]::GetFullPath($HomeRoot)
$runId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff')
$changes = [System.Collections.Generic.List[string]]::new()
$preserved = [System.Collections.Generic.List[string]]::new()
$gates = [System.Collections.Generic.List[string]]::new()
$projectProvenanceAuthority = 'agent-harness/portable-project-contract/v3'

function Get-Sha256Text([string]$Text) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-Sha256File([string]$Path) {
    $stream = [System.IO.File]::OpenRead([System.IO.Path]::GetFullPath($Path))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function Get-SetupStampHash([string]$Path) {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
    if ($bytes -contains 0) {
        return Get-Sha256File $fullPath
    }

    try {
        $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
        $text = $strictUtf8.GetString($bytes)
        $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
        return Get-Sha256Text $normalized
    }
    catch {
        return Get-Sha256File $fullPath
    }
}

function Read-Text([string]$Path) {
    return [System.IO.File]::ReadAllText($Path)
}

function Render-HomeTokens([string]$Content) {
    $windowsHome = $HomeRoot.TrimEnd('\', '/')
    $posixHome = $windowsHome.Replace('\', '/')
    $jsonWindowsHome = $windowsHome.Replace('\', '\\')
    $rendered = $Content.Replace('{{HOME_WINDOWS_JSON}}', $jsonWindowsHome)
    $rendered = $rendered.Replace('{{HOME_WINDOWS}}', $windowsHome)
    return $rendered.Replace('{{HOME_POSIX}}', $posixHome)
}

function Get-BackupPath([string]$Path) {
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullHome = [System.IO.Path]::GetFullPath($HomeRoot).TrimEnd('\', '/') + '\'
    $safe = if ($fullPath.StartsWith($fullHome, [StringComparison]::OrdinalIgnoreCase)) {
        $fullPath.Substring($fullHome.Length)
    }
    else {
        ($fullPath -replace '^[A-Za-z]:', '' -replace '[\\/]+', '\').TrimStart('\')
    }
    return Join-Path (Join-Path $HomeRoot ".agents\backups\$runId") $safe
}

function Backup-Existing([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $backup = Get-BackupPath $Path
    if ($PSCmdlet.ShouldProcess($backup, "Back up $Path")) {
        $parent = Split-Path $backup -Parent
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        Copy-Item -LiteralPath $Path -Destination $backup
    }
}

function Write-TextIfChanged {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [string]$Purpose = 'Write managed harness content'
    )

    $full = [System.IO.Path]::GetFullPath($Path)
    if ((Test-Path -LiteralPath $full -PathType Leaf) -and (Read-Text $full) -ceq $Content) {
        return $false
    }
    if ($PSCmdlet.ShouldProcess($full, $Purpose)) {
        Backup-Existing $full
        $parent = Split-Path $full -Parent
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        $temp = Join-Path $parent ('.harness-' + [Guid]::NewGuid().ToString('N') + '.tmp')
        [System.IO.File]::WriteAllText($temp, $Content, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temp -Destination $full -Force
        $changes.Add($full)
    }
    return $true
}

function Copy-TextIfChanged([string]$Source, [string]$Destination, [string]$Purpose = 'Project managed file') {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Missing source file: $Source"
    }
    return Write-TextIfChanged -Path $Destination -Content (Read-Text $Source) -Purpose $Purpose
}

function Get-MarkedBlock([string]$Content, [string]$Start, [string]$End) {
    $pattern = '(?s)' + [regex]::Escape($Start) + '.*?' + [regex]::Escape($End)
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) { throw "Managed block is missing: $Start" }
    return $match.Value
}

function Set-MarkedBlock {
    param(
        [string]$Target,
        [string]$Template = '',
        [string]$TemplateContent = '',
        [string]$Start,
        [string]$End,
        [string]$LegacyStart = '',
        [string]$LegacyEnd = ''
    )

    $desiredFile = if ($TemplateContent) { $TemplateContent } else { Read-Text $Template }
    $desired = Get-MarkedBlock $desiredFile $Start $End
    if (-not (Test-Path -LiteralPath $Target -PathType Leaf)) {
        [void](Write-TextIfChanged $Target $desiredFile 'Install project contract')
        return
    }

    $existing = Read-Text $Target
    $pattern = '(?s)' + [regex]::Escape($Start) + '.*?' + [regex]::Escape($End)
    if ([regex]::IsMatch($existing, $pattern)) {
        $updated = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $desired }, 1)
        [void](Write-TextIfChanged $Target $updated 'Refresh managed project block')
        return
    }

    if ($LegacyStart -and $LegacyEnd) {
        $legacyPattern = '(?s)' + [regex]::Escape($LegacyStart) + '.*?' + [regex]::Escape($LegacyEnd)
        if ([regex]::IsMatch($existing, $legacyPattern)) {
            $updated = [regex]::Replace($existing, $legacyPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $desired }, 1)
            [void](Write-TextIfChanged $Target $updated 'Upgrade managed project block')
            return
        }
    }

    $updated = $desired + [Environment]::NewLine + [Environment]::NewLine + $existing
    [void](Write-TextIfChanged $Target $updated 'Add managed project block while preserving project content')
}

function Get-RepositoryPath {
    if (-not $Repository) { throw "-Repository is required for action $Action." }
    $resolved = (Resolve-Path -LiteralPath $Repository).Path
    $git = Get-Command git.exe -ErrorAction Stop
    & $git.Source -C $resolved rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) { throw "Path is outside a Git worktree: $resolved" }
    return $resolved
}

function Get-ProjectName([string]$Repo) {
    if ($ProjectName) {
        if ($ProjectName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw "Unsafe project name: $ProjectName" }
        return $ProjectName
    }
    $git = Get-Command git.exe -ErrorAction Stop
    $top = (& $git.Source -C $Repo rev-parse --show-toplevel).Trim()
    return Split-Path $top -Leaf
}

function Invoke-GitForReceivingHome {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $git = Get-Command git.exe -ErrorAction Stop
    $priorHomeExists = Test-Path Env:HOME
    $priorHome = $env:HOME
    $priorUserProfileExists = Test-Path Env:USERPROFILE
    $priorUserProfile = $env:USERPROFILE
    try {
        $env:HOME = $HomeRoot
        $env:USERPROFILE = $HomeRoot
        $output = @(& $git.Source @Arguments 2>&1)
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = ($output -join [Environment]::NewLine).Trim()
        }
    }
    finally {
        if ($priorHomeExists) { $env:HOME = $priorHome } else { Remove-Item Env:HOME -ErrorAction SilentlyContinue }
        if ($priorUserProfileExists) { $env:USERPROFILE = $priorUserProfile } else { Remove-Item Env:USERPROFILE -ErrorAction SilentlyContinue }
    }
}

function Install-ReceivingGitTemplateConfiguration {
    $desiredTemplate = Join-Path $HomeRoot '.agents\git-template'
    $current = Invoke-GitForReceivingHome @('config', '--global', '--get', 'init.templateDir')
    $currentTemplate = if ($current.ExitCode -eq 0) { $current.Output.Replace('/', '\').TrimEnd('\') } else { '' }
    $normalizedDesired = $desiredTemplate.Replace('/', '\').TrimEnd('\')
    if ([string]::Equals($currentTemplate, $normalizedDesired, [StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    $gitConfigPath = Join-Path $HomeRoot '.gitconfig'
    if ($PSCmdlet.ShouldProcess($gitConfigPath, "Set receiving-user init.templateDir to $desiredTemplate")) {
        Backup-Existing $gitConfigPath
        $result = Invoke-GitForReceivingHome @('config', '--global', 'init.templateDir', $desiredTemplate)
        if ($result.ExitCode -ne 0) {
            throw "Unable to configure the receiving user's Git init template: $($result.Output)"
        }
        $changes.Add($gitConfigPath)
    }
}

function Get-Template([string]$Name) {
    return Join-Path $HarnessRoot "templates\$Name"
}

function Get-BaselineManifest {
    $path = Join-Path $HarnessRoot 'manifests\baseline-skills.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing baseline skill manifest: $path" }
    return Read-Text $path | ConvertFrom-Json
}

function Get-CanonicalSkillNames {
    $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($binding in @(Get-BaselineManifest).bindings) {
        foreach ($name in @($binding.canonical)) { [void]$names.Add([string]$name) }
    }
    return @($names | Sort-Object)
}

function Merge-SkillsManifest([string]$Path, [string]$Name) {
    $template = Read-Text (Get-Template 'skills-manifest.json') | ConvertFrom-Json
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        try { $manifest = Read-Text $Path | ConvertFrom-Json }
        catch { throw "Invalid project skills manifest: $Path`n$($_.Exception.Message)" }
    }
    else {
        $manifest = $template
        $manifest.project = $Name
    }

    if (-not $manifest.project -or $manifest.project -eq '<project-name>') { $manifest.project = $Name }
    if (-not $manifest.schemaVersion -or [int]$manifest.schemaVersion -lt 2) { $manifest.schemaVersion = 2 }
    $bindings = [System.Collections.Generic.List[object]]::new()
    foreach ($binding in @($manifest.bindings)) { $bindings.Add($binding) }
    $byCapability = @{}
    foreach ($binding in $bindings) { $byCapability[[string]$binding.capability] = $binding }
    foreach ($baseline in @($template.bindings)) {
        $capability = [string]$baseline.capability
        if (-not $byCapability.ContainsKey($capability)) {
            $bindings.Add($baseline)
            continue
        }
        $existingNames = @($byCapability[$capability].canonical | ForEach-Object { [string]$_ })
        $expectedNames = @($baseline.canonical | ForEach-Object { [string]$_ })
        if (($existingNames -join "`n") -cne ($expectedNames -join "`n")) {
            throw "Project binding '$capability' conflicts with the canonical baseline in $Path."
        }
    }
    $manifest.bindings = @($bindings)
    $json = $manifest | ConvertTo-Json -Depth 8
    [void](Write-TextIfChanged $Path ($json + [Environment]::NewLine) 'Merge canonical project skill bindings')
}

function Ensure-Project {
    $repo = Get-RepositoryPath
    $name = Get-ProjectName $repo

    foreach ($legacy in @('CURRENT-TASK.md', 'WORK_QUEUE.md', 'VERIFY.md')) {
        $legacyPath = Join-Path $repo $legacy
        if (Test-Path -LiteralPath $legacyPath) {
            throw "Legacy active state remains at $legacyPath. Consolidate it into TASK.md and archive the source before project setup."
        }
    }
    if ($WhatIfPreference) {
        return $repo
    }

    Set-MarkedBlock `
        -Target (Join-Path $repo 'AGENTS.md') `
        -Template (Get-Template 'AGENTS.md') `
        -Start '<!-- agent-harness:portable:v3:start -->' `
        -End '<!-- agent-harness:portable:v3:end -->' `
        -LegacyStart '<!-- agent-harness:portable-principles:v2:start -->' `
        -LegacyEnd '<!-- agent-harness:portable-principles:v2:end -->'

    $agentsPath = Join-Path $repo 'AGENTS.md'
    $agents = Read-Text $agentsPath
    $branch = (& git.exe -C $repo symbolic-ref --quiet --short HEAD 2>$null)
    if (-not $branch) { $branch = '<branch>' }
    $agents = $agents.Replace('<project-name>', $name).Replace('<branch>', [string]$branch)
    [void](Write-TextIfChanged $agentsPath $agents 'Resolve project contract identity')

    Set-MarkedBlock `
        -Target (Join-Path $repo 'DESIGN.md') `
        -Template (Get-Template 'DESIGN.md') `
        -Start '<!-- agent-harness:universal-design:v1:start -->' `
        -End '<!-- agent-harness:universal-design:v1:end -->'

    $simple = @(
        @('CLAUDE.md', 'CLAUDE.md'),
        @('MAP.md', 'MAP.md'),
        @('TASK.md', 'TASK.md'),
        @('STATUS.md', 'STATUS.md'),
        @('LOG.md', 'LOG.md'),
        @('BACKBURNER.md', 'BACKBURNER.md'),
        @('MEMORY.md', 'MEMORY.md'),
        @('data-manifest.yaml', 'data-manifest.yaml'),
        @('secret-manifest.json', 'secret-manifest.json'),
        @('.env.example', '.env.example')
    )
    foreach ($pair in $simple) {
        $target = Join-Path $repo $pair[1]
        if (-not (Test-Path -LiteralPath $target)) {
            [void](Copy-TextIfChanged (Get-Template $pair[0]) $target)
        }
    }

    $cursor = Join-Path $repo '.cursor\rules\00-project-contract.mdc'
    if (-not (Test-Path -LiteralPath $cursor)) {
        [void](Copy-TextIfChanged (Get-Template 'cursor-project-contract.mdc') $cursor)
    }

    $dataManifestPath = Join-Path $repo 'data-manifest.yaml'
    $dataManifest = Read-Text $dataManifestPath
    if ($dataManifest.Contains('<project-name>')) {
        [void](Write-TextIfChanged $dataManifestPath ($dataManifest.Replace('<project-name>', $name)) 'Resolve data-manifest project identity')
    }

    $secretManifestPath = Join-Path $repo 'secret-manifest.json'
    $secretManifest = Read-Text $secretManifestPath | ConvertFrom-Json
    $secretProjectName = if ([string]$secretManifest.project -eq '<project-name>') { $name } else { $null }
    $secretUpdateArguments = @{
        Repository = $repo
    }
    if ($secretProjectName) { $secretUpdateArguments.ProjectName = $secretProjectName }
    & (Join-Path $HarnessRoot 'tools\Update-SecretManifest.ps1') @secretUpdateArguments | Out-Null

    $feedback = Join-Path $repo '.agents\feedback\FEEDBACK-LOG.md'
    if (-not (Test-Path -LiteralPath $feedback)) {
        [void](Write-TextIfChanged $feedback @'
# Feedback log

Append-only, value-free correction records. Supersede or retire an entry by appending a record that references its ID.
'@ 'Install project feedback log')
    }

    foreach ($pair in @(
        @('gitleaks\.gitleaks.toml', '.gitleaks.toml'),
        @('gitleaks\gitleaks.yml', '.github\workflows\gitleaks.yml')
    )) {
        $target = Join-Path $repo $pair[1]
        if (-not (Test-Path -LiteralPath $target)) {
            [void](Copy-TextIfChanged (Get-Template $pair[0]) $target 'Install project Gitleaks support')
        }
    }
    & (Join-Path $HarnessRoot 'tools\Enable-Gitleaks.ps1') -Repository $repo | Out-Null

    if ($IncludeProduct) {
        $product = Join-Path $repo 'PRODUCT.md'
        if (-not (Test-Path -LiteralPath $product)) {
            [void](Copy-TextIfChanged (Get-Template 'PRODUCT.md') $product)
        }
    }

    $pathways = Join-Path $repo '.agents\skill-pathways.json'
    if (-not (Test-Path -LiteralPath $pathways)) {
        [void](Copy-TextIfChanged (Join-Path $HarnessRoot 'skill-pathways.json') $pathways)
    }

    Merge-SkillsManifest (Join-Path $repo 'skills-manifest.json') $name
    Write-ProjectProvenance $repo
    return $repo
}

function Get-TreeHash([string]$Root) {
    $rows = Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
        Where-Object { $_.Name -ne '.projection.json' } |
        ForEach-Object {
            $relative = $_.FullName.Substring($Root.Length).TrimStart('\')
            "$relative`t$(Get-Sha256File $_.FullName)"
        } |
        Sort-Object
    return Get-Sha256Text ($rows -join "`n")
}

function Sync-ProjectSkills([string]$Repo) {
    $manifestPath = Join-Path $Repo 'skills-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Missing skills manifest: $manifestPath" }
    $manifest = Read-Text $manifestPath | ConvertFrom-Json
    $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($binding in @($manifest.bindings)) {
        foreach ($name in @($binding.canonical)) { [void]$names.Add([string]$name) }
    }

    foreach ($name in @($names | Sort-Object)) {
        if ($name -notmatch '^[a-z0-9][a-z0-9-]+$') { throw "Unsafe canonical skill name: $name" }
        $source = Join-Path $HarnessRoot "skills\$name"
        if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md'))) {
            throw "Canonical skill is missing: $source"
        }
        $target = Join-Path $Repo ".agents\skills\$name"
        $marker = Join-Path $target '.projection.json'
        $sourceHash = Get-TreeHash $source

        if (Test-Path -LiteralPath $target) {
            if (-not (Test-Path -LiteralPath $marker)) {
                $preserved.Add("$target (project-owned skill)")
                continue
            }
            $projection = Read-Text $marker | ConvertFrom-Json
            if ([string]$projection.source -ne $source) {
                throw "Skill projection marker has a different owner: $marker"
            }
            if ([string]$projection.sha256 -eq $sourceHash -and (Get-TreeHash $target) -eq $sourceHash) {
                continue
            }
        }

        if ($PSCmdlet.ShouldProcess($target, "Project canonical skill $name")) {
            if (Test-Path -LiteralPath $target) {
                $backup = Get-BackupPath $target
                New-Item -ItemType Directory -Path (Split-Path $backup -Parent) -Force | Out-Null
                Copy-Item -LiteralPath $target -Destination $backup -Recurse
                Remove-Item -LiteralPath $target -Recurse -Force
            }
            New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Recurse
            $projection = [ordered]@{
                schemaVersion = 1
                name = $name
                source = $source
                sha256 = $sourceHash
            }
            [System.IO.File]::WriteAllText(
                $marker,
                ($projection | ConvertTo-Json -Depth 4) + [Environment]::NewLine,
                [System.Text.UTF8Encoding]::new($false)
            )
            $changes.Add($target)
        }
    }
}

function Get-ProjectProvenanceEntries([string]$Repo) {
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($relative in @(
        'AGENTS.md', 'CLAUDE.md', '.cursor\rules\00-project-contract.mdc', 'DESIGN.md',
        'MAP.md', 'TASK.md', 'STATUS.md', 'LOG.md', 'BACKBURNER.md', 'MEMORY.md',
        'skills-manifest.json', 'data-manifest.yaml', 'secret-manifest.json', 'secret-manifest.md',
        '.env.example', '.gitleaks.toml', '.github\workflows\gitleaks.yml',
        '.agents\feedback\FEEDBACK-LOG.md', '.agents\skill-pathways.json'
    )) {
        $path = Join-Path $Repo $relative
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $entries.Add([ordered]@{ path = $relative; sha256 = Get-Sha256File $path })
        }
    }
    if (Test-Path -LiteralPath (Join-Path $Repo 'PRODUCT.md')) {
        $entries.Add([ordered]@{ path = 'PRODUCT.md'; sha256 = Get-Sha256File (Join-Path $Repo 'PRODUCT.md') })
    }
    return @($entries)
}

function Write-ProjectProvenance([string]$Repo) {
    $provenance = [ordered]@{
        schemaVersion = 1
        authority = $projectProvenanceAuthority
        files = @(Get-ProjectProvenanceEntries $Repo)
    }
    $target = Join-Path $Repo '.agents\harness-provenance.json'
    [void](Write-TextIfChanged $target (($provenance | ConvertTo-Json -Depth 6) + [Environment]::NewLine) 'Record project harness provenance')
}

function Test-ProjectProvenance(
    [string]$Repo,
    [System.Collections.Generic.List[string]]$Failures
) {
    $path = Join-Path $Repo '.agents\harness-provenance.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return
    }

    try {
        $provenance = Read-Text $path | ConvertFrom-Json
        if ([int]$provenance.schemaVersion -ne 1) {
            throw 'schemaVersion must be 1'
        }
        if (-not [string]::Equals(
            [string]$provenance.authority,
            $projectProvenanceAuthority,
            [StringComparison]::Ordinal
        )) {
            throw "authority must be '$projectProvenanceAuthority'"
        }

        $expectedEntries = @(Get-ProjectProvenanceEntries $Repo)
        $actualEntries = @($provenance.files)
        if ($actualEntries.Count -ne $expectedEntries.Count) {
            throw "file count is $($actualEntries.Count); expected $($expectedEntries.Count)"
        }

        $actualByPath = @{}
        foreach ($entry in $actualEntries) {
            $relative = [string]$entry.path
            if ([string]::IsNullOrWhiteSpace($relative) -or
                [System.IO.Path]::IsPathRooted($relative) -or
                @($relative -split '[/\\]' | Where-Object { $_ -in @('', '.', '..') }).Count) {
                throw "unsafe relative path '$relative'"
            }
            $key = $relative.Replace('/', '\')
            if ($actualByPath.ContainsKey($key)) {
                throw "duplicate path '$relative'"
            }
            if ([string]$entry.sha256 -notmatch '^[a-f0-9]{64}$') {
                throw "invalid SHA-256 for '$relative'"
            }
            $actualByPath[$key] = [string]$entry.sha256
        }

        foreach ($expected in $expectedEntries) {
            $key = ([string]$expected.path).Replace('/', '\')
            if (-not $actualByPath.ContainsKey($key)) {
                throw "missing file record '$key'"
            }
            if (-not [string]::Equals(
                [string]$actualByPath[$key],
                [string]$expected.sha256,
                [StringComparison]::Ordinal
            )) {
                throw "stale SHA-256 for '$key'"
            }
        }
    }
    catch {
        Add-Failure $Failures "Project harness provenance is invalid: $($_.Exception.Message)"
    }
}

function Install-CanonicalPackage([string]$TargetAgents) {
    $relativeFiles = [System.Collections.Generic.List[string]]::new()
    foreach ($name in @('AGENTS.md', 'DESIGN.md', 'MAP.md', 'MEMORY.md')) { $relativeFiles.Add($name) }
    $relativeFiles.Add('skill-pathways.json')
    foreach ($name in @(
        'CLAUDE-SKILL-ADAPTERS.json',
        'DOCKET-PROTOCOL.md',
        'PORTABLE-PRINCIPLES.md',
        'SKILL-PORTABILITY-CONTRACT.md',
        'WORKTREE-PROTOCOL.md'
    )) {
        if (Test-Path -LiteralPath (Join-Path $HarnessRoot $name) -PathType Leaf) {
            $relativeFiles.Add($name)
        }
    }
    foreach ($dir in @('adapters', 'templates', 'manifests', 'skills', 'tools', 'capsule', 'git-template')) {
        $sourceDir = Join-Path $HarnessRoot $dir
        if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $sourceDir -Recurse -File) {
            $relativeFiles.Add($file.FullName.Substring($HarnessRoot.Length).TrimStart('\'))
        }
    }

    foreach ($relative in @($relativeFiles | Sort-Object -Unique)) {
        $source = Join-Path $HarnessRoot $relative
        $target = Join-Path $TargetAgents $relative
        if ([System.IO.Path]::GetFullPath($source) -ne [System.IO.Path]::GetFullPath($target)) {
            [void](Copy-TextIfChanged $source $target 'Install canonical harness package')
        }
    }
}

function Install-HumanGuide([string]$TargetAgents) {
    $sourceRoot = Get-HumanGuideRoot
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        throw "Human guide source is unavailable: $sourceRoot"
    }
    $targetRoot = Join-Path $TargetAgents 'human-readable'
    if ([System.IO.Path]::GetFullPath($sourceRoot) -eq [System.IO.Path]::GetFullPath($targetRoot)) {
        return
    }
    foreach ($file in Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Force) {
        if ($file.Extension -notin @('.md', '.html', '.json')) { continue }
        if ($file.Name -in @('setup-stamp.json', 'guide-provenance.json')) { continue }
        $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
        [void](Copy-TextIfChanged $file.FullName (Join-Path $targetRoot $relative) 'Install human-readable harness guide')
    }
    $guideProvenance = [ordered]@{
        schemaVersion = 1
        files = @(
            [ordered]@{ path = 'README.md'; sha256 = Get-Sha256File (Join-Path $sourceRoot 'README.md') },
            [ordered]@{ path = 'README.html'; sha256 = Get-Sha256File (Join-Path $sourceRoot 'README.html') }
        )
    }
    [void](Write-TextIfChanged `
        (Join-Path $targetRoot 'guide-provenance.json') `
        (($guideProvenance | ConvertTo-Json -Depth 4) + [Environment]::NewLine) `
        'Install authenticated human-guide provenance')
}

function Archive-LegacyHumanFiles([string]$TargetAgents) {
    $targetRoot = Join-Path $TargetAgents 'human-readable'
    if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) { return }
    $activeNames = @('README.md', 'README.html', 'CHANGELOG.md', 'UPDATE-PROTOCOL.md', 'guide-provenance.json')
    foreach ($file in Get-ChildItem -LiteralPath $targetRoot -File -Force) {
        if ($file.Name -in $activeNames) { continue }
        $archiveRoot = Join-Path $targetRoot "archive\pre-consolidation\$runId"
        $target = Join-Path $archiveRoot $file.Name
        if ($PSCmdlet.ShouldProcess($file.FullName, "Archive superseded human-readable file as $target")) {
            New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
            Move-Item -LiteralPath $file.FullName -Destination $target
            $changes.Add($file.FullName)
        }
    }
}

function Get-TaskHookSourceRoot {
    $inside = Join-Path $HarnessRoot 'task-hooks'
    if (Test-Path -LiteralPath (Join-Path $inside 'hooks') -PathType Container) { return $inside }
    $sibling = Join-Path (Split-Path $HarnessRoot -Parent) 'task-hooks'
    if (Test-Path -LiteralPath (Join-Path $sibling 'hooks') -PathType Container) { return $sibling }
    return $null
}

function Install-HookPackage([string]$TargetAgents) {
    $sourceRoot = Get-TaskHookSourceRoot
    $targetHooks = Join-Path $TargetAgents 'hooks'
    if (-not $sourceRoot) {
        foreach ($entrypoint in @('security-dispatch.js', 'task-state-dispatch.js', 'continue-dispatch.js')) {
            if (-not (Test-Path -LiteralPath (Join-Path $targetHooks $entrypoint) -PathType Leaf)) {
                throw "Portable task-hook source is unavailable and the installed entrypoint is missing: $entrypoint"
            }
        }
        return
    }

    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'hooks') -Recurse -File -Force) {
        $relative = $file.FullName.Substring((Join-Path $sourceRoot 'hooks').Length).TrimStart('\')
        [void](Copy-TextIfChanged $file.FullName (Join-Path $targetHooks $relative) 'Install consolidated hook package')
    }
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $sourceRoot 'config') -File -Force) {
        [void](Copy-TextIfChanged $file.FullName (Join-Path $TargetAgents "hook-config\$($file.Name)") 'Install product hook configuration example')
    }
    [void](Copy-TextIfChanged (Join-Path $sourceRoot 'tools\Migrate-TaskState.ps1') (Join-Path $TargetAgents 'tools\Migrate-TaskState.ps1') 'Install TASK migration tool')
    [void](Copy-TextIfChanged (Join-Path $sourceRoot 'README.md') (Join-Path $targetHooks 'README.md') 'Install hook package reference')
}

function Set-JsonProperty([object]$Object, [string]$Name, [object]$Value) {
    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        $property.Value = $Value
    }
    else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Install-ProductHookWiring {
    $sourceRoot = Get-TaskHookSourceRoot
    if (-not $sourceRoot) {
        $sourceRoot = $HarnessRoot
        $sourceConfig = Join-Path $HarnessRoot 'hook-config'
    }
    else {
        $sourceConfig = Join-Path $sourceRoot 'config'
    }
    foreach ($spec in @(
        @{ Product = 'claude'; Source = 'claude-hooks.example.json'; Target = (Join-Path $HomeRoot '.claude\settings.json') },
        @{ Product = 'codex'; Source = 'codex-hooks.example.json'; Target = (Join-Path $HomeRoot '.codex\hooks.json') },
        @{ Product = 'cursor'; Source = 'cursor-hooks.example.json'; Target = (Join-Path $HomeRoot '.cursor\hooks.json') }
    )) {
        $sourcePath = Join-Path $sourceConfig $spec.Source
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Hook configuration source is unavailable: $sourcePath"
        }
        $desired = Render-HomeTokens (Read-Text $sourcePath) | ConvertFrom-Json
        if (Test-Path -LiteralPath $spec.Target -PathType Leaf) {
            try { $targetObject = Read-Text $spec.Target | ConvertFrom-Json }
            catch { throw "Existing $($spec.Product) hook settings are invalid JSON: $($spec.Target)" }
        }
        else {
            $targetObject = [pscustomobject]@{}
        }
        Set-JsonProperty $targetObject 'hooks' $desired.hooks
        if ($desired.PSObject.Properties['version']) {
            Set-JsonProperty $targetObject 'version' $desired.version
        }
        [void](Write-TextIfChanged `
            $spec.Target `
            (($targetObject | ConvertTo-Json -Depth 100) + [Environment]::NewLine) `
            "Activate consolidated $($spec.Product) hook wiring")
    }
}

function Add-HookCommands([object]$Node, [System.Collections.Generic.List[string]]$Commands) {
    if ($null -eq $Node -or $Node -is [string]) { return }
    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($item in $Node) { Add-HookCommands $item $Commands }
        return
    }
    foreach ($property in $Node.PSObject.Properties) {
        if ($property.Name -eq 'command' -and $property.Value -is [string]) {
            $Commands.Add([string]$property.Value)
        }
        else {
            Add-HookCommands $property.Value $Commands
        }
    }
}

function Verify-HookWiring {
    $failures = [System.Collections.Generic.List[string]]::new()
    $allowed = @('security-dispatch.js', 'task-state-dispatch.js', 'continue-dispatch.js')
    $targetHooks = Join-Path $HomeRoot '.agents\hooks'
    foreach ($spec in @(
        @{ Product = 'claude'; Target = (Join-Path $HomeRoot '.claude\settings.json') },
        @{ Product = 'codex'; Target = (Join-Path $HomeRoot '.codex\hooks.json') },
        @{ Product = 'cursor'; Target = (Join-Path $HomeRoot '.cursor\hooks.json') }
    )) {
        if (-not (Test-Path -LiteralPath $spec.Target -PathType Leaf)) {
            Add-Failure $failures "Missing active $($spec.Product) hook settings: $($spec.Target)"
            continue
        }
        try { $settings = Read-Text $spec.Target | ConvertFrom-Json }
        catch {
            Add-Failure $failures "Invalid active $($spec.Product) hook settings: $($spec.Target)"
            continue
        }
        $commands = [System.Collections.Generic.List[string]]::new()
        Add-HookCommands $settings.hooks $commands
        if (-not $commands.Count) {
            Add-Failure $failures "No active $($spec.Product) hook commands were found."
            continue
        }
        $found = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($command in $commands) {
            if ($command.Contains('{{HOME_')) {
                Add-Failure $failures "Unrendered home token in active $($spec.Product) hook command."
                continue
            }
            $match = [regex]::Match($command, '(?i)[\\/]\.agents[\\/]hooks[\\/](?<name>[A-Za-z0-9_.-]+\.js)')
            if (-not $match.Success) {
                Add-Failure $failures "Active $($spec.Product) hook command bypasses the consolidated hook root: $command"
                continue
            }
            $name = $match.Groups['name'].Value
            if ($name -notin $allowed) {
                Add-Failure $failures "Active $($spec.Product) hook command references an extra entrypoint: $name"
                continue
            }
            [void]$found.Add($name)
            if (-not (Test-Path -LiteralPath (Join-Path $targetHooks $name) -PathType Leaf)) {
                Add-Failure $failures "Active $($spec.Product) hook entrypoint is missing: $name"
            }
        }
        foreach ($name in $allowed) {
            if (-not $found.Contains($name)) {
                Add-Failure $failures "Active $($spec.Product) hook wiring is missing: $name"
            }
        }
    }
    if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
    return 'Active product hook wiring uses exactly the three consolidated entrypoints.'
}

function Get-ThinSkillProjection([string]$Name) {
    $canonical = Join-Path $HomeRoot ".agents\skills\$Name\SKILL.md"
    return @"
---
name: $Name
description: "Local projection of the canonical $Name skill. Use when the canonical skill's trigger matches."
---

# Canonical skill projection

Read and follow $canonical.

<!-- agent-harness:canonical-skill-projection:v1 -->
"@
}

function Archive-LegacyGlobalFiles([string]$TargetAgents) {
    foreach ($name in @('HARNESS-MAP.md', 'CROSS-AGENT-CONTRACT.md', 'FEEDBACK-ROUTER.md')) {
        $source = Join-Path $TargetAgents $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
        $archiveRoot = Join-Path $TargetAgents 'archive\legacy-contracts'
        $target = Join-Path $archiveRoot $name
        if ((Test-Path -LiteralPath $target) -and (Read-Text $target) -cne (Read-Text $source)) {
            $target = Join-Path $archiveRoot ($name + '.' + $runId + '.md')
        }
        if ($PSCmdlet.ShouldProcess($source, "Archive stale global contract as $target")) {
            New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $source -Force
            }
            else {
                Move-Item -LiteralPath $source -Destination $target
            }
            $changes.Add($source)
        }
    }
}

function Remove-RetiredManagedFiles([string]$TargetAgents) {
    $retired = @(
        'capsule\Run-BitwardenScaffoldInteractive.ps1',
        'capsule\Run-BitwardenScaffoldInteractive.Tests.ps1',
        'tools\bitwarden-project-scaffolds.json',
        'tools\Invoke-WithBitwardenItem.cmd',
        'tools\Invoke-WithBitwardenItem.ps1',
        'tools\Invoke-WithBitwardenItem.test.ps1',
        'tools\New-BitwardenProjectScaffolds.ps1',
        'tools\New-BitwardenProjectScaffolds.Tests.ps1',
        'tools\.local\bitwarden-scaffold-ids.json'
    )
    foreach ($relativePath in $retired) {
        $target = Join-Path $TargetAgents $relativePath
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { continue }
        if ($PSCmdlet.ShouldProcess($target, 'Back up and remove retired Bitwarden Password Manager artifact')) {
            Backup-Existing $target
            Remove-Item -LiteralPath $target -Force
            $changes.Add($target)
        }
    }
}

function Install-Global {
    $targetAgents = Join-Path $HomeRoot '.agents'
    Install-CanonicalPackage $targetAgents
    Remove-RetiredManagedFiles $targetAgents
    Install-ReceivingGitTemplateConfiguration
    Install-HumanGuide $targetAgents
    Archive-LegacyHumanFiles $targetAgents
    Install-HookPackage $targetAgents
    Archive-LegacyGlobalFiles $targetAgents
    if ($ActivateHooks) {
        Install-ProductHookWiring
    }
    else {
        $gates.Add('Hooks are staged. Rerun InstallGlobal with -ActivateHooks after reviewing the timestamped product-setting backups.')
    }

    $claudeAdapter = Render-HomeTokens (Read-Text (Join-Path $HarnessRoot 'adapters\claude\CLAUDE.md'))
    Set-MarkedBlock `
        -Target (Join-Path $HomeRoot '.claude\CLAUDE.md') `
        -TemplateContent $claudeAdapter `
        -Start '<!-- agent-harness:claude-loader:v1:start -->' `
        -End '<!-- agent-harness:claude-loader:v1:end -->'
    [void](Write-TextIfChanged `
        (Join-Path $HomeRoot '.codex\AGENTS.proposed.md') `
        (Render-HomeTokens (Read-Text (Join-Path $HarnessRoot 'adapters\codex\AGENTS.proposed.md'))) `
        'Write Codex loader proposal while preserving live AGENTS.md')
    [void](Write-TextIfChanged `
        (Join-Path $HomeRoot '.cursor\user-rules.txt') `
        (Render-HomeTokens (Read-Text (Join-Path $HarnessRoot 'adapters\cursor\user-rules.txt'))) `
        'Write Cursor plain-text user-rules projection')
    $legacyCursorRule = Join-Path $HomeRoot '.cursor\rules\00-cross-agent-contract.mdc'
    if (Test-Path -LiteralPath $legacyCursorRule -PathType Leaf) {
        if ($PSCmdlet.ShouldProcess($legacyCursorRule, 'Back up and remove superseded Cursor global harness rule')) {
            Backup-Existing $legacyCursorRule
            Remove-Item -LiteralPath $legacyCursorRule -Force
            $changes.Add($legacyCursorRule)
        }
    }
    [void](Write-TextIfChanged `
        (Join-Path $HomeRoot '.cursor\rules\00-agent-harness.mdc') `
        (Render-HomeTokens (Read-Text (Join-Path $HarnessRoot 'adapters\cursor\00-agent-harness.mdc'))) `
        'Install Cursor global harness rule')

    foreach ($name in Get-CanonicalSkillNames) {
        $projection = Get-ThinSkillProjection $name
        foreach ($surface in @('.claude', '.cursor')) {
            $target = Join-Path $HomeRoot "$surface\skills\$name\SKILL.md"
            [void](Write-TextIfChanged $target $projection "Install thin $surface skill projection")
        }
    }

    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($path in @(
        (Join-Path $HomeRoot '.claude\CLAUDE.md'),
        (Join-Path $HomeRoot '.codex\AGENTS.proposed.md'),
        (Join-Path $HomeRoot '.cursor\user-rules.txt'),
        (Join-Path $HomeRoot '.cursor\rules\00-agent-harness.mdc')
    )) {
        if (Test-Path -LiteralPath $path) {
            $entries.Add([ordered]@{ path = $path; sha256 = Get-Sha256File $path })
        }
    }
    $provenance = [ordered]@{
        schemaVersion = 1
        authority = $targetAgents
        productProjections = @($entries)
    }
    [void](Write-TextIfChanged `
        (Join-Path $targetAgents 'provenance.json') `
        (($provenance | ConvertTo-Json -Depth 5) + [Environment]::NewLine) `
        'Record global harness provenance')
}

function Get-HumanGuideRoot {
    $inside = Join-Path $HarnessRoot 'human-readable'
    if (Test-Path -LiteralPath $inside -PathType Container) { return $inside }
    $sibling = Join-Path (Split-Path $HarnessRoot -Parent) 'human-readable'
    if (Test-Path -LiteralPath $sibling -PathType Container) { return $sibling }
    return $inside
}

function Verify-HumanGuide {
    $root = Get-HumanGuideRoot
    $markdown = Join-Path $root 'README.md'
    $html = Join-Path $root 'README.html'
    $generator = Join-Path $HarnessRoot 'tools\Convert-HumanGuide.ps1'
    if (-not (Test-Path -LiteralPath $markdown -PathType Leaf)) { throw "Missing human guide source: $markdown" }
    if (-not (Test-Path -LiteralPath $html -PathType Leaf)) { throw "Missing human guide mirror: $html" }
    if (-not (Test-Path -LiteralPath $generator -PathType Leaf)) { throw "Missing human guide generator: $generator" }
    $content = Read-Text $html
    $expectedContent = & $generator -MarkdownPath $markdown
    if ($content -cne $expectedContent) {
        throw "Human guide HTML differs from its deterministic render: $html"
    }
    $stampPath = Join-Path $HarnessRoot 'setup-stamp.json'
    if (Test-Path -LiteralPath $stampPath -PathType Leaf) {
        $stamp = Read-Text $stampPath | ConvertFrom-Json
        $htmlRecords = @($stamp.files | Where-Object {
            ([string]$_.path).Replace('\', '/') -eq 'human-readable/README.html'
        })
        if ($htmlRecords.Count -ne 1 -or
            -not [string]::Equals(
                [string]$htmlRecords[0].sha256,
                (Get-Sha256File $html),
                [StringComparison]::OrdinalIgnoreCase
            )) {
            throw 'Human guide HTML differs from the exact version authenticated by setup-stamp.json.'
        }
        return 'Human guide deterministic render and authenticated HTML body passed.'
    }

    $provenancePath = Join-Path $root 'guide-provenance.json'
    if (-not (Test-Path -LiteralPath $provenancePath -PathType Leaf)) {
        throw "Human guide verification requires authenticated guide provenance: $provenancePath"
    }
    $provenance = Read-Text $provenancePath | ConvertFrom-Json
    foreach ($expected in @(
        @{ path = 'README.md'; fullPath = $markdown },
        @{ path = 'README.html'; fullPath = $html }
    )) {
        $records = @($provenance.files | Where-Object { [string]$_.path -eq $expected.path })
        if ($records.Count -ne 1 -or
            -not [string]::Equals(
                [string]$records[0].sha256,
                (Get-Sha256File $expected.fullPath),
                [StringComparison]::OrdinalIgnoreCase
            )) {
            throw "Human guide file differs from installed authenticated provenance: $($expected.path)"
        }
    }
    return 'Human guide deterministic render and authenticated HTML body passed.'
}

function Add-Failure([System.Collections.Generic.List[string]]$Failures, [string]$Message) {
    $Failures.Add($Message)
}

function Assert-TextContains(
    [System.Collections.Generic.List[string]]$Failures,
    [string]$Path,
    [string[]]$Patterns
) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Failure $Failures "Missing file: $Path"
        return
    }
    $content = Read-Text $Path
    foreach ($pattern in $Patterns) {
        if (-not $content.Contains($pattern)) { Add-Failure $Failures "Missing '$pattern' in $Path" }
    }
}

function Verify-Global {
    $failures = [System.Collections.Generic.List[string]]::new()
    foreach ($relative in @(
        'AGENTS.md', 'DESIGN.md', 'MAP.md', 'MEMORY.md', 'skill-pathways.json',
        'adapters\claude\CLAUDE.md',
        'adapters\codex\AGENTS.proposed.md',
        'adapters\cursor\user-rules.txt',
        'manifests\baseline-skills.json',
        'skills\correct\SKILL.md',
        'skills\correct\scripts\Record-Correction.ps1',
        'skills\correct\scripts\Record-Correction.test.ps1',
        'skills\feedback\SKILL.md',
        'tools\Manage-Harness.ps1', 'tools\Convert-HumanGuide.ps1',
        'tools\Convert-HumanGuide.test.ps1',
        'templates\AGENTS.md', 'templates\CLAUDE.md',
        'templates\cursor-project-contract.mdc', 'templates\DESIGN.md', 'templates\MAP.md',
        'templates\TASK.md', 'templates\STATUS.md', 'templates\LOG.md',
        'templates\BACKBURNER.md', 'templates\MEMORY.md', 'templates\PRODUCT.md',
        'templates\skills-manifest.json', 'templates\data-manifest.yaml',
        'templates\data-manifest.schema.v2.json', 'templates\secret-manifest.json',
        'templates\.env.example', 'templates\gitleaks\.gitleaks.toml',
        'templates\gitleaks\gitleaks.yml', 'templates\gitleaks\pre-commit',
        'tools\Test-DataManifest.ps1', 'tools\Update-SecretManifest.ps1',
        'tools\Update-SecretManifest.test.ps1'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $HarnessRoot $relative) -PathType Leaf)) {
            Add-Failure $failures "Missing global harness file: $relative"
        }
    }

    $hookSource = Get-TaskHookSourceRoot
    if ($hookSource) {
        $hookRuntime = Join-Path $hookSource 'hooks'
        $hookConfig = Join-Path $hookSource 'config'
        $migrationTool = Join-Path $hookSource 'tools\Migrate-TaskState.ps1'
    }
    else {
        $hookRuntime = Join-Path $HarnessRoot 'hooks'
        $hookConfig = Join-Path $HarnessRoot 'hook-config'
        $migrationTool = Join-Path $HarnessRoot 'tools\Migrate-TaskState.ps1'
    }
    foreach ($relative in @(
        'security-dispatch.js', 'task-state-dispatch.js', 'continue-dispatch.js',
        'lib\completion-loop.js', 'lib\lifecycle-diagnostics.js', 'lib\notifications.js',
        'lib\task-state.js', 'lib\toast-worker.js', 'lib\usage-limit.js'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $hookRuntime $relative) -PathType Leaf)) {
            Add-Failure $failures "Missing consolidated hook file: $relative"
        }
    }
    $rootEntrypoints = @(Get-ChildItem -LiteralPath $hookRuntime -File -Filter '*.js' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object)
    $expectedEntrypoints = @('continue-dispatch.js', 'security-dispatch.js', 'task-state-dispatch.js')
    if (($rootEntrypoints -join ',') -ne ($expectedEntrypoints -join ',')) {
        Add-Failure $failures "Hook root must expose exactly three JavaScript entrypoints; found: $($rootEntrypoints -join ', ')"
    }
    foreach ($configName in @('claude-hooks.example.json', 'codex-hooks.example.json', 'cursor-hooks.example.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $hookConfig $configName) -PathType Leaf)) {
            Add-Failure $failures "Missing hook configuration example: $configName"
        }
    }
    if (-not (Test-Path -LiteralPath $migrationTool -PathType Leaf)) {
        Add-Failure $failures 'Missing TASK migration tool.'
    }

    foreach ($legacy in @('HARNESS-MAP.md', 'CROSS-AGENT-CONTRACT.md', 'FEEDBACK-ROUTER.md', 'CURRENT-TASK.md', 'WORK_QUEUE.md', 'VERIFY.md')) {
        if (Test-Path -LiteralPath (Join-Path $HarnessRoot $legacy)) {
            Add-Failure $failures "Stale active architecture file: $legacy"
        }
        if (Test-Path -LiteralPath (Join-Path $HarnessRoot "templates\$legacy")) {
            Add-Failure $failures "Stale project template: $legacy"
        }
    }

    Assert-TextContains $failures (Join-Path $HarnessRoot 'AGENTS.md') @(
        '## Existing-system-first rule',
        'the `correct` skill',
        'Use `TASK.md`'
    )
    Assert-TextContains $failures (Get-Template 'AGENTS.md') @(
        '<!-- agent-harness:portable:v3:start -->',
        'search the repository and available shared harness',
        '`TASK.md`'
    )
    Assert-TextContains $failures (Get-Template 'DESIGN.md') @(
        '<!-- agent-harness:universal-design:v1:start -->',
        'Never use IBM Plex Mono'
    )
    Assert-TextContains $failures (Join-Path $HarnessRoot 'adapters\codex\AGENTS.proposed.md') @(
        'This file is a proposal',
        'preserves the user-edited live'
    )
    Assert-TextContains $failures (Join-Path $HarnessRoot 'adapters\cursor\user-rules.txt') @(
        'Cursor Settings > Rules > User Rules'
    )
    foreach ($adapter in @(
        'adapters\claude\CLAUDE.md',
        'adapters\codex\AGENTS.proposed.md',
        'adapters\cursor\user-rules.txt'
    )) {
        $adapterPath = Join-Path $HarnessRoot $adapter
        if ((Read-Text $adapterPath) -match '(?i)C:[/\\]Users[/\\][^/\\]+') {
            Add-Failure $failures "Adapter contains a hard-coded Windows user profile: $adapter"
        }
    }
    $taskTemplate = Read-Text (Get-Template 'TASK.md')
    if ($taskTemplate -match '(?m)^\s*-\s*\[(?: |~)\]\s+') {
        Add-Failure $failures 'TASK.md template contains an actionable placeholder.'
    }

    try {
        $baseline = Get-BaselineManifest
        $actual = @($baseline.bindings | ForEach-Object { [string]$_.capability })
        foreach ($required in @('deep-search', 'recon', 'ultra-skill', 'task-design', 'design-review', 'docket', 'harden-tail', 'probe', 'spar', 'spec', 'correct')) {
            if ($actual -notcontains $required) { Add-Failure $failures "Baseline skill mapping is missing: $required" }
        }
        $harden = @($baseline.bindings | Where-Object { $_.capability -eq 'harden-tail' })[0]
        if ((@($harden.canonical) -join ',') -ne 'source-command-pathway,source-command-solo-review,source-command-probe,source-command-hone,source-command-spar') {
            Add-Failure $failures 'harden-tail must map to the pathway runner and every installed step skill.'
        }
        if ((@($harden.steps) -join ',') -ne 'solo-review,probe,hone,spar') {
            Add-Failure $failures 'harden-tail step order drifted from the installed chain.'
        }
        $taskDesign = @($baseline.bindings | Where-Object { $_.capability -eq 'task-design' })[0]
        if ((@($taskDesign.canonical) -join ',') -ne 'source-command-task,source-command-design') {
            Add-Failure $failures 'task-design must map to both intake triage and whole-feature design.'
        }
        foreach ($name in Get-CanonicalSkillNames) {
            if (-not (Test-Path -LiteralPath (Join-Path $HarnessRoot "skills\$name\SKILL.md") -PathType Leaf)) {
                Add-Failure $failures "Baseline canonical skill is missing from the portable package: $name"
            }
        }
    }
    catch { Add-Failure $failures "Baseline skill manifest is invalid: $($_.Exception.Message)" }

    try { [void](Verify-HumanGuide) }
    catch { Add-Failure $failures $_.Exception.Message }

    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $HarnessRoot 'tools\Manage-Harness.ps1'),
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count) { Add-Failure $failures 'Manage-Harness.ps1 has PowerShell parse errors.' }
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $HarnessRoot 'skills\correct\scripts\Record-Correction.ps1'),
        [ref]$tokens,
        [ref]$errors
    )
    if ($errors.Count) { Add-Failure $failures 'Record-Correction.ps1 has PowerShell parse errors.' }

    $stampPath = Join-Path $HarnessRoot 'setup-stamp.json'
    if (Test-Path -LiteralPath $stampPath) {
        try {
            $stamp = Read-Text $stampPath | ConvertFrom-Json
            foreach ($entry in @($stamp.files)) {
                $path = Join-Path $HarnessRoot ([string]$entry.path)
                if (-not (Test-Path -LiteralPath $path)) {
                    Add-Failure $failures "Stamped file is missing: $($entry.path)"
                }
                elseif ((Get-SetupStampHash $path) -ne [string]$entry.sha256) {
                    Add-Failure $failures "Stamped file drifted: $($entry.path)"
                }
            }
        }
        catch { Add-Failure $failures "Setup stamp is invalid: $($_.Exception.Message)" }
    }

    if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
    return 'Global harness verification passed.'
}

function Verify-Project {
    $repo = Get-RepositoryPath
    $failures = [System.Collections.Generic.List[string]]::new()
    foreach ($relative in @(
        'AGENTS.md', 'CLAUDE.md', '.cursor\rules\00-project-contract.mdc',
        'DESIGN.md', 'MAP.md', 'TASK.md', 'STATUS.md', 'LOG.md',
        'BACKBURNER.md', 'MEMORY.md', 'skills-manifest.json', 'data-manifest.yaml',
        'secret-manifest.json', 'secret-manifest.md', '.env.example',
        '.gitleaks.toml', '.github\workflows\gitleaks.yml',
        '.agents\feedback\FEEDBACK-LOG.md', '.agents\skill-pathways.json',
        '.agents\harness-provenance.json'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $repo $relative) -PathType Leaf)) {
            Add-Failure $failures "Missing project file: $relative"
        }
    }
    foreach ($legacy in @('CURRENT-TASK.md', 'WORK_QUEUE.md', 'VERIFY.md')) {
        if (Test-Path -LiteralPath (Join-Path $repo $legacy)) {
            Add-Failure $failures "Stale active project architecture file: $legacy"
        }
    }
    Assert-TextContains $failures (Join-Path $repo 'AGENTS.md') @(
        '<!-- agent-harness:portable:v3:start -->',
        'Before creating, replacing, renaming, or removing an artifact',
        '`TASK.md`'
    )
    Assert-TextContains $failures (Join-Path $repo 'DESIGN.md') @(
        '<!-- agent-harness:universal-design:v1:start -->',
        'Never use IBM Plex Mono'
    )
    Assert-TextContains $failures (Join-Path $repo 'TASK.md') @(
        '## Goal', '## Active', '## Queue', '## Blocked',
        '## Needs decision', '## Completed', '## Verification'
    )
    $taskPath = Join-Path $repo 'TASK.md'
    if ((Test-Path -LiteralPath $taskPath -PathType Leaf) -and
        (Read-Text $taskPath) -match '(?im)^\s*##\s+Answers\s*$') {
        Add-Failure $failures 'TASK.md contains a forbidden Answers section; keep answers in chat or durable topic documentation.'
    }
    Test-ProjectProvenance $repo $failures
    try {
        $manifest = Read-Text (Join-Path $repo 'skills-manifest.json') | ConvertFrom-Json
        $actual = @($manifest.bindings | ForEach-Object { [string]$_.capability })
        foreach ($required in @((Get-BaselineManifest).bindings | ForEach-Object { [string]$_.capability })) {
            if ($actual -notcontains $required) { Add-Failure $failures "Project skill mapping is missing: $required" }
        }
    }
    catch { Add-Failure $failures "Project skill manifest is invalid: $($_.Exception.Message)" }

    try {
        & (Join-Path $HarnessRoot 'tools\Test-DataManifest.ps1') `
            -ManifestPath (Join-Path $repo 'data-manifest.yaml') `
            -AdapterRoot (Join-Path $HarnessRoot 'tools') `
            -ProjectAdapterRoot (Join-Path $repo '.agents\data') `
            -SchemaPath (Get-Template 'data-manifest.schema.v2.json') | Out-Null
    }
    catch { Add-Failure $failures "Project data manifest is invalid: $($_.Exception.Message)" }

    try {
        & (Join-Path $HarnessRoot 'tools\Update-SecretManifest.ps1') -Repository $repo -Check | Out-Null
    }
    catch { Add-Failure $failures "Project secret manifest is invalid: $($_.Exception.Message)" }

    if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
    return 'Project harness verification passed.'
}

function Update-Stamp {
    $files = Get-ChildItem -LiteralPath $HarnessRoot -Recurse -File -Force |
        Where-Object {
            $_.FullName -ne (Join-Path $HarnessRoot 'setup-stamp.json') -and
            $_.FullName -notmatch '[\\/]backups[\\/]'
        } |
        Sort-Object FullName |
        ForEach-Object {
            [ordered]@{
                path = $_.FullName.Substring($HarnessRoot.Length).TrimStart('\').Replace('\', '/')
                sha256 = Get-SetupStampHash $_.FullName
            }
        }
    $stamp = [ordered]@{ schemaVersion = 2; files = @($files) }
    [void](Write-TextIfChanged `
        (Join-Path $HarnessRoot 'setup-stamp.json') `
        (($stamp | ConvertTo-Json -Depth 5) + [Environment]::NewLine) `
        'Refresh deterministic harness setup stamp')
}

$result = switch ($Action) {
    'InstallGlobal' {
        Install-Global
        [pscustomobject]@{ action = $Action; harnessRoot = $HarnessRoot; homeRoot = $HomeRoot }
    }
    'EnsureProject' {
        $repo = Ensure-Project
        [pscustomobject]@{ action = $Action; repository = $repo }
    }
    'SyncProject' {
        $repo = Ensure-Project
        Sync-ProjectSkills $repo
        Write-ProjectProvenance $repo
        [void](Verify-Project)
        [pscustomobject]@{ action = $Action; repository = $repo }
    }
    'VerifyProject' {
        [pscustomobject]@{ action = $Action; result = Verify-Project }
    }
    'VerifyGlobal' {
        [pscustomobject]@{ action = $Action; result = Verify-Global }
    }
    'VerifyHumanGuide' {
        [pscustomobject]@{ action = $Action; result = Verify-HumanGuide }
    }
    'VerifyHooks' {
        [pscustomobject]@{ action = $Action; result = Verify-HookWiring }
    }
    'Stamp' {
        Update-Stamp
        [void](Verify-Global)
        [pscustomobject]@{ action = $Action; stamp = Join-Path $HarnessRoot 'setup-stamp.json' }
    }
    'All' {
        Install-Global
        if ($Repository) {
            $repo = Ensure-Project
            Sync-ProjectSkills $repo
            Write-ProjectProvenance $repo
            [void](Verify-Project)
        }
        Update-Stamp
        [void](Verify-Global)
        [pscustomobject]@{ action = $Action; repository = $Repository; stamp = Join-Path $HarnessRoot 'setup-stamp.json' }
    }
}

$result | Add-Member -NotePropertyName changed -NotePropertyValue @($changes)
$result | Add-Member -NotePropertyName preserved -NotePropertyValue @($preserved)
$result | Add-Member -NotePropertyName gates -NotePropertyValue @($gates)
$result | Add-Member -NotePropertyName dryRun -NotePropertyValue ([bool]$DryRun)
$result
