[CmdletBinding()]
param(
    [switch]$Execute,
    [ValidateRange(30, 10080)]
    [int]$MinimumAgeMinutes = 180,
    [string]$InventoryPath,
    [datetime]$ReferenceTime = [datetime]::UtcNow,
    [string]$TaskkillPath = 'taskkill.exe',
    [string]$LogPath,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
$nodePath = 'C:\Program Files\nodejs\node.exe'
$protectedNames = @(
    'ChatGPT.exe',
    'codex.exe',
    'Cursor.exe',
    'Claude.exe'
)

function Get-AgentProcessInventory {
    if ($InventoryPath) {
        $parsedInventory = Get-Content -LiteralPath $InventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($row in $parsedInventory) {
            Write-Output $row
        }
        return
    }

    $rows = foreach ($process in Get-CimInstance Win32_Process) {
        $startTime = $null
        try {
            $startTime = (Get-Process -Id $process.ProcessId -ErrorAction Stop).StartTime.ToUniversalTime()
        }
        catch {
            continue
        }
        [pscustomobject]@{
            ProcessId = [int]$process.ProcessId
            ParentProcessId = [int]$process.ParentProcessId
            Name = [string]$process.Name
            ExecutablePath = [string]$process.ExecutablePath
            StartTimeUtc = $startTime.ToString('o')
        }
    }
    return @($rows)
}

function Get-Descendants {
    param(
        [int]$RootProcessId,
        [object[]]$Inventory
    )

    $descendants = [System.Collections.Generic.List[object]]::new()
    $queue = [System.Collections.Queue]::new()
    $queue.Enqueue($RootProcessId)
    while ($queue.Count -gt 0) {
        $parentId = [int]$queue.Dequeue()
        foreach ($child in @($Inventory | Where-Object ParentProcessId -eq $parentId)) {
            $descendants.Add($child)
            $queue.Enqueue([int]$child.ProcessId)
        }
    }
    return @($descendants)
}

function Test-ProtectedName {
    param([string]$Name)

    if ($protectedNames -contains $Name) {
        return $true
    }
    return $Name -like 'codex-command-runner*.exe'
}

function Get-StaleAgentRoots {
    param([object[]]$Inventory)

    $knownPids = @{}
    foreach ($process in $Inventory) {
        $knownPids[[int]$process.ProcessId] = $true
    }

    $cutoff = $ReferenceTime.ToUniversalTime().AddMinutes(-$MinimumAgeMinutes)
    $candidates = foreach ($process in $Inventory) {
        if ($process.Name -ne 'node.exe') { continue }
        if ($process.ExecutablePath -ne $nodePath) { continue }
        if ($knownPids.ContainsKey([int]$process.ParentProcessId)) { continue }

        $started = [datetime]::Parse(
            [string]$process.StartTimeUtc,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind
        ).ToUniversalTime()
        if ($started -gt $cutoff) { continue }

        $directChildren = @($Inventory | Where-Object ParentProcessId -eq $process.ProcessId)
        $cmdChildren = @($directChildren | Where-Object Name -eq 'cmd.exe')
        if ($cmdChildren.Count -eq 0) { continue }

        $descendants = @(Get-Descendants -RootProcessId $process.ProcessId -Inventory $Inventory)
        if (@($descendants | Where-Object { Test-ProtectedName -Name $_.Name }).Count -gt 0) {
            continue
        }

        $cmdHasNodeChild = $false
        foreach ($cmd in $cmdChildren) {
            if (@($Inventory | Where-Object {
                $_.ParentProcessId -eq $cmd.ProcessId -and
                $_.Name -eq 'node.exe' -and
                $_.ExecutablePath -eq $nodePath
            }).Count -gt 0) {
                $cmdHasNodeChild = $true
                break
            }
        }
        if (-not $cmdHasNodeChild) { continue }

        [pscustomobject]@{
            ProcessId = [int]$process.ProcessId
            StartTimeUtc = $started.ToString('o')
            AgeMinutes = [math]::Floor(($ReferenceTime.ToUniversalTime() - $started).TotalMinutes)
            DescendantCount = $descendants.Count
            Reason = 'orphaned old node-cmd-node helper tree'
        }
    }
    return @($candidates)
}

$initialInventory = @(Get-AgentProcessInventory)
$candidates = @(Get-StaleAgentRoots -Inventory $initialInventory)
$terminated = [System.Collections.Generic.List[int]]::new()
$skipped = [System.Collections.Generic.List[object]]::new()

if ($Execute) {
    foreach ($candidate in $candidates) {
        $freshInventory = @(Get-AgentProcessInventory)
        $freshCandidates = @(Get-StaleAgentRoots -Inventory $freshInventory)
        if ($candidate.ProcessId -notin $freshCandidates.ProcessId) {
            $skipped.Add([pscustomobject]@{
                ProcessId = $candidate.ProcessId
                Reason = 'failed immediate safety revalidation'
            })
            continue
        }

        & $TaskkillPath /PID $candidate.ProcessId /T /F | Out-Null
        $deadline = [datetime]::UtcNow.AddSeconds(5)
        do {
            $stillRunning = Get-Process -Id $candidate.ProcessId -ErrorAction SilentlyContinue
            if (-not $stillRunning) { break }
            Start-Sleep -Milliseconds 100
        } while ([datetime]::UtcNow -lt $deadline)

        if ($stillRunning) {
            $skipped.Add([pscustomobject]@{
                ProcessId = $candidate.ProcessId
                Reason = 'termination did not complete within five seconds'
            })
        }
        else {
            $terminated.Add([int]$candidate.ProcessId)
        }
    }
}

$result = [pscustomobject]@{
    TimestampUtc = [datetime]::UtcNow.ToString('o')
    Mode = if ($Execute) { 'execute' } else { 'dry-run' }
    MinimumAgeMinutes = $MinimumAgeMinutes
    CandidateCount = $candidates.Count
    Candidates = $candidates
    TerminatedCount = $terminated.Count
    TerminatedProcessIds = @($terminated)
    SkippedCount = $skipped.Count
    Skipped = @($skipped)
}

if ($LogPath) {
    $logDirectory = Split-Path -Parent $LogPath
    if ($logDirectory -and -not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }
    Add-Content -LiteralPath $LogPath -Value ($result | ConvertTo-Json -Depth 6 -Compress) -Encoding UTF8
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
}
else {
    $result
}
