# Deploiement manuel du backend vers la production (egypt-grid.com).
# Je n'ai pas acces a ton serveur depuis Cursor : copie ces etapes sur ta machine ou ton VPS.
#
# 1) Sur ton PC : arrete le backend local si besoin ; le code a jour est dans : .\backend\
#
# 2) Copie le dossier `backend` vers le serveur (exemples) :
#    - WinSCP / FileZilla : uploader tout le dossier sauf `backend\node_modules` (optionnel : tout uploader puis npm install sur le serveur)
#    - Ou en ligne de commande (Git Bash ou PowerShell avec OpenSSH) :
#        scp -r C:\Users\hp\Desktop\developpement\stock_management_app\backend\* USER@egypt-grid.com:/chemin/backend/
#
# 3) En SSH sur le serveur :
#        cd /chemin/backend
#        npm install --production
#        pm2 restart all
#    (ou : systemctl restart nom-du-service  /  IISNode / panneau Plesk "Redemarrer Node")
#
# 4) Verifier : ouvrir http://egypt-grid.com:5000/api (ou l'URL reelle de l'API).
#
# Important : ne pas ecraser le fichier `.env` du serveur avec une copie locale si les cles Firebase / secrets different.

Write-Host "Lisez les instructions dans ce fichier (deploy-backend-template.ps1)." -ForegroundColor Cyan
Write-Host "Backend local actuel : $(Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'backend')" -ForegroundColor Gray
