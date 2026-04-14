/**
 * One-time migration: rename user name "Administrateur" → "Administrator" in Firestore.
 * Run from backend folder: node scripts/migrateAdministrateurToAdministrator.js
 */
require('dotenv').config();
const { getFirestore, admin } = require('../firebase');

async function main() {
  const firestore = getFirestore();
  const snapshot = await firestore.collection('users').get();
  let updated = 0;
  let batch = firestore.batch();
  let batchCount = 0;
  const MAX_BATCH = 500;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const name = data.name;
    if (name == null || typeof name !== 'string') continue;
    if (name.trim().toLowerCase() !== 'administrateur') continue;

    batch.update(doc.ref, {
      name: 'Administrator',
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    batchCount++;
    updated++;
    console.log(`Will update user ${doc.id}: "${name}" → Administrator`);

    if (batchCount >= MAX_BATCH) {
      await batch.commit();
      batch = firestore.batch();
      batchCount = 0;
    }
  }

  if (batchCount > 0) {
    await batch.commit();
  }

  console.log(`Done. Updated ${updated} document(s).`);
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
