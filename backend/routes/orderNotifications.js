const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { protect, authorize } = require('../middleware/auth');

/** Create order notification for admin (new order) or warehouse (approved/rejected) */
async function createOrderNotification(firestore, { type, orderId, projectId, userId, userName, targetRole, status, products, projectName, storeId }) {
  // Idempotency guard: avoid duplicate notifications for same event/target.
  // This can happen on client retries or accidental double-submit.
  const existing = await firestore.collection('order_notifications')
    .where('order_id', '==', orderId)
    .where('type', '==', type)
    .where('target_role', '==', targetRole)
    .limit(1)
    .get();
  const doc = {
    type,
    order_id: orderId,
    project_id: projectId || null,
    user_id: userId || null,
    user_name: userName || null,
    target_role: targetRole,
    status: status || null,
    read: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (products && products.length > 0) doc.products = products;
  if (projectName) doc.project_name = projectName;
  if (storeId) doc.store_id = storeId;
  if (!existing.empty) {
    // Keep one notification per (order,type,target_role) but refresh payload so warehouse
    // always receives latest approved products/quantities.
    await existing.docs[0].ref.set({
      ...doc,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return;
  }
  await firestore.collection('order_notifications').add(doc);
}

router.get('/count', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
    const snapshot = await firestore.collection('order_notifications')
      .where('target_role', '==', role)
      .limit(500)
      .get();
    const unreadCount = snapshot.docs.filter((d) => d.data().read === false).length;
    res.json({ success: true, count: unreadCount });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
    const snapshot = await firestore.collection('order_notifications')
      .where('target_role', '==', role)
      .limit(100)
      .get();
    const data = snapshot.docs
      .map((d) => {
      const r = d.data();
      const item = {
        id: d.id,
        type: r.type,
        orderId: r.order_id,
        projectId: r.project_id,
        userId: r.user_id,
        userName: r.user_name,
        status: r.status,
        read: r.read,
        createdAt: r.created_at,
      };
      if (r.products) item.products = r.products;
      if (r.project_name) item.projectName = r.project_name;
      if (r.store_id) item.storeId = r.store_id;
      if (r.type === 'new_order') {
        item.bannerBackground = '#C62828';
        item.bannerTextColor = '#FFFFFF';
      }
      return item;
    })
      .sort((a, b) => {
        const ta = typeof a.createdAt?.toMillis === 'function' ? a.createdAt.toMillis() : (a.createdAt ? new Date(a.createdAt).getTime() : 0);
        const tb = typeof b.createdAt?.toMillis === 'function' ? b.createdAt.toMillis() : (b.createdAt ? new Date(b.createdAt).getTime() : 0);
        return tb - ta;
      })
      .slice(0, 50);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/read', protect, async (req, res) => {
  try {
    const firestore = getFirestore();
    const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
    const snapshot = await firestore.collection('order_notifications')
      .where('target_role', '==', role)
      .limit(500)
      .get();
    const unreadDocs = snapshot.docs.filter((d) => d.data().read === false);
    if (unreadDocs.length > 0) {
      const batch = firestore.batch();
      unreadDocs.forEach((d) => batch.update(d.ref, { read: true }));
      await batch.commit();
    }
    res.json({ success: true, count: unreadDocs.length });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
module.exports.createOrderNotification = createOrderNotification;
