<#
.SYNOPSIS
    Brings into this repository what was made on the live site: its tags and its pages, and the posts you ask
    for, as files.

.DESCRIPTION
    This repository decides what the sites show: preview.ps1 and publish.ps1 send its tags, pages and posts to a
    site. This script is for the other direction, for what was made in Ghost Admin and is not in the repository
    yet. It only reads from the site, and writes files here. Look at what changed with git, and commit it.

    A tag becomes tags/<slug>.md: its fields in the front matter, its description below it.

    A page becomes pages/<slug>/index.md: its fields in the front matter, its content below it. A page that was
    written as Markdown on the site gives that Markdown back. Any other page gives the HTML that Ghost renders
    for it, which looks the same in most cases but is no longer made of the cards of the editor: the column
    Content says which it was. Drafts are written too, and this repository is public: leave out of a commit what
    is not meant to be read yet.

    A post is only read when you ask for it, because the posts that were written here are here already. -Lessons
    asks for the lessons of the courses, and -PostFilter for the posts that match a filter of Ghost. A post
    becomes posts/<date>-<slug>/index.md, with the day it was published, and its content is written the way the
    content of a page is. A post that already has a file anywhere below posts keeps that file. The file of a
    post holds all of its text, also when the site shows the post to members only.

    A link to a page of the site itself is written without the address of the site: /courses/a-course/ and not
    https://example.com/courses/a-course/. Such a link stays on the site that shows it, so on the site on this
    machine it leads to the page on this machine. A picture keeps its address, and so does a link to a file of
    the site. A file is compared with the address in its links, so it does not differ from the site for this.

    A file that is the same as what the site has is left alone. A file that differs is not overwritten, because
    the repository decides, unless you pass -Force.

    The key of the live site comes from GHOST_LIVE_ADMIN_API_KEY, from a secret with that name in your vault, or
    from you: the script asks for it. See AGENTS.md.

.EXAMPLE
    ./pull.ps1

    Writes a file for every tag and every page of the live site that has none here yet.

.EXAMPLE
    ./pull.ps1 -Force

    Also overwrites the files that differ: the folders tags and pages become what the live site has.

.EXAMPLE
    ./pull.ps1 -Local

    Reads the site on this machine instead, for a tag or a page you made in its Ghost Admin.

.EXAMPLE
    ./pull.ps1 -Lessons

    Also writes a folder in posts for every lesson of a course. A course is a page with the tag Course, and its
    lessons are the posts that carry the tag with the slug of that page.

.EXAMPLE
    ./pull.ps1 -PostFilter 'tag:powershell+status:published'

    Also writes a folder in posts for every published post with the tag PowerShell.
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'NoPosts')]
param(
    # Also write the lessons of the courses: the posts that carry the tag of a course.
    [Parameter(Mandatory, ParameterSetName = 'Lessons')]
    [switch] $Lessons,

    # Also write the posts that match this filter of Ghost, such as tag:powershell. A tag is named by its slug.
    [Parameter(Mandatory, ParameterSetName = 'PostFilter')]
    [ValidateNotNullOrEmpty()]
    [string] $PostFilter,

    # Overwrite a file that differs from what the site has.
    [switch] $Force,

    # Read from the site on this machine instead of the live site.
    [switch] $Local
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$site = & (Join-Path -Path $PSScriptRoot -ChildPath 'tools/Initialize-Site.ps1')

# Posts are written by a command that the first versions of the module Ghost do not have. Said here, before
# anything is read from a site.
$withPosts = $PSCmdlet.ParameterSetName -ne 'NoPosts'
if ($withPosts -and -not (Get-Command -Name 'Export-GhostPost' -ErrorAction SilentlyContinue)) {
    $why = 'Reading posts takes the command Export-GhostPost, which this version of the module Ghost does not have.'
    $advice = 'Raise GhostVersion in site.psd1, or point GHOST_MODULE_PATH at the folder of a module that has it.'
    throw "$why $advice"
}

if ($Local) {
    $state = Join-Path -Path $site.LocalPath -ChildPath 'local-ghost.json'
    if (-not (Test-Path -LiteralPath $state)) {
        throw 'There is no site on this machine yet. Run ./preview.ps1 first.'
    }
    $source = Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
    $address = $source.Url
    $key = [System.Net.NetworkCredential]::new('', $source.AdminApiKey).SecurePassword
    $staffKey = [System.Net.NetworkCredential]::new('', $source.StaffAccessToken).SecurePassword
}
else {
    if (-not $site.LiveUrl) {
        throw 'Reading the live site needs its address: LiveUrl in site.psd1, or GHOST_LIVE_URL.'
    }
    $address = $site.LiveUrl
    $secrets = Join-Path -Path $PSScriptRoot -ChildPath 'tools/Get-SiteSecret.ps1'
    $key = & $secrets -Site $site -Name 'LiveAdminApiKey'

    # The settings of the theme need more than that key: a staff access token. Without one they are not read.
    $staffKey = & $secrets -Site $site -Name 'LiveStaffAccessToken' -Optional
}

$connection = Connect-Ghost -Url $address -AdminApiKey $key
Write-Information -MessageData "Reading the tags and the pages of $($connection.Url). Nothing is changed there."

# A link to a page of the site itself is in the files without the address of the site: /courses/a-course/. Such a
# link stays on the site that shows it, so on the site on this machine it leads to the page on this machine.
# Ghost answers with the address in every link, and that is the address its readers see, which is not always
# the one this script connects to. So for the time of the comparison the files get that address too, and
# afterwards it is taken out again, also out of what was written. See tools/Set-RelativeLink.ps1.
$linkTool = Join-Path -Path $PSScriptRoot -ChildPath 'tools/Set-RelativeLink.ps1'
$readerUrl = @(Get-GhostPage -Fields 'url' -Limit 1 | ForEach-Object { $_.url }) | Select-Object -First 1
$siteUrls = @(
    @(
        if ($readerUrl) { ([uri] $readerUrl).GetLeftPart([System.UriPartial]::Authority) }
        ([uri] $connection.Url).GetLeftPart([System.UriPartial]::Authority)
    ) | Select-Object -Unique
)
$linkFolders = @(
    @(
        $site.PagesPath
        if ($withPosts) { $site.PostsPath }
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }
)

$withAddress = @()
if ($WhatIfPreference) {
    $what = 'With -WhatIf the files are compared as they are'
    Write-Information -MessageData "${what}: one with a link without the address of the site shows as different."
}
elseif ($linkFolders.Count -gt 0) {
    $withAddress = @(& $linkTool -Path $linkFolders -SiteUrl $siteUrls[0] -Absolute)
}

$pages = @()
$posts = @()
try {
    # -WhatIf of this script does not reach the commands of a module by itself, so it is passed on by name.
    $tags = @(Export-GhostTag -Path $site.TagsPath -Force:$Force -WhatIf:$WhatIfPreference)
    $tags | Format-Table -Property Action, Name, Slug -AutoSize

    $pages = @(Export-GhostPage -Path $site.PagesPath -Force:$Force -WhatIf:$WhatIfPreference)
    $pages | Format-Table -Property Action, Status, Slug, Content -AutoSize

    $html = @($pages | Where-Object { $_.Content -eq 'Html' }).Count
    if ($html -gt 0) {
        $what = "$html of the pages were not written as Markdown on the site and are here as the HTML Ghost renders"
        Write-Information -MessageData "${what}. Look at them with ./preview.ps1 before you publish."
    }
    $drafts = @($pages | Where-Object { $_.Status -ne 'published' }).Count
    if ($drafts -gt 0) {
        $what = "$drafts of the pages are not published on the site"
        Write-Information -MessageData "${what}. Committing them makes them public in this repository."
    }

    # The posts that were asked for. The lessons of a course are the posts with the tag of that course, and
    # that tag has the slug of the page of the course: the routes of the theme count on it.
    $posts = @()
    $filter = $PostFilter
    if ($Lessons) {
        $courses = @(Get-GhostPage -Filter 'tag:course' -Fields 'slug' | ForEach-Object { $_.slug })
        if ($courses.Count -gt 0) {
            $filter = 'tag:[{0}]' -f ($courses -join ',')
        }
        else {
            Write-Information -MessageData 'The site has no page with the tag Course, so no lesson was read.'
        }
    }
    if ($filter) {
        Write-Information -MessageData "Reading the posts that match $filter."
        $posts = @(Export-GhostPost -Path $site.PostsPath -Filter $filter -Force:$Force -WhatIf:$WhatIfPreference)
        $posts | Format-Table -Property Action, Status, Visibility, Slug, Content -AutoSize

        $html = @($posts | Where-Object { $_.Content -eq 'Html' }).Count
        if ($html -gt 0) {
            $what = "$html of the posts were not written as Markdown on the site and are here as the HTML Ghost renders"
            $next = 'The next publish makes each of them one Markdown card on the site'
            Write-Information -MessageData "${what}. ${next}: look at them with ./preview.ps1 first."
        }
        $drafts = @($posts | Where-Object { $_.Status -ne 'published' }).Count
        if ($drafts -gt 0) {
            $what = "$drafts of the posts are not published on the site"
            Write-Information -MessageData "${what}. Committing them makes them public in this repository."
        }
        $closed = @($posts | Where-Object { $_.Visibility -and $_.Visibility -ne 'public' }).Count
        if ($closed -gt 0) {
            $what = "$closed of the posts are for members only on the site"
            Write-Information -MessageData "${what}. Committing them makes all of their text public here."
        }
    }

    # The settings of the theme, which Ghost shows to an owner or an administrator only.
    $settings = @()
    if ($staffKey -and $site.ThemeSettingsPath) {
        Connect-Ghost -Url $address -AdminApiKey $staffKey | Out-Null
        $tool = Join-Path -Path $PSScriptRoot -ChildPath 'tools/Save-ThemeSetting.ps1'
        $settings = @(& $tool -Site $site -Force:$Force -WhatIf:$WhatIfPreference)
        $settings | Format-Table -Property Action, Settings, Path -AutoSize
    }
    elseif ($site.ThemeSettingsPath) {
        $why = 'that takes a staff access token, in GHOST_LIVE_STAFF_ACCESS_TOKEN or in your vault'
        Write-Information -MessageData "The settings of the theme were not read: $why."
    }

    $skipped = @($tags + $pages + $posts + $settings | Where-Object { $_.Action -eq 'Skipped' }).Count
    if ($skipped -gt 0) {
        $what = "$skipped of the files differ from the site and were left as they are"
        Write-Information -MessageData "${what}: this repository decides. Run ./pull.ps1 -Force to take the site."
    }
}
finally {
    # The address out of the links again: in the files that got it above, and in every file that is now what the
    # site has. A file that differs and was left alone stays as it was written here.
    if (-not $WhatIfPreference) {
        $same = @($pages + $posts | Where-Object { $_.Action -ne 'Skipped' } | ForEach-Object { $_.Path })
        $files = @($withAddress + $same | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
                Sort-Object -Unique)
        if ($files) {
            $relative = @(foreach ($url in $siteUrls) { & $linkTool -Path $files -SiteUrl $url }) |
                Sort-Object -Unique
            $new = @($relative | Where-Object { $withAddress -notcontains $_ }).Count
            if ($new -gt 0) {
                $what = "In $new of the files the links to the site itself were written without its address"
                Write-Information -MessageData "${what}, so that they stay on the site that shows them."
            }
        }
    }

    Disconnect-Ghost
}
