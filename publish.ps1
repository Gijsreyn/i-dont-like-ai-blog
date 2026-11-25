<#
.SYNOPSIS
    Brings the live site up to date with this repository: the theme when it changed, and the posts.

.DESCRIPTION
    Does on the live site what preview.ps1 does on your own machine, and only sends what differs:

    1. The theme. The newest package of the theme is taken from Azure Artifacts, where the pipeline of the theme
       publishes it, and uploaded and activated when the live site shows another theme than that one. A post never
       needs a template that the site does not have yet, because the theme goes first.
    2. The settings of the theme, from theme-settings.psd1, when they differ. Ghost only allows that with a
       staff access token: without GHOST_LIVE_STAFF_ACCESS_TOKEN they are left as they are on the site.
    3. The tags. A tag is created or updated for every file in the folder tags that differs from the tag on the
       site.
    4. The pages. A page is created or updated for every folder in the folder pages whose file differs from the
       page on the site.
    5. The posts. A post is created or updated for every Markdown file in the folder posts whose file differs from
       the post on the site. A post is published when its front matter says status: published. An email is never
       sent.

    The workflow Publish of this repository does the same for every change to main. It leaves the theme, the tags,
    the pages and the posts to the action ghost-deploy-action, which uses the same commands, and runs this script
    with -SettingsOnly for the settings of the theme. You can run the script yourself too.

    Before the posts are sent, cover.ps1 makes the covers again that are missing, or that are behind on their
    post or on the theme. They are files of this repository: commit what it made.

    -WhatIf shows what would change, without changing anything: it only reads. -Local does the whole thing for
    real, but on the site on your own machine, which is how to rehearse a publish.

    The address of the live site is in site.psd1. Its Admin API key is a secret and is in no file: it is taken from
    GHOST_LIVE_ADMIN_API_KEY, which is how a workflow passes it, or from a secret with that name in your vault, and
    otherwise the script asks you for it. See README.md.

.EXAMPLE
    ./publish.ps1 -WhatIf

    Shows which theme and which posts would be sent to the live site.

.EXAMPLE
    ./publish.ps1 -Local

    Publishes to the site on this machine, the one of preview.ps1, to see a publish happen without the live site.

.EXAMPLE
    ./publish.ps1

    Publishes to the live site after one confirmation.

.EXAMPLE
    ./publish.ps1 -ThemePackage ./i-dont-like-ai.zip -Confirm:$false

    Publishes without asking, with a theme package that is on this machine already.

.EXAMPLE
    ./publish.ps1 -SkipTheme

    Publishes the posts and leaves the theme of the live site as it is.

.EXAMPLE
    ./publish.ps1 -SettingsOnly -Confirm:$false

    Sends the settings of the theme that differ and nothing else, without asking. The workflow Publish does this
    after its action has brought the theme, the tags, the pages and the posts up to date.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    # The zip file or the folder of the theme. Defaults to the newest package in Azure Artifacts.
    [string] $ThemePackage,

    # Leave the theme of the site, and its settings, as they are.
    [switch] $SkipTheme,

    # Leave the posts, the pages and the tags of the site as they are.
    [switch] $SkipPosts,

    # Send the settings of the theme and nothing else. The theme itself, the tags, the pages and the posts are
    # left as they are.
    [switch] $SettingsOnly,

    # Publish to the site on this machine instead of the live site.
    [switch] $Local
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$site = & (Join-Path -Path $PSScriptRoot -ChildPath 'tools/Initialize-Site.ps1')

# -WhatIf of this script does not reach the commands of a module by itself: a module does not see the preferences
# of the script that calls it. So it is passed on, by name, to every command that changes something.
$dryRun = [bool] $WhatIfPreference

# Before -SkipTheme is set for a theme that is linked into the local site: its settings are still sent.
$applySettings = -not $SkipTheme

# The settings alone. Whoever asks for that has taken care of the rest, as the workflow Publish does.
if ($SettingsOnly) {
    $applySettings = $true
    $SkipTheme = $true
    $SkipPosts = $true
}

if ($Local) {
    $state = Join-Path -Path $site.LocalPath -ChildPath 'local-ghost.json'
    if (-not (Test-Path -LiteralPath $state)) {
        throw 'There is no site on this machine yet. Run ./preview.ps1 first.'
    }
    $target = Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
    $address = $target.Url
    if (-not ([uri] $address).IsLoopback) {
        throw "$address is not a site on this machine."
    }
    $key = [System.Net.NetworkCredential]::new('', $target.AdminApiKey).SecurePassword
    $staffKey = [System.Net.NetworkCredential]::new('', $target.StaffAccessToken).SecurePassword

    # preview.ps1 links the folder of the theme into the site. The site then shows the theme as it is in that
    # folder, and an upload would only replace the link with a copy that no longer follows the folder.
    $linked = Join-Path -Path $site.LocalPath -ChildPath "content/themes/$($site.ThemeName)"
    $link = Get-Item -LiteralPath $linked -Force -ErrorAction SilentlyContinue
    if ($link -and ($link.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -and -not $SkipTheme) {
        $reason = 'The local site shows the theme straight from its folder'
        Write-Information -MessageData "${reason}: there is no theme to send."
        $SkipTheme = $true
    }
}
else {
    if (-not $site.LiveUrl) {
        throw 'Publishing needs the address of the live site: LiveUrl in site.psd1, or GHOST_LIVE_URL.'
    }
    $address = $site.LiveUrl
    if ($address -notmatch '^https?://') {
        $address = "https://$address"
    }
    if (([uri] $address).IsLoopback) {
        throw "$address is a site on this machine. Use -Local to publish to the local site."
    }

    # The key is not in a file: it comes from the environment, from a vault, or from you.
    $secrets = Join-Path -Path $PSScriptRoot -ChildPath 'tools/Get-SiteSecret.ps1'
    $key = & $secrets -Site $site -Name 'LiveAdminApiKey'

    # The settings of the theme need more than that key: a staff access token. Without one they are left alone.
    $staffKey = & $secrets -Site $site -Name 'LiveStaffAccessToken' -Optional

    # One question for the whole run. With -WhatIf nothing is asked, and the commands below say what they would do.
    $question = 'Publish the theme and the posts of this repository'
    if ($SettingsOnly) {
        $question = 'Send the settings of the theme of this repository'
    }
    if (-not $dryRun -and -not $PSCmdlet.ShouldProcess($address, $question)) {
        return
    }
}

$connection = Connect-Ghost -Url $address -AdminApiKey $key
$mode = if ($dryRun) { 'Nothing is changed: this run only reads.' } else { 'This run changes the site.' }
$name = '{0} ({1}, Ghost {2})' -f $connection.Url, $connection.Title, $connection.Version
Write-Information -MessageData "Connected to $name. $mode"

try {
    # 1. The theme.
    if (-not $SkipTheme) {
        if (-not $ThemePackage) {
            if ($site.ThemeFeedOrganization -and $site.ThemeFeed) {
                $what = "the newest package of the theme $($site.ThemeName)"
                Write-Information -MessageData "Downloading $what from the feed $($site.ThemeFeed)."
                $download = @{
                    Organization = $site.ThemeFeedOrganization
                    Project      = $site.ThemeFeedProject
                    Feed         = $site.ThemeFeed
                    Name         = $site.ThemeName
                }
                if ($site.ThemeFeedToken) {
                    $download['Token'] = $site.ThemeFeedToken
                }
                $tool = Join-Path -Path $PSScriptRoot -ChildPath 'tools/Get-ThemePackage.ps1'
                $ThemePackage = (& $tool @download).FullName
            }
            else {
                $missing = 'No theme package and no feed to take one from'
                Write-Warning -Message "${missing}: the theme is left as it is. See site.local.example.psd1."
            }
        }

        if ($ThemePackage) {
            $theme = Sync-GhostTheme -Path $ThemePackage -Name $site.ThemeName -WhatIf:$dryRun -Confirm:$false
            $short = @{ Name = 'Fingerprint'; Expression = { $_.Fingerprint.Substring(0, 12) } }
            $theme | Format-Table -Property Action, Name, Version, $short -AutoSize
        }
    }

    # 2. The settings of the theme. Ghost lets only an owner or an administrator change them, so this part runs
    # with the staff access token, and the rest with the key of the integration again.
    $hasSettings = $site.ThemeSettingsPath -and (Test-Path -LiteralPath $site.ThemeSettingsPath)
    if ($applySettings -and $hasSettings) {
        if ($staffKey) {
            Connect-Ghost -Url $address -AdminApiKey $staffKey | Out-Null
            try {
                $tool = Join-Path -Path $PSScriptRoot -ChildPath 'tools/Set-ThemeSetting.ps1'
                & $tool -Site $site -WhatIf:$dryRun
            }
            finally {
                Connect-Ghost -Url $address -AdminApiKey $key | Out-Null
            }
        }
        else {
            $why = 'that takes a staff access token, in GHOST_LIVE_STAFF_ACCESS_TOKEN or in your vault'
            Write-Information -MessageData "The settings of the theme are left as they are: $why."
        }
    }
    elseif ($hasSettings) {
        Write-Information -MessageData 'The settings of the theme are left as they are: -SkipTheme skips them too.'
    }

    # The covers, before the posts that show them: one that is missing, or whose title, picture or theme
    # changed since it was made, is made again. In a dry run it only says which. A cover is not worth stopping a
    # publish for: without it the post keeps the one it had.
    if (-not $SkipPosts) {
        try {
            & (Join-Path -Path $PSScriptRoot -ChildPath 'cover.ps1') -Refresh -WhatIf:$dryRun
        }
        catch {
            Write-Warning -Message "The covers were not brought up to date: $($_.Exception.Message)"
        }
    }

    # 3. The tags, before the posts: a post that names a tag that is not there creates it with only that name.
    if (-not $SkipPosts -and $site.TagsPath -and (Test-Path -LiteralPath $site.TagsPath)) {
        $tags = Sync-GhostTag -Path $site.TagsPath -WhatIf:$dryRun -Confirm:$false
        $tags | Format-Table -Property Action, Name, Slug -AutoSize
    }

    # 4. The pages. The routes of the theme show some of them: /books/my-book/ needs the page my-book.
    if (-not $SkipPosts -and $site.PagesPath -and (Test-Path -LiteralPath $site.PagesPath)) {
        $pages = Sync-GhostPage -Path $site.PagesPath -Recurse -WhatIf:$dryRun -Confirm:$false
        $pages | Format-Table -Property Action, Status, Slug, Url -AutoSize
    }

    # 5. The posts.
    if (-not $SkipPosts) {
        $posts = Sync-GhostPost -Path $site.PostsPath -Recurse -WhatIf:$dryRun -Confirm:$false
        $posts | Format-Table -Property Action, Status, Slug, Url -AutoSize
    }
}
finally {
    Disconnect-Ghost
}
