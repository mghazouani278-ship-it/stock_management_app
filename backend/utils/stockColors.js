/**
 * Firestore document IDs cannot contain "/" (path separators).
 * Product **variant** labels (e.g. "200 gm / m2") must be encoded for stock collection IDs only.
 * The human-readable variant is stored in stock fields `variant` (and legacy `color`).
 *
 * Stock doc id (variant line): `productId + '_' + storeId + '_' + variantSegmentForStockDocId(label)`.
 * Must stay in sync with mobile `stock.dart` / `_variantSegmentForStockDocId` and GET `stockToApi`.
 */
function variantSegmentForStockDocId(variantLabel) {
  if (variantLabel == null || variantLabel === '') return '';
  let s = String(variantLabel).trim().toLowerCase();
  if (!s) return '';
  return s
    .replace(/\//g, '_')
    .replace(/\s+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');
}

module.exports = { variantSegmentForStockDocId };
