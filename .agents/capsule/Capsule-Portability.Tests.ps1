[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$refresh = Join-Path $PSScriptRoot 'Refresh-Capsule.ps1'
$testRoot = Join-Path $env:TEMP ('capsule-portability-test-' + [Guid]::NewGuid().ToString('N'))

function Write-Utf8 {
    param([string]$Path, [string]$Value)
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [System.IO.File]::WriteAllText($Path, $Value, [System.Text.UTF8Encoding]::new($false))
}

function Invoke-Git {
    param([string]$Repository, [Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git -C $Repository @Arguments 2>&1)
    }
    finally {
        $ErrorActionPreference = $previousPreference
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Git failed in ${Repository}: $($output -join [Environment]::NewLine)"
    }
}

function Initialize-HarnessGitFixture {
    param([string]$Repository, [string]$Remote)

    & git init --bare $Remote | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Fixture bare remote initialization failed.' }
    & git init $Repository | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Fixture harness initialization failed.' }
    Write-Utf8 `
        -Path (Join-Path $Repository '.gitattributes') `
        -Value ".agents/capsule/approved-obsidian-config/** -text`n"
    Invoke-Git $Repository config user.name 'Capsule Test'
    Invoke-Git $Repository config user.email 'capsule-test@example.invalid'
    Invoke-Git $Repository remote add origin $Remote
    Invoke-Git $Repository add .agents .gitattributes
    Invoke-Git $Repository commit -m 'fixture harness'
    Invoke-Git $Repository branch -M master
    Invoke-Git $Repository push -u origin master
}

function Assert-PackagedSkillPointersResolve {
    param([string]$AgentsRoot)

    $agentsRoot = [System.IO.Path]::GetFullPath($AgentsRoot)
    $skillsRoot = Join-Path $agentsRoot 'skills'
    $agentsPrefix = [System.IO.Path]::GetFullPath($agentsRoot).TrimEnd('\') + '\'
    $failures = [System.Collections.Generic.List[string]]::new()

    foreach ($skill in @(Get-ChildItem -LiteralPath $skillsRoot -Recurse -File -Filter 'SKILL.md')) {
        $content = Get-Content -LiteralPath $skill.FullName -Raw -Encoding UTF8
        foreach ($match in [regex]::Matches($content, '(?i)(?<path>\.\.[\\/][^`)\s]*SKILL\.md)')) {
            $target = [System.IO.Path]::GetFullPath(
                (Join-Path $skill.DirectoryName $match.Groups['path'].Value)
            )
            if (-not $target.StartsWith($agentsPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                $failures.Add("Packaged compatibility pointer escapes the shared .agents tree: $($skill.FullName)")
                continue
            }
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                $relativeSkill = $skill.FullName.Substring($agentsRoot.Length).TrimStart('\')
                $relativeTarget = $target.Substring($agentsRoot.Length).TrimStart('\')
                $failures.Add("Packaged compatibility pointer is unresolved: $relativeSkill -> $relativeTarget")
            }
        }
    }
    if ($failures.Count) {
        throw ($failures -join [Environment]::NewLine)
    }
}

try {
    $capsule = Join-Path $testRoot 'Drive Folder With Spaces\Capsule'
    $harness = Join-Path $testRoot 'Harness Repository With Spaces'
    $harnessRemote = Join-Path $testRoot 'Harness Remote With Spaces.git'
    $vault = Join-Path $testRoot 'Active Vault With Spaces'
    $registry = Join-Path $testRoot 'Roaming\obsidian\obsidian.json'
    $accountMap = Join-Path $PSScriptRoot 'templates\accounts.template.json'
    $canonicalHarnessRepository = Join-Path $testRoot 'Canonical Harness Repository With Spaces'
    $canonicalHarnessRemote = Join-Path $testRoot 'Canonical Harness Remote With Spaces.git'
    $dependencyCapsule = Join-Path $testRoot 'Packaged Skill Dependencies'

    New-Item -ItemType Directory -Path $canonicalHarnessRepository -Force | Out-Null
    Copy-Item -LiteralPath (Split-Path -Parent $PSScriptRoot) -Destination $canonicalHarnessRepository -Recurse -Force
    Initialize-HarnessGitFixture -Repository $canonicalHarnessRepository -Remote $canonicalHarnessRemote
    & $refresh `
        -CapsuleRoot $dependencyCapsule `
        -HarnessRepository $canonicalHarnessRepository `
        -AccountMapPath $accountMap `
        -SkipObsidianConfig | Out-Null
    Assert-PackagedSkillPointersResolve `
        -AgentsRoot (Join-Path $dependencyCapsule 'payload\harness\.agents')

    Write-Utf8 -Path (Join-Path $harness '.agents\AGENTS.md') -Value "version one`n"
    Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $harness '.agents') -Recurse -Force
    Initialize-HarnessGitFixture -Repository $harness -Remote $harnessRemote
    Write-Utf8 -Path (Join-Path $vault '.obsidian\app.json') -Value "{`"version`":1}`n"
    Write-Utf8 -Path $registry -Value (([ordered]@{
        vaults = [ordered]@{
            active = [ordered]@{ path = $vault; open = $true }
        }
    } | ConvertTo-Json -Depth 5) + [Environment]::NewLine)
    & (Join-Path $harness '.agents\capsule\Capture-ApprovedObsidianConfig.ps1') `
        -HarnessRepository $harness `
        -ObsidianRegistryPath $registry | Out-Null
    Invoke-Git $harness add .agents/capsule/approved-obsidian-config
    Invoke-Git $harness commit -m 'capture fixture Obsidian configuration'
    Invoke-Git $harness push

    & $refresh `
        -CapsuleRoot $capsule `
        -HarnessRepository $harness `
        -AccountMapPath $accountMap | Out-Null

    foreach ($entrypoint in @(
        'Harness.ps1',
        'tools\Refresh-Capsule.ps1',
        'tools\Verify-Capsule.ps1',
        'tools\Bootstrap-Capsule.ps1',
        'tools\Export-ObsidianConfig.ps1',
        'tools\Restore-ObsidianConfig.ps1'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $capsule $entrypoint) -PathType Leaf)) {
            throw "Initial Capsule omitted a portable entrypoint: $entrypoint"
        }
    }

    Write-Utf8 -Path (Join-Path $harness '.agents\AGENTS.md') -Value "version two`n"
    Invoke-Git $harness add .agents
    Invoke-Git $harness commit -m 'fixture harness version two'
    Invoke-Git $harness push
    Write-Utf8 `
        -Path (Join-Path $harness '.agents\capsule\approved-obsidian-config\files\app.json') `
        -Value "{`"uncommitted`":true}`n"
    $packagedRefresh = Join-Path $capsule 'tools\Refresh-Capsule.ps1'
    & $packagedRefresh `
        -CapsuleRoot $capsule `
        -HarnessRepository $harness `
        -AccountMapPath (Join-Path $capsule 'manifests\accounts.json') | Out-Null

    $harnessContent = Get-Content -LiteralPath (Join-Path $capsule 'payload\harness\.agents\AGENTS.md') -Raw
    $obsidianContent = Get-Content -LiteralPath (Join-Path $capsule 'payload\obsidian\config\app.json') -Raw
    if ($harnessContent.Trim() -ne 'version two') {
        throw 'Packaged refresh did not update the shared harness payload.'
    }
    if ($obsidianContent.Trim() -ne '{"version":1}') {
        throw 'Packaged refresh did not preserve the committed approved Obsidian configuration.'
    }
    if (Test-Path -LiteralPath (Join-Path $capsule 'payload\workspace')) {
        throw 'Packaged refresh recreated a retired workspace payload.'
    }

    $normalizedLockRoot = [System.IO.Path]::GetFullPath($capsule).TrimEnd('\').ToLowerInvariant()
    $lockSha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $lockHash = ([BitConverter]::ToString(
            $lockSha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($normalizedLockRoot))
        )).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $lockSha.Dispose()
    }
    $lockDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'AgentHarness-CapsuleLocks'
    New-Item -ItemType Directory -Path $lockDirectory -Force | Out-Null
    $heldLock = [System.IO.File]::Open(
        (Join-Path $lockDirectory ($lockHash + '.lock')),
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
    $overlapRejected = $false
    try {
        try {
            & (Join-Path $capsule 'tools\Refresh-Capsule.ps1') `
                -CapsuleRoot $capsule `
                -HarnessRepository $harness `
                -AccountMapPath (Join-Path $capsule 'manifests\accounts.json') | Out-Null
        }
        catch {
            $overlapRejected = $true
        }
    }
    finally {
        $heldLock.Dispose()
    }
    if (-not $overlapRejected) {
        throw 'Capsule refresh accepted an overlapping refresh for the same target.'
    }

    $refreshAliasExternal = Join-Path $testRoot 'Refresh Alias External'
    $refreshAlias = Join-Path $testRoot 'Refresh Alias'
    New-Item -ItemType Directory -Path $refreshAliasExternal -Force | Out-Null
    New-Item -ItemType Junction -Path $refreshAlias -Target $refreshAliasExternal | Out-Null
    $refreshAliasRejected = $false
    try {
        & $refresh `
            -CapsuleRoot (Join-Path $refreshAlias 'Capsule') `
            -HarnessRepository $harness `
            -AccountMapPath $accountMap `
            -SkipObsidianConfig | Out-Null
    }
    catch {
        $refreshAliasRejected = $_.Exception.Message -match 'reparse'
    }
    if (-not $refreshAliasRejected -or
        (Test-Path -LiteralPath (Join-Path $refreshAliasExternal 'Capsule'))) {
        throw 'Capsule refresh wrote through a reparse-point target ancestor.'
    }

    $external = Join-Path $testRoot 'External Data'
    Write-Utf8 -Path (Join-Path $external 'must-survive.txt') -Value "outside Capsule`n"
    $retiredWorkspace = Join-Path $capsule 'payload\workspace'
    New-Item -ItemType Directory -Path $retiredWorkspace -Force | Out-Null
    New-Item -ItemType Junction -Path (Join-Path $retiredWorkspace 'external-link') -Target $external | Out-Null
    & (Join-Path $capsule 'tools\Refresh-Capsule.ps1') `
        -CapsuleRoot $capsule `
        -HarnessRepository $harness `
        -AccountMapPath (Join-Path $capsule 'manifests\accounts.json') | Out-Null
    if (-not (Test-Path -LiteralPath (Join-Path $external 'must-survive.txt') -PathType Leaf)) {
        throw 'Capsule refresh followed a retired workspace junction and deleted external data.'
    }

    $verifyResult = & (Join-Path $capsule 'Harness.ps1') `
        -Action verify `
        -HarnessRepository $harness
    if ($verifyResult.Result -ne 'PASS' -or $verifyResult.PayloadKind -ne 'global-harness') {
        throw 'The self-refreshed Capsule did not verify through its portable root entrypoint.'
    }

    [pscustomobject]@{
        Result = 'PASS'
        PackagedRefresh = $true
        PathWithSpaces = $true
        GlobalHarnessOnly = $true
        CommittedObsidianConfig = $true
        UncommittedSnapshotIgnored = $true
        OverlappingRefreshRejected = $true
        RefreshAncestorJunctionRejected = $true
        ExternalJunctionPreserved = $true
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = (Resolve-Path -LiteralPath $testRoot).Path
        if ($resolved.StartsWith([System.IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
