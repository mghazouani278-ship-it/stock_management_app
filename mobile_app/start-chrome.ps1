# Lancer l'application Flutter dans Google Chrome (web)
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $flutterPaths = @(
        "$env:LOCALAPPDATA\flutter\bin",
        "$env:USERPROFILE\flutter\bin",
        "C:\flutter\bin",
        "C:\src\flutter\bin",
        "${env:ProgramFiles}\flutter\bin"
    )
    foreach ($p in $flutterPaths) {
        if (Test-Path "$p\flutter.bat") {
            $env:Path = "$p;$env:Path"
            Write-Host "Flutter ajoute au PATH: $p" -ForegroundColor Gray
            break
        }
    }
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "ERREUR: Flutter non trouve. Installez-le (https://flutter.dev)" -ForegroundColor Red
    exit 1
}

Write-Host "Lancement de l'app dans Google Chrome..." -ForegroundColor Green
Write-Host ""

if (-not (Test-Path ".dart_tool")) {
    Write-Host "Installation des dependances Flutter..." -ForegroundColor Yellow
    flutter pub get
    Write-Host ""
}

flutter run -d chrome
