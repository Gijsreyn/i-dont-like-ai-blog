<#
.SYNOPSIS
    Starts a new post: a folder in posts with an index.md, its front matter filled in, and room for its images.

.DESCRIPTION
    Creates posts/<date>-<slug>/index.md and the folder images next to it. The date in the name of the folder is
    the publication date of the post, and the rest of the name is its slug, the last part of its address.

    The post starts as a draft. Write it, look at it with ./preview.ps1, and set status to published in its front
    matter when it may go live.

    The post gets its cover right away: its title in the style of the site, as images/cover.jpg, and the line
    feature_image in its front matter that points to it. ./cover.ps1 -Image gives the cover a picture later.

.EXAMPLE
    ./new-post.ps1 'Why I do not like AI'

    Creates posts/<today>-why-i-do-not-like-ai/index.md and returns the file.

.EXAMPLE
    ./new-post.ps1 'Release notes' -Tags News, Releases -Open

    Creates the post with two tags and opens the file in the editor for Markdown files.

.EXAMPLE
    ./new-post.ps1 'Looking back' -Date 2026-01-31 -Slug january

    Creates posts/2026-01-31-january/index.md.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # The title of the post.
    [Parameter(Mandatory, Position = 0)]
    [string] $Title,

    # The tags of the post.
    [string[]] $Tags = @(),

    # The last part of the address of the post. Defaults to the title in lower case letters, digits and hyphens.
    [string] $Slug,

    # The publication date of the post. Defaults to today.
    [datetime] $Date = (Get-Date),

    # Open the file when it is there.
    [switch] $Open
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$site = & (Join-Path -Path $PSScriptRoot -ChildPath 'tools/Initialize-Site.ps1')

$post = @{
    Title = $Title
    Path  = $site.PostsPath
    Tags  = $Tags
    Date  = $Date
}
if ($Slug) {
    $post['Slug'] = $Slug
}

# -WhatIf of this script does not reach the commands of a module by itself, so it is passed on by name.
$file = New-GhostPostFile @post -WhatIf:$WhatIfPreference

# The cover. Every post has one with its title on it, so it is there from the start, and from here on preview.ps1
# and publish.ps1 keep it in step with the title. A cover is not worth failing for: the post is there either way.
if ($file) {
    try {
        # The line in the front matter that makes it the cover of this post, when the post names no picture yet.
        # The file is written back the way it was: with its line endings, and with or without a mark in front.
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $marked = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $skip = if ($marked) { 3 } else { 0 }
        $utf8 = [System.Text.UTF8Encoding]::new($marked)
        $text = $utf8.GetString($bytes, $skip, $bytes.Length - $skip)
        $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }

        $frontMatter = [regex]::Match($text, '\A---\r?\n(?<keys>.*?)\r?\n---(?=\r?\n|\z)', 'Singleline')
        if ($frontMatter.Success) {
            $keys = $frontMatter.Groups['keys']
            $line = 'feature_image: images/cover.jpg'
            $empty = [regex]::new('(?m)^feature_image:[ \t]*(?:""|' + "''" + ')?[ \t]*(?=\r?$)')
            $changed = $null
            if ($empty.IsMatch($keys.Value)) {
                $changed = $empty.Replace($keys.Value, $line, 1)
            }
            elseif ($keys.Value -notmatch '(?m)^feature_image:') {
                $changed = $keys.Value + $newline + $line
            }
            if ($changed) {
                $text = $text.Remove($keys.Index, $keys.Length).Insert($keys.Index, $changed)
                [System.IO.File]::WriteAllText($file.FullName, $text, $utf8)
            }
        }

        # What the cover shows, feature_image_alt, is for later: cover.ps1 would warn about it now.
        $cover = Join-Path -Path $PSScriptRoot -ChildPath 'cover.ps1'
        & $cover -Post $file.Directory.FullName -WarningAction SilentlyContinue
    }
    catch {
        Write-Warning -Message "The post has no cover yet: $($_.Exception.Message)"
    }

    # What comes next, with the folder of this post filled in, so that nobody has to remember it.
    $folder = [System.IO.Path]::GetRelativePath($PSScriptRoot, $file.Directory.FullName) -replace '\\', '/'
    @(
        ''
        'The post has a cover with its title. To give the cover a picture:'
        "  ./cover.ps1 -Prompt 'what the picture shows'      the prompt, for the image generator"
        "  ./cover.ps1 $folder -Image <the picture> -Open"
        './cover.ps1 without anything shows the rest: a picture inside the post, and what happens by itself.'
        ''
    ) | ForEach-Object -Process { Write-Information -MessageData $_ -InformationAction Continue }
}

$file

if ($Open -and $file) {
    Invoke-Item -LiteralPath $file.FullName
}
