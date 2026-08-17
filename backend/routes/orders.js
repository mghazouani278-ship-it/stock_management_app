const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { protect, authorizeAdminLike, authorize } = require('../middleware/auth');
const { createOrderNotification } = require('./orderNotifications');
const {
  toYmd,
  normalizeExpectedArrivalDays,
  computeExpectedArrivalDate,
  diffDaysYmd,
} = require('../utils/lateOrders');
const { projectRef, userRef } = require('../utils/embedRefs');
const { parseProjectProductQty, setProjectMapQty, addProjectMapQty } = require('../utils/projectProductsMap');
const {
  makeProductKey,
  parseQtyField,
  loadDistributedMapsForProject,
  splitOrderQuantity,
} = require('../utils/projectBoqRemaining');
const { findStockStoreForProductLine } = require('../utils/resolveProductStockStore');
const {
  isAdmin,
  isManager,
  isAdminLike,
  isSupervisor,
  isUser,
  isWarehouseLike,
  migrateOrderStatus,
  userHasProjectAccess,
} = require('../utils/roles');
const { appendOrderAudit, productLinesSnapshot } = require('../utils/orderAudit');

function orderLineContext(projectData, distributedMaps, productId, color) {
  const productsMap = projectData?.products || {};
  const productsRequestedMap = projectData?.products_requested || productsMap;
  const key = makeProductKey(productId, color);
  const rawRequested = productsRequestedMap[key] ?? productsMap[key];
  const requestedQty = parseQtyField(rawRequested);
  const distributedQty =
    (distributedMaps.distributedByKey[key] ?? distributedMaps.distributedByProduct[productId] ?? 0);
  return {
    requestedQty,
    distributedQty,
    allowedInMap: productsMap[key],
  };
}

/** Merge duplicate product lines (same id + color) so one request cannot deduct twice. */
function mergeOrderProductLines(productsBody, actorId) {
  const map = new Map();
  for (const item of productsBody) {
    const incomingId = item.product?.id ?? item.product?._id ?? item.product;
    const originalId = item.original_product_id ?? item.originalProductId ?? incomingId;
    const replacementId = item.replacement_product_id ?? item.replacementProductId ?? null;
    const isReplaced = !!(item.is_replaced ?? item.isReplaced ?? (replacementId && String(replacementId) !== String(originalId)));
    if (isReplaced && (!replacementId || String(replacementId) === String(originalId))) {
      return { error: 'Replacement product must be different from the original product' };
    }
    const shipId = isReplaced ? String(replacementId) : String(incomingId || originalId || '');
    const quantity = Number(item.quantity);
    const color = (item.variant ?? item.color) ? String(item.variant ?? item.color).trim().toLowerCase() : null;
    const originalColor = (item.original_color ?? item.originalColor)
      ? String(item.original_color ?? item.originalColor).trim().toLowerCase()
      : (isReplaced ? null : color);
    if (!shipId || !quantity || quantity <= 0) return { error: 'Invalid product or quantity' };
    const key = `${makeProductKey(shipId, color)}__${String(originalId || '')}`;
    const prev = map.get(key);
    const line = {
      productId: shipId,
      color,
      quantity: (prev?.quantity || 0) + quantity,
      originalProductId: String(originalId || shipId),
      replacementProductId: isReplaced ? String(replacementId) : null,
      isReplaced,
      originalColor: originalColor || null,
      projectQuantity: Number(item.projectQuantity ?? item.project_quantity),
      supplementaryQuantity: Number(item.supplementaryQuantity ?? item.supplementary_quantity),
      hasStoredSplit: item.projectQuantity != null
        || item.project_quantity != null
        || item.supplementaryQuantity != null
        || item.supplementary_quantity != null,
    };
    if (prev?.hasStoredSplit) {
      line.hasStoredSplit = true;
      line.projectQuantity = (Number.isFinite(prev.projectQuantity) ? prev.projectQuantity : 0)
        + (Number.isFinite(line.projectQuantity) ? line.projectQuantity : 0);
      line.supplementaryQuantity = (Number.isFinite(prev.supplementaryQuantity) ? prev.supplementaryQuantity : 0)
        + (Number.isFinite(line.supplementaryQuantity) ? line.supplementaryQuantity : 0);
    }
    if (isReplaced) {
      line.replacedAt = item.replaced_at ?? item.replacedAt ?? new Date().toISOString();
      line.replacedBy = item.replaced_by ?? item.replacedBy ?? actorId ?? null;
    }
    map.set(key, line);
  }
  return { lines: Array.from(map.values()) };
}

/** BOQ key product: original when replaced, else shipped product. */
function boqProductIdFromLine(item) {
  return item.original_product_id
    ?? item.originalProductId
    ?? item.product?.id
    ?? item.product?._id
    ?? item.product;
}

function boqColorFromLine(item) {
  const raw = item.original_color ?? item.originalColor ?? item.variant ?? item.color;
  return raw ? String(raw).trim().toLowerCase() : null;
}

function mapOrderProductToApi(p, productsMap, usersMap) {
    const prodId = p.product?.id ?? p.product?._id ?? p.product;
  const prodDoc = prodId ? productsMap.get(String(prodId)) : null;
    const color = (p.variant ?? p.color) ? String(p.variant ?? p.color).trim().toLowerCase() : null;
  const originalId = p.original_product_id ?? p.originalProductId ?? null;
  const replacementId = p.replacement_product_id ?? p.replacementProductId ?? null;
  const isReplaced = !!(p.is_replaced ?? p.isReplaced ?? replacementId);
    const item = {
    product: prodDoc?.exists
      ? { id: prodDoc.id, name: prodDoc.data().name, category: prodDoc.data().category, unit: prodDoc.data().unit }
      : { id: prodId },
      quantity: p.quantity,
    isReplaced,
    originalProductId: originalId ? String(originalId) : null,
    replacementProductId: replacementId ? String(replacementId) : null,
    replacedAt: toIso(p.replaced_at) ?? p.replaced_at ?? null,
    };
    if (color) {
      item.variant = color;
      item.color = color;
    }
  if (originalId) {
    const od = productsMap.get(String(originalId));
    item.originalProduct = od?.exists
      ? { id: od.id, name: od.data().name, unit: od.data().unit || null }
      : { id: String(originalId) };
  }
  if (replacementId) {
    const rd = productsMap.get(String(replacementId));
    item.replacementProduct = rd?.exists
      ? { id: rd.id, name: rd.data().name, unit: rd.data().unit || null }
      : { id: String(replacementId) };
  }
  if (p.replaced_by) {
    const ub = usersMap?.get(String(p.replaced_by));
    item.replacedBy = ub?.exists ? userRef(ub) : { id: String(p.replaced_by) };
  }
  const resolved = resolveStoredOrderLineQuantities(p);
  if (resolved.supplementary) item.supplementary = true;
  item.projectQuantity = resolved.projectQuantity;
  item.supplementaryQuantity = resolved.supplementaryQuantity;
  return item;
}

function toIso(t) {
  return t?.toDate?.()?.toISOString?.() ?? (typeof t === 'string' ? t : null);
}

/** Prefer quantities stored on the order line (snapshot at create/edit). Never re-split against current remaining. */
function resolveStoredOrderLineQuantities(p) {
    const qty = Number(p.quantity) || 0;
      const projStored = p.projectQuantity != null ? Number(p.projectQuantity) : (p.project_quantity != null ? Number(p.project_quantity) : null);
      const suppStored = p.supplementaryQuantity != null ? Number(p.supplementaryQuantity) : (p.supplementary_quantity != null ? Number(p.supplementary_quantity) : null);
  let projectQty;
  let supplementaryQty;
      if (projStored != null || suppStored != null) {
    projectQty = Math.max(0, Number.isFinite(projStored) ? projStored : 0);
    supplementaryQty = Math.max(0, Number.isFinite(suppStored) ? suppStored : Math.max(0, qty - projectQty));
    // If only one side stored, derive the other from total.
    if (projStored == null) projectQty = Math.max(0, qty - supplementaryQty);
    if (suppStored == null) supplementaryQty = Math.max(0, qty - projectQty);
      } else if (p.supplementary) {
        projectQty = 0;
        supplementaryQty = qty;
      } else {
        projectQty = qty;
        supplementaryQty = 0;
      }
  return {
    projectQuantity: projectQty,
    supplementaryQuantity: supplementaryQty,
    supplementary: p.supplementary === true || supplementaryQty > 0,
  };
}

function supervisorAllowedProjectIds(user) {
  const allowed = (user?.project_ids || []).map(String).filter(Boolean);
  if (allowed.length === 0 && user?.project_id) allowed.push(String(user.project_id));
  return allowed;
}

async function orderToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const userDoc = await firestore.collection('users').doc(data.user_id).get();
  const projectDoc = await firestore.collection('projects').doc(data.project_id).get();

  const productIds = new Set();
  const replacerIds = new Set();
  for (const p of data.products || []) {
    const pid = p.product?.id ?? p.product?._id ?? p.product;
    if (pid) productIds.add(String(pid));
    if (p.original_product_id) productIds.add(String(p.original_product_id));
    if (p.replacement_product_id) productIds.add(String(p.replacement_product_id));
    if (p.replaced_by) replacerIds.add(String(p.replaced_by));
  }
  const productSnaps = await Promise.all([...productIds].map((id) => firestore.collection('products').doc(id).get()));
  const productsMap = new Map();
  for (const s of productSnaps) if (s.exists) productsMap.set(s.id, s);
  const userSnaps = await Promise.all([...replacerIds].map((id) => firestore.collection('users').doc(id).get()));
  const usersMap = new Map();
  for (const s of userSnaps) if (s.exists) usersMap.set(s.id, s);

  const products = (data.products || []).map((p) => mapOrderProductToApi(p, productsMap, usersMap));
  const orderDate = data.order_date;
  const orderDateStr = orderDate && typeof orderDate.toDate === 'function'
    ? orderDate.toDate().toISOString().split('T')[0]
    : (orderDate ? new Date(orderDate).toISOString().split('T')[0] : null);
  const status = data.status || '';
  const approvedAtRaw = data.approved_at ?? ((status === 'approved' || status === 'completed') ? data.updated_at : null);
  const deliveryDateRaw = data.delivery_date ?? (status === 'completed' ? data.updated_at : null);
  const distributionDateStr = toYmd(data.distribution_date) || toYmd(deliveryDateRaw);
  const arrivalDateStr = toYmd(data.arrival_date) || toYmd(data.arrival_confirmed_at) || toYmd(deliveryDateRaw) || distributionDateStr;
  let arriveInDays = data.expected_arrival_days != null ? Number(data.expected_arrival_days) : null;
  if (distributionDateStr && arrivalDateStr) {
    const span = diffDaysYmd(arrivalDateStr, distributionDateStr);
    arriveInDays = Math.max(1, span + 1); // inclusive calendar days (same day => 1)
  }

  // Resolve history actor names from current user profiles (prefer live name over stale snapshot).
  const historyRaw = Array.isArray(data.history) ? data.history : [];
  const historyActorIds = [...new Set(historyRaw.map((h) => h?.actorId || h?.actor_id).filter(Boolean).map(String))];
  const historyUserSnaps = await Promise.all(historyActorIds.map((id) => firestore.collection('users').doc(id).get()));
  const historyUsers = new Map();
  for (const s of historyUserSnaps) if (s.exists) historyUsers.set(s.id, s);
  const history = historyRaw.map((h) => {
    const actorId = h?.actorId || h?.actor_id || null;
    const live = actorId ? historyUsers.get(String(actorId)) : null;
    const liveName = live?.exists ? (live.data().name || null) : null;
    return {
      action: h?.action || null,
      fromStatus: h?.fromStatus ?? h?.from_status ?? null,
      toStatus: h?.toStatus ?? h?.to_status ?? null,
      actorId: actorId ? String(actorId) : null,
      actorName: liveName || h?.actorName || h?.actor_name || null,
      actorRole: h?.actorRole || h?.actor_role || null,
      note: h?.note || null,
      changes: h?.changes || null,
      createdAt: toIso(h?.created_at) ?? h?.created_at ?? h?.createdAt ?? null,
    };
  });

  return {
    id: doc.id,
    user: userRef(userDoc),
    project: projectRef(projectDoc),
    approvedStoreId: data.approved_store_id || null,
    approvedProductStores: (data.approved_product_stores || []).map((row) => ({
      product: row.product_id ?? row.product,
      store: row.store_id ?? row.store,
      storeName: row.store_name ?? null,
      color: row.color ?? row.variant ?? null,
    })),
    products: await Promise.all(products),
    status: migrateOrderStatus(data.status),
    notes: data.notes,
    orderDate: orderDateStr,
    expectedArrivalDays: data.expected_arrival_days != null ? Number(data.expected_arrival_days) : null,
    expectedArrivalDate: toYmd(data.expected_arrival_date) || computeExpectedArrivalDate(orderDateStr, data.expected_arrival_days),
    distributionDate: distributionDateStr,
    arrivalDate: arrivalDateStr,
    arriveInDays,
    createdAt: toIso(data.created_at) ?? data.created_at,
    updatedAt: toIso(data.updated_at) ?? data.updated_at,
    approvedAt: toIso(approvedAtRaw) ?? approvedAtRaw,
    deliveryDate: toIso(deliveryDateRaw) ?? deliveryDateRaw,
    adminNotes: data.admin_notes || null,
    arrivalConfirmed: data.arrival_confirmed === true,
    arrivalConfirmedAt: toIso(data.arrival_confirmed_at) ?? data.arrival_confirmed_at ?? null,
    history,
  };
}

/** Batch-hydrate many orders to avoid N+1 Firestore reads. */
async function ordersToApiBatch(docs, firestore) {
  if (!docs.length) return [];
  const userIds = new Set();
  const projectIds = new Set();
  const productIds = new Set();
  for (const doc of docs) {
    const d = doc.data();
    if (d.user_id) userIds.add(String(d.user_id));
    if (d.project_id) projectIds.add(String(d.project_id));
    for (const p of d.products || []) {
      const pid = p.product?.id ?? p.product?._id ?? p.product;
      if (pid) productIds.add(String(pid));
      if (p.original_product_id) productIds.add(String(p.original_product_id));
      if (p.replacement_product_id) productIds.add(String(p.replacement_product_id));
      if (p.replaced_by) userIds.add(String(p.replaced_by));
    }
  }

  const [userSnaps, projectSnaps, productSnaps] = await Promise.all([
    Promise.all([...userIds].map((id) => firestore.collection('users').doc(id).get())),
    Promise.all([...projectIds].map((id) => firestore.collection('projects').doc(id).get())),
    Promise.all([...productIds].map((id) => firestore.collection('products').doc(id).get())),
  ]);

  const users = new Map();
  for (const s of userSnaps) if (s.exists) users.set(s.id, s);
  const projects = new Map();
  for (const s of projectSnaps) if (s.exists) projects.set(s.id, s);
  const productsMap = new Map();
  for (const s of productSnaps) if (s.exists) productsMap.set(s.id, s);

  return docs.map((doc) => {
    const data = doc.data();
    const userDoc = users.get(String(data.user_id));
    const projectDoc = projects.get(String(data.project_id));

    const products = (data.products || []).map((p) => mapOrderProductToApi(p, productsMap, users));

    const orderDate = data.order_date;
    const orderDateStr = orderDate && typeof orderDate.toDate === 'function'
      ? orderDate.toDate().toISOString().split('T')[0]
      : (orderDate ? new Date(orderDate).toISOString().split('T')[0] : null);
    const status = data.status || '';
    const approvedAtRaw = data.approved_at ?? ((status === 'approved' || status === 'completed') ? data.updated_at : null);
    const deliveryDateRaw = data.delivery_date ?? (status === 'completed' ? data.updated_at : null);
    const distributionDateStr = toYmd(data.distribution_date) || toYmd(deliveryDateRaw);
    const arrivalDateStr = toYmd(data.arrival_date) || toYmd(data.arrival_confirmed_at) || toYmd(deliveryDateRaw) || distributionDateStr;
    let arriveInDays = data.expected_arrival_days != null ? Number(data.expected_arrival_days) : null;
    if (distributionDateStr && arrivalDateStr) {
      const span = diffDaysYmd(arrivalDateStr, distributionDateStr);
      arriveInDays = Math.max(1, span + 1);
    }
    return {
      id: doc.id,
      user: userRef(userDoc),
      project: projectRef(projectDoc),
      approvedStoreId: data.approved_store_id || null,
      approvedProductStores: (data.approved_product_stores || []).map((row) => ({
        product: row.product_id ?? row.product,
        store: row.store_id ?? row.store,
        storeName: row.store_name ?? null,
        color: row.color ?? row.variant ?? null,
      })),
      products,
      status: migrateOrderStatus(data.status),
      notes: data.notes,
      orderDate: orderDateStr,
      expectedArrivalDays: data.expected_arrival_days != null ? Number(data.expected_arrival_days) : null,
      expectedArrivalDate: toYmd(data.expected_arrival_date) || computeExpectedArrivalDate(orderDateStr, data.expected_arrival_days),
      distributionDate: distributionDateStr,
      arrivalDate: arrivalDateStr,
      arriveInDays,
      createdAt: toIso(data.created_at) ?? data.created_at,
      updatedAt: toIso(data.updated_at) ?? data.updated_at,
      approvedAt: toIso(approvedAtRaw) ?? approvedAtRaw,
      deliveryDate: toIso(deliveryDateRaw) ?? deliveryDateRaw,
      adminNotes: data.admin_notes || null,
      arrivalConfirmed: data.arrival_confirmed === true,
      arrivalConfirmedAt: toIso(data.arrival_confirmed_at) ?? data.arrival_confirmed_at ?? null,
      history: data.history || [],
    };
  });
}

function restoreProjectBoq(firestore, orderData) {
  return (async () => {
    const projectRefDb = firestore.collection('projects').doc(orderData.project_id);
    const projectDoc = await projectRefDb.get();
    if (!projectDoc.exists) return;
    const productsMap = { ...(projectDoc.data().products || {}) };
    const productsRequestedMap = { ...(projectDoc.data().products_requested || productsMap) };
    const historyEntries = [];
    for (const item of orderData.products || []) {
      if (item.supplementary) continue;
      const pid = boqProductIdFromLine(item);
      const qty = Number(item.projectQuantity ?? item.project_quantity ?? item.quantity) || 0;
      if (qty <= 0) continue;
      const color = boqColorFromLine(item);
      const key = makeProductKey(pid, color);
      if (!pid) continue;
      productsMap[key] = addProjectMapQty(productsMap[key] ?? 0, qty);
      historyEntries.push({
        action: 'qty_restore',
        productId: String(pid),
        color: color || null,
        quantityAdded: qty,
        quantityOrdered: 0,
        remainingAfter: parseProjectProductQty(productsMap[key]),
        requestedTotalAfter: parseProjectProductQty(productsRequestedMap[key] ?? productsMap[key]),
        at: admin.firestore.Timestamp.now(),
        by: null,
        changes: ['products'],
      });
    }
    const updatePayload = {
      products: productsMap,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (historyEntries.length) {
      updatePayload.history = admin.firestore.FieldValue.arrayUnion(...historyEntries);
    }
    await projectRefDb.update(updatePayload);
  })();
}

async function resolveApprovedStores(firestore, orderData, sid, productStoresBody) {
  let approvedProductStores = [];
  if (Array.isArray(productStoresBody) && productStoresBody.length > 0) {
    approvedProductStores = productStoresBody.map((row) => {
      const pid = row.product?.id ?? row.product?._id ?? row.product;
      const store = row.store ?? row.store_id ?? row.depot;
      if (!pid || !store) {
        const e = new Error('Each product must include product id and store id');
        e.code = 'BAD_PRODUCT_STORES';
        throw e;
      }
      return {
        product_id: pid,
        store_id: store,
        color: row.color ?? row.variant ?? null,
        store_name: row.storeName ?? row.store_name ?? null,
      };
    });
  } else if (sid) {
    for (const item of orderData.products || []) {
      const pid = item.product?.id ?? item.product?._id ?? item.product;
      if (!pid) continue;
      approvedProductStores.push({
        product_id: pid,
        store_id: sid,
        color: item.variant ?? item.color ?? null,
      });
    }
  } else {
    for (const item of orderData.products || []) {
      const pid = item.product?.id ?? item.product?._id ?? item.product;
      if (!pid) continue;
      const color = item.variant ?? item.color ?? null;
      const found = await findStockStoreForProductLine(firestore, pid, color);
      if (!found?.storeId) {
        const prodDoc = await firestore.collection('products').doc(pid).get();
        const name = prodDoc?.exists ? prodDoc.data().name : pid;
        const e = new Error(`No stock registered for "${name}"${color ? ` (${color})` : ''}. Add stock with a store first.`);
        e.code = 'NO_STOCK';
        throw e;
      }
      approvedProductStores.push({
        product_id: pid,
        store_id: found.storeId,
        color: color || null,
        store_name: found.storeName || null,
      });
    }
  }
  if (approvedProductStores.length === 0) {
    const e = new Error('Please provide store per product or a default store when approving');
    e.code = 'NO_STORE';
    throw e;
  }
  return approvedProductStores;
}

router.get('/', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    let docs;
    const role = req.user.role;
    if (isUser(role)) {
      const snapshot = await firestore.collection('orders').where('user_id', '==', req.user.id).get();
      docs = snapshot.docs;
    } else if (req.query.status) {
      const snapshot = await firestore.collection('orders').where('status', '==', String(req.query.status)).get();
      docs = snapshot.docs;
      if (isSupervisor(role)) {
        const allowed = supervisorAllowedProjectIds(req.user);
        docs = docs.filter((d) => allowed.includes(String(d.data().project_id)));
      }
      if (req.query.user) docs = docs.filter((d) => d.data().user_id === req.query.user);
      if (req.query.project) docs = docs.filter((d) => d.data().project_id === req.query.project);
    } else {
      const snapshot = await firestore.collection('orders').get();
      docs = snapshot.docs;
      if (isSupervisor(role)) {
        const allowed = supervisorAllowedProjectIds(req.user);
        docs = docs.filter((d) => allowed.includes(String(d.data().project_id)));
      }
      if (req.query.user) docs = docs.filter((d) => d.data().user_id === req.query.user);
      if (req.query.project) docs = docs.filter((d) => d.data().project_id === req.query.project);
    }
    docs = docs.sort((a, b) => {
      const va = a.data().created_at?.toMillis?.() ?? 0;
      const vb = b.data().created_at?.toMillis?.() ?? 0;
      return vb - va;
    });
    const data = await ordersToApiBatch(docs, firestore);
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/** Fast count for dashboard badges — no hydration. */
router.get('/count', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const role = req.user.role;
    let docs;
    if (isUser(role)) {
      const snapshot = await firestore.collection('orders').where('user_id', '==', req.user.id).get();
      docs = snapshot.docs;
    } else if (req.query.status) {
      const snapshot = await firestore.collection('orders').where('status', '==', String(req.query.status)).get();
      docs = snapshot.docs;
    } else {
      const snapshot = await firestore.collection('orders').get();
      docs = snapshot.docs;
    }
    if (isSupervisor(role)) {
      const allowed = supervisorAllowedProjectIds(req.user);
      docs = docs.filter((d) => allowed.includes(String(d.data().project_id)));
    }
    if (req.query.user) docs = docs.filter((d) => d.data().user_id === req.query.user);
    if (req.query.project) docs = docs.filter((d) => d.data().project_id === req.query.project);
    if (req.query.status && isUser(role)) {
      docs = docs.filter((d) => migrateOrderStatus(d.data().status) === req.query.status);
    }
    res.json({ success: true, count: docs.length });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('orders').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Order not found' });
    const orderData = doc.data();
    if (isUser(req.user.role) && orderData.user_id !== req.user.id) {
      return res.status(403).json({ success: false, message: 'You do not have access to this order' });
    }
    if (isSupervisor(req.user.role) && !userHasProjectAccess(req.user, orderData.project_id)) {
      return res.status(403).json({ success: false, message: 'You do not have access to this order' });
    }
    const data = await orderToApi(doc, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/', protect, async (req, res) => {
  try {
    const { products: productsBody, notes, orderDate, expectedArrivalDays: expectedArrivalDaysBody } = req.body;
    if (!productsBody || !Array.isArray(productsBody) || productsBody.length === 0) {
      return res.status(400).json({ success: false, message: 'Please provide at least one product' });
    }
    const expectedArrivalDays = normalizeExpectedArrivalDays(expectedArrivalDaysBody);
    if (!expectedArrivalDays) {
      return res.status(400).json({ success: false, message: 'Please choose expected arrival within 1 to 7 days' });
    }

    let projectId = req.body.projectId || null;
    if (isAdminLike(req.user.role)) {
      projectId = req.body.projectId;
    } else if (isUser(req.user.role) || isSupervisor(req.user.role)) {
      const allowed = (req.user.project_ids || []).map(String);
      if (projectId) {
        if (!allowed.includes(String(projectId))) {
          return res.status(403).json({ success: false, message: 'You are not assigned to this project' });
        }
      } else {
        projectId = req.user.project_id;
      }
      if (!projectId) {
        return res.status(400).json({ success: false, message: 'You are not assigned to any project' });
      }
    } else {
      return res.status(403).json({ success: false, message: 'Only users, supervisors, admins or managers can create orders' });
    }
    if (!projectId) return res.status(400).json({ success: false, message: 'Please provide a project' });

    const merged = mergeOrderProductLines(productsBody);
    if (merged.error) return res.status(400).json({ success: false, message: merged.error });
    const lines = merged.lines;
    if (lines.length === 0) return res.status(400).json({ success: false, message: 'Please provide at least one product' });

    const firestore = getFirestore();
    const projectRefDb = firestore.collection('projects').doc(projectId);
    const orderRef = firestore.collection('orders').doc();

    const creatorRole = req.user.role;
    const initialStatus = isAdmin(creatorRole) || isManager(creatorRole) ? 'pending_manager' : 'pending';
    let projectNameForNotif = null;

    await firestore.runTransaction(async (transaction) => {
      const projectDoc = await transaction.get(projectRefDb);
      if (!projectDoc.exists) {
        const e = new Error('Project not found');
        e.code = 'NOT_FOUND';
        throw e;
      }
      const projectData = projectDoc.data();
      projectNameForNotif = projectData.name || null;
      const productsMap = { ...(projectData.products || {}) };
      const productsRequestedMap = { ...(projectData.products_requested || productsMap) };
      const validatedProducts = [];
      const productsToDeduct = [];
      const qtyHistoryEvents = [];
      for (const line of lines) {
        const { productId, color, quantity } = line;
        const key = makeProductKey(productId, color);
        const allowedRaw = productsMap[key];
        if (allowedRaw === undefined) {
          const e = new Error(`Product ${productId}${color ? ` (${color})` : ''} is not assigned to this project`);
          e.code = 'BAD_PRODUCT';
          throw e;
        }
        const remaining = parseProjectProductQty(allowedRaw);
        const split = splitOrderQuantity(quantity, { allowedInMap: allowedRaw });
        const { projectQuantity: projectQty, supplementaryQuantity: supplementaryQty, supplementary: isSupplementary } = split;
        validatedProducts.push({
          product: productId,
          quantity,
          supplementary: isSupplementary,
          color,
          projectQuantity: projectQty,
          supplementaryQuantity: supplementaryQty,
        });
        if (projectQty > 0) {
          productsToDeduct.push({ product: productId, quantity: projectQty, color });
        }
      }

      const newProductsMap = { ...productsMap };
      for (const item of productsToDeduct) {
        const key = makeProductKey(item.product, item.color);
        const current = newProductsMap[key] ?? 0;
        const after = Math.max(0, parseProjectProductQty(current) - item.quantity);
        newProductsMap[key] = setProjectMapQty(current, after);
        const requestedTotal = parseProjectProductQty(productsRequestedMap[key] ?? current);
        qtyHistoryEvents.push({
          action: 'qty_order',
          productId: String(item.product),
          color: item.color || null,
          quantityAdded: 0,
          quantityOrdered: item.quantity,
          remainingAfter: after,
          requestedTotalAfter: requestedTotal,
          at: admin.firestore.Timestamp.now(),
          by: {
            id: req.user.id || null,
            name: req.user.name || null,
            email: req.user.email || null,
            role: req.user.role || null,
          },
          changes: ['products'],
        });
      }

      const ordDate = orderDate ? new Date(orderDate) : admin.firestore.FieldValue.serverTimestamp();
      const orderDateYmd = orderDate
        ? String(orderDate).slice(0, 10)
        : new Date().toISOString().split('T')[0];
      const expectedArrivalDate = computeExpectedArrivalDate(orderDateYmd, expectedArrivalDays);
      const productsForStorage = validatedProducts.map(({ product, quantity, supplementary, color, projectQuantity, supplementaryQuantity }) => ({
        product,
        quantity,
        supplementary: supplementary || false,
        color: color || null,
        projectQuantity: projectQuantity ?? quantity,
        supplementaryQuantity: supplementaryQuantity ?? 0,
      }));

      if (productsToDeduct.length > 0) {
        const projectUpdate = {
          products: newProductsMap,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (qtyHistoryEvents.length) {
          projectUpdate.history = admin.firestore.FieldValue.arrayUnion(...qtyHistoryEvents);
        }
        transaction.update(projectRefDb, projectUpdate);
      }

      transaction.set(orderRef, {
        user_id: req.user.id,
        project_id: projectId,
        status: initialStatus,
        notes: notes || null,
        order_date: ordDate,
        expected_arrival_days: expectedArrivalDays,
        expected_arrival_date: expectedArrivalDate,
        products: productsForStorage,
        history: [{
          action: 'created',
          fromStatus: null,
          toStatus: initialStatus,
          actorId: req.user.id,
          actorName: req.user.name,
          actorRole: req.user.role,
          note: notes || null,
          changes: null,
          created_at: new Date().toISOString(),
        }],
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    const doc = await orderRef.get();
    const data = await orderToApi(doc, firestore);
    if (initialStatus === 'pending_manager') {
      await createOrderNotification(firestore, {
        type: 'order_pending_manager',
        orderId: orderRef.id,
        projectId,
        userId: req.user.id,
        userName: req.user.name,
        targetRole: 'manager',
        status: 'pending_manager',
        projectName: projectNameForNotif,
      });
    } else {
      await createOrderNotification(firestore, {
        type: 'new_order',
        orderId: orderRef.id,
        projectId,
        userId: req.user.id,
        userName: req.user.name,
        targetRole: 'supervisor',
        projectName: projectNameForNotif,
      });
    }
    res.status(201).json({ success: true, data });
  } catch (error) {
    if (error.code === 'NOT_FOUND') return res.status(404).json({ success: false, message: error.message });
    if (error.code === 'BAD_PRODUCT' || error.code === 'EXCEEDS_REMAINING') {
      return res.status(400).json({ success: false, message: error.message });
    }
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * Workflow status transitions:
 * - supervisor: pending → pending_admin | returned
 * - user: returned → pending (resubmit)
 * - admin: pending_admin → pending_manager (after review/edit via PUT /:id)
 * - manager: pending_manager → approved | cancelled
 */
router.put('/:id/status', protect, async (req, res) => {
  try {
    const { status: rawStatus, store: storeId, depot: depotId, productStores: productStoresBody, note } = req.body;
    const status = migrateOrderStatus(rawStatus);
    const sid = storeId || depotId;
    const firestore = getFirestore();
    const ref = firestore.collection('orders').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Order not found' });

    const orderData = doc.data();
    const currentStatus = migrateOrderStatus(orderData.status);
    const role = req.user.role;

    const allowed = {
      pending: {
        pending_admin: () => isSupervisor(role) && userHasProjectAccess(req.user, orderData.project_id),
        returned: () => isSupervisor(role) && userHasProjectAccess(req.user, orderData.project_id),
      },
      returned: {
        pending: () => isUser(role) && orderData.user_id === req.user.id,
      },
      pending_admin: {
        pending_manager: () => isAdmin(role) || isManager(role),
      },
      pending_manager: {
        approved: () => isManager(role),
        cancelled: () => isManager(role),
      },
    };

    const checker = allowed[currentStatus]?.[status];
    if (!checker || !checker()) {
      return res.status(403).json({
        success: false,
        message: `Cannot change status from '${currentStatus}' to '${status}' with role '${role}'`,
      });
    }

    // Restore BOQ only when manager cancels (or equivalent). Returned keeps reservation for correction.
    if (status === 'cancelled' && ['pending', 'pending_admin', 'pending_manager', 'returned'].includes(currentStatus)) {
      await restoreProjectBoq(firestore, orderData);
    }

    let approvedProductStores = [];
    if (status === 'approved') {
      try {
        approvedProductStores = await resolveApprovedStores(firestore, orderData, sid, productStoresBody);
      } catch (e) {
        if (e.code === 'NO_STOCK' || e.code === 'NO_STORE' || e.code === 'BAD_PRODUCT_STORES') {
          return res.status(400).json({ success: false, message: e.message });
        }
            throw e;
      }
      const primaryStoreId = approvedProductStores[0].store_id;
      const projectDoc = await firestore.collection('projects').doc(orderData.project_id).get();
      const projectName = projectDoc.exists ? projectDoc.data().name : null;
      const userDoc = await firestore.collection('users').doc(orderData.user_id).get();
      const userName = userDoc.exists ? userDoc.data().name : null;
      const productsForNotification = await Promise.all((orderData.products || []).map(async (item) => {
        const pid = item.product?.id ?? item.product?._id ?? item.product;
        const prodDoc = pid ? await firestore.collection('products').doc(pid).get() : null;
        const name = prodDoc?.exists ? prodDoc.data().name : pid;
        const color = (item.variant ?? item.color) ? String(item.variant ?? item.color).trim() : null;
        return {
          productId: pid,
          productName: name,
          quantity: item.quantity || 0,
          color: color || null,
          unit: prodDoc?.exists ? prodDoc.data().unit : null,
        };
      }));
      for (const targetRole of ['warehouse_user', 'warehouse']) {
        await createOrderNotification(firestore, {
          type: 'order_approved',
          orderId: req.params.id,
          projectId: orderData.project_id,
          userId: orderData.user_id,
          userName,
          targetRole,
          status: 'approved',
          products: productsForNotification,
          projectName,
          storeId: primaryStoreId,
          productStores: approvedProductStores,
        });
        // Hide stale "new_order" banners for the same order (legacy warehouse notifs).
        const staleNew = await firestore.collection('order_notifications')
          .where('order_id', '==', req.params.id)
          .where('type', '==', 'new_order')
          .where('target_role', '==', targetRole)
          .limit(20)
          .get();
        if (!staleNew.empty) {
          const batch = firestore.batch();
          staleNew.docs.forEach((d) => batch.update(d.ref, { read: true }));
          await batch.commit();
        }
      }
    }

    if (status === 'pending_admin') {
      await createOrderNotification(firestore, {
        type: 'order_pending_admin',
        orderId: req.params.id,
        projectId: orderData.project_id,
        userId: orderData.user_id,
        userName: req.user.name,
        targetRole: 'admin',
        status: 'pending_admin',
      });
    }
    if (status === 'returned') {
      await createOrderNotification(firestore, {
        type: 'order_returned',
        orderId: req.params.id,
        projectId: orderData.project_id,
        userId: orderData.user_id,
        userName: req.user.name,
        targetRole: 'user',
        status: 'returned',
        note: note || null,
      });
    }
    if (status === 'pending_manager') {
      await createOrderNotification(firestore, {
        type: 'order_pending_manager',
        orderId: req.params.id,
        projectId: orderData.project_id,
        userId: orderData.user_id,
        userName: req.user.name,
        targetRole: 'manager',
        status: 'pending_manager',
      });
      for (const targetRole of ['warehouse_user', 'warehouse']) {
        await createOrderNotification(firestore, {
          type: 'order_modified',
          orderId: req.params.id,
          projectId: orderData.project_id,
          userId: orderData.user_id,
          userName: req.user.name,
          targetRole,
          status: 'pending_manager',
        });
      }
    }
    if (status === 'cancelled') {
      await createOrderNotification(firestore, {
        type: 'order_cancelled',
        orderId: req.params.id,
        projectId: orderData.project_id,
        userId: orderData.user_id,
        userName: req.user.name,
        targetRole: 'user',
        status: 'cancelled',
      });
    }

    const updates = {
      status,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (note) updates.supervisor_notes = note;
    if (status === 'approved') {
      updates.approved_at = admin.firestore.FieldValue.serverTimestamp();
      updates.approved_store_id = approvedProductStores[0]?.store_id ?? sid;
      updates.approved_product_stores = approvedProductStores;
      updates.stock_deducted = false;
    }

    await ref.update(updates);
    await appendOrderAudit(ref, {
      action: 'status_change',
      fromStatus: currentStatus,
      toStatus: status,
      actorId: req.user.id,
      actorName: req.user.name,
      actorRole: role,
      note: note || null,
    });

    const updated = await ref.get();
    const data = await orderToApi(updated, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * Admin edits order products / quantities / notes, then sends to manager.
 * Supervisor may edit products/notes while status is still `pending` (before send to admin).
 * Body: { products, adminNotes|supervisorNotes, store?, productStores? }
 */
router.put('/:id', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('orders').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Order not found' });
    const orderData = doc.data();
    const currentStatus = migrateOrderStatus(orderData.status);

    // Supervisor: modify pending order (products / notes), keep status pending.
    if (isSupervisor(req.user.role)) {
      if (!userHasProjectAccess(req.user, orderData.project_id)) {
        return res.status(403).json({ success: false, message: 'You do not have access to this order' });
      }
      if (currentStatus !== 'pending') {
        return res.status(400).json({ success: false, message: 'Supervisor can only modify pending orders' });
      }
      const { products: productsBody, notes, supervisorNotes, adminNotes } = req.body;
      const updates = { updated_at: admin.firestore.FieldValue.serverTimestamp() };
      const changes = { before: productLinesSnapshot(orderData.products), after: null };
      const noteText = supervisorNotes ?? notes ?? adminNotes;

      if (productsBody && Array.isArray(productsBody) && productsBody.length > 0) {
        const merged = mergeOrderProductLines(productsBody);
        if (merged.error) return res.status(400).json({ success: false, message: merged.error });
        await restoreProjectBoq(firestore, orderData);

        const projectId = orderData.project_id;
        const projectRefDb = firestore.collection('projects').doc(projectId);
        const projectDoc = await projectRefDb.get();
        if (!projectDoc.exists) return res.status(404).json({ success: false, message: 'Project not found' });
        const projectData = projectDoc.data();
        const productsMap = { ...(projectData.products || {}) };
        const validatedProducts = [];
        const productsToDeduct = [];
        for (const line of merged.lines) {
          const { productId, color, quantity } = line;
          const key = makeProductKey(productId, color);
          if (productsMap[key] === undefined) {
            return res.status(400).json({
              success: false,
              message: `Product ${productId}${color ? ` (${color})` : ''} is not assigned to this project`,
            });
          }
          const split = splitOrderQuantity(quantity, { allowedInMap: productsMap[key] });
          validatedProducts.push({
            product: productId,
            quantity,
            supplementary: split.supplementary,
            color,
            projectQuantity: split.projectQuantity,
            supplementaryQuantity: split.supplementaryQuantity,
          });
          if (split.projectQuantity > 0) {
            productsToDeduct.push({ product: productId, quantity: split.projectQuantity, color });
          }
        }
        const newProductsMap = { ...productsMap };
        for (const item of productsToDeduct) {
          const key = makeProductKey(item.product, item.color);
          const current = newProductsMap[key] ?? 0;
          newProductsMap[key] = setProjectMapQty(current, parseProjectProductQty(current) - item.quantity);
        }
        await projectRefDb.update({
          products: newProductsMap,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        updates.products = validatedProducts.map((p) => ({
          product: p.product,
          quantity: p.quantity,
          supplementary: p.supplementary || false,
          color: p.color || null,
          projectQuantity: p.projectQuantity ?? p.quantity,
          supplementaryQuantity: p.supplementaryQuantity ?? 0,
        }));
        changes.after = productLinesSnapshot(updates.products);
      } else {
        changes.after = changes.before;
      }
      if (noteText != null) {
        updates.notes = noteText;
        updates.supervisor_notes = noteText;
    }
    await ref.update(updates);
      await appendOrderAudit(ref, {
        action: 'supervisor_modify',
        fromStatus: currentStatus,
        toStatus: currentStatus,
        actorId: req.user.id,
        actorName: req.user.name,
        actorRole: req.user.role,
        note: noteText || null,
        changes,
      });
      const updated = await ref.get();
      const data = await orderToApi(updated, firestore);
      return res.json({ success: true, data });
    }

    if (!isAdmin(req.user.role) && !isManager(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Only Admin or Manager can modify orders at this stage' });
    }

    const adminEditing = isAdmin(req.user.role) && currentStatus === 'pending_admin';
    const managerEditing = isManager(req.user.role) && currentStatus === 'pending_manager';
    if (!adminEditing && !managerEditing) {
      return res.status(400).json({
        success: false,
        message: isManager(req.user.role)
          ? 'Manager can only modify orders when pending_manager'
          : 'Order can only be modified when pending_admin',
      });
    }

    const {
      products: productsBody,
      adminNotes,
      store: storeId,
      depot: depotId,
      productStores: productStoresBody,
      sendToManager,
    } = req.body;
    // Admin may keep pending_admin (sendToManager:false) or forward to manager.
    // Manager always stays on pending_manager after edits.
    const goToManager = adminEditing && sendToManager !== false;
    const updates = {
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (goToManager) updates.status = 'pending_manager';
    const changes = { before: productLinesSnapshot(orderData.products), after: null };

    if (productsBody && Array.isArray(productsBody) && productsBody.length > 0) {
      const merged = mergeOrderProductLines(productsBody, req.user.id);
      if (merged.error) return res.status(400).json({ success: false, message: merged.error });
      const hasReplacement = merged.lines.some((l) => l.isReplaced);
      if (hasReplacement && !isAdminLike(req.user.role)) {
        return res.status(403).json({ success: false, message: 'Only Admin or Manager can replace products' });
      }
      // Restore old BOQ then deduct new quantities
      await restoreProjectBoq(firestore, orderData);

      const projectId = orderData.project_id;
      const projectRefDb = firestore.collection('projects').doc(projectId);
      const distributedMaps = await loadDistributedMapsForProject(firestore, projectId);
      const projectDoc = await projectRefDb.get();
      if (!projectDoc.exists) return res.status(404).json({ success: false, message: 'Project not found' });
      const projectData = projectDoc.data();
      const productsMap = { ...(projectData.products || {}) };
      const validatedProducts = [];
      const productsToDeduct = [];
      for (const line of merged.lines) {
        const { productId, color, quantity } = line;
        const boqId = line.originalProductId || productId;
        const boqColor = line.originalColor || (line.isReplaced ? null : color);
        const key = makeProductKey(boqId, boqColor);
        if (productsMap[key] === undefined) {
          return res.status(400).json({
            success: false,
            message: `Product ${boqId}${boqColor ? ` (${boqColor})` : ''} is not assigned to this project`,
          });
        }
        const ctx = orderLineContext(projectData, distributedMaps, boqId, boqColor);
        let split;
        if (line.hasStoredSplit
          && Number.isFinite(line.projectQuantity)
          && Number.isFinite(line.supplementaryQuantity)
          && (line.projectQuantity + line.supplementaryQuantity) === quantity) {
          split = {
            projectQuantity: Math.max(0, line.projectQuantity),
            supplementaryQuantity: Math.max(0, line.supplementaryQuantity),
            supplementary: line.supplementaryQuantity > 0,
          };
        } else {
          split = splitOrderQuantity(quantity, ctx);
        }
        const stored = {
          product: productId,
          quantity,
          supplementary: split.supplementary,
          color: color || null,
          projectQuantity: split.projectQuantity,
          supplementaryQuantity: split.supplementaryQuantity,
          original_product_id: line.originalProductId || productId,
          is_replaced: !!line.isReplaced,
          replacement_product_id: line.isReplaced ? line.replacementProductId : null,
        };
        if (line.originalColor) stored.original_color = line.originalColor;
        if (line.isReplaced) {
          stored.replaced_at = line.replacedAt || new Date().toISOString();
          stored.replaced_by = line.replacedBy || req.user.id;
        }
        validatedProducts.push(stored);
        if (split.projectQuantity > 0) {
          productsToDeduct.push({ product: boqId, quantity: split.projectQuantity, color: boqColor });
        }
      }
      const newProductsMap = { ...productsMap };
      for (const item of productsToDeduct) {
        const key = makeProductKey(item.product, item.color);
        const current = newProductsMap[key] ?? 0;
        newProductsMap[key] = setProjectMapQty(current, parseProjectProductQty(current) - item.quantity);
      }
      await projectRefDb.update({
        products: newProductsMap,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      updates.products = validatedProducts;
      changes.after = productLinesSnapshot(updates.products);
      if (hasReplacement) {
        updates.history = admin.firestore.FieldValue.arrayUnion(
          ...validatedProducts
            .filter((p) => p.is_replaced)
            .map((p) => ({
              action: 'product_replaced',
              at: p.replaced_at,
              by: p.replaced_by,
              original_product_id: p.original_product_id,
              replacement_product_id: p.replacement_product_id,
              quantity: p.quantity,
              note: 'Product replaced due to insufficient stock',
            }))
        );
      }
    } else {
      changes.after = changes.before;
    }

    if (adminNotes != null) updates.admin_notes = adminNotes;

    const sid = storeId || depotId;
    try {
      const stores = await resolveApprovedStores(
        firestore,
        { ...orderData, products: updates.products || orderData.products },
        sid,
        productStoresBody
      );
      updates.approved_product_stores = stores;
      updates.approved_store_id = stores[0]?.store_id || null;
    } catch (_) {
      // store assignment optional at admin edit; manager can finalize
    }

    await ref.update(updates);
    await appendOrderAudit(ref, {
      action: managerEditing
        ? 'manager_modify'
        : (goToManager ? 'admin_modify' : 'admin_replace_product'),
      fromStatus: currentStatus,
      toStatus: goToManager ? 'pending_manager' : currentStatus,
      actorId: req.user.id,
      actorName: req.user.name,
      actorRole: req.user.role,
      note: adminNotes || null,
      changes,
    });

    if (goToManager) {
      await createOrderNotification(firestore, {
        type: 'order_pending_manager',
        orderId: req.params.id,
        projectId: orderData.project_id,
        userId: orderData.user_id,
        userName: req.user.name,
        targetRole: 'manager',
        status: 'pending_manager',
      });
      for (const targetRole of ['warehouse_user', 'warehouse']) {
        await createOrderNotification(firestore, {
          type: 'order_modified',
          orderId: req.params.id,
          projectId: orderData.project_id,
          userId: orderData.user_id,
          userName: req.user.name,
          targetRole,
          status: 'pending_manager',
        });
      }
    } else if (managerEditing && productsBody && Array.isArray(productsBody) && productsBody.length > 0) {
      for (const targetRole of ['warehouse_user', 'warehouse', 'admin']) {
        await createOrderNotification(firestore, {
          type: 'order_modified',
          orderId: req.params.id,
          projectId: orderData.project_id,
          userId: orderData.user_id,
          userName: req.user.name,
          targetRole,
          status: 'pending_manager',
        });
      }
    }

    const updated = await ref.get();
    const data = await orderToApi(updated, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/** One-time / on-demand: migrate legacy rejected → cancelled on all orders */
router.post('/migrate-statuses', protect, authorizeAdminLike, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('orders').get();
    let updated = 0;
    for (const doc of snapshot.docs) {
      const s = doc.data().status;
      const migrated = migrateOrderStatus(s);
      if (migrated !== s) {
        await doc.ref.update({
          status: migrated,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        updated += 1;
      }
    }
    res.json({ success: true, message: `Migrated ${updated} orders`, updated });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * User confirms that the delivered order arrived successfully.
 * Notifies supervisor, admin and manager.
 */
router.put('/:id/confirm-arrival', protect, async (req, res) => {
  try {
    if (!isUser(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Only the order user can confirm arrival' });
    }
    const firestore = getFirestore();
    const ref = firestore.collection('orders').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Order not found' });

    const orderData = doc.data();
    if (String(orderData.user_id) !== String(req.user.id)) {
      return res.status(403).json({ success: false, message: 'You can only confirm your own orders' });
    }
    const status = migrateOrderStatus(orderData.status);
    if (status !== 'completed') {
      return res.status(400).json({ success: false, message: 'Order has not arrived yet' });
    }
    if (orderData.arrival_confirmed === true) {
      const data = await orderToApi(doc, firestore);
      return res.json({ success: true, data, message: 'Arrival already confirmed' });
    }

    await ref.update({
      arrival_confirmed: true,
      arrival_confirmed_at: admin.firestore.FieldValue.serverTimestamp(),
      arrival_confirmed_by: req.user.id,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      history: admin.firestore.FieldValue.arrayUnion({
        action: 'arrival_confirmed',
        fromStatus: 'completed',
        toStatus: 'completed',
        actorId: req.user.id,
        actorName: req.user.name,
        actorRole: req.user.role,
        note: 'Order arrived successfully',
        changes: null,
        created_at: new Date().toISOString(),
      }),
    });

    let projectName = null;
    try {
      const projectDoc = await firestore.collection('projects').doc(String(orderData.project_id)).get();
      if (projectDoc.exists) projectName = projectDoc.data().name || null;
    } catch (_) {}

    for (const targetRole of ['admin', 'manager', 'supervisor']) {
      await createOrderNotification(firestore, {
        type: 'order_arrived',
        orderId: ref.id,
        projectId: orderData.project_id,
        userId: req.user.id,
        userName: req.user.name,
        targetRole,
        status: 'completed',
        projectName,
      });
    }

    const updated = await ref.get();
    const data = await orderToApi(updated, firestore);
    res.json({ success: true, data, message: 'Arrival confirmed' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, authorize('manager'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('orders').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Order not found' });
    const orderData = doc.data();
    const status = orderData.status;

    if (status === 'pending') {
      const projectRef = firestore.collection('projects').doc(orderData.project_id);
      const projectDoc = await projectRef.get();
      if (projectDoc.exists) {
        const productsMap = { ...(projectDoc.data().products || {}) };
        for (const item of orderData.products || []) {
          if (item.supplementary) continue;
          const pid = item.product?.id ?? item.product?._id ?? item.product;
          const qty = item.quantity || 0;
          const col = (item.variant ?? item.color) ? String(item.variant ?? item.color).trim().toLowerCase() : null;
          const key = makeProductKey(pid, col);
          if (pid) productsMap[key] = addProjectMapQty(productsMap[key] ?? 0, qty);
        }
        await projectRef.update({
          products: productsMap,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } else if ((status === 'approved' || status === 'completed') && orderData.approved_store_id && orderData.stock_deducted === true) {
      const sid = orderData.approved_store_id;
      for (const item of orderData.products || []) {
        const productId = item.product?.id ?? item.product?._id ?? item.product;
        const quantity = item.quantity || 0;
        const variantLabel = (item.variant ?? item.color) ? String(item.variant ?? item.color).trim().toLowerCase() : null;
        // Legacy safeguard: restore only for old orders where stock was actually deducted at approval.
        const updateStock = require('../utils/updateStock');
        await updateStock(productId, sid, quantity, 'order', {
          project: orderData.project_id,
          user: req.user.id,
          reference: doc.id,
          variant: variantLabel,
          notes: 'Order deleted - stock restored',
        });
      }
      const projectRef = firestore.collection('projects').doc(orderData.project_id);
      const projectDoc = await projectRef.get();
      if (projectDoc.exists) {
        const supplementaryItems = (orderData.products || []).filter((p) => p.supplementary);
        if (supplementaryItems.length > 0) {
          const productsMap = { ...(projectDoc.data().products || {}) };
          for (const item of supplementaryItems) {
            const pid = item.product?.id ?? item.product?._id ?? item.product;
            const qty = item.quantity || 0;
            const col = (item.variant ?? item.color) ? String(item.variant ?? item.color).trim().toLowerCase() : null;
            const key = makeProductKey(pid, col);
            if (pid) productsMap[key] = addProjectMapQty(productsMap[key] ?? 0, qty);
          }
          await projectRef.update({
            products: productsMap,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    }

    await ref.delete();
    res.json({ success: true, message: 'Order deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
module.exports.orderToApi = orderToApi;
