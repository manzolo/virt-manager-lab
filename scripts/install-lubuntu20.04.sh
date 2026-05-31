#!/usr/bin/env bash
# Installazione unattended Lubuntu 20.04 LTS (Focal) — lubuntu20
# Base: Ubuntu live-server 20.04.6 + autoinstall + lubuntu-desktop.
#
# Uso: bash scripts/install-lubuntu20.04.sh
#      echo S | bash scripts/install-lubuntu20.04.sh   (non interattivo)

set -euo pipefail

VM_NAME="lubuntu20.04"
DISK_PATH="/home/manzolo/Workspaces/qemu/storage/hd/lubuntu20.04.qcow2"
DISK_SIZE="25G"
ISO_ORIG="/home/manzolo/Workspaces/qemu/storage/Iso/Distro/ubuntu-20.04.6-live-server-amd64.iso"
ISO_AUTO="/home/manzolo/Workspaces/qemu/storage/Iso/Distro/lubuntu-20.04.6-autoinstall.iso"
AUTOINSTALL_SRC="/home/manzolo/Workspaces/qemu/virt-manager/lubuntu20.04-autoinstall.yaml"
ISO_URL="https://releases.ubuntu.com/20.04.6/ubuntu-20.04.6-live-server-amd64.iso"
SHARED_DIR="/home/manzolo/Workspaces/qemu/storage/shared"

for cmd in wget xorriso qemu-img virt-install virsh; do
    command -v "$cmd" >/dev/null || { echo "Comando mancante: $cmd"; exit 1; }
done

if [[ ! -f "$AUTOINSTALL_SRC" ]]; then
    echo "Mancante: $AUTOINSTALL_SRC"
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

echo "Preparo ISO autoinstall Lubuntu 20.04..."
rm -f "$ISO_AUTO"

GRUBCFG_TMP=$(mktemp /tmp/lubuntu20-grub.cfg.XXXXX)
META_TMP=$(mktemp /tmp/lubuntu20-meta.XXXXX)
touch "$META_TMP"

cat > "$GRUBCFG_TMP" <<'GRUBCFG'
set default=0
set timeout=10

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Automated Lubuntu 20.04 Install" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/ fsck.mode=skip quiet splash ---
    initrd  /casper/initrd
}
menuentry "Ubuntu Server Install (manual)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet ---
    initrd  /casper/initrd
}
if [ "$grub_platform" = "efi" ]; then
menuentry 'UEFI Firmware Settings' { fwsetup }
fi
GRUBCFG

xorriso \
    -indev  "$ISO_ORIG" \
    -outdev "$ISO_AUTO" \
    -boot_image any replay \
    -map "$GRUBCFG_TMP"     /boot/grub/grub.cfg \
    -map "$AUTOINSTALL_SRC" /user-data \
    -map "$META_TMP"        /meta-data \
    -commit -eject all 2>&1 | grep -v "^xorriso : UPDATE" || true

rm -f "$GRUBCFG_TMP" "$META_TMP"
echo "ISO pronta: $ISO_AUTO"

echo "Creo e avvio la VM '$VM_NAME'..."
virt-install \
    --name "$VM_NAME" \
    --memory 2048 \
    --vcpus 2 \
    --machine q35 \
    --cpu host-passthrough \
    --os-variant ubuntu20.04 \
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
