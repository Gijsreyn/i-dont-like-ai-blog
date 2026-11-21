<#
.SYNOPSIS
    Reads the settings of this repository and loads the Ghost module.

.DESCRIPTION
    preview.ps1 and publish.ps1 start with this. It returns the settings as one table, taken from three places.
    A later one wins from an earlier one:

    1. site.psd1, which is in the repository and holds what everybody may know.
    2. site.local.psd1, which git ignores: where the theme comes from, on your own machine.
       site.local.example.psd1 shows what can be in it. The keys of the live site are not in it:
       tools/Get-SiteSecret.ps1 fetches those when a script needs them.
    3. Environment variables, which is how a workflow passes its secrets:

       GHOST_LIVE_URL                  the address of the live site
       GHOST_LIVE_ADMIN_API_KEY        the Admin API key of an integration of the live site
       GHOST_LIVE_STAFF_ACCESS_TOKEN   the staff access token of an owner or administrator, to copy the live site
       GHOST_THEME_PATH                a folder with the theme, on this machine
       GHOST_THEME_REPOSITORY          the address of the git repository of the theme
       AZURE_DEVOPS_ORGANIZATION       the Azure DevOps organization that has the package of the theme
       AZURE_DEVOPS_PROJECT            the project of the feed
       AZURE_ARTIFACTS_FEED            the feed

    The tooling itself is not in this repository. The Ghost module comes from the PowerShell Gallery and is
    installed for the current user when it is missing or too old. To work with a module that is not published
    yet, point the environment variable GHOST_MODULE_PATH at its folder.

.EXAMPLE
    $site = & "$PSScriptRoot/tools/Initialize-Site.ps1"

    Returns the settings and makes the commands of the Ghost module available.
#>
[CmdletBinding()]
[OutputType([hashtable])]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Path $PSScriptRoot -Parent
$settings = Import-PowerShellDataFile -Path (Join-Path -Path $root -ChildPath 'site.psd1')

$localFile = Join-Path -Path $root -ChildPath 'site.local.psd1'
if (Test-Path -LiteralPath $localFile) {
    $local = Import-PowerShellDataFile -Path $localFile
    foreach ($name in $local.Keys) {
        $settings[$name] = $local[$name]
    }
}

$fromEnvironment = @{
    GHOST_LIVE_URL                = 'LiveUrl'
    GHOST_LIVE_ADMIN_API_KEY      = 'LiveAdminApiKey'
    GHOST_LIVE_STAFF_ACCESS_TOKEN = 'LiveStaffAccessToken'
    GHOST_THEME_PATH              = 'ThemePath'
    GHOST_THEME_REPOSITORY        = 'ThemeRepository'
    AZURE_DEVOPS_ORGANIZATION     = 'ThemeFeedOrganization'
    AZURE_DEVOPS_PROJECT          = 'ThemeFeedProject'
    AZURE_ARTIFACTS_FEED          = 'ThemeFeed'
}
foreach ($variable in $fromEnvironment.Keys) {
    $value = [System.Environment]::GetEnvironmentVariable($variable)
    if ($value) {
        $settings[$fromEnvironment[$variable]] = $value
    }
}

# Every setting has a value, so that a script can read it without asking whether it is there.
$names = @(
    'LiveUrl', 'LiveAdminApiKey', 'LiveStaffAccessToken', 'PostsPath', 'PagesPath', 'TagsPath', 'GhostVersion'
    'LocalPath', 'LocalPort', 'ThemeName', 'ThemePath', 'ThemeRepository', 'ThemeFeedOrganization'
    'ThemeFeedProject', 'ThemeFeed', 'ThemeFeedToken', 'SecretVault', 'ThemeSettingsPath', 'PrivateThemeSettings'
)
foreach ($name in $names) {
    if (-not $settings.ContainsKey($name)) {
        $settings[$name] = $null
    }
}

# Paths in the settings are relative to the root of the repository.
$settings['Root'] = $root
foreach ($name in 'PostsPath', 'PagesPath', 'TagsPath', 'LocalPath', 'ThemePath', 'ThemeSettingsPath') {
    if ($settings[$name] -and -not [System.IO.Path]::IsPathRooted($settings[$name])) {
        $settings[$name] = [System.IO.Path]::GetFullPath((Join-Path -Path $root -ChildPath $settings[$name]))
    }
}

# The Ghost module.
$minimum = [version] $settings['GhostVersion']
if ($env:GHOST_MODULE_PATH) {
    Import-Module -Name $env:GHOST_MODULE_PATH -Force
}
else {
    $installed = Get-Module -Name 'Ghost' -ListAvailable | Where-Object { $_.Version -ge $minimum }
    if (-not $installed) {
        $message = "Installing the Ghost module, version $minimum or later."
        Write-Information -MessageData $message -InformationAction Continue
        try {
            $install = @{
                Name       = 'Ghost'
                Version    = "$minimum"
                Scope      = 'CurrentUser'
                Repository = 'PSGallery'
            }
            Install-PSResource @install -TrustRepository
        }
        catch {
            $failure = "The Ghost module $minimum or later could not be installed from the PowerShell Gallery."
            $advice = 'When that version is not published yet, set GHOST_MODULE_PATH to the folder of the module.'
            throw "$failure $advice $($_.Exception.Message)"
        }
    }
    Import-Module -Name 'Ghost' -MinimumVersion $minimum
}

$settings
