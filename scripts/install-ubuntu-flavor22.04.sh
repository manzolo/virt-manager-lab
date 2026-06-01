#!/usr/bin/env bash
# Installer comune per flavor Ubuntu LTS basati su live-server + autoinstall.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lab.env"
STORAGE="$VM_BASE_DIR/storage"
REPO_DIR="$VM_BASE_DIR/virt-manager"

: "${FLAVOR_ID:?FLAVOR_ID non impostato}"
: "${FLAVOR_LABEL:?FLAVOR_LABEL non impostato}"
: "${VM_NAME:?VM_NAME non impostato}"
: "${DESKTOP_PACKAGE:?DESKTOP_PACKAGE non impostato}"
: "${DISPLAY_MANAGER:?DISPLAY_MANAGER non impostato}"
: "${PLYMOUTH_PACKAGE:?PLYMOUTH_PACKAGE non impostato}"
: "${PLYMOUTH_THEME_PATH:?PLYMOUTH_THEME_PATH non impostato}"

DISK_SIZE="${DISK_SIZE:-30G}"
MEMORY="${MEMORY:-2048}"
VCPUS="${VCPUS:-2}"
SDDM_SESSION="${SDDM_SESSION:-}"
LIGHTDM_SESSION="${LIGHTDM_SESSION:-}"
UBUNTU_VERSION="${UBUNTU_VERSION:-22.04}"
UBUNTU_POINT_VERSION="${UBUNTU_POINT_VERSION:-22.04.5}"
HWE_KERNEL_PACKAGE="${HWE_KERNEL_PACKAGE:-linux-generic-hwe-${UBUNTU_VERSION}}"
OS_VARIANT_CANDIDATE="${OS_VARIANT_CANDIDATE:-ubuntu${UBUNTU_VERSION}}"
OS_VARIANT_FALLBACK="${OS_VARIANT_FALLBACK:-ubuntu22.04}"
OS_VARIANT_FALLBACK2="${OS_VARIANT_FALLBACK2:-}"
DESKTOP_INSTALL_MODE="${DESKTOP_INSTALL_MODE:-packages}"

case "$DESKTOP_INSTALL_MODE" in
    packages|firstboot) ;;
    *)
        echo "DESKTOP_INSTALL_MODE non valido: $DESKTOP_INSTALL_MODE"
        echo "Valori ammessi: packages, firstboot"
        exit 1
        ;;
esac

if [[ -z "${FIRSTBOOT_AUTOSTART+x}" ]]; then
    if [[ "$DESKTOP_INSTALL_MODE" == "firstboot" ]]; then
        FIRSTBOOT_AUTOSTART="true"
    else
        FIRSTBOOT_AUTOSTART="false"
    fi
fi
FIRSTBOOT_WAIT_DESKTOP="${FIRSTBOOT_WAIT_DESKTOP:-$FIRSTBOOT_AUTOSTART}"
FIRSTBOOT_BASE_TIMEOUT="${FIRSTBOOT_BASE_TIMEOUT:-7200}"
FIRSTBOOT_DESKTOP_TIMEOUT="${FIRSTBOOT_DESKTOP_TIMEOUT:-14400}"
FIRSTBOOT_POLL_INTERVAL="${FIRSTBOOT_POLL_INTERVAL:-30}"

OS_VARIANT=""
for candidate in "$OS_VARIANT_CANDIDATE" "$OS_VARIANT_FALLBACK" "$OS_VARIANT_FALLBACK2"; do
    [[ -n "$candidate" ]] || continue
    if virt-install --os-variant "$candidate" --print-xml &>/dev/null; then
        OS_VARIANT="$candidate"
        break
    fi
done

if [[ -z "$OS_VARIANT" ]]; then
    echo "Nessun os-variant valido tra: $OS_VARIANT_CANDIDATE $OS_VARIANT_FALLBACK $OS_VARIANT_FALLBACK2"
    exit 1
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
    [[ "$DESKTOP_INSTALL_MODE" == "firstboot" ]] || return 0
    [[ "$FIRSTBOOT_AUTOSTART" == "true" ]] || return 0

    echo ""
    echo "[+] Attendo lo spegnimento dell'autoinstall base di $VM_NAME..."
    wait_for_vm_state "shut off" "$FIRSTBOOT_BASE_TIMEOUT" "Autoinstall base" || return 1

    echo "[+] Avvio $VM_NAME per installare il desktop al primo boot..."
    virsh start "$VM_NAME"

    [[ "$FIRSTBOOT_WAIT_DESKTOP" == "true" ]] || return 0
    wait_for_firstboot_desktop
}

DISK_PATH="$STORAGE/hd/$VM_NAME.qcow2"
ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-${UBUNTU_POINT_VERSION}-live-server-amd64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/$FLAVOR_ID-${UBUNTU_POINT_VERSION}-autoinstall.iso"
AUTOINSTALL_TEMPLATE="$REPO_DIR/ubuntu-flavor22.04-autoinstall.yaml"
ISO_URL="https://releases.ubuntu.com/${UBUNTU_POINT_VERSION}/ubuntu-${UBUNTU_POINT_VERSION}-live-server-amd64.iso"
SHARED_DIR="$STORAGE/shared"

for cmd in wget xorriso qemu-img virt-install virsh; do
    command -v "$cmd" >/dev/null || { echo "Comando mancante: $cmd"; exit 1; }
done

if [[ ! -f "$AUTOINSTALL_TEMPLATE" ]]; then
    echo "Mancante: $AUTOINSTALL_TEMPLATE"
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

echo "Preparo ISO autoinstall $FLAVOR_LABEL..."
rm -f "$ISO_AUTO"

GRUBCFG_TMP=$(mktemp "/tmp/$FLAVOR_ID-grub.XXXXX")
META_TMP=$(mktemp "/tmp/$FLAVOR_ID-meta.XXXXX")
AUTOINSTALL_BASE=$(mktemp "/tmp/$FLAVOR_ID-autoinstall-base.XXXXX.yaml")
AUTOINSTALL_RENDERED=$(mktemp "/tmp/$FLAVOR_ID-autoinstall.XXXXX.yaml")
AUTOINSTALL_RENDERED_TMP=$(mktemp "/tmp/$FLAVOR_ID-autoinstall.XXXXX.yaml")
AUTOINSTALL_RENDERED_TMP2=$(mktemp "/tmp/$FLAVOR_ID-autoinstall.XXXXX.yaml")
touch "$META_TMP"
trap 'rm -f "$GRUBCFG_TMP" "$META_TMP" "$AUTOINSTALL_BASE" "$AUTOINSTALL_RENDERED" "$AUTOINSTALL_RENDERED_TMP" "$AUTOINSTALL_RENDERED_TMP2"' EXIT

render_template "$AUTOINSTALL_TEMPLATE" "$AUTOINSTALL_BASE"

BASE_PACKAGES=$(cat <<EOF
    - qemu-guest-agent
    - spice-vdagent
    - openvpn
    - network-manager-openvpn
    - network-manager-openvpn-gnome
    - bind9-dnsutils
    - aspell
    - aspell-it
    - ${HWE_KERNEL_PACKAGE}
EOF
)

if [[ "$DESKTOP_INSTALL_MODE" == "packages" ]]; then
    INSTALLER_PACKAGES=$(cat <<EOF
    - ${DESKTOP_PACKAGE}
    - ${PLYMOUTH_PACKAGE}
${BASE_PACKAGES}
EOF
)
    GRAPHICAL_LATE_COMMANDS=$(cat <<EOF
    - curtin in-target -- systemctl set-default graphical.target
    - curtin in-target -- bash -c 'systemctl enable ${DISPLAY_MANAGER} || true'
    - curtin in-target -- bash -c 'if [ -n "${PLYMOUTH_THEME_PATH}" ] && [ -f "${PLYMOUTH_THEME_PATH}" ]; then update-alternatives --set default.plymouth "${PLYMOUTH_THEME_PATH}"; update-initramfs -u; fi'
EOF
)
    FIRSTBOOT_LATE_COMMANDS=""
else
    INSTALLER_PACKAGES="$BASE_PACKAGES"
    GRAPHICAL_LATE_COMMANDS=""
    FIRSTBOOT_LATE_COMMANDS=$(cat <<EOF
    - curtin in-target -- bash -c 'printf "#!/bin/sh\nexec >>/var/log/lab-desktop.log 2>&1\nset -ex\nexport DEBIAN_FRONTEND=noninteractive\nprintf \"#!/bin/sh\\nexit 101\\n\" > /usr/sbin/policy-rc.d\nchmod +x /usr/sbin/policy-rc.d\ntrap \"rm -f /usr/sbin/policy-rc.d\" EXIT\napt-get update\napt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold ${DESKTOP_PACKAGE} ${PLYMOUTH_PACKAGE}\nrm -f /usr/sbin/policy-rc.d\ntrap - EXIT\nsystemctl set-default graphical.target\nif systemctl list-unit-files ${DISPLAY_MANAGER}.service >/dev/null 2>&1; then rm -f /etc/systemd/system/display-manager.service; systemctl enable ${DISPLAY_MANAGER}; fi\nif [ -n \"${PLYMOUTH_THEME_PATH}\" ] && [ -f \"${PLYMOUTH_THEME_PATH}\" ] && update-alternatives --query default.plymouth >/dev/null 2>&1; then update-alternatives --set default.plymouth \"${PLYMOUTH_THEME_PATH}\"; update-initramfs -u; fi\nsystemctl disable lab-desktop.service\nsystemctl reboot\n" > /usr/local/sbin/lab-desktop.sh; chmod +x /usr/local/sbin/lab-desktop.sh'
    - curtin in-target -- bash -c 'printf "[Unit]\nDescription=Lab desktop first boot install\nAfter=network-online.target\nWants=network-online.target\n\n[Service]\nType=oneshot\nExecStart=/usr/local/sbin/lab-desktop.sh\nRemainAfterExit=yes\nTimeoutStartSec=0\n\n[Install]\nWantedBy=multi-user.target\n" > /etc/systemd/system/lab-desktop.service; systemctl enable lab-desktop.service'
EOF
)
fi

sed \
    -e "s|__FLAVOR_HOSTNAME__|${FLAVOR_ID}|g" \
    -e "s|__DISPLAY_MANAGER__|${DISPLAY_MANAGER}|g" \
    -e "s|__SDDM_SESSION__|${SDDM_SESSION}|g" \
    -e "s|__LIGHTDM_SESSION__|${LIGHTDM_SESSION}|g" \
    -e "s|__PLYMOUTH_THEME_PATH__|${PLYMOUTH_THEME_PATH}|g" \
    -e "/__INSTALLER_PACKAGES__/{
        r /dev/stdin
        d
    }" \
    "$AUTOINSTALL_BASE" > "$AUTOINSTALL_RENDERED_TMP" <<< "$INSTALLER_PACKAGES"

sed \
    -e "/__GRAPHICAL_LATE_COMMANDS__/{
        r /dev/stdin
        d
    }" \
    "$AUTOINSTALL_RENDERED_TMP" > "$AUTOINSTALL_RENDERED_TMP2" <<< "$GRAPHICAL_LATE_COMMANDS"

sed \
    -e "/__FIRSTBOOT_LATE_COMMANDS__/{
        r /dev/stdin
        d
    }" \
    "$AUTOINSTALL_RENDERED_TMP2" > "$AUTOINSTALL_RENDERED" <<< "$FIRSTBOOT_LATE_COMMANDS"

cat > "$GRUBCFG_TMP" <<GRUBCFG
set default=0
set timeout=10

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Automated $FLAVOR_LABEL Install" {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\\;s=/cdrom/ fsck.mode=skip quiet splash ---
    initrd  /casper/initrd
}
menuentry "Ubuntu Server Install (manual)" {
    set gfxpayload=keep
    linux   /casper/vmlinuz quiet ---
    initrd  /casper/initrd
}
if [ "\$grub_platform" = "efi" ]; then
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
    --memory "$MEMORY" \
    --vcpus "$VCPUS" \
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
if [[ "$DESKTOP_INSTALL_MODE" == "firstboot" && "$FIRSTBOOT_AUTOSTART" == "true" ]]; then
    echo "    Al termine della base install la VM viene riavviata automaticamente"
    echo "    per completare il desktop al primo boot."
    run_firstboot_if_requested
else
    echo "    Al termine la VM si spegne automaticamente."
    echo "    Per avviarla: virsh start $VM_NAME"
fi
