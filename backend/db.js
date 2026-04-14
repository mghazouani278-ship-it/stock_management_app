const Database = require('better-sqlite3');
const path = require('path');
const bcrypt = require('bcryptjs');

const dbPath = path.join(__dirname, 'data', 'stock.db');
let db;

function getDb() {
  if (!db) {
    const fs = require('fs');
    const dir = path.join(__dirname, 'data');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    db = new Database(dbPath);
    db.pragma('foreign_keys = ON');
    initSchema();
  }
  return db;
}

function initSchema() {
  const d = db;

  d.exec(`
    CREATE TABLE IF NOT EXISTS depots (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      location TEXT,
      description TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      unit TEXT NOT NULL,
      manufacturer TEXT,
      distributor TEXT,
      status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','inactive')),
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS product_depots (
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      depot_id INTEGER NOT NULL REFERENCES depots(id) ON DELETE CASCADE,
      quantity INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (product_id, depot_id)
    );

    CREATE TABLE IF NOT EXISTS projects (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      description TEXT,
      status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','inactive')),
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'user' CHECK(role IN ('admin','user')),
      project_id INTEGER REFERENCES projects(id),
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS project_products (
      project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      allowed_quantity INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (project_id, product_id)
    );

    CREATE TABLE IF NOT EXISTS orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL REFERENCES users(id),
      project_id INTEGER NOT NULL REFERENCES projects(id),
      status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected','completed')),
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS order_products (
      order_id INTEGER NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      product_id INTEGER NOT NULL REFERENCES products(id),
      quantity INTEGER NOT NULL,
      PRIMARY KEY (order_id, product_id)
    );

    CREATE TABLE IF NOT EXISTS stock (
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
      depot_id INTEGER NOT NULL REFERENCES depots(id) ON DELETE CASCADE,
      quantity INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL DEFAULT (datetime('now')),
      PRIMARY KEY (product_id, depot_id)
    );

    CREATE TABLE IF NOT EXISTS stock_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL REFERENCES products(id),
      depot_id INTEGER NOT NULL REFERENCES depots(id),
      type TEXT NOT NULL CHECK(type IN ('distribution','return','damaged','manual_update','initial')),
      quantity INTEGER NOT NULL,
      previous_quantity INTEGER NOT NULL,
      new_quantity INTEGER NOT NULL,
      project_id INTEGER REFERENCES projects(id),
      user_id INTEGER REFERENCES users(id),
      reference TEXT,
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS distributions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      bon_alimentation TEXT NOT NULL UNIQUE,
      project_id INTEGER NOT NULL REFERENCES projects(id),
      depot_id INTEGER NOT NULL REFERENCES depots(id),
      status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','validated','cancelled')),
      validated_by INTEGER REFERENCES users(id),
      validated_at TEXT,
      created_by INTEGER NOT NULL REFERENCES users(id),
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS distribution_products (
      distribution_id INTEGER NOT NULL REFERENCES distributions(id) ON DELETE CASCADE,
      product_id INTEGER NOT NULL REFERENCES products(id),
      quantity INTEGER NOT NULL,
      PRIMARY KEY (distribution_id, product_id)
    );

    CREATE TABLE IF NOT EXISTS returns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL REFERENCES users(id),
      project_id INTEGER NOT NULL REFERENCES projects(id),
      status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
      approved_by INTEGER REFERENCES users(id),
      approved_at TEXT,
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );

    CREATE TABLE IF NOT EXISTS return_products (
      return_id INTEGER NOT NULL REFERENCES returns(id) ON DELETE CASCADE,
      product_id INTEGER NOT NULL REFERENCES products(id),
      quantity INTEGER NOT NULL,
      condition TEXT NOT NULL DEFAULT 'good' CHECK(condition IN ('good','damaged')),
      PRIMARY KEY (return_id, product_id)
    );

    CREATE TABLE IF NOT EXISTS damaged_products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL REFERENCES products(id),
      project_id INTEGER NOT NULL REFERENCES projects(id),
      depot_id INTEGER NOT NULL REFERENCES depots(id),
      quantity INTEGER NOT NULL,
      reason TEXT NOT NULL,
      reported_by INTEGER NOT NULL REFERENCES users(id),
      approved_by INTEGER REFERENCES users(id),
      status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','approved','rejected')),
      notes TEXT,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
  `);

  // Ensure users can be created before projects (first run: no projects yet)
  const userCount = d.prepare('SELECT COUNT(*) as c FROM users').get();
  if (userCount.c === 0) {
    const hash = bcrypt.hashSync('admin123', 10);
    d.prepare(
      'INSERT INTO users (name, email, password, role, is_active) VALUES (?, ?, ?, ?, ?)'
    ).run('Administrator', 'admin@example.com', hash, 'admin', 1);
    console.log('Admin créé: admin@example.com / admin123');
  }
}

function ensureAdmin() {
  const d = getDb();
  const row = d.prepare('SELECT id FROM users WHERE role = ?').get('admin');
  if (!row) {
    const hash = bcrypt.hashSync('admin123', 10);
    d.prepare(
      'INSERT INTO users (name, email, password, role, is_active) VALUES (?, ?, ?, ?, ?)'
    ).run('Administrator', 'admin@example.com', hash, 'admin', 1);
    return true;
  }
  return false;
}

module.exports = { getDb, initSchema, ensureAdmin };
