# Redemarre le backend (tue les anciens processus Node puis relance)
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Arret des processus Node..." -ForegroundColor Yellow
Get-Process -Name "node" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

Write-Host "Demarrage du backend..." -ForegroundColor Green
$backendDir = Join-Path $scriptDir "backend"
Start-Process -FilePath "node" -ArgumentList "server.js" -WorkingDirectory $backendDir -WindowStyle Hidden
Write-Host "Backend relance. Attends 3 secondes puis reessaie l'app." -ForegroundColor Green
