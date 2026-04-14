# Corriger l'erreur "The query requires an index" - Distribution

## Solution rapide (2 minutes)

1. **Clique sur le lien** affiché dans le message d'erreur de l'app (le lien https://console.firebase.google.com/...)
2. Tu seras redirigé vers la console Firebase
3. Clique sur **"Create index"** (Créer l'index)
4. Attends 2 à 5 minutes que l'index soit créé (statut "Building" → "Enabled")
5. Réessaie l'écran Distribution

---

## Si tu n'as plus le lien

Va sur : https://console.firebase.google.com/project/management-depot/firestore/indexes

Puis crée un index composite :
- **Collection** : `order_notifications`
- **Champs** :
  - `target_role` (Ascending)
  - `created_at` (Descending)

---

## Redémarrer le backend (important)

Le backend doit être redémarré pour charger le nouveau code :

1. Ferme tous les terminaux où le backend tourne
2. Ou arrête le processus Node : `taskkill /F /IM node.exe` (dans PowerShell)
3. Relance : `.\start.ps1` ou `cd backend; node server.js`
