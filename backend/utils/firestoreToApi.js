function toApi(doc) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const out = { id: doc.id };
  for (const [k, v] of Object.entries(data)) {
    if (v && typeof v.toDate === 'function') {
      out[k] = v.toDate().toISOString();
    } else {
      out[k] = v;
    }
  }
  return out;
}

function snapshotToApi(doc) {
  return toApi(doc);
}

module.exports = { toApi, snapshotToApi };
