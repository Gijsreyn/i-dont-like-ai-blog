<#
.SYNOPSIS
    Writes the links to the pages of the site itself without the address of the site, in the files of a folder.

.DESCRIPTION
    A link in a page or a post to another page of the same site can be written in two ways: with the address of
    the site in it, https://example.com/courses/a-course/, or without it, /courses/a-course/. The first one leads
    to that site wherever the text is shown. The second one stays on the site that shows it, so on the site on
    this machine it leads to the page on this machine. This script turns the first into the second.

    It reads every index.md in the folders and changes:

    - an HTML link:     <a href="https://example.com/courses/a-course/">
    - a Markdown link:  [a course](https://example.com/courses/a-course/)

    The address is taken with http or https, and with or without www. in front of it.

    It leaves alone:

    - a picture, in HTML or in Markdown: a picture stays on the site it is on;
    - a link to something below /content/, a file or a picture of the site, for the same reason;
    - an address that is not a link: text, the front matter, an address between angle brackets;
    - what is in a fenced code block, which is an example and not a link of the page.

    With -Absolute it does the opposite, and writes the address in front of a link that has none. Ghost answers
    with the address in every link, so that is how a file compares to what a site has.

    It returns the path of every file it changed.

.EXAMPLE
    & "$PSScriptRoot/tools/Set-RelativeLink.ps1" -Path pages, posts -SiteUrl 'https://example.com'

    Takes https://example.com out of the links in the pages and the posts.

.EXAMPLE
    & "$PSScriptRoot/tools/Set-RelativeLink.ps1" -Path pages -SiteUrl 'https://example.com' -Absolute

    Puts https://example.com in front of the links in the pages that have no address.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([string])]
param(
    # The folders to look in for index.md files, or such files themselves.
    [Parameter(Mandatory)]
    [string[]] $Path,

    # The address of the site whose links these are, as its readers see it: https://example.com.
    [Parameter(Mandatory)]
    [uri] $SiteUrl,

    # Write the address in front of the links that have none, instead of taking it out.
    [switch] $Absolute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $SiteUrl.IsAbsoluteUri -or $SiteUrl.Scheme -notin 'http', 'https') {
    throw "The address of the site has to start with http:// or https://, and this does not: $SiteUrl"
}

# The address in the ways it is written: http or https, with or without www., and with its port when it has one.
$name = [regex]::Escape(($SiteUrl.Host -replace '^www\.', ''))
$port = if ($SiteUrl.IsDefaultPort) { '' } else { ':{0}' -f $SiteUrl.Port }
$origin = "https?://(?:www\.)?$name$([regex]::Escape($port))"
$written = '{0}://{1}{2}' -f $SiteUrl.Scheme, $SiteUrl.Host, $port

# What follows the address in a link, or what a link without an address is: a path, and not one below /content/.
$own = '(?!/content/)(?<rest>(?:[/?#][^"''\s)]*)?)'
$bare = '(?!/content/)(?<rest>/(?!/)[^"''\s)]*)'
$options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase

if ($Absolute) {
    $html = [regex]::new("(?<start>\bhref\s*=\s*(?<quote>[""']))$bare(?=\k<quote>)", $options)
    $markdown = [regex]::new("(?<start>(?<!!)\[[^\]]*\]\()$bare(?=[\s)])", $options)
    $replace = { param($match) $match.Groups['start'].Value + $written + $match.Groups['rest'].Value }
}
else {
    $html = [regex]::new("(?<start>\bhref\s*=\s*(?<quote>[""']))$origin$own(?=\k<quote>)", $options)
    $markdown = [regex]::new("(?<start>(?<!!)\[[^\]]*\]\()$origin$own(?=[\s)])", $options)
    $replace = {
        param($match)
        $rest = $match.Groups['rest'].Value
        if (-not $rest.StartsWith('/')) {
            # The address alone, or with only a question or a place on the page behind it
            $rest = "/$rest"
        }
        $match.Groups['start'].Value + $rest
    }
}

$files = foreach ($item in $Path) {
    if (Test-Path -LiteralPath $item -PathType Container) {
        Get-ChildItem -LiteralPath $item -Filter 'index.md' -File -Recurse
    }
    elseif (Test-Path -LiteralPath $item -PathType Leaf) {
        Get-Item -LiteralPath $item
    }
}

foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)

    # Line by line, to know what is in a fenced code block. The ends of the lines stay what they are.
    $inFence = $false
    $lines = foreach ($line in [regex]::Split($text, '(?<=\n)')) {
        if ($line -match '^\s*(```|~~~)') {
            $inFence = -not $inFence
            $line
        }
        elseif ($inFence) {
            $line
        }
        else {
            $markdown.Replace($html.Replace($line, $replace), $replace)
        }
    }
    $changed = -join $lines

    if ($changed -cne $text) {
        $what = if ($Absolute) { "Write $written in front of the links" } else { "Take $written out of the links" }
        if ($PSCmdlet.ShouldProcess($file.FullName, $what)) {
            [System.IO.File]::WriteAllText($file.FullName, $changed, [System.Text.UTF8Encoding]::new($false))
            $file.FullName
        }
    }
}
