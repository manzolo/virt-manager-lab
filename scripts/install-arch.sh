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
FIRSTBOOT_AUTOSTART="${FIRSTBOOT_AUTOSTART:-true}"
FIRSTBOOT_WAIT_TIMEOUT="${FIRSTBOOT_WAIT_TIMEOUT:-3600}"
case "$ARCH_PROFILE" in
  gnome) VM_NAME="arch" ;;
  niri)  VM_NAME="niri" ;;
  *) echo "ARCH_PROFILE non valido: $ARCH_PROFILE (gnome|niri)"; exit 2 ;;
esac

if [ "$ARCH_PROFILE" = "niri" ]; then
    NIRI_GL_RENDERNODE="${NIRI_GL_RENDERNODE:-/dev/dri/renderD128}"
    VM_MEMORY=8192
    GRAPHICS_ARGS=(--graphics "vnc,listen=127.0.0.1" --graphics "egl-headless,gl.rendernode=${NIRI_GL_RENDERNODE}" --video virtio,model.acceleration.accel3d=yes,model.blob=on)
else
    VM_MEMORY=4096
    GRAPHICS_ARGS=(--graphics spice --video virtio)
fi

DISK_PATH="$STORAGE/hd/${VM_NAME}.qcow2"
DISK_SIZE="40G"
ISO_ORIG="$STORAGE/Iso/Distro/archlinux-x86_64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/${VM_NAME}-auto.iso"
SHARED_DIR="$STORAGE/shared"
BOOTSTRAP_SRC="$SCRIPT_DIR/assets/arch-bootstrap.sh"
NIRI_FB_SRC="$SCRIPT_DIR/assets/niri-firstboot.sh"
ISO_URL="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso"

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
# 4. Remaster ISO: inietta SOLO la cartella arch-lab/ (bootstrap + niri-firstboot).
#    Lo script= non si mette nelle entry di boot (in UEFI l'archiso le legge da
#    un'immagine EFI FAT embedded, non dal filesystem ISO): lo passiamo invece
#    sul cmdline via 'virt-install --location ... --extra-args' (vedi sotto).
# --------------------------------------------------------------------------
echo "Preparo l'ISO archiso con arch-lab/ (profilo: $ARCH_PROFILE)..."
WORK="$(mktemp -d)"
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

mkdir -p "$WORK/arch-lab"
render_template "$BOOTSTRAP_SRC" "$WORK/arch-lab/bootstrap.sh"
sed -i "s|__PROFILE__|${ARCH_PROFILE}|g" "$WORK/arch-lab/bootstrap.sh"
cp "$NIRI_FB_SRC" "$WORK/arch-lab/niri-firstboot.sh"

# Label del filesystem ISO (per archisolabel=), kernel e initrd interni.
ARCHISO_LABEL="$(blkid -o value -s LABEL "$ISO_ORIG" 2>/dev/null || echo ARCH_202601)"
ISO_KERNEL="arch/boot/x86_64/vmlinuz-linux"
ISO_INITRD="arch/boot/x86_64/initramfs-linux.img"

rm -f "$ISO_AUTO"
# replay: preserva El Torito/EFI/label; -map aggiunge solo /arch-lab
xorriso \
    -indev  "$ISO_ORIG" \
    -outdev "$ISO_AUTO" \
    -boot_image any replay \
    -map "$WORK/arch-lab" /arch-lab \
    -commit 2>&1 | grep -v '^xorriso : UPDATE' || true
echo "ISO pronta: $ISO_AUTO (label $ARCHISO_LABEL)"

# --------------------------------------------------------------------------
# 5. Crea e avvia la VM
#    --location estrae kernel/initrd dall'ISO e li avvia passando --extra-args
#    sul cmdline (qui lo script= dell'autorun archiso). L'ISO va comunque
#    allegata come cdrom: l'initramfs la ritrova via archisolabel e monta la sfs.
#    Dopo l'install, virt-install riconfigura il dominio per il boot da disco.
# --------------------------------------------------------------------------
echo "Creo e avvio la VM '$VM_NAME'..."
virt-install \
    --name "$VM_NAME" \
    --memory "$VM_MEMORY" \
    --vcpus 4 \
    --machine q35 \
    --cpu host-passthrough \
    --os-variant archlinux \
    --disk "$DISK_PATH",bus=virtio,driver.discard=unmap \
    --disk "$ISO_AUTO",device=cdrom \
    --location "$ISO_AUTO",kernel="$ISO_KERNEL",initrd="$ISO_INITRD" \
    --extra-args "archisobasedir=arch archisolabel=${ARCHISO_LABEL} cow_spacesize=4G script=/run/archiso/bootmnt/arch-lab/bootstrap.sh console=ttyS0,115200 console=tty0" \
    --network network=default,model=virtio \
    "${GRAPHICS_ARGS[@]}" \
    --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.fd \
    --memorybacking source.type=memfd,access.mode=shared \
    --filesystem "source.dir=$SHARED_DIR,target.dir=shared,driver.type=virtiofs,accessmode=passthrough" \
    --controller type=scsi,model=virtio-scsi \
    --rng /dev/urandom,model=virtio \
    --memballoon model=virtio \
    --noautoconsole \
    --noreboot

# L'archiso deve restare nel live domain durante l'installazione, ma non nella
# configurazione persistente: cosi' al primo boot dopo il poweroff parte dal disco.
for tgt in $(virsh domblklist "$VM_NAME" 2>/dev/null | awk -v iso="$ISO_AUTO" '$2 == iso {print $1}'); do
  virsh change-media "$VM_NAME" "$tgt" --eject --config >/dev/null 2>&1 || true
done

if [ "$FIRSTBOOT_AUTOSTART" = "true" ]; then
    echo "Attendo lo spegnimento di fine installazione per avviare il primo boot..."
    deadline=$((SECONDS + FIRSTBOOT_WAIT_TIMEOUT))
    while [ "$(virsh domstate "$VM_NAME" 2>/dev/null || true)" != "shut off" ]; do
        if [ "$SECONDS" -ge "$deadline" ]; then
            echo "Timeout: installazione non terminata entro ${FIRSTBOOT_WAIT_TIMEOUT}s."
            exit 1
        fi
        sleep 10
    done
    virsh start "$VM_NAME" >/dev/null
fi

echo ""
if [ "$ARCH_PROFILE" = "niri" ]; then
    echo "[+] Installazione avviata. Console VNC: ricava il display con 'virsh vncdisplay $VM_NAME'"
    echo "    Esempio: se vncdisplay stampa 127.0.0.1:2, apri 'remote-viewer vnc://127.0.0.1:5902'"
else
    echo "[+] Installazione avviata. Seguila con: virt-viewer $VM_NAME"
fi
echo "    Al termine la VM si spegne (bootstrap -> poweroff); il CD e' gia' espulso dalla config."
if [ "$FIRSTBOOT_AUTOSTART" = "true" ]; then
    echo "    Primo boot gia' avviato automaticamente."
else
    echo "    Primo boot: virsh start $VM_NAME"
fi
