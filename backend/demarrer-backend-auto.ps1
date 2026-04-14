# Demarrage automatique du backend - Solution "Failed to fetch"
# Execute toutes les etapes sans interaction utilisateur

$ErrorActionPreference = "Stop"
$BackendRoot = $PSScriptRoot

Set-Location $BackendRoot

# Corriger le terminal : ajouter Node.js au PATH si non trouve
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    $nodePaths = @(
        "C:\Program Files\nodejs",
        "C:\Program Files (x86)\nodejs",
        "${env:ProgramFiles}\nodejs",
        "${env:APPDATA}\nvm\current",
        "$env:LOCALAPPDATA\Programs\node",
        "$env:LOCALAPPDATA\fnm",
        "$env:USERPROFILE\AppData\Local\fnm",
        "$env:USERPROFILE\scoop\shims"
    )
    foreach ($p in $nodePaths) {
        if (Test-Path "$p\node.exe") {
            $env:Path = "$p;$env:Path"
            Write-Host "Node.js trouve: $p" -ForegroundColor Gray
            break
        }
    }
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "ERREUR: Node.js non trouve. Installez-le depuis https://nodejs.org ou verifiez le PATH." -ForegroundColor Red
    Write-Host "Voir: stock_management_app\PROBLEME_NODEJS.md" -ForegroundColor Yellow
    exit 1
}

Write-Host "=== Demarrage automatique du backend ===" -ForegroundColor Green
Write-Host ""

# 1. Installer les dependances
if (-not (Test-Path "node_modules")) {
    Write-Host "[1/4] Installation des dependances (npm install)..." -ForegroundColor Yellow
    npm install
    Write-Host ""
} else {
    Write-Host "[1/4] node_modules present, skip npm install" -ForegroundColor Gray
}

# 2. Creer .env si absent
if (-not (Test-Path ".env")) {
    Write-Host "[2/4] Creation du fichier .env depuis env.example..." -ForegroundColor Yellow
    if (Test-Path "env.example") {
        Copy-Item "env.example" ".env"
        Write-Host "    .env cree. Modifiez-le si besoin (JWT_SECRET)." -ForegroundColor Gray
    } else {
        @"
PORT=5000
JWT_SECRET=your_super_secret_jwt_key_change_in_production
JWT_EXPIRE=7d
NODE_ENV=development
"@ | Out-File -FilePath ".env" -Encoding utf8
    }
    Write-Host ""
} else {
    Write-Host "[2/4] Fichier .env deja present" -ForegroundColor Gray
}

# 3. Creer l'admin si pas encore fait
Write-Host "[3/4] Creation du premier admin (si necessaire)..." -ForegroundColor Yellow
& node scripts/createAdmin.js
if ($LASTEXITCODE -ne 0) { Write-Host "    (admin deja cree - on continue)" -ForegroundColor Gray }
Write-Host ""

# 4. Demarrer le serveur
Write-Host "[4/4] Demarrage du serveur sur le port 5000..." -ForegroundColor Green
Write-Host ""
node server.js
