<#
.SYNOPSIS
    Shows the posts of this repository on a Ghost site on your own machine, with the theme of the live site.

.DESCRIPTION
    Starts a Ghost site on this machine, gives it the theme, and creates or updates a post for every Markdown file
    in the folder posts. Nothing reaches the live site: this is where you look at a post, and at the theme, before
    anybody else does.

    1. The site. It is installed the first time, which takes a few minutes and needs Node.js 22 or 24. After that
       it is started when it does not run. It lives in .local-ghost, which git ignores.
    2. The theme. A folder on this machine when there is one (-ThemePath, or ThemePath in site.local.psd1): the
       folder is linked, so a change to the theme shows right away. Otherwise the repository of the theme is cloned
       (ThemeRepository in site.local.psd1), with git as it is set up on this machine.
    3. With -FromLive, the content of the live site: its posts, pages, tags and settings replace those of the local
       site, so that you look at the real thing. That needs a staff access token of the live site, which the
       script takes from your vault or asks you for, see README.md.
    4. The tags, the pages and the posts of this repository, which are created or updated on top of that.

    Run it again whenever you want to see a change: only what changed is sent.

    The title of a post is on its cover. Before the posts are sent, cover.ps1 makes the covers again that are
    missing, or that are behind on their post or on the theme. What you see is then what a publish sends.

    Before all that it looks for secrets in the files of the repository, with tools/Test-Secret.ps1, and stops
    when it finds one. -SkipSecretScan leaves that out, for when there is no internet.

.EXAMPLE
    ./preview.ps1

    Starts the local site and brings its posts up to date with the folder posts.

.EXAMPLE
    ./preview.ps1 -FromLive -Open

    Makes the local site a copy of the live one first, then adds the posts of this repository and opens the site.

.EXAMPLE
    ./preview.ps1 -ThemePath ../i-dont-like-ai-theme

    Uses the theme in that folder, to work on the theme and the posts side by side.

.EXAMPLE
    ./preview.ps1 -Stop

    Stops the local site. Its content is kept. -Remove deletes it.
#>
[CmdletBinding(DefaultParameterSetName = 'Start')]
param(
    # A folder with the theme, to link into the site. Defaults to ThemePath in site.local.psd1.
    [Parameter(ParameterSetName = 'Start')]
    [string] $ThemePath,

    # Replace the posts, pages, tags and settings of the local site with those of the live site first.
    [Parameter(ParameterSetName = 'Start')]
    [switch] $FromLive,

    # Open the site in the browser when it is ready.
    [Parameter(ParameterSetName = 'Start')]
    [switch] $Open,

    # Do not look for secrets in the files of the repository first. That check needs the internet.
    [Parameter(ParameterSetName = 'Start')]
    [switch] $SkipSecretScan,

    # Stop the local site.
    [Parameter(Mandatory, ParameterSetName = 'Stop')]
    [switch] $Stop,

    # Stop the local site and delete it, with its content.
    [Parameter(Mandatory, ParameterSetName = 'Remove')]
    [switch] $Remove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$site = & (Join-Path -Path $PSScriptRoot -ChildPath 'tools/Initialize-Site.ps1')

if ($Stop) {
    Stop-GhostLocalSite -Path $site.LocalPath
    return
}
if ($Remove) {
    Remove-GhostLocalSite -Path $site.LocalPath
    return
}

# Before anything else: no key, token or other secret in a file that git does not ignore. This repository is
# public, and this is the moment before a commit to find out.
if (-not $SkipSecretScan) {
    & (Join-Path -Path $PSScriptRoot -ChildPath 'tools/Test-Secret.ps1')
}

# 1 and 2. The site and its theme.
$start = @{
    Path  = $site.LocalPath
    Port  = $site.LocalPort
    Title = 'Local preview'
}
if (-not $ThemePath) {
    $ThemePath = $site.ThemePath
}
if ($ThemePath -and (Test-Path -LiteralPath $ThemePath)) {
    $start['ThemePath'] = $ThemePath
}
elseif ($site.ThemeRepository) {
    $start['ThemeRepository'] = $site.ThemeRepository
}
else {
    $advice = 'The settings of the theme are left out. See site.local.example.psd1.'
    Write-Warning -Message "No theme is set, so the site shows the theme Ghost comes with. $advice"
}
$local = Start-GhostLocalSite @start -Connect

# 3. The content of the live site.
if ($FromLive) {
    if (-not $site.LiveUrl) {
        throw 'Copying the live site needs its address: LiveUrl in site.psd1, or GHOST_LIVE_URL.'
    }

    # The token is not in a file: it comes from the environment, from a vault, or from you.
    $secrets = Join-Path -Path $PSScriptRoot -ChildPath 'tools/Get-SiteSecret.ps1'
    $liveKey = & $secrets -Site $site -Name 'LiveStaffAccessToken'

    Write-Information -MessageData "Reading the content of $($site.LiveUrl)."
    $name = 'ghost-live-{0}.json' -f [guid]::NewGuid().ToString('N')
    $export = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $name
    try {
        Connect-Ghost -Url $site.LiveUrl -AdminApiKey $liveKey | Out-Null

        # Only reads from the live site. The images stay there: the local site shows them from the live one.
        Export-GhostContent -Path $export -AbsoluteUrl | Out-Null

        # Importing is something only the owner of a site may do.
        $ownerKey = [System.Net.NetworkCredential]::new('', $local.StaffAccessToken).SecurePassword
        Connect-Ghost -Url $local.Url -AdminApiKey $ownerKey | Out-Null
        Write-Information -MessageData "Replacing the content of $($local.Url) with it."
        $import = Import-GhostContent -Path $export -Replace -Confirm:$false
        foreach ($problem in $import.Problems) {
            Write-Warning -Message ('Not imported as it was: {0}' -f ($problem | ConvertTo-Json -Compress -Depth 3))
        }

        # The settings of the live site came along, and with them the theme that is active there.
        if ($local.Theme) {
            Enable-GhostTheme -Name $local.Theme | Out-Null
        }
    }
    finally {
        # The export holds everything that was written on the live site, drafts included.
        Remove-Item -LiteralPath $export -Force -ErrorAction SilentlyContinue

        # From here on as the integration again, which may do what the integration of the live site may do.
        $localKey = [System.Net.NetworkCredential]::new('', $local.AdminApiKey).SecurePassword
        Connect-Ghost -Url $local.Url -AdminApiKey $localKey | Out-Null
    }
}

# The settings of the theme, which a new site does not have and which the live site may have different. Only the
# owner may change them, so this part runs with the staff access token of the local site.
#
# They are the settings of the theme of the live site. The theme Ghost comes with has other ones and refuses
# these, so a site without the theme is left alone. That is the site of the workflow Check.
$hasSettings = $site.ThemeSettingsPath -and (Test-Path -LiteralPath $site.ThemeSettingsPath)
if ($local.Theme -and $hasSettings) {
    $ownerKey = [System.Net.NetworkCredential]::new('', $local.StaffAccessToken).SecurePassword
    Connect-Ghost -Url $local.Url -AdminApiKey $ownerKey | Out-Null
    try {
        & (Join-Path -Path $PSScriptRoot -ChildPath 'tools/Set-ThemeSetting.ps1') -Site $site
    }
    finally {
        $localKey = [System.Net.NetworkCredential]::new('', $local.AdminApiKey).SecurePassword
        Connect-Ghost -Url $local.Url -AdminApiKey $localKey | Out-Null
    }
}

# The covers, before the posts that show them: one that is missing, or whose title, picture or theme changed
# since it was made, is made again. A cover is not worth stopping for: without it the post keeps the one it had.
try {
    $cover = @{ Refresh = $true }
    if ($start.ContainsKey('ThemePath')) {
        $cover['ThemePath'] = $start['ThemePath']
    }
    & (Join-Path -Path $PSScriptRoot -ChildPath 'cover.ps1') @cover
}
catch {
    Write-Warning -Message "The covers were not brought up to date: $($_.Exception.Message)"
}

# 4. The tags of this repository, before the posts: a post that names a tag that is not there creates it with
# only that name.
if ($site.TagsPath -and (Test-Path -LiteralPath $site.TagsPath)) {
    $tags = @(Sync-GhostTag -Path $site.TagsPath)
    $tags | Format-Table -Property Action, Name, Slug -AutoSize
}

# 5. The pages of this repository. The routes of the theme show some of them: /books/my-book/ needs the page
# my-book.
if ($site.PagesPath -and (Test-Path -LiteralPath $site.PagesPath)) {
    $pages = @(Sync-GhostPage -Path $site.PagesPath -Recurse)
    $pages | Format-Table -Property Action, Status, Slug -AutoSize
}

# 6. The posts of this repository.
Write-Information -MessageData "Bringing the posts of $($local.Url) up to date with $($site.PostsPath)."
$posts = @(Sync-GhostPost -Path $site.PostsPath -Recurse)
$posts | Format-Table -Property Action, Status, Slug, @{ Name = 'Preview'; Expression = { $_.Url } } -AutoSize

Write-Information -MessageData ''
Write-Information -MessageData "Site:   $($local.Url)"
Write-Information -MessageData "Admin:  $($local.AdminUrl)   ($($local.Email) / $($local.Password))"
Write-Information -MessageData 'A draft is not in the lists of the site: open it by its address under Preview.'

if ($Open) {
    Start-Process -FilePath $local.Url
}
