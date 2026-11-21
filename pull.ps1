<#
.SYNOPSIS
    Brings into this repository what was made on the live site: its tags and its pages, as files.

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
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # Overwrite a file that differs from what the site has.
    [switch] $Force,

    # Read from the site on this machine instead of the live site.
    [switch] $Local
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$site = & (Join-Path -Path $PSScriptRoot -ChildPath 'tools/Initialize-Site.ps1')

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

    $skipped = @($tags + $pages + $settings | Where-Object { $_.Action -eq 'Skipped' }).Count
    if ($skipped -gt 0) {
        $what = "$skipped of the files differ from the site and were left as they are"
        Write-Information -MessageData "${what}: this repository decides. Run ./pull.ps1 -Force to take the site."
    }
}
finally {
    Disconnect-Ghost
}
