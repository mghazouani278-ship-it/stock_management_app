const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const { getFirestore } = require('../firebase');
const { protect, authorizeAdminLike, authorize } = require('../middleware/auth');
const { toApi } = require('../utils/firestoreToApi');
const { normalizeUserDisplayName } = require('../utils/userDisplayName');
const { VALID_ROLES, normalizeRole, isUser, isSupervisor, getUserProjectIds } = require('../utils/roles');

async function userToApi(doc, firestore) {
  if (!doc || !doc.exists) return null;
  const data = doc.data();
  const projectIds = getUserProjectIds(data);
  const projects = [];
  for (const pid of projectIds) {
    const projectDoc = await firestore.collection('projects').doc(pid).get();
    if (projectDoc.exists) {
      const p = projectDoc.data();
      projects.push({
        id: projectDoc.id,
        name: p.name,
        nameAr: p.name_ar || null,
        description: p.description,
        status: p.status,
      });
    }
  }
  const out = toApi(doc);
  if (out.name != null) out.name = normalizeUserDisplayName(out.name);
  out.nameAr = data.name_ar || null;
  out.project = projects[0] || null;
  out.projects = projects;
  out.projectIds = projectIds;
  out.project_ids = projectIds;
  out.isActive = data.is_active !== false;
  out.createdAt = data.created_at;
  delete out.password;
  return out;
}

function normalizeProjectIds(body, role) {
  const r = normalizeRole(role);
  const needsProjects = r === 'user' || r === 'supervisor';
  if (!needsProjects) return { project_id: null, project_ids: [] };

  let ids = [];
  if (Array.isArray(body.projectIds)) ids = body.projectIds.map(String).filter(Boolean);
  else if (Array.isArray(body.project_ids)) ids = body.project_ids.map(String).filter(Boolean);
  else if (body.projectId) ids = [String(body.projectId)];

  return {
    project_id: ids[0] || null,
    project_ids: ids,
  };
}

router.get('/', protect, authorizeAdminLike, async (req, res) => {
  try {
    const firestore = getFirestore();
    const snapshot = await firestore.collection('users').orderBy('created_at', 'desc').get();
    const data = await Promise.all(snapshot.docs.map((d) => userToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

/** Supervisors can list users (read-only view of assigned projects' users) */
router.get('/for-supervisor', protect, authorize('supervisor'), async (req, res) => {
  try {
    const firestore = getFirestore();
    const allowed = (req.user.project_ids || []).map(String).filter(Boolean);
    if (allowed.length === 0 && req.user.project_id) allowed.push(String(req.user.project_id));
    const snapshot = await firestore.collection('users').get();
    const filtered = snapshot.docs.filter((d) => {
      const ids = getUserProjectIds(d.data());
      return ids.some((id) => allowed.includes(String(id)));
    });
    const data = await Promise.all(filtered.map((d) => userToApi(d, firestore)));
    res.json({ success: true, count: data.length, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.get('/:id', protect, authorizeAdminLike, async (req, res) => {
  try {
    const firestore = getFirestore();
    const doc = await firestore.collection('users').doc(req.params.id).get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    const data = await userToApi(doc, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id', protect, authorizeAdminLike, async (req, res) => {
  try {
    const { name, email, role, isActive, nameAr, password } = req.body;
    const firestore = getFirestore();
    const ref = firestore.collection('users').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    const updates = {};
    if (name != null) updates.name = name;
    if (nameAr !== undefined) {
      const t = nameAr == null ? '' : String(nameAr).trim();
      updates.name_ar = t || null;
    }
    if (email != null) updates.email = email;
    if (role != null) {
      const nr = normalizeRole(role);
      if (!VALID_ROLES.includes(nr) && !nr.startsWith('warehouse')) {
        return res.status(400).json({ success: false, message: `Invalid role: ${role}` });
      }
      updates.role = nr;
    }
    if (isActive !== undefined) updates.is_active = isActive;

    const effectiveRole = updates.role || doc.data().role;
    if (
      req.body.projectId !== undefined ||
      req.body.projectIds !== undefined ||
      req.body.project_ids !== undefined ||
      role != null
    ) {
      const proj = normalizeProjectIds(req.body, effectiveRole);
      updates.project_id = proj.project_id;
      updates.project_ids = proj.project_ids;
    }

    if (password != null && String(password).trim() !== '') {
      const plain = String(password).trim();
      if (plain.length < 6) {
        return res.status(400).json({ success: false, message: 'Password must be at least 6 characters' });
      }
      updates.password = await bcrypt.hash(plain, 10);
    }
    if (Object.keys(updates).length) await ref.update(updates);
    const updated = await ref.get();
    const data = await userToApi(updated, firestore);
    res.json({ success: true, data });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.delete('/:id', protect, authorizeAdminLike, async (req, res) => {
  try {
    const firestore = getFirestore();
    const ref = firestore.collection('users').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    await ref.delete();
    res.json({ success: true, message: 'User deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

router.put('/:id/activate', protect, authorizeAdminLike, async (req, res) => {
  try {
    const { isActive } = req.body;
    const firestore = getFirestore();
    const ref = firestore.collection('users').doc(req.params.id);
    const doc = await ref.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    const data = doc.data();
    const newActive = isActive !== undefined ? isActive : !data.is_active;
    await ref.update({ is_active: newActive });
    res.json({ success: true, data: { id: doc.id, isActive: !!newActive } });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
module.exports.userToApi = userToApi;
