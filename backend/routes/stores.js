const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { protect, authorize, authorizeAdminOrWarehouse } = require('../middleware/auth');
const { toApi } = require('../utils/firestoreToApi');

function storeToApi(doc) {
  if (!doc || !doc.exists) return null;
  const o = toApi(doc);
  o.createdAt = o.created_at;
  o.updatedAt = o.updated_at;
  return o;
}

router.get('/', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('stores').orderBy('created_at', 'desc').get();
    const data = snapshot.docs.map(d => storeToApi(d));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('stores').doc(req.params.id).get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Store not found' });
    }
    res.json({ success: true, data: storeToApi(doc) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/', protect, authorize('admin'), async (req, res) => {
  try {
    const { name, nameAr, location, description } = req.body;
    if (!name) {
      return res.status(400).json({ success: false, message: 'Please provide a store name' });
    }
    const firestore = getFirestore();
    const existing = await firestore.collection('stores').where('name', '==', name.trim()).limit(1).get();
    if (!existing.empty) {
      return res.status(400).json({ success: false, message: 'Store name already exists' });
    }
    const nameArTrim = nameAr != null && String(nameAr).trim() !== '' ? String(nameAr).trim() : null;
    const ref = await firestore.collection('stores').add({
      name: name.trim(),
      name_ar: nameArTrim,
      location: location || null,
      description: description || null,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const doc = await ref.get();
    res.status(201).json({ success: true, data: storeToApi(doc) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const { name, nameAr, location, description } = req.body;
    const firestore = getFirestore();
    const ref = firestore.collection('stores').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Store not found' });
    }
    if (name) {
      const existing = await firestore.collection('stores').where('name', '==', name.trim()).limit(1).get();
      if (!existing.empty && existing.docs[0].id !== req.params.id) {
        return res.status(400).json({ success: false, message: 'Store name already exists' });
      }
    }
    const updates = { updated_at: admin.firestore.FieldValue.serverTimestamp() };
    if (name != null) updates.name = name;
    if (nameAr !== undefined) {
      updates.name_ar = nameAr != null && String(nameAr).trim() !== '' ? String(nameAr).trim() : null;
    }
    if (location !== undefined) updates.location = location;
    if (description !== undefined) updates.description = description;
    await ref.update(updates);
    const updated = await ref.get();
    res.json({ success: true, data: storeToApi(updated) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('stores').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Store not found' });
    }
    await ref.delete();
    res.json({ success: true, message: 'Store deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
