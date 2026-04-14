@echo off
setlocal
echo ========================================
echo   Egypt Grid - Demarrage de l'application
echo ========================================
echo.

where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ERREUR: Node.js introuvable. Installez Node.js depuis https://nodejs.org
    pause
    exit /b 1
)

where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo ERREUR: Flutter introuvable. Ajoutez Flutter au PATH.
    pause
    exit /b 1
)

echo [1/3] Demarrage du backend...
cd /d "%~dp0backend"
start /b node server.js
cd /d "%~dp0"

echo [2/3] Attente de l'API http://127.0.0.1:5000/api/health ...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ok=$false; for($i=0; $i -lt 45; $i++) { try { $r = Invoke-WebRequest -Uri 'http://127.0.0.1:5000/api/health' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { $ok=$true; break } } catch { } Start-Sleep -Seconds 1 }; if (-not $ok) { Write-Host 'ERREUR: le backend ne repond pas sur le port 5000.'; exit 1 } else { Write-Host 'API OK.' }"
if %errorlevel% neq 0 (
    echo Verifiez le fichier .env et Firebase, ou un autre processus sur le port 5000.
    pause
    exit /b 1
)

echo [3/3] Demarrage de l'application Flutter (Chrome^)...
cd /d "%~dp0mobile_app"
flutter run -d chrome
endlocal
