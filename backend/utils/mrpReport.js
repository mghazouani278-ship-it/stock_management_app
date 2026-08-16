const { parseProjectProductQty } = require('./projectProductsMap');
const { makeProductKey, parseProductKey } = require('./projectBoqRemaining');

/**
 * Build consolidated MRP rows from Firestore snapshots (in-memory aggregation).
 * Key = productId or productId:color
 */

function parseCategories(productData) {
  const c = productData?.category;
  if (Array.isArray(c)) return c.map(String).filter(Boolean);
  if (c == null || c === '') return [];
  return [String(c)];
}

function statusFrom(available, remaining) {
  if (remaining <= 0 || available >= remaining) return 'in_stock';
  if (available > 0) return 'partial';
  return 'purchase_required';
}

/**
 * @param {object} opts
 * @param {FirebaseFirestore.QueryDocumentSnapshot[]} opts.projectDocs
 * @param {FirebaseFirestore.QueryDocumentSnapshot[]} opts.stockDocs
 * @param {FirebaseFirestore.QueryDocumentSnapshot[]} opts.orderDocs approved open orders
 * @param {FirebaseFirestore.QueryDocumentSnapshot[]} opts.distributionDocs
 * @param {Map<string, object>} opts.productCache id -> product data
 * @param {object} opts.filters
 */
function buildMrpRows({
  projectDocs,
  stockDocs,
  orderDocs,
  distributionDocs,
  productCache,
  filters = {},
}) {
  const projectFilter = filters.projectIds?.length
    ? new Set(filters.projectIds.map(String))
    : null;
  const warehouseFilter = filters.warehouseId ? String(filters.warehouseId) : null;
  const categoryFilter = filters.category
    ? String(filters.category).toLowerCase()
    : null;
  const productFilter = filters.productIds?.length
    ? new Set(filters.productIds.map(String))
    : null;
  const statusFilter = filters.status || null;
  const search = (filters.search || '').toString().trim().toLowerCase();

  // distributedByKey[projectId][key] = qty
  const distributedByProject = {};
  for (const doc of distributionDocs) {
    const d = doc.data();
    const pid = String(d.project_id || '');
    if (!pid) continue;
    if (projectFilter && !projectFilter.has(pid)) continue;
    if (!distributedByProject[pid]) distributedByProject[pid] = {};
    for (const item of d.products || []) {
      const productId = item.product?.id ?? item.product?._id ?? item.product;
      if (!productId) continue;
      const color = (item.variant ?? item.color)
        ? String(item.variant ?? item.color).trim().toLowerCase()
        : null;
      const key = makeProductKey(String(productId), color);
      const qty = Number(item.quantity) || 0;
      distributedByProject[pid][key] = (distributedByProject[pid][key] || 0) + qty;
    }
  }

  // reservedByKey[key] = qty from approved orders not completed
  const reservedByKey = {};
  for (const doc of orderDocs) {
    const d = doc.data();
    const st = d.status || '';
    if (st !== 'approved') continue;
    if (projectFilter && !projectFilter.has(String(d.project_id))) continue;
    for (const item of d.products || []) {
      const productId = item.product?.id ?? item.product?._id ?? item.product;
      if (!productId) continue;
      const color = (item.variant ?? item.color)
        ? String(item.variant ?? item.color).trim().toLowerCase()
        : null;
      const key = makeProductKey(String(productId), color);
      const qty = Number(item.quantity) || 0;
      reservedByKey[key] = (reservedByKey[key] || 0) + qty;
    }
  }

  // stockByKey[key] = qty
  const stockByKey = {};
  const stockUpdatedAt = {};
  for (const doc of stockDocs) {
    const d = doc.data();
    if (warehouseFilter) {
      const sid = String(d.store_id || d.depot_id || '');
      if (sid !== warehouseFilter) continue;
    }
    const productId = d.product_id;
    if (!productId) continue;
    let color = d.variant || d.color || null;
    if (!color && doc.id.includes('_')) {
      // doc id: productId_storeId_variant
      const parts = doc.id.split('_');
      if (parts.length >= 3) color = parts.slice(2).join('_') || null;
    }
    if (color) color = String(color).trim().toLowerCase();
    const key = makeProductKey(String(productId), color || null);
    const qty = Number(d.quantity) || 0;
    stockByKey[key] = (stockByKey[key] || 0) + qty;
    const updated = d.updated_at?.toDate?.()?.toISOString?.() || d.updated_at || null;
    if (updated) {
      if (!stockUpdatedAt[key] || String(updated) > String(stockUpdatedAt[key])) {
        stockUpdatedAt[key] = updated;
      }
    }
  }

  // Aggregate required per key across projects
  /** @type {Map<string, { perProject: object, totalRequired: number }>} */
  const required = new Map();

  for (const doc of projectDocs) {
    const projectId = doc.id;
    if (projectFilter && !projectFilter.has(projectId)) continue;
    const pdata = doc.data();
    const projectName = pdata.name || projectId;
    const projectNameAr = pdata.name_ar || null;
    const productsMap = pdata.products || {};
    const requestedMap = pdata.products_requested || productsMap;
    const distMap = distributedByProject[projectId] || {};

    const keys = new Set([...Object.keys(requestedMap), ...Object.keys(productsMap)]);
    for (const key of keys) {
      const { productId } = parseProductKey(key);
      if (productFilter && !productFilter.has(String(productId))) continue;

      const requested = parseProjectProductQty(requestedMap[key] ?? productsMap[key] ?? 0);
      if (requested <= 0 && parseProjectProductQty(productsMap[key] ?? 0) <= 0) continue;

      if (!required.has(key)) {
        required.set(key, { perProject: {}, totalRequired: 0 });
      }
      const row = required.get(key);
      row.perProject[projectId] = {
        projectId,
        projectName,
        projectNameAr,
        required: requested,
        distributed: distMap[key] || 0,
        remaining: Math.max(0, requested - (distMap[key] || 0)),
      };
      row.totalRequired += requested;
    }
  }

  // Also include stock-only keys if they appear in stock (optional — skip to keep MRP demand-focused)
  const nowIso = new Date().toISOString();
  const rows = [];

  for (const [key, agg] of required.entries()) {
    const { productId, color } = parseProductKey(key);
    const prod = productCache.get(String(productId)) || {};
    const categories = parseCategories(prod);
    if (categoryFilter) {
      const ok = categories.some((c) => c.toLowerCase().includes(categoryFilter));
      if (!ok) continue;
    }

    const name = prod.name || productId;
    const sku = prod.sku || prod.code || productId;
    const unit = prod.unit || 'pcs';

    if (search) {
      const hay = `${name} ${sku} ${categories.join(' ')} ${color || ''}`.toLowerCase();
      if (!hay.includes(search)) continue;
    }

    let remainingToSupply = 0;
    for (const p of Object.values(agg.perProject)) {
      remainingToSupply += p.remaining;
    }

    const reserved = reservedByKey[key] || 0;
    // Also sum reserved without color variant if stock is aggregated — keep key-exact
    const warehouseStock = stockByKey[key] || 0;
    const availableStock = Math.max(0, warehouseStock - reserved);
    const qtyToPurchase = Math.max(0, remainingToSupply - availableStock);
    const purchaseStatus = statusFrom(availableStock, remainingToSupply);

    if (statusFilter && purchaseStatus !== statusFilter) continue;

    rows.push({
      key,
      productId,
      product: name,
      productNameAr: prod.name_ar || null,
      sku: String(sku),
      unit: String(unit),
      color: color || null,
      category: categories,
      requiredPerProject: Object.values(agg.perProject),
      totalRequired: agg.totalRequired,
      reservedQuantity: reserved,
      remainingQuantity: remainingToSupply,
      warehouseStock,
      availableStock,
      quantityToPurchase: qtyToPurchase,
      purchaseStatus,
      lastUpdated: stockUpdatedAt[key] || nowIso,
    });
  }

  return rows;
}

function sortMrpRows(rows, sortBy, sortDir) {
  const dir = sortDir === 'desc' ? -1 : 1;
  const key = sortBy || 'product';
  const sorted = [...rows];
  sorted.sort((a, b) => {
    let va;
    let vb;
    switch (key) {
      case 'totalRequired':
      case 'warehouseStock':
      case 'quantityToPurchase':
      case 'remainingQuantity':
      case 'availableStock':
      case 'reservedQuantity':
        va = Number(a[key]) || 0;
        vb = Number(b[key]) || 0;
        break;
      case 'purchaseStatus':
      case 'status':
        va = a.purchaseStatus || '';
        vb = b.purchaseStatus || '';
        break;
      case 'sku':
        va = a.sku || '';
        vb = b.sku || '';
        break;
      default:
        va = (a.product || '').toLowerCase();
        vb = (b.product || '').toLowerCase();
    }
    if (va < vb) return -1 * dir;
    if (va > vb) return 1 * dir;
    return 0;
  });
  return sorted;
}

function summarizeMrp(rows) {
  return {
    totalProducts: rows.length,
    totalRequired: rows.reduce((s, r) => s + (r.totalRequired || 0), 0),
    totalReserved: rows.reduce((s, r) => s + (r.reservedQuantity || 0), 0),
    totalRemaining: rows.reduce((s, r) => s + (r.remainingQuantity || 0), 0),
    totalWarehouseStock: rows.reduce((s, r) => s + (r.warehouseStock || 0), 0),
    totalAvailableStock: rows.reduce((s, r) => s + (r.availableStock || 0), 0),
    totalQuantityToPurchase: rows.reduce((s, r) => s + (r.quantityToPurchase || 0), 0),
  };
}

module.exports = {
  buildMrpRows,
  sortMrpRows,
  summarizeMrp,
  statusFrom,
};
