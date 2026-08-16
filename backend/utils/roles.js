/** Role helpers for Egypt Grid workflow */

function normalizeRole(role) {
  const r = (role || '').toLowerCase().replace(/\s+/g, '_');
  if (r === 'warehouseuser') return 'warehouse_user';
  return r;
}

function isWarehouseLike(role) {
  const r = normalizeRole(role);
  return r === 'warehouse_user' || r === 'warehouse' || r.startsWith('warehouse_');
}

function isAdmin(role) {
  return normalizeRole(role) === 'admin';
}

function isManager(role) {
  return normalizeRole(role) === 'manager';
}

/** Admin or Manager — full system access (Manager = same pages as Admin) */
function isAdminLike(role) {
  const r = normalizeRole(role);
  return r === 'admin' || r === 'manager';
}

function isSupervisor(role) {
  return normalizeRole(role) === 'supervisor';
}

function isFinance(role) {
  return normalizeRole(role) === 'finance';
}

function isUser(role) {
  return normalizeRole(role) === 'user';
}

/** Roles that may manage users/projects/products like admin */
function canManageSystem(role) {
  return isAdminLike(role);
}

/** Roles that see all projects (not supervisors — they use assigned project_ids) */
function canViewAllProjects(role) {
  return isAdminLike(role) || isWarehouseLike(role);
}

const VALID_ROLES = [
  'admin',
  'manager',
  'supervisor',
  'user',
  'warehouse_user',
  'finance',
];

/**
 * Order workflow:
 * pending → (supervisor) → pending_admin | returned
 * returned → (user resubmit) → pending
 * pending_admin → (admin edits) → pending_manager
 * pending_manager → (manager) → approved | cancelled
 * approved → (warehouse) → completed
 */
const ORDER_STATUSES = [
  'pending',
  'returned',
  'pending_admin',
  'pending_manager',
  'approved',
  'cancelled',
  'rejected', // legacy
  'completed',
];

/** Migrate legacy statuses toward the new workflow */
function migrateOrderStatus(status) {
  const s = status || 'pending';
  if (s === 'rejected') return 'cancelled';
  return s;
}

/**
 * Allowed transitions: { fromStatus: { toStatus: [roles] } }
 */
const ORDER_TRANSITIONS = {
  pending: {
    pending_admin: ['supervisor'],
    returned: ['supervisor'],
  },
  returned: {
    pending: ['user'], // user resubmits
  },
  pending_admin: {
    pending_manager: ['admin', 'manager'], // admin edits then sends to manager; manager may also forward
  },
  pending_manager: {
    approved: ['manager'],
    cancelled: ['manager'],
  },
  // Legacy: old pending→approved was admin; after migrate pending stays pending.
  // Keep rejected→cancelled handled via migrate.
};

function canTransitionOrder(role, fromStatus, toStatus) {
  const from = migrateOrderStatus(fromStatus);
  const to = migrateOrderStatus(toStatus);
  const r = normalizeRole(role);
  const allowed = ORDER_TRANSITIONS[from]?.[to];
  if (!allowed) return false;
  return allowed.includes(r) || (r === 'warehouse_user' && false);
}

/** Normalize project id list from user doc */
function getUserProjectIds(userData) {
  if (!userData) return [];
  const ids = [];
  if (Array.isArray(userData.project_ids)) {
    for (const id of userData.project_ids) {
      if (id) ids.push(String(id));
    }
  }
  if (userData.project_id) {
    const pid = String(userData.project_id);
    if (!ids.includes(pid)) ids.push(pid);
  }
  return ids;
}

function userHasProjectAccess(userDataOrReqUser, projectId) {
  if (!projectId) return false;
  const pid = String(projectId);
  if (userDataOrReqUser.project_ids && Array.isArray(userDataOrReqUser.project_ids)) {
    if (userDataOrReqUser.project_ids.map(String).includes(pid)) return true;
  }
  if (userDataOrReqUser.project_id && String(userDataOrReqUser.project_id) === pid) return true;
  if (userDataOrReqUser.project && String(userDataOrReqUser.project.id) === pid) return true;
  return false;
}

module.exports = {
  normalizeRole,
  isWarehouseLike,
  isAdmin,
  isManager,
  isAdminLike,
  isSupervisor,
  isFinance,
  isUser,
  canManageSystem,
  canViewAllProjects,
  VALID_ROLES,
  ORDER_STATUSES,
  ORDER_TRANSITIONS,
  migrateOrderStatus,
  canTransitionOrder,
  getUserProjectIds,
  userHasProjectAccess,
};
