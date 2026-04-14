# Egypt Grid - Script de demarrage (PowerShell)
#
# Regles pour eviter les erreurs dans le terminal :
# - Ne collez JAMAIS deux commandes sur une ligne (ex: "node server.jscd ..." casse Node).
# - Backend : .\dev-backend.ps1   |   Flutter : .\dev-flutter-chrome.ps1 (2 terminaux separes).
# - Si "EADDRINUSE port 5000" : un serveur tourne deja ; fermez l'autre terminal ou tuez le processus sur 5000.
# - Si "No pubspec.yaml" : vous etes dans "backend" ; lancez Flutter depuis mobile_app ou dev-flutter-chrome.ps1
#
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Egypt Grid - Demarrage de l'application" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verifier Node.js
try {
    $null = Get-Command node -ErrorAction Stop
} catch {
    Write-Host "ERREUR: Node.js introuvable. Installez Node.js depuis https://nodejs.org" -ForegroundColor Red
    Read-Host "Appuyez sur Entree pour fermer"
    exit 1
}

# Verifier Flutter
try {
    $null = Get-Command flutter -ErrorAction Stop
} catch {
    Write-Host "ERREUR: Flutter introuvable. Ajoutez Flutter au PATH." -ForegroundColor Red
    Read-Host "Appuyez sur Entree pour fermer"
    exit 1
}

# Demarrer le backend (en arriere-plan, sans fenetre) - pas de doublon si le port 5000 est deja pris
Write-Host "[1/2] Backend (port 5000)..." -ForegroundColor Yellow
$backendDir = Join-Path $scriptDir "backend"
$portBusy = $false
try {
    $existing = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue
    if ($existing) { $portBusy = $true }
} catch { }
if ($portBusy) {
    Write-Host "Le port 5000 est deja utilise - backend considere comme actif (pas de second Node)." -ForegroundColor Green
} else {
    Start-Process -FilePath "node" -ArgumentList "server.js" -WorkingDirectory $backendDir -WindowStyle Hidden
    Write-Host "Backend lance en arriere-plan (aucune fenetre)." -ForegroundColor Green
}
Write-Host ""

# Attendre que le serveur soit pret
Write-Host "[2/2] Attente du serveur (5 secondes)..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
Write-Host ""

# Demarrer Flutter
Write-Host "Demarrage de l'application Flutter..." -ForegroundColor Yellow
Set-Location (Join-Path $scriptDir "mobile_app")

# Si Flutter affiche une erreur sur le dossier Temp (flutter_tools_chrome_device) :
# fermez toutes les fenetres Chrome, puis relancez ; en dernier recours : flutter clean (dans mobile_app).
# --no-web-resources-cdn : CanvasKit en local (evite l'echec de chargement depuis gstatic.com).
flutter run -d chrome --no-web-resources-cdn
