[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'Sync-AgentRepositories.ps1'
if (-not (Test-Path -LiteralPath $script -PathType Leaf)) {
    throw "Repository sync tool is missing: $script"
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-BareFixture {
    param([string]$Root, [string]$Name)
    $seed = Join-Path $Root ($Name + '-seed')
    $bare = Join-Path $Root ($Name + '.git')
    New-Item -ItemType Directory -Path $seed | Out-Null
    git -C $seed init -b master | Out-Null
    git -C $seed config user.email 'sync-test@example.invalid'
    git -C $seed config user.name 'Sync Test'
    [System.IO.File]::WriteAllText((Join-Path $seed 'README.md'), "# $Name`n")
    git -C $seed add README.md
    git -C $seed commit -m 'initial' | Out-Null
    git init --bare $bare | Out-Null
    git -C $seed remote add origin $bare
    git -C $seed push -u origin master | Out-Null
    git --git-dir $bare symbolic-ref HEAD refs/heads/master
    [pscustomobject]@{ Seed = $seed; Bare = $bare }
}

$root = Join-Path $env:TEMP ('sync-agent-repositories-' + [Guid]::NewGuid().ToString('N'))
try {
    $projects = Join-Path $root 'projects'
    New-Item -ItemType Directory -Path $projects -Force | Out-Null

    $missing = New-BareFixture -Root $root -Name 'missing'
    $clean = New-BareFixture -Root $root -Name 'clean'
    $dirty = New-BareFixture -Root $root -Name 'dirty'
    $wrong = New-BareFixture -Root $root -Name 'wrong'
    $other = New-BareFixture -Root $root -Name 'other'
    $plain = New-BareFixture -Root $root -Name 'plain'
    $ahead = New-BareFixture -Root $root -Name 'ahead'
    $diverged = New-BareFixture -Root $root -Name 'diverged'

    git clone $clean.Bare (Join-Path $projects 'clean') | Out-Null
    git clone $dirty.Bare (Join-Path $projects 'dirty') | Out-Null
    git clone $other.Bare (Join-Path $projects 'wrong') | Out-Null
    git clone $ahead.Bare (Join-Path $projects 'ahead') | Out-Null
    git clone $diverged.Bare (Join-Path $projects 'diverged') | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $projects 'plain') | Out-Null

    foreach ($name in @('ahead', 'diverged')) {
        git -C (Join-Path $projects $name) config user.email 'sync-test@example.invalid'
        git -C (Join-Path $projects $name) config user.name 'Sync Test'
        [System.IO.File]::WriteAllText((Join-Path $projects "$name\local.txt"), "local`n")
        git -C (Join-Path $projects $name) add local.txt
        git -C (Join-Path $projects $name) commit -m 'local commit' | Out-Null
    }
    [System.IO.File]::WriteAllText((Join-Path $diverged.Seed 'remote.txt'), "remote`n")
    git -C $diverged.Seed add remote.txt
    git -C $diverged.Seed commit -m 'remote commit' | Out-Null
    git -C $diverged.Seed push | Out-Null

    [System.IO.File]::AppendAllText((Join-Path $clean.Seed 'README.md'), "remote update`n")
    git -C $clean.Seed add README.md
    git -C $clean.Seed commit -m 'remote update' | Out-Null
    git -C $clean.Seed push | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $projects 'dirty\local.txt'), "uncommitted`n")

    $catalog = @(
        [ordered]@{ name = 'missing'; nameWithOwner = 'fixture/missing'; url = $missing.Bare; defaultBranchRef = @{ name = 'master' } },
        [ordered]@{ name = 'clean'; nameWithOwner = 'fixture/clean'; url = $clean.Bare; defaultBranchRef = @{ name = 'master' } },
        [ordered]@{ name = 'dirty'; nameWithOwner = 'fixture/dirty'; url = $dirty.Bare; defaultBranchRef = @{ name = 'master' } },
        [ordered]@{ name = 'wrong'; nameWithOwner = 'fixture/wrong'; url = $wrong.Bare; defaultBranchRef = @{ name = 'master' } },
        [ordered]@{ name = 'plain'; nameWithOwner = 'fixture/plain'; url = $plain.Bare; defaultBranchRef = @{ name = 'master' } },
        [ordered]@{ name = 'ahead'; nameWithOwner = 'fixture/ahead'; url = $ahead.Bare; defaultBranchRef = @{ name = 'master' } },
        [ordered]@{ name = 'diverged'; nameWithOwner = 'fixture/diverged'; url = $diverged.Bare; defaultBranchRef = @{ name = 'master' } }
    )
    $catalogPath = Join-Path $root 'catalog.json'
    [System.IO.File]::WriteAllText(
        $catalogPath,
        ($catalog | ConvertTo-Json -Depth 5),
        [System.Text.UTF8Encoding]::new($false)
    )

    $dryRun = @(& $script -ProjectsRoot $projects -RepositoryJsonPath $catalogPath)
    Assert-True (($dryRun | Where-Object Name -eq 'missing').Action -eq 'clone') 'Missing repository was not planned for clone.'
    Assert-True (($dryRun | Where-Object Name -eq 'clean').Action -eq 'pull') 'Clean repository was not planned for pull.'
    Assert-True (($dryRun | Where-Object Name -eq 'dirty').Action -eq 'attention') 'Dirty repository was not protected.'
    Assert-True (($dryRun | Where-Object Name -eq 'wrong').Reason -eq 'origin-mismatch') 'Wrong origin was not detected.'
    Assert-True (($dryRun | Where-Object Name -eq 'plain').Reason -eq 'target-is-not-repository') 'Non-repository collision was not detected.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $projects 'missing'))) 'Dry-run created a repository.'

    $applied = @(& $script -ProjectsRoot $projects -RepositoryJsonPath $catalogPath -Apply)
    Assert-True (Test-Path -LiteralPath (Join-Path $projects 'missing\.git')) 'Apply did not clone the missing repository.'
    $remoteHead = (git -C $clean.Seed rev-parse HEAD).Trim()
    $localHead = (git -C (Join-Path $projects 'clean') rev-parse HEAD).Trim()
    Assert-True ($localHead -eq $remoteHead) 'Apply did not fast-forward the clean repository.'
    Assert-True (Test-Path -LiteralPath (Join-Path $projects 'dirty\local.txt')) 'Apply overwrote dirty work.'
    Assert-True (($applied | Where-Object Name -eq 'dirty').Applied -eq $false) 'Dirty repository was marked applied.'
    Assert-True (($applied | Where-Object Name -eq 'ahead').Reason -eq 'local-ahead-or-diverged') 'Local-ahead repository was not protected.'
    Assert-True (($applied | Where-Object Name -eq 'diverged').Reason -eq 'pull-not-fast-forward') 'Diverged repository was not protected.'

    $names = @($applied | ForEach-Object Name)
    Assert-True (($names -join ',') -eq 'ahead,clean,dirty,diverged,missing,plain,wrong') 'Results are not deterministic by repository name.'

    $unsafeCatalogPath = Join-Path $root 'unsafe-catalog.json'
    [System.IO.File]::WriteAllText(
        $unsafeCatalogPath,
        (@([ordered]@{ name = '..\escape'; nameWithOwner = 'fixture/escape'; url = $missing.Bare; defaultBranchRef = @{ name = 'master' } }) | ConvertTo-Json -Depth 5),
        [System.Text.UTF8Encoding]::new($false)
    )
    $unsafeRejected = $false
    try {
        & $script -ProjectsRoot $projects -RepositoryJsonPath $unsafeCatalogPath | Out-Null
    }
    catch {
        $unsafeRejected = $_.Exception.Message -like 'Unsafe repository name*'
    }
    Assert-True $unsafeRejected 'Unsafe repository name was not rejected.'

    $reservedCatalogPath = Join-Path $root 'reserved-catalog.json'
    [System.IO.File]::WriteAllText(
        $reservedCatalogPath,
        (@([ordered]@{ name = 'CON'; nameWithOwner = 'fixture/CON'; url = $missing.Bare; defaultBranchRef = @{ name = 'master' } }) | ConvertTo-Json -Depth 5),
        [System.Text.UTF8Encoding]::new($false)
    )
    $reservedRejected = $false
    try {
        & $script -ProjectsRoot $projects -RepositoryJsonPath $reservedCatalogPath | Out-Null
    }
    catch {
        $reservedRejected = $_.Exception.Message -like 'Unsafe repository name*'
    }
    Assert-True $reservedRejected 'Windows reserved repository name was not rejected.'

    $sshMatchPath = Join-Path $projects 'ssh-match'
    git clone $missing.Bare $sshMatchPath | Out-Null
    git -C $sshMatchPath remote set-url origin 'git@github.com:fixture/ssh-match.git'
    $sshCatalogPath = Join-Path $root 'ssh-catalog.json'
    [System.IO.File]::WriteAllText(
        $sshCatalogPath,
        (@([ordered]@{
            name = 'ssh-match'
            nameWithOwner = 'fixture/ssh-match'
            url = 'https://github.com/fixture/ssh-match.git'
            defaultBranchRef = @{ name = 'master' }
        }) | ConvertTo-Json -Depth 5),
        [System.Text.UTF8Encoding]::new($false)
    )
    $sshDryRun = @(& $script -ProjectsRoot $projects -RepositoryJsonPath $sshCatalogPath)
    Assert-True (($sshDryRun | Select-Object -First 1).Action -eq 'pull') 'Equivalent GitHub SSH and HTTPS origins were treated as different repositories.'

    [pscustomobject]@{
        Result = 'PASS'
        Clone = $true
        Pull = $true
        DirtyProtected = $true
        WrongOriginProtected = $true
        CollisionProtected = $true
        AheadProtected = $true
        DivergedProtected = $true
        UnsafeNameRejected = $true
        ReservedNameRejected = $true
        EquivalentGitHubOrigins = $true
    }
}
finally {
    if (Test-Path -LiteralPath $root) {
        $resolved = [System.IO.Path]::GetFullPath($root)
        if ($resolved.StartsWith([System.IO.Path]::GetTempPath(), [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
