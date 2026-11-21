<#
.SYNOPSIS
    Looks for a key, a token or another secret in the files that git does not ignore, and fails when there is one.

.DESCRIPTION
    This repository is public, so a secret in a file that git tracks is a secret for everybody. Two checks:

    1. Semgrep, with the secrets rules of its registry (p/secrets) and the rules in .semgrep/secrets.yml for what
       this repository deals with: a key of Ghost, the signature of a SAS of Azure Storage, a token of Azure DevOps.
       Semgrep is run with uv (uvx semgrep), which is installed for the current user when it is missing. The rules
       of the registry are downloaded, so this needs the internet; nothing about the repository is sent.
    2. The values themselves: what is in the files git ignores (site.local.psd1, theme-settings.local.psd1) and in
       the environment variables of the keys and the theme settings may not be in any other file, in any form a
       rule would not recognize.

    Files that git ignores are not looked at: that is where a secret may be. A finding is shown as a file, a line
    and a rule, never as its text.

.EXAMPLE
    ./tools/Test-Secret.ps1

    Checks the repository. preview.ps1 does this at its start, and the workflows do it before they publish.
#>
[CmdletBinding()]
[OutputType([void])]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Path $PSScriptRoot -Parent
$windows = $env:OS -eq 'Windows_NT'

# uv, which runs Semgrep without installing it. Its installer puts it in the folder .local/bin of the user.
$userBin = Join-Path -Path ([System.Environment]::GetFolderPath('UserProfile')) -ChildPath '.local/bin'
if (-not (Get-Command -Name 'uv' -ErrorAction SilentlyContinue)) {
    Write-Information -MessageData 'Installing uv, to run Semgrep with.' -InformationAction Continue
    if ($windows) {
        $installer = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'uv-install.ps1'
        Invoke-WebRequest -Uri 'https://astral.sh/uv/install.ps1' -OutFile $installer -UseBasicParsing
        try {
            & $installer | Out-Null
        }
        finally {
            Remove-Item -LiteralPath $installer -Force -ErrorAction SilentlyContinue
        }
    }
    else {
        & sh -c 'curl -LsSf https://astral.sh/uv/install.sh | sh' | Out-Null
    }
    $env:PATH = $userBin + [System.IO.Path]::PathSeparator + $env:PATH
    if (-not (Get-Command -Name 'uv' -ErrorAction SilentlyContinue)) {
        throw 'uv could not be installed. Install it from https://docs.astral.sh/uv/ and run this again.'
    }
}

$found = [System.Collections.Generic.List[string]]::new()

# 1. Semgrep. It leaves out what git ignores, and its answer is read as JSON so that no secret is printed.
$rules = Join-Path -Path $root -ChildPath '.semgrep/secrets.yml'
$arguments = @(
    'semgrep', 'scan'
    '--config', 'p/secrets'
    '--config', $rules
    '--metrics', 'off'
    '--json', '--quiet'
    $root
)
$env:PYTHONUTF8 = '1'
$log = 'semgrep-{0}.txt' -f [guid]::NewGuid().ToString('N')
$errors = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $log
try {
    $json = & uvx @arguments 2>$errors
    if ($LASTEXITCODE -ne 0) {
        $why = (Get-Content -LiteralPath $errors -Tail 5 -ErrorAction SilentlyContinue) -join ' '
        throw "Semgrep could not check the repository for secrets (it ended with $LASTEXITCODE). $why"
    }
}
finally {
    Remove-Item -LiteralPath $errors -Force -ErrorAction SilentlyContinue
}
$scan = ($json -join "`n") | ConvertFrom-Json
foreach ($result in $scan.results) {
    $file = [System.IO.Path]::GetFullPath($result.path).Substring($root.Length).TrimStart('\', '/')
    $rule = ($result.check_id -split '\.')[-1]
    $found.Add(('{0}:{1}  {2}' -f ($file -replace '\\', '/'), $result.start.line, $rule))
}

# 2. The values that are known to be private: in the ignored files and in the environment.
$private = @{}
$fromSite = 'LiveAdminApiKey', 'LiveStaffAccessToken', 'ThemeFeedToken', 'ThemeFeedOrganization', 'ThemeRepository'
$siteFile = Join-Path -Path $root -ChildPath 'site.local.psd1'
if (Test-Path -LiteralPath $siteFile) {
    $values = Import-PowerShellDataFile -Path $siteFile
    foreach ($name in $fromSite) {
        if ($values.ContainsKey($name)) {
            $private["$name in site.local.psd1"] = [string] $values[$name]
        }
    }
}
$themeFile = Join-Path -Path $root -ChildPath 'theme-settings.local.psd1'
if (Test-Path -LiteralPath $themeFile) {
    $values = Import-PowerShellDataFile -Path $themeFile
    foreach ($name in $values.Keys) {
        $private["$name in theme-settings.local.psd1"] = [string] $values[$name]
    }
}
$variables = @('GHOST_LIVE_ADMIN_API_KEY', 'GHOST_LIVE_STAFF_ACCESS_TOKEN', 'AZURE_DEVOPS_EXT_PAT')
$variables += @(Get-ChildItem -Path 'Env:GHOST_THEME_SETTING_*' | ForEach-Object { $_.Name })
foreach ($variable in $variables) {
    $private["the environment variable $variable"] = [System.Environment]::GetEnvironmentVariable($variable)
}

# A short value, such as a word, would be found everywhere and says nothing.
$names = @($private.Keys | Where-Object { $private[$_] -and $private[$_].Length -ge 8 })
if ($names.Count -gt 0) {
    $files = @(& git -C $root ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) {
        throw 'git could not list the files of the repository.'
    }
    foreach ($file in $files) {
        $path = Join-Path -Path $root -ChildPath $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            continue
        }
        foreach ($name in $names) {
            $hits = @(Select-String -LiteralPath $path -Pattern $private[$name] -SimpleMatch)
            foreach ($hit in $hits) {
                $found.Add(('{0}:{1}  the value of {2}' -f $file, $hit.LineNumber, $name))
            }
        }
    }
}

if ($found.Count -gt 0) {
    $list = ($found | Sort-Object -Unique) -join "`n  "
    $advice = 'Take it out of the file, and replace a key or a token that was ever committed: git keeps it.'
    throw "A secret is in a file that git does not ignore.`n  $list`n$advice"
}
Write-Information -MessageData 'No secrets in the files of the repository.' -InformationAction Continue
