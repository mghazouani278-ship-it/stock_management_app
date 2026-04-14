const express = require('express');
const cors = require('cors');
const path = require('path');
const dotenv = require('dotenv');
const { getFirestore, ensureAdmin, getProjectId } = require('./firebase');

dotenv.config();

const app = express();

app.use(cors({
  origin: (origin, cb) => cb(null, true), // Allow all origins (localhost, 127.0.0.1, etc.)
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
  exposedHeaders: ['Content-Length', 'Content-Type'],
  preflightContinue: false,
}));
app.use(express.json({ type: 'application/json' }));
app.use(express.urlencoded({ extended: true, type: 'application/x-www-form-urlencoded' }));

const uploadsDir = path.join(__dirname, 'uploads');
app.use('/uploads', (req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  next();
}, express.static(uploadsDir));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/upload', require('./routes/upload'));
app.use('/api/users', require('./routes/users'));
app.use('/api/stores', require('./routes/stores'));
app.use('/api/depots', require('./routes/depots'));
app.use('/api/products', require('./routes/products'));
app.use('/api/projects', require('./routes/projects'));
app.use('/api/stock', require('./routes/stock'));
app.use('/api/orders', require('./routes/orders'));
app.use('/api/order-notifications', require('./routes/orderNotifications'));
app.use('/api/distributions', require('./routes/distributions'));
app.use('/api/distribution-notifications', require('./routes/distributionNotifications'));
app.use('/api/returns', require('./routes/returns'));
app.use('/api/damaged-products', require('./routes/damagedProducts'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/supplementary-requests', require('./routes/supplementaryRequests'));
app.use('/api/supplementary-notifications', require('./routes/supplementaryNotifications'));

app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'Server is running' });
});

app.get('/api/uploads/:filename', (req, res) => {
  const filename = req.params.filename;
  if (!filename || filename.includes('..')) return res.status(400).send('Invalid filename');
  const filePath = path.join(uploadsDir, filename);
  const fs = require('fs');
  if (!fs.existsSync(filePath)) return res.status(404).send('Not found');
  res.sendFile(filePath);
});

app.use((req, res) => {
  console.warn(`[404] ${req.method} ${req.originalUrl}`);
  res.status(404).json({ success: false, message: 'Route not found' });
});

async function start() {
  try {
    getFirestore();
    const projectId = getProjectId();
    if (projectId) {
      console.log('Firebase connecté (projet:', projectId + ')');
    } else {
      console.log('Firebase connecté');
    }
    await ensureAdmin();
    const PORT = process.env.PORT || 5000;
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server running on http://localhost:${PORT} (API: http://localhost:${PORT}/api)`);
    });
  } catch (err) {
    console.error('Erreur démarrage:', err.message);
    process.exit(1);
  }
}

start();

module.exports = app;
