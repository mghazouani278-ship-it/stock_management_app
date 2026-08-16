const jwt = require('jsonwebtoken');
const { getFirestore } = require('../firebase');
const { normalizeUserDisplayName } = require('../utils/userDisplayName');
const {
  normalizeRole,
  isWarehouseLike,
  isAdminLike,
  isFinance,
  isSupervisor,
  getUserProjectIds,
  userHasProjectAccess,
} = require('../utils/roles');

async function loadProjectsForIds(firestore, projectIds) {
  if (!projectIds.length) return [];
  const snaps = await Promise.all(
    projectIds.map((pid) => firestore.collection('projects').doc(pid).get())
  );
  const projects = [];
  for (const projectDoc of snaps) {
    if (!projectDoc.exists) continue;
    const pData = projectDoc.data();
    const productsMap = pData.products || {};
    // Keep product ids only — enough for access checks; avoid heavy work on every request.
    const projectProducts = Object.keys(productsMap).map((key) => {
      const productId = String(key).includes(':') ? String(key).split(':')[0] : String(key);
      return {
        product: { id: productId },
        allowedQuantity: productsMap[key],
      };
    });
    projects.push({
      id: projectDoc.id,
      name: pData.name,
      nameAr: pData.name_ar || null,
      description: pData.description,
      status: pData.status,
      projectOwner: pData.project_owner || null,
      projectOwnerAr: pData.project_owner_ar || null,
      boqCreationDate: pData.boq_creation_date || null,
      products: projectProducts,
    });
  }
  return projects;
}

exports.protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({
      success: false,
      message: 'Not authorized to access this route',
    });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const firestore = getFirestore();
    const userDoc = await firestore.collection('users').doc(decoded.id).get();
    if (!userDoc.exists) {
      return res.status(401).json({
        success: false,
        message: 'User not found',
      });
    }

    const userData = userDoc.data();
    const isActive = userData.is_active !== false;
    const projectIds = getUserProjectIds(userData);
    const projects = await loadProjectsForIds(firestore, projectIds);
    const primaryProject = projects[0] || null;

    req.user = {
      id: userDoc.id,
      name: normalizeUserDisplayName(userData.name),
      nameAr: userData.name_ar || null,
      email: userData.email,
      role: userData.role,
      isActive,
      project: primaryProject,
      project_id: primaryProject?.id || userData.project_id || null,
      project_ids: projectIds,
      projects,
    };

    if (!req.user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'User account is deactivated',
      });
    }

    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Not authorized to access this route',
    });
  }
};

exports.authorize = (...roles) => {
  return (req, res, next) => {
    const userRole = normalizeRole(req.user?.role);
    const normalizedRoles = roles.map((r) => normalizeRole(r));
    // Expanding 'admin' alone does not include manager — use authorizeAdminLike for that.
    if (!normalizedRoles.includes(userRole)) {
      // Allow warehouse aliases when warehouse_user is listed
      if (normalizedRoles.includes('warehouse_user') && isWarehouseLike(req.user?.role)) {
        return next();
      }
      return res.status(403).json({
        success: false,
        message: `User role '${req.user.role}' is not authorized to access this route`,
      });
    }
    next();
  };
};

/** Admin or Manager — system management */
exports.authorizeAdminLike = (req, res, next) => {
  if (isAdminLike(req.user?.role)) return next();
  return res.status(403).json({
    success: false,
    message: `User role '${req.user?.role}' is not authorized to access this route`,
  });
};

/** Admin, Manager, or Warehouse */
exports.authorizeAdminOrWarehouse = (req, res, next) => {
  if (isAdminLike(req.user?.role) || isWarehouseLike(req.user?.role)) return next();
  return res.status(403).json({
    success: false,
    message: `User role '${req.user?.role}' is not authorized to access this route`,
  });
};

/** Admin, Manager, Warehouse, or Supervisor (read reports) */
exports.authorizeAdminWarehouseOrSupervisor = (req, res, next) => {
  if (
    isAdminLike(req.user?.role) ||
    isWarehouseLike(req.user?.role) ||
    isSupervisor(req.user?.role)
  ) {
    return next();
  }
  return res.status(403).json({
    success: false,
    message: `User role '${req.user?.role}' is not authorized to access this route`,
  });
};

/** Stock read: admin-like, warehouse, finance, or supervisor (MRP filters) */
exports.authorizeStockRead = (req, res, next) => {
  if (
    isAdminLike(req.user?.role) ||
    isWarehouseLike(req.user?.role) ||
    isFinance(req.user?.role) ||
    isSupervisor(req.user?.role)
  ) {
    return next();
  }
  return res.status(403).json({
    success: false,
    message: `User role '${req.user?.role}' is not authorized to access this route`,
  });
};

exports.checkProjectAccess = async (req, res, next) => {
  const projectId = req.params.id || req.params.projectId;

  if (isAdminLike(req.user?.role)) return next();
  if (isWarehouseLike(req.user?.role)) return next();
  if (isSupervisor(req.user?.role) && userHasProjectAccess(req.user, projectId)) return next();
  if (userHasProjectAccess(req.user, projectId)) return next();

  return res.status(403).json({
    success: false,
    message: 'You do not have access to this project',
  });
};
