// Convert SQLite row (snake_case, id number) to API shape (camelCase, id string) for compatibility with Flutter app

function toId(v) {
  if (v == null) return null;
  return String(v);
}

function userRow(row, projectRow = null) {
  if (!row) return null;
  return {
    id: toId(row.id),
    name: row.name,
    email: row.email,
    role: row.role,
    project: projectRow ? projectRowToApi(projectRow) : null,
    isActive: !!row.is_active,
    createdAt: row.created_at,
  };
}

function projectRowToApi(row) {
  if (!row) return null;
  return { id: toId(row.id), name: row.name, description: row.description, status: row.status };
}

function depotRowToApi(row) {
  if (!row) return null;
  return { id: toId(row.id), name: row.name, location: row.location, description: row.description };
}

function productRowToApi(row) {
  if (!row) return null;
  return {
    id: toId(row.id),
    name: row.name,
    category: row.category,
    unit: row.unit,
    manufacturer: row.manufacturer,
    distributor: row.distributor,
    status: row.status,
  };
}

module.exports = {
  toId,
  userRow,
  projectRowToApi,
  depotRowToApi,
  productRowToApi,
};
