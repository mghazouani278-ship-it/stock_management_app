/// API endpoint configuration
///
/// **Production (app en ligne)** — pointe vers le serveur déployé.
/// Le code backend sur `egypt-grid.com` doit être le même que dans ce dépôt (`backend/`)
/// pour que les correctifs (stock, variants, etc.) s’appliquent.
///
/// **Développement local** — mettre `null` pour utiliser la machine :
/// `http://127.0.0.1:5000/api` (voir [api_host_io.dart]) ou `http://localhost:5000/api` (web).
/// Lancer `node server.js` dans `backend/` avant de tester.
///
/// Avec SSL plus tard : passer à `https://...` (même règles de chemin `/api`).
///
/// Android cleartext : [network_security_config] + usesCleartextTraffic.
///
/// Quand ce champ est `null`, l’URL est `http://<api_host_io.apiHost>:5000/api` (téléphone
/// physique → souvent le VPS). **Mettre à jour et redémarrer** ce serveur avec le dossier
/// `backend/` du dépôt après un correctif API (ex. erreur Firestore sur `history`).
const String? apiBaseUrlOverride = null;
