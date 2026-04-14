'use strict';

/**
 * Project `products` map values are either a non-negative number (legacy)
 * or `{ allowed_quantity, boq_date? }`.
 */

function parseProjectProductQty(v) {
  if (v == null) return 0;
  if (typeof v === 'number' && !Number.isNaN(v)) return Math.max(0, Math.floor(v));
  if (typeof v === 'object' && v != null && !Array.isArray(v)) {
    const q = v.quantity ?? v.allowedQuantity ?? v.allowed_quantity;
    if (q != null) return parseProjectProductQty(q);
  }
  const n = parseInt(String(v), 10);
  return Number.isNaN(n) ? 0 : Math.max(0, n);
}

/** Keep boq_date (and similar) when writing a new quantity. */
function setProjectMapQty(prevRaw, newQty) {
  const q = Math.max(0, Math.floor(newQty));
  if (typeof prevRaw === 'object' && prevRaw != null && !Array.isArray(prevRaw)) {
    const next = { ...prevRaw };
    next.allowed_quantity = q;
    if ('allowedQuantity' in next) delete next.allowedQuantity;
    if ('quantity' in next) delete next.quantity;
    return next;
  }
  return q;
}

function addProjectMapQty(prevRaw, delta) {
  const prev = parseProjectProductQty(prevRaw);
  return setProjectMapQty(prevRaw, prev + delta);
}

function extractBoqDate(raw) {
  if (typeof raw === 'object' && raw != null) {
    const b = raw.boq_date ?? raw.boqDate;
    if (b != null && String(b).trim() !== '') return String(b).trim();
  }
  return null;
}

module.exports = {
  parseProjectProductQty,
  setProjectMapQty,
  addProjectMapQty,
  extractBoqDate,
};
