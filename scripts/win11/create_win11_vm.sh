#!/bin/bash
# Crea la VM Windows 11 con installazione non presidiata.
#
# Prerequisiti:
#   - ISO in: storage/Iso/Windows/Win11_24H2_Italian_x64.iso
#   - autounattend.xml nella stessa cartella di questo script
#   - virtio-win ISO in: storage/Iso/addons/virtio-win-0.1.285.iso
#   - winfsp-2.0.23075.msi in: storage/shared/
#
# Uso: bash scripts/win11/create_win11_vm.sh

set -e

STORAGE="/home/manzolo/Workspaces/qemu/storage"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ISO_WIN11="$STORAGE/Iso/Windows/Win11_24H2_Italian_x64.iso"
ISO_VIRTIO="$STORAGE/Iso/addons/virtio-win-0.1.285.iso"
DISK="$STORAGE/hd/Windows11.qcow2"
AUTOUNATTEND="$SCRIPT_DIR/autounattend.xml"
UNATTEND_ISO="$SCRIPT_DIR/win11_autounattend.iso"
UNATTEND_DIR="$SCRIPT_DIR/win11_unattend_src"

# Verifica prerequisiti
for f in "$ISO_WIN11" "$ISO_VIRTIO" "$AUTOUNATTEND"; do
    [ -f "$f" ] || { echo "Mancante: $f"; exit 1; }
done

# Crea una mini-ISO con autounattend.xml alla radice
# Windows Setup scansiona tutti i CD/DVD montati e trova il file automaticamente
echo "[*] Creo ISO con autounattend.xml..."
rm -rf "$UNATTEND_DIR" && mkdir -p "$UNATTEND_DIR"
cp "$AUTOUNATTEND" "$UNATTEND_DIR/autounattend.xml"
genisoimage -o "$UNATTEND_ISO" -J -r -V "UNATTEND" "$UNATTEND_DIR" 2>/dev/null
echo "    → $UNATTEND_ISO"

# Crea disco virtuale (60 GB)
echo "[*] Creo disco Windows11.qcow2 (60 GB)..."
[ -f "$DISK" ] && { echo "Disco già esistente: $DISK"; exit 1; }
qemu-img create -f qcow2 -o preallocation=off "$DISK" 60G

# Crea la VM
echo "[*] Creo VM Windows11..."
virt-install \
    --name Windows11 \
    --memory 8192 \
    --vcpus 4 \
    --os-variant win11 \
    --machine pc-q35-8.2 \
    --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.fd,cdrom,hd \
    --disk path="$DISK",bus=sata,format=qcow2,discard=unmap \
    --disk path="$ISO_WIN11",device=cdrom,bus=sata \
    --disk path="$ISO_VIRTIO",device=cdrom,bus=sata \
    --disk path="$UNATTEND_ISO",device=cdrom,bus=sata \
    --filesystem source="$STORAGE/shared",target=shared,driver.type=virtiofs \
    --memorybacking source.type=memfd,access.mode=shared \
    --network network=default,model=e1000e \
    --tpm emulator,model=tpm-crb,version=2.0 \
    --graphics spice,listen=none \
    --video qxl \
    --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
    --noautoconsole \
    --boot bootmenu.enable=on

echo ""
echo "[+] VM Windows11 creata. Avvio installazione..."
echo "    Connettiti con: virt-viewer Windows11"
echo ""
echo "    Al termine dell'installazione:"
echo "    1. Il sistema si riavvia automaticamente"
echo "    2. Il primo login è automatico come 'manzolo'"
echo "    3. VirtIO guest tools vengono installati in automatico"
echo "    4. WinFSP viene installato dalla cartella shared (Z:)"
