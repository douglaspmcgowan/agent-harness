[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$MarkdownPath,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$generatorIdentity = 'Convert-HumanGuide.ps1:v1'

function Get-Sha256File([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Convert-HtmlText([string]$Text) {
    return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Convert-MarkdownPlainText([string]$Text) {
    $plain = [regex]::Replace($Text, '\[([^\]]+)\]\([^)]+\)', '$1')
    $plain = [regex]::Replace($plain, '`([^`]+)`', '$1')
    return $plain.Replace('**', '')
}

function Convert-InlineMarkdown([string]$Text) {
    $rendered = [System.Text.StringBuilder]::new()
    $index = 0
    while ($index -lt $Text.Length) {
        if ($Text[$index] -eq '`') {
            $closing = $Text.IndexOf('`', $index + 1)
            if ($closing -lt 0) {
                throw "Unsupported Markdown inline construct: unclosed code span in '$Text'."
            }
            $code = $Text.Substring($index + 1, $closing - $index - 1)
            [void]$rendered.Append('<code>')
            [void]$rendered.Append((Convert-HtmlText $code))
            [void]$rendered.Append('</code>')
            $index = $closing + 1
            continue
        }

        if ($index + 1 -lt $Text.Length -and $Text.Substring($index, 2) -eq '**') {
            $closing = $Text.IndexOf('**', $index + 2, [StringComparison]::Ordinal)
            if ($closing -lt 0) {
                throw "Unsupported Markdown inline construct: unclosed strong emphasis in '$Text'."
            }
            $strong = $Text.Substring($index + 2, $closing - $index - 2)
            [void]$rendered.Append('<strong>')
            [void]$rendered.Append((Convert-InlineMarkdown $strong))
            [void]$rendered.Append('</strong>')
            $index = $closing + 2
            continue
        }

        if ($Text[$index] -eq '!' -and $index + 1 -lt $Text.Length -and $Text[$index + 1] -eq '[') {
            throw "Unsupported Markdown inline construct: images are not supported in '$Text'."
        }

        if ($Text[$index] -eq '[') {
            $remaining = $Text.Substring($index)
            $link = [regex]::Match($remaining, '^\[(?<label>[^\]\r\n]+)\]\((?<url>[^)\r\n]+)\)')
            if ($link.Success) {
                $url = $link.Groups['url'].Value
                if ($url -notmatch '^(?:https?://|\.\.?/|#)' -or $url -match '[\x00-\x20]') {
                    throw "Unsupported Markdown link target: '$url'."
                }
                [void]$rendered.Append('<a href="')
                [void]$rendered.Append((Convert-HtmlText $url))
                [void]$rendered.Append('">')
                [void]$rendered.Append((Convert-InlineMarkdown $link.Groups['label'].Value))
                [void]$rendered.Append('</a>')
                $index += $link.Length
                continue
            }
        }

        [void]$rendered.Append((Convert-HtmlText ([string]$Text[$index])))
        $index++
    }
    return $rendered.ToString()
}

function Get-HeadingId([string]$Text, [hashtable]$Seen) {
    $plain = Convert-MarkdownPlainText $Text
    $slug = [regex]::Replace($plain.ToLowerInvariant(), '[^\p{L}\p{Nd}]+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Heading cannot produce a stable HTML id: '$Text'."
    }
    if ($Seen.ContainsKey($slug)) {
        $Seen[$slug]++
        return "$slug-$($Seen[$slug])"
    }
    $Seen[$slug] = 1
    return $slug
}

function Test-UnsupportedBlock([string]$Line, [int]$LineNumber) {
    if ($Line -match '^\s+' -or
        $Line -match '^>' -or
        $Line -match '^(?:---+|\*\s*\*\s*\*+|___+)\s*$' -or
        $Line -match '^<[/!?A-Za-z]') {
        throw "Unsupported Markdown block at line $LineNumber`: $Line"
    }
}

function Split-TableRow([string]$Line) {
    $trimmed = $Line.Trim()
    if (-not ($trimmed.StartsWith('|') -and $trimmed.EndsWith('|'))) {
        throw "Unsupported Markdown table row: $Line"
    }
    return @($trimmed.Substring(1, $trimmed.Length - 2).Split('|') | ForEach-Object { $_.Trim() })
}

function Convert-MarkdownDocument([string]$Path) {
    $fullPath = (Resolve-Path -LiteralPath $Path).Path
    $source = [System.IO.File]::ReadAllText($fullPath)
    $normalized = $source.Replace("`r`n", "`n").Replace("`r", "`n")
    $lines = [regex]::Split($normalized, "`n")
    $sourceHash = Get-Sha256File $fullPath
    $headingIds = @{}
    $body = [System.Collections.Generic.List[string]]::new()
    $title = 'Human Guide'
    $index = 0

    while ($index -lt $lines.Count) {
        $line = $lines[$index]
        $lineNumber = $index + 1
        if ([string]::IsNullOrWhiteSpace($line)) {
            $index++
            continue
        }

        $fence = [regex]::Match($line, '^```(?<language>[A-Za-z0-9_-]*)\s*$')
        if ($fence.Success) {
            $language = $fence.Groups['language'].Value
            if ($language -notin @('', 'mermaid')) {
                throw "Unsupported Markdown block at line $lineNumber`: fenced language '$language'."
            }
            $codeLines = [System.Collections.Generic.List[string]]::new()
            $index++
            while ($index -lt $lines.Count -and $lines[$index] -notmatch '^```\s*$') {
                $codeLines.Add($lines[$index])
                $index++
            }
            if ($index -ge $lines.Count) {
                throw "Unsupported Markdown block at line $lineNumber`: unclosed fenced code block."
            }
            $class = if ($language -eq 'mermaid') { ' class="mermaid"' } else { '' }
            $code = ($codeLines -join "`n")
            $body.Add("<pre$class><code>$(Convert-HtmlText $code)</code></pre>")
            $index++
            continue
        }

        $heading = [regex]::Match($line, '^(?<marks>#{1,6})\s+(?<text>.+?)\s*$')
        if ($heading.Success) {
            $level = $heading.Groups['marks'].Value.Length
            $headingText = $heading.Groups['text'].Value
            if ($level -eq 1 -and $title -eq 'Human Guide') {
                $title = Convert-MarkdownPlainText $headingText
            }
            $id = Get-HeadingId $headingText $headingIds
            $body.Add("<h$level id=`"$id`">$(Convert-InlineMarkdown $headingText)</h$level>")
            $index++
            continue
        }

        if ($line -match '^\|.*\|\s*$') {
            if ($index + 1 -ge $lines.Count -or $lines[$index + 1] -notmatch '^\|.*\|\s*$') {
                throw "Unsupported Markdown block at line $lineNumber`: table header lacks a divider."
            }
            $header = Split-TableRow $line
            $divider = Split-TableRow $lines[$index + 1]
            if ($header.Count -ne $divider.Count -or
                @($divider | Where-Object { $_ -notmatch '^:?-{3,}:?$' }).Count -gt 0) {
                throw "Unsupported Markdown block at line $lineNumber`: invalid table divider."
            }
            $body.Add('<table>')
            $body.Add('  <thead>')
            $body.Add('    <tr>')
            foreach ($cell in $header) {
                $body.Add("      <th>$(Convert-InlineMarkdown $cell)</th>")
            }
            $body.Add('    </tr>')
            $body.Add('  </thead>')
            $body.Add('  <tbody>')
            $index += 2
            while ($index -lt $lines.Count -and $lines[$index] -match '^\|.*\|\s*$') {
                $cells = Split-TableRow $lines[$index]
                if ($cells.Count -ne $header.Count) {
                    throw "Unsupported Markdown block at line $($index + 1): table column count changed."
                }
                $body.Add('    <tr>')
                foreach ($cell in $cells) {
                    $body.Add("      <td>$(Convert-InlineMarkdown $cell)</td>")
                }
                $body.Add('    </tr>')
                $index++
            }
            $body.Add('  </tbody>')
            $body.Add('</table>')
            continue
        }

        $listItem = [regex]::Match($line, '^(?<indent>\s*)(?<marker>[-+*]|\d+\.)\s+(?<text>.+)$')
        if ($listItem.Success) {
            if ($listItem.Groups['indent'].Value.Length -gt 0) {
                throw "Unsupported Markdown block at line $lineNumber`: nested lists are not supported."
            }
            $ordered = $listItem.Groups['marker'].Value -match '^\d+\.$'
            $tag = if ($ordered) { 'ol' } else { 'ul' }
            $body.Add("<$tag>")
            while ($index -lt $lines.Count) {
                $candidate = [regex]::Match($lines[$index], '^(?<indent>\s*)(?<marker>[-+*]|\d+\.)\s+(?<text>.+)$')
                if (-not $candidate.Success -or $candidate.Groups['indent'].Value.Length -gt 0) {
                    break
                }
                $candidateOrdered = $candidate.Groups['marker'].Value -match '^\d+\.$'
                if ($candidateOrdered -ne $ordered) {
                    break
                }
                $body.Add("  <li>$(Convert-InlineMarkdown $candidate.Groups['text'].Value)</li>")
                $index++
            }
            $body.Add("</$tag>")
            continue
        }

        Test-UnsupportedBlock $line $lineNumber
        $paragraphLines = [System.Collections.Generic.List[string]]::new()
        while ($index -lt $lines.Count -and -not [string]::IsNullOrWhiteSpace($lines[$index])) {
            $candidate = $lines[$index]
            if ($paragraphLines.Count -gt 0 -and
                ($candidate -match '^#{1,6}\s+' -or
                 $candidate -match '^```' -or
                 $candidate -match '^\|.*\|\s*$' -or
                 $candidate -match '^(?:[-+*]|\d+\.)\s+')) {
                break
            }
            Test-UnsupportedBlock $candidate ($index + 1)
            $paragraphLines.Add($candidate.Trim())
            $index++
        }
        $paragraph = $paragraphLines -join ' '
        $class = if ($paragraph -match '^Last updated:\s+') { ' class="meta"' } else { '' }
        $body.Add("<p$class>$(Convert-InlineMarkdown $paragraph)</p>")
    }

    $encodedTitle = Convert-HtmlText $title
    $bodyHtml = $body -join "`n"
    $html = @"
<!doctype html>
<html lang="en" data-source-sha256="$sourceHash" data-generator="$generatorIdentity">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="generator" content="$generatorIdentity">
  <title>$encodedTitle</title>
  <style>
    :root {
      color-scheme: light dark;
      --bg: #f4f1e9;
      --paper: #fffdf8;
      --ink: #1f2824;
      --muted: #64706a;
      --line: #d7d3c8;
      --accent: #17624b;
      --code: #ece8de;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #161b19;
        --paper: #202724;
        --ink: #edf2ee;
        --muted: #aab6b0;
        --line: #3c4741;
        --accent: #7fd7b4;
        --code: #29322e;
      }
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--bg);
      color: var(--ink);
      font-family: Inter, "Segoe UI", Arial, sans-serif;
      line-height: 1.62;
    }
    main {
      max-width: 1040px;
      margin: 32px auto;
      padding: clamp(24px, 5vw, 64px);
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: 18px;
    }
    h1, h2, h3, h4 { line-height: 1.15; letter-spacing: -0.025em; }
    h1 { font-size: clamp(2.4rem, 6vw, 4.8rem); margin: 0 0 8px; }
    h2 { margin-top: 56px; padding-top: 18px; border-top: 1px solid var(--line); }
    h3, h4 { margin-top: 32px; }
    a { color: var(--accent); }
    .meta { color: var(--muted); }
    code {
      background: var(--code);
      border-radius: 5px;
      padding: .12em .35em;
      font-family: "Geist Mono", Consolas, monospace;
    }
    pre {
      overflow-x: auto;
      padding: 20px;
      background: var(--code);
      border-radius: 12px;
    }
    pre code { padding: 0; background: transparent; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th, td { text-align: left; vertical-align: top; border-bottom: 1px solid var(--line); padding: 10px 12px; }
    th { color: var(--muted); font-size: .88rem; text-transform: uppercase; letter-spacing: .04em; }
    li + li { margin-top: 7px; }
    @media (max-width: 720px) {
      main { margin: 0; border-left: 0; border-right: 0; border-radius: 0; }
      table { display: block; overflow-x: auto; }
      code, a { overflow-wrap: anywhere; }
    }
  </style>
</head>
<body>
<main>
$bodyHtml
</main>
</body>
</html>
"@
    return $html.Replace("`r`n", "`n").Replace("`r", "`n")
}

$renderedHtml = Convert-MarkdownDocument $MarkdownPath
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $renderedHtml
}
else {
    $fullOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $parent = Split-Path $fullOutputPath -Parent
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if ($PSCmdlet.ShouldProcess($fullOutputPath, 'Write deterministic human-guide HTML mirror')) {
        [System.IO.File]::WriteAllText(
            $fullOutputPath,
            $renderedHtml,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}
