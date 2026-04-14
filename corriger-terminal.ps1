# Corriger le terminal : ajouter Node.js et Flutter au PATH pour cette session
# Executez ce script en debut de session si "node" ou "flutter" ne sont pas reconnus.
# Usage : depuis la racine du projet : .\corriger-terminal.ps1

$ErrorActionPreference = "SilentlyContinue"
$ProjectRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
Set-Location $ProjectRoot

Write-Host "=== Correction du terminal (PATH) ===" -ForegroundColor Cyan
Write-Host ""

# Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    $nodePaths = @(
        "C:\Program Files\nodejs",
        "C:\Program Files (x86)\nodejs",
        "${env:ProgramFiles}\nodejs",
        "${env:APPDATA}\nvm\current",
        "$env:LOCALAPPDATA\Programs\node",
        "$env:LOCALAPPDATA\fnm",
        "$env:USERPROFILE\AppData\Local\fnm",
        "$env:USERPROFILE\scoop\shims",
        "$env:USERPROFILE\AppData\Local\Volta",
        "$env:ProgramData\chocolatey\bin"
    )
    $nodeFound = $false
    foreach ($p in $nodePaths) {
        if ($p -and (Test-Path "$p\node.exe")) {
            $env:Path = "$p;$env:Path"
            Write-Host "[OK] Node.js ajoute au PATH: $p" -ForegroundColor Green
            $nodeFound = $true
            break
        }
    }
    # NVM : chercher dans les dossiers de version (v18.0.0, etc.)
    if (-not $nodeFound) {
        $nvmDir = "$env:APPDATA\nvm"
        if (Test-Path $nvmDir) {
            $vers = Get-ChildItem $nvmDir -Directory -Filter "v*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending
            foreach ($v in $vers) {
                if (Test-Path "$($v.FullName)\node.exe") {
                    $env:Path = "$($v.FullName);$env:Path"
                    Write-Host "[OK] Node.js (nvm) ajoute au PATH: $($v.FullName)" -ForegroundColor Green
                    $nodeFound = $true
                    break
                }
            }
        }
    }
    if (-not $nodeFound) {
        Write-Host "[!] Node.js non trouve. Installez depuis https://nodejs.org" -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] Node.js deja dans le PATH" -ForegroundColor Gray
}

# Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $flutterPaths = @(
        "$env:LOCALAPPDATA\flutter\bin",
        "$env:USERPROFILE\flutter\bin",
        "C:\flutter\bin",
        "C:\src\flutter\bin",
        "${env:ProgramFiles}\flutter\bin"
    )
    $flutterFound = $false
    foreach ($p in $flutterPaths) {
        if ($p -and (Test-Path "$p\flutter.bat")) {
            $env:Path = "$p;$env:Path"
            Write-Host "[OK] Flutter ajoute au PATH: $p" -ForegroundColor Green
            $flutterFound = $true
            break
        }
    }
    if (-not $flutterFound) {
        Write-Host "[!] Flutter non trouve. Installez depuis https://flutter.dev" -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] Flutter deja dans le PATH" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Terminal pret. Repertoire actuel: $ProjectRoot" -ForegroundColor Cyan
Write-Host ""
Write-Host "Commandes utiles (depuis la racine du projet) :" -ForegroundColor Cyan
Write-Host "  .\dev-backend.ps1          — API seule (libere le port 5000 si occupe)" -ForegroundColor Gray
Write-Host "  .\dev-flutter-chrome.ps1   — Flutter Web (dossier mobile_app)" -ForegroundColor Gray
Write-Host "  .\run-flutter.ps1 run      - idem : flutter run depuis mobile_app" -ForegroundColor Gray
Write-Host "  .\backend\flutter.ps1 run  - si vous etes dans le dossier backend\" -ForegroundColor Gray
Write-Host "  .\start.ps1                — backend + Chrome (ne relance pas Node si port 5000 pris)" -ForegroundColor Gray
Write-Host ""
Write-Host "Erreur ""No pubspec.yaml"" : vous etes dans backend\ — utilisez dev-flutter-chrome.ps1 ou cd mobile_app" -ForegroundColor Yellow
Write-Host "Erreur EADDRINUSE port 5000 : .\dev-backend.ps1 arrete l'ancien ecouteur, ou fermez l'autre terminal Node" -ForegroundColor Yellow
Write-Host ""
