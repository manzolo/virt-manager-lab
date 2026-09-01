#!/usr/bin/env bash
# Installazione unattended Ubuntu 24.04 LTS (Noble) — ubuntu24
# GNOME 46, openvpn, virtiofs host_shared. Base: ISO desktop + autoinstall.
# Il lavoro vero lo fa scripts/lib/subiquity-install.sh: qui solo la config.
#
# Uso: bash scripts/install-ubuntu24.04.sh
#      echo S | bash scripts/install-ubuntu24.04.sh   (non interattivo)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/subiquity-install.sh"

VM_NAME="ubuntu24.04"
LABEL="Ubuntu 24.04"
DISK_SIZE="40G"
OS_VARIANTS="ubuntu24.04"
ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-24.04.3-desktop-amd64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/ubuntu-24.04.3-autoinstall.iso"
ISO_URL="https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-desktop-amd64.iso"
AUTOINSTALL_TEMPLATE="$UNATTENDED_DIR/ubuntu24.04-autoinstall.yaml"
GRUB_MANUAL_LABEL="Try or Install Ubuntu (manual)"
GRUB_MANUAL_ARGS="quiet splash ---"

subiquity_install
