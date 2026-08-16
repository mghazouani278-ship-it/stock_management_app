const fs = require('fs');
const path = require('path');

function walk(d) {
  for (const f of fs.readdirSync(d)) {
    const p = path.join(d, f);
    const s = fs.statSync(p);
    if (s.isDirectory()) walk(p);
    else if (f.endsWith('.js')) {
      let c = fs.readFileSync(p, 'utf8');
      if (!c.includes("authorize('admin')")) continue;
      if (!c.includes('authorizeAdminLike') && c.includes("require('../middleware/auth')")) {
        c = c.replace(/const \{([^}]+)\} = require\('\.\.\/middleware\/auth'\)/, (m, inner) => {
          if (inner.includes('authorizeAdminLike')) return m;
          return `const {${inner.trim()}, authorizeAdminLike} = require('../middleware/auth')`;
        });
      }
      c = c.replace(/authorize\('admin'\)/g, 'authorizeAdminLike');
      fs.writeFileSync(p, c);
      console.log('updated', p);
    }
  }
}

walk(path.join(__dirname, '..', 'routes'));
