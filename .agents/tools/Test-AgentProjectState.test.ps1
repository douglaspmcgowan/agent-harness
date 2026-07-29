$ErrorActionPreference = 'Stop'

$harnessRoot = Split-Path $PSScriptRoot -Parent
$ensure = Join-Path $PSScriptRoot 'Ensure-AgentProject.ps1'
$verifier = Join-Path $PSScriptRoot 'Test-AgentProjectState.ps1'
$testId = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$root = Join-Path $env:TEMP "taps-$testId"
$repo = Join-Path $root 'repo'
$testHome = Join-Path $env:TEMP "taph-$testId"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Invoke-Verifier {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = 'powershell.exe'
    $startInfo.Arguments = @(
        '-NoProfile',
        '-ExecutionPolicy Bypass',
        "-File `"$verifier`"",
        "-Repository `"$repo`"",
        "-HarnessRoot `"$harnessRoot`"",
        "-HomeRoot `"$testHome`""
    ) -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return @{
        ExitCode = $process.ExitCode
        Output = ($stdout + $stderr)
    }
}

try {
    New-Item -ItemType Directory -Path $repo, $testHome -Force | Out-Null
    & git.exe -c init.templateDir= -C $repo init --quiet
    if ($LASTEXITCODE -ne 0) { throw 'Failed to initialize the project-state test repository.' }

    & $ensure `
        -Repository $repo `
        -ProjectName 'repo' `
        -HarnessRoot $harnessRoot `
        -HomeRoot $testHome | Out-Null

    $valid = Invoke-Verifier
    Assert-True ($valid.ExitCode -eq 0) "Fresh v3 project failed verification:`n$($valid.Output)"

    $taskPath = Join-Path $repo 'TASK.md'
    $validTask = [System.IO.File]::ReadAllText($taskPath)
    [System.IO.File]::AppendAllText($taskPath, "`r`n## Answers`r`n`r`nDuplicate answer ledger.`r`n")
    $answersSection = Invoke-Verifier
    Assert-True ($answersSection.ExitCode -ne 0) 'TASK.md with an Answers section unexpectedly passed verification.'
    Assert-True ($answersSection.Output -match 'Answers section') "Forbidden Answers section was not reported:`n$($answersSection.Output)"
    [System.IO.File]::WriteAllText($taskPath, $validTask, [System.Text.UTF8Encoding]::new($false))

    Remove-Item -LiteralPath $taskPath -Force
    $missingTask = Invoke-Verifier
    Assert-True ($missingTask.ExitCode -ne 0) 'Project without TASK.md unexpectedly passed verification.'
    Assert-True ($missingTask.Output -match 'Missing project file: TASK\.md') "Missing TASK.md was not reported:`n$($missingTask.Output)"

    Write-Output 'Test-AgentProjectState tests passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
    if (Test-Path -LiteralPath $testHome) {
        Remove-Item -LiteralPath $testHome -Recurse -Force
    }
}
