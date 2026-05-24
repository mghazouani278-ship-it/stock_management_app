const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { protect, authorize } = require('../middleware/auth');
const { createOrderNotification } = require('./orderNotifications');
const { projectRef, userRef } = require('../utils/embedRefs');
const { parseProjectProductQty, setProjectMapQty, addProjectMapQty } = require('../utils/projectProductsMap');
const {
  makeProductKey,
  parseQtyField,
  loadDistributedMapsForProject,
  splitOrderQuantity,
} = require('../utils/projectBoqRemaining');
const { findStockStoreForProductLine, buildStoreByProductKey } = require('../utils/resolveProductStockStore');

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
function mergeOrderProductLines(productsBody) {
  const map = new Map();
  for (const item of productsBody) {
    const productId = item.product?.id ?? item.product?._id ?? item.product;
    const quantity = Number(item.quantity);
    const color = (item.variant ?? item.color) ? String(item.variant ?? item.color).trim().toLowerCase() : null;
    if (!productId || !quantity || quantity <= 0) return { error: 'Invalid product or quantity' };
    const key = makeProductKey(productId, color);
    const prev = map.get(key);
    map.set(key, {
      productId,
      color,
      quantity: (prev?.quantity || 0) + quantity,
    });
  }
  return { lines: Array.from(map.values()) };
}

function toIso(t) {
  return t?.toDate?.()?.toISOString?.() ?? (typeof t === 'string' ? t : null);
}

async function orderToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const userDoc = await firestore.collection('users').doc(data.user_id).get();
  const projectDoc = await firestore.collection('projects').doc(data.project_id).get();
  const projectData = projectDoc.exists ? projectDoc.data() : null;
  const distributedMaps = projectData
    ? await loadDistributedMapsForProject(firestore, data.project_id)
    : { distributedByProduct: {}, distributedByKey: {} };

  const products = (data.products || []).map(async (p) => {
    const prodId = p.product?.id ?? p.product?._id ?? p.product;
    const prodDoc = prodId ? await firestore.collection('products').doc(prodId).get() : null;
    const color = (p.variant ?? p.color) ? String(p.variant ?? p.color).trim().toLowerCase() : null;
    const item = {
      product: prodDoc?.exists ? { id: prodDoc.id, name: prodDoc.data().name, category: prodDoc.data().category, unit: prodDoc.data().unit } : { id: prodId },
      quantity: p.quantity,
    };
    if (color) {
      item.variant = color;
      item.color = color;
    }
    const qty = Number(p.quantity) || 0;
    let projectQty;
    let supplementaryQty;
    let isSupplementary;
    if (projectData && prodId) {
      const ctx = orderLineContext(projectData, distributedMaps, prodId, color);
      const split = splitOrderQuantity(qty, ctx);
      projectQty = split.projectQuantity;
      supplementaryQty = split.supplementaryQuantity;
      isSupplementary = split.supplementary;
    } else {
      const projStored = p.projectQuantity != null ? Number(p.projectQuantity) : (p.project_quantity != null ? Number(p.project_quantity) : null);
      const suppStored = p.supplementaryQuantity != null ? Number(p.supplementaryQuantity) : (p.supplementary_quantity != null ? Number(p.supplementary_quantity) : null);
      if (projStored != null || suppStored != null) {
        projectQty = Math.max(0, projStored ?? 0);
        supplementaryQty = Math.max(0, suppStored ?? 0);
      } else if (p.supplementary) {
        projectQty = 0;
        supplementaryQty = qty;
      } else {
        projectQty = qty;
        supplementaryQty = 0;
      }
      isSupplementary = p.supplementary || supplementaryQty > 0;
    }
    if (isSupplementary) item.supplementary = true;
    item.projectQuantity = projectQty;
    item.supplementaryQuantity = supplementaryQty;
    return item;
  });
  const orderDate = data.order_date;
  const orderDateStr = orderDate && typeof orderDate.toDate === 'function'
    ? orderDate.toDate().toISOString().split('T')[0]
    : (orderDate ? new Date(orderDate).toISOString().split('T')[0] : null);
  const status = data.status || '';
  const approvedAtRaw = data.approved_at ?? ((status === 'approved' || status === 'completed') ? data.updated_at : null);
  const deliveryDateRaw = data.delivery_date ?? (status === 'completed' ? data.updated_at : null);
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
    status: data.status,
    notes: data.notes,
    orderDate: orderDateStr,
    createdAt: toIso(data.created_at) ?? data.created_at,
    updatedAt: toIso(data.updated_at) ?? data.updated_at,
    approvedAt: toIso(approvedAtRaw) ?? approvedAtRaw,
    deliveryDate: toIso(deliveryDateRaw) ?? deliveryDateRaw,
  };
}

router.get('/', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    let docs;
    if (req.user.role === 'user') {
      const snapshot = await firestore.collection('orders').where('user_id', '==', req.user.id).get();
      docs = snapshot.docs;
    } else {
      const snapshot = await firestore.collection('orders').get();
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
    const data = await Promise.all(docs.map(d => orderToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('orders').doc(req.params.id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Order not found' });
    if (req.user.role === 'user' && doc.data().user_id !== req.user.id) return res.status(403).json({ success: false, message: 'You do not have access to this order' });
    const data = await orderToApi(doc, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post('/', protect, async (req, res) => {
  try {
    const { products: productsBody, notes, orderDate } = req.body;
    if (!productsBody || !Array.isArray(productsBody) || productsBody.length === 0) return res.status(400).json({ success: false, message: 'Please provide at least one product' });
    if (req.user.role === 'user' && !req.user.project_id) return res.status(400).json({ success: false, message: 'You are not assigned to any project' });
    const projectId = req.user.role === 'admin' ? req.body.projectId : req.user.project_id;
    if (!projectId) return res.status(400).json({ success: false, message: 'Please provide a project' });

    const merged = mergeOrderProductLines(productsBody);
    if (merged.error) return res.status(400).json({ success: false, message: merged.error });
    const lines = merged.lines;
    if (lines.length === 0) return res.status(400).json({ success: false, message: 'Please provide at least one product' });

    const firestore = getFirestore();
    const projectRef = firestore.collection('projects').doc(projectId);
    const orderRef = firestore.collection('orders').doc();
    const distributedMaps = await loadDistributedMapsForProject(firestore, projectId);

    let projectNameForNotif = null;

    await firestore.runTransaction(async (transaction) => {
      const projectDoc = await transaction.get(projectRef);
      if (!projectDoc.exists) {
        const e = new Error('Project not found');
        e.code = 'NOT_FOUND';
        throw e;
      }
      const projectData = projectDoc.data();
      projectNameForNotif = projectData.name || null;
      const productsMap = { ...(projectData.products || {}) };
      const validatedProducts = [];
      const productsToDeduct = [];
      for (const line of lines) {
        const { productId, color, quantity } = line;
        const key = makeProductKey(productId, color);
        const allowedRaw = productsMap[key];
        if (allowedRaw === undefined) {
          const e = new Error(`Product ${productId}${color ? ` (${color})` : ''} is not assigned to this project`);
          e.code = 'BAD_PRODUCT';
          throw e;
        }
        const ctx = orderLineContext(projectData, distributedMaps, productId, color);
        const split = splitOrderQuantity(quantity, ctx);
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
        newProductsMap[key] = setProjectMapQty(current, parseProjectProductQty(current) - item.quantity);
      }

      const ordDate = orderDate ? new Date(orderDate) : admin.firestore.FieldValue.serverTimestamp();
      const productsForStorage = validatedProducts.map(({ product, quantity, supplementary, color, projectQuantity, supplementaryQuantity }) => ({
        product,
        quantity,
        supplementary: supplementary || false,
        color: color || null,
        projectQuantity: projectQuantity ?? quantity,
        supplementaryQuantity: supplementaryQuantity ?? 0,
      }));

      if (productsToDeduct.length > 0) {
        transaction.update(projectRef, {
          products: newProductsMap,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      transaction.set(orderRef, {
        user_id: req.user.id,
        project_id: projectId,
        status: 'pending',
        notes: notes || null,
        order_date: ordDate,
        products: productsForStorage,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    const doc = await orderRef.get();
    const data = await orderToApi(doc, firestore);
    for (const targetRole of ['warehouse_user', 'warehouse']) {
      await createOrderNotification(firestore, {
        type: 'new_order',
        orderId: orderRef.id,
        projectId,
        userId: req.user.id,
        userName: req.user.name,
        targetRole,
        projectName: projectNameForNotif,
      });
    }
    res.status(201).json({ success: true, data });
  } catch (error) {
    if (error.code === 'NOT_FOUND') return res.status(404).json({ success: false, message: error.message });
    if (error.code === 'BAD_PRODUCT') return res.status(400).json({ success: false, message: error.message });
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/status', protect, async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ success: false, message: 'Only admins can update order status' });
    const { status, store: storeId, depot: depotId, productStores: productStoresBody } = req.body;
    const sid = storeId || depotId;
    if (!['pending', 'approved', 'rejected', 'completed'].includes(status)) return res.status(400).json({ success: false, message: 'Invalid status' });
    const firestore = getFirestore();
    const ref = firestore.collection('orders').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Order not found' });
    const orderData = doc.data();
    const currentStatus = orderData.status;

    if (status === 'rejected' && currentStatus === 'pending') {
      // Restore project's allowed quantity only for non-supplementary products
      const projectRef = firestore.collection('projects').doc(orderData.project_id);
      const projectDoc = await projectRef.get();
      if (projectDoc.exists) {
        const productsMap = { ...(projectDoc.data().products || {}) };
        for (const item of orderData.products || []) {
          if (item.supplementary) continue;
          const pid = item.product?.id ?? item.product?._id ?? item.product;
          const qty = item.quantity || 0;
          const color = (item.variant ?? item.color) ? String(item.variant ?? item.color).trim().toLowerCase() : null;
          const key = makeProductKey(pid, color);
          if (pid) productsMap[key] = addProjectMapQty(productsMap[key] ?? 0, qty);
        }
        await projectRef.update({
          products: productsMap,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await createOrderNotification(firestore, {
        type: 'order_rejected',
        orderId: req.params.id,
        projectId: orderData.project_id,
        userId: orderData.user_id,
        targetRole: 'warehouse_user',
        status: 'rejected',
      });
    }

    let approvedProductStores = [];
    if ((status === 'approved' || status === 'completed') && currentStatus === 'pending') {
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
            return res.status(400).json({
              success: false,
              message: `No stock registered for "${name}"${color ? ` (${color})` : ''}. Add stock with a store first.`,
            });
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
        return res.status(400).json({ success: false, message: 'Please provide store per product or a default store when approving' });
      }
      const primaryStoreId = approvedProductStores[0].store_id;
      // Stock is deducted when warehouse saves the distribution (not here).
      const projectRef = firestore.collection('projects').doc(orderData.project_id);
      const projectDoc = await projectRef.get();
      const projectDocData = projectDoc.exists ? projectDoc.data() : null;
      const projectName = projectDocData?.name || null;
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
      }
    }

    const updates = { status, updated_at: admin.firestore.FieldValue.serverTimestamp() };
    if (status === 'approved' || status === 'completed') {
      updates.approved_at = admin.firestore.FieldValue.serverTimestamp();
      updates.approved_store_id = approvedProductStores[0]?.store_id ?? sid;
      updates.approved_product_stores = approvedProductStores;
      updates.stock_deducted = false;
    }
    if (status === 'completed') {
      updates.delivery_date = admin.firestore.FieldValue.serverTimestamp();
    }
    await ref.update(updates);
    const updated = await ref.get();
    const data = await orderToApi(updated, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, authorize('admin'), async (req, res) => {
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
