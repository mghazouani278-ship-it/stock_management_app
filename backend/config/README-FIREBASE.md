# Firebase – Projet « Management Depot »

L’application utilise **Firebase Firestore** avec le projet **Management Depot**.

## 1. Créer le projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com/).
2. **Ajouter un projet** (ou sélectionner un projet existant).
3. **Nom du projet** : `Management Depot` (l’identifiant peut être `management-depot` ou similaire).
4. Activez **Google Analytics** si vous le souhaitez (optionnel).
5. Créez le projet.

## 2. Activer Firestore

1. Dans le projet Firebase, menu **Build** → **Firestore Database**.
2. **Créer une base de données**.
3. Choisir **Mode production** (règles de sécurité à configurer ensuite).
4. Choisir une région (ex. `europe-west1`).

## 3. Clé de compte de service (backend)

1. Dans Firebase : **Paramètres du projet** (engrenage) → **Comptes de service**.
2. **Générer une nouvelle clé privée** pour le compte « Node.js admin SDK ».
3. Un fichier JSON est téléchargé.
4. Placez ce fichier dans ce dossier sous le nom :  
   **`firebase-service-account.json`**  
   (ou mettez son contenu dans la variable d’environnement `FIREBASE_SERVICE_ACCOUNT_JSON`).

Structure attendue du dossier :

```
backend/
  config/
    firebase-service-account.json   ← fichier téléchargé (ne pas commiter)
    README-FIREBASE.md
```

## 4. Fichier .env (optionnel)

Si vous ne mettez pas le fichier dans `config/`, vous pouvez mettre le JSON dans `.env` :

```
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"management-depot",...}
```

(Attention : tout le JSON sur une seule ligne, sans retours à la ligne.)

## 5. Vérifier

Au démarrage du backend, vous devez voir :

- `Firebase connecté (projet Management Depot)` ou équivalent
- `Server running on port 5000`

En cas d’erreur « Firebase non configuré », vérifiez la présence de `config/firebase-service-account.json` ou de `FIREBASE_SERVICE_ACCOUNT_JSON` dans `.env`.
