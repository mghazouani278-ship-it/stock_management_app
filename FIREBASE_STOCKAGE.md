# Stockage des données dans Firebase (management-depot)

## Où sont enregistrées les données ?

**Toutes les données de l'application sont enregistrées dans Firebase Firestore**, projet **management-depot**.

Aucun Firebase CLI n'est nécessaire pour le stockage. Le backend utilise directement l'API Firebase.

---

## Collections Firestore utilisées

| Collection         | Données stockées                          |
|--------------------|-------------------------------------------|
| `users`            | Utilisateurs, admins, mots de passe       |
| `stores`           | Magasins / dépôts                         |
| `products`         | Produits, catégories                      |
| `projects`         | Projets                                   |
| `stock`            | Stock par magasin/produit                 |
| `orders`           | Commandes des utilisateurs                |
| `returns`          | Retours de produits                       |
| `damaged_products` | Produits endommagés signalés              |
| `distributions`    | Distributions validées                     |
| `stock_history`    | Historique des mouvements de stock         |

---

## Configuration

Le backend lit la configuration depuis :

- **Fichier** : `backend/config/firebase-service-account.json` ou `firebase-service-account.json.json`
- **Variable d'environnement** : `FIREBASE_PROJECT_ID=management-depot` (dans `backend/.env`)

Le `project_id` dans le fichier de clé de service doit être **management-depot**.

---

## Vérifier que les données sont bien enregistrées

1. Ouvrez la [Console Firebase](https://console.firebase.google.com/project/management-depot/firestore)
2. Allez dans **Firestore Database**
3. Consultez les collections : `users`, `products`, `orders`, etc.

---

## Firebase CLI – à quoi ça sert ?

**Firebase CLI n'est pas utilisé pour enregistrer les données.**

Il sert uniquement à :
- Déployer les index Firestore (optionnel, pour certaines requêtes complexes)
- Déployer des règles de sécurité
- Déployer des fonctions Cloud

Pour l’usage normal de l’app, **aucune action avec Firebase CLI n’est nécessaire**. Les données sont déjà enregistrées dans Firebase via le backend.
