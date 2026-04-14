# Run Flutter commands from project root (automatically uses mobile_app folder)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mobileDir = Join-Path $scriptDir "mobile_app"
Set-Location $mobileDir
& flutter $args
