#!/usr/bin/env bash
# Installazione unattended Lubuntu 26.04 LTS — lubuntu26
# Base: Ubuntu live-server 26.04 + autoinstall + lubuntu-desktop.
#
# Uso: bash scripts/install-lubuntu26.04.sh
#      echo S | bash scripts/install-lubuntu26.04.sh   (non interattivo)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lab.env"
STORAGE="$VM_BASE_DIR/storage"
REPO_DIR="$VM_BASE_DIR/virt-manager"

VM_NAME="lubuntu26.04"
DESKTOP_PACKAGE="lubuntu-desktop"
DISPLAY_MANAGER="sddm"
DISK_PATH="$STORAGE/hd/lubuntu26.04.qcow2"
DISK_SIZE="35G"
ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-26.04-live-server-amd64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/lubuntu-26.04-autoinstall.iso"
AUTOINSTALL_TEMPLATE="$REPO_DIR/lubuntu26.04-autoinstall.yaml"
ISO_URL="https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
SHARED_DIR="$STORAGE/shared"
FIRSTBOOT_AUTOSTART="${FIRSTBOOT_AUTOSTART:-true}"
FIRSTBOOT_WAIT_DESKTOP="${FIRSTBOOT_WAIT_DESKTOP:-$FIRSTBOOT_AUTOSTART}"
FIRSTBOOT_BASE_TIMEOUT="${FIRSTBOOT_BASE_TIMEOUT:-7200}"
FIRSTBOOT_DESKTOP_TIMEOUT="${FIRSTBOOT_DESKTOP_TIMEOUT:-14400}"
FIRSTBOOT_POLL_INTERVAL="${FIRSTBOOT_POLL_INTERVAL:-30}"

for cmd in wget xorriso qemu-img virt-install virsh; do
    command -v "$cmd" >/dev/null || { echo "Comando mancante: $cmd"; exit 1; }
done

if [[ ! -f "$AUTOINSTALL_TEMPLATE" ]]; then
    echo "Mancante: $AUTOINSTALL_TEMPLATE"
    exit 1
fi

# os-variant: 26.04 puo' non essere nel db osinfo -> fallback
if virt-install --os-variant ubuntu26.04 --print-xml &>/dev/null; then
    OS_VARIANT=ubuntu26.04
elif virt-install --os-variant ubuntu25.10 --print-xml &>/dev/null; then
    OS_VARIANT=ubuntu25.10
else
    OS_VARIANT=ubuntu24.04
fi
echo "OS variant: $OS_VARIANT"

wait_for_vm_state() {
    local expected="$1" timeout="$2" label="$3"
    local elapsed=0 state

    while (( elapsed <= timeout )); do
        state="$(LC_ALL=C virsh domstate "$VM_NAME" 2>/dev/null | head -n 1 || true)"
        if [[ "$state" == "$expected" ]]; then
            echo "$label: $state"
            return 0
        fi

        echo "$label: ${state:-non definita} (${elapsed}s/${timeout}s)"
        sleep "$FIRSTBOOT_POLL_INTERVAL"
        elapsed=$((elapsed + FIRSTBOOT_POLL_INTERVAL))
    done

    echo "Timeout aspettando '$expected' per $VM_NAME ($label)."
    return 1
}

guest_agent_ready() {
    virsh qemu-agent-command "$VM_NAME" '{"execute":"guest-ping"}' >/dev/null 2>&1
}

guest_exec_quiet() {
    local cmd="$1" encoded payload output pid status exitcode

    encoded="$(printf '%s' "$cmd" | base64 | tr -d '\n')"
    payload="{\"execute\":\"guest-exec\",\"arguments\":{\"path\":\"/bin/sh\",\"arg\":[\"-lc\",\"printf %s $encoded | base64 -d | /bin/sh\"],\"capture-output\":true}}"

    output="$(virsh qemu-agent-command "$VM_NAME" "$payload" 2>/dev/null)" || return 125
    pid="$(sed -n 's/.*"pid":\([0-9][0-9]*\).*/\1/p' <<< "$output")"
    [[ -n "$pid" ]] || return 125

    for _ in {1..60}; do
        status="$(virsh qemu-agent-command "$VM_NAME" "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$pid}}" 2>/dev/null)" || return 125
        if [[ "$status" == *'"exited":true'* ]]; then
            exitcode="$(sed -n 's/.*"exitcode":\([0-9][0-9]*\).*/\1/p' <<< "$status")"
            return "${exitcode:-1}"
        fi
        sleep 1
    done

    return 124
}

wait_for_firstboot_desktop() {
    local elapsed=0 check_cmd

    check_cmd="systemctl get-default | grep -qx graphical.target && systemctl is-active --quiet ${DISPLAY_MANAGER} && dpkg-query -W ${DESKTOP_PACKAGE} >/dev/null 2>&1 && ! systemctl is-enabled --quiet lab-desktop.service"

    while (( elapsed <= FIRSTBOOT_DESKTOP_TIMEOUT )); do
        if guest_agent_ready && guest_exec_quiet "$check_cmd"; then
            echo "Desktop first boot completato per $VM_NAME."
            return 0
        fi

        echo "Attendo desktop first boot di $VM_NAME (${elapsed}s/${FIRSTBOOT_DESKTOP_TIMEOUT}s)..."
        sleep "$FIRSTBOOT_POLL_INTERVAL"
        elapsed=$((elapsed + FIRSTBOOT_POLL_INTERVAL))
    done

    echo "Timeout aspettando il desktop first boot di $VM_NAME."
    echo "Diagnosi guest: /var/log/lab-desktop.log, /var/log/apt/term.log, systemctl status lab-desktop.service"
    return 1
}

run_firstboot_if_requested() {
    [[ "$FIRSTBOOT_AUTOSTART" == "true" ]] || return 0

    echo ""
    echo "[+] Attendo lo spegnimento dell'autoinstall base di $VM_NAME..."
    wait_for_vm_state "shut off" "$FIRSTBOOT_BASE_TIMEOUT" "Autoinstall base" || return 1

    echo "[+] Avvio $VM_NAME per installare il desktop al primo boot..."
    virsh start "$VM_NAME"

    [[ "$FIRSTBOOT_WAIT_DESKTOP" == "true" ]] || return 0
    wait_for_firstboot_desktop
}

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

echo "Preparo ISO autoinstall Lubuntu..."
rm -f "$ISO_AUTO"

GRUBCFG_TMP=$(mktemp /tmp/lubuntu-grub.cfg.XXXXX)
META_TMP=$(mktemp /tmp/lubuntu-meta.XXXXX)
AUTOINSTALL_RENDERED=$(mktemp /tmp/lubuntu26-autoinstall.XXXXX.yaml)
touch "$META_TMP"
trap 'rm -f "$GRUBCFG_TMP" "$META_TMP" "$AUTOINSTALL_RENDERED"' EXIT
render_template "$AUTOINSTALL_TEMPLATE" "$AUTOINSTALL_RENDERED"

cat > "$GRUBCFG_TMP" <<'GRUBCFG'
set default=0
set timeout=10

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Automated Lubuntu Install" {
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
    -map "$GRUBCFG_TMP"          /boot/grub/grub.cfg \
    -map "$AUTOINSTALL_RENDERED" /user-data \
    -map "$META_TMP"             /meta-data \
    -commit -eject all 2>&1 | grep -v "^xorriso : UPDATE" || true

echo "ISO pronta: $ISO_AUTO"

echo "Creo e avvio la VM '$VM_NAME'..."
virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 2 \
    --machine q35 \
    --cpu host-passthrough \
    --os-variant "$OS_VARIANT" \
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
if [[ "$FIRSTBOOT_AUTOSTART" == "true" ]]; then
    echo "    Al termine della base install la VM viene riavviata automaticamente"
    echo "    per completare il desktop al primo boot."
    run_firstboot_if_requested
else
    echo "    Al termine la VM si spegne automaticamente."
    echo "    Per avviarla: virsh start $VM_NAME"
fi
