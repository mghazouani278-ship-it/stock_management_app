const { admin } = require('../firebase');
const { migrateOrderStatus } = require('./roles');

function toYmd(value) {
  if (!value) return null;
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}/.test(value)) {
    return value.slice(0, 10);
  }
  if (typeof value?.toDate === 'function') {
    return value.toDate().toISOString().split('T')[0];
  }
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().split('T')[0];
}

function addDaysYmd(ymd, days) {
  const [y, m, d] = ymd.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + days);
  return dt.toISOString().split('T')[0];
}

function diffDaysYmd(laterYmd, earlierYmd) {
  const [y1, m1, d1] = laterYmd.split('-').map(Number);
  const [y2, m2, d2] = earlierYmd.split('-').map(Number);
  const a = Date.UTC(y1, m1 - 1, d1);
  const b = Date.UTC(y2, m2 - 1, d2);
  return Math.floor((a - b) / 86400000);
}

function normalizeExpectedArrivalDays(raw) {
  const n = parseInt(raw, 10);
  if (!Number.isFinite(n) || n < 1 || n > 7) return null;
  return n;
}

function computeExpectedArrivalDate(orderDateYmd, days) {
  if (!orderDateYmd || !days) return null;
  return addDaysYmd(orderDateYmd, days);
}

/**
 * Find open orders past their expected arrival and notify admin/manager/supervisor/user.
 * Idempotent per (order, order_late, role); refreshes days_late and re-opens unread when lateness grows.
 */
async function checkAndNotifyLateOrders(firestore, createOrderNotification) {
  const todayYmd = new Date().toISOString().split('T')[0];
  const snapshot = await firestore.collection('orders').limit(1000).get();
  let notified = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const status = migrateOrderStatus(data.status || '');
    if (status === 'completed' || status === 'cancelled' || status === 'rejected') continue;

    const days = normalizeExpectedArrivalDays(data.expected_arrival_days);
    if (!days) continue;

    const orderDateYmd = toYmd(data.order_date);
    const expectedYmd = toYmd(data.expected_arrival_date) || computeExpectedArrivalDate(orderDateYmd, days);
    if (!expectedYmd) continue;
    if (todayYmd <= expectedYmd) continue;

    const daysLate = Math.max(1, diffDaysYmd(todayYmd, expectedYmd));
    let projectName = null;
    if (data.project_id) {
      try {
        const pDoc = await firestore.collection('projects').doc(String(data.project_id)).get();
        if (pDoc.exists) projectName = pDoc.data().name || null;
      } catch (_) {}
    }
    const targets = ['admin', 'manager', 'supervisor', 'user'];
    for (const targetRole of targets) {
      await createOrderNotification(firestore, {
        type: 'order_late',
        orderId: doc.id,
        projectId: data.project_id,
        userId: data.user_id,
        targetRole,
        status,
        daysLate,
        expectedArrivalDays: days,
        projectName,
      });
      notified += 1;
    }

    // Persist computed expected date if missing (legacy orders after field added).
    if (!data.expected_arrival_date && expectedYmd) {
      try {
        await doc.ref.update({
          expected_arrival_date: expectedYmd,
          updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  return { checked: snapshot.size, notified };
}

module.exports = {
  toYmd,
  addDaysYmd,
  diffDaysYmd,
  normalizeExpectedArrivalDays,
  computeExpectedArrivalDate,
  checkAndNotifyLateOrders,
};
