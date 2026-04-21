const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { getFirestore } = require('../firebase');
const { protect, authorize } = require('../middleware/auth');
const { toApi } = require('../utils/firestoreToApi');
const { normalizeUserDisplayName } = require('../utils/userDisplayName');

async function userToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  let project = null;
  if (data.project_id) {
    const projectDoc = await firestore.collection('projects').doc(data.project_id).get();
    if (projectDoc.exists) {
      const p = projectDoc.data();
      project = { id: projectDoc.id, name: p.name, nameAr: p.name_ar || null, description: p.description, status: p.status };
    }
  }
  const out = toApi(doc);
  if (out.name != null) out.name = normalizeUserDisplayName(out.name);
  out.nameAr = data.name_ar || null;
  out.project = project;
  out.isActive = data.is_active !== false;
  out.createdAt = data.created_at;
  delete out.password;
  return out;
}

router.get('/', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('users').orderBy('created_at', 'desc').get();
    const data = await Promise.all(snapshot.docs.map(d => userToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('users').doc(req.params.id).get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    const data = await userToApi(doc, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const { name, email, role, projectId, isActive, nameAr, password } = req.body;
    const firestore = getFirestore();
    const ref = firestore.collection('users').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    const updates = {};
    if (name != null) updates.name = name;
    if (nameAr !== undefined) {
      const t = nameAr == null ? '' : String(nameAr).trim();
      updates.name_ar = t || null;
    }
    if (email != null) updates.email = email;
    if (role != null) updates.role = role;
    if (isActive !== undefined) updates.is_active = isActive;
    if (projectId !== undefined) updates.project_id = role === 'user' ? projectId : null;
    if (password != null && String(password).trim() !== '') {
      const plain = String(password).trim();
      if (plain.length < 6) {
        return res.status(400).json({ success: false, message: 'Password must be at least 6 characters' });
      }
      updates.password = await bcrypt.hash(plain, 10);
    }
    if (Object.keys(updates).length) await ref.update(updates);
    const updated = await ref.get();
    const data = await userToApi(updated, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('users').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    await ref.delete();
    res.json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/activate', protect, authorize('admin'), async (req, res) => {
  try {
    const { isActive } = req.body;
    const firestore = getFirestore();
    const ref = firestore.collection('users').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    const data = doc.data();
    const newActive = isActive !== undefined ? isActive : !data.is_active;
    await ref.update({ is_active: newActive });
    res.json({ success: true, data: { id: doc.id, isActive: !!newActive } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
