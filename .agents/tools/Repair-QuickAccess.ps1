[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,
    [string]$UserRoot = $env:USERPROFILE,
    [int]$MaximumPins = 13
)

$ErrorActionPreference = 'Stop'

function Expand-PortablePath {
    param([string]$Path)
    $driveRoot = Join-Path $UserRoot 'My Drive'
    $expanded = $Path.Replace('%USERPROFILE%', $UserRoot).Replace('%GOOGLE_DRIVE_ROOT%', $driveRoot)
    foreach ($knownFolder in @('Desktop', 'Documents', 'Downloads', 'Pictures', 'Music', 'Videos')) {
        $retired = Join-Path $UserRoot ("OneDrive\" + $knownFolder)
        if ($expanded.StartsWith($retired, [StringComparison]::OrdinalIgnoreCase)) {
            return (Join-Path $UserRoot $knownFolder) + $expanded.Substring($retired.Length)
        }
    }
    return $expanded
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$allTargets = @($manifest.pinnedFolders | ForEach-Object {
    Expand-PortablePath -Path ([string]$_)
})
$priority = @(
    (Join-Path $UserRoot 'projects'),
    (Join-Path $UserRoot 'Desktop'),
    (Join-Path $UserRoot 'Documents'),
    (Join-Path $UserRoot 'Downloads'),
    (Join-Path $UserRoot 'Pictures'),
    (Join-Path $UserRoot 'My Drive'),
    (Join-Path $UserRoot 'My Drive\Actual Documents'),
    (Join-Path $UserRoot 'My Drive\UC Berkeley'),
    (Join-Path $UserRoot 'My Drive\UC Berkeley\Research\Claude Research Folder'),
    (Join-Path $UserRoot 'My Drive\UC Berkeley\Research\Codex Research Folder'),
    (Join-Path $UserRoot 'My Drive\UC Berkeley\Research\Gemini Research Folder'),
    (Join-Path $UserRoot 'My Drive\UC Berkeley\Research\dfm_scraping'),
    (Join-Path $UserRoot 'Documents\Sound Recordings')
)
$targets = @($allTargets | Sort-Object {
    $index = [Array]::IndexOf($priority, $_)
    if ($index -ge 0) { $index } else { 1000 }
}, { $_ } | Select-Object -First $MaximumPins)

if ($WhatIfPreference) {
    $targets | ForEach-Object {
        [pscustomobject]@{ Action = 'Pin'; Path = $_ }
    }
    return
}

$shell = New-Object -ComObject Shell.Application
$quickAccess = $shell.Namespace('shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}')
if (-not $quickAccess) { throw 'File Explorer Quick Access is unavailable.' }

@($quickAccess.Items() | Where-Object {
    $_.IsFolder -and $_.ExtendedProperty('System.Home.IsPinned') -and
    (($_.Path.StartsWith((Join-Path $UserRoot 'OneDrive'), [StringComparison]::OrdinalIgnoreCase) -or
      $_.Path.StartsWith('G:\My Drive', [StringComparison]::OrdinalIgnoreCase)) -or
     (($allTargets -contains $_.Path) -and ($targets -notcontains $_.Path)))
}) | ForEach-Object {
    if ($PSCmdlet.ShouldProcess($_.Path, 'Unpin stale Quick Access folder')) {
        $_.InvokeVerb('unpinfromhome')
    }
}

$currentPins = @($quickAccess.Items() | Where-Object {
    $_.IsFolder -and $_.ExtendedProperty('System.Home.IsPinned')
} | ForEach-Object { $_.Path })
foreach ($target in $targets) {
    if (-not (Test-Path -LiteralPath $target -PathType Container)) {
        Write-Warning "Quick Access target is unavailable: $target"
        continue
    }
    if ($currentPins -contains $target) { continue }
    if ($PSCmdlet.ShouldProcess($target, 'Pin Quick Access folder')) {
        $folder = $shell.Namespace($target)
        if (-not $folder) { throw "File Explorer could not resolve: $target" }
        $folder.Self.InvokeVerb('pintohome')
        $currentPins += $target
        Start-Sleep -Milliseconds 150
    }
}

[pscustomobject]@{
    ManifestPath = $ManifestPath
    RequestedPins = $targets.Count
}
