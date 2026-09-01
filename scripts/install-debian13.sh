#!/usr/bin/env bash
# Installazione unattended Debian 13 (Trixie) — ManzoloDebian
# Replica: GNOME, Apache2, Docker, build-essential, gcc, bind9-dnsutils, aspell-it
# Strategia: sistema base (standard) dal DVD, tutto il resto via late_command dalla rete

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lab.env"
STORAGE="$VM_BASE_DIR/storage"
# Il repo si individua dalla posizione dello script: la cartella del clone puo' chiamarsi come si vuole.
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

VM_NAME="Debian13"
DISK_PATH="$STORAGE/hd/Debian13.qcow2"
DISK_SIZE="50G"
ISO_ORIG="$STORAGE/Iso/Distro/debian-13.0.0-amd64-DVD-1.iso"
ISO_PRESEED="$STORAGE/Iso/Distro/debian-13-preseed.iso"
PRESEED_TEMPLATE="$REPO_DIR/unattended/Debian13-preseed.cfg"
ISO_WORKDIR="/tmp/debian13-iso-build"
ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/debian-13.0.0-amd64-DVD-1.iso"

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
# 4. Costruisce ISO con preseed integrato
# --------------------------------------------------------------------------
echo "Estraggo l'ISO originale..."
chmod -R u+w "$ISO_WORKDIR" 2>/dev/null || true
rm -rf "$ISO_WORKDIR"
mkdir -p "$ISO_WORKDIR"
xorriso -osirrox on \
    -indev "$ISO_ORIG" \
    -extract / "$ISO_WORKDIR/" 2>/dev/null

echo "Inietto il preseed..."
PRESEED_RENDERED=$(mktemp /tmp/debian13-preseed.XXXXX.cfg)
trap 'rm -f "$PRESEED_RENDERED"' EXIT
render_template "$PRESEED_TEMPLATE" "$PRESEED_RENDERED"
cp "$PRESEED_RENDERED" "$ISO_WORKDIR/preseed.cfg"
chmod -R u+w "$ISO_WORKDIR/boot/grub/" "$ISO_WORKDIR/isolinux/"

# GRUB (EFI): prima voce = auto preseed, timeout 10s
cat > "$ISO_WORKDIR/boot/grub/grub.cfg" <<'GRUBCFG'
if [ x$feature_default_font_path = xy ] ; then
   font=unicode
else
   font=$prefix/font.pf2
fi

if loadfont $font ; then
  set gfxmode=800x600
  set gfxpayload=keep
  insmod efi_gop
  insmod efi_uga
  insmod video_bochs
  insmod video_cirrus
  insmod gfxterm
  insmod png
  terminal_output gfxterm
fi

if background_image /isolinux/splash.png; then
  set color_normal=light-gray/black
  set color_highlight=white/black
elif background_image /splash.png; then
  set color_normal=light-gray/black
  set color_highlight=white/black
else
  set menu_color_normal=cyan/blue
  set menu_color_highlight=white/blue
fi

set default=0
set timeout=10
set theme=/boot/grub/theme/1

menuentry 'Automated Install (preseed)' {
    set background_color=black
    linux    /install.amd/vmlinuz auto=true priority=critical file=/cdrom/preseed.cfg vga=788 --- quiet
    initrd   /install.amd/gtk/initrd.gz
}
menuentry --hotkey=g 'Graphical install (manual)' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 --- quiet
    initrd   /install.amd/gtk/initrd.gz
}
menuentry --hotkey=i 'Install (manual)' {
    set background_color=black
    linux    /install.amd/vmlinuz vga=788 --- quiet
    initrd   /install.amd/initrd.gz
}
GRUBCFG

# isolinux (BIOS fallback)
cat > "$ISO_WORKDIR/isolinux/txt.cfg" <<'ISOLINUX'
label install
	menu label ^Automated Install (preseed)
	kernel /install.amd/vmlinuz
	append auto=true priority=critical file=/cdrom/preseed.cfg vga=788 initrd=/install.amd/initrd.gz --- quiet
label manual
	menu label ^Manual Install
	kernel /install.amd/vmlinuz
	append vga=788 initrd=/install.amd/initrd.gz --- quiet
ISOLINUX

echo "Ricostruisco l'ISO con preseed..."
MBR_IMG=$(mktemp)
dd if="$ISO_ORIG" bs=1 count=432 of="$MBR_IMG" 2>/dev/null

xorriso -as mkisofs \
    -r -J -joliet-long \
    -l -cache-inodes \
    -isohybrid-mbr "$MBR_IMG" \
    -partition_offset 16 \
    -A "Debian 13 Preseed" \
    -V "Debian 13 Preseed" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -boot-load-size 4 \
    -boot-info-table \
    -no-emul-boot \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -o "$ISO_PRESEED" \
    "$ISO_WORKDIR/" 2>/dev/null

rm -f "$MBR_IMG"
chmod -R u+w "$ISO_WORKDIR" 2>/dev/null || true
rm -rf "$ISO_WORKDIR"
echo "ISO creata: $ISO_PRESEED"

# --------------------------------------------------------------------------
# 5. Crea e avvia la VM
# --------------------------------------------------------------------------
echo "Creo e avvio la VM '$VM_NAME'..."
virt-install \
    --name "$VM_NAME" \
    --memory 2048 \
    --vcpus 2 \
    --machine q35 \
    --cpu host-passthrough \
    --os-variant debian13 \
    --disk "$DISK_PATH",bus=virtio \
    --cdrom "$ISO_PRESEED" \
    --network network=default,model=virtio \
    --graphics spice \
    --video qxl \
    --sound ich9 \
    --boot uefi \
    --controller type=scsi,model=virtio-scsi \
    --rng /dev/urandom,model=virtio \
    --memballoon model=virtio \
    --watchdog i6300esb \
    --noautoconsole \
    --noreboot

echo ""
echo "Installazione avviata. Seguila con:"
echo "  virt-viewer $VM_NAME"
echo ""
echo "Al termine la VM si spegnerà automaticamente."
echo "Per avviarla normalmente: virsh start $VM_NAME"
