#!/usr/bin/env bash
# Installazione unattended Arch Linux — arch (GNOME) oppure niri (ARCH_PROFILE=niri).
# Meccanismo: remaster dell'ISO archiso per autoeseguire un bootstrap nel live
# (feature archiso 'script='). Il bootstrap (scripts/assets/arch-bootstrap.sh)
# partiziona, pacstrap, configura DM+autologin+virtiofs e spegne.
#
# Contratto e2e: install -> poweroff -> virsh start -> qemu-guest-agent ->
# graphical.target + display-manager.
#
# Uso:
#   bash scripts/install-arch.sh                 # profilo gnome (VM 'arch')
#   ARCH_PROFILE=niri bash scripts/install-arch.sh   # profilo niri  (VM 'niri')
#   echo S | bash scripts/install-arch.sh
#
# STATO: first-draft, da validare al primo run reale (vedi docs/new-distros.md):
#   - autorun 'script=' dell'archiso e path dei file di boot (loader/syslinux)
#     cambiano col mese della ISO;
#   - per niri: build AUR di noctalia al primo boot (sperimentale).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lab.env"
STORAGE="$VM_BASE_DIR/storage"

ARCH_PROFILE="${ARCH_PROFILE:-gnome}"
case "$ARCH_PROFILE" in
  gnome) VM_NAME="arch" ;;
  niri)  VM_NAME="niri" ;;
  *) echo "ARCH_PROFILE non valido: $ARCH_PROFILE (gnome|niri)"; exit 2 ;;
esac

DISK_PATH="$STORAGE/hd/${VM_NAME}.qcow2"
DISK_SIZE="40G"
ISO_ORIG="$STORAGE/Iso/Distro/archlinux-x86_64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/${VM_NAME}-auto.iso"
SHARED_DIR="$STORAGE/shared"
BOOTSTRAP_SRC="$SCRIPT_DIR/assets/arch-bootstrap.sh"
NIRI_FB_SRC="$SCRIPT_DIR/assets/niri-firstboot.sh"
ISO_URL="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"

SCRIPT_PARAM="script=/run/archiso/bootmnt/arch-lab/bootstrap.sh"

# --------------------------------------------------------------------------
# 1. ISO originale
# --------------------------------------------------------------------------
if [[ ! -f "$ISO_ORIG" ]]; then
    echo "ISO Arch non trovata: $ISO_ORIG"
    read -rp "La scarico ora da $ISO_URL ? [s/N] " dl
    [[ "${dl:-N}" =~ ^[sS]$ ]] || { echo "Annullato."; exit 1; }
    mkdir -p "$(dirname "$ISO_ORIG")"
    wget --show-progress -O "$ISO_ORIG" "$ISO_URL"
fi

# --------------------------------------------------------------------------
# 2. VM esistente
# --------------------------------------------------------------------------
if virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "La VM '$VM_NAME' esiste gia'."
    read -rp "Vuoi eliminarla e reinstallare? [S/n] " risposta
    risposta="${risposta:-S}"
    [[ "$risposta" =~ ^[sS]$ ]] || { echo "Installazione annullata."; exit 0; }
    virsh destroy "$VM_NAME" 2>/dev/null || true
    virsh undefine "$VM_NAME" --snapshots-metadata --nvram 2>/dev/null || \
    virsh undefine "$VM_NAME" --snapshots-metadata 2>/dev/null || true
fi

# --------------------------------------------------------------------------
# 3. Disco
# --------------------------------------------------------------------------
echo "Creo il disco $DISK_PATH ($DISK_SIZE)..."
rm -f "$DISK_PATH"
qemu-img create -f qcow2 -o preallocation=off "$DISK_PATH" "$DISK_SIZE"
virsh pool-refresh hdd 2>/dev/null || true

# --------------------------------------------------------------------------
# 4. Remaster ISO: inietta arch-lab/ + aggiunge 'script=' alle entry di boot
# --------------------------------------------------------------------------
echo "Preparo l'ISO archiso autoeseguibile (profilo: $ARCH_PROFILE)..."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# bootstrap reso con utente/pass/profilo
mkdir -p "$WORK/arch-lab"
render_template "$BOOTSTRAP_SRC" "$WORK/arch-lab/bootstrap.sh"
sed -i "s|__PROFILE__|${ARCH_PROFILE}|g" "$WORK/arch-lab/bootstrap.sh"
cp "$NIRI_FB_SRC" "$WORK/arch-lab/niri-firstboot.sh"

# estrai SOLO i config di boot da modificare
for d in loader/entries syslinux boot/grub EFI/BOOT; do
    xorriso -osirrox on -indev "$ISO_ORIG" -extract "/$d" "$WORK/orig/$d" 2>/dev/null || true
done

# aggiungi il parametro script= a tutte le righe kernel (options/APPEND)
MAP_ARGS=()
while IFS= read -r -d '' f; do
    rel="${f#"$WORK/orig/"}"
    # inserisce script= dove compaiono le opzioni di boot
    sed -i -E "s#(^[[:space:]]*options[[:space:]].*)#\1 ${SCRIPT_PARAM}#; s#(^[[:space:]]*APPEND[[:space:]].*)#\1 ${SCRIPT_PARAM}#" "$f" 2>/dev/null || true
    MAP_ARGS+=( -map "$f" "/$rel" )
done < <(find "$WORK/orig" -type f \( -name '*.conf' -o -name '*.cfg' \) -print0 2>/dev/null)

rm -f "$ISO_AUTO"
# replay: preserva El Torito / EFI / volume label dell'archiso; -map sovrascrive
xorriso \
    -indev  "$ISO_ORIG" \
    -outdev "$ISO_AUTO" \
    -boot_image any replay \
    -map "$WORK/arch-lab" /arch-lab \
    "${MAP_ARGS[@]}" \
    -commit 2>&1 | grep -v '^xorriso : UPDATE' || true
echo "ISO pronta: $ISO_AUTO"

# --------------------------------------------------------------------------
# 5. Crea e avvia la VM
# --------------------------------------------------------------------------
echo "Creo e avvio la VM '$VM_NAME'..."
virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 4 \
    --machine q35 \
    --cpu host-passthrough \
    --os-variant archlinux \
    --disk "$DISK_PATH",bus=virtio,driver.discard=unmap \
    --cdrom "$ISO_AUTO" \
    --network network=default,model=virtio \
    --graphics spice \
    --video virtio \
    --boot uefi \
    --memorybacking source.type=memfd,access.mode=shared \
    --filesystem "source.dir=$SHARED_DIR,target.dir=shared,driver.type=virtiofs,accessmode=passthrough" \
    --controller type=scsi,model=virtio-scsi \
    --rng /dev/urandom,model=virtio \
    --memballoon model=virtio \
    --noautoconsole \
    --noreboot

echo ""
echo "[+] Installazione avviata. Seguila con: virt-viewer $VM_NAME"
echo "    Al termine la VM si spegne (bootstrap -> poweroff)."
echo "    Primo boot: virsh start $VM_NAME"
