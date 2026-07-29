[CmdletBinding()]
param(
    [ValidateRange(0, 60)]
    [int]$SampleSeconds = 1,
    [ValidateRange(1, 10080)]
    [int]$MinimumAgeMinutes = 60,
    [string]$InventoryPath,
    [string]$RevalidateCandidateId,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
$activeAgentNames = @('chatgpt.exe', 'codex.exe', 'claude.exe', 'cursor.exe')
$windowsCoreNames = @(
    'system', 'registry', 'memory compression', 'secure system', 'idle',
    'smss.exe', 'csrss.exe', 'wininit.exe', 'services.exe', 'lsass.exe',
    'winlogon.exe', 'dwm.exe', 'explorer.exe', 'svchost.exe'
)
$trackedNames = @(
    'node.exe', 'python.exe', 'pythonw.exe', 'chrome.exe', 'headless_shell.exe',
    'msedge.exe', 'chromium.exe', 'chromedriver.exe', 'msedgedriver.exe',
    'geckodriver.exe', 'msedgewebview2.exe', 'electron.exe', 'git.exe',
    'taskkill.exe', 'conhost.exe'
)
$currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value

function Convert-ToUtcString {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    return ([datetime]$Value).ToUniversalTime().ToString('o')
}

function Convert-ToProcessRow {
    param($Process, [string]$OwnerSid)
    $cpuSeconds = ([double]$Process.KernelModeTime + [double]$Process.UserModeTime) / 10000000
    [pscustomobject]@{
        ProcessId = [int]$Process.ProcessId
        ParentProcessId = [int]$Process.ParentProcessId
        Name = [string]$Process.Name
        ExecutablePath = [string]$Process.ExecutablePath
        StartTimeUtc = Convert-ToUtcString $Process.CreationDate
        OwnerSid = $OwnerSid
        SessionId = [int]$Process.SessionId
        WorkingSetBytes = [int64]$Process.WorkingSetSize
        PrivateBytes = [int64]$Process.PrivatePageCount
        CpuSeconds = [math]::Round($cpuSeconds, 3)
    }
}

function Get-LiveProcesses {
    $rawProcesses = @(Get-CimInstance Win32_Process)
    $rows = foreach ($process in $rawProcesses) {
        $ownerSid = $null
        # Owner lookups through Win32_Process.GetOwnerSid can stall for tens of
        # seconds on inaccessible or exiting processes. The live audit records
        # missing ownership as ambiguity and therefore cannot auto-approve it.
        Convert-ToProcessRow -Process $process -OwnerSid $ownerSid
    }
    return @($rows)
}

function Get-LiveSystemMemory {
    $computer = Get-CimInstance Win32_ComputerSystem
    $memory = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory
    [pscustomobject]@{
        TotalPhysicalBytes = [int64]$computer.TotalPhysicalMemory
        AvailablePhysicalBytes = [int64]$memory.AvailableBytes
        CommittedBytes = [int64]$memory.CommittedBytes
        CommitLimitBytes = [int64]$memory.CommitLimit
        PoolPagedBytes = [int64]$memory.PoolPagedBytes
        PoolNonpagedBytes = [int64]$memory.PoolNonpagedBytes
        CacheBytes = [int64]$memory.CacheBytes
    }
}

function Normalize-ProcessRows {
    param([object[]]$Rows)
    return @($Rows | ForEach-Object {
        [pscustomobject]@{
            ProcessId = [int]$_.ProcessId
            ParentProcessId = [int]$_.ParentProcessId
            Name = [string]$_.Name
            ExecutablePath = [string]$_.ExecutablePath
            StartTimeUtc = Convert-ToUtcString $_.StartTimeUtc
            OwnerSid = [string]$_.OwnerSid
            SessionId = [int]$_.SessionId
            WorkingSetBytes = [int64]$_.WorkingSetBytes
            PrivateBytes = [int64]$_.PrivateBytes
            CpuSeconds = [double]$_.CpuSeconds
        }
    })
}

function Get-Descendants {
    param([int]$RootProcessId, [object[]]$Inventory)
    $found = [System.Collections.Generic.List[object]]::new()
    $queue = [System.Collections.Queue]::new()
    $seen = @{}
    $seen[$RootProcessId] = $true
    $queue.Enqueue($RootProcessId)
    while ($queue.Count -gt 0) {
        $parentId = [int]$queue.Dequeue()
        foreach ($child in @($Inventory | Where-Object ParentProcessId -eq $parentId)) {
            if ($seen.ContainsKey([int]$child.ProcessId)) {
                continue
            }
            $seen[[int]$child.ProcessId] = $true
            $found.Add($child)
            $queue.Enqueue([int]$child.ProcessId)
        }
    }
    return @($found)
}

function Get-Ancestors {
    param($Process, [hashtable]$ByPid)
    $found = [System.Collections.Generic.List[object]]::new()
    $seen = @{}
    $parentId = [int]$Process.ParentProcessId
    while ($ByPid.ContainsKey($parentId) -and -not $seen.ContainsKey($parentId)) {
        $parent = $ByPid[$parentId]
        $found.Add($parent)
        $seen[$parentId] = $true
        $parentId = [int]$parent.ParentProcessId
    }
    return @($found)
}

function Test-ActiveAgentName {
    param([string]$Name)
    $lower = $Name.ToLowerInvariant()
    return ($lower -in $activeAgentNames -or $lower -like 'codex-command-runner*.exe')
}

function Test-WindowsCore {
    param($Process)
    $name = $Process.Name.ToLowerInvariant()
    $path = $Process.ExecutablePath.ToLowerInvariant()
    if ($name -in $windowsCoreNames) { return $true }
    if ($path -match '^c:\\windows\\(system32|syswow64|winsxs)\\' -and
        $name -notin @('conhost.exe', 'taskkill.exe')) { return $true }
    return $false
}

function Get-CandidateId {
    param($Process, [string]$Classification)
    $raw = '{0}|{1}|{2}|{3}|{4}|{5}' -f
        $Process.ProcessId,
        $Process.StartTimeUtc,
        $Process.ExecutablePath.ToLowerInvariant(),
        $Process.OwnerSid,
        $Process.SessionId,
        $Classification
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($raw)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-ProcessClassification {
    param($Process, [object[]]$Inventory, [hashtable]$ByPid, [datetime]$ReferenceTime)
    $name = $Process.Name.ToLowerInvariant()
    $path = $Process.ExecutablePath.ToLowerInvariant()
    $started = if ($Process.StartTimeUtc) { [datetime]$Process.StartTimeUtc } else { $null }
    $ageMinutes = if ($started) {
        [math]::Max(0, [math]::Floor(($ReferenceTime - $started.ToUniversalTime()).TotalMinutes))
    } else { $null }
    $parentKnown = $ByPid.ContainsKey([int]$Process.ParentProcessId)
    $ancestors = @(Get-Ancestors -Process $Process -ByPid $ByPid)
    $descendants = @(Get-Descendants -RootProcessId $Process.ProcessId -Inventory $Inventory)
    $activeRelated = (Test-ActiveAgentName $Process.Name) -or
        @($ancestors | Where-Object { Test-ActiveAgentName $_.Name }).Count -gt 0 -or
        @($descendants | Where-Object { Test-ActiveAgentName $_.Name }).Count -gt 0

    if ($activeRelated -or (Test-WindowsCore $Process)) {
        return [pscustomobject]@{ Class='protected-active-tree'; Type='protected'; Reason='active agent ancestry or Windows core identity'; AgeMinutes=$ageMinutes }
    }
    if ($name -notin $trackedNames) { return $null }
    if ($parentKnown) { return $null }
    if ($null -eq $ageMinutes -or $ageMinutes -lt $MinimumAgeMinutes) { return $null }
    if ([string]::IsNullOrWhiteSpace($path) -or [string]::IsNullOrWhiteSpace($Process.OwnerSid)) {
        return [pscustomobject]@{ Class='decision-required'; Type='unknown-owner-or-path'; Reason='typed process has a missing parent, but path or owner evidence is incomplete'; AgeMinutes=$ageMinutes }
    }
    if ($Process.OwnerSid -ne $currentSid -and -not $InventoryPath) { return $null }

    $nodePath = 'c:\program files\nodejs\node.exe'
    if ($name -eq 'node.exe' -and $path -eq $nodePath -and $ageMinutes -ge 180) {
        $cmdChildren = @($descendants | Where-Object {
            $_.ParentProcessId -eq $Process.ProcessId -and
            $_.Name.ToLowerInvariant() -eq 'cmd.exe' -and
            $_.ExecutablePath.ToLowerInvariant() -eq 'c:\windows\system32\cmd.exe'
        })
        $exactNodeChain = $false
        foreach ($cmd in $cmdChildren) {
            if (@($descendants | Where-Object {
                $_.ParentProcessId -eq $cmd.ProcessId -and
                $_.Name.ToLowerInvariant() -eq 'node.exe' -and
                $_.ExecutablePath.ToLowerInvariant() -eq $nodePath
            }).Count -gt 0) { $exactNodeChain = $true; break }
        }
        if ($exactNodeChain) {
            return [pscustomobject]@{ Class='established-node-cleanup'; Type='node-cmd-node'; Reason='exact old orphaned node-cmd-node helper pattern; use established guarded tool only'; AgeMinutes=$ageMinutes }
        }
    }
    if ($name -in @('chrome.exe','headless_shell.exe','msedge.exe','chromium.exe') -and $path -match '\\ms-playwright\\') {
        return [pscustomobject]@{ Class='decision-required'; Type='detached-playwright-browser'; Reason='old browser root from an exact Playwright-managed executable path has no live parent'; AgeMinutes=$ageMinutes }
    }
    if ($name -in @('chromedriver.exe','msedgedriver.exe','geckodriver.exe')) {
        return [pscustomobject]@{ Class='decision-required'; Type='detached-browser-driver'; Reason='old browser-driver root has no live parent'; AgeMinutes=$ageMinutes }
    }
    if ($name -eq 'node.exe') {
        return [pscustomobject]@{ Class='decision-required'; Type='detached-node-or-mcp'; Reason='old Node root has no live parent; command-line inspection is intentionally excluded'; AgeMinutes=$ageMinutes }
    }
    if ($name -in @('python.exe','pythonw.exe')) {
        return [pscustomobject]@{ Class='decision-required'; Type='detached-python'; Reason='old Python root has no live parent; workload ownership remains ambiguous'; AgeMinutes=$ageMinutes }
    }
    if ($name -in @('msedgewebview2.exe','electron.exe')) {
        return [pscustomobject]@{ Class='decision-required'; Type='detached-webview-or-electron'; Reason='old embedded-browser root has no live parent; owning application must be identified'; AgeMinutes=$ageMinutes }
    }
    if ($name -in @('git.exe','taskkill.exe','conhost.exe')) {
        return [pscustomobject]@{ Class='decision-required'; Type='detached-console-helper'; Reason='old console/helper root has no live parent; owning task must be identified'; AgeMinutes=$ageMinutes }
    }
    if ($name -in @('chrome.exe','msedge.exe','chromium.exe','headless_shell.exe')) {
        return [pscustomobject]@{ Class='decision-required'; Type='detached-browser'; Reason='old browser root has no live parent; may be an intentional user browser'; AgeMinutes=$ageMinutes }
    }
    return $null
}

function Get-Delta {
    param($Before, $After)
    if (-not $After) {
        return [pscustomobject]@{ WorkingSetBytes=0; PrivateBytes=0; CpuSeconds=0 }
    }
    [pscustomobject]@{
        WorkingSetBytes = [int64]$After.WorkingSetBytes - [int64]$Before.WorkingSetBytes
        PrivateBytes = [int64]$After.PrivateBytes - [int64]$Before.PrivateBytes
        CpuSeconds = [math]::Round([double]$After.CpuSeconds - [double]$Before.CpuSeconds, 3)
    }
}

$fixture = $null
if ($InventoryPath) {
    $fixture = Get-Content -LiteralPath $InventoryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $system = $fixture.System
    $before = @(Normalize-ProcessRows @($fixture.Processes))
    $after = if ($fixture.ProcessesAfter) { @(Normalize-ProcessRows @($fixture.ProcessesAfter)) } else { $before }
    $referenceTime = if ($fixture.ReferenceTimeUtc) { ([datetime]$fixture.ReferenceTimeUtc).ToUniversalTime() } else { [datetime]::UtcNow }
}
else {
    $system = Get-LiveSystemMemory
    $before = @(Get-LiveProcesses)
    if ($SampleSeconds -gt 0) { Start-Sleep -Seconds $SampleSeconds }
    $after = if ($SampleSeconds -gt 0) { @(Get-LiveProcesses) } else { $before }
    $referenceTime = [datetime]::UtcNow
}

$beforeByPid = @{}
foreach ($process in $before) { $beforeByPid[[int]$process.ProcessId] = $process }
$afterByIdentity = @{}
foreach ($process in $after) {
    $key = '{0}|{1}' -f $process.ProcessId, $process.StartTimeUtc
    $afterByIdentity[$key] = $process
}

$candidates = [System.Collections.Generic.List[object]]::new()
foreach ($process in $before) {
    $classification = Get-ProcessClassification -Process $process -Inventory $before -ByPid $beforeByPid -ReferenceTime $referenceTime
    if (-not $classification -or $classification.Class -eq 'protected-active-tree') { continue }
    $descendants = @(Get-Descendants -RootProcessId $process.ProcessId -Inventory $before)
    $tree = @($process) + $descendants
    $treeWorkingSet = [int64](($tree | Measure-Object WorkingSetBytes -Sum).Sum)
    $treePrivate = [int64](($tree | Measure-Object PrivateBytes -Sum).Sum)
    $afterProcess = $afterByIdentity['{0}|{1}' -f $process.ProcessId, $process.StartTimeUtc]
    $delta = Get-Delta -Before $process -After $afterProcess
    $id = Get-CandidateId -Process $process -Classification $classification.Class
    $candidates.Add([pscustomobject]@{
        CandidateId = $id
        Classification = $classification.Class
        Type = $classification.Type
        ProcessId = $process.ProcessId
        ParentProcessId = $process.ParentProcessId
        ParentPresent = $beforeByPid.ContainsKey([int]$process.ParentProcessId)
        Name = $process.Name
        ExecutablePath = $process.ExecutablePath
        StartTimeUtc = $process.StartTimeUtc
        AgeMinutes = $classification.AgeMinutes
        OwnerSid = $process.OwnerSid
        SessionId = $process.SessionId
        DescendantCount = $descendants.Count
        TreeWorkingSetBytes = $treeWorkingSet
        TreePrivateBytes = $treePrivate
        RootDelta = $delta
        Reason = $classification.Reason
    })
}

$processGroups = @($before | Group-Object Name | ForEach-Object {
        $cpuDelta = 0.0
        $workingSetDelta = [int64]0
        $privateDelta = [int64]0
        foreach ($member in $_.Group) {
            $afterMember = $afterByIdentity['{0}|{1}' -f $member.ProcessId, $member.StartTimeUtc]
            $memberDelta = Get-Delta -Before $member -After $afterMember
            $cpuDelta += [double]$memberDelta.CpuSeconds
            $workingSetDelta += [int64]$memberDelta.WorkingSetBytes
            $privateDelta += [int64]$memberDelta.PrivateBytes
        }
        [pscustomobject]@{
            Name = $_.Name
            ProcessCount = $_.Count
            WorkingSetBytes = [int64](($_.Group | Measure-Object WorkingSetBytes -Sum).Sum)
            PrivateBytes = [int64](($_.Group | Measure-Object PrivateBytes -Sum).Sum)
            WorkingSetDeltaBytes = $workingSetDelta
            PrivateDeltaBytes = $privateDelta
            CpuSecondsDelta = [math]::Round($cpuDelta, 3)
        }
    } | Sort-Object PrivateBytes -Descending | Select-Object -First 25)

$total = [int64]$system.TotalPhysicalBytes
$available = [int64]$system.AvailablePhysicalBytes
$result = [pscustomobject]@{
    TimestampUtc = [datetime]::UtcNow.ToString('o')
    Source = if ($InventoryPath) { 'fixture' } else { 'live' }
    SampleSeconds = $SampleSeconds
    MemoryAccounting = [pscustomobject]@{
        TotalPhysicalBytes = $total
        AvailablePhysicalBytes = $available
        UsedPhysicalBytes = $total - $available
        CommittedBytes = [int64]$system.CommittedBytes
        CommitLimitBytes = [int64]$system.CommitLimitBytes
        PoolPagedBytes = [int64]$system.PoolPagedBytes
        PoolNonpagedBytes = [int64]$system.PoolNonpagedBytes
        CacheBytes = [int64]$system.CacheBytes
        WorkingSetMeaning = 'physical pages currently resident for a process; shared pages can appear in multiple process working sets'
        PrivateBytesMeaning = 'process-specific committed virtual memory; it can be backed by RAM or the page file'
    }
    ProcessGroups = $processGroups
    CandidateCount = $candidates.Count
    Candidates = @($candidates)
    Safety = [pscustomobject]@{
        TerminationPerformed = $false
        CommandLinesCollected = $false
        EnvironmentValuesCollected = $false
        ActiveAgentTreesProtected = $true
        WindowsCoreProtected = $true
    }
}

if ($RevalidateCandidateId) {
    $match = @($candidates | Where-Object CandidateId -eq $RevalidateCandidateId)
    $result | Add-Member -NotePropertyName Revalidation -NotePropertyValue ([pscustomobject]@{
        CandidateId = $RevalidateCandidateId
        Valid = $match.Count -eq 1
        MatchCount = $match.Count
        Reason = if ($match.Count -eq 1) { 'immutable identity and classification match the fresh inventory' } else { 'candidate is absent, changed, ambiguous, or now protected' }
    })
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    $result
}
