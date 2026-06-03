#!/usr/bin/env bash
# Installazione unattended openSUSE Tumbleweed via AutoYaST.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lab.env"
STORAGE="$VM_BASE_DIR/storage"
REPO_DIR="$VM_BASE_DIR/virt-manager"

VM_NAME="tumbleweed"
FIRSTBOOT_AUTOSTART="${FIRSTBOOT_AUTOSTART:-true}"
FIRSTBOOT_WAIT_TIMEOUT="${FIRSTBOOT_WAIT_TIMEOUT:-5400}"
DISK_PATH="$STORAGE/hd/${VM_NAME}.qcow2"
DISK_SIZE="${DISK_SIZE:-40G}"
ISO_ORIG="$STORAGE/Iso/Distro/openSUSE-Tumbleweed-DVD-x86_64-Current.iso"
ISO_AUTOYAST="$STORAGE/Iso/Distro/${VM_NAME}-autoyast.iso"
ISO_URL="https://download.opensuse.org/tumbleweed/iso/openSUSE-Tumbleweed-DVD-x86_64-Current.iso"
SHARED_DIR="$STORAGE/shared"
AY_TEMPLATE="$REPO_DIR/tumbleweed-autoyast.xml"

if [[ ! -f "$ISO_ORIG" ]]; then
    echo "ISO Tumbleweed non trovata: $ISO_ORIG"
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

echo "Preparo la ISO AutoYaST..."
AY_DIR="$(mktemp -d)"
trap 'rm -rf "$AY_DIR"' EXIT
render_template "$AY_TEMPLATE" "$AY_DIR/autoinst.xml"
if [[ -f /tmp/tumbleweed-schema/usr/share/YaST2/schema/autoyast/rng/profile.rng ]]; then
    xmllint --noout --relaxng /tmp/tumbleweed-schema/usr/share/YaST2/schema/autoyast/rng/profile.rng "$AY_DIR/autoinst.xml"
fi
rm -f "$ISO_AUTOYAST"
xorriso -as mkisofs -V OEMDRV -J -r -o "$ISO_AUTOYAST" "$AY_DIR" >/dev/null 2>&1

echo "Creo e avvio la VM '$VM_NAME'..."
virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 2 \
    --machine q35 \
    --cpu host-passthrough \
    --os-variant "opensusetumbleweed" \
    --disk "$DISK_PATH",bus=virtio,driver.discard=unmap \
    --disk "$ISO_ORIG",device=cdrom \
    --disk "$ISO_AUTOYAST",device=cdrom \
    --location "$ISO_ORIG" \
    --extra-args "autoyast=cd:///autoinst.xml ifcfg=*=dhcp netsetup=dhcp console=ttyS0,115200 console=tty0" \
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

# I media AutoYaST servono solo durante l'installazione. Li lasciamo nel runtime
# corrente, ma li togliamo dalla configurazione persistente per il boot da disco.
for tgt in $(virsh domblklist "$VM_NAME" 2>/dev/null | awk -v iso="$ISO_ORIG" '$2 == iso {print $1}'); do
    virsh change-media "$VM_NAME" "$tgt" --eject --config >/dev/null 2>&1 || true
done
for tgt in $(virsh domblklist "$VM_NAME" 2>/dev/null | awk -v iso="$ISO_AUTOYAST" '$2 == iso {print $1}'); do
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

echo "[+] Installazione avviata: virt-viewer $VM_NAME"
