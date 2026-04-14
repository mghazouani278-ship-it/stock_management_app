# Backend API seul (port 5000). Laissez ce terminal ouvert.
# Ne collez pas d'autres commandes sur la meme ligne que "node server.js".
# Si EADDRINUSE : un autre Node ecoute deja (ex. start.ps1 en arriere-plan) - on libere le port.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $root "backend")

function Stop-ListenerOnPort {
    param([int]$Port = 5000)
    try {
        $conns = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
        foreach ($c in $conns) {
            $owningPid = $c.OwningProcess
            if (-not $owningPid) { continue }
            $proc = Get-Process -Id $owningPid -ErrorAction SilentlyContinue
            $nm = if ($proc) { $proc.ProcessName } else { "?" }
            Write-Host ('Port ' + $Port + ' occupe par PID ' + $owningPid + ' (' + $nm + ') - arret...') -ForegroundColor Yellow
            Stop-Process -Id $owningPid -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # Ancien Windows / droits limites : ignorer
    }
}

Stop-ListenerOnPort 5000

Write-Host 'API: http://localhost:5000/api  (Ctrl+C pour arreter)' -ForegroundColor Cyan
Write-Host ""
node server.js
