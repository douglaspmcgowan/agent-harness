[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$refresh = Join-Path $PSScriptRoot 'Refresh-Capsule.ps1'
$verify = Join-Path $PSScriptRoot 'Verify-Capsule.ps1'
$bootstrap = Join-Path $PSScriptRoot 'Bootstrap-Capsule.ps1'
$testRoot = Join-Path $env:TEMP ('capsule-global-only-test-' + [Guid]::NewGuid().ToString('N'))

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

try {
    $receivingMyDrive = Join-Path $testRoot 'Google Drive With Spaces\My Drive'
    $capsuleRoot = Join-Path $receivingMyDrive 'Capsule'
    $harnessRepository = Join-Path $testRoot 'Harness Repository'
    $harnessRemote = Join-Path $testRoot 'Harness Remote With Spaces.git'
    $sourceVault = Join-Path $testRoot 'Source Vault With Spaces'
    $targetVault = Join-Path $testRoot 'Target Vault With Spaces'
    $userRoot = Join-Path $testRoot 'Receiving User'
    $registryPath = Join-Path $testRoot 'App Data\obsidian\obsidian.json'

    Write-Utf8 -Path (Join-Path $harnessRepository '.agents\AGENTS.md') -Value "portable harness`n"
    Write-Utf8 -Path (Join-Path $harnessRepository '.agents\tools\shared.ps1') -Value "'shared'`n"
    Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $harnessRepository '.agents') -Recurse -Force
    Write-Utf8 -Path (Join-Path $harnessRepository 'projects\must-not-copy.txt') -Value "project data`n"
    Write-Utf8 -Path (Join-Path $harnessRepository 'Data\Projects\must-not-copy.txt') -Value "runtime data`n"
    Initialize-HarnessGitFixture -Repository $harnessRepository -Remote $harnessRemote

    $sourceConfig = Join-Path $sourceVault '.obsidian'
    Write-Utf8 -Path (Join-Path $sourceConfig 'app.json') -Value "{`"spellcheck`":true}`n"
    Write-Utf8 -Path (Join-Path $sourceConfig 'community-plugins.json') -Value "[`"calendar`",`"dataview`"]`n"
    Write-Utf8 -Path (Join-Path $sourceConfig 'snippets\portable.css') -Value "body { color: red; }`n"
    Write-Utf8 -Path (Join-Path $sourceConfig 'themes\Portable Theme\manifest.json') -Value "{`"name`":`"Portable Theme`"}`n"
    Write-Utf8 -Path (Join-Path $sourceConfig 'themes\Portable Theme\theme.css') -Value "body { color: blue; }`n"
    Write-Utf8 -Path (Join-Path $sourceConfig 'workspace.json') -Value "{`"privateSession`":true}`n"
    Write-Utf8 -Path (Join-Path $sourceConfig 'bookmarks.json') -Value "[]`n"
    Write-Utf8 -Path (Join-Path $sourceConfig 'sync.json') -Value "{`"token`":`"never-copy`"}`n"
    Write-Utf8 -Path (Join-Path $sourceConfig 'core-plugins-migration.json') -Value "{}"
    Write-Utf8 -Path (Join-Path $sourceConfig 'plugins\calendar\data.json') -Value "{`"private`":true}`n"
    Write-Utf8 -Path (Join-Path $sourceVault 'AI Reference\must-not-read.txt') -Value "forbidden`n"
    Write-Utf8 -Path (Join-Path $sourceVault '26_Sensitive\must-not-read.txt') -Value "forbidden`n"
    Write-Utf8 -Path $registryPath -Value (([ordered]@{
        vaults = [ordered]@{
            fixture = [ordered]@{ path = $sourceVault; open = $true }
        }
    } | ConvertTo-Json -Depth 5) + [Environment]::NewLine)
    & (Join-Path $harnessRepository '.agents\capsule\Capture-ApprovedObsidianConfig.ps1') `
        -HarnessRepository $harnessRepository `
        -ObsidianRegistryPath $registryPath | Out-Null
    Invoke-Git $harnessRepository add .agents/capsule/approved-obsidian-config
    Invoke-Git $harnessRepository commit -m 'capture fixture Obsidian configuration'
    Invoke-Git $harnessRepository push

    # A previous Capsule may contain the retired workspace/project payload.
    Write-Utf8 -Path (Join-Path $capsuleRoot 'payload\workspace\old\project.txt') -Value "stale project`n"
    Write-Utf8 -Path (Join-Path $capsuleRoot 'payload\projects\old\data.txt') -Value "stale runtime data`n"

    $result = & $refresh `
        -CapsuleRoot $capsuleRoot `
        -HarnessRepository $harnessRepository `
        -AccountMapPath (Join-Path $PSScriptRoot 'templates\accounts.template.json')

    if ($result.PayloadKind -ne 'global-harness') {
        throw "Refresh returned the wrong payload boundary: $($result.PayloadKind)"
    }
    & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null

    foreach ($required in @(
        'payload\harness\.agents\AGENTS.md',
        'payload\obsidian\config\app.json',
        'payload\obsidian\config\community-plugins.json',
        'tools\Export-ObsidianConfig.ps1',
        'tools\Restore-ObsidianConfig.ps1'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $capsuleRoot $required) -PathType Leaf)) {
            throw "Capsule omitted required global payload: $required"
        }
    }

    foreach ($forbidden in @(
        'payload\workspace',
        'payload\projects',
        'payload\harness\projects',
        'payload\harness\Data',
        'tools\Restore-AgentWorkspace.ps1',
        'payload\obsidian\config\workspace.json',
        'payload\obsidian\config\bookmarks.json',
        'payload\obsidian\config\sync.json',
        'payload\obsidian\config\core-plugins-migration.json',
        'payload\obsidian\config\plugins',
        'payload\obsidian\config\AI Reference',
        'payload\obsidian\config\26_Sensitive'
    )) {
        if (Test-Path -LiteralPath (Join-Path $capsuleRoot $forbidden)) {
            throw "Capsule retained forbidden project, runtime, or unsafe Obsidian content: $forbidden"
        }
    }

    $software = Get-Content -LiteralPath (Join-Path $capsuleRoot 'manifests\software.json') -Raw -Encoding UTF8 |
        ConvertFrom-Json
    if (@($software.packages.wingetId) -notcontains 'Obsidian.Obsidian') {
        throw 'Capsule software manifest omitted Obsidian from receiving-computer setup.'
    }

    $pointer = Get-Content -LiteralPath (Join-Path $capsuleRoot 'manifests\capsule.json') -Raw -Encoding UTF8 |
        ConvertFrom-Json
    if ($pointer.payloadKind -ne 'global-harness' -or
        $pointer.PSObject.Properties.Name -contains 'workspaceRelativePath') {
        throw 'Capsule manifest still describes a workspace snapshot.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$pointer.harness.remote) -or
        [string]::IsNullOrWhiteSpace([string]$pointer.harness.revision) -or
        [string]::IsNullOrWhiteSpace([string]$pointer.harness.releaseIdentifier) -or
        [string]::IsNullOrWhiteSpace([string]$pointer.harness.treeHash)) {
        throw 'Capsule manifest omitted the external Git provenance contract.'
    }
    Write-Utf8 -Path (Join-Path $harnessRepository 'future-change.txt') -Value "future commit`n"
    Invoke-Git $harnessRepository add future-change.txt
    Invoke-Git $harnessRepository commit -m 'future fixture commit'
    Invoke-Git $harnessRepository push
    & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null

    $obsidianTamperPath = Join-Path $capsuleRoot 'payload\obsidian\config\app.json'
    $obsidianTamperOriginal = Get-Content -LiteralPath $obsidianTamperPath -Raw -Encoding UTF8
    Write-Utf8 -Path $obsidianTamperPath -Value "{`"attacker`":true}`n"
    $obsidianPointerPath = Join-Path $capsuleRoot 'manifests\capsule.json'
    $obsidianPointer = Get-Content -LiteralPath $obsidianPointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $obsidianManifestHashOriginal = [string]$obsidianPointer.obsidian.snapshotManifestSha256
    $obsidianPointer.obsidian.snapshotManifestSha256 = ('0' * 64)
    Write-Utf8 -Path $obsidianPointerPath -Value (($obsidianPointer | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    $jointObsidianTamperRejected = $false
    try {
        & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null
    }
    catch {
        $jointObsidianTamperRejected = $_.Exception.Message -match 'Obsidian|snapshot|trusted'
    }
    if (-not $jointObsidianTamperRejected) {
        throw 'Capsule verification accepted joint Obsidian payload, integrity, and provenance replacement.'
    }
    Write-Utf8 -Path $obsidianTamperPath -Value $obsidianTamperOriginal
    $obsidianPointer.obsidian.snapshotManifestSha256 = $obsidianManifestHashOriginal
    Write-Utf8 -Path $obsidianPointerPath -Value (($obsidianPointer | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null

    $jointTamperPath = Join-Path $capsuleRoot 'payload\harness\.agents\AGENTS.md'
    $jointTamperOriginal = Get-Content -LiteralPath $jointTamperPath -Raw -Encoding UTF8
    Write-Utf8 -Path $jointTamperPath -Value "attacker replacement`n"
    $jointPointerPath = Join-Path $capsuleRoot 'manifests\capsule.json'
    $jointPointer = Get-Content -LiteralPath $jointPointerPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $jointPointer.harness.treeHash = ('0' * 40)
    Write-Utf8 -Path $jointPointerPath -Value (($jointPointer | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    $jointTamperRejected = $false
    try {
        & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null
    }
    catch {
        $jointTamperRejected = $_.Exception.Message -match 'provenance|trusted|tree|payload'
    }
    if (-not $jointTamperRejected) {
        throw 'Capsule verification accepted joint payload, integrity, and local provenance replacement.'
    }
    Write-Utf8 -Path $jointTamperPath -Value $jointTamperOriginal
    $jointPointer.harness.treeHash = [string]$pointer.harness.treeHash
    Write-Utf8 -Path $jointPointerPath -Value (($jointPointer | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null

    $projectedToolPath = Join-Path $capsuleRoot 'tools\Bootstrap-Capsule.ps1'
    $projectedToolOriginal = Get-Content -LiteralPath $projectedToolPath -Raw -Encoding UTF8
    Write-Utf8 -Path $projectedToolPath -Value "throw 'replacement bootstrap'`n"
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    $projectedToolTamperRejected = $false
    try {
        & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null
    }
    catch {
        $projectedToolTamperRejected = $_.Exception.Message -match 'entrypoint|instruction|trusted'
    }
    if (-not $projectedToolTamperRejected) {
        throw 'Capsule verification accepted a replaced bootstrap tool with refreshed local integrity.'
    }
    Write-Utf8 -Path $projectedToolPath -Value $projectedToolOriginal
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null

    $undeclaredObsidianFile = Join-Path $capsuleRoot 'payload\obsidian\config\workspace.json'
    Write-Utf8 -Path $undeclaredObsidianFile -Value "{`"unsafe`":true}`n"
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    $undeclaredRejected = $false
    try {
        & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null
    }
    catch {
        $undeclaredRejected = $true
    }
    if (-not $undeclaredRejected) {
        throw 'Capsule verification accepted undeclared unsafe Obsidian configuration.'
    }
    Remove-Item -LiteralPath $undeclaredObsidianFile -Force
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null

    $topLevelProjectData = Join-Path $capsuleRoot 'Projects\repo-data.txt'
    Write-Utf8 -Path $topLevelProjectData -Value "must stay in Git repository sync`n"
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    $topLevelProjectRejected = $false
    try {
        & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null
    }
    catch {
        $topLevelProjectRejected = $true
    }
    if (-not $topLevelProjectRejected) {
        throw 'Capsule verification accepted top-level project data.'
    }
    Remove-Item -LiteralPath (Join-Path $capsuleRoot 'Projects') -Recurse -Force

    $communityPluginsPath = Join-Path $capsuleRoot 'payload\obsidian\config\community-plugins.json'
    $communityPluginsOriginal = Get-Content -LiteralPath $communityPluginsPath -Raw -Encoding UTF8
    Write-Utf8 -Path $communityPluginsPath -Value "{`"id`":`"calendar`",`"data`":{}}`n"
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    $malformedPluginIdsRejected = $false
    try {
        & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null
    }
    catch {
        $malformedPluginIdsRejected = $true
    }
    if (-not $malformedPluginIdsRejected) {
        throw 'Capsule verification accepted non-ID community plugin configuration.'
    }
    Write-Utf8 -Path $communityPluginsPath -Value $communityPluginsOriginal
    & (Join-Path $capsuleRoot 'tools\Refresh-Integrity.ps1') -CapsuleRoot $capsuleRoot | Out-Null
    & $verify -CapsuleRoot $capsuleRoot -TrustedHarnessRepository $harnessRepository | Out-Null

    Write-Utf8 -Path (Join-Path $userRoot '.agents\old.txt') -Value "previous harness`n"
    Write-Utf8 -Path (Join-Path $targetVault '.obsidian\app.json') -Value "{`"spellcheck`":false}`n"
    New-Item -ItemType Directory -Path $receivingMyDrive -Force | Out-Null
    $environmentState = @{}
    $environmentRead = {
        param($Name)
        return $environmentState[$Name]
    }.GetNewClosure()
    $environmentWrite = {
        param($Name, $Value, $ExpandedValue)
        $environmentState[$Name] = $Value
    }.GetNewClosure()

    $bootstrapAliasExternal = Join-Path $testRoot 'Bootstrap Alias External'
    $bootstrapAlias = Join-Path $testRoot 'Bootstrap Alias'
    New-Item -ItemType Directory -Path $bootstrapAliasExternal -Force | Out-Null
    New-Item -ItemType Junction -Path $bootstrapAlias -Target $bootstrapAliasExternal | Out-Null
    $bootstrapAliasRejected = $false
    try {
        & $bootstrap `
            -CapsuleRoot $capsuleRoot `
            -TrustedHarnessRepository $harnessRepository `
            -UserRoot (Join-Path $bootstrapAlias 'Receiving User') `
            -SkipObsidianConfig `
            -SkipProjectDataEnvironment `
            -SkipPackageInstall `
            -SkipAccountLogin | Out-Null
    }
    catch {
        $bootstrapAliasRejected = $_.Exception.Message -match 'reparse'
    }
    if (-not $bootstrapAliasRejected -or
        (Test-Path -LiteralPath (Join-Path $bootstrapAliasExternal 'Receiving User\.agents'))) {
        throw 'Bootstrap wrote through a reparse-point target ancestor.'
    }

    $bootstrapLockTarget = [System.IO.Path]::GetFullPath((Join-Path $userRoot '.agents')).TrimEnd('\').ToLowerInvariant()
    $bootstrapLockSha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bootstrapLockHash = ([BitConverter]::ToString(
            $bootstrapLockSha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($bootstrapLockTarget))
        )).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $bootstrapLockSha.Dispose()
    }
    $bootstrapLockDirectory = Join-Path ([System.IO.Path]::GetTempPath()) 'AgentHarness-BootstrapLocks'
    New-Item -ItemType Directory -Path $bootstrapLockDirectory -Force | Out-Null
    $heldBootstrapLock = [System.IO.File]::Open(
        (Join-Path $bootstrapLockDirectory ($bootstrapLockHash + '.lock')),
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
    $overlappingBootstrapRejected = $false
    try {
        try {
            & $bootstrap `
                -CapsuleRoot $capsuleRoot `
                -TrustedHarnessRepository $harnessRepository `
                -UserRoot $userRoot `
                -ObsidianVaultRoot $targetVault `
                -ProjectDataEnvironmentReadOperation $environmentRead `
                -ProjectDataEnvironmentWriteOperation $environmentWrite `
                -SkipPackageInstall `
                -SkipAccountLogin | Out-Null
        }
        catch {
            $overlappingBootstrapRejected = $true
        }
    }
    finally {
        $heldBootstrapLock.Dispose()
    }
    if (-not $overlappingBootstrapRejected) {
        throw 'Bootstrap accepted an overlapping install for the same shared harness target.'
    }

    $bootstrapResult = & $bootstrap `
        -CapsuleRoot $capsuleRoot `
        -TrustedHarnessRepository $harnessRepository `
        -UserRoot $userRoot `
        -ObsidianVaultRoot $targetVault `
        -ProjectDataEnvironmentReadOperation $environmentRead `
        -ProjectDataEnvironmentWriteOperation $environmentWrite `
        -SkipPackageInstall `
        -SkipAccountLogin

    if (-not (Test-Path -LiteralPath (Join-Path $userRoot '.agents\AGENTS.md') -PathType Leaf)) {
        throw 'Bootstrap did not install the shared global harness.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $bootstrapResult.HarnessBackupRoot 'old.txt') -PathType Leaf)) {
        throw 'Bootstrap did not back up the receiving shared harness before replacement.'
    }
    if ($environmentState.PROJECT_DATA_SYNC_ROOT -ne (Join-Path $receivingMyDrive 'Project Data') -or
        $environmentState.PROJECT_DATA_ROOT -ne '%USERPROFILE%\Data\Projects' -or
        -not (Test-Path -LiteralPath (Join-Path $receivingMyDrive 'Project Data') -PathType Container)) {
        throw 'Bootstrap did not configure the receiving project-data environment.'
    }
    $expectedPortableApp = (Get-Content -LiteralPath (Join-Path $sourceConfig 'app.json') -Raw).Trim()
    if ((Get-Content -LiteralPath (Join-Path $targetVault '.obsidian\app.json') -Raw).Trim() -ne $expectedPortableApp) {
        throw 'Bootstrap did not restore the portable Obsidian configuration.'
    }
    $backedUpApp = @(Get-ChildItem -LiteralPath $bootstrapResult.ObsidianBackupRoot -File -Recurse -Filter app.json)
    if ($backedUpApp.Count -ne 1 -or (Get-Content -LiteralPath $backedUpApp[0].FullName -Raw) -notmatch '"spellcheck":false') {
        throw 'Bootstrap did not preserve the receiving vault configuration before replacement.'
    }

    $approvedMetadataFiles = @(
        'credential-command-allowlist.json',
        'credential-command-policy.json',
        'bws-command-allowlist.json'
    )
    $secretLikeFiles = @(Get-ChildItem -LiteralPath $capsuleRoot -File -Recurse -Force | Where-Object {
        $_.Name -notin $approvedMetadataFiles -and
        $_.Name -match '^(?i)\.env($|\.)|credential|token|password|passcode|recovery.?key|cookies?$'
    })
    if ($secretLikeFiles.Count) {
        throw 'Capsule contains a forbidden secret-like filename.'
    }

    $missingSnapshotHarness = Join-Path $testRoot 'Harness Missing Approved Snapshot'
    $missingSnapshotRemote = Join-Path $testRoot 'Harness Missing Approved Snapshot Remote.git'
    Write-Utf8 -Path (Join-Path $missingSnapshotHarness '.agents\AGENTS.md') -Value "fixture`n"
    Copy-Item -LiteralPath $PSScriptRoot -Destination (Join-Path $missingSnapshotHarness '.agents') -Recurse -Force
    Remove-Item `
        -LiteralPath (Join-Path $missingSnapshotHarness '.agents\capsule\approved-obsidian-config') `
        -Recurse `
        -Force
    Initialize-HarnessGitFixture -Repository $missingSnapshotHarness -Remote $missingSnapshotRemote
    $missingSnapshotRejected = $false
    try {
        & $refresh `
            -CapsuleRoot (Join-Path $testRoot 'Missing Snapshot Capsule') `
            -HarnessRepository $missingSnapshotHarness `
            -AccountMapPath (Join-Path $PSScriptRoot 'templates\accounts.template.json') | Out-Null
    }
    catch {
        $missingSnapshotRejected = $_.Exception.Message -match 'approved Obsidian'
    }
    if (-not $missingSnapshotRejected) {
        throw 'Capsule refresh accepted a harness revision without a committed approved Obsidian snapshot.'
    }

    $missingGitleaksRejected = $false
    $missingGitleaksMessage = $null
    try {
        & $refresh `
            -CapsuleRoot (Join-Path $testRoot 'Missing Gitleaks Capsule') `
            -HarnessRepository $harnessRepository `
            -AccountMapPath (Join-Path $PSScriptRoot 'templates\accounts.template.json') `
            -GitleaksPath (Join-Path $testRoot 'missing\gitleaks.exe') | Out-Null
    }
    catch {
        $missingGitleaksMessage = $_.Exception.Message
        $missingGitleaksRejected = $_.Exception.Message -match 'Gitleaks is required'
    }
    if (-not $missingGitleaksRejected) {
        throw "Capsule refresh did not fail closed when Gitleaks was unavailable: $missingGitleaksMessage"
    }

    [pscustomobject]@{
        Result = 'PASS'
        PayloadKind = $result.PayloadKind
        GlobalHarnessOnly = $true
        ObsidianPackageIncluded = $true
        ObsidianConfigPortable = $true
        RestoreBackupVerified = $true
        ProjectDataEnvironmentConfigured = $true
        UndeclaredObsidianFileRejected = $true
        TopLevelProjectDataRejected = $true
        MalformedPluginIdsRejected = $true
        JointPayloadMetadataTamperRejected = $true
        ProjectedToolTamperRejected = $true
        JointObsidianTamperRejected = $true
        RecordedRevisionVerifiedAfterNewerCommit = $true
        OverlappingBootstrapRejected = $true
        BootstrapAncestorJunctionRejected = $true
        PathWithSpacesVerified = $true
        MissingCommittedSnapshotRejected = $true
        MissingGitleaksRejected = $true
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
