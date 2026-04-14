# Application Flutter dans Chrome (dossier mobile_app impose).
# Lancez APRES le backend, dans un AUTRE terminal.
# --no-web-resources-cdn : evite l'erreur "Failed to fetch" sur canvaskit (gstatic).
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $root "mobile_app")
Write-Host "Flutter Web (Chrome) depuis mobile_app" -ForegroundColor Cyan
Write-Host ""
flutter run -d chrome --no-web-resources-cdn
