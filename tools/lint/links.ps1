<#
.SYNOPSIS
    Links that lead nowhere: a file or a picture that is not there, an address that does not answer.

.DESCRIPTION
    Runs mlc, the markup link checker (https://github.com/becheran/mlc), over the Markdown files of the repository
    and returns what it found as the findings of ./lint.ps1.

    mlc is not installed: the build of the version below is downloaded from its releases on GitHub, once, into
    the folder for temporary files, and only used when it is the file that this script expects.

    It is given the Markdown and HTML files that git knows or would know, by name. What git ignores is left out
    that way, such as the Ghost site on this machine, which has more files than mlc gets through when it is
    pointed at the folder. So this needs git.

    What mlc leaves alone of what is in those files is in .mlc.toml, in the root of the repository: the addresses
    that never answer a program, and the time between two requests to one site.

    Good to know about mlc:

    - A link to a heading, #like-this, is not followed: only that the file is there.
    - A reference without its line, [text][99], is a warning and not an error.
    - The tags in the front matter and a line such as [!NOTE] look like such a reference to it. Those two are
      left out here.
    - A link without the address of the site, /courses/a-course/a-lesson/, is a file that is not there to it.
      Here it is right when its last part is the slug of a page, a post or a tag of the repository, and a
      warning when it is not.

.EXAMPLE
    ./lint.ps1 links

    The way to run this: ./lint.ps1 shows the findings.

.EXAMPLE
    ./lint.ps1 links -Offline

    Only the links to files and pictures of the repository, without the internet. That takes a second.
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    # Leave the addresses on the internet alone and only check the links to files.
    [switch] $Offline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

# The version of mlc, and for every build of it the file of the release and its SHA-256. For another version,
# change all three: the hashes are those of the files at
# https://github.com/becheran/mlc/releases/download/v<version>/<file>.
$version = '2.0.0'
$builds = @{
    'linux-x64'   = @{
        File = 'mlc-x86_64-linux'
        Hash = '6beb49ec68ea6c48ca945a3589f920aebf9b3e5e8ef17a4587fae628cf109748'
    }
    'linux-arm64' = @{
        File = 'mlc-aarch64-linux'
        Hash = '55f3b9436a5834fdc784b3dbb088d6cca2fe2a9150a5d7490fc5ca6781fb26bb'
    }
    'windows-x64' = @{
        File = 'mlc-x86_64-windows.exe'
        Hash = 'a2b9411c5679bfe599959e5fe509d9aa022afccd59f783d51abee98b074a2001'
    }
    'macos-x64'   = @{
        File = 'mlc-x86_64-apple-darwin'
        Hash = '44b060d5645f5b5b19fa207f55f1af8354107287e0baed95bab0ccdf897d85c5'
    }
    'macos-arm64' = @{
        File = 'mlc-aarch64-apple-darwin'
        Hash = '5b0e1f519461806e03d836f6fc483ae3ba3af11d49bfaaae8b5edbcef7d488e0'
    }
}

$system = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
$processor = "$([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)".ToLowerInvariant()
if ($system -eq 'windows') {
    # There is one build for Windows, which a machine with another processor runs as well.
    $processor = 'x64'
}
$build = $builds["$system-$processor"]
if (-not $build) {
    throw "There is no build of mlc $version for $system on $processor. See https://github.com/becheran/mlc."
}

# The file, downloaded once. A file that is not the expected one is never run.
$cache = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "mlc-$version"
$mlc = Join-Path -Path $cache -ChildPath $build.File
$isExpected = { param($path) (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $build.Hash }
if (-not (Test-Path -LiteralPath $mlc) -or -not (& $isExpected $mlc)) {
    $address = "https://github.com/becheran/mlc/releases/download/v$version/$($build.File)"
    Write-Information -MessageData "Downloading mlc $version from $address."
    New-Item -Path $cache -ItemType Directory -Force | Out-Null
    $download = "$mlc.download"
    Invoke-WebRequest -Uri $address -OutFile $download -UseBasicParsing
    if (-not (& $isExpected $download)) {
        Remove-Item -LiteralPath $download -Force
        throw "What came from $address is not the file this script expects: its SHA-256 differs. It was removed."
    }
    Move-Item -LiteralPath $download -Destination $mlc -Force
    if (-not $IsWindows) {
        & chmod +x $mlc
    }
}

# The files, by name: what git has, and what it would take. A file that was removed and is still known to git is
# not there to read.
if (-not (Get-Command -Name 'git' -ErrorAction SilentlyContinue)) {
    throw 'This linter asks git which files there are, and git is not installed.'
}
Push-Location -LiteralPath $root
try {
    $known = @(& git -c core.quotePath=false ls-files --cached --others --exclude-standard -- '*.md' '*.html')
    if ($LASTEXITCODE -ne 0) {
        throw 'git could not say which files there are. Is this the repository?'
    }
    $files = @($known | Sort-Object -Unique | Where-Object -FilterScript { Test-Path -LiteralPath $_ -PathType Leaf })

    # mlc takes the names with commas between them, so a name with a comma in it cannot be given.
    foreach ($file in $files | Where-Object -FilterScript { $_.Contains(',') }) {
        [pscustomobject] @{
            Severity = 'warning'
            File     = $file
            Line     = 0
            Column   = 0
            Message  = 'Not looked at: the name of the file has a comma in it, which mlc cannot be given.'
        }
    }
    $files = @($files | Where-Object -FilterScript { -not $_.Contains(',') })

    # In groups, so that a command never gets longer than a system takes. Each group is one run of mlc, which
    # answers with one JSON document. What it says besides that goes to a file, to show when it fails.
    $groups = [System.Collections.Generic.List[string]]::new()
    $group = ''
    foreach ($file in $files) {
        if ($group -and ($group.Length + $file.Length) -gt 6000) {
            $groups.Add($group)
            $group = ''
        }
        $group = if ($group) { "$group,$file" } else { $file }
    }
    if ($group) {
        $groups.Add($group)
    }

    $counted = @{ total = 0; ok = 0; skipped = 0 }
    $issues = [System.Collections.Generic.List[object]]::new()
    $said = [System.IO.Path]::GetTempFileName()
    try {
        foreach ($group in $groups) {
            $arguments = @('--format', 'json', '--files', $group)
            if ($Offline) {
                $arguments += '--offline'
            }
            $answer = (& $mlc @arguments . 2> $said) -join "`n"
            try {
                $report = $answer | ConvertFrom-Json
                foreach ($count in @($counted.Keys)) {
                    $counted[$count] += [int] $report.summary.$count
                }
                $issues.AddRange(@($report.issues))
            }
            catch {
                $why = (Get-Content -LiteralPath $said -Raw -ErrorAction SilentlyContinue), $answer -join ' '
                throw "mlc did not answer with its report. It said: $("$why".Trim())"
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $said -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Pop-Location
}

$looked = "mlc $version looked at $($counted.total) links in $($files.Count) files: $($counted.ok) are right"
Write-Information -MessageData "$looked, $($counted.skipped) were left alone."

# Where the front matter of a file ends, to know a tag from a link.
$frontMatter = @{}
function Get-FrontMatterEnd {
    param([string] $File)

    if (-not $frontMatter.ContainsKey($File)) {
        $end = 0
        $path = Join-Path -Path $root -ChildPath $File
        if (Test-Path -LiteralPath $path) {
            $lines = @(Get-Content -LiteralPath $path -TotalCount 60)
            if ($lines.Count -and $lines[0].Trim() -eq '---') {
                for ($index = 1; $index -lt $lines.Count; $index++) {
                    if ($lines[$index].Trim() -eq '---') {
                        $end = $index + 1
                        break
                    }
                }
            }
        }
        $frontMatter[$File] = $end
    }
    $frontMatter[$File]
}

# What the site names by a slug: a page and a post by the name of their folder, without the day in front of it for
# a post, and a tag by the name of its file. To know a path on the site from a file that is not there.
$slugs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($folder in 'pages', 'posts') {
    $path = Join-Path -Path $root -ChildPath $folder
    if (Test-Path -LiteralPath $path -PathType Container) {
        foreach ($item in Get-ChildItem -LiteralPath $path -Directory) {
            [void] $slugs.Add(($item.Name -replace '^\d{4}-\d{2}-\d{2}-', ''))
        }
    }
}
$path = Join-Path -Path $root -ChildPath 'tags'
if (Test-Path -LiteralPath $path -PathType Container) {
    foreach ($item in Get-ChildItem -LiteralPath $path -Filter '*.md' -File) {
        [void] $slugs.Add($item.BaseName)
    }
}

foreach ($issue in $issues) {
    # A link that starts with one / is a path on the site, /courses/a-course/a-lesson/, and not a file of the
    # repository, which is what mlc looks for. Its last part is the slug of a page, a post or a tag. When that
    # is one of this repository the link is right. When it is not, the path may still be one the theme makes,
    # such as /blog/: that is for a reader to look at, so it is a warning.
    if ("$($issue.target)" -match '^/(?!/)') {
        $slug = @(("$($issue.target)" -replace '[?#].*$', '') -split '/' | Where-Object { $_ }) | Select-Object -Last 1
        if (-not $slug -or $slugs.Contains($slug)) {
            continue
        }
        $issue.severity = 'warning'
        $issue.message = 'A path on the site that no page, post or tag here has the slug of'
    }

    # mlc names a file in full when it was given by name: from the root of the repository is what is shown.
    $file = "$($issue.source)"
    if ([System.IO.Path]::IsPathRooted($file)) {
        $file = [System.IO.Path]::GetRelativePath($root, $file)
    }
    $file = $file.Replace('\', '/') -replace '^\./'

    # Not a reference: the tags of the front matter, tags: ["A", "B"], and the mark of a note, > [!NOTE].
    if ($issue.message -eq 'Markdown reference not found') {
        $isMark = $issue.target -cmatch '^!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)$'
        if ($isMark -or [int] $issue.line -le (Get-FrontMatterEnd -File $file)) {
            continue
        }
    }

    [pscustomobject] @{
        Severity = if ($issue.severity -eq 'error') { 'error' } else { 'warning' }
        File     = $file
        Line     = [int] $issue.line
        Column   = [int] $issue.column
        Message  = "$($issue.target): $($issue.message)"
    }
}
