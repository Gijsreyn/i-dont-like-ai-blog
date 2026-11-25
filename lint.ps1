<#
.SYNOPSIS
    Runs the linters of this repository: the checks that read its files and say what is wrong in them.

.DESCRIPTION
    A linter is a script in the folder tools/lint, and its name is the name of that file: tools/lint/links.ps1 is
    the linter links. This script finds them, runs them and shows what they found, in the same way for each. The
    workflow Lint does the same for a pull request, with a job for every linter. Nothing here reaches a site.

    To add a linter, add a file. Nothing else has to change, not this script and not the workflow. The file:

    - has a name in lower case letters, digits and hyphens, and a .SYNOPSIS that says what it looks for;
    - is started in the root of the repository, and brings the tool it needs when that is not there yet;
    - returns a finding for everything that is wrong, and nothing else:

          [pscustomobject] @{
              Severity = 'error'               # or 'warning', which is shown and does not fail
              File     = 'posts/a-post/index.md'   # from the root of the repository, with forward slashes
              Line     = 12                    # 0 when the finding is about the whole file
              Column   = 3                     # 0 when it is about the whole line
              Message  = 'What is wrong, and with what'
          }

    - says what it likes with Write-Information, and throws when it could not do its work at all;
    - may take the switch -Offline, which it then gets when this script got it.

    The findings are shown as lines here, and in a workflow also as annotations on the lines of the pull request
    and as a table in the summary of the run. One error makes the run fail.

.EXAMPLE
    ./lint.ps1

    Runs every linter.

.EXAMPLE
    ./lint.ps1 links

    Runs the linter links and no other.

.EXAMPLE
    ./lint.ps1 -Offline

    Runs every linter without the internet: a linter that has -Offline skips what needs it.

.EXAMPLE
    ./lint.ps1 -List

    Returns the names of the linters. The workflow Lint makes its jobs from this.
#>
[CmdletBinding(DefaultParameterSetName = 'Run')]
param(
    # The linters to run. Defaults to all of them.
    [Parameter(Position = 0, ParameterSetName = 'Run')]
    [string[]] $Name,

    # Do not use the internet. Passed on to the linters that have this switch.
    [Parameter(ParameterSetName = 'Run')]
    [switch] $Offline,

    # Return the names of the linters and run nothing.
    [Parameter(Mandatory, ParameterSetName = 'List')]
    [switch] $List
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# A linter is a file whose name can be the name of a job: nothing in it that a shell or a workflow reads as more.
$folder = Join-Path -Path $PSScriptRoot -ChildPath 'tools/lint'
$linters = @(
    Get-ChildItem -LiteralPath $folder -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
        Where-Object -FilterScript { $_.BaseName -cmatch '^[a-z0-9][a-z0-9-]*$' } |
        Sort-Object -Property BaseName
)

if ($List) {
    $linters.BaseName
    return
}

if ($Name) {
    $unknown = @($Name | Where-Object -FilterScript { $_ -notin $linters.BaseName })
    if ($unknown) {
        throw "There is no linter $($unknown -join ', '). There is: $($linters.BaseName -join ', ')."
    }
    $linters = @($linters | Where-Object -FilterScript { $_.BaseName -in $Name })
}
if (-not $linters) {
    throw "There is no linter in $folder."
}

$inWorkflow = $env:GITHUB_ACTIONS -eq 'true'

function ConvertTo-WorkflowText {
    # What a workflow command of GitHub may hold as its text, and with -Property as one of its values.
    param([string] $Text, [switch] $Property)

    $Text = $Text.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
    if ($Property) {
        $Text = $Text.Replace(':', '%3A').Replace(',', '%2C')
    }
    $Text
}

$errors = 0
$summary = [System.Collections.Generic.List[string]]::new()

foreach ($linter in $linters) {
    $name = $linter.BaseName
    Write-Information -MessageData ''
    Write-Information -MessageData "--- $name"

    $arguments = @{}
    if ($Offline -and (Get-Command -Name $linter.FullName).Parameters.ContainsKey('Offline')) {
        $arguments['Offline'] = $true
    }

    # A linter that fails is a finding too, so that the linters after it still run.
    Push-Location -LiteralPath $PSScriptRoot
    try {
        $returned = @(& $linter.FullName @arguments)
    }
    catch {
        $returned = @([pscustomobject] @{
                Severity = 'error'
                File     = "tools/lint/$name.ps1"
                Line     = 0
                Column   = 0
                Message  = "The linter could not do its work: $($_.Exception.Message)"
            })
    }
    finally {
        Pop-Location
    }

    $findings = foreach ($item in $returned) {
        $properties = if ($null -ne $item) { $item.PSObject.Properties.Name } else { @() }
        if ('Severity' -in $properties -and 'Message' -in $properties) {
            [pscustomobject] @{
                Severity = if ("$($item.Severity)" -eq 'warning') { 'warning' } else { 'error' }
                File     = if ('File' -in $properties) { "$($item.File)".Replace('\', '/') } else { '' }
                Line     = if ('Line' -in $properties) { [int] $item.Line } else { 0 }
                Column   = if ('Column' -in $properties) { [int] $item.Column } else { 0 }
                Message  = "$($item.Message)"
            }
        }
        elseif ($null -ne $item) {
            # Not a finding: something the linter let slip. It is shown, and does not count.
            Write-Information -MessageData "$item"
        }
    }
    $findings = @($findings | Sort-Object -Property File, Line, Column)

    foreach ($finding in $findings) {
        $place = $finding.File
        if ($finding.Line -gt 0) {
            $place += ":$($finding.Line)"
            if ($finding.Column -gt 0) {
                $place += ":$($finding.Column)"
            }
        }
        Write-Information -MessageData ('{0,-8}{1}  {2}' -f $finding.Severity, $place, $finding.Message)

        if ($inWorkflow) {
            # An annotation, which GitHub shows on that line of the pull request.
            $values = @("title=$(ConvertTo-WorkflowText -Text $name -Property)")
            if ($finding.File) {
                $values += "file=$(ConvertTo-WorkflowText -Text $finding.File -Property)"
            }
            if ($finding.Line -gt 0) {
                $values += "line=$($finding.Line)"
                if ($finding.Column -gt 0) {
                    $values += "col=$($finding.Column)"
                }
            }
            $text = ConvertTo-WorkflowText -Text $finding.Message
            Write-Information -MessageData "::$($finding.Severity) $($values -join ',')::$text"
        }
        $cells = $name, $finding.Severity, $place, $finding.Message | ForEach-Object -Process { $_.Replace('|', '\|') }
        $summary.Add("| $($cells -join ' | ') |")
    }

    $wrong = @($findings | Where-Object -Property Severity -EQ -Value 'error').Count
    $errors += $wrong
    $warnings = $findings.Count - $wrong
    Write-Information -MessageData "${name}: $wrong to fix, $warnings to look at."
}

if ($inWorkflow -and $env:GITHUB_STEP_SUMMARY) {
    $lines = if ($summary.Count) {
        @('| Linter | What | Where | Finding |', '| --- | --- | --- | --- |') + $summary
    }
    else {
        @("Nothing found by $($linters.BaseName -join ', ').")
    }
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value $lines
}

Write-Information -MessageData ''
if ($errors) {
    throw "The linters found $errors to fix, see the lines that start with error above."
}
Write-Information -MessageData 'The linters found nothing to fix.'
