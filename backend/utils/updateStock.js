const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const { variantSegmentForStockDocId } = require('./stockColors');

/**
 * Update stock quantity and create history record (Firestore)
 * @param {string} productId - Product ID
 * @param {string} storeId - Store/Depot ID
 * @param {number} quantityChange - Positive for increase, negative for decrease
 * @param {string} type - Type of change: 'distribution', 'return', 'damaged', 'manual_update', 'initial', 'order'
 * @param {object} metadata - Additional data (project, user, reference, notes, variant, color legacy)
 */
const updateStock = async (productId, storeId, quantityChange, type, metadata = {}) => {
  const firestore = getFirestore();
  const rawVariant = metadata.variant ?? metadata.color;
  const variantLabel =
    rawVariant && String(rawVariant).trim() ? String(rawVariant).trim().toLowerCase() : null;
  const seg = variantLabel ? variantSegmentForStockDocId(variantLabel) : '';
  const stockColl = firestore.collection('stock');
  const stockId = variantLabel && seg ? `${productId}_${storeId}_${seg}` : `${productId}_${storeId}`;
  const altId = variantLabel && seg ? `${storeId}_${productId}_${seg}` : `${storeId}_${productId}`;

  // Resolve an existing stock row first (primary id, legacy alt id, then query fallback)
  // so distribution deductions always hit the real stock document.
  let ref = stockColl.doc(stockId);
  let doc = await ref.get();
  if (!doc.exists) {
    const altRef = stockColl.doc(altId);
    const altDoc = await altRef.get();
    if (altDoc.exists) {
      ref = altRef;
      doc = altDoc;
    }
  }
  if (!doc.exists) {
    const snapshot = await stockColl.where('product_id', '==', productId).get();
    for (const d of snapshot.docs) {
      const data = d.data();
      const sid = data.store_id || data.depot_id;
      if (sid !== storeId) continue;
      const c = data.variant ?? data.color;
      const cNorm = c && String(c).trim() ? String(c).trim().toLowerCase() : null;
      if ((variantLabel ?? null) == cNorm) {
        ref = d.ref;
        doc = d;
        break;
      }
      if (!variantLabel && !cNorm) {
        ref = d.ref;
        doc = d;
        break;
      }
    }
  }

  let previousQuantity = 0;
  if (doc.exists) {
    previousQuantity = doc.data().quantity || 0;
  } else {
    const initData = {
      product_id: productId,
      store_id: storeId,
      depot_id: storeId,
      quantity: 0,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (variantLabel) {
      initData.variant = variantLabel;
      initData.color = variantLabel;
    }
    await ref.set(initData);
  }

  const newQuantity = Math.max(0, previousQuantity + quantityChange);

  await ref.update({
    quantity: newQuantity,
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  const hist = {
    product_id: productId,
    store_id: storeId,
    depot_id: storeId,
    type,
    quantity: Math.abs(quantityChange),
    previous_quantity: previousQuantity,
    new_quantity: newQuantity,
    project_id: metadata.project || null,
    user_id: metadata.user || null,
    reference: metadata.reference || null,
    notes: metadata.notes || null,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (variantLabel) {
    hist.variant = variantLabel;
    hist.color = variantLabel;
  }
  await firestore.collection('stock_history').add(hist);

  const updated = await ref.get();
  return {
    stock: { id: updated.id, ...updated.data() },
    history: {},
  };
};

module.exports = updateStock;
