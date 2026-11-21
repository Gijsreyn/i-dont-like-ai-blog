<#
.SYNOPSIS
    Writes the settings of the theme of the site that is connected to the files of this repository.

.DESCRIPTION
    Reads the settings of the active theme, the ones under Settings > Design in Ghost Admin, and writes them to
    two files:

    theme-settings.psd1         every setting that everybody may know. It is in the repository.
    theme-settings.local.psd1   the settings that site.psd1 lists under PrivateThemeSettings: a secret, or a value
                                that differs per site. Git ignores this file.

    A file that is the same already is left alone. A file that differs is only overwritten with -Force.

    Ghost lets only an owner or an administrator read these settings: the connection has to be one with a staff
    access token.

.EXAMPLE
    & "$PSScriptRoot/tools/Save-ThemeSetting.ps1" -Site $site

    Writes the two files and returns what happened to each.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([pscustomobject])]
param(
    # The settings of this repository, as tools/Initialize-Site.ps1 returns them.
    [Parameter(Mandatory)]
    [hashtable] $Site,

    # Overwrite a file that differs from the site.
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$private = @($Site.PrivateThemeSettings | Where-Object { $_ })
$settings = @(Get-GhostThemeSetting)
$files = @(
    @{
        Path     = $Site.ThemeSettingsPath
        Settings = @($settings | Where-Object { $private -notcontains $_.key })
        Header   = 'The settings of the theme, as under Settings > Design in Ghost Admin. Everything here is public.'
    }
    @{
        Path     = $Site.ThemeSettingsPath -replace '\.psd1$', '.local.psd1'
        Settings = @($settings | Where-Object { $private -contains $_.key })
        Header   = 'Settings of the theme that are not for the repository. Git ignores this file.'
    }
)

foreach ($file in $files) {
    if ($file.Settings.Count -eq 0) {
        continue
    }

    $width = ($file.Settings | ForEach-Object { $_.key.Length } | Measure-Object -Maximum).Maximum
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('@{')
    $lines.Add("    # $($file.Header)")
    foreach ($setting in $file.Settings) {
        $value = if ($setting.type -eq 'boolean') {
            if ($setting.value) { '$true' } else { '$false' }
        }
        else {
            "'{0}'" -f ([string] $setting.value).Replace("'", "''")
        }
        $lines.Add('')
        $description = $setting.PSObject.Properties['description']
        if ($description -and $description.Value) {
            $lines.Add("    # $($description.Value)")
        }
        $options = $setting.PSObject.Properties['options']
        if ($options -and $options.Value) {
            $lines.Add("    # One of: $(@($options.Value) -join ', ')")
        }
        $lines.Add(('    {0} = {1}' -f $setting.key.PadRight($width), $value))
    }
    $lines.Add('}')
    $content = ($lines -join "`n") + "`n"

    $action = 'Created'
    if (Test-Path -LiteralPath $file.Path) {
        $existing = [System.IO.File]::ReadAllText($file.Path, [System.Text.Encoding]::UTF8)
        if (($existing -replace '\r\n?', "`n") -ceq $content) {
            $action = 'Unchanged'
        }
        elseif ($Force) {
            $action = 'Updated'
        }
        else {
            $action = 'Skipped'
        }
    }
    if (@('Created', 'Updated') -contains $action) {
        if (-not $PSCmdlet.ShouldProcess($file.Path, 'Write the settings of the theme')) {
            continue
        }
        [System.IO.File]::WriteAllText($file.Path, $content, [System.Text.UTF8Encoding]::new($false))
    }

    [pscustomobject]@{
        Action   = $action
        Settings = $file.Settings.Count
        Path     = $file.Path
    }
}
