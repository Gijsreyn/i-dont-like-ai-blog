<#
.SYNOPSIS
    Makes the pictures of a post look like the site: the cover with the title on it, and the prompt for a picture.

.DESCRIPTION
    The style is not written down here. It is read from the theme: its colours, the space behind its pages, the
    name of the site. brand/README.md says what is taken from where.

    1. A prompt (-Prompt). Say what the picture shows, and get the text for an image generator with the style of
       the site around it. It is also put on the clipboard. This is how every picture starts.
    2. A cover (-Post). The title of the post, set as on the site, next to the picture. A long title goes across
       the top instead, with the picture below it. Without a picture the cover has the sign of the site in its
       place. Written as images/cover.jpg in the folder of the post; the picture is kept next to it as
       images/cover-art.jpg.
    3. The covers that are behind (-Refresh): one that is missing, or whose title, picture or theme changed since
       it was made. A cover that is still right is not touched. new-post.ps1 makes the first cover of a
       post, and preview.ps1 and publish.ps1 do this before they send the posts, so there is seldom a reason to
       run it by hand. -All makes every cover again, whether it is behind or not.
    4. A picture for inside the post (-Picture): brought to the width of the site and made light.
    5. A check (-Check) and a contact sheet (-Sheet) of all covers, in brand/contact-sheet.jpg.
    6. The posts from before the house style (-Adopt): the ones with a cover of their own, all at once. The first
       run writes a plan, brand/adopt.csv, with a row for every such post and what would be done with its cover:
       the picture it has next to the title, the title alone, or nothing. Change the plan where it is wrong. With
       -WhatIf the covers are made and shown on the contact sheet, and no post is touched. Without it the script
       asks once, and then every post of the plan gets its cover, and its front matter points to it. A post that
       was done is passed over, so it can be run again. A post with a template of its own, such as a lesson of a
       course, is never in the plan.

    The theme is the folder ThemePath of site.local.psd1, or -ThemePath. Without it the style is taken from
    brand/theme.json, which holds what was read from the theme the last time.

    Without anything, ./cover.ps1 shows the routine in a few lines.

    The pictures are handled by tools/cover.py, which uv runs: uv brings Python and what it needs by itself, the
    first time from the internet. Nothing here reaches a site.

.EXAMPLE
    ./cover.ps1 -Prompt 'a laptop that receives two settings from a document'

    Shows the prompt for a square picture, as a cover takes it, and puts it on the clipboard.

.EXAMPLE
    ./cover.ps1 posts/2026-11-20-why-i-do-not-like-ai -Image ~/Downloads/robot.png -Open

    Makes the cover of that post with its title and this picture, and opens it.

.EXAMPLE
    ./cover.ps1 posts/2026-11-20-why-i-do-not-like-ai

    Makes the cover of that post with the picture it has, or without one when it has none.

.EXAMPLE
    ./cover.ps1 -Refresh

    Makes the covers that are missing or behind on their post or on the theme, and leaves the others alone.

.EXAMPLE
    ./cover.ps1 -Refresh -WhatIf

    Only says which covers would be made again.

.EXAMPLE
    ./cover.ps1 -Adopt
    ./cover.ps1 -Adopt -WhatIf -Open
    ./cover.ps1 -Adopt

    The posts from before the house style, in three steps: write the plan, look at the covers it would give
    without changing a post, and do it.

.EXAMPLE
    ./cover.ps1 -Prompt 'three servers that share one clock' -Wide
    ./cover.ps1 -Picture ~/Downloads/servers.png -Post posts/2026-11-20-why-i-do-not-like-ai -Name servers.jpg

    A picture for inside the post: the prompt for a wide one, and the result written to the folder images.
#>
[CmdletBinding(DefaultParameterSetName = 'Routine', SupportsShouldProcess)]
param(
    # The folder of the post or the page.
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Cover')]
    [Parameter(Mandatory, ParameterSetName = 'Picture')]
    [string] $Post,

    # The picture for the cover. Any shape: the largest square around -Focus is used. Left out, the picture the
    # cover already has is used again.
    [Parameter(ParameterSetName = 'Cover')]
    [string] $Image,

    # The point of -Image to cut around, as parts of its width and its height: 0.5,0.5 is the middle.
    [Parameter(ParameterSetName = 'Cover')]
    [string[]] $Focus = @('0.5', '0.5'),

    # Make the covers that are missing, or that are no longer what their post or the theme says.
    [Parameter(Mandatory, ParameterSetName = 'Refresh')]
    [switch] $Refresh,

    # Make every cover again, also the ones that are still right.
    [Parameter(Mandatory, ParameterSetName = 'All')]
    [switch] $All,

    # What a picture shows, in a few words. The answer is the prompt for an image generator.
    [Parameter(Mandatory, ParameterSetName = 'Prompt')]
    [string] $Prompt,

    # A wide picture, 16:9, for inside a post. Without it the prompt asks for a square, for a cover.
    [Parameter(ParameterSetName = 'Prompt')]
    [switch] $Wide,

    # A picture for inside the post.
    [Parameter(Mandatory, ParameterSetName = 'Picture')]
    [string] $Picture,

    # The name of that picture in the folder images of the post. Its extension decides the format.
    [Parameter(Mandatory, ParameterSetName = 'Picture')]
    [ValidatePattern('\.(jpg|jpeg|png|webp)$')]
    [string] $Name,

    # Give the posts that have a cover of their own the house style, as brand/adopt.csv says. The first run
    # writes that plan and changes nothing else.
    [Parameter(Mandatory, ParameterSetName = 'Adopt')]
    [switch] $Adopt,

    # Check the covers of every post and page.
    [Parameter(Mandatory, ParameterSetName = 'Check')]
    [switch] $Check,

    # Put the covers next to each other.
    [Parameter(Mandatory, ParameterSetName = 'Sheet')]
    [switch] $Sheet,

    # The folder of the theme, to read the style from. Defaults to ThemePath in site.local.psd1.
    [string] $ThemePath,

    # Open the picture that was written.
    [Parameter(ParameterSetName = 'Cover')]
    [Parameter(ParameterSetName = 'Picture')]
    [Parameter(ParameterSetName = 'Sheet')]
    [Parameter(ParameterSetName = 'Adopt')]
    [switch] $Open
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Without anything: the routine, for when it is a while ago.
if ($PSCmdlet.ParameterSetName -eq 'Routine') {
    @(
        'The pictures of a post, in the style of the theme. brand/README.md has the whole story.'
        ''
        '  A cover'
        "    ./cover.ps1 -Prompt 'what the picture shows'"
        '        The prompt, on the clipboard. Paste it in the image generator and save what comes back.'
        '    ./cover.ps1 posts/<folder> -Image <the picture> -Open'
        '        The cover: the title of the post next to that picture. -Focus 0.5,0.4 moves the cut.'
        ''
        '  A picture inside the post'
        "    ./cover.ps1 -Prompt 'what the picture shows' -Wide"
        '    ./cover.ps1 -Picture <the picture> -Post posts/<folder> -Name <name>.jpg'
        '        Written to the folder images of the post. The line for the Markdown is shown.'
        ''
        '  By itself: ./new-post.ps1 makes the first cover, and ./preview.ps1 makes one again when its title'
        '  changed. Commit images/cover.jpg and images/cover-art.jpg with the post.'
        ''
        '  Get-Help ./cover.ps1 -Examples shows more, and ./cover.ps1 -Check and -Sheet look at all covers.'
        '  ./cover.ps1 -Adopt gives the posts from before the house style their cover, all at once.'
    ) | ForEach-Object -Process { Write-Information -MessageData $_ }
    return
}

$site = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $PSScriptRoot -ChildPath 'site.psd1')
$tool = Join-Path -Path $PSScriptRoot -ChildPath 'tools/cover.py'
$postsPath = Join-Path -Path $PSScriptRoot -ChildPath $site.PostsPath
$pagesPath = Join-Path -Path $PSScriptRoot -ChildPath $site.PagesPath

# The theme, as preview.ps1 finds it: the parameter, the environment, site.local.psd1. Only its place is read
# from that file, which also holds what nobody may see.
if (-not $ThemePath) {
    $ThemePath = $env:GHOST_THEME_PATH
}
$localFile = Join-Path -Path $PSScriptRoot -ChildPath 'site.local.psd1'
if (-not $ThemePath -and (Test-Path -LiteralPath $localFile)) {
    $local = Import-PowerShellDataFile -LiteralPath $localFile
    if ($local.ContainsKey('ThemePath')) {
        $ThemePath = $local['ThemePath']
    }
}
$common = @()
if ($ThemePath) {
    if (-not [System.IO.Path]::IsPathRooted($ThemePath)) {
        $ThemePath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath $ThemePath))
    }
    if (Test-Path -LiteralPath (Join-Path -Path $ThemePath -ChildPath 'assets/css/screen.css')) {
        $common = '--theme', $ThemePath
    }
}
if (-not $common) {
    Write-Information -MessageData 'The theme is not on this machine: the style is taken from brand/theme.json.'
}

# uv, which runs the tool with Python and what it needs. tools/Test-Secret.ps1 installs it in the folder
# .local/bin of the user, and a session that was open before that does not have the folder in its path yet.
$profileFolder = [System.Environment]::GetFolderPath('UserProfile')
if ($profileFolder -and -not (Get-Command -Name 'uv' -ErrorAction SilentlyContinue)) {
    $userBin = Join-Path -Path $profileFolder -ChildPath '.local/bin'
    if (Test-Path -LiteralPath $userBin) {
        $env:PATH = $userBin + [System.IO.Path]::PathSeparator + $env:PATH
    }
}
if (-not (Get-Command -Name 'uv' -ErrorAction SilentlyContinue)) {
    throw 'uv is not installed. ./preview.ps1 installs it on its first run, or take it from https://docs.astral.sh/uv/.'
}

function Invoke-CoverTool {
    # Runs tools/cover.py and returns its lines. Throws with -Failure when it fails.
    [OutputType([string[]])]
    param([string[]] $Arguments, [string] $Failure)

    $lines = @(& uv run --quiet $tool @common @Arguments)
    if ($LASTEXITCODE -ne 0) {
        $lines | ForEach-Object -Process { Write-Information -MessageData $_ }
        throw $Failure
    }
    $lines
}

function Show-CoverTool {
    # The same, with the lines shown and not returned.
    param([string[]] $Arguments, [string] $Failure)

    Invoke-CoverTool -Arguments $Arguments -Failure $Failure |
        ForEach-Object -Process { Write-Information -MessageData $_ }
}

if ($Prompt) {
    $arguments = @('prompt', $Prompt)
    if ($Wide) {
        $arguments += '--wide'
    }
    $lines = @(Invoke-CoverTool -Arguments $arguments -Failure 'The prompt could not be made.')
    # A line that the tool says about the style is not part of the prompt.
    $aside = '^(The style of the theme|  The covers that|The theme is not at hand)'
    $text = ($lines | Where-Object -FilterScript { $_ -notmatch $aside }) -join "`n"
    try {
        Set-Clipboard -Value $text
        Write-Information -MessageData 'The prompt is on the clipboard.'
    }
    catch {
        Write-Information -MessageData 'The prompt could not be put on the clipboard: copy it from here.'
    }
    $text
    return
}

if ($Check) {
    $failure = 'A cover does not follow the rules, see the lines with an x above and brand/README.md.'
    Show-CoverTool -Arguments 'check', $postsPath, $pagesPath -Failure $failure
    return
}

if ($Sheet) {
    $output = Join-Path -Path $PSScriptRoot -ChildPath 'brand/contact-sheet.jpg'
    if ($PSCmdlet.ShouldProcess($output, 'Write the contact sheet')) {
        $failure = 'The contact sheet could not be made.'
        Show-CoverTool -Arguments 'sheet', $output, '--posts', $postsPath -Failure $failure
        if ($Open) {
            Invoke-Item -LiteralPath $output
        }
    }
    return
}

if ($Adopt) {
    $plan = Join-Path -Path $PSScriptRoot -ChildPath 'brand/adopt.csv'
    $sheetFile = Join-Path -Path $PSScriptRoot -ChildPath 'brand/contact-sheet.jpg'
    $arguments = @('adopt', $postsPath, '--plan', $plan, '--sheet', $sheetFile)
    $failure = 'Not every post could be given its cover, see above.'

    # The first run only writes the plan, with or without -WhatIf.
    if (-not (Test-Path -LiteralPath $plan)) {
        Show-CoverTool -Arguments $arguments -Failure $failure
        if ($Open) {
            Invoke-Item -LiteralPath $plan
        }
        return
    }

    # In a dry run the tool is still asked: it makes the covers, puts them on the contact sheet and leaves the
    # posts alone.
    if (-not $PSCmdlet.ShouldProcess($postsPath, "Give the posts of $plan a cover in the house style")) {
        $arguments += '--dry-run'
        Show-CoverTool -Arguments $arguments -Failure $failure
        if ($Open -and (Test-Path -LiteralPath $sheetFile)) {
            Invoke-Item -LiteralPath $sheetFile
        }
        return
    }

    # This changes many posts at once, so it asks first, whatever the session is set to.
    $question = "Give every post in $plan that is not skipped its cover, and point its front matter to it?"
    if (-not $PSCmdlet.ShouldContinue($question, 'The posts from before the house style')) {
        return
    }
    Show-CoverTool -Arguments $arguments -Failure $failure
    return
}

if ($Refresh -or $All) {
    # A cover is one of this script when the front matter of its post points to images/cover.jpg.
    $arguments = @('refresh', $postsPath, $pagesPath)
    if ($All) {
        $arguments += '--all'
    }
    # In a dry run the tool is still asked, so that it can say which covers it would make. It writes nothing.
    if (-not $PSCmdlet.ShouldProcess($postsPath, 'Make the covers that are behind')) {
        $arguments += '--dry-run'
    }
    Show-CoverTool -Arguments $arguments -Failure 'Not every cover could be made.'
    return
}

$folder = (Resolve-Path -LiteralPath $Post).Path
$index = Join-Path -Path $folder -ChildPath 'index.md'
if (-not (Test-Path -LiteralPath $index)) {
    throw "$Post has no index.md: give the folder of a post or a page."
}

if ($Picture) {
    $output = Join-Path -Path $folder -ChildPath "images/$Name"
    if ($PSCmdlet.ShouldProcess($output, 'Write the picture')) {
        $source = (Resolve-Path -LiteralPath $Picture).Path
        Show-CoverTool -Arguments 'picture', $source, $output -Failure 'The picture could not be made.'
        Write-Information -MessageData "In the post: ![What the picture shows](images/$Name)"
        if ($Open) {
            Invoke-Item -LiteralPath $output
        }
    }
    return
}

$output = Join-Path -Path $folder -ChildPath 'images/cover.jpg'
$arguments = @('cover', $folder)
if ($Image) {
    # -Focus 0.5,0.4 arrives as two numbers from the command line and as one text from a script or a workflow.
    $point = @(($Focus -join ',') -split '[,\s]+' | Where-Object -FilterScript { $_ })
    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    $number = 0.0
    $valid = $point.Count -eq 2
    foreach ($part in $point) {
        $valid = $valid -and [double]::TryParse($part, 'Float', $invariant, [ref] $number) -and
            $number -ge 0 -and $number -le 1
    }
    if (-not $valid) {
        throw "-Focus takes two numbers from 0 to 1, such as 0.5,0.4. This is not that: $($Focus -join ',')"
    }
    $arguments += '--image', (Resolve-Path -LiteralPath $Image).Path, '--focus', ($point -join ',')
}
if ($PSCmdlet.ShouldProcess($output, 'Write the cover')) {
    Show-CoverTool -Arguments $arguments -Failure 'The cover could not be made.'

    # The front matter is the author's: say what it should have, and leave it alone.
    $frontMatter = Get-Content -LiteralPath $index -TotalCount 40
    if (-not ($frontMatter -match '^feature_image:\s*["'']?images/cover\.jpg["'']?\s*$')) {
        Write-Warning -Message "$index does not point to this cover yet. Give it: feature_image: images/cover.jpg"
    }
    if (-not ($frontMatter -match '^feature_image_alt:\s*[^\s''"]')) {
        Write-Warning -Message "feature_image_alt is empty in $index. Say in a sentence what the cover shows."
    }

    if ($Open) {
        Invoke-Item -LiteralPath $output
    }
}
