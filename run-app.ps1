# Run de l'app : demarre le backend puis l'app (Chrome ou appareil)
# Double-cliquez ou executez : .\run-app.ps1
# Option : .\run-app.ps1 -Chrome   pour forcer Chrome

param(
    [switch]$Chrome
)

$ProjectRoot = $PSScriptRoot
$BackendPath = Join-Path $ProjectRoot "backend"
$MobilePath = Join-Path $ProjectRoot "mobile_app"

Write-Host ""
Write-Host "=== Run de l'app ===" -ForegroundColor Cyan
Write-Host ""

# Corriger le PATH si besoin (Node + Flutter)
if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Correction du PATH (Node/Flutter)..." -ForegroundColor Gray
    if (Test-Path (Join-Path $ProjectRoot "corriger-terminal.ps1")) {
        & (Join-Path $ProjectRoot "corriger-terminal.ps1")
    }
    Write-Host ""
}

# 1. Backend dans une nouvelle fenetre
Write-Host "[1/2] Demarrage du backend (fenetre separee)..." -ForegroundColor Yellow
$backendScript = if (Test-Path (Join-Path $BackendPath "demarrer-backend-auto.ps1")) { ".\demarrer-backend-auto.ps1" } else { ".\start.ps1" }
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$BackendPath'; Write-Host 'Backend - Ne pas fermer cette fenetre.' -ForegroundColor Green; $backendScript"
)

Write-Host "      Attente 6 secondes..." -ForegroundColor Gray
Start-Sleep -Seconds 6

# 2. App Flutter
Write-Host "[2/2] Demarrage de l'app Flutter..." -ForegroundColor Yellow
if ($Chrome) {
    Write-Host "      Cible : Chrome" -ForegroundColor Gray
    $mobileCmd = "if (Test-Path '.\start-chrome.ps1') { .\start-chrome.ps1 } else { flutter run -d chrome }"
} else {
    Write-Host "      Cible : appareil par defaut (ou Chrome si web seul)" -ForegroundColor Gray
    $mobileCmd = "flutter run"
}
Start-Process powershell -ArgumentList @(
    "-NoExit",
    "-Command",
    "Set-Location '$MobilePath'; Write-Host 'App Flutter - Ne pas fermer cette fenetre.' -ForegroundColor Green; $mobileCmd"
)

Write-Host ""
Write-Host "Run termine. Deux fenetres ont ete ouvertes." -ForegroundColor Green
Write-Host "  - Connexion : admin@example.com / admin123" -ForegroundColor Gray
Write-Host "  - Pour lancer uniquement dans Chrome : .\run-app.ps1 -Chrome" -ForegroundColor Gray
Write-Host ""
