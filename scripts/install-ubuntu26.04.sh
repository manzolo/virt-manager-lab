#!/usr/bin/env bash
# Installazione unattended Ubuntu 26.04 LTS — ubuntu26
# GNOME, openvpn, virtiofs host_shared. Base: ISO desktop + autoinstall.
# Il lavoro vero lo fa scripts/lib/subiquity-install.sh: qui solo la config.
#
# Uso: bash scripts/install-ubuntu26.04.sh
#      echo S | bash scripts/install-ubuntu26.04.sh   (non interattivo)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/subiquity-install.sh"

VM_NAME="ubuntu26.04"
LABEL="Ubuntu 26.04"
DISK_SIZE="40G"
# 26.04 puo' non essere ancora nel db osinfo: si ripiega su 25.10.
OS_VARIANTS="ubuntu26.04 ubuntu25.10"
ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-26.04-desktop-amd64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/ubuntu-26.04-autoinstall.iso"
ISO_URL="https://releases.ubuntu.com/26.04/ubuntu-26.04-desktop-amd64.iso"
AUTOINSTALL_TEMPLATE="$UNATTENDED_DIR/ubuntu26.04-autoinstall.yaml"
GRUB_MANUAL_LABEL="Try or Install Ubuntu (manual)"
GRUB_MANUAL_ARGS="quiet splash ---"

subiquity_install
