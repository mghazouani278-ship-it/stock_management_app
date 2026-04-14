const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const updateStock = require('../utils/updateStock');
const { protect, authorize, authorizeAdminOrWarehouse } = require('../middleware/auth');
const { createWarehouseSupplementaryNotification } = require('./supplementaryNotifications');
const { projectRef, userRef } = require('../utils/embedRefs');
const { parseProjectProductQty, setProjectMapQty } = require('../utils/projectProductsMap');

function makeProductKey(productId, color) {
  return color ? `${productId}:${String(color).trim().toLowerCase()}` : productId;
}

function findAllowedForProduct(productsMap, productId, color) {
  const pColor = color ? String(color).trim().toLowerCase() : null;
  const key = makeProductKey(productId, pColor);
  if (productsMap[key] != null) return parseProjectProductQty(productsMap[key]);
  if (productsMap[productId] != null) return parseProjectProductQty(productsMap[productId]);
  for (const k of Object.keys(productsMap)) {
    if (k.startsWith(productId + ':') || k === productId) return parseProjectProductQty(productsMap[k]);
  }
  return 0;
}

function isProductInProject(productsMap, productId, color) {
  const pColor = color ? String(color).trim().toLowerCase() : null;
  const key = makeProductKey(productId, pColor);
  if (key in productsMap) return true;
  if (productId in productsMap) return true;
  return Object.keys(productsMap).some(k => k === productId || k.startsWith(productId + ':'));
}

async function requestToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const userDoc = await firestore.collection('users').doc(data.user_id).get();
  const projectDoc = await firestore.collection('projects').doc(data.project_id).get();
  const projProducts = projectDoc.data()?.products || {};
  const products = await Promise.all((data.products || []).map(async (p) => {
    const prodId = p.product?.id ?? p.product?._id ?? p.product;
    const prodDoc = prodId ? await firestore.collection('products').doc(prodId).get() : null;
    const allowed = findAllowedForProduct(projProducts, prodId, p.color);
    return {
      product: prodDoc?.exists ? { id: prodDoc.id, name: prodDoc.data().name, category: prodDoc.data().category, unit: prodDoc.data().unit } : { id: prodId },
      quantity: p.quantity,
      extraQuantity: p.extra_quantity ?? Math.max(0, (p.quantity || 0) - allowed),
      allowedQuantity: allowed,
    };
  }));
  return {
    id: doc.id,
    user: userRef(userDoc),
    project: projectRef(projectDoc),
    products,
    status: data.status,
    notes: data.notes,
    createdAt: data.created_at,
    updatedAt: data.updated_at,
  };
}

router.get('/', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    let docs;
    if (req.user.role === 'user') {
      const snapshot = await firestore.collection('supplementary_requests').where('user_id', '==', req.user.id).get();
      docs = snapshot.docs;
    } else if (['admin', 'warehouse_user'].includes(req.user.role)) {
      const snapshot = await firestore.collection('supplementary_requests').get();
      docs = snapshot.docs;
    } else {
      return res.status(403).json({ success: false, message: 'Not authorized' });
    }
    docs = docs.sort((a, b) => {
      const va = a.data().created_at?.toMillis?.() ?? 0;
      const vb = b.data().created_at?.toMillis?.() ?? 0;
      return vb - va;
    });
    const data = await Promise.all(docs.map(d => requestToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('supplementary_requests').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Supplementary request not found' });
    if (req.user.role === 'user' && doc.data().user_id !== req.user.id) return res.status(403).json({ success: false, message: 'Access denied' });
    const data = await requestToApi(doc, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/', protect, async (req, res) => {
  try {
    const { products: productsBody, notes } = req.body;
    if (!productsBody || !Array.isArray(productsBody) || productsBody.length === 0) return res.status(400).json({ success: false, message: 'Please provide at least one product' });
    if (req.user.role !== 'user') return res.status(400).json({ success: false, message: 'Only users can create supplementary requests' });
    if (!req.user.project_id) return res.status(400).json({ success: false, message: 'You are not assigned to any project' });

    const firestore = getFirestore();
    const projectDoc = await firestore.collection('projects').doc(req.user.project_id).get();
    if (!projectDoc.exists) return res.status(404).json({ success: false, message: 'Project not found' });
    const productsMap = projectDoc.data().products || {};

    const validatedProducts = [];
    let hasExtra = false;
    for (const item of productsBody) {
      const productId = item.product?.id ?? item.product?._id ?? item.product;
      const color = item.color ? String(item.color).trim().toLowerCase() : null;
      const quantity = item.quantity;
      if (!productId || !quantity || quantity <= 0) return res.status(400).json({ success: false, message: 'Invalid product or quantity' });
      const allowed = findAllowedForProduct(productsMap, productId, color);
      if (!isProductInProject(productsMap, productId, color)) return res.status(400).json({ success: false, message: `Product ${productId} is not assigned to this project` });
      if (quantity <= allowed) return res.status(400).json({ success: false, message: 'Supplementary request must have quantities exceeding the allowed amount' });
      hasExtra = true;
      validatedProducts.push({
        product: productId,
        quantity,
        extra_quantity: quantity - allowed,
        ...(color ? { color } : {}),
      });
    }
    if (!hasExtra) return res.status(400).json({ success: false, message: 'At least one product must exceed the allowed quantity' });

    const ref = await firestore.collection('supplementary_requests').add({
      user_id: req.user.id,
      project_id: req.user.project_id,
      status: 'pending',
      notes: notes || null,
      products: validatedProducts,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const doc = await ref.get();
    const data = await requestToApi(doc, firestore);
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/approve', protect, authorize('admin'), async (req, res) => {
  try {
    const { store: storeId, depot: depotId } = req.body;
    const sid = storeId || depotId;
    if (!sid) return res.status(400).json({ success: false, message: 'Please provide store ID when approving' });

    const firestore = getFirestore();
    const ref = firestore.collection('supplementary_requests').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Supplementary request not found' });
    const data = doc.data();
    if (data.status !== 'pending') return res.status(400).json({ success: false, message: `Request already ${data.status}` });

    for (const item of data.products || []) {
      const productId = item.product?.id ?? item.product?._id ?? item.product;
      const quantity = item.quantity || 0;
      const stockDoc = await firestore.collection('stock').doc(productId + '_' + sid).get();
      const available = stockDoc.exists ? (stockDoc.data().quantity || 0) : 0;
      if (available < quantity) {
        return res.status(400).json({
          success: false,
          message: `Insufficient stock. Available: ${available}, Requested: ${quantity}`,
        });
      }
    }

    for (const item of data.products || []) {
      const productId = item.product?.id ?? item.product?._id ?? item.product;
      const quantity = item.quantity || 0;
      await updateStock(productId, sid, -quantity, 'supplementary_request', {
        project: data.project_id,
        user: req.user.id,
        reference: doc.id,
        notes: 'Supplementary request approved',
      });
    }

    const projectRef = firestore.collection('projects').doc(data.project_id);
    const projectDoc = await projectRef.get();
    if (projectDoc.exists) {
      const productsMap = { ...(projectDoc.data().products || {}) };
      for (const item of data.products || []) {
        const productId = item.product?.id ?? item.product?._id ?? item.product;
        const color = item.color ? String(item.color).trim().toLowerCase() : null;
        const quantity = item.quantity || 0;
        const key = makeProductKey(productId, color);
        const existingKey = key in productsMap ? key : (productId in productsMap ? productId : Object.keys(productsMap).find(k => k === productId || k.startsWith(productId + ':')));
        if (existingKey != null) {
          const prev = productsMap[existingKey] ?? 0;
          productsMap[existingKey] = setProjectMapQty(prev, parseProjectProductQty(prev) - quantity);
        }
      }
      await projectRef.update({
        products: productsMap,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await ref.update({ status: 'approved', updated_at: admin.firestore.FieldValue.serverTimestamp() });
    const updated = await ref.get();
    const out = await requestToApi(updated, firestore);
    const userDoc = await firestore.collection('users').doc(data.user_id).get();
    const productNames = await Promise.all((data.products || []).map(async (p) => {
      const prodId = p.product?.id ?? p.product?._id ?? p.product;
      const prodDoc = prodId ? await firestore.collection('products').doc(prodId).get() : null;
      const name = prodDoc?.exists ? prodDoc.data().name : prodId;
      return `${name}: ${p.quantity}`;
    }));
    await createWarehouseSupplementaryNotification(firestore, {
      requestId: ref.id,
      status: 'approved',
      projectName: projectDoc?.exists ? projectDoc.data().name : null,
      userName: userDoc?.exists ? userDoc.data().name : null,
      productSummary: productNames.join(', '),
    });
    res.json({ success: true, data: out });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/refuse', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('supplementary_requests').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Supplementary request not found' });
    const data = doc.data();
    if (data.status !== 'pending') return res.status(400).json({ success: false, message: `Request already ${data.status}` });

    await ref.update({ status: 'refused', updated_at: admin.firestore.FieldValue.serverTimestamp() });
    const updated = await ref.get();
    const out = await requestToApi(updated, firestore);
    const projectDoc = await firestore.collection('projects').doc(data.project_id).get();
    const userDoc = await firestore.collection('users').doc(data.user_id).get();
    const productNames = await Promise.all((data.products || []).map(async (p) => {
      const prodId = p.product?.id ?? p.product?._id ?? p.product;
      const prodDoc = prodId ? await firestore.collection('products').doc(prodId).get() : null;
      const name = prodDoc?.exists ? prodDoc.data().name : prodId;
      return `${name}: ${p.quantity}`;
    }));
    await createWarehouseSupplementaryNotification(firestore, {
      requestId: ref.id,
      status: 'refused',
      projectName: projectDoc?.exists ? projectDoc.data().name : null,
      userName: userDoc?.exists ? userDoc.data().name : null,
      productSummary: productNames.join(', '),
    });
    res.json({ success: true, data: out });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
