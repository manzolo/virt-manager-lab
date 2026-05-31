#!/usr/bin/env bash
# Abilita la cartella condivisa per Windows7U tramite SPICE WebDAV.
#
# Da eseguire sul host dopo aver lanciato nel guest "Installa guest tools.bat".
# Nel guest la cartella appare tramite il client SPICE/WebDAV, non come virtiofs.

set -euo pipefail

VM_NAME="Windows7U"
CHANNEL_XML="$(mktemp /tmp/win7u-webdav-channel.XXXXXX.xml)"
CONTROLLER_XML="$(mktemp /tmp/win7u-virtio-serial.XXXXXX.xml)"

cleanup() {
    rm -f "$CHANNEL_XML"
    rm -f "$CONTROLLER_XML"
}
trap cleanup EXIT

if ! virsh dominfo "$VM_NAME" >/dev/null; then
    echo "VM non trovata: $VM_NAME"
    exit 1
fi

if virsh dumpxml "$VM_NAME" | grep -q "org.spice-space.webdav.0"; then
    echo "SPICE WebDAV gia' configurato per $VM_NAME."
    exit 0
fi

cat > "$CHANNEL_XML" <<'XML'
<channel type='spiceport'>
  <source channel='org.spice-space.webdav.0'/>
  <target type='virtio' name='org.spice-space.webdav.0'/>
</channel>
XML

cat > "$CONTROLLER_XML" <<'XML'
<controller type='virtio-serial' index='0'/>
XML

if ! virsh dumpxml "$VM_NAME" | grep -q "type='virtio-serial'"; then
    echo "[*] Aggiungo controller virtio-serial a $VM_NAME..."
    virsh attach-device "$VM_NAME" "$CONTROLLER_XML" --live --config
fi

echo "[*] Aggiungo canale SPICE WebDAV a $VM_NAME..."
if ! virsh attach-device "$VM_NAME" "$CHANNEL_XML" --live --config; then
    echo "    -> hotplug live non supportato, applico la modifica solo alla definizione persistente."
    virsh attach-device "$VM_NAME" "$CHANNEL_XML" --config
    echo "    -> riavvia $VM_NAME per rendere attivo il canale."
fi

echo "[+] Canale SPICE WebDAV aggiunto."
echo "    Riavvia o riconnetti virt-viewer se la cartella condivisa non appare subito."
