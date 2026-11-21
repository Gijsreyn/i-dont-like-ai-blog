<#
.SYNOPSIS
    Starts a new post: a folder in posts with an index.md, its front matter filled in, and room for its images.

.DESCRIPTION
    Creates posts/<date>-<slug>/index.md and the folder images next to it. The date in the name of the folder is
    the publication date of the post, and the rest of the name is its slug, the last part of its address.

    The post starts as a draft. Write it, look at it with ./preview.ps1, and set status to published in its front
    matter when it may go live.

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
$file

if ($Open -and $file) {
    Invoke-Item -LiteralPath $file.FullName
}
