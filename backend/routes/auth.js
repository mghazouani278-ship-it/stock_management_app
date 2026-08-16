const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const bcrypt = require('bcryptjs');
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const generateToken = require('../utils/generateToken');
const { protect, authorizeAdminLike } = require('../middleware/auth');
const { normalizeUserDisplayName } = require('../utils/userDisplayName');
const { VALID_ROLES, normalizeRole, getUserProjectIds } = require('../utils/roles');

function projectToApi(data, id) {
  if (!data) return null;
  return {
    id,
    name: data.name,
    nameAr: data.name_ar || null,
    description: data.description,
    status: data.status,
    projectOwner: data.project_owner || null,
    projectOwnerAr: data.project_owner_ar || null,
    boqCreationDate: data.boq_creation_date || null,
  };
}

router.post('/register', protect, authorizeAdminLike, async (req, res) => {
  const { name, email, password, role, projectId, projectIds, nameAr } = req.body;

  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const nr = normalizeRole(role || 'user');
    if (!VALID_ROLES.includes(nr) && !nr.startsWith('warehouse')) {
      return res.status(400).json({ success: false, message: `Invalid role: ${role}` });
    }

    const firestore = getFirestore();
    const existing = await firestore.collection('users').where('email', '==', email.toLowerCase().trim()).limit(1).get();
    if (!existing.empty) {
      return res.status(400).json({ success: false, message: 'User already exists' });
    }

    const hashed = await bcrypt.hash(password, 10);
    let project_ids = [];
    if (nr === 'user' || nr === 'supervisor') {
      if (Array.isArray(projectIds)) project_ids = projectIds.map(String).filter(Boolean);
      else if (projectId) project_ids = [String(projectId)];
    }
    const project_id = project_ids[0] || null;
    const nameArTrim = (nameAr != null ? String(nameAr).trim() : '') || '';
    const ref = await firestore.collection('users').add({
      name: name.trim(),
      name_ar: nameArTrim || null,
      email: email.toLowerCase().trim(),
      password: hashed,
      role: nr,
      project_id,
      project_ids,
      is_active: true,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    const newUserDoc = await ref.get();
    const newUserData = newUserDoc.data();
    const projects = [];
    for (const pid of getUserProjectIds(newUserData)) {
      const projectDoc = await firestore.collection('projects').doc(pid).get();
      if (projectDoc.exists) projects.push(projectToApi(projectDoc.data(), projectDoc.id));
    }

    res.status(201).json({
      success: true,
      data: {
        id: newUserDoc.id,
        name: normalizeUserDisplayName(newUserData.name),
        nameAr: newUserData.name_ar || null,
        email: newUserData.email,
        role: newUserData.role,
        project: projects[0] || null,
        projects,
        projectIds: getUserProjectIds(newUserData),
        isActive: true,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.post(
  '/login',
  [
    body('email').isEmail().withMessage('Please provide a valid email'),
    body('password').notEmpty().withMessage('Please provide a password'),
  ],
  async (req, res) => {
    const { email, password } = req.body;

    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ success: false, errors: errors.array() });
      }

      const firestore = getFirestore();
      const snapshot = await firestore.collection('users').where('email', '==', email.toLowerCase().trim()).limit(1).get();
      if (snapshot.empty) {
        return res.status(401).json({ success: false, message: 'Invalid credentials' });
      }
      const userDoc = snapshot.docs[0];
      const row = userDoc.data();
      if (row.is_active === false) {
        return res.status(401).json({ success: false, message: 'Your account has been deactivated' });
      }

      const isMatch = await bcrypt.compare(password, row.password);
      if (!isMatch) {
        return res.status(401).json({ success: false, message: 'Invalid credentials' });
      }

      let projects = [];
      for (const pid of getUserProjectIds(row)) {
        const projectDoc = await firestore.collection('projects').doc(pid).get();
        if (projectDoc.exists) {
          projects.push(projectToApi(projectDoc.data(), projectDoc.id));
        }
      }

      const token = generateToken(userDoc.id);
      res.json({
        success: true,
        token,
        data: {
          id: userDoc.id,
          name: normalizeUserDisplayName(row.name),
          nameAr: row.name_ar || null,
          email: row.email,
          role: row.role,
          project: projects[0] || null,
          projects,
          projectIds: getUserProjectIds(row),
          isActive: row.is_active !== false,
        },
      });
    } catch (error) {
      const msg = error.message || String(error);
      if (msg.includes('RESOURCE_EXHAUSTED') || msg.includes('Quota exceeded')) {
        return res.status(503).json({
          success: false,
          message:
            'Database quota exceeded (Firebase). Check Google Cloud billing / Firestore limits or try again later.',
        });
      }
      res.status(500).json({ success: false, message: msg });
    }
  }
);

router.get('/me', protect, async (req, res) => {
  try {
    const projects = (req.user.projects || []).map((p) => ({
      id: p.id,
      name: p.name,
      nameAr: p.nameAr ?? null,
      description: p.description,
      status: p.status,
      projectOwner: p.projectOwner ?? null,
      projectOwnerAr: p.projectOwnerAr ?? null,
      boqCreationDate: p.boqCreationDate ?? null,
    }));
    const p = projects[0] || null;
    res.json({
      success: true,
      data: {
        id: req.user.id,
        name: req.user.name,
        nameAr: req.user.nameAr ?? null,
        email: req.user.email,
        role: req.user.role,
        project: p,
        projects,
        projectIds: req.user.project_ids || [],
        isActive: req.user.isActive,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
