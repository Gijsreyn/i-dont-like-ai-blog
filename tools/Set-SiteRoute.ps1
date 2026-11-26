<#
.SYNOPSIS
    Gives a site the routes of the theme, when they differ.

.DESCRIPTION
    The theme has templates of its own for certain addresses, such as /books/ and /courses/. Which address shows
    which template is in its routes.yaml. Ghost keeps the routes of a site apart from its theme, so a theme that
    is uploaded does not bring them: without this script a changed routes.yaml is uploaded by hand, under
    Settings > Labs in Ghost Admin.

    The routes come from the package of the theme, which holds its routes.yaml: the routes that go to the site
    are the ones that theme was made and tested with. They are compared with the routes of the site as text,
    whatever the line endings, and only sent when they differ. Ghost keeps a copy of the routes it had.

    A package without a routes.yaml, which is one from before the theme packed it, leaves the routes as they are.

    Ghost lets only an owner or an administrator read and change the routes: it takes a staff access token, not
    the key of an integration.

.EXAMPLE
    & "$PSScriptRoot/tools/Set-SiteRoute.ps1" -Url $address -StaffAccessToken $staffKey -ThemePackage $package

    Sends the routes of the package when the site has other ones, and says what it did.

.EXAMPLE
    & "$PSScriptRoot/tools/Set-SiteRoute.ps1" -Url $address -StaffAccessToken $staffKey -ThemePackage $package -WhatIf

    Only says whether the routes differ.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([pscustomobject])]
param(
    # The address of the site.
    [Parameter(Mandatory)]
    [string] $Url,

    # A staff access token of an owner or an administrator of that site.
    [Parameter(Mandatory)]
    [securestring] $StaffAccessToken,

    # The package of the theme: its zip file, or its folder.
    [Parameter(Mandatory)]
    [string] $ThemePackage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Url = $Url.TrimEnd('/')
$result = [ordered]@{ Action = 'Skipped'; Url = $Url; Routes = $null }

# 1. The routes of the theme: routes.yaml in the folder, or in the zip file, where a zip may have one folder
# around everything.
$wanted = $null
if (Test-Path -LiteralPath $ThemePackage -PathType Container) {
    $file = Join-Path -Path $ThemePackage -ChildPath 'routes.yaml'
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        $wanted = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $file).ProviderPath)
    }
}
elseif (Test-Path -LiteralPath $ThemePackage -PathType Leaf) {
    Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
    $zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ThemePackage).ProviderPath)
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -match '^([^/\\]+[/\\])?routes\.yaml$' } | Select-Object -First 1
        if ($entry) {
            $stream = $entry.Open()
            try {
                $memory = [System.IO.MemoryStream]::new()
                $stream.CopyTo($memory)
                $wanted = $memory.ToArray()
            }
            finally {
                $stream.Dispose()
            }
        }
    }
    finally {
        $zip.Dispose()
    }
}
else {
    throw "The package of the theme is not there: $ThemePackage"
}

if (-not $wanted) {
    Write-Information -MessageData "The package of the theme holds no routes.yaml: the routes of $Url are left as they are."
    return [pscustomobject] $result
}
$result['Routes'] = $ThemePackage

# 2. Signing in with the staff access token: a short note, signed with the secret of the token, as for a key of
# an integration. Ghost reads from it who is asking.
$plain = [System.Net.NetworkCredential]::new('', $StaffAccessToken).Password
$id, $secret = $plain -split ':', 2
if (-not $id -or $secret -notmatch '^[0-9a-fA-F]+$') {
    throw 'The staff access token does not look like one: it is an ID and a secret with a colon between them.'
}

function ConvertTo-Base64Url {
    param([byte[]] $Bytes)

    [System.Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

$key = [byte[]] ($secret -split '(..)' -ne '' | ForEach-Object { [System.Convert]::ToByte($_, 16) })
$now = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$head = ConvertTo-Base64Url -Bytes ([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -Compress -InputObject ([ordered]@{ alg = 'HS256'; typ = 'JWT'; kid = $id }))))
$body = ConvertTo-Base64Url -Bytes ([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -Compress -InputObject ([ordered]@{ iat = $now; exp = $now + 300; aud = '/admin/' }))))
$hmac = [System.Security.Cryptography.HMACSHA256]::new($key)
try {
    $signature = ConvertTo-Base64Url -Bytes $hmac.ComputeHash([System.Text.Encoding]::ASCII.GetBytes("$head.$body"))
}
finally {
    $hmac.Dispose()
}
$headers = @{ Authorization = "Ghost $head.$body.$signature" }
$address = "$Url/ghost/api/admin/settings/routes/yaml/"

function Invoke-Route {
    # One request for the routes, which stops with what Ghost said when it refuses.
    param([hashtable] $Request)

    try {
        Invoke-WebRequest @Request -Uri $address -Headers $headers -UseBasicParsing
    }
    catch {
        $detail = $_.Exception.Message
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            try {
                $reported = @((ConvertFrom-Json -InputObject $_.ErrorDetails.Message).errors)[0]
                $detail = (@($reported.message, $reported.context) -join ' ').Trim()
            }
            catch {
                Write-Debug -Message "The answer is not an error of Ghost: $($_.Exception.Message)"
            }
        }
        $advice = 'Reading and changing the routes takes the staff access token of an owner or an administrator.'
        throw "Ghost refused the routes of $Url ($($Request.Method)): $detail $advice"
    }
}

# 3. The routes of the site. They come as a file, which is bytes for one PowerShell and text for the other.
$answer = (Invoke-Route -Request @{ Method = 'Get' }).Content
$current = if ($answer -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($answer) } else { [string] $answer }

$normalize = { param($Text) ($Text -replace '\r\n?', "`n").Trim().TrimStart([char] 0xFEFF) }
if ((& $normalize $current) -ceq (& $normalize ([System.Text.Encoding]::UTF8.GetString($wanted)))) {
    $result['Action'] = 'Unchanged'
    Write-Information -MessageData "The routes of $Url are those of the theme already."
    return [pscustomobject] $result
}

# 4. They differ: the routes of the theme go to the site, as the form that Ghost Admin sends.
if (-not $PSCmdlet.ShouldProcess($Url, 'Replace the routes by those of the theme')) {
    $result['Action'] = 'WouldUpdate'
    return [pscustomobject] $result
}

$boundary = 'routes{0}' -f [guid]::NewGuid().ToString('N')
$lead = "--$boundary`r`nContent-Disposition: form-data; name=`"routes`"; filename=`"routes.yaml`"`r`nContent-Type: application/x-yaml`r`n`r`n"
$form = [System.IO.MemoryStream]::new()
foreach ($part in [System.Text.Encoding]::ASCII.GetBytes($lead), $wanted, [System.Text.Encoding]::ASCII.GetBytes("`r`n--$boundary--`r`n")) {
    $form.Write($part, 0, $part.Length)
}

Invoke-Route -Request @{ Method = 'Post'; Body = $form.ToArray(); ContentType = "multipart/form-data; boundary=$boundary" } | Out-Null

$result['Action'] = 'Updated'
Write-Information -MessageData "The routes of $Url are now those of the theme."
[pscustomobject] $result
