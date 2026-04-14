const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const updateStock = require('../utils/updateStock');
const { protect } = require('../middleware/auth');
const { projectRef, userRef } = require('../utils/embedRefs');

function normalizeColor(c) {
  if (c == null || c === '') return null;
  const s = String(c).trim();
  return s ? s.toLowerCase() : null;
}

function toIso(t) {
  return t?.toDate?.()?.toISOString?.() ?? (typeof t === 'string' ? t : null);
}

async function returnToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const userDoc = await firestore.collection('users').doc(data.user_id).get();
  const projectDoc = await firestore.collection('projects').doc(data.project_id).get();
  const approvedByDoc = data.approved_by ? await firestore.collection('users').doc(data.approved_by).get() : null;
    const products = await Promise.all((data.products || []).map(async (p) => {
      const pid = p.product_id ?? p.product?.id ?? p.product;
      let productName = null;
      if (pid) {
        const productDoc = await firestore.collection('products').doc(String(pid)).get();
        if (productDoc.exists) productName = productDoc.data().name;
      }
      const line = {
        product: { id: pid, name: productName },
        quantity: p.quantity,
        condition: p.condition || 'good',
      };
      const col = normalizeColor(p.color ?? p.variant ?? p.variance);
      if (col) line.color = col;
      return line;
    }));
  return {
    id: doc.id,
    user: userRef(userDoc),
    project: projectRef(projectDoc),
    products,
    status: data.status,
    approvedBy: approvedByDoc?.exists ? (() => {
      const d = approvedByDoc.data();
      const n = d.name;
      const name = (n && (String(n).toLowerCase() === 'administrator' || String(n).toLowerCase() === 'administrateur')) ? 'administrator' : n;
      return { id: approvedByDoc.id, name, nameAr: d.name_ar || null, email: d.email };
    })() : null,
    approvedAt: toIso(data.approved_at) ?? data.approved_at,
    notes: data.notes,
    createdAt: toIso(data.created_at) ?? data.created_at,
    updatedAt: toIso(data.updated_at) ?? data.updated_at,
  };
}

function _normalizeRole(role) {
  return (role || '').toLowerCase().replace(/\s+/g, '_');
}

router.get('/', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const role = _normalizeRole(req.user.role);
    let docs;
    if (role === 'user') {
      const snapshot = await firestore.collection('returns').where('user_id', '==', req.user.id).get();
      docs = snapshot.docs;
    } else {
      const snapshot = await firestore.collection('returns').get();
      docs = snapshot.docs;
      if (req.query.user) docs = docs.filter(d => d.data().user_id === req.query.user);
      if (req.query.project) docs = docs.filter(d => d.data().project_id === req.query.project);
      if (req.query.status) docs = docs.filter(d => d.data().status === req.query.status);
    }
    docs = docs.sort((a, b) => {
      const va = a.data().created_at?.toMillis?.() ?? 0;
      const vb = b.data().created_at?.toMillis?.() ?? 0;
      return vb - va;
    });
    const data = await Promise.all(docs.map(d => returnToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('returns').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Return not found' });
    if (_normalizeRole(req.user.role) === 'user' && doc.data().user_id !== req.user.id) return res.status(403).json({ success: false, message: 'You do not have access to this return' });
    const data = await returnToApi(doc, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/', protect, async (req, res) => {
  try {
    const { products, notes } = req.body;
    if (!products || !Array.isArray(products) || products.length === 0) return res.status(400).json({ success: false, message: 'Please provide at least one product' });
    if (_normalizeRole(req.user.role) === 'user' && !req.user.project_id) return res.status(400).json({ success: false, message: 'You are not assigned to any project' });
    const projectId = _normalizeRole(req.user.role) === 'admin' ? req.body.projectId : req.user.project_id;
    const firestore = getFirestore();
    const productsData = products.map((p) => {
      const productId = p.product?.id ?? p.product?._id ?? p.product;
      const row = {
        product_id: productId,
        quantity: p.quantity,
        condition: p.condition || 'good',
      };
      const col = normalizeColor(p.color ?? p.variant ?? p.variance);
      if (col) row.color = col;
      return row;
    });
    const ref = await firestore.collection('returns').add({
      user_id: req.user.id,
      project_id: projectId,
      status: 'pending',
      notes: notes || null,
      products: productsData,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const doc = await ref.get();
    const data = await returnToApi(doc, firestore);
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/approve', protect, async (req, res) => {
  try {
    const role = _normalizeRole(req.user.role);
    if (!['admin', 'warehouse_user'].includes(role)) return res.status(403).json({ success: false, message: 'Only admins or warehouse users can approve returns' });
    const { store, depot } = req.body;
    const fallbackStoreId = store || depot;
    const firestore = getFirestore();
    const ref = firestore.collection('returns').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Return not found' });
    const data = doc.data();
    if (data.status === 'approved') return res.status(400).json({ success: false, message: 'Return already approved' });
    const products = data.products || [];
    const needsFallback = products.some((p) => p.condition === 'good');
    if (needsFallback && !fallbackStoreId) return res.status(400).json({ success: false, message: 'Please provide store ID (used when product has no store of origin)' });
    for (const item of products) {
      const color = normalizeColor(item.color ?? item.variant ?? item.variance);
      if (item.condition === 'good') {
        const productId = item.product_id ?? item.product?.id ?? item.product;
        let targetStoreId = fallbackStoreId;
        const productDoc = productId ? await firestore.collection('products').doc(String(productId)).get() : null;
        if (productDoc?.exists) {
          const storesMap = productDoc.data().stores || productDoc.data().depots || {};
          const firstStoreId = Object.keys(storesMap)[0];
          if (firstStoreId) targetStoreId = firstStoreId;
        }
        if (!targetStoreId) continue;
        await updateStock(productId, targetStoreId, item.quantity, 'return', {
          project: data.project_id,
          user: req.user.id,
          reference: doc.id,
          notes: 'Product returned - Good condition (store of origin)',
          color,
        });
      } else {
        const storeId = fallbackStoreId;
        if (!storeId) return res.status(400).json({ success: false, message: 'Please provide store ID for damaged products' });
        const damagedPayload = {
          product_id: item.product_id,
          project_id: data.project_id,
          store_id: storeId,
          quantity: item.quantity,
          reason: 'Returned as damaged',
          reported_by: data.user_id,
          approved_by: req.user.id,
          status: 'approved',
          notes: 'Damaged product from return',
          created_at: admin.firestore.FieldValue.serverTimestamp(),
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (color) damagedPayload.color = color;
        await firestore.collection('damaged_products').add(damagedPayload);
      }
    }
    await ref.update({
      status: 'approved',
      approved_by: req.user.id,
      approved_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const updated = await ref.get();
    const out = await returnToApi(updated, firestore);
    res.json({ success: true, data: out });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, async (req, res) => {
  try {
    const role = _normalizeRole(req.user.role);
    if (!['admin', 'warehouse_user'].includes(role)) return res.status(403).json({ success: false, message: 'Only admins or warehouse users can delete returns' });
    const firestore = getFirestore();
    const ref = firestore.collection('returns').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Return not found' });
    await ref.delete();
    res.json({ success: true, message: 'Return deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
module.exports.returnToApi = returnToApi;
