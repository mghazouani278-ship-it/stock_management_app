const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { protect, authorize } = require('../middleware/auth');
const updateStock = require('../utils/updateStock');

function parseQuantityInput(v) {
  if (v === undefined || v === null) return NaN;
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  const s = String(v).trim().replace(/\s/g, '').replace(/\u00a0/g, '').replace(',', '.');
  if (s === '') return NaN;
  const n = parseFloat(s);
  return Number.isFinite(n) ? n : NaN;
}

async function productToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const storesMap = data.stores || data.depots || {};
  const stores = [];
  for (const [storeId, quantity] of Object.entries(storesMap)) {
    const storeDoc = await firestore.collection('stores').doc(storeId).get();
    stores.push({
      store: storeDoc.exists
        ? { id: storeId, name: storeDoc.data().name, location: storeDoc.data().location, description: storeDoc.data().description }
        : { id: storeId },
      quantity,
    });
  }
  const category = data.category;
  const categories = Array.isArray(category) ? category : (category ? [category] : []);
  const colorsRaw = data.available_colors ?? data.availableColors;
  const availableColors = Array.isArray(colorsRaw) ? colorsRaw : (colorsRaw ? [colorsRaw] : []);
  const colorsArRaw = data.available_colors_ar ?? data.availableColorsAr;
  const availableColorsAr = Array.isArray(colorsArRaw) ? colorsArRaw : (colorsArRaw ? [colorsArRaw] : []);
  const catArRaw = data.category_ar ?? data.categoryAr;
  const categoriesAr = Array.isArray(catArRaw) ? catArRaw : (catArRaw != null ? [String(catArRaw)] : []);
  const manufacturerVal = (() => {
    const raw = data.manufacturer ?? data.manufacture ?? data.Manufacture;
    const s = raw != null ? String(raw).trim() : '';
    return s || null;
  })();
  return {
    id: doc.id,
    name: data.name,
    name_ar: data.name_ar || null,
    image: data.image || null,
    category: categories,
    category_ar: categoriesAr.length ? categoriesAr : null,
    unit: data.unit,
    manufacturer: manufacturerVal,
    distributor: data.distributor,
    status: data.status,
    stores,
    availableColors: availableColors,
    available_colors_ar: availableColorsAr.length ? availableColorsAr : null,
    createdAt: data.created_at,
    updatedAt: data.updated_at,
  };
}

router.get('/', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    let snapshot;
    if (req.user.role === 'user' && req.user.project && req.user.project.products) {
      const productIds = req.user.project.products.map(p => p.product.id);
      if (productIds.length === 0) return res.json({ success: true, count: 0, data: [] });
      const results = await Promise.all(productIds.map(id => firestore.collection('products').doc(id).get()));
      const docs = results.filter(d => d.exists && d.data().status === 'active');
      const data = await Promise.all(docs.map(d => productToApi(d, firestore)));
      return res.json({ success: true, count: data.length, data });
    }
    snapshot = await firestore.collection('products').orderBy('created_at', 'desc').get();
    const data = await Promise.all(snapshot.docs.map(d => productToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('products').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Product not found' });
    if (req.user.role === 'user' && req.user.project) {
      const hasAccess = req.user.project.products.some(p => String(p.product.id || p.product._id) === req.params.id);
      if (!hasAccess) return res.status(403).json({ success: false, message: 'You do not have access to this product' });
    }
    const data = await productToApi(doc, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/', protect, authorize('admin'), async (req, res) => {
  try {
    const { name, nameAr, name_ar, image, category, categories, categoryAr, category_ar, unit, manufacturer, distributor, status, stores, depots, availableColorsAr, available_colors_ar } = req.body;
    if (!name || !unit) return res.status(400).json({ success: false, message: 'Please provide name and unit' });
    const nameArVal = nameAr ?? name_ar;
    const catArr = Array.isArray(categories) ? categories : (Array.isArray(category) ? category : (category ? [category] : []));
    const catArIn = categoryAr ?? category_ar;
    let category_ar_store = null;
    if (catArIn != null) {
      if (Array.isArray(catArIn)) category_ar_store = catArIn.map((s) => String(s).trim()).filter(Boolean);
      else if (String(catArIn).trim()) category_ar_store = [String(catArIn).trim()];
    }
    const colorsArIn = availableColorsAr ?? available_colors_ar;
    let available_colors_ar_store = null;
    if (colorsArIn != null) {
      available_colors_ar_store = Array.isArray(colorsArIn)
        ? colorsArIn.map((s) => String(s).trim())
        : [String(colorsArIn).trim()];
    }
    const firestore = getFirestore();
    const storesMap = {};
    const list = stores || depots || [];
    if (Array.isArray(list)) {
      for (const d of list) {
        const storeId = d.store?.id ?? d.depot?.id ?? d.store ?? d.depot;
        if (storeId) storesMap[storeId] = d.quantity ?? 0;
      }
    }
    const colorsArr = req.body.availableColors ?? req.body.available_colors;
    const availableColors = Array.isArray(colorsArr) ? colorsArr : (colorsArr ? [colorsArr] : []);
    const ref = await firestore.collection('products').add({
      name,
      name_ar: nameArVal && String(nameArVal).trim() ? String(nameArVal).trim() : null,
      image: image || null,
      category: catArr,
      category_ar: category_ar_store && category_ar_store.length ? category_ar_store : null,
      unit,
      manufacturer: manufacturer || null,
      distributor: distributor || null,
      status: status || 'active',
      stores: storesMap,
      available_colors: availableColors,
      available_colors_ar: available_colors_ar_store && available_colors_ar_store.length ? available_colors_ar_store : null,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const productId = ref.id;
    for (const [storeId, qty] of Object.entries(storesMap)) {
      const quantity = parseQuantityInput(qty);
      const q = Number.isFinite(quantity) ? quantity : 0;
      if (q > 0) {
        await updateStock(productId, storeId, q, 'initial', { user: req.user.id, notes: 'Initial stock from product' });
      }
    }
    const doc = await ref.get();
    const data = await productToApi(doc, firestore);
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const { name, nameAr, name_ar, image, category, categories, categoryAr, category_ar, unit, manufacturer, distributor, status, depots, availableColorsAr, available_colors_ar } = req.body;
    const firestore = getFirestore();
    const ref = firestore.collection('products').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Product not found' });
    const updates = { updated_at: admin.firestore.FieldValue.serverTimestamp() };
    if (name != null) updates.name = name;
    const nameArVal = nameAr ?? name_ar;
    if (nameArVal !== undefined) updates.name_ar = nameArVal && String(nameArVal).trim() ? String(nameArVal).trim() : null;
    if (image !== undefined) updates.image = image;
    const catArr = categories !== undefined
      ? (Array.isArray(categories) ? categories : (categories ? [categories] : []))
      : (category !== undefined ? (Array.isArray(category) ? category : (category ? [category] : [])) : undefined);
    if (catArr !== undefined) updates.category = catArr;
    if (unit != null) updates.unit = unit;
    if (manufacturer !== undefined) updates.manufacturer = manufacturer;
    if (distributor !== undefined) updates.distributor = distributor;
    if (status != null) updates.status = status;
    const list = depots || req.body.stores;
    if (list && Array.isArray(list)) {
      const storesMap = {};
      for (const d of list) {
        const storeId = d.store?.id ?? d.depot?.id ?? d.store ?? d.depot;
        if (storeId) storesMap[storeId] = d.quantity ?? 0;
      }
      updates.stores = storesMap;
      const productId = req.params.id;
      const stockColl = firestore.collection('stock');
      for (const [storeId, newQty] of Object.entries(storesMap)) {
        const parsed = parseQuantityInput(newQty);
        const targetQty = Number.isFinite(parsed) ? parsed : 0;
        const stockDoc = await stockColl.doc(`${productId}_${storeId}`).get();
        const currentQty = stockDoc.exists ? (stockDoc.data().quantity || 0) : 0;
        const change = targetQty - currentQty;
        if (change !== 0) {
          await updateStock(productId, storeId, change, 'manual_update', { user: req.user.id, notes: 'Stock sync from product update' });
        }
      }
    }
    const colorsArr = req.body.availableColors ?? req.body.available_colors;
    if (colorsArr !== undefined) {
      updates.available_colors = Array.isArray(colorsArr) ? colorsArr : (colorsArr ? [colorsArr] : []);
    }
    const catArInPut = categoryAr ?? category_ar;
    if (catArInPut !== undefined) {
      if (catArInPut == null) updates.category_ar = null;
      else if (Array.isArray(catArInPut)) updates.category_ar = catArInPut.map((s) => String(s).trim()).filter(Boolean);
      else updates.category_ar = String(catArInPut).trim() ? [String(catArInPut).trim()] : null;
    }
    const colorsArPut = availableColorsAr ?? available_colors_ar;
    if (colorsArPut !== undefined) {
      if (colorsArPut == null) updates.available_colors_ar = null;
      else updates.available_colors_ar = Array.isArray(colorsArPut)
        ? colorsArPut.map((s) => String(s).trim())
        : [String(colorsArPut).trim()];
    }
    await ref.update(updates);
    const updated = await ref.get();
    const data = await productToApi(updated, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('products').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Product not found' });
    await ref.delete();
    res.json({ success: true, message: 'Product deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/:id/assign-store', protect, authorize('admin'), async (req, res) => {
  try {
    const { storeId, depotId, quantity } = req.body;
    const sid = storeId || depotId;
    if (!sid) return res.status(400).json({ success: false, message: 'Please provide store ID' });
    const firestore = getFirestore();
    const ref = firestore.collection('products').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Product not found' });
    const data = doc.data();
    const stores = { ...(data.stores || data.depots || {}) };
    const fromBody = quantity !== undefined ? parseQuantityInput(quantity) : NaN;
    const fromStore = parseQuantityInput(stores[sid]);
    const targetQty = quantity !== undefined
      ? (Number.isFinite(fromBody) ? fromBody : 0)
      : (Number.isFinite(fromStore) ? fromStore : 0);
    stores[sid] = targetQty;
    const productId = req.params.id;
    const stockDoc = await firestore.collection('stock').doc(`${productId}_${sid}`).get();
    const currentQty = stockDoc.exists ? (stockDoc.data().quantity || 0) : 0;
    const change = targetQty - currentQty;
    if (change !== 0) {
      await updateStock(productId, sid, change, 'manual_update', { user: req.user.id, notes: 'Stock sync from assign-store' });
    }
    await ref.update({ stores, updated_at: admin.firestore.FieldValue.serverTimestamp() });
    const updated = await ref.get();
    const out = await productToApi(updated, firestore);
    res.json({ success: true, data: out });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
