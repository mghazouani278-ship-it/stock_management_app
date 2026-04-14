const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const bcrypt = require('bcryptjs');
const { getFirestore } = require('../firebase');
const { admin } = require('../firebase');
const generateToken = require('../utils/generateToken');
const { protect } = require('../middleware/auth');
const { normalizeUserDisplayName } = require('../utils/userDisplayName');

function projectToApi(data, id) {
  if (!data) return null;
  return {
    id,
    name: data.name,
    description: data.description,
    status: data.status,
    projectOwner: data.project_owner || null,
  };
}

router.post('/register', protect, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ success: false, message: 'Only admins can register users' });
  }

  const { name, email, password, role, projectId, nameAr } = req.body;

  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const firestore = getFirestore();
    const existing = await firestore.collection('users').where('email', '==', email.toLowerCase().trim()).limit(1).get();
    if (!existing.empty) {
      return res.status(400).json({ success: false, message: 'User already exists' });
    }

    const hashed = await bcrypt.hash(password, 10);
    const project_id = (role === 'user' && projectId) ? projectId : null; // warehouse_user has no project
    const nameArTrim = (nameAr != null ? String(nameAr).trim() : '') || '';
    const ref = await firestore.collection('users').add({
      name: name.trim(),
      name_ar: nameArTrim || null,
      email: email.toLowerCase().trim(),
      password: hashed,
      role: role || 'user', // admin, user, warehouse_user
      project_id,
      is_active: true,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    const newUserDoc = await ref.get();
    const newUserData = newUserDoc.data();
    let project = null;
    if (newUserData.project_id) {
      const projectDoc = await firestore.collection('projects').doc(newUserData.project_id).get();
      if (projectDoc.exists) project = projectToApi(projectDoc.data(), projectDoc.id);
    }

    res.status(201).json({
      success: true,
      data: {
        id: newUserDoc.id,
        name: normalizeUserDisplayName(newUserData.name),
        nameAr: newUserData.name_ar || null,
        email: newUserData.email,
        role: newUserData.role,
        project,
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

      let project = null;
      if (row.project_id) {
        const projectDoc = await firestore.collection('projects').doc(row.project_id).get();
        if (projectDoc.exists) project = projectToApi(projectDoc.data(), projectDoc.id);
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
          project,
          isActive: row.is_active !== false,
        },
      });
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

router.get('/me', protect, async (req, res) => {
  try {
    res.json({
      success: true,
      data: {
        id: req.user.id,
        name: req.user.name,
        nameAr: req.user.nameAr ?? null,
        email: req.user.email,
        role: req.user.role,
        project: req.user.project
          ? {
              id: req.user.project.id,
              name: req.user.project.name,
              description: req.user.project.description,
              status: req.user.project.status,
              projectOwner: req.user.project.projectOwner ?? null,
            }
          : null,
        isActive: req.user.isActive,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
