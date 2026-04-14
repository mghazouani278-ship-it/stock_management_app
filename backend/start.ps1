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
            Write-Host "Node.js ajoute au PATH: $p" -ForegroundColor Gray
            break
        }
    }
}
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "ERREUR: Node.js non trouve. Installez-le depuis https://nodejs.org ou verifiez le PATH." -ForegroundColor Red
    exit 1
}

Write-Host "Starting Stock Management Backend Server..." -ForegroundColor Green
Write-Host ""

if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    npm install
    Write-Host ""
}

if (-not (Test-Path ".env")) {
    Write-Host "Creating .env file from env.example..." -ForegroundColor Yellow
    if (Test-Path "env.example") {
        Copy-Item "env.example" ".env"
    } else {
        Write-Host "env.example not found. Creating default .env..." -ForegroundColor Yellow
        @"
PORT=5000
JWT_SECRET=your_super_secret_jwt_key_change_in_production
JWT_EXPIRE=7d
NODE_ENV=development
"@ | Out-File -FilePath ".env" -Encoding utf8
    }
    Write-Host ""
    Write-Host "Please edit .env if needed (JWT_SECRET)." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to continue"
}

Write-Host "Starting server..." -ForegroundColor Green
node server.js

