#!/usr/bin/env bash
# =============================================================================
# Motore comune dei flavor Ubuntu LTS (Kubuntu, Xubuntu, MATE, Budgie) su base
# live-server + autoinstall. Vale per 22.04, 24.04 e 26.04: e' invocato dai 12
# wrapper scripts/install-{kubuntu,xubuntu,mate,budgie}NN.04.sh, che si limitano
# a esportare le variabili sotto e a fare exec di questo file.
#
# Rispetto a scripts/lib/subiquity-install.sh (che fa ISO + VM + first boot),
# qui sta solo cio' che e' specifico dei flavor: la GENERAZIONE del template
# autoinstall, cioe' la lista pacchetti e le late-commands, che cambiano fra
# modalita' 'packages' (desktop dentro curtin) e 'firstboot' (desktop al primo
# avvio).
#
# Variabili attese dai wrapper: FLAVOR_ID, FLAVOR_LABEL, VM_NAME,
# DESKTOP_PACKAGE, DISPLAY_MANAGER, PLYMOUTH_PACKAGE, PLYMOUTH_THEME_PATH,
# UBUNTU_VERSION, UBUNTU_POINT_VERSION, OS_VARIANT_CANDIDATE/_FALLBACK/_FALLBACK2,
# DISK_SIZE, MEMORY, e opzionali SDDM_SESSION, LIGHTDM_SESSION,
# DESKTOP_INSTALL_MODE (packages|firstboot).
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/subiquity-install.sh"

: "${FLAVOR_ID:?FLAVOR_ID non impostato}"
: "${FLAVOR_LABEL:?FLAVOR_LABEL non impostato}"
: "${VM_NAME:?VM_NAME non impostato}"
: "${DESKTOP_PACKAGE:?DESKTOP_PACKAGE non impostato}"
: "${DISPLAY_MANAGER:?DISPLAY_MANAGER non impostato}"
: "${PLYMOUTH_PACKAGE:?PLYMOUTH_PACKAGE non impostato}"
: "${PLYMOUTH_THEME_PATH:?PLYMOUTH_THEME_PATH non impostato}"

SDDM_SESSION="${SDDM_SESSION:-}"
LIGHTDM_SESSION="${LIGHTDM_SESSION:-}"
UBUNTU_VERSION="${UBUNTU_VERSION:-22.04}"
UBUNTU_POINT_VERSION="${UBUNTU_POINT_VERSION:-22.04.5}"
HWE_KERNEL_PACKAGE="${HWE_KERNEL_PACKAGE:-linux-generic-hwe-${UBUNTU_VERSION}}"

# --- configurazione passata al motore condiviso -------------------------------
LABEL="$FLAVOR_LABEL"
DISK_SIZE="${DISK_SIZE:-30G}"
MEMORY="${MEMORY:-2048}"
VCPUS="${VCPUS:-2}"
OS_VARIANTS="${OS_VARIANT_CANDIDATE:-ubuntu${UBUNTU_VERSION}} ${OS_VARIANT_FALLBACK:-ubuntu22.04} ${OS_VARIANT_FALLBACK2:-}"
ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-${UBUNTU_POINT_VERSION}-live-server-amd64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/$FLAVOR_ID-${UBUNTU_POINT_VERSION}-autoinstall.iso"
ISO_URL="https://releases.ubuntu.com/${UBUNTU_POINT_VERSION}/ubuntu-${UBUNTU_POINT_VERSION}-live-server-amd64.iso"
AUTOINSTALL_TEMPLATE="$UNATTENDED_DIR/ubuntu-flavor-autoinstall.yaml"
GRUB_AUTO_EXTRA_ARGS="fsck.mode=skip"

# -----------------------------------------------------------------------------
# Hook chiamato dal motore: rende il template sostituendo i tre blocchi
# __INSTALLER_PACKAGES__, __GRAPHICAL_LATE_COMMANDS__ e __FIRSTBOOT_LATE_COMMANDS__.
# (Il template da solo non e' YAML valido: lo diventa dopo questa sostituzione.)
# -----------------------------------------------------------------------------
render_autoinstall() {
    local src="$1" dst="$2"
    local base tmp1 tmp2
    mktemp_tracked base "/tmp/$FLAVOR_ID-autoinstall-base.XXXXX.yaml"
    mktemp_tracked tmp1 "/tmp/$FLAVOR_ID-autoinstall-1.XXXXX.yaml"
    mktemp_tracked tmp2 "/tmp/$FLAVOR_ID-autoinstall-2.XXXXX.yaml"

    render_template "$src" "$base"

    local BASE_PACKAGES INSTALLER_PACKAGES GRAPHICAL_LATE_COMMANDS FIRSTBOOT_LATE_COMMANDS
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
        "$base" > "$tmp1" <<< "$INSTALLER_PACKAGES"

    sed \
        -e "/__GRAPHICAL_LATE_COMMANDS__/{
            r /dev/stdin
            d
        }" \
        "$tmp1" > "$tmp2" <<< "$GRAPHICAL_LATE_COMMANDS"

    sed \
        -e "/__FIRSTBOOT_LATE_COMMANDS__/{
            r /dev/stdin
            d
        }" \
        "$tmp2" > "$dst" <<< "$FIRSTBOOT_LATE_COMMANDS"
}

subiquity_install
