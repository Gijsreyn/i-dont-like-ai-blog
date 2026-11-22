<#
.SYNOPSIS
    Downloads the newest package of the theme from Azure Artifacts and returns the zip file.

.DESCRIPTION
    The pipeline of the theme builds the theme, checks it and publishes it to a feed in Azure Artifacts as a
    Universal Package that holds one zip file. This script downloads the newest version of that package with the
    Azure CLI, which is the only way to download a Universal Package.

    The Azure CLI signs in to Azure DevOps with what it has: your own sign-in (az login) on your machine, or a
    personal access token with the scope Packaging (Read) in the environment variable AZURE_DEVOPS_EXT_PAT, which
    is how a workflow does it, or in -Token, which publish.ps1 fills from ThemeFeedToken in site.local.psd1.

.EXAMPLE
    ./tools/Get-ThemePackage.ps1 -Organization https://dev.azure.com/my-org -Feed my-feed -Name my-theme

    Downloads the newest package my-theme from a feed of the organization and returns its zip file. Add -Project
    for a feed of a project.
#>
[CmdletBinding()]
[OutputType([System.IO.FileInfo])]
param(
    # The address of the Azure DevOps organization, such as https://dev.azure.com/my-org.
    [Parameter(Mandatory)]
    [string] $Organization,

    # The project of the feed. Leave it out for a feed of the organization.
    [string] $Project,

    # The feed.
    [Parameter(Mandatory)]
    [string] $Feed,

    # The name of the package, which is the name of the theme.
    [Parameter(Mandatory)]
    [string] $Name,

    # The version to download. A wildcard takes the newest: * for the newest of all, 1.* for the newest 1.x.
    [string] $Version = '*',

    # The folder to download to. Defaults to a new folder for temporary files.
    [string] $Path,

    # A personal access token with the scope Packaging (Read), for when AZURE_DEVOPS_EXT_PAT is not set. Without
    # either the Azure CLI uses your own sign-in.
    [string] $Token
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command -Name 'az' -ErrorAction SilentlyContinue)) {
    $install = 'Install it from https://aka.ms/azure-cli.'
    throw "The Azure CLI (az) is needed to download the theme from Azure Artifacts. $install"
}

if (-not $Path) {
    $folder = 'ghost-theme-{0}' -f [guid]::NewGuid().ToString('N')
    $Path = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $folder
}
# Also in a dry run of publish.ps1: the download changes nothing on the site, and the dry run needs the package.
New-Item -Path $Path -ItemType Directory -Force -WhatIf:$false | Out-Null

# The version goes in one argument with its option. On Linux and macOS, PowerShell expands a wildcard in an
# argument of a program to the files that match it, as a shell does there: a version of * by itself became every
# file in the current folder. Nothing matches --version=*, so that one stays as it is.
$arguments = @(
    'artifacts', 'universal', 'download'
    '--organization', $Organization
    '--feed', $Feed
    '--name', $Name
    "--version=$Version"
    '--path', $Path
)
if ($Project) {
    $arguments += '--project', $Project, '--scope', 'project'
}

# The extension for Azure DevOps is installed on first use, without a question.
$env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = 'yes_without_prompt'

# The Azure CLI only reads the token from the environment. It is set for this download and taken away again.
$lendToken = $Token -and -not $env:AZURE_DEVOPS_EXT_PAT
if ($lendToken) {
    $env:AZURE_DEVOPS_EXT_PAT = $Token
}
try {
    & az @arguments | Out-Null
}
finally {
    if ($lendToken) {
        Remove-Item -Path 'Env:AZURE_DEVOPS_EXT_PAT' -ErrorAction SilentlyContinue
    }
}
if ($LASTEXITCODE -ne 0) {
    $where = 'in AZURE_DEVOPS_EXT_PAT or as ThemeFeedToken in site.local.psd1'
    $hint = "Sign in with az login, or put a personal access token with the scope Packaging (Read) $where."
    $hint = "$hint A token that has ended fails the same way."
    throw "The package $Name could not be downloaded from the feed $Feed (az ended with $LASTEXITCODE). $hint"
}

$package = @(Get-ChildItem -LiteralPath $Path -Filter '*.zip' -File -Recurse | Select-Object -First 1)
if ($package.Count -eq 0) {
    throw "The package $Name was downloaded to $Path but holds no zip file."
}
$package[0]
