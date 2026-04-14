# Depuis backend\ : lance Flutter dans mobile_app (evite "No pubspec.yaml").
# Usage : .\flutter.ps1 run -d chrome
$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location (Join-Path $projectRoot "mobile_app")
& flutter @args
