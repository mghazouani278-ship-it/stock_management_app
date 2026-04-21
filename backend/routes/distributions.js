const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const updateStock = require('../utils/updateStock');
const { protect, authorize, authorizeAdminOrWarehouse } = require('../middleware/auth');
const { createWarehouseDistributionStatusNotification, createAdminDistributionCompletedNotification } = require('./distributionNotifications');
const { projectRef, storeRef } = require('../utils/embedRefs');
const { variantSegmentForStockDocId } = require('../utils/stockColors');

function getStockId(productId, storeId, variantLabel) {
  const c = variantLabel && String(variantLabel).trim().toLowerCase();
  const seg = c ? variantSegmentForStockDocId(c) : '';
  return c && seg ? `${productId}_${storeId}_${seg}` : `${productId}_${storeId}`;
}

/** Get available stock quantity - tries doc ID first, then query fallback for legacy formats */
async function getAvailableStock(firestore, productId, storeId, color) {
  const stockColl = firestore.collection('stock');
  const cNorm = color && String(color).trim().toLowerCase();
  const seg = cNorm ? variantSegmentForStockDocId(cNorm) : '';
  const stockId = getStockId(productId, storeId, color);
  let doc = await stockColl.doc(stockId).get();
  if (doc.exists) return doc.data().quantity || 0;
  // Try alternate ID format: storeId_productId (some legacy formats)
  const altId = cNorm && seg ? `${storeId}_${productId}_${seg}` : `${storeId}_${productId}`;
  doc = await stockColl.doc(altId).get();
  if (doc.exists) return doc.data().quantity || 0;
  // Fallback: query by product_id and match store_id/depot_id
  const matchColor = (d) => !cNorm || (d.color && String(d.color).toLowerCase() === cNorm);
  const snapshot = await stockColl.where('product_id', '==', productId).get();
  for (const d of snapshot.docs) {
    const data = d.data();
    const sid = data.store_id || data.depot_id;
    if (sid === storeId && matchColor(data)) return data.quantity || 0;
  }
  return 0;
}

function toIso(t) {
  return t?.toDate?.()?.toISOString?.() ?? (typeof t === 'string' ? t : null);
}

async function distributionToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const projectDoc = await firestore.collection('projects').doc(data.project_id).get();
  const storeId = data.store_id || data.depot_id;
  const storeDoc = storeId ? await firestore.collection('stores').doc(storeId).get() : null;
  const depotDoc = storeId && (!storeDoc || !storeDoc.exists) ? await firestore.collection('depots').doc(storeId).get() : null;
  const store = storeDoc?.exists ? storeDoc : depotDoc;
  const createdByDoc = await firestore.collection('users').doc(data.created_by).get();
  const validatedByDoc = data.validated_by ? await firestore.collection('users').doc(data.validated_by).get() : null;
  const products = await Promise.all((data.products || []).map(async (p) => {
    const pid = p.product?.id ?? p.product;
    const color = p.color && String(p.color).trim() ? String(p.color).trim().toLowerCase() : null;
    const productDoc = pid ? await firestore.collection('products').doc(pid).get() : null;
    const productName = productDoc?.exists ? productDoc.data().name : null;
    const out = { product: { id: pid, name: productName }, quantity: p.quantity };
    if (color) out.color = color;
    return out;
  }));
  const distDate = data.distribution_date;
  const distDateStr = distDate && typeof distDate.toDate === 'function'
    ? distDate.toDate().toISOString().split('T')[0]
    : (distDate ? new Date(distDate).toISOString().split('T')[0] : null);
  return {
    id: doc.id,
    serialNumber: data.serial_number,
    bonAlimentation: data.bon_alimentation,
    distributionDate: distDateStr,
    project: projectRef(projectDoc),
    store: store?.exists ? storeRef(store) : null,
    products,
    status: data.status,
    validatedBy: validatedByDoc?.exists ? (() => {
      const d = validatedByDoc.data();
      const n = d.name;
      const name = (n && (String(n).toLowerCase() === 'administrator' || String(n).toLowerCase() === 'administrateur')) ? 'administrator' : n;
      return { id: validatedByDoc.id, name, nameAr: d.name_ar || null, email: d.email };
    })() : null,
    validatedAt: toIso(data.validated_at) ?? data.validated_at,
    createdBy: createdByDoc.exists ? (() => {
      const d = createdByDoc.data();
      const n = d.name;
      const name = (n && (String(n).toLowerCase() === 'administrator' || String(n).toLowerCase() === 'administrateur')) ? 'administrator' : n;
      return { id: createdByDoc.id, name, nameAr: d.name_ar || null, email: d.email };
    })() : null,
    notes: data.notes,
    createdAt: toIso(data.created_at) ?? data.created_at,
    updatedAt: toIso(data.updated_at) ?? data.updated_at,
  };
}

router.get('/', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    let q;
    if (req.query.order) {
      q = firestore.collection('distributions').where('order_id', '==', req.query.order);
    } else if (req.query.status) {
      q = firestore.collection('distributions').where('status', '==', req.query.status);
    } else if (req.query.project) {
      // Use where only to avoid Firestore composite index (orderBy+where on different fields)
      q = firestore.collection('distributions').where('project_id', '==', req.query.project);
    } else {
      q = firestore.collection('distributions').orderBy('created_at', 'desc');
    }
    const snapshot = await q.get();
    let docs = snapshot.docs;
    if (req.query.status && req.query.project) {
      docs = docs.filter(d => d.data().project_id === req.query.project);
    }
    // Sort in memory when we used project filter (no orderBy)
    if (req.query.project || req.query.status) {
      docs = docs.sort((a, b) => {
        const va = a.data().validated_at?.toMillis?.() ?? a.data().created_at?.toMillis?.() ?? 0;
        const vb = b.data().validated_at?.toMillis?.() ?? b.data().created_at?.toMillis?.() ?? 0;
        return vb - va;
      });
    }
    const data = await Promise.all(docs.map(d => distributionToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('distributions').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Distribution not found' });
    const data = await distributionToApi(doc, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/** en → English API messages; ar → Arabic; default → French (legacy). */
function apiLang(req) {
  const h = (req.get('accept-language') || '').toLowerCase();
  if (h.startsWith('en')) return 'en';
  if (h.startsWith('ar')) return 'ar';
  return 'fr';
}

function msgInsufficientStockCreate(displayName, available, quantity, req) {
  const lang = apiLang(req);
  if (lang === 'en') {
    return `Insufficient stock for "${displayName}". Available: ${available}, requested: ${quantity}. Register stock before creating the distribution.`;
  }
  if (lang === 'ar') {
    return `مخزون غير كافٍ لـ "${displayName}". المتاح: ${available}، المطلوب: ${quantity}. سجّل المخزون قبل إنشاء التوزيع.`;
  }
  return `Stock insuffisant pour "${displayName}". Disponible: ${available}, Demandé: ${quantity}. Enregistrez le stock avant de créer la distribution.`;
}

function msgInsufficientStockValidate(displayName, available, quantity, req) {
  const lang = apiLang(req);
  if (lang === 'en') {
    return `Insufficient stock for "${displayName}". Available: ${available}, requested: ${quantity}. Add stock before validating.`;
  }
  if (lang === 'ar') {
    return `مخزون غير كافٍ لـ "${displayName}". المتاح: ${available}، المطلوب: ${quantity}. أضف مخزونًا قبل التأكيد.`;
  }
  return `Stock insuffisant pour "${displayName}". Disponible: ${available}, Demandé: ${quantity}. Ajoutez du stock avant de valider.`;
}

function msgNoApprovedOrder(req) {
  const lang = apiLang(req);
  if (lang === 'en') {
    return 'No approved order found for this project and store. Admin must approve an order first.';
  }
  if (lang === 'ar') {
    return 'لا يوجد طلب مُعتمد لهذا المشروع وهذا المخزن. يجب أن يعتمد المسؤول الطلب أولاً.';
  }
  return "Aucune commande approuvee n'a ete trouvee pour ce projet et ce depot. L'admin doit d'abord approuver une commande.";
}

function generateSerialNumber() {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  const suffix = String(Date.now()).slice(-6);
  return `DIST-${yyyy}${mm}${dd}-${suffix}`;
}

const colorFromItem = (c) => (c && String(c).trim() ? String(c).trim().toLowerCase() : null);

/** Merge duplicate distribution lines (same product + color) */
function mergeDistributionProducts(items = []) {
  const merged = new Map();
  for (const raw of items) {
    const productId = raw?.product?.id ?? raw?.product?._id ?? raw?.product;
    const quantity = Number(raw?.quantity || 0);
    if (!productId || !Number.isFinite(quantity) || quantity <= 0) continue;
    const color = colorFromItem(raw?.color);
    const key = `${productId}__${color || ''}`;
    if (!merged.has(key)) {
      const out = { product: productId, quantity };
      if (color) out.color = color;
      merged.set(key, out);
    } else {
      merged.get(key).quantity += quantity;
    }
  }
  return Array.from(merged.values());
}

/**
 * Stock check before deducting (shared by create + validate).
 * @param {'create'|'validate'} messageKind
 */
async function assertStockAvailableForDistribution(firestore, products, storeId, req, messageKind) {
  for (const item of products) {
    const productId = item.product?.id ?? item.product?._id ?? item.product;
    const itemColor = colorFromItem(item.color);
    const quantity = item.quantity || 0;
    const available = await getAvailableStock(firestore, productId, storeId, itemColor);
    if (available < quantity) {
      const productDoc = await firestore.collection('products').doc(productId).get();
      const productName = productDoc?.exists ? productDoc.data().name : productId;
      const displayName = itemColor ? `${productName} (${itemColor})` : productName;
      const msg =
        messageKind === 'create'
          ? msgInsufficientStockCreate(displayName, available, quantity, req)
          : msgInsufficientStockValidate(displayName, available, quantity, req);
      return { status: 400, body: { success: false, message: msg } };
    }
  }
  return null;
}

/**
 * Deduct warehouse stock only.
 * Project BOQ remaining (`projects.products`) is already decremented when the user places an order
 * (`POST /orders`). Applying the same decrement here caused quantities to "double" (rest / distributed wrong).
 */
async function applyDistributionDeductions(firestore, products, projectId, storeId, bonAlimentation, userId) {
  for (const item of products) {
    const productId = item.product?.id ?? item.product?._id ?? item.product;
    const itemColor = colorFromItem(item.color);
    await updateStock(productId, storeId, -item.quantity, 'distribution', {
      project: projectId,
      user: userId,
      reference: bonAlimentation,
      notes: 'Distribution',
      variant: itemColor,
    });
  }
}

async function sendValidatedDistributionNotifications(firestore, ref, data, req, projectId, sid) {
  const projectDoc = projectId ? await firestore.collection('projects').doc(projectId).get() : null;
  const storeDoc = sid ? await firestore.collection('stores').doc(sid).get() : null;
  const depotDoc = sid && (!storeDoc || !storeDoc.exists) ? await firestore.collection('depots').doc(sid).get() : null;
  const store = storeDoc?.exists ? storeDoc : depotDoc;
  const createdBy = data.created_by;
  const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
  if (['warehouse_user', 'warehouse', 'warehouseuser'].includes(role)) {
    await createAdminDistributionCompletedNotification(firestore, {
      distributionId: ref.id,
      bonAlimentation: data.bon_alimentation,
      projectName: projectDoc?.exists ? projectDoc.data().name : null,
      storeName: store?.exists ? store.data().name : null,
      validatedBy: req.user.id,
    });
  } else if (createdBy) {
    await createWarehouseDistributionStatusNotification(firestore, {
      distributionId: ref.id,
      targetUserId: createdBy,
      status: 'accepted',
      bonAlimentation: data.bon_alimentation,
      projectName: projectDoc?.exists ? projectDoc.data().name : null,
      storeName: store?.exists ? store.data().name : null,
    });
  }
}

router.post('/', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const { bonAlimentation, project, store, depot, products, notes, distributionDate, orderId } = req.body;
    const storeId = store || depot;
    if (!project || !storeId || !products || !Array.isArray(products) || products.length === 0) {
      return res.status(400).json({ success: false, message: 'Please provide project, store, and products' });
    }
    const firestore = getFirestore();
    const approvedOrdersSnap = await firestore.collection('orders')
      .where('project_id', '==', project)
      .where('approved_store_id', '==', storeId)
      .where('status', 'in', ['approved', 'completed'])
      .limit(1)
      .get();
    if (approvedOrdersSnap.empty) {
      return res.status(400).json({
        success: false,
        message: msgNoApprovedOrder(req),
      });
    }
    if (orderId && String(orderId).trim()) {
      const existingByOrder = await firestore.collection('distributions')
        .where('order_id', '==', String(orderId).trim())
        .limit(1)
        .get();
      if (!existingByOrder.empty) {
        return res.status(400).json({
          success: false,
          message: 'This approved order already has a distribution',
        });
      }
    }

    const firestoreProducts = mergeDistributionProducts(products.map((p) => {
      const pid = p.product?.id ?? p.product?._id ?? p.product;
      const out = { product: pid, quantity: p.quantity };
      if (p.color && String(p.color).trim()) out.color = String(p.color).trim().toLowerCase();
      return out;
    }));
    const stockErr = await assertStockAvailableForDistribution(firestore, firestoreProducts, storeId, req, 'create');
    if (stockErr) return res.status(stockErr.status).json(stockErr.body);
    const serialNumber = generateSerialNumber();
    const bonValue = bonAlimentation && String(bonAlimentation).trim() ? bonAlimentation.trim() : serialNumber;
    const existing = await firestore.collection('distributions').where('bon_alimentation', '==', bonValue).limit(1).get();
    if (!existing.empty) return res.status(400).json({ success: false, message: 'Bon Alimentation/Serial number already exists' });
    const distDate = distributionDate ? new Date(distributionDate) : admin.firestore.FieldValue.serverTimestamp();
    const ref = await firestore.collection('distributions').add({
      serial_number: serialNumber,
      bon_alimentation: bonValue,
      project_id: project,
      store_id: storeId,
      order_id: orderId && String(orderId).trim() ? String(orderId).trim() : null,
      status: 'pending',
      created_by: req.user.id,
      distribution_date: distDate,
      notes: notes || null,
      products: firestoreProducts,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    try {
      await applyDistributionDeductions(firestore, firestoreProducts, project, storeId, bonValue, req.user.id);
    } catch (deductErr) {
      try {
        await ref.delete();
      } catch (_) {
        /* ignore */
      }
      throw deductErr;
    }
    await ref.update({
      status: 'validated',
      validated_by: req.user.id,
      validated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (orderId && String(orderId).trim()) {
      const orderRef = firestore.collection('orders').doc(String(orderId).trim());
      const orderDoc = await orderRef.get();
      if (orderDoc.exists) {
        const st = orderDoc.data().status;
        if (st === 'approved' || st === 'completed') {
          await orderRef.update({
            status: 'completed',
            delivery_date: admin.firestore.FieldValue.serverTimestamp(),
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    }
    const doc = await ref.get();
    const data = await distributionToApi(doc, firestore);
    await sendValidatedDistributionNotifications(firestore, ref, doc.data(), req, project, storeId);
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/validate', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('distributions').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Distribution not found' });
    const data = doc.data();
    if (data.status === 'validated') return res.status(400).json({ success: false, message: 'Distribution already validated' });
    const products = mergeDistributionProducts(data.products || []);
    const projectId = data.project_id;
    const sid = data.store_id || data.depot_id;

    const stockErr = await assertStockAvailableForDistribution(firestore, products, sid, req, 'validate');
    if (stockErr) return res.status(stockErr.status).json(stockErr.body);

    await applyDistributionDeductions(firestore, products, projectId, sid, data.bon_alimentation, req.user.id);

    await ref.update({
      status: 'validated',
      validated_by: req.user.id,
      validated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const updated = await ref.get();
    const out = await distributionToApi(updated, firestore);
    await sendValidatedDistributionNotifications(firestore, ref, data, req, projectId, sid);
    res.json({ success: true, data: out });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/refuse', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('distributions').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Distribution not found' });
    const data = doc.data();
    if (data.status !== 'pending') return res.status(400).json({ success: false, message: 'Only pending distributions can be refused' });
    await ref.update({
      status: 'refused',
      refused_at: admin.firestore.FieldValue.serverTimestamp(),
      refused_by: req.user.id,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const updated = await ref.get();
    const out = await distributionToApi(updated, firestore);
    const createdBy = data.created_by;
    if (createdBy) {
      const projectId = data.project_id;
      const sid = data.store_id || data.depot_id;
      const projectDoc = projectId ? await firestore.collection('projects').doc(projectId).get() : null;
      const storeDoc = sid ? await firestore.collection('stores').doc(sid).get() : null;
      const depotDoc = sid && (!storeDoc || !storeDoc.exists) ? await firestore.collection('depots').doc(sid).get() : null;
      const store = storeDoc?.exists ? storeDoc : depotDoc;
      await createWarehouseDistributionStatusNotification(firestore, {
        distributionId: ref.id,
        targetUserId: createdBy,
        status: 'refused',
        bonAlimentation: data.bon_alimentation,
        projectName: projectDoc?.exists ? projectDoc.data().name : null,
        storeName: store?.exists ? store.data().name : null,
      });
    }
    res.json({ success: true, data: out });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('distributions').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Distribution not found' });
    await ref.delete();
    res.json({ success: true, message: 'Distribution deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
