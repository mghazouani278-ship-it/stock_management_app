# Script pour builder l'APK release
# Usage: .\build_apk.ps1

Write-Host "Arret des daemons Gradle..." -ForegroundColor Yellow
& "$PSScriptRoot\android\gradlew.bat" --stop 2>$null

Write-Host "`nBuild de l'APK release..." -ForegroundColor Cyan
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    $apkPath = "$PSScriptRoot\build\app\outputs\flutter-apk\app-release.apk"
    Write-Host "`nAPK cree: $apkPath" -ForegroundColor Green
    Write-Host "Tu peux le partager via Drive ou WeTransfer." -ForegroundColor Green
} else {
    Write-Host "`nBuild echoue." -ForegroundColor Red
}
