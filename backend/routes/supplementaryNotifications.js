const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { protect, authorizeAdminOrWarehouse } = require('../middleware/auth');

/** Create notification for warehouse user when admin approves supplementary request */
async function createWarehouseSupplementaryNotification(firestore, { requestId, status, projectName, userName, productSummary }) {
  await firestore.collection('warehouse_supplementary_notifications').add({
    request_id: requestId,
    target_role: 'warehouse_user',
    status, // 'approved' | 'refused'
    project_name: projectName || null,
    user_name: userName || null,
    product_summary: productSummary || null,
    read: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// --- Warehouse user: notifications when admin approves/refuses supplementary requests ---
router.get('/warehouse/count', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
    if (!['admin', 'warehouse_user', 'warehouse'].includes(role)) {
      return res.json({ success: true, count: 0 });
    }
    const firestore = getFirestore();
    const snapshot = await firestore.collection('warehouse_supplementary_notifications')
      .where('target_role', '==', 'warehouse_user')
      .where('read', '==', false)
      .get();
    res.json({ success: true, count: snapshot.size });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/warehouse', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
    if (!['admin', 'warehouse_user', 'warehouse'].includes(role)) {
      return res.json({ success: true, data: [] });
    }
    const firestore = getFirestore();
    const snapshot = await firestore.collection('warehouse_supplementary_notifications')
      .where('target_role', '==', 'warehouse_user')
      .orderBy('created_at', 'desc')
      .limit(50)
      .get();
    const data = snapshot.docs.map((d) => {
      const r = d.data();
      return {
        id: d.id,
        requestId: r.request_id,
        status: r.status,
        projectName: r.project_name,
        userName: r.user_name,
        productSummary: r.product_summary,
        read: r.read,
        createdAt: r.created_at,
      };
    });
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/warehouse/read', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
    if (!['admin', 'warehouse_user', 'warehouse'].includes(role)) {
      return res.json({ success: true, count: 0 });
    }
    const firestore = getFirestore();
    const snapshot = await firestore.collection('warehouse_supplementary_notifications')
      .where('target_role', '==', 'warehouse_user')
      .where('read', '==', false)
      .get();
    const batch = firestore.batch();
    snapshot.docs.forEach((d) => batch.update(d.ref, { read: true }));
    await batch.commit();
    res.json({ success: true, count: snapshot.size });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
module.exports.createWarehouseSupplementaryNotification = createWarehouseSupplementaryNotification;
