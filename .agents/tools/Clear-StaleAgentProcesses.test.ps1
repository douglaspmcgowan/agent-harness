$ErrorActionPreference = 'Stop'

$tool = Join-Path $PSScriptRoot 'Clear-StaleAgentProcesses.ps1'
$root = Join-Path $env:TEMP ("stale-agent-process-test-" + [Guid]::NewGuid().ToString('N'))
$inventoryPath = Join-Path $root 'inventory.json'
$mockTaskkill = Join-Path $root 'taskkill.cmd'
$marker = Join-Path $root 'taskkill-marker.txt'
$nodePath = 'C:\Program Files\nodejs\node.exe'
$referenceTime = [datetime]'2026-07-28T18:00:00Z'

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $inventory = @(
        [ordered]@{ ProcessId=100; ParentProcessId=999; Name='node.exe'; ExecutablePath=$nodePath; StartTimeUtc='2026-07-28T10:00:00Z' },
        [ordered]@{ ProcessId=101; ParentProcessId=100; Name='cmd.exe'; ExecutablePath='C:\Windows\System32\cmd.exe'; StartTimeUtc='2026-07-28T10:00:01Z' },
        [ordered]@{ ProcessId=102; ParentProcessId=101; Name='node.exe'; ExecutablePath=$nodePath; StartTimeUtc='2026-07-28T10:00:02Z' },
        [ordered]@{ ProcessId=200; ParentProcessId=201; Name='node.exe'; ExecutablePath=$nodePath; StartTimeUtc='2026-07-28T10:00:00Z' },
        [ordered]@{ ProcessId=201; ParentProcessId=1; Name='codex-command-runner.exe'; ExecutablePath='C:\Codex\runner.exe'; StartTimeUtc='2026-07-28T10:00:00Z' },
        [ordered]@{ ProcessId=202; ParentProcessId=200; Name='cmd.exe'; ExecutablePath='C:\Windows\System32\cmd.exe'; StartTimeUtc='2026-07-28T10:00:01Z' },
        [ordered]@{ ProcessId=203; ParentProcessId=202; Name='node.exe'; ExecutablePath=$nodePath; StartTimeUtc='2026-07-28T10:00:02Z' },
        [ordered]@{ ProcessId=300; ParentProcessId=998; Name='node.exe'; ExecutablePath=$nodePath; StartTimeUtc='2026-07-28T10:00:00Z' },
        [ordered]@{ ProcessId=301; ParentProcessId=300; Name='cmd.exe'; ExecutablePath='C:\Windows\System32\cmd.exe'; StartTimeUtc='2026-07-28T10:00:01Z' },
        [ordered]@{ ProcessId=302; ParentProcessId=301; Name='codex.exe'; ExecutablePath='C:\Codex\codex.exe'; StartTimeUtc='2026-07-28T10:00:02Z' },
        [ordered]@{ ProcessId=400; ParentProcessId=997; Name='node.exe'; ExecutablePath=$nodePath; StartTimeUtc='2026-07-28T17:30:00Z' },
        [ordered]@{ ProcessId=401; ParentProcessId=400; Name='cmd.exe'; ExecutablePath='C:\Windows\System32\cmd.exe'; StartTimeUtc='2026-07-28T17:30:01Z' },
        [ordered]@{ ProcessId=402; ParentProcessId=401; Name='node.exe'; ExecutablePath=$nodePath; StartTimeUtc='2026-07-28T17:30:02Z' }
    )
    [System.IO.File]::WriteAllText(
        $inventoryPath,
        ($inventory | ConvertTo-Json -Depth 4),
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        $mockTaskkill,
        "@echo off`r`n>> `"$marker`" echo %*`r`n",
        [System.Text.Encoding]::ASCII
    )

    $dryRun = & $tool -InventoryPath $inventoryPath -ReferenceTime $referenceTime -MinimumAgeMinutes 180
    if ($dryRun.Mode -ne 'dry-run') { throw 'Default mode was not dry-run.' }
    if ($dryRun.CandidateCount -ne 1) { throw "Expected one candidate; found $($dryRun.CandidateCount)." }
    if ($dryRun.Candidates.ProcessId -ne 100) { throw 'Wrong process tree selected.' }
    if (Test-Path -LiteralPath $marker) { throw 'Dry-run called the terminator.' }

    $execute = & $tool -Execute -InventoryPath $inventoryPath -ReferenceTime $referenceTime -MinimumAgeMinutes 180 -TaskkillPath $mockTaskkill
    if ($execute.TerminatedCount -ne 1) { throw 'Execute mode did not report the validated candidate.' }
    $invocation = Get-Content -LiteralPath $marker -Raw
    if ($invocation -notmatch '/PID 100 /T /F') { throw 'Terminator did not receive the exact validated tree.' }

    'Clear-StaleAgentProcesses regression test passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
