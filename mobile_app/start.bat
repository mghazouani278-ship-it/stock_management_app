@echo off
echo Starting Flutter Mobile App...
echo.
echo Branche ton telephone en USB (debogage USB active) pour lancer sur le telephone.
echo.

if not exist .dart_tool (
    echo Installing Flutter dependencies...
    flutter pub get
    echo.
)

echo Starting Flutter app...
flutter run -d android

