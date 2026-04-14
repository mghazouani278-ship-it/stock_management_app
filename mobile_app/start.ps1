# Corriger le terminal : ajouter Flutter au PATH si non trouve
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
    Write-Host "ERREUR: Flutter non trouve. Installez-le (https://flutter.dev) ou ajoutez son dossier bin au PATH." -ForegroundColor Red
    exit 1
}

Write-Host "Starting Flutter Mobile App..." -ForegroundColor Green
Write-Host ""

if (-not (Test-Path ".dart_tool")) {
    Write-Host "Installing Flutter dependencies..." -ForegroundColor Yellow
    flutter pub get
    Write-Host ""
}

Write-Host "Starting Flutter app..." -ForegroundColor Green
flutter run

