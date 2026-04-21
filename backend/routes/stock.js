const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const updateStock = require('../utils/updateStock');
const { variantSegmentForStockDocId } = require('../utils/stockColors');
const { protect, authorize, authorizeAdminOrWarehouse } = require('../middleware/auth');
const { projectRef, storeRef, userRef } = require('../utils/embedRefs');

/** JSON number or string with `,` or `.` as decimal separator (e.g. m² quantities: 2,01). */
function parseQuantityInput(v) {
  if (v === undefined || v === null) return NaN;
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  const s = String(v).trim().replace(/\s/g, '').replace(/\u00a0/g, '').replace(',', '.');
  if (s === '') return NaN;
  const n = parseFloat(s);
  return Number.isFinite(n) ? n : NaN;
}

/** Segment after `${productId}_${storeId}_` in stock doc id; aligns with Flutter `stock.dart` prefix logic. */
function variantSegmentFromStockDocId(docId, productId, storeId) {
  if (!docId || !productId || !storeId) return null;
  const p = String(productId).trim();
  const s = String(storeId).trim();
  if (!p || !s) return null;
  const prefix = `${p}_${s}_`;
  if (docId.startsWith(prefix)) {
    const seg = docId.substring(prefix.length);
    return seg || null;
  }
  if (docId === `${p}_${s}`) return null;
  const idParts = docId.split('_');
  if (idParts.length >= 3) return idParts.slice(2).join('_');
  return null;
}

/** Create notification for admin when warehouse user edits stock */
async function createStockNotification(firestore, { productId, storeId, userId, quantityChange, productName, storeName, variant }) {
  const doc = {
    product_id: productId,
    store_id: storeId,
    user_id: userId,
    quantity_change: quantityChange,
    product_name: productName || null,
    store_name: storeName || null,
    read: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (variant && String(variant).trim()) {
    const v = String(variant).trim().toLowerCase();
    doc.variant = v;
    doc.color = v;
  }
  await firestore.collection('stock_notifications').add(doc);
}

/**
 * Shape returned by GET /stock and POST/PUT responses.
 *
 * - `id` is the Firestore document id. For a variant line it is built as:
 *   `${productId}_${storeId}_${variantSegmentForStockDocId(variantLabel)}`
 *   (see ../utils/stockColors.js). Without variant: `${productId}_${storeId}`.
 * - `variant` and `color` are the same normalized label (lowercase when matched from product).
 *   They come from document fields first; if missing, they are recovered from `id` by matching
 *   the id segment to `product.available_colors` (same encoding as create), else a readable
 *   fallback from the segment.
 *
 * Limitation: parsing `id` with `split('_')` assumes `productId` and `storeId` do not contain `_`.
 * Firestore auto-ids usually satisfy this; custom ids with `_` would mis-parse variant segments.
 */
async function stockToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const productDoc = await firestore.collection('products').doc(data.product_id).get();
  const storeId = data.store_id || data.depot_id;
  const storeDoc = storeId ? await firestore.collection('stores').doc(storeId).get() : null;
  const depotDoc = storeId && (!storeDoc || !storeDoc.exists) ? await firestore.collection('depots').doc(storeId).get() : null;
  const store = storeDoc?.exists ? storeDoc : depotDoc;
  const pd = productDoc.exists ? productDoc.data() : null;
  let productPayload = null;
  if (pd) {
    const cat = pd.category;
    const categories = Array.isArray(cat) ? cat : (cat ? [cat] : []);
    const catArRaw = pd.category_ar ?? pd.categoryAr;
    const categoriesAr = Array.isArray(catArRaw) ? catArRaw : (catArRaw != null ? [String(catArRaw)] : []);
    const colorsRaw = pd.available_colors ?? pd.availableColors;
    const availableColors = Array.isArray(colorsRaw) ? colorsRaw : (colorsRaw ? [colorsRaw] : []);
    const colorsArRaw = pd.available_colors_ar ?? pd.availableColorsAr;
    const availableColorsAr = Array.isArray(colorsArRaw) ? colorsArRaw : (colorsArRaw ? [colorsArRaw] : []);
    productPayload = {
      id: productDoc.id,
      name: pd.name,
      name_ar: pd.name_ar || null,
      category: categories,
      category_ar: categoriesAr.length ? categoriesAr : null,
      unit: pd.unit,
      manufacturer: (() => {
        const raw = pd.manufacturer ?? pd.manufacture ?? pd.Manufacture;
        const s = raw != null ? String(raw).trim() : '';
        return s || null;
      })(),
      available_colors: availableColors.map((c) => String(c).toLowerCase()),
      available_colors_ar: availableColorsAr.length ? availableColorsAr : null,
    };
  }
  // Stock doc id is often `productId_storeId_${segment}` while Firestore fields may omit variant/color
  // (legacy rows or quantity-only updates). Match segment to product.available_colors like PUT /:id does.
  let variantVal = data.variant ?? data.color ?? null;
  if (variantVal != null && String(variantVal).trim() !== '') {
    variantVal = String(variantVal).trim();
  } else {
    variantVal = null;
    const pid = data.product_id;
    const sid = data.store_id || data.depot_id;
    const segment = variantSegmentFromStockDocId(doc.id, pid, sid);
    if (segment) {
      const colorsRaw = pd ? (pd.available_colors ?? pd.availableColors) : null;
      const arr = Array.isArray(colorsRaw) ? colorsRaw : (colorsRaw != null ? [colorsRaw] : []);
      for (const c of arr) {
        if (variantSegmentForStockDocId(String(c)) === segment) {
          variantVal = String(c).trim().toLowerCase();
          break;
        }
      }
      if (variantVal == null && segment) {
        variantVal = segment.replace(/_/g, ' ');
      }
    }
  }
  const sidOut = data.store_id || data.depot_id || null;
  return {
    id: doc.id,
    product_id: data.product_id ?? null,
    store_id: sidOut,
    product: productPayload,
    store: store?.exists ? storeRef(store) : null,
    quantity: data.quantity,
    variant: variantVal,
    color: variantVal,
    updatedAt: data.updated_at,
  };
}

router.get('/notifications', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('stock_notifications').orderBy('created_at', 'desc').limit(50).get();
    const data = snapshot.docs.map((d) => {
      const r = d.data();
      const item = {
        id: d.id,
        type: 'stock',
        productId: r.product_id,
        productName: r.product_name,
        storeId: r.store_id,
        storeName: r.store_name,
        quantityChange: r.quantity_change,
        read: r.read,
        createdAt: r.created_at,
      };
      const v = r.variant ?? r.color;
      if (v) {
        item.variant = v;
        item.color = v;
      }
      return item;
    });
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/notifications-count', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('stock_notifications').where('read', '==', false).get();
    res.json({ success: true, count: snapshot.size });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/notifications-read', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('stock_notifications').where('read', '==', false).get();
    const batch = firestore.batch();
    snapshot.docs.forEach((d) => batch.update(d.ref, { read: true }));
    await batch.commit();
    res.json({ success: true, count: snapshot.size });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/** Nombre de produits distincts ayant au moins une ligne en stock (admin dashboard). */
router.get('/distinct-products-count', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('stock').select('product_id').get();
    const ids = new Set();
    for (const d of snapshot.docs) {
      const pid = d.data().product_id;
      if (pid) ids.add(String(pid));
    }
    res.json({ success: true, count: ids.size });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * Stock rows for one physical location. Documents may set only `store_id`, only `depot_id`,
 * or both (see updateStock). Querying one field misses legacy rows; merging avoids empty GET /stock.
 * Avoids orderBy+where composite index issues that break filtered lists in production.
 */
async function stockDocsForLocation(firestore, locationId) {
  const loc = String(locationId || '').trim();
  if (!loc) return [];
  const [snapStore, snapDepot] = await Promise.all([
    firestore.collection('stock').where('store_id', '==', loc).get(),
    firestore.collection('stock').where('depot_id', '==', loc).get(),
  ]);
  const merged = new Map();
  for (const d of snapStore.docs) merged.set(d.id, d);
  for (const d of snapDepot.docs) merged.set(d.id, d);
  const ms = (d) => {
    const t = d.data().updated_at;
    return typeof t?.toMillis === 'function' ? t.toMillis() : 0;
  };
  return [...merged.values()].sort((a, b) => ms(b) - ms(a));
}

router.get('/', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const locationId = req.query.store || req.query.depot;
    if (locationId) {
      let docs = await stockDocsForLocation(firestore, locationId);
      if (req.query.product) {
        const pid = String(req.query.product).trim();
        docs = docs.filter((d) => String(d.data().product_id || '') === pid);
      }
      const data = await Promise.all(docs.map((d) => stockToApi(d, firestore)));
      return res.json({ success: true, count: data.length, data });
    }
    let q = firestore.collection('stock').orderBy('updated_at', 'desc');
    if (req.query.product) q = q.where('product_id', '==', req.query.product);
    const snapshot = await q.get();
    const data = await Promise.all(snapshot.docs.map(d => stockToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/history', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    let q = firestore.collection('stock_history').orderBy('created_at', 'desc').limit(1000);
    if (req.query.store) q = q.where('store_id', '==', req.query.store);
    else if (req.query.depot) q = q.where('depot_id', '==', req.query.depot);
    if (req.query.product) q = q.where('product_id', '==', req.query.product);
    if (req.query.project) q = q.where('project_id', '==', req.query.project);
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
      return {
        id: d.id,
        product: productDoc?.exists ? { id: productDoc.id, name: productDoc.data().name } : null,
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
      };
    }));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const { productId, storeId, depotId, quantity, mode, color, variant } = req.body;
    const sid = storeId || depotId;
    if (!productId || !sid) return res.status(400).json({ success: false, message: 'Please provide productId and storeId' });
    const qty = quantity !== undefined ? parseQuantityInput(quantity) : 0;
    if (!Number.isFinite(qty) || qty <= 0) return res.status(400).json({ success: false, message: 'Please provide a valid quantity (> 0)' });
    const firestore = getFirestore();
    const rawVariant = variant ?? color;
    const variantVal = rawVariant && String(rawVariant).trim() ? String(rawVariant).trim().toLowerCase() : null;
    const vSeg = variantVal ? variantSegmentForStockDocId(variantVal) : '';
    const stockId = variantVal && vSeg ? `${productId}_${sid}_${vSeg}` : `${productId}_${sid}`;
    const ref = firestore.collection('stock').doc(stockId);
    const doc = await ref.get();
    const current = doc.exists ? (doc.data().quantity || 0) : 0;
    const change = (req.user.role === 'warehouse_user' || mode === 'add') ? qty : (qty - current);
    await updateStock(productId, sid, change, req.user.role === 'warehouse_user' ? 'stock_entry' : 'initial', {
      user: req.user.id,
      variant: variantVal,
      notes: req.user.role === 'warehouse_user' ? 'Stock entry by warehouse' : 'Initial stock',
    });
    if (req.user.role === 'warehouse_user') {
      const productDoc = await firestore.collection('products').doc(productId).get();
      const storeDoc = await firestore.collection('stores').doc(sid).get();
      const depotDoc = (!storeDoc || !storeDoc.exists) ? await firestore.collection('depots').doc(sid).get() : null;
      const store = storeDoc?.exists ? storeDoc : depotDoc;
      await createStockNotification(firestore, {
        productId,
        storeId: sid,
        userId: req.user.id,
        quantityChange: change,
        productName: productDoc?.exists ? productDoc.data().name : null,
        storeName: store?.exists ? store.data().name : null,
        variant: variantVal,
      });
    }
    const updated = await ref.get();
    const data = await stockToApi(updated, firestore);
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const { quantity, productId: bodyProductId, storeId: bodyStoreId, depotId: bodyDepotId, variant: bodyVariant, color: bodyColor } = req.body;
    if (quantity === undefined) return res.status(400).json({ success: false, message: 'Please provide a valid quantity (>= 0)' });
    const newQty = parseQuantityInput(quantity);
    if (!Number.isFinite(newQty) || newQty < 0) return res.status(400).json({ success: false, message: 'Invalid quantity' });

    const firestore = getFirestore();
    const ref = firestore.collection('stock').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Stock record not found' });
    const row = doc.data();
    const oldProductId = row.product_id;
    const oldStoreId = row.store_id || row.depot_id;
    if (!oldProductId || !oldStoreId) return res.status(400).json({ success: false, message: 'Invalid stock document' });

    const pid = bodyProductId != null && String(bodyProductId).trim() !== '' ? String(bodyProductId).trim() : oldProductId;
    const sid = (() => {
      if (bodyStoreId != null && String(bodyStoreId).trim() !== '') return String(bodyStoreId).trim();
      if (bodyDepotId != null && String(bodyDepotId).trim() !== '') return String(bodyDepotId).trim();
      return oldStoreId;
    })();

    let variantVal = null;
    if (bodyVariant !== undefined || bodyColor !== undefined) {
      const r = bodyVariant !== undefined ? bodyVariant : bodyColor;
      if (r != null && String(r).trim() !== '') variantVal = String(r).trim().toLowerCase();
    } else if (pid === oldProductId && sid === oldStoreId) {
      const segment = variantSegmentFromStockDocId(doc.id, oldProductId, oldStoreId);
      const variantFromId = segment || null;
      const fromRow = row.variant ?? row.color ?? variantFromId;
      variantVal = fromRow != null && String(fromRow).trim() !== '' ? String(fromRow).trim().toLowerCase() : null;
    } else {
      variantVal = null;
    }

    const vSeg = variantVal ? variantSegmentForStockDocId(variantVal) : '';
    const newStockId = variantVal && vSeg ? `${pid}_${sid}_${vSeg}` : `${pid}_${sid}`;

    if (newStockId === req.params.id) {
      const segment = variantSegmentFromStockDocId(doc.id, pid, sid);
      const variantFromId = segment || null;
      const current = row.quantity || 0;
      const change = newQty - current;
      const variantLabel = variantVal ?? row.variant ?? row.color ?? variantFromId;
      await updateStock(pid, sid, change, 'manual_update', { user: req.user.id, variant: variantLabel, notes: 'Manual stock update' });
      const updated = await ref.get();
      const payload = await stockToApi(updated, firestore);
      return res.json({ success: true, data: payload });
    }

    const targetRef = firestore.collection('stock').doc(newStockId);
    const targetSnap = await targetRef.get();
    if (targetSnap.exists) {
      return res.status(409).json({
        success: false,
        message: 'A stock line already exists for this product, store and variant. Edit or remove the other line first.',
      });
    }

    const currentOld = row.quantity || 0;
    if (currentOld > 0) {
      const segment = variantSegmentFromStockDocId(doc.id, oldProductId, oldStoreId);
      const variantFromId = segment || null;
      const variantLabel = row.variant ?? row.color ?? variantFromId;
      await updateStock(oldProductId, oldStoreId, -currentOld, 'manual_update', { user: req.user.id, variant: variantLabel, notes: 'Stock line replaced (edit)' });
    }
    await ref.delete();

    await updateStock(pid, sid, newQty, 'manual_update', { user: req.user.id, variant: variantVal, notes: 'Stock line updated (edit)' });
    const newDoc = await targetRef.get();
    const payload = await stockToApi(newDoc, firestore);
    return res.json({ success: true, data: payload });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('stock').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Stock record not found' });
    const data = doc.data();
    const productId = data.product_id;
    const storeId = data.store_id || data.depot_id;
    if (!productId || !storeId) return res.status(400).json({ success: false, message: 'Invalid stock document' });
    const current = data.quantity || 0;
    if (current > 0) {
      const segment = variantSegmentFromStockDocId(doc.id, productId, storeId);
      const variantFromId = segment || null;
      const variantLabel = data.variant ?? data.color ?? variantFromId;
      await updateStock(productId, storeId, -current, 'manual_update', { user: req.user.id, variant: variantLabel, notes: 'Stock record deleted' });
    }
    await ref.delete();
    res.json({ success: true, message: 'Stock record deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
