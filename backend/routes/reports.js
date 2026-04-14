const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { protect, authorize, authorizeAdminOrWarehouse } = require('../middleware/auth');
const ordersRoute = require('./orders');
const returnsRoute = require('./returns');
const damagedRoute = require('./damagedProducts');
const { projectRef, storeRef, userRef } = require('../utils/embedRefs');

router.get('/stock-summary', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('stock').get();
    let totalQuantity = 0;
    const byProduct = {};
    snapshot.docs.forEach(d => {
      const dta = d.data();
      const qty = dta.quantity || 0;
      totalQuantity += qty;
      const pid = dta.product_id;
      if (pid) byProduct[pid] = (byProduct[pid] || 0) + qty;
    });
    const byProductWithNames = {};
    for (const [pid, qty] of Object.entries(byProduct)) {
      const prodDoc = await firestore.collection('products').doc(pid).get();
      byProductWithNames[pid] = { quantity: qty, name: prodDoc.exists ? prodDoc.data().name : pid };
    }
    res.json({ success: true, data: { totalQuantity, byProduct: byProductWithNames } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/distributions', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('distributions').where('status', '==', 'validated').get();
    let docs = snapshot.docs;
    if (req.query.project) docs = docs.filter(d => d.data().project_id === req.query.project);
    if (req.query.store) docs = docs.filter(d => d.data().store_id === req.query.store);
    if (req.query.depot) docs = docs.filter(d => d.data().depot_id === req.query.depot);
    docs = docs.sort((a, b) => {
      const va = a.data().validated_at?.toMillis?.() ?? 0;
      const vb = b.data().validated_at?.toMillis?.() ?? 0;
      return vb - va;
    });
    if (req.query.product) {
      docs = docs.filter(d => {
        const products = d.data().products || [];
        return products.some(p => (p.product?.id ?? p.product) === req.query.product);
      });
    }
    const distToApi = async (doc) => {
      const data = doc.data();
      const projectDoc = await firestore.collection('projects').doc(data.project_id).get();
      const sid = data.store_id || data.depot_id;
      const storeDoc = sid ? await firestore.collection('stores').doc(sid).get() : null;
      const depotDoc = sid && (!storeDoc || !storeDoc.exists) ? await firestore.collection('depots').doc(sid).get() : null;
      const store = storeDoc?.exists ? storeDoc : depotDoc;
      const validatedByDoc = data.validated_by ? await firestore.collection('users').doc(data.validated_by).get() : null;
      return {
        id: doc.id,
        bonAlimentation: data.bon_alimentation,
        project: projectRef(projectDoc),
        store: store?.exists ? storeRef(store) : null,
        products: (data.products || []).map(p => ({ product: { id: p.product }, quantity: p.quantity })),
        validatedBy: validatedByDoc?.exists ? (() => {
        const n = validatedByDoc.data().name;
        const name = (n && (String(n).toLowerCase() === 'administrator' || String(n).toLowerCase() === 'administrateur')) ? 'administrator' : n;
        return { id: validatedByDoc.id, name, email: validatedByDoc.data().email };
      })() : null,
        validatedAt: data.validated_at,
      };
    };
    const data = await Promise.all(docs.map(distToApi));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/orders', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    let q = firestore.collection('orders').orderBy('created_at', 'desc');
    if (req.query.project) q = q.where('project_id', '==', req.query.project);
    if (req.query.user) q = q.where('user_id', '==', req.query.user);
    const snapshot = await q.get();
    const data = await Promise.all(snapshot.docs.map(d => ordersRoute.orderToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/returns', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('returns').where('status', '==', 'approved').get();
    let docs = snapshot.docs;
    if (req.query.project) docs = docs.filter(d => d.data().project_id === req.query.project);
    if (req.query.user) docs = docs.filter(d => d.data().user_id === req.query.user);
    docs = docs.sort((a, b) => {
      const va = a.data().approved_at?.toMillis?.() ?? 0;
      const vb = b.data().approved_at?.toMillis?.() ?? 0;
      return vb - va;
    });
    const data = await Promise.all(docs.map(d => returnsRoute.returnToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/damaged-products', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('damaged_products').where('status', '==', 'approved').get();
    let docs = snapshot.docs;
    if (req.query.project) docs = docs.filter(d => d.data().project_id === req.query.project);
    if (req.query.depot) docs = docs.filter(d => d.data().depot_id === req.query.depot);
    if (req.query.product) docs = docs.filter(d => d.data().product_id === req.query.product);
    docs = docs.sort((a, b) => {
      const va = a.data().created_at?.toMillis?.() ?? 0;
      const vb = b.data().created_at?.toMillis?.() ?? 0;
      return vb - va;
    });
    const data = await Promise.all(docs.map(d => damagedRoute.damagedToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/stock-history', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    let q = firestore.collection('stock_history').orderBy('created_at', 'desc').limit(1000);
    if (req.query.project) q = q.where('project_id', '==', req.query.project);
    if (req.query.store) q = q.where('store_id', '==', req.query.store);
    else if (req.query.depot) q = q.where('depot_id', '==', req.query.depot);
    if (req.query.product) q = q.where('product_id', '==', req.query.product);
    if (req.query.type) q = q.where('type', '==', req.query.type);
    const snapshot = await q.get();
    const data = await Promise.all(snapshot.docs.map(async (d) => {
      const r = d.data();
      const productDoc = r.product_id ? await firestore.collection('products').doc(r.product_id).get() : null;
      const sid = r.store_id || r.depot_id;
      const storeDoc = sid ? await firestore.collection('stores').doc(sid).get() : null;
      const depotDoc = sid && (!storeDoc || !storeDoc.exists) ? await firestore.collection('depots').doc(sid).get() : null;
      const s = storeDoc?.exists ? storeDoc : depotDoc;
      const projectDoc = r.project_id ? await firestore.collection('projects').doc(r.project_id).get() : null;
      const userDoc = r.user_id ? await firestore.collection('users').doc(r.user_id).get() : null;
      const productData = productDoc?.exists ? productDoc.data() : null;
      const productCreatedAt = productData?.created_at;
      const productCreatedAtStr = productCreatedAt?.toDate?.()?.toISOString?.() ?? (typeof productCreatedAt === 'string' ? productCreatedAt : null);
      return {
        id: d.id,
        product: productDoc?.exists ? { id: productDoc.id, name: productDoc.data().name, createdAt: productCreatedAtStr } : null,
        store: s?.exists ? storeRef(s) : null,
        type: r.type,
        quantity: r.quantity,
        previousQuantity: r.previous_quantity,
        newQuantity: r.new_quantity,
        project: projectRef(projectDoc),
        user: userRef(userDoc),
        reference: r.reference,
        notes: r.notes,
        createdAt: r.created_at,
        productCreatedAt: productCreatedAtStr,
      };
    }));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/stock-history/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('stock_history').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Stock history entry not found' });
    await ref.delete();
    res.json({ success: true, message: 'Stock history entry deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
