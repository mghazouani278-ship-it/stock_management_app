# Run ON THE VPS (PowerShell): installs privacy + delete-account pages for Play Console
# Example: cd C:\stock_management_app\backend
#          powershell -ExecutionPolicy Bypass -File .\install-play-console-pages.ps1

$ErrorActionPreference = 'Stop'
$backend = $PSScriptRoot
$publicDir = Join-Path $backend 'public'
$serverJs = Join-Path $backend 'server.js'

New-Item -ItemType Directory -Force -Path $publicDir | Out-Null

@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Privacy Policy — Egypt Grid Stock Management</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; color: #0f172a; }
    h1 { font-size: 1.5rem; }
    h2 { font-size: 1.1rem; margin-top: 1.5rem; }
    .updated { color: #64748b; font-size: 0.9rem; }
  </style>
</head>
<body>
  <h1>Privacy Policy</h1>
  <p class="updated">Egypt Grid — Stock &amp; Project Management App<br />Last updated: May 31, 2026</p>
  <p>This policy describes how Egypt Grid handles information in the Egypt Grid Stock Management app.</p>
  <h2>Information we collect</h2>
  <ul>
    <li><strong>Account data:</strong> email, name, and role when you sign in.</li>
    <li><strong>Business data:</strong> stock, orders, projects, stores, and reports.</li>
    <li><strong>Technical data:</strong> IP address and device type for security and operation.</li>
  </ul>
  <h2>How we use information</h2>
  <ul>
    <li>Authenticate users and provide stock and project management.</li>
    <li>Sync data with our servers at api.egypt-grid.com.</li>
  </ul>
  <h2>Sharing</h2>
  <p>We do not sell personal data. Data is shared only within your organization and with hosting providers.</p>
  <h2>Security</h2>
  <p>We use HTTPS and access controls.</p>
  <h2>Contact</h2>
  <p>Egypt Grid — <a href="mailto:admin@egypt-grid.com">admin@egypt-grid.com</a></p>
</body>
</html>
'@ | Set-Content -Path (Join-Path $publicDir 'privacy.html') -Encoding UTF8

@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Delete account — Egypt Grid</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 720px; margin: 2rem auto; padding: 0 1rem; line-height: 1.6; }
    h1 { font-size: 1.5rem; }
    h2 { font-size: 1.1rem; margin-top: 1.5rem; }
    ol { padding-left: 1.25rem; }
  </style>
</head>
<body>
  <h1>Request account deletion</h1>
  <p><strong>Egypt Grid — Stock &amp; Project Management</strong></p>
  <h2>How to request deletion</h2>
  <ol>
    <li>Email <a href="mailto:admin@egypt-grid.com">admin@egypt-grid.com</a> from your account email.</li>
    <li>Subject: Account deletion request — Egypt Grid app</li>
    <li>Include your full name and sign-in email.</li>
    <li>Processed within 30 days.</li>
  </ol>
  <h2>What is deleted</h2>
  <p>Your login account and personal profile identifiers.</p>
  <h2>What may be kept</h2>
  <p>Business records (orders, stock) may be retained for legal compliance.</p>
  <p><a href="/api/privacy">Privacy policy</a></p>
</body>
</html>
'@ | Set-Content -Path (Join-Path $publicDir 'delete-account.html') -Encoding UTF8

$content = Get-Content $serverJs -Raw
if ($content -notmatch '/api/privacy') {
  $insert = @'

const publicDir = path.join(__dirname, 'public');
const privacyPage = path.join(publicDir, 'privacy.html');

function sendPrivacyPage(_req, res) {
  res.sendFile(privacyPage);
}

function sendDeleteAccountPage(_req, res) {
  res.sendFile(path.join(publicDir, 'delete-account.html'));
}

app.get('/privacy', sendPrivacyPage);
app.get('/api/privacy', sendPrivacyPage);
app.get('/delete-account', sendDeleteAccountPage);
app.get('/api/delete-account', sendDeleteAccountPage);

'@
  $content = $content -replace "(const uploadsDir = path\.join\(__dirname, 'uploads'\);)", "`$1$insert"
  Set-Content -Path $serverJs -Value $content -Encoding UTF8 -NoNewline
  Write-Host 'Updated server.js with privacy routes'
} else {
  Write-Host 'server.js already has privacy routes'
}

Write-Host 'HTML files written to public/'
Write-Host 'Now run: pm2 restart stock-api'
Write-Host 'Test: https://api.egypt-grid.com/api/privacy'
