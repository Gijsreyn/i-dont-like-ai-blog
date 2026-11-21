<#
.SYNOPSIS
    Gives the theme of the site that is connected the settings of this repository.

.DESCRIPTION
    The theme has settings of its own, the ones under Settings > Design in Ghost Admin: fonts, the layout, a few
    addresses. They are in two files:

    theme-settings.psd1         in the repository, for what everybody may know.
    theme-settings.local.psd1   on this machine only, which git ignores, for what is a secret or differs per
                                site, such as the Content API key. A value here wins from the other file.

    A workflow has no second file. It passes such a value as an environment variable, filled from a secret of the
    repository: GHOST_THEME_SETTING_ followed by the key in capitals, such as GHOST_THEME_SETTING_CONTENT_API_KEY.
    That wins from both files, for every key of the files and of PrivateThemeSettings in site.psd1.

    Only a setting whose value differs from the one on the site is sent, and a setting that is in neither file is
    left as it is on the site.

    Ghost lets only an owner or an administrator do this: the connection has to be one with a staff access token,
    not with the key of an integration. The caller connects, and connects again as it wants afterwards.

.EXAMPLE
    & "$PSScriptRoot/tools/Set-ThemeSetting.ps1" -Site $site

    Sends the settings that differ and says which ones, without their values.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([void])]
param(
    # The settings of this repository, as tools/Initialize-Site.ps1 returns them.
    [Parameter(Mandatory)]
    [hashtable] $Site
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$local = $Site.ThemeSettingsPath -replace '\.psd1$', '.local.psd1'
$wanted = @{}
foreach ($file in $Site.ThemeSettingsPath, $local) {
    if ($file -and (Test-Path -LiteralPath $file)) {
        $values = Import-PowerShellDataFile -Path $file
        foreach ($key in $values.Keys) {
            $wanted[$key] = $values[$key]
        }
    }
}

# 3. The environment, which is how a workflow passes a secret: GHOST_THEME_SETTING_ followed by the key in capitals.
foreach ($key in @($wanted.Keys) + @($Site.PrivateThemeSettings) | Where-Object { $_ } | Select-Object -Unique) {
    $value = [System.Environment]::GetEnvironmentVariable('GHOST_THEME_SETTING_{0}' -f $key.ToUpperInvariant())
    if ($value) {
        $wanted[$key] = $value
    }
}
if ($wanted.Count -eq 0) {
    return
}

# -WhatIf of this script does not reach the commands of a module by itself, so it is passed on by name. The
# values are not shown: one of them can be a secret, and a workflow keeps what it prints.
$changed = @(Set-GhostThemeSetting -Setting $wanted -WhatIf:$WhatIfPreference -Confirm:$false)
if ($changed.Count -gt 0) {
    $keys = @($changed | ForEach-Object { $_.key }) -join ', '
    Write-Information -MessageData "Settings of the theme that were changed: $keys." -InformationAction Continue
}
elseif (-not $WhatIfPreference) {
    Write-Information -MessageData 'The settings of the theme are up to date.' -InformationAction Continue
}
else {
    # A dry run returns nothing, also when nothing would change. Say which of the two it was.
    $differs = @(
        foreach ($setting in Get-GhostThemeSetting -Key @($wanted.Keys)) {
            if ("$($wanted[$setting.key])" -ne "$($setting.value)") {
                $setting.key
            }
        }
    )
    if ($differs.Count -eq 0) {
        Write-Information -MessageData 'The settings of the theme are up to date.' -InformationAction Continue
    }
}
