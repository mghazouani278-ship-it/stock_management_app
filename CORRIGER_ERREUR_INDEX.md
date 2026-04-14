# Corriger l'erreur "The query requires an index"

## Rapports > Validated Distributions – Correction détaillée

### Qu'est-ce que la faute ?

**Message d'erreur :**
```
9 FAILED_PRECONDITION: The query requires an index. You can create it here: [lien Firebase]
```

**Explication :** Firestore exige un index composite quand une requête combine un filtre (`where`) et un tri (`orderBy`) sur des champs différents. Le rapport "Validated Distributions" interroge la collection `distributions` avec `status == 'validated'` et `orderBy('validated_at')`, ce qui nécessitait cet index.

**Bonne nouvelle :** Le backend a été modifié pour éviter cet index. Le tri se fait maintenant en mémoire. Il suffit de **redémarrer le backend** pour que la correction soit prise en compte.

---

## Solution 1 : Redémarrer le backend (recommandé)

1. **Arrêtez le backend** : dans le terminal où il tourne, appuyez sur `Ctrl+C`
2. **Relancez-le :**
   ```powershell
   cd C:\Users\hp\Desktop\developpement\stock_management_app\backend; node server.js
   ```
3. **Testez** : dans l'app, allez dans Rapports > Validated Distributions et cliquez sur **Retry**

---

## Solution 2 : Créer l'index dans Firebase (si le redémarrage ne suffit pas)

Si l'erreur continue après le redémarrage du backend :

1. **Copiez le lien** complet affiché dans le message d'erreur rouge
2. **Collez-le** dans votre navigateur (Chrome, Edge, etc.)
3. La console Firebase s'ouvre avec l'index pré-rempli (collection `distributions`, champs `status` + `validated_at`)
4. Cliquez sur **"Create index"**
5. Attendez 2 à 10 minutes que l'index soit créé (statut "Enabled" en vert)
6. Cliquez sur **Retry** dans l'app

**Lien direct pour Validated Distributions :**  
https://console.firebase.google.com/v1/r/project/management-depot/firestore/indexes?create_composite=CIZwcm9qZWN0cy9tYW5hZ2VtZW50LWRlcG90L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9kaXN0cmlidXRpb25zL2luZGV4ZXMvXxABGgoKBnN0YXR1cxABGhAKDHZhbGlkYXRlZF9hdBACGgwKCF9fbmFtZV9fEAI

---

## Message d'erreur (autres écrans)

```
9 FAILED_PRECONDITION: The query requires an index. You can create it here: [lien]
```

**Signification :** Firestore a besoin d'un index composite pour la requête.

---

## Solution rapide (recommandée)

**La même procédure s'applique à chaque écran** (Approved Returns, Validated Distributions, Damaged Products).

### Liens directs pour créer les index

Cliquez sur le lien correspondant à l'écran qui affiche l'erreur :

| Écran | Lien direct |
|-------|-------------|
| **Validated Distributions** | [Créer l'index distributions](https://console.firebase.google.com/v1/r/project/management-depot/firestore/indexes?create_composite=CIZwcm9qZWN0cy9tYW5hZ2VtZW50LWRlcG90L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9kaXN0cmlidXRpb25zL2luZGV4ZXMvXxABGgoKBnN0YXR1cxABGhAKDHZhbGlkYXRlZF9hdBACGgwKCF9fbmFtZV9fEAI) |
| **Approved Returns** | Copiez le lien depuis le message d'erreur dans l'app |
| **Damaged Products** | Copiez le lien depuis le message d'erreur dans l'app |

### Étape 1 : Ouvrir le lien

1. **Cliquez** sur le lien ci-dessus (Validated Distributions) ou **copiez le lien** depuis le message d'erreur
2. La console Firebase s'ouvre avec l'index déjà configuré

### Étape 2 : Créer l'index

1. Vérifiez la collection et les champs affichés :
   - **Approved Returns** → collection `returns`, champs `status` + `approved_at`
   - **Validated Distributions** → collection `distributions`, champs `status` + `validated_at`
   - **Damaged Products** → collection `damaged_products`, champs `status` + `created_at`
2. Cliquez sur **"Create index"** (Créer l'index)
3. Attendez 2 à 10 minutes que l'index soit construit (statut "Enabled" en vert)

### Étape 3 : Tester

1. Retournez dans l'app
2. Cliquez sur **"Retry"** (Réessayer) ou rechargez l'écran

---

## Solution complète (tous les rapports)

Si la même erreur apparaît aussi sur **Validated Distributions** et **Damaged Products**, créez tous les index d'un coup :

### Option A : Via Firebase CLI

```powershell
# 1. Installer Firebase CLI (une seule fois)
npm install -g firebase-tools

# 2. Se connecter à Firebase (une seule fois)
firebase login

# 3. Aller dans le dossier du projet
cd C:\Users\hp\Desktop\developpement\stock_management_app

# 4. Déployer tous les index (exécuter chaque commande séparément)
firebase deploy --only firestore:indexes
```

### Option B : Créer chaque index manuellement

Quand l'erreur s'affiche sur un écran (Approved Returns, Validated Distributions, Damaged Products) :
- Cliquez sur le lien dans le message d'erreur
- Créez l'index dans la console Firebase
- Répétez pour chaque écran qui affiche l'erreur

---

## Suivre la progression

Ouvrez : [Firebase Console → Firestore → Indexes](https://console.firebase.google.com/project/management-depot/firestore/indexes)

Les index en cours de création affichent "Building...". Une fois terminés, ils passent à "Enabled" (vert).

---

## Dépannage : l'erreur persiste après avoir créé l'index

### 1. Vérifier le statut de l'index
- Allez sur [Firestore → Indexes](https://console.firebase.google.com/project/management-depot/firestore/indexes)
- Cherchez l'index pour la collection **distributions** (champs : status, validated_at)
- Le statut doit être **Enabled** (vert). Si c'est "Building", attendez 5 à 15 minutes.

### 2. Vérifier le projet Firebase
- Le backend utilise le fichier `backend/config/firebase-service-account.json`
- Le `project_id` dans ce fichier doit être **management-depot** (comme dans le lien d'erreur)

### 3. Redémarrer le backend
Après la création de l'index, redémarrez le serveur :
```powershell
# Arrêtez le backend (Ctrl+C), puis :
cd C:\Users\hp\Desktop\developpement\stock_management_app\backend; node server.js
```

### 5. Erreur "address already in use :::5000"
Si le port 5000 est déjà utilisé, arrêtez le processus Node.js :
```powershell
# Arrêter tous les processus Node.js
Get-Process -Name node -ErrorAction SilentlyContinue | Stop-Process -Force

# Attendre 2 secondes, puis relancer le backend
Start-Sleep -Seconds 2; cd C:\Users\hp\Desktop\developpement\stock_management_app\backend; node server.js
```

### 6. Solution de contournement (sans index)
Le backend a été modifié pour **ne plus exiger d'index** sur les rapports (Validated Distributions, Approved Returns, Damaged Products). Le tri et les filtres se font maintenant en mémoire. Redémarrez le backend pour appliquer les changements.
