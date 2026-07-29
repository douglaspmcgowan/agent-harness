$ErrorActionPreference = 'Stop'

$generator = Join-Path $PSScriptRoot 'Convert-HumanGuide.ps1'
$root = Join-Path $env:TEMP ('human-guide-renderer-' + [Guid]::NewGuid().ToString('N'))

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $markdown = Join-Path $root 'README.md'
    $output = Join-Path $root 'README.html'
    $fixture = @'
# Fixture Guide

Last updated: 2026-07-29

**System contract:** [`SPEC.md`](../../SPEC.md) carries the contract.

## System map

```mermaid
flowchart TD
    A["Source <node>"] --> B["Target"]
```

| Kind | Evidence |
|---|---|
| Guide | **Bold**, `code`, and [link](https://example.com/path?q=1&mode=proof) |

- first item
- second item

1. ordered item

#### Detailed heading

Plain text with <placeholder> characters.
'@
    [System.IO.File]::WriteAllText($markdown, $fixture, [System.Text.UTF8Encoding]::new($false))

    $first = & $generator -MarkdownPath $markdown
    $second = & $generator -MarkdownPath $markdown
    Assert-True ($first -ceq $second) 'Human-guide rendering is not deterministic.'

    $sourceHash = (Get-FileHash -LiteralPath $markdown -Algorithm SHA256).Hash.ToLowerInvariant()
    foreach ($expected in @(
        "data-source-sha256=`"$sourceHash`"",
        'data-generator="Convert-HumanGuide.ps1:v1"',
        '<pre class="mermaid"><code>flowchart TD',
        'A[&quot;Source &lt;node&gt;&quot;] --&gt; B[&quot;Target&quot;]',
        '<table>',
        '<strong>Bold</strong>',
        '<code>code</code>',
        '<a href="https://example.com/path?q=1&amp;mode=proof">link</a>',
        '<ul>',
        '<ol>',
        '<h4 id="detailed-heading">Detailed heading</h4>',
        'Plain text with &lt;placeholder&gt; characters.'
    )) {
        Assert-True $first.Contains($expected) "Rendered guide omitted expected syntax: $expected"
    }

    & $generator -MarkdownPath $markdown -OutputPath $output | Out-Null
    Assert-True (Test-Path -LiteralPath $output -PathType Leaf) 'Generator did not write the requested HTML output.'
    Assert-True ([System.IO.File]::ReadAllText($output) -ceq $first) 'Written HTML differs from the in-memory render.'

    $harness = Join-Path $root 'harness'
    $harnessTools = Join-Path $harness 'tools'
    $harnessGuide = Join-Path $harness 'human-readable'
    New-Item -ItemType Directory -Path $harnessTools, $harnessGuide -Force | Out-Null
    Copy-Item -LiteralPath $generator -Destination (Join-Path $harnessTools 'Convert-HumanGuide.ps1')
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Manage-Harness.ps1') -Destination (Join-Path $harnessTools 'Manage-Harness.ps1')
    Copy-Item -LiteralPath $markdown -Destination (Join-Path $harnessGuide 'README.md')
    Copy-Item -LiteralPath $output -Destination (Join-Path $harnessGuide 'README.html')
    $provenance = [ordered]@{
        schemaVersion = 1
        files = @(
            [ordered]@{ path = 'README.md'; sha256 = (Get-FileHash -LiteralPath (Join-Path $harnessGuide 'README.md') -Algorithm SHA256).Hash.ToLowerInvariant() },
            [ordered]@{ path = 'README.html'; sha256 = (Get-FileHash -LiteralPath (Join-Path $harnessGuide 'README.html') -Algorithm SHA256).Hash.ToLowerInvariant() }
        )
    }
    [System.IO.File]::WriteAllText(
        (Join-Path $harnessGuide 'guide-provenance.json'),
        (($provenance | ConvertTo-Json -Depth 4) + "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
    $manager = Join-Path $harnessTools 'Manage-Harness.ps1'
    $verified = & $manager -Action VerifyHumanGuide -HarnessRoot $harness -HomeRoot (Join-Path $root 'home')
    Assert-True (
        $verified.result -eq 'Human guide deterministic render and authenticated HTML body passed.'
    ) 'Manage-Harness did not accept the canonical deterministic guide.'

    $installedHtml = Join-Path $harnessGuide 'README.html'
    $originalHtml = [System.IO.File]::ReadAllText($installedHtml)
    [System.IO.File]::WriteAllText(
        $installedHtml,
        $originalHtml.Replace($sourceHash, ('0' * 64)),
        [System.Text.UTF8Encoding]::new($false)
    )
    $staleMarkerRejected = $false
    try {
        & $manager -Action VerifyHumanGuide -HarnessRoot $harness -HomeRoot (Join-Path $root 'home') | Out-Null
    }
    catch {
        $staleMarkerRejected = $_.Exception.Message -match 'deterministic render'
    }
    Assert-True $staleMarkerRejected 'Manage-Harness accepted a stale Markdown source marker.'

    [System.IO.File]::WriteAllText(
        $installedHtml,
        "<html lang=`"en`" data-source-sha256=`"$sourceHash`" data-generator=`"Convert-HumanGuide.ps1:v1`"><body>Substituted body</body></html>`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $substitutedBodyRejected = $false
    try {
        & $manager -Action VerifyHumanGuide -HarnessRoot $harness -HomeRoot (Join-Path $root 'home') | Out-Null
    }
    catch {
        $substitutedBodyRejected = $_.Exception.Message -match 'deterministic render'
    }
    Assert-True $substitutedBodyRejected 'Manage-Harness accepted a substituted body carrying valid provenance markers.'

    $canonicalGuideRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'human-readable'
    $canonicalMarkdown = Join-Path $canonicalGuideRoot 'README.md'
    $canonicalHtml = Join-Path $canonicalGuideRoot 'README.html'
    $canonicalRender = & $generator -MarkdownPath $canonicalMarkdown
    Assert-True (
        [System.IO.File]::ReadAllText($canonicalHtml) -ceq $canonicalRender
    ) 'Checked-in README.html differs from the deterministic README.md render.'

    [System.IO.File]::WriteAllText(
        $markdown,
        "# Unsupported`n`n> block quote`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $unsupportedRejected = $false
    try {
        & $generator -MarkdownPath $markdown | Out-Null
    }
    catch {
        $unsupportedRejected = $_.Exception.Message -match 'Unsupported Markdown block'
    }
    Assert-True $unsupportedRejected 'Generator silently flattened an unsupported Markdown block.'

    Write-Output 'Convert-HumanGuide regression test passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
