# Lancer l'application dans Google (Chrome)
# Ouvre 2 fenetres : Backend (API) + App Flutter dans Chrome

$ProjectRoot = $PSScriptRoot
$BackendPath = Join-Path $ProjectRoot "backend"
$MobilePath = Join-Path $ProjectRoot "mobile_app"

Write-Host "=== Lancement de l'app (Backend + Chrome) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Fenetre 1 : Backend API (port 5000)" -ForegroundColor Yellow
Write-Host "Fenetre 2 : App Flutter dans Google Chrome" -ForegroundColor Yellow
Write-Host ""

# Demarrer le backend dans une nouvelle fenetre
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$BackendPath'; Write-Host 'Backend - Gardez cette fenetre ouverte.' -ForegroundColor Green; if (Test-Path '.\demarrer-backend-auto.ps1') { .\demarrer-backend-auto.ps1 } else { .\start.ps1 }"
)

Write-Host "Attente du demarrage du backend (5 s)..." -ForegroundColor Gray
Start-Sleep -Seconds 5

# Lancer l'app Flutter dans Chrome dans une autre fenetre
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "cd '$MobilePath'; Write-Host 'App dans Chrome - Gardez cette fenetre ouverte.' -ForegroundColor Green; if (Test-Path '.\start-chrome.ps1') { .\start-chrome.ps1 } else { flutter run -d chrome }"
) -WorkingDirectory $MobilePath

Write-Host ""
Write-Host "Deux fenetres PowerShell ont ete ouvertes." -ForegroundColor Green
Write-Host "  - Connexion : admin@example.com / admin123" -ForegroundColor Gray
Write-Host ""
