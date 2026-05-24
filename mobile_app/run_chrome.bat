@echo off
REM Lance l'app Flutter dans Chrome (CanvasKit local, evite l'ecran blanc si le CDN gstatic est bloque).
cd /d %~dp0

if not exist .dart_tool (
    echo Installation des dependances Flutter...
    flutter pub get
    echo.
)

echo Demarrage dans Chrome (CanvasKit local)...
echo Assurez-vous que le backend tourne: cd ..\backend ^& node server.js
echo.
flutter run -d chrome --no-web-resources-cdn
