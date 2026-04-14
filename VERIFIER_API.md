# Vérifier que l'API fonctionne

## 1. Démarrer le backend

```powershell
cd C:\Users\hp\Desktop\developpement\stock_management_app\backend
node server.js
```

Vous devez voir : `Server running on port 5000`

## 2. Tester l'API dans le navigateur

Ouvrez : **http://127.0.0.1:5000/api/health**

Vous devez voir : `{"status":"OK","message":"Server is running"}`

Si vous voyez une page HTML ou une erreur, le backend ne fonctionne pas correctement.

## 3. Ordre de démarrage

1. **D'abord** : Démarrer le backend (`node server.js`)
2. **Ensuite** : Lancer l'app Flutter (`flutter run -d chrome`)

## 4. Si l'erreur persiste

- Fermez toutes les fenêtres du backend
- Redémarrez le backend
- Vérifiez qu'aucun autre programme n'utilise le port 5000 : `netstat -ano | findstr :5000`

## 5. Appareil physique (téléphone réel)

Si vous testez sur un vrai téléphone (pas l'émulateur), modifiez `mobile_app/lib/services/api_host_io.dart` :
remplacez `_overrideHost = null` par `_overrideHost = '192.168.1.XXX'` (l'IP de votre PC sur le réseau local).
