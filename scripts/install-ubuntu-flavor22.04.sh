#!/usr/bin/env bash
# Installer comune per flavor Ubuntu 22.04 LTS basati su live-server + autoinstall.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lab.env"
STORAGE="$VM_BASE_DIR/storage"
REPO_DIR="$VM_BASE_DIR/virt-manager"

: "${FLAVOR_ID:?FLAVOR_ID non impostato}"
: "${FLAVOR_LABEL:?FLAVOR_LABEL non impostato}"
: "${VM_NAME:?VM_NAME non impostato}"
: "${DESKTOP_PACKAGE:?DESKTOP_PACKAGE non impostato}"
: "${DISPLAY_MANAGER:?DISPLAY_MANAGER non impostato}"
: "${PLYMOUTH_PACKAGE:?PLYMOUTH_PACKAGE non impostato}"
: "${PLYMOUTH_THEME_PATH:?PLYMOUTH_THEME_PATH non impostato}"

DISK_SIZE="${DISK_SIZE:-30G}"
MEMORY="${MEMORY:-2048}"
VCPUS="${VCPUS:-2}"
SDDM_SESSION="${SDDM_SESSION:-}"

DISK_PATH="$STORAGE/hd/$VM_NAME.qcow2"
ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-22.04.5-live-server-amd64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/$FLAVOR_ID-22.04.5-autoinstall.iso"
AUTOINSTALL_TEMPLATE="$REPO_DIR/ubuntu-flavor22.04-autoinstall.yaml"
ISO_URL="https://releases.ubuntu.com/22.04.5/ubuntu-22.04.5-live-server-amd64.iso"
SHARED_DIR="$STORAGE/shared"

for cmd in wget xorriso qemu-img virt-install virsh; do
    command -v "$cmd" >/dev/null || { echo "Comando mancante: $cmd"; exit 1; }
done

if [[ ! -f "$AUTOINSTALL_TEMPLATE" ]]; then
    echo "Mancante: $AUTOINSTALL_TEMPLATE"
    exit 1
fi

if [[ ! -f "$ISO_ORIG" ]]; then
    echo "ISO originale non trovata: $ISO_ORIG"
    echo "Download in corso da: $ISO_URL"
    mkdir -p "$(dirname "$ISO_ORIG")"
    wget --show-progress -O "$ISO_ORIG" "$ISO_URL"
    echo "Download completato."
fi

if virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "La VM '$VM_NAME' esiste gia'."
    read -rp "Vuoi eliminarla e reinstallare? [S/n] " risposta
    risposta="${risposta:-S}"
    if [[ ! "$risposta" =~ ^[sS]$ ]]; then
        echo "Installazione annullata."
        exit 0
    fi

    echo "Fermo e rimuovo la VM..."
    virsh destroy "$VM_NAME" 2>/dev/null || true
    virsh undefine "$VM_NAME" --snapshots-metadata --nvram 2>/dev/null || \
    virsh undefine "$VM_NAME" --snapshots-metadata 2>/dev/null || true
fi

echo "Creo il disco $DISK_PATH ($DISK_SIZE)..."
rm -f "$DISK_PATH"
qemu-img create -f qcow2 -o preallocation=off "$DISK_PATH" "$DISK_SIZE"
virsh pool-refresh hdd

echo "Preparo ISO autoinstall $FLAVOR_LABEL..."
rm -f "$ISO_AUTO"

GRUBCFG_TMP=$(mktemp "/tmp/$FLAVOR_ID-grub.XXXXX")
META_TMP=$(mktemp "/tmp/$FLAVOR_ID-meta.XXXXX")
AUTOINSTALL_BASE=$(mktemp "/tmp/$FLAVOR_ID-autoinstall-base.XXXXX.yaml")
AUTOINSTALL_RENDERED=$(mktemp "/tmp/$FLAVOR_ID-autoinstall.XXXXX.yaml")
touch "$META_TMP"
trap 'rm -f "$GRUBCFG_TMP" "$META_TMP" "$AUTOINSTALL_BASE" "$AUTOINSTALL_RENDERED"' EXIT

render_template "$AUTOINSTALL_TEMPLATE" "$AUTOINSTALL_BASE"
sed \
    -e "s|__FLAVOR_HOSTNAME__|${FLAVOR_ID}|g" \
    -e "s|__DESKTOP_PACKAGE__|${DESKTOP_PACKAGE}|g" \
    -e "s|__DISPLAY_MANAGER__|${DISPLAY_MANAGER}|g" \
    -e "s|__SDDM_SESSION__|${SDDM_SESSION}|g" \
    -e "s|__PLYMOUTH_PACKAGE__|${PLYMOUTH_PACKAGE}|g" \
    -e "s|__PLYMOUTH_THEME_PATH__|${PLYMOUTH_THEME_PATH}|g" \
    "$AUTOINSTALL_BASE" > "$AUTOINSTALL_RENDERED"

cat > "$GRUBCFG_TMP" <<GRUBCFG
set default=0
set timeout=10

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Automated $FLAVOR_LABEL Install" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\\;s=/cdrom/ fsck.mode=skip quiet splash ---
    initrd  /casper/initrd
}
menuentry "Ubuntu Server Install (manual)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet ---
    initrd  /casper/initrd
}
if [ "\$grub_platform" = "efi" ]; then
menuentry 'UEFI Firmware Settings' { fwsetup }
fi
GRUBCFG

xorriso \
    -indev  "$ISO_ORIG" \
    -outdev "$ISO_AUTO" \
    -boot_image any replay \
    -map "$GRUBCFG_TMP"          /boot/grub/grub.cfg \
    -map "$AUTOINSTALL_RENDERED" /user-data \
    -map "$META_TMP"             /meta-data \
    -commit -eject all 2>&1 | grep -v "^xorriso : UPDATE" || true

echo "ISO pronta: $ISO_AUTO"

echo "Creo e avvio la VM '$VM_NAME'..."
virt-install \
    --name "$VM_NAME" \
    --memory "$MEMORY" \
    --vcpus "$VCPUS" \
    --machine q35 \
    --cpu host-passthrough \
    --os-variant ubuntu22.04 \
    --disk "$DISK_PATH",bus=virtio,driver.discard=unmap \
    --cdrom "$ISO_AUTO" \
    --network network=default,model=virtio \
    --graphics spice \
    --video virtio \
    --sound ich9 \
    --boot uefi \
    --memorybacking source.type=memfd,access.mode=shared \
    --filesystem "source.dir=$SHARED_DIR,target.dir=host_shared,driver.type=virtiofs,accessmode=passthrough" \
    --controller type=scsi,model=virtio-scsi \
    --rng /dev/urandom,model=virtio \
    --memballoon model=virtio \
    --watchdog i6300esb \
    --noautoconsole \
    --noreboot

echo ""
echo "[+] VM $VM_NAME avviata, installazione in corso."
echo "    Connettiti con: virt-viewer $VM_NAME"
echo ""
echo "    Al termine la VM si spegne automaticamente."
echo "    Per avviarla: virsh start $VM_NAME"
