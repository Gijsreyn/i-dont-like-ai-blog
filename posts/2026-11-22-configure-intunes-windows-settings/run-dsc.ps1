param([string]$Operation, [string]$Document)

$yaml = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Document))
$result = $yaml | & "$env:ProgramFiles\dsc\dsc.exe" config $Operation --file - | ConvertFrom-Json
foreach ($resource in $result.results) {
    if ($Operation -eq 'test') {
        '{0} in desired state: {1}' -f $resource.name, $resource.result.inDesiredState
    } else {
        '{0} changed: {1}' -f $resource.name, ($resource.result.changedProperties -join ', ')
    }
}