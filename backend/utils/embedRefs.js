/** Embedded { id, name, nameAr } for API responses (Firestore snake_case name_ar). */
function projectRef(doc) {
  if (!doc || !doc.exists) return null;
  const d = doc.data();
  return { id: doc.id, name: d.name, nameAr: d.name_ar || null };
}

function storeRef(doc) {
  if (!doc || !doc.exists) return null;
  const d = doc.data();
  return { id: doc.id, name: d.name, nameAr: d.name_ar || null };
}

/** Embedded user for API responses (Firestore `name_ar` → `nameAr`). */
function userRef(doc) {
  if (!doc || !doc.exists) return null;
  const d = doc.data();
  return { id: doc.id, name: d.name, nameAr: d.name_ar || null, email: d.email };
}

module.exports = { projectRef, storeRef, userRef };
