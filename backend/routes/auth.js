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
    nameAr: data.name_ar || null,
    description: data.description,
    status: data.status,
    projectOwner: data.project_owner || null,
    projectOwnerAr: data.project_owner_ar || null,
    boqCreationDate: data.boq_creation_date || null,
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
        if (projectDoc.exists) {
          project = projectToApi(projectDoc.data(), projectDoc.id);
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
          project,
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
    const p = req.user.project;
    res.json({
      success: true,
      data: {
        id: req.user.id,
        name: req.user.name,
        nameAr: req.user.nameAr ?? null,
        email: req.user.email,
        role: req.user.role,
        // Same shape as login — always read fresh project in [protect] middleware.
        project: p
          ? {
              id: p.id,
              name: p.name,
              nameAr: p.nameAr ?? null,
              description: p.description,
              status: p.status,
              projectOwner: p.projectOwner ?? null,
              projectOwnerAr: p.projectOwnerAr ?? null,
              boqCreationDate: p.boqCreationDate ?? null,
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
