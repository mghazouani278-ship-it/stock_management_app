'use strict';

const { variantSegmentForStockDocId } = require('./stockColors');

function normalizeColor(c) {
  return c ? String(c).trim().toLowerCase() : '';
}

function stockLineMatchesColor(data, orderColor) {
  const sc = normalizeColor(data.variant ?? data.color);
  const oc = normalizeColor(orderColor);
  if (oc === sc) return true;
  return !oc && !sc;
}

/**
 * Find the stock row (and thus store) for a product line.
 * Prefers the row with the highest quantity when several stores match.
 */
async function findStockStoreForProductLine(firestore, productId, color) {
  if (!productId) return null;
  const snap = await firestore.collection('stock').where('product_id', '==', productId).get();
  let best = null;
  for (const doc of snap.docs) {
    const d = doc.data();
    if (!stockLineMatchesColor(d, color)) continue;
    const storeId = d.store_id || d.depot_id;
    if (!storeId) continue;
    const qty = Number(d.quantity) || 0;
    if (!best || qty > best.availableQuantity) {
      best = {
        storeId,
        availableQuantity: qty,
        stockDocId: doc.id,
      };
    }
  }
  if (!best) return null;
  const storeDoc = await firestore.collection('stores').doc(best.storeId).get();
  if (storeDoc.exists) {
    best.storeName = storeDoc.data().name || best.storeId;
    return best;
  }
  const depotDoc = await firestore.collection('depots').doc(best.storeId).get();
  best.storeName = depotDoc.exists ? depotDoc.data().name : best.storeId;
  return best;
}

function makeProductKey(productId, color) {
  const c = normalizeColor(color);
  return c ? `${productId}:${c}` : productId;
}

function buildStoreByProductKey(orderData, fallbackStoreId) {
  const map = new Map();
  const rows = orderData.approved_product_stores || [];
  for (const row of rows) {
    const pid = row.product_id ?? row.product?.id ?? row.product?._id ?? row.product;
    if (!pid) continue;
    const sid = row.store_id ?? row.store;
    if (!sid) continue;
    map.set(makeProductKey(pid, row.color ?? row.variant), sid);
  }
  if (map.size === 0 && fallbackStoreId) {
    for (const item of orderData.products || []) {
      const pid = item.product?.id ?? item.product?._id ?? item.product;
      if (!pid) continue;
      const color = item.variant ?? item.color;
      map.set(makeProductKey(pid, color), fallbackStoreId);
    }
  }
  return map;
}

module.exports = {
  findStockStoreForProductLine,
  makeProductKey,
  buildStoreByProductKey,
  variantSegmentForStockDocId,
};
