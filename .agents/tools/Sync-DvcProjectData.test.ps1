$ErrorActionPreference = 'Stop'

$adapter = Join-Path $PSScriptRoot 'Sync-DvcProjectData.ps1'
$root = Join-Path $env:TEMP ('dvc project data proof ' + [Guid]::NewGuid().ToString('N'))
$sourceRepo = Join-Path $root 'source repository'
$receiverRepo = Join-Path $root 'receiving repository'
$corruptReceiverRepo = Join-Path $root 'corrupt receiving repository'
$missingRemoteRepo = Join-Path $root 'missing remote repository'
$rollbackRepo = Join-Path $root 'rollback repository'
$raceWinnerRepo = Join-Path $root 'race-winner'
$raceLoserRepo = Join-Path $root 'race-loser'
$existingRollbackRepo = Join-Path $root 'existing rollback repository'
$missingPublishRepo = Join-Path $root 'missing publish repository'
$reparseRepo = Join-Path $root 'reparse repository'
$advancerRepo = Join-Path $root 'upstream advancer'
$bareRemote = Join-Path $root 'project.git'
$sourceDataRoot = Join-Path $root 'source data root'
$receiverDataRoot = Join-Path $root 'receiver data root'
$corruptDataRoot = Join-Path $root 'corrupt receiver data root'
$sourceSyncRoot = Join-Path $root 'Google Drive A\Project Data'
$receiverSyncRoot = Join-Path $root 'Google Drive B\Project Data'
$corruptSyncRoot = Join-Path $root 'Google Drive Corrupt\Project Data'
$missingSyncRoot = Join-Path $root 'Google Drive Still Syncing\Project Data'
$project = 'proof-project'
$asset = 'research-bundle'
$relativeDestination = 'inputs\large payload.bin'
$sourcePath = Join-Path (Join-Path $sourceDataRoot $project) $relativeDestination
$receiverPath = Join-Path (Join-Path $receiverDataRoot $project) $relativeDestination

function Invoke-Git {
    param([string]$Repository, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & git -C $Repository @Arguments 2>&1 | Out-Null
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousPreference
    if ($exitCode -ne 0) {
        throw "git failed in $Repository"
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Throws {
    param([scriptblock]$Operation, [string]$Pattern, [string]$Message)
    try {
        & $Operation
    }
    catch {
        if ($_.Exception.Message -notmatch $Pattern) {
            throw "$Message Unexpected error: $($_.Exception.Message)"
        }
        return
    }
    throw $Message
}

try {
    New-Item -ItemType Directory -Path $sourceRepo, (Split-Path $sourcePath -Parent), $sourceSyncRoot | Out-Null
    [IO.File]::WriteAllBytes($sourcePath, [Text.Encoding]::UTF8.GetBytes('version-one-large-artifact'))

    $manifest = @"
version: 2
project: "$project"
data_root_env: "PROJECT_DATA_ROOT"
assets:
$(([IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot -Parent) 'templates\dvc-data-manifest.asset.yaml')) `
    -replace '<asset-id>', $asset `
    -replace '<project-name>', $project `
    -replace '<artifact-path>', 'large payload.bin'))
"@
    $manifestPath = Join-Path $root 'data-manifest.yaml'
    [IO.File]::WriteAllText($manifestPath, $manifest, [Text.UTF8Encoding]::new($false))
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Test-DataManifest.ps1') `
        -ManifestPath $manifestPath -AdapterRoot $PSScriptRoot | Out-Null
    $manifestExitCode = $LASTEXITCODE
    Assert-True ($manifestExitCode -eq 0) 'The reusable DVC manifest template did not validate.'

    $fakeDvcScript = Join-Path $root 'fake-dvc.ps1'
    $failingDvc = Join-Path $root 'fail-on-push.cmd'
    $fakeDvcScriptText = @'
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$DvcArguments)
$command = if ($DvcArguments.Count) { $DvcArguments[0] } else { '' }
if ($command -eq '--version') {
    Write-Output 'dvc 99.0 fixture'
    exit 0
}
if ($command -eq 'init') {
    New-Item -ItemType Directory -Path '.dvc' -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path '.dvc' 'config'), "[core]`n")
    if ($env:DVC_RACE_BARRIER) {
        New-Item -ItemType Directory -Path $env:DVC_RACE_BARRIER -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $env:DVC_RACE_BARRIER ((Split-Path (Get-Location) -Leaf) + '.ready')), 'ready')
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        while (@(Get-ChildItem -LiteralPath $env:DVC_RACE_BARRIER -Filter '*.ready' -File).Count -lt 2) {
            if ([DateTime]::UtcNow -gt $deadline) {
                Write-Error 'race fixture barrier timed out'
                exit 43
            }
            Start-Sleep -Milliseconds 25
        }
        if ((Split-Path (Get-Location) -Leaf) -eq 'race-loser') {
            Start-Sleep -Milliseconds 150
        }
    }
    exit 0
}
if ($command -eq 'remote') {
    New-Item -ItemType Directory -Path '.dvc' -Force | Out-Null
    $remote = $DvcArguments[$DvcArguments.Count - 1]
    [IO.File]::WriteAllText((Join-Path '.dvc' 'config.local'), "[remote `"project-data`"]`n    url = $remote`n")
    exit 0
}
if ($command -eq 'add') {
    $metadata = $DvcArguments[1] + '.dvc'
    New-Item -ItemType Directory -Path (Split-Path $metadata -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($metadata, "outs:`n- md5: fixture`n  path: fixture`n")
    exit 0
}
if ($command -eq 'push') {
    $config = [IO.File]::ReadAllText((Join-Path '.dvc' 'config.local'))
    $remote = ([regex]::Match($config, '(?m)^\s*url\s*=\s*(.+)$')).Groups[1].Value.Trim()
    if ($env:DVC_RACE_BARRIER) {
        if ((Split-Path (Get-Location) -Leaf) -eq 'race-loser') {
            Start-Sleep -Milliseconds 300
            Write-Error 'forced concurrent loser'
            exit 42
        }
        New-Item -ItemType Directory -Path $remote -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $remote 'winning-generation'), 'winner')
        Start-Sleep -Milliseconds 1200
        exit 0
    }
    New-Item -ItemType Directory -Path $remote -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $remote 'synced-competitor-object'), 'immutable competitor bytes')
    Write-Error 'forced fixture push failure'
    exit 42
}
exit 0
'@
    [IO.File]::WriteAllText($fakeDvcScript, $fakeDvcScriptText, [Text.UTF8Encoding]::new($false))
    $failingDvcText = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0fake-dvc.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n"
    [IO.File]::WriteAllText($failingDvc, $failingDvcText, [Text.Encoding]::ASCII)
    $brokenDvc = Join-Path $root 'broken-dvc.cmd'
    [IO.File]::WriteAllText($brokenDvc, "@echo off`r`nexit /b 101`r`n", [Text.Encoding]::ASCII)
    $rollbackDataRoot = Join-Path $root 'rollback data root'
    $rollbackSyncRoot = Join-Path $root 'rollback Drive\Project Data'
    $rollbackSource = Join-Path (Join-Path $rollbackDataRoot $project) $relativeDestination
    New-Item -ItemType Directory -Path $rollbackRepo, (Split-Path $rollbackSource -Parent), $rollbackSyncRoot -Force | Out-Null
    [IO.File]::WriteAllText($rollbackSource, 'rollback-proof')
    Invoke-Git $rollbackRepo init
    Assert-Throws {
        & $adapter -Action Inspect -Repository $rollbackRepo -Project $project -AssetId $asset `
            -RelativeDestination $relativeDestination -DataRoot $rollbackDataRoot -SyncRoot $rollbackSyncRoot `
            -DvcCommand $brokenDvc
    } 'runnable DVC|DVC is unavailable' 'A broken explicit DVC shim was accepted.'
    Assert-Throws {
        & $adapter -Action Publish -Repository $rollbackRepo -Project $project -AssetId $asset `
            -RelativeDestination $relativeDestination -DataRoot $rollbackDataRoot -SyncRoot $rollbackSyncRoot `
            -DvcCommand $failingDvc
    } 'DVC push failed' 'A forced push failure did not propagate.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $rollbackRepo '.dvc'))) 'Failed first publication left DVC initialization behind.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $rollbackRepo '.dvc-data'))) 'Failed first publication left staged data or ignore metadata behind.'
    $failedFirstRemote = Join-Path (Join-Path (Join-Path $rollbackSyncRoot $project) 'dvc') $asset
    Assert-True (Test-Path -LiteralPath (Join-Path $failedFirstRemote 'synced-competitor-object') -PathType Leaf) 'Failed first publication deleted immutable bytes that another Drive replica could have synchronized.'

    $raceWinnerDataRoot = Join-Path $root 'race winner data'
    $raceLoserDataRoot = Join-Path $root 'race loser data'
    $raceSyncRoot = Join-Path $root 'race Drive\Project Data'
    $raceBarrier = Join-Path $root 'race barrier'
    $raceWinnerSource = Join-Path (Join-Path $raceWinnerDataRoot $project) $relativeDestination
    $raceLoserSource = Join-Path (Join-Path $raceLoserDataRoot $project) $relativeDestination
    New-Item -ItemType Directory -Path $raceWinnerRepo, $raceLoserRepo, (Split-Path $raceWinnerSource -Parent), `
        (Split-Path $raceLoserSource -Parent), $raceSyncRoot -Force | Out-Null
    [IO.File]::WriteAllText($raceWinnerSource, 'winning-generation')
    [IO.File]::WriteAllText($raceLoserSource, 'losing-generation')
    Invoke-Git $raceWinnerRepo init
    Invoke-Git $raceLoserRepo init
    $raceArguments = @($adapter, $project, $asset, $relativeDestination, $raceSyncRoot, $failingDvc, $raceBarrier)
    $winnerJob = Start-Job -ScriptBlock {
        param($Adapter, $Project, $Asset, $RelativeDestination, $SyncRoot, $DvcCommand, $Barrier, $Repository, $DataRoot)
        $env:DVC_RACE_BARRIER = $Barrier
        try {
            $output = & $Adapter -Action Publish -Repository $Repository -Project $Project -AssetId $Asset `
                -RelativeDestination $RelativeDestination -DataRoot $DataRoot -SyncRoot $SyncRoot -DvcCommand $DvcCommand
            [pscustomobject]@{ succeeded = $true; output = [string]$output; error = '' }
        }
        catch {
            [pscustomobject]@{ succeeded = $false; output = ''; error = $_.Exception.Message }
        }
    } -ArgumentList ($raceArguments + @($raceWinnerRepo, $raceWinnerDataRoot))
    $loserJob = Start-Job -ScriptBlock {
        param($Adapter, $Project, $Asset, $RelativeDestination, $SyncRoot, $DvcCommand, $Barrier, $Repository, $DataRoot)
        $env:DVC_RACE_BARRIER = $Barrier
        try {
            $output = & $Adapter -Action Publish -Repository $Repository -Project $Project -AssetId $Asset `
                -RelativeDestination $RelativeDestination -DataRoot $DataRoot -SyncRoot $SyncRoot -DvcCommand $DvcCommand
            [pscustomobject]@{ succeeded = $true; output = [string]$output; error = '' }
        }
        catch {
            [pscustomobject]@{ succeeded = $false; output = ''; error = $_.Exception.Message }
        }
    } -ArgumentList ($raceArguments + @($raceLoserRepo, $raceLoserDataRoot))
    Wait-Job -Job $winnerJob, $loserJob | Out-Null
    $raceResults = @(Receive-Job -Job $winnerJob, $loserJob)
    Remove-Job -Job $winnerJob, $loserJob -Force
    Assert-True (@($raceResults | Where-Object succeeded).Count -eq 1) 'Simultaneous first publication did not produce exactly one owner.'
    Assert-True (@($raceResults | Where-Object { -not $_.succeeded }).Count -eq 1) 'Simultaneous first publication did not reject exactly one losing publisher.'
    $raceRemote = Join-Path (Join-Path (Join-Path $raceSyncRoot $project) 'dvc') $asset
    Assert-True (Test-Path -LiteralPath (Join-Path $raceRemote 'winning-generation') -PathType Leaf) 'The losing first publisher deleted the winning publisher remote generation.'
    Assert-True (@(Get-ChildItem -LiteralPath $raceSyncRoot -Recurse -Force -Filter '*.lock' -ErrorAction SilentlyContinue).Count -eq 0) 'A same-host optimization lock was written into the synchronized DVC remote.'

    $existingRollbackDataRoot = Join-Path $root 'existing rollback data root'
    $existingRollbackSyncRoot = Join-Path $root 'existing rollback Drive\Project Data'
    $existingRollbackSource = Join-Path (Join-Path $existingRollbackDataRoot $project) $relativeDestination
    $existingRemote = Join-Path (Join-Path (Join-Path $existingRollbackSyncRoot $project) 'dvc') $asset
    $existingMetadata = Join-Path $existingRollbackRepo ".dvc-data\$asset.dvc"
    $existingConfigLocal = Join-Path $existingRollbackRepo '.dvc\config.local'
    New-Item -ItemType Directory -Path $existingRollbackRepo, (Split-Path $existingRollbackSource -Parent), `
        $existingRemote, (Split-Path $existingMetadata -Parent), (Split-Path $existingConfigLocal -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($existingRollbackSource, 'existing-rollback-proof')
    [IO.File]::WriteAllText($existingMetadata, "outs:`n- md5: prior`n  path: fixture`n")
    $originalConfigLocal = "[remote `"original`"]`n    url = C:\prior remote`n"
    [IO.File]::WriteAllText($existingConfigLocal, $originalConfigLocal)
    Invoke-Git $existingRollbackRepo init
    Invoke-Git $existingRollbackRepo add .
    Invoke-Git $existingRollbackRepo -c user.email=proof@example.invalid -c user.name='DVC Proof' commit -m 'Existing DVC state'
    $existingMetadataHash = (Get-FileHash -LiteralPath $existingMetadata -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Throws {
        & $adapter -Action Publish -Repository $existingRollbackRepo -Project $project -AssetId $asset `
            -RelativeDestination $relativeDestination -DataRoot $existingRollbackDataRoot -SyncRoot $existingRollbackSyncRoot `
            -ExpectedMetadataSha256 $existingMetadataHash -DvcCommand $failingDvc
    } 'DVC push failed' 'A later forced push failure did not propagate.'
    Assert-True ([IO.File]::ReadAllText($existingConfigLocal) -ceq $originalConfigLocal) 'Failed later publication did not exactly restore .dvc\config.local.'

    $missingPublishDataRoot = Join-Path $root 'missing publish data root'
    $missingPublishSyncRoot = Join-Path $root 'missing publish Drive\Project Data'
    $missingPublishSource = Join-Path (Join-Path $missingPublishDataRoot $project) $relativeDestination
    New-Item -ItemType Directory -Path $missingPublishRepo, (Split-Path $missingPublishSource -Parent), `
        (Join-Path $missingPublishRepo '.dvc'), (Join-Path $missingPublishRepo '.dvc-data') -Force | Out-Null
    [IO.File]::WriteAllText($missingPublishSource, 'missing-publish-proof')
    $missingPublishMetadata = Join-Path $missingPublishRepo ".dvc-data\$asset.dvc"
    [IO.File]::WriteAllText($missingPublishMetadata, "outs:`n- md5: prior`n  path: fixture`n")
    [IO.File]::WriteAllText((Join-Path $missingPublishRepo '.dvc\config.local'), $originalConfigLocal)
    Invoke-Git $missingPublishRepo init
    Invoke-Git $missingPublishRepo add .
    Invoke-Git $missingPublishRepo -c user.email=proof@example.invalid -c user.name='DVC Proof' commit -m 'Published DVC state'
    $missingPublishHash = (Get-FileHash -LiteralPath $missingPublishMetadata -Algorithm SHA256).Hash.ToLowerInvariant()
    Assert-Throws {
        & $adapter -Action Publish -Repository $missingPublishRepo -Project $project -AssetId $asset `
            -RelativeDestination $relativeDestination -DataRoot $missingPublishDataRoot -SyncRoot $missingPublishSyncRoot `
            -ExpectedMetadataSha256 $missingPublishHash -DvcCommand $failingDvc
    } 'remote.*unavailable|sync' 'A later publication recreated a missing DVC remote.'
    $missingPublishRemote = Join-Path (Join-Path (Join-Path $missingPublishSyncRoot $project) 'dvc') $asset
    Assert-True (-not (Test-Path -LiteralPath $missingPublishRemote)) 'A later publication created a replacement remote while Drive was unavailable.'

    $reparseDataRoot = Join-Path $root 'reparse data root'
    $reparseSyncRoot = Join-Path $root 'reparse Drive\Project Data'
    $reparseSource = Join-Path (Join-Path $reparseDataRoot $project) 'inputs\bundle'
    $outsideDirectory = Join-Path $root 'outside directory'
    New-Item -ItemType Directory -Path $reparseRepo, $reparseSource, $outsideDirectory, $reparseSyncRoot -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $outsideDirectory 'outside.bin'), 'outside')
    New-Item -ItemType Junction -Path (Join-Path $reparseSource 'escape') -Target $outsideDirectory | Out-Null
    Invoke-Git $reparseRepo init
    Assert-Throws {
        & $adapter -Action Publish -Repository $reparseRepo -Project $project -AssetId 'directory-bundle' `
            -RelativeDestination 'inputs\bundle' -DataRoot $reparseDataRoot -SyncRoot $reparseSyncRoot `
            -DvcCommand $failingDvc
    } 'Nested reparse-point' 'Publish followed a nested junction inside a directory asset.'

    $realDvc = @(
        Get-Command dvc.exe -All -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Source }
        if ($env:USERPROFILE) { Join-Path $env:USERPROFILE '.local\bin\dvc.exe' }
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -Unique | Where-Object {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $_ --version 2>&1 | Out-Null
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = $previousPreference
        $exitCode -eq 0
    } | Select-Object -First 1
    if (-not $realDvc) {
        Write-Host 'Sync-DvcProjectData safety regressions passed; full DVC integration skipped because no runnable normal-user DVC exists.'
        return
    }

    Invoke-Git $sourceRepo init
    Invoke-Git $sourceRepo config user.email 'proof@example.invalid'
    Invoke-Git $sourceRepo config user.name 'DVC Proof'

    $firstPublish = & $adapter -Action Publish -Repository $sourceRepo -Project $project -AssetId $asset `
        -RelativeDestination $relativeDestination -DataRoot $sourceDataRoot -SyncRoot $sourceSyncRoot |
        ConvertFrom-Json

    Assert-True ($firstPublish.action -eq 'Publish') 'Publish did not return structured evidence.'
    Assert-True ($firstPublish.content_sha256 -match '^[0-9a-f]{64}$') 'Publish omitted the content SHA-256.'
    Assert-True ($firstPublish.metadata_sha256 -match '^[0-9a-f]{64}$') 'Publish omitted the metadata SHA-256.'
    Assert-True (Test-Path -LiteralPath $firstPublish.metadata_path) 'DVC metadata was not created.'
    Assert-True (Test-Path -LiteralPath (Join-Path $sourceRepo '.dvc\config.local')) 'The per-device remote config was not created.'
    $trackedConfig = Join-Path $sourceRepo '.dvc\config'
    if (Test-Path -LiteralPath $trackedConfig) {
        $trackedText = [IO.File]::ReadAllText($trackedConfig)
        Assert-True (-not $trackedText.Contains($sourceSyncRoot)) 'The source-machine Drive path leaked into tracked DVC config.'
    }

    $inspection = & $adapter -Action Inspect -Repository $sourceRepo -Project $project -AssetId $asset `
        -RelativeDestination $relativeDestination -DataRoot $sourceDataRoot -SyncRoot $sourceSyncRoot |
        ConvertFrom-Json
    Assert-True ($inspection.metadata_sha256 -eq $firstPublish.metadata_sha256) 'Inspect returned a different metadata checksum.'
    Assert-True ($inspection.content_sha256 -eq $firstPublish.content_sha256) 'Inspect returned a different content checksum.'

    Invoke-Git $sourceRepo add .
    Invoke-Git $sourceRepo commit -m 'Track proof artifact'

    New-Item -ItemType Directory -Path (Split-Path $receiverSyncRoot -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $sourceSyncRoot -Destination $receiverSyncRoot -Recurse
    Invoke-Git $root clone $sourceRepo $receiverRepo

    $retrieval = & $adapter -Action Retrieve -Repository $receiverRepo -Project $project -AssetId $asset `
        -RelativeDestination $relativeDestination -DataRoot $receiverDataRoot -SyncRoot $receiverSyncRoot |
        ConvertFrom-Json
    Assert-True (Test-Path -LiteralPath $receiverPath) 'The receiving computer did not get the artifact.'
    Assert-True ($retrieval.content_sha256 -eq $firstPublish.content_sha256) 'The receiving checksum differs from the published checksum.'

    Invoke-Git $root clone $sourceRepo $missingRemoteRepo
    Assert-Throws {
        & $adapter -Action Retrieve -Repository $missingRemoteRepo -Project $project -AssetId $asset `
            -RelativeDestination $relativeDestination -DataRoot (Join-Path $root 'missing remote data') -SyncRoot $missingSyncRoot
    } 'remote.*missing|remote.*unavailable|sync' 'Retrieve concealed a Drive remote that had not synced yet.'
    Assert-True (-not (Test-Path -LiteralPath $missingSyncRoot)) 'Retrieve created an empty remote while Drive was still syncing.'

    New-Item -ItemType Directory -Path (Split-Path $corruptSyncRoot -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $sourceSyncRoot -Destination $corruptSyncRoot -Recurse
    $remoteObject = Get-ChildItem -LiteralPath (Join-Path (Join-Path (Join-Path $corruptSyncRoot $project) 'dvc') $asset) -File -Recurse |
        Select-Object -First 1
    Assert-True ($null -ne $remoteObject) 'The proof remote did not contain a DVC content object.'
    $remoteObject.Attributes = [IO.FileAttributes]::Normal
    [IO.File]::WriteAllText($remoteObject.FullName, 'corrupted-remote-object')
    Invoke-Git $root clone $sourceRepo $corruptReceiverRepo
    Assert-Throws {
        & $adapter -Action Retrieve -Repository $corruptReceiverRepo -Project $project -AssetId $asset `
            -RelativeDestination $relativeDestination -DataRoot $corruptDataRoot -SyncRoot $corruptSyncRoot
    } 'checksum|hash|corrupt|DVC pull failed' 'Retrieve accepted a corrupted content-addressed remote object.'

    [IO.File]::WriteAllText($receiverPath, 'locally-edited')
    Assert-Throws {
        & $adapter -Action Retrieve -Repository $receiverRepo -Project $project -AssetId $asset `
            -RelativeDestination $relativeDestination -DataRoot $receiverDataRoot -SyncRoot $receiverSyncRoot
    } 'dirty destination' 'Retrieve overwrote a dirty local destination.'
    Assert-True ([IO.File]::ReadAllText($receiverPath) -eq 'locally-edited') 'Dirty destination bytes changed.'

    [IO.File]::WriteAllText($sourcePath, 'version-two-large-artifact')
    Assert-Throws {
        & $adapter -Action Publish -Repository $sourceRepo -Project $project -AssetId $asset `
            -RelativeDestination $relativeDestination -DataRoot $sourceDataRoot -SyncRoot $sourceSyncRoot `
            -ExpectedMetadataSha256 ('0' * 64)
    } 'stale publish' 'Publish accepted a stale metadata checksum.'

    Invoke-Git $root init --bare $bareRemote
    Invoke-Git $sourceRepo remote add origin $bareRemote
    Invoke-Git $sourceRepo push --set-upstream origin HEAD:master
    Invoke-Git $root clone $bareRemote $advancerRepo
    Invoke-Git $advancerRepo config user.email 'proof@example.invalid'
    Invoke-Git $advancerRepo config user.name 'DVC Proof'
    [IO.File]::WriteAllText((Join-Path $advancerRepo 'upstream-marker.txt'), 'advanced')
    Invoke-Git $advancerRepo add upstream-marker.txt
    Invoke-Git $advancerRepo commit -m 'Advance upstream'
    Invoke-Git $advancerRepo push
    Assert-Throws {
        & $adapter -Action Publish -Repository $sourceRepo -Project $project -AssetId $asset `
            -RelativeDestination $relativeDestination -DataRoot $sourceDataRoot -SyncRoot $sourceSyncRoot `
            -ExpectedMetadataSha256 $firstPublish.metadata_sha256
    } 'upstream Git revision advanced' 'Publish accepted a checkout whose upstream revision had advanced.'
    Invoke-Git $sourceRepo pull --ff-only

    $secondPublish = & $adapter -Action Publish -Repository $sourceRepo -Project $project -AssetId $asset `
        -RelativeDestination $relativeDestination -DataRoot $sourceDataRoot -SyncRoot $sourceSyncRoot `
        -ExpectedMetadataSha256 $firstPublish.metadata_sha256 |
        ConvertFrom-Json
    Assert-True ($secondPublish.content_sha256 -ne $firstPublish.content_sha256) 'A new artifact version did not produce a new checksum.'
    Assert-True ($secondPublish.metadata_sha256 -ne $firstPublish.metadata_sha256) 'A new artifact version did not update DVC metadata.'

    $verification = & $adapter -Action Verify -Repository $sourceRepo -Project $project -AssetId $asset `
        -RelativeDestination $relativeDestination -DataRoot $sourceDataRoot -SyncRoot $sourceSyncRoot |
        ConvertFrom-Json
    Assert-True ($verification.remote_in_sync) 'DVC did not verify its content-addressed remote.'
    Assert-True ($verification.content_sha256 -eq $secondPublish.content_sha256) 'Verify returned the wrong content checksum.'

    Write-Host 'Sync-DvcProjectData integration proof passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
