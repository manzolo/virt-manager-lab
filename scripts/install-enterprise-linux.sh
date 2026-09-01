#!/usr/bin/env bash
# Installazione unattended Rocky Linux / AlmaLinux via kickstart.
#
# Uso:
#   EL_DISTRO=rocky bash scripts/install-enterprise-linux.sh
#   EL_DISTRO=alma  bash scripts/install-enterprise-linux.sh
#   echo S | EL_DISTRO=rocky bash scripts/install-enterprise-linux.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lab.env"
STORAGE="$VM_BASE_DIR/storage"
# Il repo si individua dalla posizione dello script: la cartella del clone puo' chiamarsi come si vuole.
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

EL_DISTRO="${EL_DISTRO:-rocky}"
EL_MAJOR="${EL_MAJOR:-9}"
FIRSTBOOT_AUTOSTART="${FIRSTBOOT_AUTOSTART:-true}"
FIRSTBOOT_WAIT_TIMEOUT="${FIRSTBOOT_WAIT_TIMEOUT:-5400}"
DISK_SIZE="${DISK_SIZE:-40G}"
SHARED_DIR="$STORAGE/shared"
KS_TEMPLATE="$REPO_DIR/unattended/enterprise-linux.ks"

case "$EL_DISTRO" in
  rocky)
    VM_NAME="rocky${EL_MAJOR}"
    ISO_BASENAME="Rocky-${EL_MAJOR}-latest-x86_64-boot.iso"
    ISO_URL="https://dl.rockylinux.org/pub/rocky/${EL_MAJOR}/isos/x86_64/${ISO_BASENAME}"
    EL_REPO_URL="https://dl.rockylinux.org/pub/rocky/${EL_MAJOR}/BaseOS/x86_64/os/"
    OS_VARIANT="rocky${EL_MAJOR}"
    ;;
  alma|almalinux)
    VM_NAME="alma${EL_MAJOR}"
    ISO_BASENAME="AlmaLinux-${EL_MAJOR}-latest-x86_64-boot.iso"
    ISO_URL="https://repo.almalinux.org/almalinux/${EL_MAJOR}/isos/x86_64/${ISO_BASENAME}"
    EL_REPO_URL="https://repo.almalinux.org/almalinux/${EL_MAJOR}/BaseOS/x86_64/os/"
    OS_VARIANT="almalinux${EL_MAJOR}"
    ;;
  *)
    echo "EL_DISTRO non valido: $EL_DISTRO (rocky|alma)"
    exit 2
    ;;
esac

DISK_PATH="$STORAGE/hd/${VM_NAME}.qcow2"
ISO_ORIG="$STORAGE/Iso/Distro/${ISO_BASENAME}"
ISO_OEMDRV="$STORAGE/Iso/Distro/${VM_NAME}-oemdrv-ks.iso"

if [[ ! -f "$ISO_ORIG" ]]; then
    echo "ISO non trovata: $ISO_ORIG"
    read -rp "La scarico ora da $ISO_URL ? [s/N] " dl
    [[ "${dl:-N}" =~ ^[sS]$ ]] || { echo "Annullato."; exit 1; }
    mkdir -p "$(dirname "$ISO_ORIG")"
    wget --show-progress -O "$ISO_ORIG" "$ISO_URL"
fi

if virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "La VM '$VM_NAME' esiste gia'."
    read -rp "Vuoi eliminarla e reinstallare? [S/n] " risposta
    risposta="${risposta:-S}"
    [[ "$risposta" =~ ^[sS]$ ]] || { echo "Installazione annullata."; exit 0; }
    virsh destroy "$VM_NAME" 2>/dev/null || true
    virsh undefine "$VM_NAME" --snapshots-metadata --nvram 2>/dev/null || \
    virsh undefine "$VM_NAME" --snapshots-metadata 2>/dev/null || true
fi

echo "Creo il disco $DISK_PATH ($DISK_SIZE)..."
rm -f "$DISK_PATH"
qemu-img create -f qcow2 -o preallocation=off "$DISK_PATH" "$DISK_SIZE"
virsh pool-refresh hdd 2>/dev/null || true

echo "Preparo la ISO OEMDRV con kickstart..."
KS_DIR="$(mktemp -d)"
trap 'rm -rf "$KS_DIR"' EXIT
render_template "$KS_TEMPLATE" "$KS_DIR/ks.cfg"
sed -i "s|__EL_HOSTNAME__|${VM_NAME}-lab|g" "$KS_DIR/ks.cfg"
sed -i "s|__EL_REPO_URL__|${EL_REPO_URL}|g" "$KS_DIR/ks.cfg"
rm -f "$ISO_OEMDRV"
xorriso -as mkisofs -V OEMDRV -J -r -o "$ISO_OEMDRV" "$KS_DIR" >/dev/null 2>&1

echo "Creo e avvio la VM '$VM_NAME'..."
virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 2 \
    --machine q35 \
    --cpu host-passthrough \
    --os-variant "$OS_VARIANT" \
    --disk "$DISK_PATH",bus=virtio,driver.discard=unmap \
    --disk "$ISO_OEMDRV",device=cdrom \
    --cdrom "$ISO_ORIG" \
    --network network=default,model=virtio \
    --graphics spice \
    --video virtio \
    --boot uefi \
    --memorybacking source.type=memfd,access.mode=shared \
    --filesystem "source.dir=$SHARED_DIR,target.dir=shared,driver.type=virtiofs,accessmode=passthrough" \
    --controller type=scsi,model=virtio-scsi \
    --rng /dev/urandom,model=virtio \
    --memballoon model=virtio \
    --events on_reboot=restart \
    --noautoconsole \
    --noreboot

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

echo "[+] Installazione avviata: virt-viewer $VM_NAME"
