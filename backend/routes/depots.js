const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { protect, authorizeAdminOrWarehouse } = require('../middleware/auth');
const { toApi } = require('../utils/firestoreToApi');

function depotToApi(doc) {
  if (!doc || !doc.exists) return null;
  const o = toApi(doc);
  o.createdAt = o.created_at;
  o.updatedAt = o.updated_at;
  return o;
}

router.get('/', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('depots').get();
    const data = snapshot.docs.map(d => depotToApi(d));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.json({ success: true, count: 0, data: [] });
  }
});

module.exports = router;
