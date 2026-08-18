const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const updateStock = require('../utils/updateStock');
const {protect, authorize, authorizeAdminOrWarehouse, authorizeAdminLike, authorizeAdminWarehouseOrSupervisor} = require('../middleware/auth');
const { createWarehouseDistributionStatusNotification, createAdminDistributionCompletedNotification } = require('./distributionNotifications');
const { projectRef, storeRef, userRef } = require('../utils/embedRefs');
const { variantSegmentForStockDocId } = require('../utils/stockColors');
const { buildStoreByProductKey, makeProductKey } = require('../utils/resolveProductStockStore');
const { isAdminLike, isWarehouseLike, isSupervisor, userHasProjectAccess } = require('../utils/roles');
const { toYmd, clearLateNotificationsForOrder } = require('../utils/lateOrders');

async function applyOrderDistributed(firestore, orderId, distributionDate) {
  if (!orderId || !String(orderId).trim()) return;
  const orderRef = firestore.collection('orders').doc(String(orderId).trim());
  const orderDoc = await orderRef.get();
  if (!orderDoc.exists) return;
  const st = orderDoc.data().status;
  if (st !== 'approved' && st !== 'completed') return;
  let distYmd = toYmd(distributionDate);
  if (!distYmd) distYmd = new Date().toISOString().split('T')[0];
  await orderRef.update({
    status: 'completed',
    distribution_date: distYmd,
    arrival_date: distYmd,
    delivery_date: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  await clearLateNotificationsForOrder(firestore, orderRef.id);
}

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

/** YYYY-MM-DD only (no time / Z). */
function toDateOnly(t) {
  const iso = toIso(t) ?? (typeof t === 'string' ? t : null);
  if (!iso) return null;
  const s = String(iso);
  if (s.length >= 10 && /^\d{4}-\d{2}-\d{2}/.test(s)) return s.slice(0, 10);
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch (_) {
    return null;
  }
}

function orderProductId(p) {
  return String(p?.product?.id ?? p?.product?._id ?? p?.product ?? '');
}

/** Find matching replaced order line for a distribution product. */
function findOrderReplacementLine(orderData, distProduct) {
  const orig = String(distProduct.original_product_id || distProduct.originalProductId || '');
  const ship = String(
    distProduct.replacement_product_id
      || distProduct.replacementProductId
      || distProduct.product?.id
      || distProduct.product
      || ''
  );
  for (const op of orderData?.products || []) {
    const oOrig = String(op.original_product_id ?? op.originalProductId ?? orderProductId(op));
    const oShip = String(op.replacement_product_id ?? op.replacementProductId ?? orderProductId(op));
    const oReplaced = !!(
      op.is_replaced
      ?? op.isReplaced
      ?? (op.replacement_product_id && String(op.replacement_product_id) !== oOrig)
    );
    if (!oReplaced) continue;
    if (oOrig === orig && oShip === ship) return op;
  }
  return null;
}

/** Manager (or admin) who approved the order — from audit history. */
function orderApproverId(orderData) {
  const history = Array.isArray(orderData?.history) ? orderData.history : [];
  for (let i = history.length - 1; i >= 0; i -= 1) {
    const h = history[i];
    const to = h?.toStatus ?? h?.to_status ?? h?.to;
    if ((h?.action === 'status_change' || h?.action === 'statusChange') && to === 'approved') {
      return h.actorId || h.actor_id || h.by || null;
    }
  }
  return null;
}

/**
 * Copy Admin/Manager replacement audit from the order onto distribution lines
 * (warehouse ships; they must not appear as the person who replaced).
 */
function enrichReplacementsFromOrder(firestoreProducts, orderData) {
  if (!orderData) return firestoreProducts;
  for (const p of firestoreProducts) {
    if (!p.is_replaced) continue;
    const op = findOrderReplacementLine(orderData, p);
    if (!op) continue;
    const by = op.replaced_by ?? op.replacedBy;
    const at = op.replaced_at ?? op.replacedAt;
    if (by) p.replaced_by = String(by);
    if (at) p.replaced_at = toDateOnly(at) || at;
  }
  return firestoreProducts;
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

  let orderData = null;
  if (data.order_id) {
    const orderDoc = await firestore.collection('orders').doc(String(data.order_id)).get();
    if (orderDoc.exists) orderData = orderDoc.data();
  }

  // Prefer manager who approved the linked order as "Validated by".
  let validatedById = data.validated_by || null;
  if (orderData) {
    const approverId = orderApproverId(orderData);
    if (approverId) validatedById = String(approverId);
  }
  const validatedByDoc = validatedById ? await firestore.collection('users').doc(String(validatedById)).get() : null;

  const products = await Promise.all((data.products || []).map(async (p) => {
    const pid = p.product?.id ?? p.product;
    const color = p.color && String(p.color).trim() ? String(p.color).trim().toLowerCase() : null;
    const productDoc = pid ? await firestore.collection('products').doc(String(pid)).get() : null;
    const productName = productDoc?.exists ? productDoc.data().name : null;
    const unit = productDoc?.exists ? (productDoc.data().unit || null) : null;
    const originalId = p.original_product_id ?? p.originalProductId ?? null;
    const replacementId = p.replacement_product_id ?? p.replacementProductId ?? null;
    const isReplaced = !!(p.is_replaced ?? p.isReplaced ?? replacementId);
    const orderLine = isReplaced && orderData ? findOrderReplacementLine(orderData, p) : null;
    const replacedById = (orderLine?.replaced_by ?? orderLine?.replacedBy ?? p.replaced_by) || null;
    const replacedAtRaw = orderLine?.replaced_at ?? orderLine?.replacedAt ?? p.replaced_at ?? null;
    const out = {
      product: { id: pid, name: productName, unit },
      quantity: p.quantity,
      isReplaced,
      originalProductId: originalId ? String(originalId) : null,
      replacementProductId: replacementId ? String(replacementId) : null,
      replacedAt: toDateOnly(replacedAtRaw),
    };
    if (color) out.color = color;
    if (originalId) {
      const od = await firestore.collection('products').doc(String(originalId)).get();
      out.originalProduct = od.exists
        ? { id: od.id, name: od.data().name, unit: od.data().unit || null }
        : { id: String(originalId) };
    }
    if (replacementId) {
      const rd = await firestore.collection('products').doc(String(replacementId)).get();
      out.replacementProduct = rd.exists
        ? { id: rd.id, name: rd.data().name, unit: rd.data().unit || null }
        : { id: String(replacementId) };
    }
    if (replacedById) {
      const ub = await firestore.collection('users').doc(String(replacedById)).get();
      out.replacedBy = userRef(ub);
    }
    return out;
  }));
  const history = Array.isArray(data.history)
    ? data.history.map((h) => ({
        action: h?.action || null,
        at: toDateOnly(h?.at) || toIso(h?.at) || null,
        by: h?.by || null,
        originalProductId: h?.original_product_id || h?.originalProductId || null,
        replacementProductId: h?.replacement_product_id || h?.replacementProductId || null,
        quantity: h?.quantity ?? null,
        note: h?.note || null,
      }))
    : [];
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
    history,
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
    orderId: data.order_id || null,
    createdAt: toIso(data.created_at) ?? data.created_at,
    updatedAt: toIso(data.updated_at) ?? data.updated_at,
  };
}

router.get('/', protect, authorizeAdminWarehouseOrSupervisor, async (req, res) => {
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
    if (isSupervisor(req.user?.role)) {
      docs = docs.filter((d) => userHasProjectAccess(req.user, d.data().project_id));
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

router.get('/count', protect, authorizeAdminWarehouseOrSupervisor, async (req, res) => {
  try {
    const firestore = getFirestore();
    let q;
    if (req.query.status) {
      q = firestore.collection('distributions').where('status', '==', req.query.status);
    } else if (req.query.project) {
      q = firestore.collection('distributions').where('project_id', '==', req.query.project);
    } else {
      q = firestore.collection('distributions');
    }
    const snapshot = await q.get();
    let docs = snapshot.docs;
    if (req.query.status && req.query.project) {
      docs = docs.filter((d) => d.data().project_id === req.query.project);
    }
    if (isSupervisor(req.user?.role)) {
      docs = docs.filter((d) => userHasProjectAccess(req.user, d.data().project_id));
    }
    res.json({ success: true, count: docs.length });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, authorizeAdminWarehouseOrSupervisor, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('distributions').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Distribution not found' });
    if (isSupervisor(req.user?.role) && !userHasProjectAccess(req.user, doc.data().project_id)) {
      return res.status(403).json({ success: false, message: 'You do not have access to this distribution' });
    }
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
    return 'No approved order found for this project and store. Manager must approve an order first.';
  }
  if (lang === 'ar') {
    return 'لا يوجد طلب مُعتمد لهذا المشروع وهذا المخزن. يجب أن يعتمد المدير الطلب أولاً.';
  }
  return "Aucune commande approuvee n'a ete trouvee pour ce projet et ce depot. Le manager doit d'abord approuver une commande.";
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

/** Normalize one distribution line; `product` is always the SKU that is shipped / deducted. */
function normalizeDistributionLine(raw, actorId) {
  const incomingProduct = raw?.product?.id ?? raw?.product?._id ?? raw?.product;
  const originalId = raw?.original_product_id ?? raw?.originalProductId ?? incomingProduct;
  const replacementId = raw?.replacement_product_id ?? raw?.replacementProductId ?? null;
  const isReplaced = !!(raw?.is_replaced ?? raw?.isReplaced ?? (replacementId && String(replacementId) !== String(originalId)));
  if (isReplaced && (!replacementId || String(replacementId) === String(originalId))) {
    return { error: 'Replacement product must be different from the original product' };
  }
  const shipId = isReplaced ? String(replacementId) : String(originalId || incomingProduct || '');
  const quantity = Number(raw?.quantity || 0);
  if (!shipId || !Number.isFinite(quantity) || quantity <= 0) return null;
  const color = colorFromItem(raw?.color);
  const originalColor = colorFromItem(raw?.original_color ?? raw?.originalColor) || (isReplaced ? null : color);
  const out = {
    product: shipId,
    quantity,
    original_product_id: String(originalId || shipId),
    replacement_product_id: isReplaced ? String(replacementId) : null,
    is_replaced: isReplaced,
  };
  if (color) out.color = color;
  if (originalColor) out.original_color = originalColor;
  if (isReplaced) {
    out.replaced_at = raw?.replaced_at ?? raw?.replacedAt ?? new Date().toISOString();
    out.replaced_by = raw?.replaced_by ?? raw?.replacedBy ?? actorId ?? null;
  }
  return out;
}

/** Merge duplicate distribution lines (same shipped product + color + original). */
function mergeDistributionProducts(items = [], actorId) {
  const merged = new Map();
  for (const raw of items) {
    const normalized = normalizeDistributionLine(raw, actorId);
    if (!normalized) continue;
    if (normalized.error) return { error: normalized.error };
    const color = normalized.color || '';
    const key = `${normalized.product}__${color}__${normalized.original_product_id || ''}`;
    if (!merged.has(key)) {
      merged.set(key, { ...normalized });
    } else {
      merged.get(key).quantity += normalized.quantity;
    }
  }
  return { products: Array.from(merged.values()) };
}

function buildReplacementHistory(products, actorId) {
  const now = new Date().toISOString();
  return (products || [])
    .filter((p) => p.is_replaced && p.replacement_product_id)
    .map((p) => ({
      action: 'product_replaced',
      at: p.replaced_at || now,
      by: p.replaced_by || actorId || null,
      original_product_id: p.original_product_id || null,
      replacement_product_id: p.replacement_product_id || null,
      quantity: p.quantity ?? null,
      note: 'Product replaced due to insufficient stock',
    }));
}

/**
 * Warehouse may ship replacements only if they were already approved on the linked order
 * (Admin/Manager did the replacement earlier). They cannot invent new replacements here.
 */
function warehouseReplacementsMatchOrder(firestoreProducts, orderData) {
  const orderLines = orderData?.products || [];
  for (const p of firestoreProducts) {
    if (!p.is_replaced) continue;
    const orig = String(p.original_product_id || '');
    const ship = String(p.replacement_product_id || p.product || '');
    const match = orderLines.some((op) => {
      const oOrig = String(op.original_product_id ?? op.originalProductId ?? op.product?.id ?? op.product ?? '');
      const oShip = String(
        op.replacement_product_id
          ?? op.replacementProductId
          ?? (op.is_replaced || op.isReplaced ? (op.product?.id ?? op.product) : '')
          ?? ''
      );
      const oReplaced = !!(
        op.is_replaced
        ?? op.isReplaced
        ?? (op.replacement_product_id && String(op.replacement_product_id) !== oOrig)
      );
      if (!oReplaced) return false;
      return oOrig === orig && oShip === ship;
    });
    if (!match) return false;
  }
  return true;
}

/**
 * Stock check before deducting (shared by create + validate).
 * @param {'create'|'validate'} messageKind
 */
async function assertStockAvailableForDistribution(firestore, products, storeId, req, messageKind, storeByKey) {
  const insufficient = [];
  for (let i = 0; i < products.length; i++) {
    const item = products[i];
    const productId = item.product?.id ?? item.product?._id ?? item.product;
    const itemColor = colorFromItem(item.color);
    const quantity = item.quantity || 0;
    const mapKeyProduct = item.original_product_id || productId;
    const lineStoreId = storeByKey?.get(makeProductKey(mapKeyProduct, itemColor))
      ?? storeByKey?.get(makeProductKey(productId, itemColor))
      ?? storeId;
    const available = await getAvailableStock(firestore, productId, lineStoreId, itemColor);
    if (available < quantity) {
      const productDoc = await firestore.collection('products').doc(String(productId)).get();
      const productName = productDoc?.exists ? productDoc.data().name : productId;
      const displayName = itemColor ? `${productName} (${itemColor})` : productName;
      insufficient.push({
        index: i,
        productId: String(productId),
        originalProductId: item.original_product_id ? String(item.original_product_id) : String(productId),
        productName: displayName,
        available,
        required: quantity,
        color: itemColor,
        storeId: lineStoreId,
      });
    }
  }
  if (insufficient.length === 0) return null;
  const first = insufficient[0];
  const msg =
    messageKind === 'create'
      ? msgInsufficientStockCreate(first.productName, first.available, first.required, req)
      : msgInsufficientStockValidate(first.productName, first.available, first.required, req);
  return {
    status: 400,
    body: {
      success: false,
      code: 'INSUFFICIENT_STOCK',
      message: msg,
      canReplace: isAdminLike(req.user?.role),
      insufficient,
    },
  };
}

/**
 * Deduct warehouse stock only (shipped product id).
 * Project BOQ remaining (`projects.products`) is already decremented when the user places an order
 * (`POST /orders`). Applying the same decrement here caused quantities to "double" (rest / distributed wrong).
 */
async function applyDistributionDeductions(firestore, products, projectId, storeId, bonAlimentation, userId, storeByKey) {
  for (const item of products) {
    const productId = item.product?.id ?? item.product?._id ?? item.product;
    const itemColor = colorFromItem(item.color);
    const mapKeyProduct = item.original_product_id || productId;
    const lineStoreId = storeByKey?.get(makeProductKey(mapKeyProduct, itemColor))
      ?? storeByKey?.get(makeProductKey(productId, itemColor))
      ?? storeId;
    const notes = item.is_replaced
      ? `Distribution (replaced ${item.original_product_id} → ${productId})`
      : 'Distribution';
    await updateStock(productId, lineStoreId, -item.quantity, 'distribution', {
      project: projectId,
      user: userId,
      reference: bonAlimentation,
      notes,
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
    let orderDocForStores = null;
    if (orderId && String(orderId).trim()) {
      orderDocForStores = await firestore.collection('orders').doc(String(orderId).trim()).get();
      if (!orderDocForStores.exists) {
        return res.status(400).json({ success: false, message: 'Order not found' });
      }
      const ost = orderDocForStores.data().status;
      if (ost !== 'approved' && ost !== 'completed') {
        return res.status(400).json({ success: false, message: 'Order is not approved yet' });
      }
      if (String(orderDocForStores.data().project_id || '') !== String(project)) {
        return res.status(400).json({ success: false, message: 'Order does not belong to this project' });
      }
    } else {
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

    const merged = mergeDistributionProducts(products, req.user.id);
    if (merged.error) {
      return res.status(400).json({ success: false, message: merged.error });
    }
    const firestoreProducts = merged.products;
    if (!firestoreProducts.length) {
      return res.status(400).json({ success: false, message: 'Please provide project, store, and products' });
    }
    // Admin/Manager may invent replacements. Warehouse may only ship ones already on the order.
    const hasReplacement = firestoreProducts.some((p) => p.is_replaced);
    if (hasReplacement && !isAdminLike(req.user?.role)) {
      const oid = orderId && String(orderId).trim();
      const orderOk = oid
        && orderDocForStores?.exists
        && isWarehouseLike(req.user?.role)
        && warehouseReplacementsMatchOrder(firestoreProducts, orderDocForStores.data());
      if (!orderOk) {
        return res.status(403).json({
          success: false,
          message: 'Only Admin or Manager can replace products',
        });
      }
    }
    if (orderDocForStores?.exists) {
      enrichReplacementsFromOrder(firestoreProducts, orderDocForStores.data());
    }
    const storeByKey = orderDocForStores?.exists
      ? buildStoreByProductKey(orderDocForStores.data(), storeId)
      : null;
    const stockErr = await assertStockAvailableForDistribution(firestore, firestoreProducts, storeId, req, 'create', storeByKey);
    if (stockErr) return res.status(stockErr.status).json(stockErr.body);
    const serialNumber = generateSerialNumber();
    const bonValue = bonAlimentation && String(bonAlimentation).trim() ? bonAlimentation.trim() : serialNumber;
    const existing = await firestore.collection('distributions').where('bon_alimentation', '==', bonValue).limit(1).get();
    if (!existing.empty) return res.status(400).json({ success: false, message: 'Bon Alimentation/Serial number already exists' });
    const distDate = distributionDate ? new Date(distributionDate) : admin.firestore.FieldValue.serverTimestamp();
    const history = buildReplacementHistory(firestoreProducts, req.user.id);
    // Warehouse creates the distribution; Manager who approved the order is "Validated by".
    let validatedById = req.user.id;
    if (isWarehouseLike(req.user?.role) && orderDocForStores?.exists) {
      const approverId = orderApproverId(orderDocForStores.data());
      if (approverId) validatedById = String(approverId);
    }
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
      history,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    try {
      await applyDistributionDeductions(firestore, firestoreProducts, project, storeId, bonValue, req.user.id, storeByKey);
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
      validated_by: validatedById,
      validated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    if (orderId && String(orderId).trim()) {
      await applyOrderDistributed(firestore, orderId, distributionDate || distDate);
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
    const merged = mergeDistributionProducts(data.products || [], req.user.id);
    if (merged.error) {
      return res.status(400).json({ success: false, message: merged.error });
    }
    const products = merged.products;
    const projectId = data.project_id;
    const sid = data.store_id || data.depot_id;

    let storeByKey = null;
    if (data.order_id) {
      const orderDoc = await firestore.collection('orders').doc(data.order_id).get();
      if (orderDoc.exists) storeByKey = buildStoreByProductKey(orderDoc.data(), sid);
    }
    const stockErr = await assertStockAvailableForDistribution(firestore, products, sid, req, 'validate', storeByKey);
    if (stockErr) return res.status(stockErr.status).json(stockErr.body);

    await applyDistributionDeductions(firestore, products, projectId, sid, data.bon_alimentation, req.user.id, storeByKey);

    await ref.update({
      status: 'validated',
      validated_by: req.user.id,
      validated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const updated = await ref.get();
    const out = await distributionToApi(updated, firestore);
    await sendValidatedDistributionNotifications(firestore, ref, data, req, projectId, sid);
    if (data.order_id) {
      await applyOrderDistributed(firestore, data.order_id, data.distribution_date);
    }
    res.json({ success: true, data: out });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/refuse', protect, authorizeAdminLike, async (req, res) => {
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
