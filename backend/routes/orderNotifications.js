const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { protect, authorize } = require('../middleware/auth');
const { checkAndNotifyLateOrders } = require('../utils/lateOrders');

/** Create order notification for admin (new order) or warehouse (approved/rejected) */
async function createOrderNotification(firestore, { type, orderId, projectId, userId, userName, targetRole, status, products, projectName, storeId, daysLate, expectedArrivalDays }) {
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
  if (daysLate != null) doc.days_late = daysLate;
  if (expectedArrivalDays != null) doc.expected_arrival_days = expectedArrivalDays;
  if (!existing.empty) {
    const prev = existing.docs[0].data();
    let read = false;
    if (type === 'order_late' && prev.read === true && Number(daysLate) === Number(prev.days_late)) {
      read = true;
    }
    // Keep one notification per (order,type,target_role) but refresh payload.
    await existing.docs[0].ref.set({
      ...doc,
      created_at: prev.created_at || doc.created_at,
      read,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return;
  }
  await firestore.collection('order_notifications').add(doc);
}

function filterNotificationsForRole(docs, req) {
  const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
  let filtered = docs;
  if (role === 'supervisor') {
    const allowed = (req.user.project_ids || []).map(String).filter(Boolean);
    if (allowed.length === 0 && req.user.project_id) allowed.push(String(req.user.project_id));
    filtered = filtered.filter((d) => {
      const pid = d.data ? d.data().project_id : d.projectId;
      return pid != null && allowed.includes(String(pid));
    });
  }
  if (role === 'user') {
    const uid = String(req.user.id || '');
    filtered = filtered.filter((d) => {
      const data = d.data ? d.data() : d;
      const owner = data.user_id ?? data.userId;
      return owner == null || String(owner) === uid;
    });
  }
  return filtered;
}

let _lastLateCheckAt = 0;
const LATE_CHECK_MIN_INTERVAL_MS = 5 * 60 * 1000;

async function runLateCheckSafe() {
  const now = Date.now();
  if (now - _lastLateCheckAt < LATE_CHECK_MIN_INTERVAL_MS) return;
  _lastLateCheckAt = now;
  try {
    const firestore = getFirestore();
    await checkAndNotifyLateOrders(firestore, createOrderNotification);
  } catch (err) {
    console.warn('[lateOrders]', err.message || err);
  }
}

router.get('/count', protect, async (req, res) => {
  try {
    await runLateCheckSafe();
    const firestore = getFirestore();
    const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
    const snapshot = await firestore.collection('order_notifications')
      .where('target_role', '==', role)
      .limit(500)
      .get();
    let docs = snapshot.docs.filter((d) => d.data().read === false);
    docs = filterNotificationsForRole(docs, req);
    res.json({ success: true, count: docs.length });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/', protect, async (req, res) => {
  try {
    await runLateCheckSafe();
    const firestore = getFirestore();
    const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
    const snapshot = await firestore.collection('order_notifications')
      .where('target_role', '==', role)
      .limit(100)
      .get();
    const scoped = filterNotificationsForRole(snapshot.docs, req);
    const data = scoped
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
      if (r.days_late != null) item.daysLate = r.days_late;
      if (r.expected_arrival_days != null) item.expectedArrivalDays = r.expected_arrival_days;
      if (r.type === 'new_order') {
        item.bannerBackground = '#C62828';
        item.bannerTextColor = '#FFFFFF';
      }
      if (r.type === 'order_late') {
        item.bannerBackground = '#E65100';
        item.bannerTextColor = '#FFFFFF';
      }
      if (r.type === 'order_arrived') {
        item.bannerBackground = '#2E7D32';
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
    let unreadDocs = snapshot.docs.filter((d) => d.data().read === false);
    unreadDocs = filterNotificationsForRole(unreadDocs, req);
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
module.exports.checkAndNotifyLateOrders = () => runLateCheckSafe();
