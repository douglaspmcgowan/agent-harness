[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repository,

    [string]$CurrentTaskName = 'CURRENT-TASK.md',

    [string]$WorkQueueName = 'WORK_QUEUE.md',

    [string]$VerifyName = 'VERIFY.md',

    [string]$TargetName = 'TASK.md',

    [string]$LogName = 'LOG.md'
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path -LiteralPath $Repository).Path
$currentPath = Join-Path $repo $CurrentTaskName
$queuePath = Join-Path $repo $WorkQueueName
$verifyPath = Join-Path $repo $VerifyName
$targetPath = Join-Path $repo $TargetName
$logPath = Join-Path $repo $LogName
$archiveDir = Join-Path $repo '.agents\archive\task-state-migration'
$migrationMarker = 'Task state consolidated into TASK.md; legacy task and verification sources retained under .agents/archive/task-state-migration.'

function Read-Utf8File {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return [System.IO.File]::ReadAllText($Path)
    }
    return ''
}

function Section-Text {
    param(
        [string]$Content,
        [string]$Heading
    )
    $pattern = "(?ms)^##\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ''
}

function Plain-SectionItems {
    param(
        [string]$Content,
        [string]$Heading
    )
    $section = Section-Text -Content $Content -Heading $Heading
    $items = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($section -split '\r?\n')) {
        $match = [regex]::Match($line, '^\s*(?:[-*+]|\d+[.)])\s+(.+?)\s*$')
        if (-not $match.Success) { continue }
        $text = [regex]::Replace($match.Groups[1].Value.Trim(), '^\[[ ~xX!?]\]\s*', '')
        if ($text) { $items.Add($text) }
    }
    return $items
}

function Checkbox-Items {
    param([string]$Content)
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($line in ($Content -split '\r?\n')) {
        $match = [regex]::Match($line, '^\s*(?:[-*+]|\d+[.)])\s*\[([ ~xX!?])\]\s*(.+?)\s*$')
        if ($match.Success) {
            $items.Add([pscustomobject]@{
                Status = $match.Groups[1].Value.ToLowerInvariant()
                Text = $match.Groups[2].Value.Trim()
            })
        }
    }
    return $items
}

function Normalize-Task {
    param([string]$Text)
    return ([regex]::Replace($Text.Trim(), '\s+', ' ')).ToLowerInvariant()
}

function Ensure-MigrationLog {
    $existing = Read-Utf8File $logPath
    if ($existing.Contains($migrationMarker)) { return }
    $entry = "$(Get-Date -Format 'yyyy-MM-dd') | $migrationMarker"
    if ($PSCmdlet.ShouldProcess($logPath, 'Append task-state migration record')) {
        $prefix = if ($existing -and -not $existing.EndsWith("`n")) { "`r`n" } else { '' }
        [System.IO.File]::AppendAllText($logPath, "$prefix$entry`r`n", [System.Text.UTF8Encoding]::new($false))
    }
}

function Preserve-Source {
    param([string]$Source)
    if (-not (Test-Path -LiteralPath $Source)) { return $null }
    if ($PSCmdlet.ShouldProcess($archiveDir, "Preserve $([System.IO.Path]::GetFileName($Source))")) {
        if (-not (Test-Path -LiteralPath $archiveDir)) {
            New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
        }
        $archivePath = Join-Path $archiveDir ([System.IO.Path]::GetFileName($Source))
        $sourceContent = [System.IO.File]::ReadAllText($Source)
        if (Test-Path -LiteralPath $archivePath) {
            if ([System.IO.File]::ReadAllText($archivePath) -cne $sourceContent) {
                throw "Archive collision with different content: $archivePath"
            }
        }
        else {
            [System.IO.File]::WriteAllText($archivePath, $sourceContent, [System.Text.UTF8Encoding]::new($false))
        }
        if ([System.IO.File]::ReadAllText($archivePath) -cne $sourceContent) {
            throw "Archive verification failed: $archivePath"
        }
        return $archivePath
    }
    return $null
}

function Remove-PreservedSource {
    param([string]$Source)
    if (-not (Test-Path -LiteralPath $Source)) { return }
    $archivePath = Join-Path $archiveDir ([System.IO.Path]::GetFileName($Source))
    if (-not (Test-Path -LiteralPath $archivePath)) {
        throw "Refusing to remove a source without its archive: $Source"
    }
    if ([System.IO.File]::ReadAllText($archivePath) -cne [System.IO.File]::ReadAllText($Source)) {
        throw "Refusing to remove a source whose archive differs: $Source"
    }
    if ($PSCmdlet.ShouldProcess($Source, 'Remove verified legacy source after migration')) {
        Remove-Item -LiteralPath $Source -Force
    }
}

$hasCurrent = Test-Path -LiteralPath $currentPath
$hasQueue = Test-Path -LiteralPath $queuePath

# Idempotent recovery after a completed migration, including cleanup of a late-restored VERIFY.md.
if (-not $hasCurrent -and -not $hasQueue) {
    if (-not (Test-Path -LiteralPath $targetPath) -or -not (Test-Path -LiteralPath $archiveDir)) {
        throw "Neither $CurrentTaskName nor $WorkQueueName exists, and no completed migration was found under $repo."
    }
    if (Test-Path -LiteralPath $verifyPath) {
        Preserve-Source $verifyPath | Out-Null
    }
    Ensure-MigrationLog
    if (-not (Read-Utf8File $logPath).Contains($migrationMarker)) {
        throw 'Migration log verification failed.'
    }
    Remove-PreservedSource $verifyPath
    [pscustomobject]@{
        Target = $targetPath
        Archive = $archiveDir
        AlreadyMigrated = $true
        LegacyRootFilesPresent = [bool](
            (Test-Path -LiteralPath $currentPath) -or
            (Test-Path -LiteralPath $queuePath) -or
            (Test-Path -LiteralPath $verifyPath)
        )
    }
    return
}

$archivedCurrentPath = Join-Path $archiveDir $CurrentTaskName
$archivedQueuePath = Join-Path $archiveDir $WorkQueueName
$archivedVerifyPath = Join-Path $archiveDir $VerifyName
$current = if ($hasCurrent) { Read-Utf8File $currentPath } else { Read-Utf8File $archivedCurrentPath }
$queue = if ($hasQueue) { Read-Utf8File $queuePath } else { Read-Utf8File $archivedQueuePath }
$goal = Section-Text -Content $current -Heading 'Goal'
$verifier = Section-Text -Content $current -Heading 'Next verifier'
$hasVerify = (Test-Path -LiteralPath $verifyPath) -or (Test-Path -LiteralPath $archivedVerifyPath)

$open = [ordered]@{}
$currentCompleted = [System.Collections.Generic.List[string]]::new()
$historicalCompleted = [System.Collections.Generic.List[string]]::new()

foreach ($text in (Plain-SectionItems -Content $current -Heading 'Completed')) {
    $currentCompleted.Add($text)
}
foreach ($text in (Plain-SectionItems -Content $current -Heading 'Remaining')) {
    $open[(Normalize-Task $text)] = [pscustomobject]@{ Status = ' '; Text = $text }
}

foreach ($item in (Checkbox-Items -Content $queue)) {
    if ($item.Status -eq 'x') {
        $historicalCompleted.Add($item.Text)
    }
    else {
        $open[(Normalize-Task $item.Text)] = $item
    }
}

$active = [System.Collections.Generic.List[string]]::new()
$queued = [System.Collections.Generic.List[string]]::new()
$blocked = [System.Collections.Generic.List[string]]::new()
$decision = [System.Collections.Generic.List[string]]::new()
foreach ($item in $open.Values) {
    switch ($item.Status) {
        '~' { $active.Add($item.Text) }
        '!' { $blocked.Add($item.Text) }
        '?' { $decision.Add($item.Text) }
        default { $queued.Add($item.Text) }
    }
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Task')
$lines.Add('')
$lines.Add('## Goal')
$lines.Add('')
$lines.Add($(if ($goal) { $goal } else { 'Record the active outcome.' }))
$lines.Add('')
$lines.Add('## Active')
$lines.Add('')
foreach ($item in $active) { $lines.Add("- [~] $item") }
$lines.Add('')
$lines.Add('## Queue')
$lines.Add('')
foreach ($item in $queued) { $lines.Add("- [ ] $item") }
$lines.Add('')
$lines.Add('## Blocked')
$lines.Add('')
foreach ($item in $blocked) { $lines.Add("- [!] $item") }
$lines.Add('')
$lines.Add('## Needs decision')
$lines.Add('')
foreach ($item in $decision) { $lines.Add("- [?] $item") }
$lines.Add('')
$lines.Add('## Completed')
$lines.Add('')
foreach ($item in $currentCompleted) { $lines.Add("- [x] $item") }
$lines.Add('')
$lines.Add('## Verification')
$lines.Add('')
if ($verifier) {
    $lines.Add("- Next: $verifier")
}
elseif (-not $hasVerify) {
    $lines.Add('- Next: record the exact command or observable proof.')
}
if ($hasVerify) {
    $lines.Add('- Reference: `.agents/archive/task-state-migration/VERIFY.md`')
}
$lines.Add('')
$lines.Add('<!-- Migrated deterministically. Legacy task and verification files were archived before removal. -->')
$lines.Add('')
$generated = $lines -join "`r`n"

foreach ($source in @($currentPath, $queuePath, $verifyPath)) {
    Preserve-Source $source | Out-Null
}

if (Test-Path -LiteralPath $targetPath) {
    if ([System.IO.File]::ReadAllText($targetPath) -cne $generated) {
        throw "Refusing to overwrite a divergent $targetPath. Move or reconcile it before rerunning."
    }
}
elseif ($PSCmdlet.ShouldProcess($targetPath, "Create $TargetName from legacy task state")) {
    [System.IO.File]::WriteAllText($targetPath, $generated, [System.Text.UTF8Encoding]::new($false))
}

Ensure-MigrationLog

if (-not (Test-Path -LiteralPath $targetPath) -or [System.IO.File]::ReadAllText($targetPath) -cne $generated) {
    throw 'TASK.md verification failed; legacy sources remain in place.'
}
if (-not (Read-Utf8File $logPath).Contains($migrationMarker)) {
    throw 'Migration log verification failed; legacy sources remain in place.'
}

foreach ($source in @($currentPath, $queuePath, $verifyPath)) {
    Remove-PreservedSource $source
}

$legacyPresent = [bool](
    (Test-Path -LiteralPath $currentPath) -or
    (Test-Path -LiteralPath $queuePath) -or
    (Test-Path -LiteralPath $verifyPath)
)

[pscustomobject]@{
    Target = $targetPath
    Active = $active.Count
    Queue = $queued.Count
    Blocked = $blocked.Count
    NeedsDecision = $decision.Count
    CurrentCompleted = $currentCompleted.Count
    HistoricalCompletedArchived = $historicalCompleted.Count
    Archive = $archiveDir
    SourceFilesRetained = $false
    LegacyRootFilesPresent = $legacyPresent
}
