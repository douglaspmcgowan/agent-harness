$ErrorActionPreference = 'Stop'

$restore = Join-Path $PSScriptRoot 'Restore-AgentWorkspace.ps1'
$root = Join-Path $env:TEMP ("agent-restore-test-" + [Guid]::NewGuid().ToString('N'))
$backup = Join-Path $root 'backup'
$remote = Join-Path $root 'remote.git'
$seed = Join-Path $root 'seed'
$target = Join-Path $root 'new-computer'

try {
    New-Item -ItemType Directory -Path $seed, (Join-Path $backup 'Recovery'), (Join-Path $backup 'Application Data\Projects\sample'), (Join-Path $backup 'Product Configuration\cursor') -Force | Out-Null
    git init --bare $remote | Out-Null
    git -C $seed init | Out-Null
    git -C $seed config user.name 'Restore Test'
    git -C $seed config user.email 'restore-test@example.invalid'
    [System.IO.File]::WriteAllText((Join-Path $seed 'README.md'), "# restored`n")
    git -C $seed add README.md
    git -C $seed commit -m 'sample' | Out-Null
    git -C $seed remote add origin $remote
    git -C $seed push -u origin HEAD:master | Out-Null
    $commit = (git -C $seed rev-parse HEAD).Trim()

    $manifest = [ordered]@{
        schemaVersion = 1
        projects = @([ordered]@{ name='sample'; remote=$remote; branch='master'; commit=$commit })
    }
    New-Item -ItemType Directory -Path (Join-Path $backup 'Handoffs\sample') -Force | Out-Null
    git -C $seed bundle create (Join-Path $backup 'Handoffs\sample\Repository.bundle') --all
    if ($LASTEXITCODE -ne 0) { throw 'Restore test bundle setup failed.' }
    [System.IO.File]::WriteAllText((Join-Path $backup 'Recovery\project-recovery.json'), ($manifest | ConvertTo-Json -Depth 5))
    [System.IO.File]::WriteAllText((Join-Path $backup 'Application Data\Projects\sample\data.txt'), 'restored-data')
    [System.IO.File]::WriteAllText((Join-Path $backup 'Product Configuration\cursor\settings.json'), '{"restored":true}')

    Move-Item -LiteralPath $remote -Destination ($remote + '.offline')
    & $restore -BackupRoot $backup -UserRoot $target -SkipQuickAccess

    if ((git -C (Join-Path $target 'projects\sample') rev-parse HEAD).Trim() -ne $commit) {
        throw 'Project was not restored at the recorded commit.'
    }
    $restoredRepository = Join-Path $target 'projects\sample'
    if ((git -C $restoredRepository remote get-url origin).Trim() -ne $remote) {
        throw 'Recorded GitHub-style remote was not restored as origin.'
    }
    if (-not (@(git -C $restoredRepository remote) -contains 'capsule')) {
        throw 'Offline bundle was not retained as the capsule remote.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $target 'Data\Projects\sample\data.txt'))) {
        throw 'Application data was not restored.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $target '.cursor\settings.json'))) {
        throw 'Product configuration was not restored.'
    }

    'Agent workspace restore regression test passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
