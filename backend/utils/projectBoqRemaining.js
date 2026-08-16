'use strict';

const { parseProjectProductQty } = require('./projectProductsMap');

function parseProductKey(key) {
  const idx = key.indexOf(':');
  if (idx < 0) return { productId: key, color: null };
  return { productId: key.slice(0, idx), color: key.slice(idx + 1) };
}

function makeProductKey(productId, color) {
  return color ? `${productId}:${color}` : productId;
}

function parseQtyField(v) {
  if (v == null) return 0;
  if (typeof v === 'number' && !Number.isNaN(v)) return Math.max(0, Math.floor(v));
  if (typeof v === 'object' && v != null && ('quantity' in v || 'allowedQuantity' in v || 'allowed_quantity' in v)) {
    return parseQtyField(v.quantity ?? v.allowedQuantity ?? v.allowed_quantity);
  }
  const n = parseInt(String(v), 10);
  return Number.isNaN(n) ? 0 : Math.max(0, n);
}

/** Sum quantities from validated distributions for this project. */
async function loadDistributedMapsForProject(firestore, projectId) {
  const distributedByProduct = {};
  const distributedByKey = {};
  const distSnap = await firestore.collection('distributions')
    .where('project_id', '==', projectId)
    .limit(1000)
    .get();
  for (const d of distSnap.docs) {
    const distData = d.data();
    for (const p of (distData.products || [])) {
      // Attribute BOQ / distributed totals to the originally requested product when replaced.
      const pid = p.original_product_id ?? p.originalProductId ?? p.product?.id ?? p.product?._id ?? p.product;
      if (!pid) continue;
      const pColorRaw = p.original_color ?? p.originalColor ?? p.color;
      const pColor = pColorRaw ? String(pColorRaw).trim().toLowerCase() : null;
      const qty = parseQtyField(p.quantity);
      if (qty <= 0) continue;
      distributedByProduct[pid] = (distributedByProduct[pid] ?? 0) + qty;
      const key = makeProductKey(pid, pColor);
      if (key !== pid) distributedByKey[key] = (distributedByKey[key] ?? 0) + qty;
    }
  }
  return { distributedByProduct, distributedByKey };
}

/**
 * Remaining quantity still allocatable to new orders.
 * Source of truth: project `products` map (increased by admin ADD, decreased by orders).
 */
function computeRemainingBoqAllocatable({ allowedInMap }) {
  return Math.max(0, parseProjectProductQty(allowedInMap));
}

/** Split order line into project (BOQ) vs supplementary parts. */
function splitOrderQuantity(quantity, ctx) {
  const qty = Math.max(0, Math.floor(Number(quantity)) || 0);
  const remaining = computeRemainingBoqAllocatable(ctx);
  const projectQuantity = Math.min(qty, remaining);
  const supplementaryQuantity = Math.max(0, qty - projectQuantity);
  return {
    projectQuantity,
    supplementaryQuantity,
    supplementary: supplementaryQuantity > 0,
    remainingBoq: remaining,
  };
}

module.exports = {
  parseProductKey,
  makeProductKey,
  parseQtyField,
  loadDistributedMapsForProject,
  computeRemainingBoqAllocatable,
  splitOrderQuantity,
};
