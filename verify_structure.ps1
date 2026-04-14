# Script de vérification de la structure du projet
Write-Host "=== Verification de la structure du projet ===" -ForegroundColor Cyan
Write-Host ""

$errors = @()
$warnings = @()

# Vérifier le dossier backend
Write-Host "Verification du backend..." -ForegroundColor Yellow
if (Test-Path "backend") {
    Write-Host "  [OK] Dossier backend existe" -ForegroundColor Green
    
    # Vérifier les fichiers essentiels
    $requiredFiles = @("server.js", "package.json", "models", "routes", "middleware")
    foreach ($file in $requiredFiles) {
        if (Test-Path "backend\$file") {
            Write-Host "  [OK] $file existe" -ForegroundColor Green
        } else {
            $errors += "backend\$file manquant"
            Write-Host "  [ERREUR] $file manquant" -ForegroundColor Red
        }
    }
    
    # Vérifier .env
    if (-not (Test-Path "backend\.env")) {
        $warnings += "backend\.env n'existe pas (copiez env.example vers .env)"
        Write-Host "  [ATTENTION] .env n'existe pas" -ForegroundColor Yellow
    }
    
    # Vérifier node_modules
    if (-not (Test-Path "backend\node_modules")) {
        $warnings += "backend\node_modules n'existe pas (executez: npm install)"
        Write-Host "  [ATTENTION] node_modules n'existe pas" -ForegroundColor Yellow
    }
} else {
    $errors += "Dossier backend manquant"
    Write-Host "  [ERREUR] Dossier backend manquant" -ForegroundColor Red
}

Write-Host ""

# Vérifier le dossier mobile_app
Write-Host "Verification de l'application mobile..." -ForegroundColor Yellow
if (Test-Path "mobile_app") {
    Write-Host "  [OK] Dossier mobile_app existe" -ForegroundColor Green
    
    # Vérifier les fichiers essentiels
    if (Test-Path "mobile_app\pubspec.yaml") {
        Write-Host "  [OK] pubspec.yaml existe" -ForegroundColor Green
    } else {
        $errors += "mobile_app\pubspec.yaml manquant"
        Write-Host "  [ERREUR] pubspec.yaml manquant" -ForegroundColor Red
    }
    
    if (Test-Path "mobile_app\lib\main.dart") {
        Write-Host "  [OK] lib\main.dart existe" -ForegroundColor Green
    } else {
        $errors += "mobile_app\lib\main.dart manquant"
        Write-Host "  [ERREUR] lib\main.dart manquant" -ForegroundColor Red
    }
    
    # Vérifier .dart_tool
    if (-not (Test-Path "mobile_app\.dart_tool")) {
        $warnings += "mobile_app\.dart_tool n'existe pas (executez: flutter pub get)"
        Write-Host "  [ATTENTION] .dart_tool n'existe pas" -ForegroundColor Yellow
    }
} else {
    $errors += "Dossier mobile_app manquant"
    Write-Host "  [ERREUR] Dossier mobile_app manquant" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Resume ===" -ForegroundColor Cyan

if ($errors.Count -eq 0) {
    Write-Host "Aucune erreur trouvee!" -ForegroundColor Green
} else {
    Write-Host "Erreurs trouvees:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "  - $error" -ForegroundColor Red
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "Avertissements:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  - $warning" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "Structure du projet OK!" -ForegroundColor Green
} else {
    Write-Host "Veuillez corriger les erreurs ci-dessus." -ForegroundColor Red
    exit 1
}

