<#
.SYNOPSIS
    Syncs the secrets of the workflow Publish on GitHub with the values on this machine, when they are here.

.DESCRIPTION
    The workflow Publish needs a few secrets under Settings > Secrets and variables > Actions, see AGENTS.md.
    When their values are available on this machine, in site.local.psd1, in theme-settings.local.psd1, in the
    environment or in a vault, you do not have to type them in on GitHub: use this script to get them synced. It
    reads them where the other scripts read them and hands them to the GitHub CLI, gh secret set. A secret that
    exists is overwritten with the value of this machine, so run it again whenever a value here changes.

    | Secret                        | Where its value comes from, the first that has one                       |
    | ----------------------------- | ------------------------------------------------------------------------ |
    | GHOST_LIVE_ADMIN_API_KEY      | The environment, LiveAdminApiKey in site.local.psd1, your vault          |
    | AZURE_DEVOPS_EXT_PAT          | The environment, ThemeFeedToken in site.local.psd1                       |
    | AZURE_DEVOPS_ORGANIZATION     | The environment, ThemeFeedOrganization in site.local.psd1                |
    | AZURE_DEVOPS_PROJECT          | The environment, ThemeFeedProject in site.local.psd1                     |
    | AZURE_ARTIFACTS_FEED          | The environment, ThemeFeed in site.local.psd1                            |

    With -ThemeSettings also the secrets that let the workflow send the settings of the theme:

    | GHOST_LIVE_STAFF_ACCESS_TOKEN | The environment, LiveStaffAccessToken in site.local.psd1, your vault     |
    | GHOST_THEME_SETTING_<KEY>     | The environment, theme-settings.local.psd1: one for every key that is in |
    |                               | PrivateThemeSettings of site.psd1                                        |

    That is a switch because the staff access token may do everything its owner may do: giving it to the workflow
    is a decision, not a default. And theme-settings.local.psd1 has to hold the values of the live site, as
    ./pull.ps1 writes them, not those of the site on this machine: content_api_key differs per site.

    A value is not shown: the script prints the names, and where each value was found. It is passed to gh over
    its input, not on its command line. A secret without a value on this machine is listed as Missing and is left
    as it is on GitHub. The script connects to GitHub only, not to the live site.

    To check what would be sent, -WhatIf -ShowValue adds a column Value with every value in plain text. That is
    for your own eyes: not in a workflow, not while you share your screen, and not in a session that is recorded
    with Start-Transcript. -ShowValue does nothing without -WhatIf.

    Needs the GitHub CLI, https://cli.github.com, signed in with gh auth login as somebody who may change the
    secrets of the repository.

.EXAMPLE
    ./set-secrets.ps1 -WhatIf

    Shows which secrets would be set and where their values come from. Nothing is sent.

.EXAMPLE
    ./set-secrets.ps1 -ThemeSettings -WhatIf -ShowValue

    Shows every secret that would be set, with the value it would get, in plain text. Nothing is sent.

.EXAMPLE
    ./set-secrets.ps1

    Sets the Admin API key and the four secrets of the theme package.

.EXAMPLE
    ./set-secrets.ps1 -ThemeSettings

    Also sets the staff access token and the private settings of the theme.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    # Also set the staff access token and the private settings of the theme.
    [switch] $ThemeSettings,

    # With -WhatIf: add a column Value with the value each secret would get, in plain text.
    [switch] $ShowValue,

    # The repository on GitHub, as owner/name. Defaults to the one this folder was cloned from.
    [string] $Repository
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

if (-not (Get-Command -Name 'gh' -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'This needs the GitHub CLI: https://cli.github.com. Install it and sign in with gh auth login.'
}
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'The GitHub CLI is not signed in. Run gh auth login first.'
}

if (-not $Repository) {
    Push-Location -LiteralPath $PSScriptRoot
    try {
        $Repository = & gh repo view --json nameWithOwner --jq '.nameWithOwner'
    }
    finally {
        Pop-Location
    }
    if ($LASTEXITCODE -ne 0 -or -not $Repository) {
        throw 'The repository on GitHub could not be found from this folder. Name it with -Repository owner/name.'
    }
}

# The settings: site.psd1, then site.local.psd1, then the environment. The same as every other script.
$site = & (Join-Path -Path $PSScriptRoot -ChildPath 'tools/Initialize-Site.ps1')
$getSecret = Join-Path -Path $PSScriptRoot -ChildPath 'tools/Get-SiteSecret.ps1'

# The two local files once more, by themselves, only to be able to say where a value was found.
function Read-DataFile {
    param([string] $Path)

    if ($Path -and (Test-Path -LiteralPath $Path)) {
        return Import-PowerShellDataFile -Path $Path
    }
    @{}
}
$localSite = Read-DataFile -Path (Join-Path -Path $PSScriptRoot -ChildPath 'site.local.psd1')
$localThemeFile = "$($site.ThemeSettingsPath)" -replace '\.psd1$', '.local.psd1'
$localTheme = Read-DataFile -Path $localThemeFile

# Returns the value of a secret and where it was found: the environment variable, or else a key of a local file.
function Find-Value {
    param([string] $Variable, [hashtable] $File, [string] $Key, [string] $FileName)

    $value = [System.Environment]::GetEnvironmentVariable($Variable)
    if ($value) {
        return @{ Value = $value; From = 'The environment' }
    }
    if ($File.ContainsKey($Key) -and "$($File[$Key])") {
        return @{ Value = "$($File[$Key])"; From = $FileName }
    }
    @{ Value = $null; From = $null }
}

# A key of the live site: the environment, site.local.psd1, and then a vault, through tools/Get-SiteSecret.ps1.
function Find-SiteSecret {
    param([string] $Variable, [string] $Name)

    $found = Find-Value -Variable $Variable -File $localSite -Key $Name -FileName 'site.local.psd1'
    if ($found.Value) {
        return $found
    }
    $secure = & $getSecret -Site $site -Name $Name -Optional
    if ($secure) {
        return @{ Value = [System.Net.NetworkCredential]::new('', $secure).Password; From = 'A vault' }
    }
    $found
}

$secrets = [ordered] @{
    GHOST_LIVE_ADMIN_API_KEY = Find-SiteSecret -Variable 'GHOST_LIVE_ADMIN_API_KEY' -Name 'LiveAdminApiKey'
}
$feed = [ordered] @{
    AZURE_DEVOPS_EXT_PAT      = 'ThemeFeedToken'
    AZURE_DEVOPS_ORGANIZATION = 'ThemeFeedOrganization'
    AZURE_DEVOPS_PROJECT      = 'ThemeFeedProject'
    AZURE_ARTIFACTS_FEED      = 'ThemeFeed'
}
foreach ($variable in $feed.Keys) {
    $key = $feed[$variable]
    $secrets[$variable] = Find-Value -Variable $variable -File $localSite -Key $key -FileName 'site.local.psd1'
}

if ($ThemeSettings) {
    $variable = 'GHOST_LIVE_STAFF_ACCESS_TOKEN'
    $secrets[$variable] = Find-SiteSecret -Variable $variable -Name 'LiveStaffAccessToken'

    $fileName = Split-Path -Path $localThemeFile -Leaf
    foreach ($key in @($site.PrivateThemeSettings)) {
        $variable = 'GHOST_THEME_SETTING_{0}' -f $key.ToUpperInvariant()
        $secrets[$variable] = Find-Value -Variable $variable -File $localTheme -Key $key -FileName $fileName
    }
}

# The values are shown for a dry run only, and only when that is asked for.
$showValue = $ShowValue -and $WhatIfPreference
if ($ShowValue -and -not $showValue) {
    Write-Warning -Message '-ShowValue only works together with -WhatIf. The values are not shown.'
}
if ($showValue) {
    Write-Warning -Message 'The values below are secrets in plain text. Clear the screen when you have seen them.'
}
else {
    Write-Information -MessageData "Setting the secrets of $Repository. Their values are not shown."
}

$results = foreach ($name in $secrets.Keys) {
    $found = $secrets[$name]
    $action = 'Missing'
    if ($found.Value) {
        if ($PSCmdlet.ShouldProcess("$Repository on GitHub", "Set the secret $name")) {
            # Over the input of gh, so that the value is not on a command line. gh drops the line end after it.
            $found.Value | & gh secret set $name --repo $Repository | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "gh could not set the secret $name in $Repository. Its message is above."
            }
            $action = 'Set'
        }
        else {
            $action = $WhatIfPreference ? 'Would set' : 'Skipped'
        }
    }
    $result = [ordered] @{
        Secret = $name
        From   = $found.From
        Action = $action
    }
    if ($showValue) {
        $result['Value'] = $found.Value
    }
    [pscustomobject] $result
}
# A long value, such as an address with a signature, is wrapped instead of cut off.
$results | Format-Table -AutoSize -Wrap:$showValue

$missing = @($results | Where-Object { $_.Action -eq 'Missing' })
if ($missing.Count -gt 0) {
    $what = "$($missing.Count) of the secrets have no value on this machine and were left as they are on GitHub"
    Write-Information -MessageData "${what}. AGENTS.md says where each one comes from."
}
if (-not $ThemeSettings) {
    $what = 'The staff access token and the settings of the theme were not set'
    Write-Information -MessageData "${what}: run ./set-secrets.ps1 -ThemeSettings for those."
}
