#!/usr/bin/env bash
# Crea la VM Windows 11 con installazione non presidiata.
#
# Strategia ISO:
#   - estrae la ISO originale di Windows 11;
#   - integra autounattend.xml alla radice;
#   - ricrea una ISO avviabile con efisys_noprompt.bin, evitando
#     "Press any key to boot from CD/DVD" e i puntini in attesa input;
#   - usa ordine boot hd,cdrom: il disco vuoto cade sul CD al primo boot,
#     poi i riavvii continuano dal disco installato.
#
# Uso: bash scripts/win11/create_win11_vm.sh
#      bash scripts/win11/create_win11_vm.sh --iso-only
#      echo S | bash scripts/win11/create_win11_vm.sh   (non interattivo)

set -euo pipefail

VM_NAME="Windows11"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../scripts/lab.env"
STORAGE="$VM_BASE_DIR/storage"

ISO_ORIG="$STORAGE/Iso/Windows/Win11_24H2_Italian_x64.iso"
ISO_AUTO="$STORAGE/Iso/Windows/Win11_24H2_Italian_x64-autounattend-noprompt.iso"
ISO_VIRTIO="$STORAGE/Iso/addons/virtio-win-0.1.285.iso"
DISK="$STORAGE/hd/Windows11.qcow2"
DISK_SIZE="60G"
AUTOUNATTEND="$SCRIPT_DIR/autounattend.xml"
SHARED_DIR="$STORAGE/shared"
BUILD_DIR="/tmp/win11-iso-build"
ISO_ONLY=0

if [[ "${1:-}" == "--iso-only" ]]; then
    ISO_ONLY=1
elif [[ $# -gt 0 ]]; then
    echo "Uso: $0 [--iso-only]"
    exit 1
fi

for cmd in 7z xorriso qemu-img virt-install virsh; do
    command -v "$cmd" >/dev/null || { echo "Comando mancante: $cmd"; exit 1; }
done

for f in "$ISO_ORIG" "$ISO_VIRTIO" "$AUTOUNATTEND" "$SHARED_DIR/winfsp-2.0.23075.msi"; do
    [[ -f "$f" ]] || { echo "Mancante: $f"; exit 1; }
done

echo "[*] Preparo ISO Windows 11 unattended senza prompt di boot..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
7z x -y "-o$BUILD_DIR" "$ISO_ORIG" >/dev/null
AUTOUNATTEND_RENDERED=$(mktemp /tmp/win11-autounattend.XXXXX.xml)
trap 'rm -f "$AUTOUNATTEND_RENDERED"' EXIT
render_template "$AUTOUNATTEND" "$AUTOUNATTEND_RENDERED"
cp "$AUTOUNATTEND_RENDERED" "$BUILD_DIR/autounattend.xml"
mkdir -p "$BUILD_DIR/tools"
cp "$SHARED_DIR/winfsp-2.0.23075.msi" "$BUILD_DIR/tools/winfsp-2.0.23075.msi"

if [[ -f "$BUILD_DIR/efi/microsoft/boot/efisys_noprompt.bin" ]]; then
    EFI_BOOT_IMAGE="efi/microsoft/boot/efisys_noprompt.bin"
else
    echo "Attenzione: efisys_noprompt.bin non trovato, uso efisys.bin."
    EFI_BOOT_IMAGE="efi/microsoft/boot/efisys.bin"
fi

if [[ -f "$BUILD_DIR/boot/bootfix.bin" ]]; then
    : > "$BUILD_DIR/boot/bootfix.bin"
fi

rm -f "$ISO_AUTO"
xorriso -as mkisofs \
    -iso-level 3 \
    -J \
    -joliet-long \
    -relaxed-filenames \
    -V "CCCOMA_X64FRE_IT-IT_DV9" \
    -o "$ISO_AUTO" \
    -b boot/etfsboot.com \
    -no-emul-boot \
    -boot-load-size 8 \
    -eltorito-alt-boot \
    -e "$EFI_BOOT_IMAGE" \
    -no-emul-boot \
    "$BUILD_DIR" >/dev/null

rm -rf "$BUILD_DIR"
echo "    -> $ISO_AUTO"

if [[ "$ISO_ONLY" -eq 1 ]]; then
    echo "[+] ISO pronta. Nessuna VM creata perche' e' stato usato --iso-only."
    exit 0
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

echo "[*] Creo disco $DISK ($DISK_SIZE)..."
rm -f "$DISK"
qemu-img create -f qcow2 -o preallocation=off "$DISK" "$DISK_SIZE"
virsh pool-refresh hdd 2>/dev/null || true

echo "[*] Creo e avvio VM $VM_NAME..."
virt-install \
    --name "$VM_NAME" \
    --memory 8192 \
    --vcpus 4 \
    --os-variant win11 \
    --machine q35 \
    --cpu host-passthrough \
    --boot loader=/usr/share/OVMF/OVMF_CODE_4M.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/OVMF_VARS_4M.fd,hd,cdrom \
    --disk path="$DISK",bus=virtio,format=qcow2,discard=unmap \
    --disk path="$ISO_AUTO",device=cdrom,bus=sata \
    --disk path="$ISO_VIRTIO",device=cdrom,bus=sata \
    --filesystem source="$SHARED_DIR",target=shared,driver.type=virtiofs \
    --memorybacking source.type=memfd,access.mode=shared \
    --network network=default,model=virtio \
    --tpm emulator,model=tpm-crb,version=2.0 \
    --graphics spice,listen=none \
    --video qxl \
    --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
    --noautoconsole

echo ""
echo "[+] VM $VM_NAME avviata, installazione in corso."
echo "    Connettiti con: virt-viewer $VM_NAME"
echo ""
echo "    La ISO generata non chiede piu' di premere un tasto."
echo "    Ai riavvii successivi il boot passa al disco Windows."
