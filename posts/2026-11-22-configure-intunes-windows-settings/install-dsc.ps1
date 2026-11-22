$ProgressPreference = 'SilentlyContinue'
$url = 'https://github.com/PowerShell/DSC/releases/download/v3.4.0-preview.3/DSC-3.4.0-preview.3-x86_64-pc-windows-msvc.zip'
$zip = Join-Path $env:TEMP 'dsc.zip'
$path = Join-Path $env:ProgramFiles 'dsc'

Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $path -Force
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
[Environment]::SetEnvironmentVariable('Path', "$machinePath;$path", 'Machine')

& "$path\dsc.exe" --version
whoami