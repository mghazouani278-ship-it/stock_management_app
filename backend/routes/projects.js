const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { protect, authorize, checkProjectAccess } = require('../middleware/auth');
const { extractBoqDate } = require('../utils/projectProductsMap');

function parseProductKey(key) {
  const idx = key.indexOf(':');
  if (idx < 0) return { productId: key, color: null };
  return { productId: key.slice(0, idx), color: key.slice(idx + 1) };
}

function makeProductKey(productId, color) {
  return color ? `${productId}:${color}` : productId;
}

function normalizeProductsMap(productsMap) {
  const out = {};
  for (const [k, v] of Object.entries(productsMap || {})) {
    if (v && typeof v === 'object' && !Array.isArray(v)) {
      out[k] = {
        allowed_quantity: Math.max(0, Math.floor(Number(v.allowed_quantity ?? v.allowedQuantity ?? v.quantity)) || 0),
        boq_date: (v.boq_date ?? v.boqDate ?? '').toString().trim() || null,
      };
    } else {
      out[k] = Math.max(0, Math.floor(Number(v)) || 0);
    }
  }
  return Object.fromEntries(Object.entries(out).sort(([a], [b]) => a.localeCompare(b)));
}

function projectComparableData(data) {
  return {
    name: data?.name ?? null,
    name_ar: data?.name_ar ?? null,
    description: data?.description ?? null,
    status: data?.status ?? null,
    project_owner: data?.project_owner ?? null,
    project_owner_ar: data?.project_owner_ar ?? null,
    boq_creation_date: data?.boq_creation_date ?? null,
    products: normalizeProductsMap(data?.products || {}),
  };
}

function projectChangesList(beforeData, afterData) {
  const labels = [];
  if (beforeData.name !== afterData.name) labels.push('name');
  if (beforeData.name_ar !== afterData.name_ar) labels.push('nameAr');
  if (beforeData.description !== afterData.description) labels.push('description');
  if (beforeData.status !== afterData.status) labels.push('status');
  if (beforeData.project_owner !== afterData.project_owner) labels.push('projectOwner');
  if (beforeData.project_owner_ar !== afterData.project_owner_ar) labels.push('projectOwnerAr');
  if (beforeData.boq_creation_date !== afterData.boq_creation_date) labels.push('boqCreationDate');
  if (JSON.stringify(beforeData.products) !== JSON.stringify(afterData.products)) labels.push('products');
  return labels;
}

function buildHistorySnapshot(data) {
  return {
    name: data?.name ?? null,
    name_ar: data?.name_ar ?? null,
    description: data?.description ?? null,
    status: data?.status ?? null,
    project_owner: data?.project_owner ?? null,
    project_owner_ar: data?.project_owner_ar ?? null,
    boq_creation_date: data?.boq_creation_date ?? null,
    products: normalizeProductsMap(data?.products || {}),
    products_requested: normalizeProductsMap(data?.products_requested || data?.products || {}),
  };
}

function historyActor(req) {
  return {
    id: req.user?.id || null,
    name: req.user?.name || null,
    email: req.user?.email || null,
  };
}

/** ISO string for JSON (Firestore Timestamp, Date, or string). */
function firestoreTimestampToIso(v) {
  if (v == null || v === undefined) return null;
  if (typeof v.toDate === 'function') return v.toDate().toISOString();
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'string') return v;
  return null;
}

/** `yyyy-MM-dd` or null */
function normalizeBoqCreationDate(v) {
  if (v == null || v === '') return null;
  const s = String(v).trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return null;
  return s;
}

/** Same qty parsing as in project payloads / distribution lines. */
function parseQtyField(v) {
  if (v == null) return 0;
  if (typeof v === 'number' && !Number.isNaN(v)) return Math.max(0, Math.floor(v));
  if (typeof v === 'object' && v != null && ('quantity' in v || 'allowedQuantity' in v || 'allowed_quantity' in v)) {
    return parseQtyField(v.quantity ?? v.allowedQuantity ?? v.allowed_quantity);
  }
  const n = parseInt(String(v), 10);
  return Number.isNaN(n) ? 0 : Math.max(0, n);
}

/** Sum quantities from validated distributions for this project (per BOQ line key + product fallback). */
async function loadDistributedMapsForProject(firestore, projectId) {
  const distributedByProduct = {};
  const distributedByKey = {};
  const distSnap = await firestore.collection('distributions')
    .where('project_id', '==', projectId)
    .limit(1000)
    .get();
  for (const d of distSnap.docs) {
    const distData = d.data();
    for (const p of (distData.products || [])) {
      const pid = p.product?.id ?? p.product?._id ?? p.product;
      if (!pid) continue;
      const pColor = p.color ? String(p.color).trim().toLowerCase() : null;
      const qty = parseQtyField(p.quantity);
      if (qty <= 0) continue;
      distributedByProduct[pid] = (distributedByProduct[pid] ?? 0) + qty;
      const key = makeProductKey(pid, pColor);
      if (key !== pid) distributedByKey[key] = (distributedByKey[key] ?? 0) + qty;
    }
  }
  return { distributedByProduct, distributedByKey };
}

async function projectToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const usersSnap = await firestore.collection('users').where('project_id', '==', doc.id).get();
  const users = usersSnap.docs.map(d => d.id);
  const productsMap = data.products || {};
  const productsRequestedMap = data.products_requested || {};
  const productDetails = [];
  const supplementaryByProduct = {};
  const supplementaryByKey = {};
  // 1. From supplementary_requests (pending + approved).
  // UI "Supplementary" shows requested extra volume, not only already-approved rows.
  const suppSnap = await firestore.collection('supplementary_requests')
    .where('project_id', '==', doc.id)
    .limit(200)
    .get();
  for (const d of suppSnap.docs) {
    const reqStatus = String(d.data().status || '').toLowerCase();
    if (reqStatus === 'rejected' || reqStatus === 'refused' || reqStatus === 'cancelled') continue;
    for (const p of (d.data().products || [])) {
      const pid = p.product?.id ?? p.product?._id ?? p.product;
      if (!pid) continue;
      const pColor = p.color ? String(p.color).trim().toLowerCase() : null;
      // supplementary_requests store total requested `quantity` + computed `extra_quantity`.
      // For project supplementary counters we must accumulate only the EXTRA approved quantity.
      const suppQty = p.extra_quantity ?? Math.max(0, (p.quantity || 0) - (p.allowed_quantity ?? 0));
      supplementaryByProduct[pid] = (supplementaryByProduct[pid] ?? 0) + suppQty;
      const key = makeProductKey(pid, pColor);
      if (key !== pid) supplementaryByKey[key] = (supplementaryByKey[key] ?? 0) + suppQty;
    }
  }
  // 2. From non-rejected orders with supplementary products.
  // Include pending so admin can see requested supplementary growth immediately.
  const ordersSnap = await firestore.collection('orders')
    .where('project_id', '==', doc.id)
    .limit(500)
    .get();
  for (const d of ordersSnap.docs) {
    const data = d.data();
    const orderStatus = String(data.status || '').toLowerCase();
    if (orderStatus === 'rejected' || orderStatus === 'refused' || orderStatus === 'cancelled') continue;
    for (const p of (data.products || [])) {
      if (!p.supplementary) continue;
      const pid = p.product?.id ?? p.product?._id ?? p.product;
      if (!pid) continue;
      const pColor = p.color ? String(p.color).trim().toLowerCase() : null;
      // For supplementary order lines, accumulate the supplementary part only.
      // Prefer explicit `supplementaryQuantity`; fallback to derived quantity - projectQuantity.
      const explicitSupp = Number(p.supplementaryQuantity);
      const derivedSupp = Math.max(0, (Number(p.quantity) || 0) - (Number(p.projectQuantity) || 0));
      const qty = Number.isFinite(explicitSupp) && explicitSupp > 0
        ? explicitSupp
        : derivedSupp;
      supplementaryByProduct[pid] = (supplementaryByProduct[pid] ?? 0) + qty;
      const key = makeProductKey(pid, pColor);
      if (key !== pid) supplementaryByKey[key] = (supplementaryByKey[key] ?? 0) + qty;
    }
  }
  const { distributedByProduct, distributedByKey } = await loadDistributedMapsForProject(firestore, doc.id);

  for (const [key, rawAllowed] of Object.entries(productsMap)) {
    const { productId, color } = parseProductKey(key);
    const prodDoc = await firestore.collection('products').doc(productId).get();
    const allowedQuantity = parseQtyField(rawAllowed);
    const rawRequested = productsRequestedMap[key] ?? rawAllowed;
    const requestedQuantity = parseQtyField(rawRequested);
    const productKey = makeProductKey(productId, color);
    const supplementaryQuantity = (supplementaryByKey[productKey] ?? supplementaryByProduct[productId] ?? 0);
    const distributedQuantity = (distributedByKey[productKey] ?? distributedByProduct[productId] ?? 0);
    const item = {
      product: prodDoc.exists
        ? { id: productId, name: prodDoc.data().name, category: prodDoc.data().category, unit: prodDoc.data().unit }
        : { id: productId },
      allowedQuantity,
      requestedQuantity: requestedQuantity > 0 ? requestedQuantity : allowedQuantity,
      supplementaryQuantity,
      distributedQuantity,
    };
    if (color) item.color = color;
    const boq = extractBoqDate(rawAllowed);
    if (boq) item.boqDate = boq;
    productDetails.push(item);
  }
  const history = Array.isArray(data.history)
    ? data.history.map((h) => ({
        action: h?.action || 'updated',
        at: firestoreTimestampToIso(h?.at) || firestoreTimestampToIso(h?.createdAt) || null,
        by: h?.by || null,
        changes: Array.isArray(h?.changes) ? h.changes : [],
        snapshot: h?.snapshot && typeof h.snapshot === 'object' ? h.snapshot : null,
      }))
    : [];
  return {
    id: doc.id,
    name: data.name,
    nameAr: data.name_ar || null,
    description: data.description,
    images1: data.images1 ?? data.images ?? null,
    status: data.status,
    projectOwner: data.project_owner || null,
    projectOwnerAr: data.project_owner_ar || null,
    depotId: data.depot_id || null,
    users,
    products: productDetails,
    boqCreationDate: data.boq_creation_date || null,
    createdAt: firestoreTimestampToIso(data.created_at),
    updatedAt: firestoreTimestampToIso(data.updated_at),
    history,
  };
}

function _normalizeRole(role) {
  return (role || '').toLowerCase().replace(/\s+/g, '_');
}

/** Lightweight: id, name, products; includes distributedQuantity from distributions (same as full API). */
async function projectToApiLite(doc, productCache, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const productsMap = data.products || {};
  const productsRequestedMap = data.products_requested || productsMap;
  const { distributedByProduct, distributedByKey } = await loadDistributedMapsForProject(firestore, doc.id);
  const productDetails = [];
  for (const [key, rawAllowed] of Object.entries(productsMap)) {
    const { productId, color } = parseProductKey(key);
    const rawRequested = productsRequestedMap[key] ?? rawAllowed;
    const requestedQuantity = parseQtyField(rawRequested);
    if (requestedQuantity <= 0) continue;
    const allowedQuantity = parseQtyField(rawAllowed);
    const prod = productCache.get(productId);
    const productKey = makeProductKey(productId, color);
    const distributedQuantity = (distributedByKey[productKey] ?? distributedByProduct[productId] ?? 0);
    const lite = {
      product: prod ? { id: productId, name: prod.name } : { id: productId },
      allowedQuantity,
      requestedQuantity,
      supplementaryQuantity: 0,
      distributedQuantity,
      ...(color ? { color } : {}),
    };
    const boq = extractBoqDate(rawAllowed);
    if (boq) lite.boqDate = boq;
    productDetails.push(lite);
  }
  return {
    id: doc.id,
    name: data.name,
    nameAr: data.name_ar || null,
    description: data.description || null,
    status: data.status || 'active',
    projectOwner: data.project_owner || null,
    projectOwnerAr: data.project_owner_ar || null,
    depotId: data.depot_id || null,
    boqCreationDate: data.boq_creation_date || null,
    createdAt: firestoreTimestampToIso(data.created_at),
    updatedAt: firestoreTimestampToIso(data.updated_at),
    products: productDetails,
  };
}

router.get('/', protect, async (req, res) => {
  try {
    res.set('Cache-Control', 'no-store, no-cache, must-revalidate, private');
    const firestore = getFirestore();
    const light = req.query.light === '1' || req.query.light === 'true';
    if (_normalizeRole(req.user.role) === 'user') {
      if (!req.user.project_id) return res.json({ success: true, count: 0, data: [] });
      const doc = await firestore.collection('projects').doc(req.user.project_id).get();
      if (!doc.exists) return res.json({ success: true, count: 0, data: [] });
      const data = light
        ? await projectToApiLite(doc, await _buildProductCache([doc], firestore), firestore)
        : await projectToApi(doc, firestore);
      return res.json({ success: true, count: 1, data: [data] });
    }
    const snapshot = await firestore.collection('projects').orderBy('created_at', 'desc').get();
    if (light) {
      const productCache = await _buildProductCache(snapshot.docs, firestore);
      const data = (await Promise.all(snapshot.docs.map((d) => projectToApiLite(d, productCache, firestore)))).filter(Boolean);
      return res.json({ success: true, count: data.length, data });
    }
    const data = await Promise.all(snapshot.docs.map(d => projectToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

async function _buildProductCache(projectDocs, firestore) {
  const productIds = new Set();
  for (const doc of projectDocs) {
    const d = doc.data();
    const pm = d.products || {};
    for (const key of Object.keys(pm)) {
      const { productId } = parseProductKey(key);
      productIds.add(productId);
    }
  }
  if (productIds.size === 0) return new Map();
  const refs = [...productIds].map(id => firestore.collection('products').doc(id));
  const chunks = [];
  const batchSize = 30;
  for (let i = 0; i < refs.length; i += batchSize) {
    chunks.push(firestore.getAll(...refs.slice(i, i + batchSize)));
  }
  const batches = await Promise.all(chunks);
  const cache = new Map();
  for (const docs of batches) {
    for (const d of docs) {
      if (d.exists) cache.set(d.id, { id: d.id, name: d.data().name });
    }
  }
  return cache;
}

router.get('/:id', protect, checkProjectAccess, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('projects').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Project not found' });
    const data = await projectToApi(doc, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/', protect, authorize('admin'), async (req, res) => {
  try {
    const { name, nameAr, description, images1, products, projectOwner, projectOwnerAr, boqCreationDate, boq_creation_date, depotId } = req.body;
    if (!name) return res.status(400).json({ success: false, message: 'Please provide a project name' });
    const boqCreationNorm = normalizeBoqCreationDate(boqCreationDate ?? boq_creation_date);
    const firestore = getFirestore();
    const existing = await firestore.collection('projects').where('name', '==', name.trim()).limit(1).get();
    if (!existing.empty) return res.status(400).json({ success: false, message: 'Project name already exists' });
    const productsMap = {};
    if (products && Array.isArray(products)) {
      for (const p of products) {
        const pid = p.product?.id ?? p.product?._id ?? p.product;
        const qty = p.allowedQuantity ?? p.allowed_quantity ?? 0;
        const color = p.color ? String(p.color).trim().toLowerCase() : null;
        const q = Math.max(0, Math.floor(Number(qty)) || 0);
        const boq = (p.boqDate ?? p.boq_date ?? '').toString().trim();
        if (!pid) continue;
        const key = makeProductKey(pid, color);
        if (boq) productsMap[key] = { allowed_quantity: q, boq_date: boq };
        else productsMap[key] = q;
      }
    }
    const nameArTrim = nameAr != null && String(nameAr).trim() !== '' ? String(nameAr).trim() : null;
    const projectDocData = {
      name: name.trim(),
      name_ar: nameArTrim,
      description: description || null,
      images1: images1 || null,
      status: 'active',
      project_owner: projectOwner ? String(projectOwner).trim() : null,
      project_owner_ar: projectOwnerAr != null && String(projectOwnerAr).trim() !== '' ? String(projectOwnerAr).trim() : null,
      boq_creation_date: boqCreationNorm,
      products: productsMap,
      products_requested: { ...productsMap },
    };
    if (depotId != null && String(depotId).trim() !== '') {
      projectDocData.depot_id = String(depotId).trim();
    }
    const ref = await firestore.collection('projects').add({
      ...projectDocData,
      history: [
        {
          action: 'created',
          // Firestore forbids FieldValue.serverTimestamp() inside array elements; use Timestamp.
          at: admin.firestore.Timestamp.now(),
          by: historyActor(req),
          changes: ['project'],
          snapshot: buildHistorySnapshot(projectDocData),
        },
      ],
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const doc = await ref.get();
    const data = await projectToApi(doc, firestore);
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const { name, nameAr, description, images1, status, products, projectOwner, projectOwnerAr, boqCreationDate, boq_creation_date, depotId } = req.body;
    const firestore = getFirestore();
    const ref = firestore.collection('projects').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Project not found' });
    if (name) {
      const existing = await firestore.collection('projects').where('name', '==', name.trim()).limit(1).get();
      if (!existing.empty && existing.docs[0].id !== req.params.id) return res.status(400).json({ success: false, message: 'Project name already exists' });
    }
    const updates = { updated_at: admin.firestore.FieldValue.serverTimestamp() };
    if (name != null) updates.name = name;
    if (nameAr !== undefined) {
      updates.name_ar = nameAr != null && String(nameAr).trim() !== '' ? String(nameAr).trim() : null;
    }
    if (description !== undefined) updates.description = description;
    if (images1 !== undefined) updates.images1 = images1;
    if (status != null) updates.status = status;
    if (projectOwner !== undefined) updates.project_owner = projectOwner ? String(projectOwner).trim() : null;
    if (projectOwnerAr !== undefined) {
      updates.project_owner_ar = projectOwnerAr != null && String(projectOwnerAr).trim() !== '' ? String(projectOwnerAr).trim() : null;
    }
    if (boqCreationDate !== undefined || boq_creation_date !== undefined) {
      const raw = boqCreationDate !== undefined ? boqCreationDate : boq_creation_date;
      updates.boq_creation_date = normalizeBoqCreationDate(raw);
    }
    if (depotId !== undefined) {
      updates.depot_id = depotId != null && String(depotId).trim() !== '' ? String(depotId).trim() : null;
    }
    if (products && Array.isArray(products)) {
      const productsMap = {};
      for (const p of products) {
        const pid = p.product?.id ?? p.product?._id ?? p.product;
        const qty = p.allowedQuantity ?? p.allowed_quantity ?? 0;
        const color = p.color ? String(p.color).trim().toLowerCase() : null;
        const q = Math.max(0, Math.floor(Number(qty)) || 0);
        const boq = (p.boqDate ?? p.boq_date ?? '').toString().trim();
        if (!pid) continue;
        const key = makeProductKey(pid, color);
        if (boq) productsMap[key] = { allowed_quantity: q, boq_date: boq };
        else productsMap[key] = q;
      }
      updates.products = productsMap;
      updates.products_requested = { ...productsMap };
    }
    const beforeComparable = projectComparableData(doc.data() || {});
    const mergedAfter = { ...(doc.data() || {}), ...updates };
    const afterComparable = projectComparableData(mergedAfter);
    const changes = projectChangesList(beforeComparable, afterComparable);
    updates.history = admin.firestore.FieldValue.arrayUnion({
      action: 'updated',
      at: admin.firestore.Timestamp.now(),
      by: historyActor(req),
      changes: changes.length ? changes : ['project'],
      snapshot: buildHistorySnapshot(mergedAfter),
    });
    await ref.update(updates);
    const updated = await ref.get();
    const data = await projectToApi(updated, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('projects').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Project not found' });
    const usersSnap = await firestore.collection('users').where('project_id', '==', req.params.id).get();
    const batch = firestore.batch();
    usersSnap.docs.forEach(d => batch.update(d.ref, { project_id: null }));
    batch.delete(ref);
    await batch.commit();
    res.json({ success: true, message: 'Project deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/:id/assign-user', protect, authorize('admin'), async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ success: false, message: 'Please provide user ID' });
    const firestore = getFirestore();
    const projectRef = firestore.collection('projects').doc(req.params.id);
    const projectDoc = await projectRef.get();
    if (!projectDoc.exists) return res.status(404).json({ success: false, message: 'Project not found' });
    const userRef = firestore.collection('users').doc(userId);
    const userDoc = await userRef.get();
    if (!userDoc.exists) return res.status(404).json({ success: false, message: 'User not found' });
    const userData = userDoc.data();
    if (userData.project_id && userData.project_id !== req.params.id) return res.status(400).json({ success: false, message: 'User is already assigned to another project' });
    await userRef.update({ project_id: req.params.id });
    const updated = await projectRef.get();
    const data = await projectToApi(updated, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/:id/assign-product', protect, authorize('admin'), async (req, res) => {
  try {
    const { productId, allowedQuantity } = req.body;
    if (!productId || allowedQuantity === undefined) return res.status(400).json({ success: false, message: 'Please provide product ID and allowed quantity' });
    const firestore = getFirestore();
    const ref = firestore.collection('projects').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Project not found' });
    const products = { ...(doc.data().products || {}), [productId]: allowedQuantity };
    const productsRequested = { ...(doc.data().products_requested || doc.data().products || {}), [productId]: allowedQuantity };
    await ref.update({ products, products_requested: productsRequested, updated_at: admin.firestore.FieldValue.serverTimestamp() });
    const updated = await ref.get();
    const data = await projectToApi(updated, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
