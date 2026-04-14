const express = require('express');
const router = express.Router();
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { protect, authorize, authorizeAdminOrWarehouse } = require('../middleware/auth');

/** Create notification for admin when warehouse user creates a distribution (pending approval) */
async function createDistributionNotification(firestore, { distributionId, bonAlimentation, projectName, storeName, createdBy }) {
  await firestore.collection('distribution_notifications').add({
    distribution_id: distributionId,
    bon_alimentation: bonAlimentation || null,
    project_name: projectName || null,
    store_name: storeName || null,
    created_by: createdBy || null,
    read: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/** Create notification for admin when warehouse user validates (effectue) a distribution */
async function createAdminDistributionCompletedNotification(firestore, { distributionId, bonAlimentation, projectName, storeName, validatedBy }) {
  await firestore.collection('admin_distribution_completed_notifications').add({
    distribution_id: distributionId,
    bon_alimentation: bonAlimentation || null,
    project_name: projectName || null,
    store_name: storeName || null,
    validated_by: validatedBy || null,
    read: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/** Create notification for warehouse user when admin accepts or refuses their distribution */
async function createWarehouseDistributionStatusNotification(firestore, { distributionId, targetUserId, status, bonAlimentation, projectName, storeName }) {
  if (!targetUserId) return;
  await firestore.collection('warehouse_distribution_status_notifications').add({
    distribution_id: distributionId,
    target_user_id: targetUserId,
    status, // 'accepted' | 'refused'
    bon_alimentation: bonAlimentation || null,
    project_name: projectName || null,
    store_name: storeName || null,
    read: false,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

router.get('/', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('distribution_notifications').orderBy('created_at', 'desc').limit(50).get();
    const data = snapshot.docs.map((d) => {
      const r = d.data();
      return {
        id: d.id,
        type: 'distribution',
        distributionId: r.distribution_id,
        bonAlimentation: r.bon_alimentation,
        projectName: r.project_name,
        storeName: r.store_name,
        read: r.read,
        createdAt: r.created_at,
      };
    });
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/count', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('distribution_notifications').where('read', '==', false).get();
    res.json({ success: true, count: snapshot.size });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/read', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('distribution_notifications').where('read', '==', false).get();
    const batch = firestore.batch();
    snapshot.docs.forEach((d) => batch.update(d.ref, { read: true }));
    await batch.commit();
    res.json({ success: true, count: snapshot.size });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// --- Warehouse user: notifications when admin accepts/refuses their distributions ---
router.get('/warehouse/count', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const role = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
    if (!['admin', 'warehouse_user', 'warehouse'].includes(role)) {
      return res.json({ success: true, count: 0 });
    }
    const firestore = getFirestore();
    const snapshot = await firestore.collection('warehouse_distribution_status_notifications')
      .where('target_user_id', '==', req.user.id)
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
    const snapshot = await firestore.collection('warehouse_distribution_status_notifications')
      .where('target_user_id', '==', req.user.id)
      .orderBy('created_at', 'desc')
      .limit(50)
      .get();
    const data = snapshot.docs.map((d) => {
      const r = d.data();
      return {
        id: d.id,
        distributionId: r.distribution_id,
        status: r.status,
        bonAlimentation: r.bon_alimentation,
        projectName: r.project_name,
        storeName: r.store_name,
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
    const snapshot = await firestore.collection('warehouse_distribution_status_notifications')
      .where('target_user_id', '==', req.user.id)
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

// --- Admin: notifications when warehouse validates (effectue) a distribution ---
router.get('/admin-completed/count', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('admin_distribution_completed_notifications')
      .where('read', '==', false)
      .get();
    res.json({ success: true, count: snapshot.size });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/admin-completed', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('admin_distribution_completed_notifications')
      .orderBy('created_at', 'desc')
      .limit(50)
      .get();
    const data = snapshot.docs.map((d) => {
      const r = d.data();
      return {
        id: d.id,
        distributionId: r.distribution_id,
        bonAlimentation: r.bon_alimentation,
        projectName: r.project_name,
        storeName: r.store_name,
        validatedBy: r.validated_by,
        read: r.read,
        createdAt: r.created_at,
      };
    });
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/admin-completed/read', protect, authorize('admin'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('admin_distribution_completed_notifications')
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
module.exports.createDistributionNotification = createDistributionNotification;
module.exports.createWarehouseDistributionStatusNotification = createWarehouseDistributionStatusNotification;
module.exports.createAdminDistributionCompletedNotification = createAdminDistributionCompletedNotification;
