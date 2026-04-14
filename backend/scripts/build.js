/**
 * Build script - uses esbuild to bundle JS (like tsc for JS projects)
 * Output: dist/ with bundled server.js + deploy assets
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const DIST = path.join(ROOT, 'dist');

async function build() {
  console.log('Building with esbuild...\n');

  // Use esbuild via require (installed as devDep) or npx
  let esbuild;
  try {
    esbuild = require('esbuild');
  } catch {
    console.log('esbuild not found, using npx...');
    execSync('npx esbuild server.js --bundle --platform=node --packages=external --outfile=dist/server.js', {
      cwd: ROOT,
      stdio: 'inherit',
    });
  }

  if (esbuild) {
    await esbuild.build({
      entryPoints: ['server.js'],
      bundle: true,
      platform: 'node',
      packages: 'external',
      outfile: 'dist/server.js',
      minify: false,
    });
    console.log('  Bundled: server.js -> dist/server.js');
  }

  // Clean and prepare dist
  if (fs.existsSync(DIST)) {
    // Keep dist/server.js from esbuild, remove rest
    for (const entry of fs.readdirSync(DIST)) {
      if (entry !== 'server.js') {
        fs.rmSync(path.join(DIST, entry), { recursive: true });
      }
    }
  } else {
    fs.mkdirSync(DIST, { recursive: true });
  }

  // Copy deploy assets
  console.log('\nCopying deploy assets...');

  for (const item of ['package.json', 'package-lock.json', 'env.example']) {
    const src = path.join(ROOT, item);
    const dest = path.join(DIST, item);
    if (fs.existsSync(src)) {
      fs.copyFileSync(src, dest);
      console.log('  Copied:', item);
    }
  }

  // Copy config (excluding secrets)
  const configSrc = path.join(ROOT, 'config');
  const configDest = path.join(DIST, 'config');
  if (fs.existsSync(configSrc)) {
    fs.mkdirSync(configDest, { recursive: true });
    for (const entry of fs.readdirSync(configSrc)) {
      if (entry === 'firebase-service-account.json') continue;
      fs.copyFileSync(path.join(configSrc, entry), path.join(configDest, entry));
    }
    console.log('  Copied: config/');
  }

  // Create uploads
  const uploadsDir = path.join(DIST, 'uploads');
  fs.mkdirSync(uploadsDir, { recursive: true });
  console.log('  Created: uploads/');

  // Copy scripts (except build.js)
  const scriptsSrc = path.join(ROOT, 'scripts');
  const scriptsDest = path.join(DIST, 'scripts');
  if (fs.existsSync(scriptsSrc)) {
    fs.mkdirSync(scriptsDest, { recursive: true });
    for (const entry of fs.readdirSync(scriptsSrc)) {
      if (entry === 'build.js') continue;
      fs.copyFileSync(path.join(scriptsSrc, entry), path.join(scriptsDest, entry));
    }
    console.log('  Copied: scripts/');
  }

  // Update dist/package.json main to server.js
  const pkgPath = path.join(DIST, 'package.json');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  pkg.main = 'server.js';
  fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2));

  // Install production dependencies
  console.log('\nInstalling production dependencies in dist/...');
  execSync('npm install --omit=dev', {
    cwd: DIST,
    stdio: 'inherit',
  });

  console.log('\nBuild complete! Output: dist/');
  console.log('Run: cd dist && npm start');
}

build().catch((err) => {
  console.error(err);
  process.exit(1);
});
