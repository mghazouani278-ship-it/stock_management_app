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
const String? apiBaseUrlOverride = 'http://92.205.161.189:5000/api';
