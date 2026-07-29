$ErrorActionPreference = 'Stop'

$tool = Join-Path $PSScriptRoot 'Get-DeclogReport.ps1'
$tempRoot = Join-Path $env:TEMP ("declog-test-" + [Guid]::NewGuid().ToString('N'))
$fixturePath = Join-Path $tempRoot 'inventory.json'
$sid = 'S-1-5-21-111-222-333-1001'
$nodePath = 'C:\Program Files\nodejs\node.exe'

function New-Row {
    param(
        [int]$Id, [int]$Parent, [string]$Name, [string]$Path,
        [string]$Start = '2026-07-29T08:00:00Z',
        [int64]$WorkingSet = 104857600,
        [int64]$Private = 209715200,
        [double]$Cpu = 1
    )
    [ordered]@{
        ProcessId=$Id; ParentProcessId=$Parent; Name=$Name; ExecutablePath=$Path
        StartTimeUtc=$Start; OwnerSid=$sid; SessionId=1
        WorkingSetBytes=$WorkingSet; PrivateBytes=$Private; CpuSeconds=$Cpu
    }
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $rows = @(
        (New-Row 10 1 'ChatGPT.exe' 'C:\Program Files\WindowsApps\OpenAI.Codex\ChatGPT.exe'),
        (New-Row 11 10 'chrome.exe' 'C:\Users\dougl\AppData\Local\ms-playwright\chromium\chrome.exe'),
        (New-Row 100 999 'node.exe' $nodePath),
        (New-Row 101 100 'cmd.exe' 'C:\Windows\System32\cmd.exe'),
        (New-Row 102 101 'node.exe' $nodePath),
        (New-Row 200 998 'chrome.exe' 'C:\Users\dougl\AppData\Local\ms-playwright\chromium-1200\chrome-win\chrome.exe'),
        (New-Row 300 997 'python.exe' 'C:\Users\dougl\projects\app\.venv\Scripts\python.exe'),
        (New-Row 400 996 'msedgewebview2.exe' 'C:\Program Files (x86)\Microsoft\EdgeWebView\Application\msedgewebview2.exe'),
        (New-Row 500 995 'conhost.exe' 'C:\Windows\System32\conhost.exe'),
        (New-Row 600 994 'svchost.exe' 'C:\Windows\System32\svchost.exe'),
        (New-Row 700 701 'node.exe' $nodePath),
        (New-Row 701 700 'cmd.exe' 'C:\Windows\System32\cmd.exe')
    )
    $after = @($rows | ForEach-Object {
        $copy = [ordered]@{}
        foreach ($property in $_.GetEnumerator()) { $copy[$property.Key] = $property.Value }
        if ($copy.ProcessId -eq 200) {
            $copy.WorkingSetBytes = [int64]$copy.WorkingSetBytes + 10485760
            $copy.PrivateBytes = [int64]$copy.PrivateBytes + 20971520
            $copy.CpuSeconds = [double]$copy.CpuSeconds + 2
        }
        $copy
    })
    $fixture = [ordered]@{
        ReferenceTimeUtc='2026-07-29T12:00:00Z'
        System=[ordered]@{
            TotalPhysicalBytes=17179869184; AvailablePhysicalBytes=4294967296
            CommittedBytes=21474836480; CommitLimitBytes=34359738368
            PoolPagedBytes=805306368; PoolNonpagedBytes=1610612736; CacheBytes=1073741824
        }
        Processes=$rows
        ProcessesAfter=$after
    }
    [IO.File]::WriteAllText($fixturePath, ($fixture | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

    $report = & $tool -InventoryPath $fixturePath -MinimumAgeMinutes 60
    if ($report.Safety.TerminationPerformed) { throw 'Audit performed termination.' }
    if ($report.Safety.CommandLinesCollected) { throw 'Audit collected command lines.' }
    if ($report.CandidateCount -ne 5) { throw "Expected five candidates; found $($report.CandidateCount)." }
    if (@($report.Candidates | Where-Object ProcessId -eq 11).Count -ne 0) { throw 'Active ChatGPT descendant was surfaced.' }
    if (@($report.Candidates | Where-Object ProcessId -eq 600).Count -ne 0) { throw 'Windows core process was surfaced.' }

    $node = @($report.Candidates | Where-Object ProcessId -eq 100)
    if ($node.Classification -ne 'established-node-cleanup') { throw 'Exact node chain missed established cleanup class.' }
    $browser = @($report.Candidates | Where-Object ProcessId -eq 200)
    if ($browser.Type -ne 'detached-playwright-browser') { throw 'Playwright browser type was not detected.' }
    if ($browser.RootDelta.WorkingSetBytes -ne 10485760) { throw 'Working-set delta is incorrect.' }
    if ($browser.RootDelta.PrivateBytes -ne 20971520) { throw 'Private-byte delta is incorrect.' }
    if (@($report.Candidates | Where-Object Type -eq 'detached-python').Count -ne 1) { throw 'Python candidate missing.' }
    if (@($report.Candidates | Where-Object Type -eq 'detached-webview-or-electron').Count -ne 1) { throw 'WebView candidate missing.' }
    if (@($report.Candidates | Where-Object Type -eq 'detached-console-helper').Count -ne 1) { throw 'Console helper candidate missing.' }

    $revalidated = & $tool -InventoryPath $fixturePath -MinimumAgeMinutes 60 -RevalidateCandidateId $browser.CandidateId
    if (-not $revalidated.Revalidation.Valid) { throw 'Stable candidate failed revalidation.' }
    $invalid = & $tool -InventoryPath $fixturePath -MinimumAgeMinutes 60 -RevalidateCandidateId ('0' * 64)
    if ($invalid.Revalidation.Valid) { throw 'Unknown candidate passed revalidation.' }

    'Declog fixture tests passed: typed detection, active/core protection, deltas, dry-run safety, and revalidation.'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
