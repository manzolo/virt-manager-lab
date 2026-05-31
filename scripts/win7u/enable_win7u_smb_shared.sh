#!/usr/bin/env bash
# Esporta storage/shared via Samba per Windows7U.
#
# Nel guest Windows 7 monta la share con:
#   net use Z: \\192.168.122.1\qemu-shared /persistent:yes

set -euo pipefail

SHARE_NAME="qemu-shared"
SHARE_DIR="/home/manzolo/Workspaces/qemu/storage/shared"
SMB_CONF="/etc/samba/smb.conf"
HOST_USER="$(id -un)"

if [[ ! -d "$SHARE_DIR" ]]; then
    echo "Cartella shared non trovata: $SHARE_DIR"
    exit 1
fi

if ! command -v smbd >/dev/null; then
    echo "Samba server non e' installato."
    echo "Installa con: sudo apt-get update && sudo apt-get install -y samba"
    exit 1
fi

if ! command -v testparm >/dev/null; then
    echo "Comando mancante: testparm"
    exit 1
fi

if [[ ! -f "$SMB_CONF" ]]; then
    echo "File Samba non trovato: $SMB_CONF"
    exit 1
fi

echo "[*] Configuro share [$SHARE_NAME] -> $SHARE_DIR"
sudo cp -n "$SMB_CONF" "$SMB_CONF.win7u.bak"

if ! sudo grep -q "^\[$SHARE_NAME\]" "$SMB_CONF"; then
    cat <<EOF | sudo tee -a "$SMB_CONF" >/dev/null

[$SHARE_NAME]
   path = $SHARE_DIR
   browseable = yes
   read only = no
   guest ok = yes
   force user = $HOST_USER
   create mask = 0664
   directory mask = 0775
EOF
else
    echo "    -> share gia' presente in $SMB_CONF"
fi

sudo chmod 0775 "$SHARE_DIR"
testparm -s >/dev/null

echo "[*] Abilito e riavvio Samba..."
sudo systemctl enable --now smbd
sudo systemctl restart smbd

if command -v ufw >/dev/null && sudo ufw status | grep -q "Status: active"; then
    echo "[*] UFW attivo: apro Samba."
    sudo ufw allow Samba
fi

echo "[+] Share pronta."
echo "    Nel guest Windows 7 esegui:"
echo "    net use Z: \\\\192.168.122.1\\$SHARE_NAME /persistent:yes"
