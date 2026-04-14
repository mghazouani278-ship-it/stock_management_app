const jwt = require('jsonwebtoken');
const { getFirestore } = require('../firebase');
const { normalizeUserDisplayName } = require('../utils/userDisplayName');

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

    let project = null;
    let projectProducts = [];
    if (userData.project_id) {
      const projectDoc = await firestore.collection('projects').doc(userData.project_id).get();
      if (projectDoc.exists) {
        const pData = projectDoc.data();
        project = {
          id: projectDoc.id,
          name: pData.name,
          nameAr: pData.name_ar || null,
          description: pData.description,
          status: pData.status,
          projectOwner: pData.project_owner || null,
          projectOwnerAr: pData.project_owner_ar || null,
        };
        const productsMap = pData.products || {};
        projectProducts = Object.entries(productsMap).map(([productId, allowedQuantity]) => ({
          product: { id: productId },
          allowedQuantity,
        }));
        project.products = projectProducts;
      }
    }

    req.user = {
      id: userDoc.id,
      name: normalizeUserDisplayName(userData.name),
      nameAr: userData.name_ar || null,
      email: userData.email,
      role: userData.role,
      isActive,
      project,
      project_id: userData.project_id || null,
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
    const userRole = (req.user?.role || '').toLowerCase().replace(/\s+/g, '_');
    const normalizedRoles = roles.map((r) => String(r).toLowerCase().replace(/\s+/g, '_'));
    if (!normalizedRoles.includes(userRole)) {
      return res.status(403).json({
        success: false,
        message: `User role '${req.user.role}' is not authorized to access this route`,
      });
    }
    next();
  };
};

/** Normalize role: handle warehouse_user, warehouse, warehouseuser, etc. */
function normalizeRoleForWarehouse(role) {
  const r = (role || '').toLowerCase().replace(/\s+/g, '_');
  if (r === 'warehouseuser') return 'warehouse_user';
  return r;
}

/** Admin or Warehouse User (for stock, distributions, projects view) */
exports.authorizeAdminOrWarehouse = (req, res, next) => {
  const role = normalizeRoleForWarehouse(req.user?.role);
  const allowed = ['admin', 'warehouse_user', 'warehouse'];
  if (allowed.includes(role)) return next();
  return res.status(403).json({
    success: false,
    message: `User role '${req.user?.role}' is not authorized to access this route`,
  });
};

exports.checkProjectAccess = async (req, res, next) => {
  const projectId = req.params.id || req.params.projectId;
  const role = normalizeRoleForWarehouse(req.user?.role);

  if (role === 'admin') return next();
  if (role === 'warehouse_user' || role === 'warehouse') return next();
  if (req.user.project_id && String(req.user.project_id) === projectId) return next();
  if (req.user.project && String(req.user.project.id) === projectId) return next();

  return res.status(403).json({
    success: false,
    message: 'You do not have access to this project',
  });
};
