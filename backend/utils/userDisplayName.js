/** Normalize user display names for API responses (legacy French → English). */
function normalizeUserDisplayName(name) {
  if (name == null || typeof name !== 'string') return name;
  const t = name.trim();
  if (t.toLowerCase() === 'administrateur') return 'Administrator';
  return name;
}

module.exports = { normalizeUserDisplayName };
