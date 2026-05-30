#!/usr/bin/env bash
# Installazione unattended Ubuntu 24.04 LTS (Noble) — ubuntu24
# Replica: GNOME 46, bpfcc-tools, bpftrace, openvpn, virtiofs host_shared
#
# Strategia ISO: -indev/-outdev + -boot_image any replay
# (preserva intatti El Torito, EFI appended partition e tutti i boot record)
#
# Uso: bash scripts/install-ubuntu24.04.sh
#      echo S | bash scripts/install-ubuntu24.04.sh   (non interattivo)

set -euo pipefail

VM_NAME="ubuntu24.04"
DISK_PATH="/home/manzolo/Workspaces/qemu/storage/hd/ubuntu24.04.qcow2"
DISK_SIZE="40G"
ISO_ORIG="/home/manzolo/Workspaces/qemu/storage/Iso/Distro/ubuntu-24.04.3-desktop-amd64.iso"
ISO_AUTO="/home/manzolo/Workspaces/qemu/storage/Iso/Distro/ubuntu-24.04.3-autoinstall.iso"
AUTOINSTALL_SRC="/home/manzolo/Workspaces/qemu/virt-manager/ubuntu24.04-autoinstall.yaml"
ISO_URL="https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-desktop-amd64.iso"
SHARED_DIR="/home/manzolo/Workspaces/qemu/storage/shared"

# --------------------------------------------------------------------------
# 1. Scarica ISO originale se mancante
# --------------------------------------------------------------------------
if [[ ! -f "$ISO_ORIG" ]]; then
    echo "ISO originale non trovata: $ISO_ORIG"
    echo "Download in corso da: $ISO_URL"
    mkdir -p "$(dirname "$ISO_ORIG")"
    wget --show-progress -O "$ISO_ORIG" "$ISO_URL"
    echo "Download completato."
fi

# --------------------------------------------------------------------------
# 2. Controlla VM esistente (default: S)
# --------------------------------------------------------------------------
if virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "La VM '$VM_NAME' esiste già."
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

# --------------------------------------------------------------------------
# 3. Reset disco
# --------------------------------------------------------------------------
echo "Creo il disco $DISK_PATH ($DISK_SIZE)..."
rm -f "$DISK_PATH"
qemu-img create -f qcow2 -o preallocation=off "$DISK_PATH" "$DISK_SIZE"
virsh pool-refresh hdd

# --------------------------------------------------------------------------
# 4. Costruisce ISO con autoinstall integrato
#    Approccio: -indev originale + -outdev nuova + -boot_image any replay
#    Preserva intatti El Torito, EFI appended partition e tutti i boot record.
# --------------------------------------------------------------------------
echo "Preparo ISO autoinstall..."
rm -f "$ISO_AUTO"

# File temporanei
GRUBCFG_TMP=$(mktemp /tmp/ubuntu-grub.cfg.XXXXX)
META_TMP=$(mktemp /tmp/ubuntu-meta.XXXXX)
touch "$META_TMP"

cat > "$GRUBCFG_TMP" <<'GRUBCFG'
set default=0
set timeout=10

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Automated Install" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/ quiet splash ---
    initrd  /casper/initrd
}
menuentry "Try or Install Ubuntu (manual)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet splash ---
    initrd  /casper/initrd
}
if [ "$grub_platform" = "efi" ]; then
menuentry 'UEFI Firmware Settings' { fwsetup }
fi
GRUBCFG

# Costruisce nuova ISO: legge originale, inietta i file, replica il boot catalog
# -boot_image any replay: preserva El Torito + EFI dall'indev (senza questo
#  xorriso scarta il boot record e il UEFI non trova il bootloader)
xorriso \
    -indev  "$ISO_ORIG" \
    -outdev "$ISO_AUTO" \
    -boot_image any replay \
    -map "$GRUBCFG_TMP"    /boot/grub/grub.cfg \
    -map "$AUTOINSTALL_SRC" /user-data \
    -map "$META_TMP"        /meta-data \
    -commit -eject all 2>&1 | grep -v "^xorriso : UPDATE" || true

rm -f "$GRUBCFG_TMP" "$META_TMP"
echo "ISO pronta: $ISO_AUTO"

# --------------------------------------------------------------------------
# 5. Crea e avvia la VM (con virtiofs e memorybacking memfd)
# --------------------------------------------------------------------------
echo "Creo e avvio la VM '$VM_NAME'..."
virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 2 \
    --machine q35 \
    --cpu host-passthrough \
    --os-variant ubuntu24.04 \
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
