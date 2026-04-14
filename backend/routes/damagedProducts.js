const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const updateStock = require('../utils/updateStock');
const { protect, authorize } = require('../middleware/auth');
const { projectRef, storeRef, userRef } = require('../utils/embedRefs');

function toIso(t) {
  return t?.toDate?.()?.toISOString?.() ?? (typeof t === 'string' ? t : null);
}

async function damagedToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const productDoc = await firestore.collection('products').doc(data.product_id).get();
  const productData = productDoc?.exists ? productDoc.data() : null;
  const productCreatedAt = toIso(productData?.created_at);
  const productUpdatedAt = toIso(productData?.updated_at);
  const projectDoc = await firestore.collection('projects').doc(data.project_id).get();
  const storeId = data.store_id || data.depot_id;
  const storeDoc = storeId ? await firestore.collection('stores').doc(storeId).get() : null;
  const depotDoc = storeId && (!storeDoc || !storeDoc.exists) ? await firestore.collection('depots').doc(storeId).get() : null;
  const store = storeDoc?.exists ? storeDoc : depotDoc;
  const reportedByDoc = await firestore.collection('users').doc(data.reported_by).get();
  const approvedByDoc = data.approved_by ? await firestore.collection('users').doc(data.approved_by).get() : null;
  const out = {
    id: doc.id,
    product: productDoc.exists ? { id: productDoc.id, name: productDoc.data().name, createdAt: productCreatedAt, updatedAt: productUpdatedAt } : null,
    project: projectRef(projectDoc),
    store: store?.exists ? storeRef(store) : null,
    quantity: data.quantity,
    reason: data.reason,
    reportedBy: userRef(reportedByDoc),
    approvedBy: approvedByDoc?.exists ? (() => {
      const d = approvedByDoc.data();
      const n = d.name;
      const name = (n && (String(n).toLowerCase() === 'administrator' || String(n).toLowerCase() === 'administrateur')) ? 'administrator' : n;
      return { id: approvedByDoc.id, name, nameAr: d.name_ar || null, email: d.email };
    })() : null,
    status: data.status,
    notes: data.notes,
    createdAt: toIso(data.created_at) ?? data.created_at,
    updatedAt: toIso(data.updated_at) ?? data.updated_at,
    approvedAt: toIso(data.approved_at) ?? data.approved_at,
    productCreatedAt,
    productUpdatedAt,
  };
  if (data.color) out.color = data.color;
  return out;
}

router.get('/', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    let docs;
    if (req.user.role === 'user') {
      const snapshot = await firestore.collection('damaged_products').where('reported_by', '==', req.user.id).get();
      docs = snapshot.docs;
    } else {
      const snapshot = await firestore.collection('damaged_products').get();
      docs = snapshot.docs;
      if (req.query.project) docs = docs.filter(d => d.data().project_id === req.query.project);
      if (req.query.store) docs = docs.filter(d => d.data().store_id === req.query.store);
      if (req.query.depot) docs = docs.filter(d => d.data().depot_id === req.query.depot);
      if (req.query.product) docs = docs.filter(d => d.data().product_id === req.query.product);
      if (req.query.status) docs = docs.filter(d => d.data().status === req.query.status);
    }
    docs = docs.sort((a, b) => {
      const va = a.data().created_at?.toMillis?.() ?? 0;
      const vb = b.data().created_at?.toMillis?.() ?? 0;
      return vb - va;
    });
    const data = await Promise.all(docs.map(d => damagedToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('damaged_products').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Damaged product not found' });
    if (req.user.role === 'user' && doc.data().reported_by !== req.user.id) return res.status(403).json({ success: false, message: 'You do not have access to this record' });
    const data = await damagedToApi(doc, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/', protect, async (req, res) => {
  try {
    const { product, store, depot, quantity, reason, notes } = req.body;
    const storeId = store || depot;
    if (!product || !storeId || !quantity || !reason) return res.status(400).json({ success: false, message: 'Please provide product, store, quantity, and reason' });
    if (quantity <= 0) return res.status(400).json({ success: false, message: 'Quantity must be greater than 0' });
    if (req.user.role === 'user' && !req.user.project_id) return res.status(400).json({ success: false, message: 'You are not assigned to any project' });
    const projectId = (req.user.role === 'admin' || req.user.role === 'warehouse_user') ? req.body.projectId : req.user.project_id;
    if (!projectId) return res.status(400).json({ success: false, message: 'Please provide project ID' });
    const firestore = getFirestore();
    const ref = await firestore.collection('damaged_products').add({
      product_id: product,
      project_id: projectId,
      store_id: storeId,
      quantity,
      reason,
      reported_by: req.user.id,
      status: 'pending',
      notes: notes || null,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const doc = await ref.get();
    const data = await damagedToApi(doc, firestore);
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/approve', protect, async (req, res) => {
  try {
    if (!['admin', 'warehouse_user'].includes(req.user.role)) return res.status(403).json({ success: false, message: 'Only admins or warehouse users can approve damaged products' });
    const firestore = getFirestore();
    const ref = firestore.collection('damaged_products').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Damaged product not found' });
    const data = doc.data();
    if (data.status === 'approved') return res.status(400).json({ success: false, message: 'Damaged product already approved' });
    const sid = data.store_id || data.depot_id;
    await updateStock(data.product_id, sid, -data.quantity, 'damaged', {
      project: data.project_id,
      user: req.user.id,
      reference: doc.id,
      notes: 'Damaged product approved - Reason: ' + data.reason,
      color: data.color && String(data.color).trim() ? String(data.color).trim().toLowerCase() : null,
    });
    await ref.update({
      status: 'approved',
      approved_by: req.user.id,
      approved_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const updated = await ref.get();
    const out = await damagedToApi(updated, firestore);
    res.json({ success: true, data: out });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('damaged_products').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Damaged product not found' });
    await ref.delete();
    res.json({ success: true, message: 'Damaged product deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
module.exports.damagedToApi = damagedToApi;
