@echo off
echo ========================================
echo   Egypt Grid - Demarrage sur TELEPHONE
echo ========================================
echo.
echo Branche ton telephone en USB et active le debogage USB.
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

echo [1/2] Demarrage du backend...
cd /d "%~dp0backend"
start /b node server.js
cd /d "%~dp0"

echo [2/2] Attente du serveur (5 secondes)...
timeout /t 5 /nobreak >nul

echo Demarrage de l'application sur le telephone...
cd /d "%~dp0mobile_app"
flutter run -d android
