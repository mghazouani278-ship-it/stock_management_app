/// Role helpers mirroring backend/utils/roles.js

String normalizeRole(String? role) {
  var r = (role ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  if (r == 'warehouseuser') return 'warehouse_user';
  return r;
}

bool isWarehouseLike(String? role) {
  final r = normalizeRole(role);
  return r == 'warehouse_user' || r == 'warehouse' || r.startsWith('warehouse_');
}

bool isAdmin(String? role) => normalizeRole(role) == 'admin';

bool isManager(String? role) => normalizeRole(role) == 'manager';

bool isAdminLike(String? role) {
  final r = normalizeRole(role);
  return r == 'admin' || r == 'manager';
}

bool isSupervisor(String? role) => normalizeRole(role) == 'supervisor';

bool isFinance(String? role) => normalizeRole(role) == 'finance';

bool isUserRole(String? role) => normalizeRole(role) == 'user';

bool roleNeedsProjects(String? role) {
  final r = normalizeRole(role);
  return r == 'user' || r == 'supervisor';
}
