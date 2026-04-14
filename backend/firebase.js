const admin = require('firebase-admin');
const bcrypt = require('bcryptjs');
const path = require('path');

let db = null;

function getFirestore() {
  if (!db) {
    if (!admin.apps.length) {
      let credential;
      if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        try {
          const key = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
          credential = admin.credential.cert(key);
        } catch (e) {
          throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is invalid JSON: ' + e.message);
        }
      } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
        credential = admin.credential.applicationDefault();
      } else {
        const fs = require('fs');
        const configDir = path.join(__dirname, 'config');
        const possibleNames = ['firebase-service-account.json', 'firebase-service-account.json.json'];
        let keyPath = null;
        for (const name of possibleNames) {
          const p = path.join(configDir, name);
          if (fs.existsSync(p)) {
            keyPath = p;
            break;
          }
        }
        if (!keyPath) {
          throw new Error(
            'Firebase non configuré. Placez la clé JSON dans backend/config/firebase-service-account.json ' +
            '(sans double .json.json). Téléchargez-la depuis Firebase Console > Paramètres > Comptes de service > Générer une clé.'
          );
        }
        const key = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
        credential = admin.credential.cert(key);
      }
      const projectId = process.env.FIREBASE_PROJECT_ID || (credential && credential.projectId) || 'management-depot';
      admin.initializeApp({ credential, projectId });
    }
    db = admin.firestore();
  }
  return db;
}

async function ensureAdmin() {
  const firestore = getFirestore();
  const snapshot = await firestore.collection('users').where('role', '==', 'admin').limit(1).get();
  if (!snapshot.empty) return false;
  const hash = await bcrypt.hash('admin123', 10);
  await firestore.collection('users').add({
    name: 'Administrator',
    email: 'admin@example.com',
    password: hash,
    role: 'admin',
    project_id: null,
    is_active: true,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  console.log('Admin créé: admin@example.com / admin123');
  return true;
}

function getProjectId() {
  if (process.env.FIREBASE_PROJECT_ID) return process.env.FIREBASE_PROJECT_ID;
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    try {
      const k = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
      return k.project_id || null;
    } catch (_) {}
  }
  const fs = require('fs');
  const configDir = path.join(__dirname, 'config');
  for (const name of ['firebase-service-account.json', 'firebase-service-account.json.json']) {
    const keyPath = path.join(configDir, name);
    if (fs.existsSync(keyPath)) {
      try {
        const k = JSON.parse(fs.readFileSync(keyPath, 'utf8'));
        return k.project_id || null;
      } catch (_) {}
    }
  }
  return null;
}

module.exports = { getFirestore, ensureAdmin, admin, getProjectId };
