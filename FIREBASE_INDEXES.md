# Index Firestore - Validated Distributions, Approved Returns, Damaged Products

## Problème
L'erreur `FAILED_PRECONDITION: The query requires an index` apparaît sur :
- **Validated Distributions** (distributions validées)
- **Approved Returns** (retours approuvés)
- **Damaged Products** (produits endommagés)

## Solution

Le fichier `firestore.indexes.json` a été mis à jour avec les index corrects. **Vous devez les déployer sur Firebase.**

### Option 1 : Déployer via Firebase CLI (recommandé)

```bash
# Installer Firebase CLI si nécessaire
npm install -g firebase-tools

# Se connecter (si pas déjà fait)
firebase login

# Déployer les index
firebase deploy --only firestore:indexes
```

### Option 2 : Créer les index manuellement via la console Firebase

Quand l'erreur s'affiche dans l'app, **cliquez sur le lien** fourni dans le message d'erreur. Il ouvre directement la console Firebase avec l'index pré-rempli. Cliquez sur **"Create index"**.

Répétez pour chaque type de rapport qui affiche l'erreur (une fois par index manquant).

### Index requis (déjà dans firestore.indexes.json)

| Collection        | Champs indexés                          | Usage                    |
|-------------------|-----------------------------------------|--------------------------|
| returns           | status, approved_at                      | Approved Returns         |
| returns           | status, project_id, approved_at         | Avec filtre projet       |
| returns           | status, user_id, approved_at            | Avec filtre utilisateur  |
| damaged_products  | status, created_at                      | Damaged Products         |
| damaged_products  | status, project_id, created_at          | Avec filtre projet       |
| damaged_products  | status, depot_id, created_at             | Avec filtre dépôt        |
| damaged_products  | status, product_id, created_at          | Avec filtre produit      |
| distributions     | status, validated_at                    | Validated Distributions  |
| distributions     | status, project_id, validated_at        | Avec filtre projet       |
| distributions     | status, store_id, validated_at         | Avec filtre magasin      |
| distributions     | status, depot_id, validated_at          | Avec filtre dépôt        |

**Correction principale** : L'index `distributions` utilisait `created_at` au lieu de `validated_at`. C'est maintenant corrigé.

## Après le déploiement

La création des index peut prendre **quelques minutes** (2-10 min). Vous pouvez suivre la progression dans :
[Firebase Console → Firestore → Indexes](https://console.firebase.google.com/project/management-depot/firestore/indexes)

Une fois tous les index en état "Enabled" (vert), les rapports fonctionneront correctement.
