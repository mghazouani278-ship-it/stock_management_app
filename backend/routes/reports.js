const express = require('express');
const router = express.Router();
const { getFirestore, admin } = require('../firebase');
const {protect, authorize, authorizeAdminOrWarehouse, authorizeAdminLike, authorizeStockRead} = require('../middleware/auth');
const ordersRoute = require('./orders');
const returnsRoute = require('./returns');
const damagedRoute = require('./damagedProducts');
const { projectRef, storeRef, userRef } = require('../utils/embedRefs');
const { buildMrpRows, sortMrpRows, summarizeMrp } = require('../utils/mrpReport');
const {
  isAdminLike,
  isFinance,
  isWarehouseLike,
  isSupervisor,
} = require('../utils/roles');

router.get('/stock-summary', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('stock').get();
    let totalQuantity = 0;
    const byProduct = {};
    snapshot.docs.forEach(d => {
      const dta = d.data();
      const qty = dta.quantity || 0;
      totalQuantity += qty;
      const pid = dta.product_id;
      if (pid) byProduct[pid] = (byProduct[pid] || 0) + qty;
    });
    const byProductWithNames = {};
    for (const [pid, qty] of Object.entries(byProduct)) {
      const prodDoc = await firestore.collection('products').doc(pid).get();
      byProductWithNames[pid] = { quantity: qty, name: prodDoc.exists ? prodDoc.data().name : pid };
    }
    res.json({ success: true, data: { totalQuantity, byProduct: byProductWithNames } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/distributions', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('distributions').where('status', '==', 'validated').get();
    let docs = snapshot.docs;
    if (req.query.project) docs = docs.filter(d => d.data().project_id === req.query.project);
    if (req.query.store) docs = docs.filter(d => d.data().store_id === req.query.store);
    if (req.query.depot) docs = docs.filter(d => d.data().depot_id === req.query.depot);
    docs = docs.sort((a, b) => {
      const va = a.data().validated_at?.toMillis?.() ?? 0;
      const vb = b.data().validated_at?.toMillis?.() ?? 0;
      return vb - va;
    });
    if (req.query.product) {
      docs = docs.filter(d => {
        const products = d.data().products || [];
        return products.some(p => (p.product?.id ?? p.product) === req.query.product);
      });
    }
    const distToApi = async (doc) => {
      const data = doc.data();
      const projectDoc = await firestore.collection('projects').doc(data.project_id).get();
      const sid = data.store_id || data.depot_id;
      const storeDoc = sid ? await firestore.collection('stores').doc(sid).get() : null;
      const depotDoc = sid && (!storeDoc || !storeDoc.exists) ? await firestore.collection('depots').doc(sid).get() : null;
      const store = storeDoc?.exists ? storeDoc : depotDoc;
      const validatedByDoc = data.validated_by ? await firestore.collection('users').doc(data.validated_by).get() : null;
      return {
        id: doc.id,
        bonAlimentation: data.bon_alimentation,
        project: projectRef(projectDoc),
        store: store?.exists ? storeRef(store) : null,
        products: await Promise.all((data.products || []).map(async (p) => {
          const pid = p.product?.id ?? p.product;
          const originalId = p.original_product_id ?? p.originalProductId ?? null;
          const replacementId = p.replacement_product_id ?? p.replacementProductId ?? null;
          const isReplaced = !!(p.is_replaced ?? p.isReplaced ?? replacementId);
          const productDoc = pid ? await firestore.collection('products').doc(String(pid)).get() : null;
          const out = {
            product: {
              id: pid,
              name: productDoc?.exists ? productDoc.data().name : null,
              unit: productDoc?.exists ? (productDoc.data().unit || null) : null,
            },
            quantity: p.quantity,
            isReplaced,
            originalProductId: originalId ? String(originalId) : null,
            replacementProductId: replacementId ? String(replacementId) : null,
            replacedAt: p.replaced_at ?? p.replacedAt ?? null,
          };
          if (originalId) {
            const od = await firestore.collection('products').doc(String(originalId)).get();
            out.originalProduct = od.exists
              ? { id: od.id, name: od.data().name, unit: od.data().unit || null }
              : { id: String(originalId) };
          }
          if (replacementId) {
            const rd = await firestore.collection('products').doc(String(replacementId)).get();
            out.replacementProduct = rd.exists
              ? { id: rd.id, name: rd.data().name, unit: rd.data().unit || null }
              : { id: String(replacementId) };
          }
          if (p.replaced_by) {
            const ub = await firestore.collection('users').doc(String(p.replaced_by)).get();
            out.replacedBy = ub.exists
              ? { id: ub.id, name: ub.data().name, email: ub.data().email }
              : { id: String(p.replaced_by) };
          }
          return out;
        })),
        validatedBy: validatedByDoc?.exists ? (() => {
        const n = validatedByDoc.data().name;
        const name = (n && (String(n).toLowerCase() === 'administrator' || String(n).toLowerCase() === 'administrateur')) ? 'administrator' : n;
        return { id: validatedByDoc.id, name, email: validatedByDoc.data().email };
      })() : null,
        validatedAt: data.validated_at,
      };
    };
    const data = await Promise.all(docs.map(distToApi));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/orders', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    let q = firestore.collection('orders').orderBy('created_at', 'desc');
    if (req.query.project) q = q.where('project_id', '==', req.query.project);
    if (req.query.user) q = q.where('user_id', '==', req.query.user);
    const snapshot = await q.get();
    const data = await Promise.all(snapshot.docs.map(d => ordersRoute.orderToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/returns', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('returns').where('status', '==', 'approved').get();
    let docs = snapshot.docs;
    if (req.query.project) docs = docs.filter(d => d.data().project_id === req.query.project);
    if (req.query.user) docs = docs.filter(d => d.data().user_id === req.query.user);
    docs = docs.sort((a, b) => {
      const va = a.data().approved_at?.toMillis?.() ?? 0;
      const vb = b.data().approved_at?.toMillis?.() ?? 0;
      return vb - va;
    });
    const data = await Promise.all(docs.map(d => returnsRoute.returnToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/damaged-products', protect, authorizeAdminOrWarehouse, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('damaged_products').where('status', '==', 'approved').get();
    let docs = snapshot.docs;
    if (req.query.project) docs = docs.filter(d => d.data().project_id === req.query.project);
    if (req.query.depot) docs = docs.filter(d => d.data().depot_id === req.query.depot);
    if (req.query.product) docs = docs.filter(d => d.data().product_id === req.query.product);
    docs = docs.sort((a, b) => {
      const va = a.data().created_at?.toMillis?.() ?? 0;
      const vb = b.data().created_at?.toMillis?.() ?? 0;
      return vb - va;
    });
    const data = await Promise.all(docs.map(d => damagedRoute.damagedToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/stock-history', protect, authorizeStockRead, async (req, res) => {
  try {
    const firestore = getFirestore();
    let q = firestore.collection('stock_history').orderBy('created_at', 'desc').limit(1000);
    if (req.query.project) q = q.where('project_id', '==', req.query.project);
    if (req.query.store) q = q.where('store_id', '==', req.query.store);
    else if (req.query.depot) q = q.where('depot_id', '==', req.query.depot);
    if (req.query.product) q = q.where('product_id', '==', req.query.product);
    if (req.query.type) q = q.where('type', '==', req.query.type);
    const snapshot = await q.get();
    const data = await Promise.all(snapshot.docs.map(async (d) => {
      const r = d.data();
      const productDoc = r.product_id ? await firestore.collection('products').doc(r.product_id).get() : null;
      const sid = r.store_id || r.depot_id;
      const storeDoc = sid ? await firestore.collection('stores').doc(sid).get() : null;
      const depotDoc = sid && (!storeDoc || !storeDoc.exists) ? await firestore.collection('depots').doc(sid).get() : null;
      const s = storeDoc?.exists ? storeDoc : depotDoc;
      const projectDoc = r.project_id ? await firestore.collection('projects').doc(r.project_id).get() : null;
      const userDoc = r.user_id ? await firestore.collection('users').doc(r.user_id).get() : null;
      const productData = productDoc?.exists ? productDoc.data() : null;
      const productCreatedAt = productData?.created_at;
      const productCreatedAtStr = productCreatedAt?.toDate?.()?.toISOString?.() ?? (typeof productCreatedAt === 'string' ? productCreatedAt : null);
      return {
        id: d.id,
        product: productDoc?.exists ? { id: productDoc.id, name: productDoc.data().name, createdAt: productCreatedAtStr } : null,
        store: s?.exists ? storeRef(s) : null,
        type: r.type,
        quantity: r.quantity,
        previousQuantity: r.previous_quantity,
        newQuantity: r.new_quantity,
        project: projectRef(projectDoc),
        user: userRef(userDoc),
        reference: r.reference,
        notes: r.notes,
        createdAt: r.created_at,
        productCreatedAt: productCreatedAtStr,
      };
    }));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/stock-history/:id', protect, authorizeAdminLike, async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('stock_history').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Stock history entry not found' });
    await ref.delete();
    res.json({ success: true, message: 'Stock history entry deleted' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

function authorizeMrpAccess(req, res, next) {
  const role = req.user?.role;
  if (isAdminLike(role) || isFinance(role) || isWarehouseLike(role)) {
    return next();
  }
  return res.status(403).json({
    success: false,
    message: `User role '${role}' is not authorized to access MRP reports`,
  });
}

/**
 * GET /reports/mrp
 * Query:
 *  page, pageSize, sortBy, sortDir,
 *  search, status (in_stock|partial|purchase_required),
 *  category, warehouseId,
 *  projectIds (comma-separated), productIds (comma-separated)
 */
let _mrpCache = { at: 0, key: '', rows: null };
const MRP_CACHE_TTL_MS = 45000;

router.get('/mrp', protect, authorizeMrpAccess, async (req, res) => {
  try {
    const firestore = getFirestore();
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const pageSize = Math.min(200, Math.max(1, parseInt(req.query.pageSize, 10) || 50));
    const sortBy = req.query.sortBy || 'product';
    const sortDir = req.query.sortDir || 'asc';

    let projectIds = req.query.projectIds
      ? String(req.query.projectIds).split(',').map((s) => s.trim()).filter(Boolean)
      : [];
    if (req.query.project) projectIds.push(String(req.query.project));
    projectIds = [...new Set(projectIds)];

    // Supervisor: restrict to assigned projects
    if (isSupervisor(req.user.role)) {
      const allowed = (req.user.project_ids || []).map(String);
      if (projectIds.length === 0) {
        projectIds = allowed;
      } else {
        projectIds = projectIds.filter((id) => allowed.includes(id));
      }
      if (projectIds.length === 0) {
        return res.json({
          success: true,
          count: 0,
          page,
          pageSize,
          totalPages: 0,
          data: [],
          totals: summarizeMrp([]),
          calculatedAt: new Date().toISOString(),
        });
      }
    }

    const productIds = req.query.productIds
      ? String(req.query.productIds).split(',').map((s) => s.trim()).filter(Boolean)
      : [];

    const filterKey = JSON.stringify({
      projectIds: projectIds.slice().sort(),
      productIds: productIds.slice().sort(),
      warehouseId: req.query.warehouseId || req.query.storeId || null,
      category: req.query.category || null,
      status: req.query.status || null,
      search: req.query.search || null,
    });

    let rows;
    const now = Date.now();
    if (_mrpCache.rows && _mrpCache.key === filterKey && now - _mrpCache.at < MRP_CACHE_TTL_MS) {
      rows = _mrpCache.rows;
    } else {
      const [projectsSnap, stockSnap, ordersSnap, distSnap, productsSnap] = await Promise.all([
        firestore.collection('projects').get(),
        firestore.collection('stock').get(),
        firestore.collection('orders').where('status', '==', 'approved').get(),
        firestore.collection('distributions').get(),
        firestore.collection('products').get(),
      ]);

      const productCache = new Map();
      for (const d of productsSnap.docs) {
        productCache.set(d.id, d.data());
      }

      rows = buildMrpRows({
        projectDocs: projectsSnap.docs,
        stockDocs: stockSnap.docs,
        orderDocs: ordersSnap.docs,
        distributionDocs: distSnap.docs,
        productCache,
        filters: {
          projectIds: projectIds.length ? projectIds : null,
          productIds: productIds.length ? productIds : null,
          warehouseId: req.query.warehouseId || req.query.storeId || null,
          category: req.query.category || null,
          status: req.query.status || null,
          search: req.query.search || null,
        },
      });
      _mrpCache = { at: now, key: filterKey, rows };
    }

    rows = sortMrpRows(rows, sortBy, sortDir);
    const totals = summarizeMrp(rows);
    const totalCount = rows.length;
    const totalPages = Math.max(1, Math.ceil(totalCount / pageSize));
    const start = (page - 1) * pageSize;
    const pageRows = rows.slice(start, start + pageSize);

    res.json({
      success: true,
      count: totalCount,
      page,
      pageSize,
      totalPages,
      data: pageRows,
      totals,
      calculatedAt: new Date(_mrpCache.at || Date.now()).toISOString(),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/** Audit log for print / export */
router.post('/mrp/audit', protect, authorizeMrpAccess, async (req, res) => {
  try {
    const firestore = getFirestore();
    const { action, selectedProducts, filters } = req.body || {};
    const allowed = ['print', 'export_pdf', 'export_excel'];
    if (!allowed.includes(action)) {
      return res.status(400).json({ success: false, message: 'Invalid action' });
    }
    const ip =
      req.headers['x-forwarded-for']?.toString().split(',')[0]?.trim() ||
      req.socket?.remoteAddress ||
      null;

    await firestore.collection('report_audit').add({
      report: 'mrp',
      action,
      user_id: req.user.id,
      user_name: req.user.name,
      user_role: req.user.role,
      selected_products: selectedProducts || [],
      filters: filters || {},
      ip,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
