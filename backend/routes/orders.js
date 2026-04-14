const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { protect, authorize } = require('../middleware/auth');
const { createOrderNotification } = require('./orderNotifications');
const { projectRef, userRef } = require('../utils/embedRefs');
const { parseProjectProductQty, setProjectMapQty, addProjectMapQty } = require('../utils/projectProductsMap');

function makeProductKey(productId, color) {
  return color ? `${productId}:${color}` : productId;
}

function toIso(t) {
  return t?.toDate?.()?.toISOString?.() ?? (typeof t === 'string' ? t : null);
}

async function orderToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const userDoc = await firestore.collection('users').doc(data.user_id).get();
  const projectDoc = await firestore.collection('projects').doc(data.project_id).get();
  const products = (data.products || []).map(async (p) => {
    const prodId = p.product?.id ?? p.product?._id ?? p.product;
    const prodDoc = prodId ? await firestore.collection('products').doc(prodId).get() : null;
    const item = {
      product: prodDoc?.exists ? { id: prodDoc.id, name: prodDoc.data().name, category: prodDoc.data().category, unit: prodDoc.data().unit } : { id: prodId },
      quantity: p.quantity,
    };
    if (p.variant ?? p.color) {
      const v = p.variant ?? p.color;
      item.variant = v;
      item.color = v;
    }
    if (p.supplementary) item.supplementary = true;
    item.projectQuantity = p.projectQuantity != null ? p.projectQuantity : (p.supplementary ? 0 : p.quantity);
    item.supplementaryQuantity = p.supplementaryQuantity != null ? p.supplementaryQuantity : (p.supplementary ? p.quantity : 0);
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

    const firestore = getFirestore();
    const projectDoc = await firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) return res.status(404).json({ success: false, message: 'Project not found' });
    const productsMap = projectDoc.data().products || {};
    const validatedProducts = [];
    const productsToDeduct = [];
    for (const item of productsBody) {
      const productId = item.product?.id ?? item.product?._id ?? item.product;
      const quantity = item.quantity;
      const color = (item.variant ?? item.color) ? String(item.variant ?? item.color).trim().toLowerCase() : null;
      if (!productId || !quantity || quantity <= 0) return res.status(400).json({ success: false, message: 'Invalid product or quantity' });
      const key = makeProductKey(productId, color);
      const allowedRaw = productsMap[key];
      if (allowedRaw === undefined) return res.status(400).json({ success: false, message: `Product ${productId}${color ? ` (${color})` : ''} is not assigned to this project` });
      const allowed = parseProjectProductQty(allowedRaw);
      const projectQty = Math.min(quantity, allowed);
      const supplementaryQty = Math.max(0, quantity - allowed);
      if (quantity > allowed) {
        validatedProducts.push({ product: productId, quantity, supplementary: true, color, projectQuantity: projectQty, supplementaryQuantity: supplementaryQty });
      } else {
        validatedProducts.push({ product: productId, quantity, supplementary: false, color, projectQuantity: projectQty, supplementaryQuantity: supplementaryQty });
        productsToDeduct.push({ product: productId, quantity, color });
      }
    }

    const projectRef = firestore.collection('projects').doc(projectId);
    if (productsToDeduct.length > 0) {
      const newProductsMap = { ...productsMap };
      for (const item of productsToDeduct) {
        const key = makeProductKey(item.product, item.color);
        const current = newProductsMap[key] ?? 0;
        newProductsMap[key] = setProjectMapQty(current, parseProjectProductQty(current) - item.quantity);
      }
      await projectRef.update({
        products: newProductsMap,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
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
    const ref = await firestore.collection('orders').add({
      user_id: req.user.id,
      project_id: projectId,
      status: 'pending',
      notes: notes || null,
      order_date: ordDate,
      products: productsForStorage,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    const doc = await ref.get();
    const data = await orderToApi(doc, firestore);
    await createOrderNotification(firestore, {
      type: 'new_order',
      orderId: ref.id,
      projectId,
      userId: req.user.id,
      userName: req.user.name,
      targetRole: 'admin',
      projectName: projectDoc.data().name || null,
    });
    res.status(201).json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/status', protect, async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ success: false, message: 'Only admins can update order status' });
    const { status, store: storeId, depot: depotId } = req.body;
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

    if ((status === 'approved' || status === 'completed') && currentStatus === 'pending') {
      if (!sid) return res.status(400).json({ success: false, message: 'Please provide store ID when approving order' });
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
          storeId: sid,
        });
      }
    }

    const updates = { status, updated_at: admin.firestore.FieldValue.serverTimestamp() };
    if (status === 'approved' || status === 'completed') {
      updates.approved_at = admin.firestore.FieldValue.serverTimestamp();
      updates.approved_store_id = sid;
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
