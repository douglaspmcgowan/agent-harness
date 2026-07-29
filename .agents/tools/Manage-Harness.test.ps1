$ErrorActionPreference = 'Stop'

$sourceHarness = Split-Path $PSScriptRoot -Parent
$insideTaskHooks = Join-Path $sourceHarness 'task-hooks'
$siblingTaskHooks = Join-Path (Split-Path $sourceHarness -Parent) 'task-hooks'
$sourceTaskHooks = if (Test-Path -LiteralPath (Join-Path $insideTaskHooks 'hooks') -PathType Container) {
    $insideTaskHooks
}
else {
    $siblingTaskHooks
}
$root = Join-Path $env:TEMP ('manage-harness-test-' + [Guid]::NewGuid().ToString('N'))
$harness = Join-Path $root 'global-contract'
$taskHooks = Join-Path $root 'task-hooks'
$testHome = Join-Path $root 'home'
$repo = Join-Path $root 'project'
$freshHome = Join-Path $root 'fresh-home'
$freshRepo = Join-Path $root 'fresh-project'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-GitWithHome {
    param(
        [Parameter(Mandatory = $true)][string]$ReceivingHome,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )
    $priorHome = [Environment]::GetEnvironmentVariable('HOME', 'Process')
    $priorUserProfile = [Environment]::GetEnvironmentVariable('USERPROFILE', 'Process')
    try {
        $env:HOME = $ReceivingHome
        $env:USERPROFILE = $ReceivingHome
        & git.exe @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "git failed for receiving home: $ReceivingHome"
        }
    }
    finally {
        [Environment]::SetEnvironmentVariable('HOME', $priorHome, 'Process')
        [Environment]::SetEnvironmentVariable('USERPROFILE', $priorUserProfile, 'Process')
    }
}

try {
    Copy-Item -LiteralPath $sourceHarness -Destination $harness -Recurse
    Copy-Item -LiteralPath $sourceTaskHooks -Destination $taskHooks -Recurse
    New-Item -ItemType Directory -Path $testHome, $repo -Force | Out-Null

    $globalContract = [System.IO.File]::ReadAllText((Join-Path $harness 'AGENTS.md'))
    $sourceProvenance = [System.IO.File]::ReadAllText((Join-Path $harness 'harness-provenance.json')) | ConvertFrom-Json
    Assert-True ($sourceProvenance.authority -eq 'agent-harness/portable-project-contract/v3') 'Canonical project provenance embeds a machine-specific authority.'
    foreach ($route in @(
        'source-command-brainstorming',
        'source-command-systematic-debugging',
        'source-command-test-driven-development',
        'source-command-requesting-code-review',
        'source-command-verification-before-completion',
        'impeccable',
        'parallelize'
    )) {
        Assert-True $globalContract.Contains($route) "Global contract is missing default skill route: $route"
    }
    $baseline = [System.IO.File]::ReadAllText((Join-Path $harness 'manifests\baseline-skills.json')) | ConvertFrom-Json
    $expectedBindings = @{
        'engineering-workflow' = @(
            'source-command-brainstorming',
            'source-command-systematic-debugging',
            'source-command-test-driven-development',
            'source-command-requesting-code-review',
            'source-command-verification-before-completion'
        )
        'interface-workflow' = @('impeccable')
        'parallel-work' = @('parallelize')
    }
    foreach ($capability in $expectedBindings.Keys) {
        $binding = @($baseline.bindings | Where-Object { $_.capability -eq $capability })
        Assert-True ($binding.Count -eq 1) "Baseline skill binding is missing or duplicated: $capability"
        Assert-True (
            (@($binding[0].canonical) -join ',') -ceq ($expectedBindings[$capability] -join ',')
        ) "Baseline canonical skill order drifted: $capability"
    }

    $manager = Join-Path $harness 'tools\Manage-Harness.ps1'
    $guideGenerator = Join-Path $harness 'tools\Convert-HumanGuide.ps1'
    & $guideGenerator `
        -MarkdownPath (Join-Path $harness 'human-readable\README.md') `
        -OutputPath (Join-Path $harness 'human-readable\README.html') | Out-Null
    & $manager -Action Stamp -HarnessRoot $harness -HomeRoot (Join-Path $root 'stamp-home') | Out-Null
    $dry = & $manager -Action InstallGlobal -HarnessRoot $harness -HomeRoot $testHome -DryRun 6>$null
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $testHome '.agents'))) 'Dry-run wrote the global harness.'
    Assert-True $dry.dryRun 'Dry-run was not reported.'

    New-Item -ItemType Directory -Path (Join-Path $testHome '.claude'), (Join-Path $testHome '.codex'), (Join-Path $testHome '.cursor'), (Join-Path $testHome '.agents') -Force | Out-Null
    $priorGitConfig = "[user]`r`n`tname = Preserved User`r`n[init]`r`n`ttemplateDir = C:/legacy-template`r`n"
    [System.IO.File]::WriteAllText((Join-Path $testHome '.gitconfig'), $priorGitConfig, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $testHome '.claude\CLAUDE.md'), "# Existing Claude rules`r`n`r`nKeep this line.`r`n")
    [System.IO.File]::WriteAllText((Join-Path $testHome '.codex\AGENTS.md'), "# User-edited Codex rules`r`n")
    New-Item -ItemType Directory -Path (Join-Path $testHome '.cursor\rules') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $testHome '.cursor\rules\00-cross-agent-contract.mdc'), "stale cursor loader`r`n")
    foreach ($legacy in @('HARNESS-MAP.md', 'CROSS-AGENT-CONTRACT.md', 'FEEDBACK-ROUTER.md')) {
        [System.IO.File]::WriteAllText((Join-Path $testHome ".agents\$legacy"), "# legacy`r`n")
    }
    $retiredBitwardenPaths = @(
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
    foreach ($relativePath in $retiredBitwardenPaths) {
        $retiredPath = Join-Path $testHome ".agents\$relativePath"
        New-Item -ItemType Directory -Path (Split-Path -Parent $retiredPath) -Force | Out-Null
        [System.IO.File]::WriteAllText($retiredPath, "retired`r`n")
    }
    New-Item -ItemType Directory -Path (Join-Path $testHome '.agents\human-readable') -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $testHome '.agents\human-readable\08-OLD-TOPIC.md'), "# old topic`r`n")
    [System.IO.File]::WriteAllText((Join-Path $testHome '.agents\human-readable\setup-stamp.json'), "{}")
    $receivingTemplateHooks = Join-Path $testHome '.agents\git-template\hooks'
    New-Item -ItemType Directory -Path $receivingTemplateHooks -Force | Out-Null
    [System.IO.File]::WriteAllText(
        (Join-Path $receivingTemplateHooks 'pre-commit'),
        "#!/bin/sh`nexit 0`n",
        [System.Text.UTF8Encoding]::new($false)
    )

    $installed = & $manager -Action InstallGlobal -HarnessRoot $harness -HomeRoot $testHome -ActivateHooks
    $claude = [System.IO.File]::ReadAllText((Join-Path $testHome '.claude\CLAUDE.md'))
    Assert-True $claude.Contains('agent-harness:claude-loader:v1:start') 'Claude loader marker was not installed.'
    Assert-True $claude.Contains('Keep this line.') 'Existing Claude global content was lost.'
    Assert-True (([System.IO.File]::ReadAllText((Join-Path $testHome '.codex\AGENTS.md'))) -eq "# User-edited Codex rules`r`n") 'Live Codex AGENTS.md was changed.'
    Assert-True (Test-Path -LiteralPath (Join-Path $testHome '.codex\AGENTS.proposed.md')) 'Codex proposal was not installed.'
    Assert-True (Test-Path -LiteralPath (Join-Path $testHome '.cursor\user-rules.txt')) 'Cursor user-rules projection was not installed.'
    $cursorGlobalRule = Join-Path $testHome '.cursor\rules\00-agent-harness.mdc'
    Assert-True (Test-Path -LiteralPath $cursorGlobalRule) 'Cursor global harness rule was not installed.'
    Assert-True (
        ([System.IO.File]::ReadAllText($cursorGlobalRule)).Contains((Join-Path $testHome '.agents\AGENTS.md'))
    ) 'Cursor global harness rule did not render the receiving profile.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $testHome '.cursor\rules\00-cross-agent-contract.mdc'))) 'Superseded Cursor global rule remained active.'
    Assert-True (Test-Path -LiteralPath (Join-Path $testHome '.agents\adapters\claude\CLAUDE.md')) 'Canonical adapters were not installed.'
    Assert-True (Test-Path -LiteralPath (Join-Path $testHome '.agents\human-readable\README.md')) 'Human guide was not installed.'
    $backupFiles = @(Get-ChildItem -LiteralPath (Join-Path $testHome '.agents\backups') -Recurse -File)
    Assert-True ($backupFiles.Count -gt 0) 'Changed receiving-profile files were not backed up under the receiving .agents root.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $harness 'backups'))) 'Receiving-profile backups polluted the canonical source harness.'
    foreach ($entrypoint in @('security-dispatch.js', 'task-state-dispatch.js', 'continue-dispatch.js')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $testHome ".agents\hooks\$entrypoint")) "Hook entrypoint was not installed: $entrypoint"
    }
    Assert-True (Test-Path -LiteralPath (Join-Path $testHome '.agents\tools\Migrate-TaskState.ps1')) 'TASK migration tool was not installed.'
    $sourceTemplateHook = Join-Path $harness 'git-template\hooks\pre-commit'
    $installedTemplateHook = Join-Path $testHome '.agents\git-template\hooks\pre-commit'
    Assert-True (
        (Get-FileHash -LiteralPath $sourceTemplateHook -Algorithm SHA256).Hash -eq
        (Get-FileHash -LiteralPath $installedTemplateHook -Algorithm SHA256).Hash
    ) 'Global installation did not replace the stale Git init-template hook with the canonical fail-closed hook.'
    $configuredTemplate = (Invoke-GitWithHome $testHome config --global --get init.templateDir | Select-Object -Last 1).Trim()
    Assert-True ($configuredTemplate -eq (Join-Path $testHome '.agents\git-template')) 'Global installation did not configure the receiving user Git init template.'
    $preservedGitName = (Invoke-GitWithHome $testHome config --global --get user.name | Select-Object -Last 1).Trim()
    Assert-True ($preservedGitName -eq 'Preserved User') 'Global installation did not preserve unrelated receiving-user Git configuration.'
    $gitConfigBackups = @(Get-ChildItem -LiteralPath (Join-Path $testHome '.agents\backups') -Recurse -File -Filter '.gitconfig')
    Assert-True ($gitConfigBackups.Count -eq 1) 'Changed receiving-user Git configuration was not backed up exactly once.'
    Assert-True ([System.IO.File]::ReadAllText($gitConfigBackups[0].FullName) -ceq $priorGitConfig) 'Receiving-user Git configuration backup did not preserve the prior bytes.'
    Assert-True ($installed.gates.Count -eq 0) 'Global installation left an unexpected manual product gate.'
    foreach ($legacy in @('HARNESS-MAP.md', 'CROSS-AGENT-CONTRACT.md', 'FEEDBACK-ROUTER.md')) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $testHome ".agents\$legacy"))) "Legacy global file remained active: $legacy"
        Assert-True (Test-Path -LiteralPath (Join-Path $testHome ".agents\archive\legacy-contracts\$legacy")) "Legacy global file was not archived: $legacy"
    }
    foreach ($relativePath in $retiredBitwardenPaths) {
        $retiredPath = Join-Path $testHome ".agents\$relativePath"
        Assert-True (-not (Test-Path -LiteralPath $retiredPath)) "Retired Bitwarden artifact remained active: $relativePath"
        $retiredBackups = @(Get-ChildItem -LiteralPath (Join-Path $testHome '.agents\backups') -Recurse -File |
            Where-Object { $_.FullName.EndsWith($relativePath, [StringComparison]::OrdinalIgnoreCase) })
        Assert-True ($retiredBackups.Count -eq 1) "Retired Bitwarden artifact was not backed up exactly once: $relativePath"
    }
    foreach ($legacyHuman in @('08-OLD-TOPIC.md', 'setup-stamp.json')) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $testHome ".agents\human-readable\$legacyHuman"))) "Legacy human-readable file remained active: $legacyHuman"
        $archived = @(Get-ChildItem -LiteralPath (Join-Path $testHome '.agents\human-readable\archive\pre-consolidation') -Recurse -File -Filter $legacyHuman)
        Assert-True ($archived.Count -eq 1) "Legacy human-readable file was not archived exactly once: $legacyHuman"
    }
    $thin = [System.IO.File]::ReadAllText((Join-Path $testHome '.claude\skills\correct\SKILL.md'))
    Assert-True $thin.Contains((Join-Path $testHome '.agents\skills\correct\SKILL.md')) 'Thin skill projection used a hard-coded home path.'
    foreach ($projectionPath in @(
        (Join-Path $testHome '.claude\CLAUDE.md'),
        (Join-Path $testHome '.codex\AGENTS.proposed.md'),
        (Join-Path $testHome '.cursor\user-rules.txt')
    )) {
        $projectionContent = [System.IO.File]::ReadAllText($projectionPath)
        $containsReceivingHome = $projectionContent.Contains($testHome) -or $projectionContent.Contains($testHome.Replace('\', '/'))
        Assert-True $containsReceivingHome "Projection did not render the receiving home: $projectionPath"
        Assert-True (-not $projectionContent.Contains('{{HOME_')) "Projection retained a home token: $projectionPath"
        $retainedSourceProfile = $projectionContent.Contains('C:\Users\dougl\.agents') -or
            $projectionContent.Contains('C:\Users\dougl\.codex') -or
            $projectionContent.Contains('C:/Users/dougl/.agents') -or
            $projectionContent.Contains('C:/Users/dougl/.codex')
        Assert-True (-not $retainedSourceProfile) "Projection retained the source profile: $projectionPath"
    }
    $liveManager = Join-Path $testHome '.agents\tools\Manage-Harness.ps1'
    $liveGlobal = & $liveManager -Action VerifyGlobal -HarnessRoot (Join-Path $testHome '.agents') -HomeRoot $testHome
    Assert-True ($liveGlobal.result -eq 'Global harness verification passed.') 'Installed global package verification did not pass.'
    $installedHtml = Join-Path $testHome '.agents\human-readable\README.html'
    $installedGuideHash = (Get-FileHash -LiteralPath (Join-Path $testHome '.agents\human-readable\README.md') -Algorithm SHA256).Hash.ToLowerInvariant()
    $originalInstalledHtml = [System.IO.File]::ReadAllText($installedHtml)
    [System.IO.File]::WriteAllText(
        $installedHtml,
        $originalInstalledHtml.Replace($installedGuideHash, ('0' * 64)),
        [System.Text.UTF8Encoding]::new($false)
    )
    $staleMarkerRejected = $false
    try {
        & $liveManager -Action VerifyGlobal -HarnessRoot (Join-Path $testHome '.agents') -HomeRoot $testHome | Out-Null
    }
    catch {
        $staleMarkerRejected = $_.Exception.Message -match 'deterministic render'
    }
    Assert-True $staleMarkerRejected 'Installed verifier accepted a stale Markdown source marker.'
    [System.IO.File]::WriteAllText($installedHtml, $originalInstalledHtml, [System.Text.UTF8Encoding]::new($false))

    [System.IO.File]::WriteAllText(
        $installedHtml,
        "<html data-source-sha256=`"$installedGuideHash`" data-generator=`"Convert-HumanGuide.ps1:v1`"><body>Substituted body</body></html>`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $htmlTamperRejected = $false
    try {
        & $liveManager -Action VerifyGlobal -HarnessRoot (Join-Path $testHome '.agents') -HomeRoot $testHome | Out-Null
    }
    catch {
        $htmlTamperRejected = $_.Exception.Message -match 'deterministic render'
    }
    Assert-True $htmlTamperRejected 'Installed verifier accepted substituted HTML carrying the expected Markdown hash marker.'
    [System.IO.File]::WriteAllText($installedHtml, $originalInstalledHtml, [System.Text.UTF8Encoding]::new($false))
    $liveHooks = & $liveManager -Action VerifyHooks -HarnessRoot (Join-Path $testHome '.agents') -HomeRoot $testHome
    Assert-True ($liveHooks.result -eq 'Active product hook wiring uses exactly the three consolidated entrypoints.') 'Installed product hook wiring did not pass.'

    $installedAgain = & $manager -Action InstallGlobal -HarnessRoot $harness -HomeRoot $testHome -ActivateHooks
    Assert-True ($installedAgain.changed.Count -eq 0) 'Second global install was not idempotent.'

    Invoke-GitWithHome $testHome -C $repo init --quiet
    Assert-True (
        (Get-FileHash -LiteralPath $installedTemplateHook -Algorithm SHA256).Hash -eq
        (Get-FileHash -LiteralPath (Join-Path $repo '.git\hooks\pre-commit') -Algorithm SHA256).Hash
    ) 'Fresh repository initialization did not consume the receiving user global Git init template.'

    New-Item -ItemType Directory -Path $freshHome, $freshRepo -Force | Out-Null
    & $manager -Action InstallGlobal -HarnessRoot $harness -HomeRoot $freshHome | Out-Null
    Invoke-GitWithHome $freshHome -C $freshRepo init --quiet
    Assert-True (
        (Get-FileHash -LiteralPath (Join-Path $freshHome '.agents\git-template\hooks\pre-commit') -Algorithm SHA256).Hash -eq
        (Get-FileHash -LiteralPath (Join-Path $freshRepo '.git\hooks\pre-commit') -Algorithm SHA256).Hash
    ) 'A fresh receiving profile required an injected init.templateDir override.'
    [System.IO.File]::WriteAllText((Join-Path $repo 'AGENTS.md'), "# Existing project rules`r`n`r`nKeep project-specific content.`r`n")
    $ensured = & $manager -Action EnsureProject -HarnessRoot $harness -HomeRoot $testHome -Repository $repo -ProjectName 'fixture-project' -IncludeProduct
    Assert-True (Test-Path -LiteralPath (Join-Path $repo 'TASK.md')) 'TASK.md was not installed.'
    $freshTask = [System.IO.File]::ReadAllText((Join-Path $repo 'TASK.md'))
    Assert-True (-not [regex]::IsMatch($freshTask, '(?m)^\s*-\s*\[(?: |~)\]\s+')) 'Fresh TASK.md contains actionable placeholder work.'
    Assert-True (Test-Path -LiteralPath (Join-Path $repo 'PRODUCT.md')) 'Optional PRODUCT.md was not installed.'
    Assert-True (Test-Path -LiteralPath (Join-Path $repo '.agents\skill-pathways.json')) 'Pathway definition was not installed.'
    $projectAgents = [System.IO.File]::ReadAllText((Join-Path $repo 'AGENTS.md'))
    Assert-True $projectAgents.Contains('agent-harness:portable:v3:start') 'Portable project block was not installed.'
    Assert-True $projectAgents.Contains('Keep project-specific content.') 'Project-specific AGENTS.md content was lost.'
    $verified = & $manager -Action VerifyProject -HarnessRoot $harness -HomeRoot $testHome -Repository $repo
    Assert-True ($verified.result -eq 'Project harness verification passed.') 'Project verification did not pass.'
    $projectProvenancePath = Join-Path $repo '.agents\harness-provenance.json'
    $projectProvenance = [System.IO.File]::ReadAllText($projectProvenancePath) | ConvertFrom-Json
    Assert-True ($projectProvenance.authority -eq 'agent-harness/portable-project-contract/v3') 'Project provenance authority is not portable.'
    Assert-True (-not [System.IO.Path]::IsPathRooted([string]$projectProvenance.authority)) 'Project provenance embeds an absolute harness path.'

    [System.IO.File]::AppendAllText((Join-Path $repo 'STATUS.md'), "`r`nprovenance-tamper")
    $tamperRejected = $false
    try {
        & $manager -Action VerifyProject -HarnessRoot $harness -HomeRoot $testHome -Repository $repo | Out-Null
    }
    catch {
        $tamperRejected = $_.Exception.Message -match 'provenance'
    }
    Assert-True $tamperRejected 'Project verifier accepted a file whose provenance hash was stale.'
    & $manager -Action EnsureProject -HarnessRoot $harness -HomeRoot $testHome -Repository $repo -ProjectName 'fixture-project' -IncludeProduct | Out-Null

    $projectProvenance = [System.IO.File]::ReadAllText($projectProvenancePath) | ConvertFrom-Json
    $projectProvenance.authority = $harness
    [System.IO.File]::WriteAllText(
        $projectProvenancePath,
        ($projectProvenance | ConvertTo-Json -Depth 8) + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
    $absoluteAuthorityRejected = $false
    try {
        & $manager -Action VerifyProject -HarnessRoot $harness -HomeRoot $testHome -Repository $repo | Out-Null
    }
    catch {
        $absoluteAuthorityRejected = $_.Exception.Message -match 'provenance'
    }
    Assert-True $absoluteAuthorityRejected 'Project verifier accepted an absolute provenance authority.'
    & $manager -Action EnsureProject -HarnessRoot $harness -HomeRoot $testHome -Repository $repo -ProjectName 'fixture-project' -IncludeProduct | Out-Null

    $ensuredAgain = & $manager -Action EnsureProject -HarnessRoot $harness -HomeRoot $testHome -Repository $repo -ProjectName 'fixture-project' -IncludeProduct
    Assert-True ($ensuredAgain.changed.Count -eq 0) 'Second project ensure was not idempotent.'

    foreach ($name in & {
        $manifest = [System.IO.File]::ReadAllText((Join-Path $harness 'manifests\baseline-skills.json')) | ConvertFrom-Json
        @($manifest.bindings.canonical) | ForEach-Object { @($_) } | Sort-Object -Unique
    }) {
        $skill = Join-Path $harness "skills\$name"
        if (-not (Test-Path -LiteralPath $skill)) {
            New-Item -ItemType Directory -Path $skill -Force | Out-Null
            [System.IO.File]::WriteAllText(
                (Join-Path $skill 'SKILL.md'),
                "---`nname: $name`ndescription: Test fixture.`n---`n",
                [System.Text.UTF8Encoding]::new($false)
            )
        }
    }
    $synced = & $manager -Action SyncProject -HarnessRoot $harness -HomeRoot $testHome -Repository $repo -ProjectName 'fixture-project' -IncludeProduct
    foreach ($name in @(
        'deep-search', 'source-command-task', 'source-command-design', 'source-command-pathway',
        'source-command-solo-review', 'source-command-probe', 'source-command-hone',
        'source-command-spar', 'source-command-spec', 'correct',
        'source-command-brainstorming', 'source-command-systematic-debugging',
        'source-command-test-driven-development', 'source-command-requesting-code-review',
        'source-command-verification-before-completion', 'impeccable', 'parallelize'
    )) {
        Assert-True (Test-Path -LiteralPath (Join-Path $repo ".agents\skills\$name\SKILL.md")) "Baseline skill was not projected: $name"
    }

    [System.IO.File]::WriteAllText((Join-Path $repo 'CURRENT-TASK.md'), "# stale`r`n")
    $rejected = $false
    try { & $manager -Action VerifyProject -HarnessRoot $harness -HomeRoot $testHome -Repository $repo | Out-Null }
    catch { $rejected = $_.Exception.Message.Contains('CURRENT-TASK.md') }
    Assert-True $rejected 'Project verifier accepted stale task architecture.'
    Remove-Item -LiteralPath (Join-Path $repo 'CURRENT-TASK.md') -Force

    $global = & $manager -Action VerifyGlobal -HarnessRoot $harness -HomeRoot $testHome
    Assert-True ($global.result -eq 'Global harness verification passed.') 'Global package verification did not pass.'
    & $manager -Action Stamp -HarnessRoot $harness -HomeRoot $testHome | Out-Null
    $stampHash = (Get-FileHash -LiteralPath (Join-Path $harness 'setup-stamp.json') -Algorithm SHA256).Hash
    & $manager -Action Stamp -HarnessRoot $harness -HomeRoot $testHome | Out-Null
    $stampHashAgain = (Get-FileHash -LiteralPath (Join-Path $harness 'setup-stamp.json') -Algorithm SHA256).Hash
    Assert-True ($stampHash -eq $stampHashAgain) 'Setup stamp was not deterministic.'

    [System.IO.File]::AppendAllText((Join-Path $harness 'DESIGN.md'), "`r`n")
    & $manager -Action Stamp -HarnessRoot $harness -HomeRoot $testHome | Out-Null
    $restamped = & $manager -Action VerifyGlobal -HarnessRoot $harness -HomeRoot $testHome
    Assert-True ($restamped.result -eq 'Global harness verification passed.') 'Stamp could not accept an intentional package update.'

    $lineEndingFixture = Join-Path $harness 'capsule\README.md'
    $fixtureText = [System.IO.File]::ReadAllText($lineEndingFixture).Replace("`r`n", "`n")
    [System.IO.File]::WriteAllText(
        $lineEndingFixture,
        $fixtureText.Replace("`n", "`r`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
    $portableStamp = & $manager -Action VerifyGlobal -HarnessRoot $harness -HomeRoot $testHome
    Assert-True ($portableStamp.result -eq 'Global harness verification passed.') 'Setup stamp changed across equivalent LF and CRLF text.'

    Write-Output 'Manage-Harness tests passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
