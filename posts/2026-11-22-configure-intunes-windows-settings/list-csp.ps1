& "$env:ProgramFiles\dsc\dsc.exe" resource list --adapter Microsoft.Windows.Adapter/ConfigurationServiceProvider |
    ForEach-Object { ($_ | ConvertFrom-Json).type } |
    Where-Object { $_ -match 'Update|Defender' }