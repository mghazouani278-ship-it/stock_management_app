const { admin } = require('../firebase');

/**
 * Append an audit entry to an order document (history array).
 * @param {FirebaseFirestore.DocumentReference} orderRef
 * @param {object} entry
 */
async function appendOrderAudit(orderRef, entry) {
  const payload = {
    action: entry.action || 'update',
    fromStatus: entry.fromStatus ?? null,
    toStatus: entry.toStatus ?? null,
    actorId: entry.actorId || null,
    actorName: entry.actorName || null,
    actorRole: entry.actorRole || null,
    note: entry.note || null,
    changes: entry.changes || null,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  await orderRef.update({
    history: admin.firestore.FieldValue.arrayUnion({
      ...payload,
      created_at: new Date().toISOString(),
    }),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function productLinesSnapshot(products) {
  return (products || []).map((p) => ({
    product: p.product?.id ?? p.product?._id ?? p.product,
    quantity: p.quantity,
    color: p.variant ?? p.color ?? null,
    supplementary: !!p.supplementary,
  }));
}

module.exports = {
  appendOrderAudit,
  productLinesSnapshot,
};
