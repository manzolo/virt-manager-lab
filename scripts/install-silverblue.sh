#!/usr/bin/env bash
# Installazione unattended Fedora Silverblue (GNOME immutabile) — silverblue
# Meccanismo: kickstart consegnato ad Anaconda via volume OEMDRV (ks.cfg).
# L'ISO Fedora originale NON viene modificata.
#
# Contratto e2e: install -> poweroff -> virsh start -> qemu-guest-agent ->
# graphical.target + gdm. (qemu-guest-agent e' layerato al primo boot, vedi .ks.)
#
# Uso: bash scripts/install-silverblue.sh
#      echo S | bash scripts/install-silverblue.sh   (non interattivo)
#
# STATO: first-draft, da validare al primo run reale (vedi docs/new-distros.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lab.env"
STORAGE="$VM_BASE_DIR/storage"
REPO_DIR="$VM_BASE_DIR/virt-manager"

VM_NAME="silverblue"
FIRSTBOOT_AUTOSTART="${FIRSTBOOT_AUTOSTART:-true}"
FIRSTBOOT_WAIT_TIMEOUT="${FIRSTBOOT_WAIT_TIMEOUT:-5400}"
DISK_PATH="$STORAGE/hd/silverblue.qcow2"
DISK_SIZE="40G"
FED_VER="${FED_VER:-44}"
FED_BUILD="${FED_BUILD:-1.7}"
ISO_ORIG="$STORAGE/Iso/Distro/Fedora-Silverblue-ostree-x86_64-${FED_VER}.iso"
ISO_OEMDRV="$STORAGE/Iso/Distro/silverblue-oemdrv-ks.iso"
KS_TEMPLATE="$REPO_DIR/fedora-silverblue.ks"
SHARED_DIR="$STORAGE/shared"
ISO_URL="https://dl.fedoraproject.org/pub/fedora/linux/releases/${FED_VER}/Silverblue/x86_64/iso/Fedora-Silverblue-ostree-x86_64-${FED_VER}-${FED_BUILD}.iso"

# --------------------------------------------------------------------------
# 1. ISO originale
# --------------------------------------------------------------------------
if [[ ! -f "$ISO_ORIG" ]]; then
    echo "ISO Silverblue non trovata: $ISO_ORIG"
    echo "Scaricala (es.) da: $ISO_URL"
    echo "e salvala come: $ISO_ORIG"
    read -rp "Provo a scaricarla ora? [s/N] " dl
    [[ "${dl:-N}" =~ ^[sS]$ ]] || { echo "Annullato."; exit 1; }
    mkdir -p "$(dirname "$ISO_ORIG")"
    wget --show-progress -O "$ISO_ORIG" "$ISO_URL"
fi

# --------------------------------------------------------------------------
# 2. VM esistente (default: S)
# --------------------------------------------------------------------------
if virsh dominfo "$VM_NAME" &>/dev/null; then
    echo "La VM '$VM_NAME' esiste gia'."
    read -rp "Vuoi eliminarla e reinstallare? [S/n] " risposta
    risposta="${risposta:-S}"
    [[ "$risposta" =~ ^[sS]$ ]] || { echo "Installazione annullata."; exit 0; }
    echo "Fermo e rimuovo la VM..."
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
# 4. Determina il ref ostree (best-effort dalla ISO, fallback su FED_VER)
# --------------------------------------------------------------------------
OSTREE_REF="fedora/${FED_VER}/x86_64/silverblue"
REFS_TMP="$(mktemp -d)"
if xorriso -osirrox on -indev "$ISO_ORIG" \
        -extract /ostree/repo/refs/heads "$REFS_TMP" 2>/dev/null; then
    found="$(find "$REFS_TMP" -type f -path '*silverblue*' | head -n1 || true)"
    if [[ -n "$found" ]]; then
        OSTREE_REF="${found#"$REFS_TMP"/}"
        echo "Ref ostree rilevato dalla ISO: $OSTREE_REF"
    fi
fi
rm -rf "$REFS_TMP"
echo "Uso ref ostree: $OSTREE_REF"

# --------------------------------------------------------------------------
# 5. Costruisce la mini-ISO OEMDRV con ks.cfg
# --------------------------------------------------------------------------
echo "Preparo la ISO OEMDRV con il kickstart..."
KS_DIR="$(mktemp -d)"
trap 'rm -rf "$KS_DIR"' EXIT
render_template "$KS_TEMPLATE" "$KS_DIR/ks.cfg"
sed -i "s|__OSTREE_REF__|${OSTREE_REF}|g" "$KS_DIR/ks.cfg"
rm -f "$ISO_OEMDRV"
# Il label DEVE essere OEMDRV perche' Anaconda carichi ks.cfg in automatico.
xorriso -as mkisofs -V OEMDRV -J -r -o "$ISO_OEMDRV" "$KS_DIR" >/dev/null 2>&1
echo "ISO OEMDRV pronta: $ISO_OEMDRV"

# --------------------------------------------------------------------------
# 6. Crea e avvia la VM
# --------------------------------------------------------------------------
echo "Creo e avvio la VM '$VM_NAME'..."
virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 2 \
    --machine q35 \
    --cpu host-passthrough \
    --os-variant "fedora-rawhide" \
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

echo ""
echo "[+] Installazione avviata. Seguila con: virt-viewer $VM_NAME"
echo "    Al termine la VM si spegne (--noreboot)."
if [ "$FIRSTBOOT_AUTOSTART" = "true" ]; then
    echo "    Primo boot gia' avviato automaticamente (layer qemu-guest-agent + 1 reboot)."
else
    echo "    Primo boot: 'virsh start $VM_NAME' (layer qemu-guest-agent + 1 reboot)."
fi
