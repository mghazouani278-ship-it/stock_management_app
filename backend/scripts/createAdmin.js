require('dotenv').config();
const { getFirestore, ensureAdmin } = require('../firebase');

(async () => {
  try {
    getFirestore();
    const created = await ensureAdmin();
    if (created) {
      console.log('');
      console.log('Admin créé avec succès!');
      console.log('  Email: admin@example.com');
      console.log('  Mot de passe: admin123');
      console.log('Changez le mot de passe après la première connexion.');
    } else {
      console.log('Un admin existe déjà (admin@example.com).');
    }
    process.exit(0);
  } catch (err) {
    console.error('Erreur:', err.message);
    process.exit(1);
  }
})();
