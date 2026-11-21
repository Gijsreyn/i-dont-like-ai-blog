<#
.SYNOPSIS
    Returns a key of the live site, at the moment a script needs it.

.DESCRIPTION
    A key of the live site is not written in a file of this repository. publish.ps1 and preview.ps1 -FromLive ask
    this script for it when they are about to use it, and it looks in three places:

    1. The environment variable, which is how a workflow passes a secret:
       GHOST_LIVE_ADMIN_API_KEY or GHOST_LIVE_STAFF_ACCESS_TOKEN.
    2. A secret with that same name in a vault of the module Microsoft.PowerShell.SecretManagement, when that
       module is on this machine. SecretVault in site.local.psd1 names the vault; without it every vault is tried.
    3. You: the script asks for the key, and does not show what you type. It does not ask in a workflow.

    The key is returned as a SecureString and is not stored anywhere by this script.

.EXAMPLE
    $key = & "$PSScriptRoot/tools/Get-SiteSecret.ps1" -Site $site -Name 'LiveAdminApiKey'

    Returns the Admin API key of the live site.

.EXAMPLE
    Set-Secret -Name 'GHOST_LIVE_ADMIN_API_KEY' -Secret (Read-Host -AsSecureString)

    Stores the key in your vault, once, so that the scripts find it from then on.
#>
[CmdletBinding()]
[OutputType([securestring])]
param(
    # The settings, as tools/Initialize-Site.ps1 returns them.
    [Parameter(Mandatory)]
    [hashtable] $Site,

    # Which key.
    [Parameter(Mandatory)]
    [ValidateSet('LiveAdminApiKey', 'LiveStaffAccessToken')]
    [string] $Name,

    # Return nothing when the key is not in the environment or in a vault, instead of asking for it or stopping.
    [switch] $Optional
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$variables = @{
    LiveAdminApiKey      = 'GHOST_LIVE_ADMIN_API_KEY'
    LiveStaffAccessToken = 'GHOST_LIVE_STAFF_ACCESS_TOKEN'
}
$descriptions = @{
    LiveAdminApiKey      = 'the Admin API key of the live site (Ghost Admin > Settings > Integrations)'
    LiveStaffAccessToken = 'your staff access token of the live site (Ghost Admin > your profile)'
}
$variable = $variables[$Name]

# 1. The environment, which Initialize-Site.ps1 has read into the settings.
if ($Site[$Name]) {
    return [System.Net.NetworkCredential]::new('', [string] $Site[$Name]).SecurePassword
}

# 2. A vault.
if (Get-Command -Name 'Get-Secret' -ErrorAction SilentlyContinue) {
    $query = @{ Name = $variable }
    if ($Site['SecretVault']) {
        $query['Vault'] = $Site['SecretVault']
    }
    $secret = Get-Secret @query -ErrorAction SilentlyContinue
    if ($secret -is [securestring]) {
        return $secret
    }
    if ($secret -is [string] -and $secret) {
        return [System.Net.NetworkCredential]::new('', $secret).SecurePassword
    }
}

if ($Optional) {
    return
}

# 3. The person at the keyboard.
$unattended = $env:CI -or $env:TF_BUILD -or [System.Console]::IsInputRedirected
if (-not $unattended) {
    try {
        $answer = Read-Host -Prompt "Paste $($descriptions[$Name])" -AsSecureString
    }
    catch {
        # A session that was started with -NonInteractive cannot ask.
        $answer = $null
    }
    if ($answer -and $answer.Length -gt 0) {
        $store = "Set-Secret -Name '$variable'"
        Write-Information -MessageData "To not be asked again, store it in a vault: $store" -InformationAction Continue
        return $answer
    }
}

$missing = "This needs $($descriptions[$Name])."
throw "$missing Set the environment variable $variable, or store a secret with that name in a vault. See README.md."
