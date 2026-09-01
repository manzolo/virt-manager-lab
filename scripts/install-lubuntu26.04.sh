#!/usr/bin/env bash
# Installazione unattended Lubuntu 26.04 LTS — lubuntu26
# Base: Ubuntu live-server 26.04 + autoinstall + lubuntu-desktop.
# Il lavoro vero lo fa scripts/lib/subiquity-install.sh: qui solo la config.
#
# Uso: bash scripts/install-lubuntu26.04.sh
#      echo S | bash scripts/install-lubuntu26.04.sh   (non interattivo)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/subiquity-install.sh"

VM_NAME="lubuntu26.04"
LABEL="Lubuntu 26.04"
DISK_SIZE="35G"
MEMORY="4096"
OS_VARIANTS="ubuntu26.04 ubuntu25.10 ubuntu24.04"
ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-26.04-live-server-amd64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/lubuntu-26.04-autoinstall.iso"
ISO_URL="https://releases.ubuntu.com/26.04/ubuntu-26.04-live-server-amd64.iso"
AUTOINSTALL_TEMPLATE="$UNATTENDED_DIR/lubuntu26.04-autoinstall.yaml"
GRUB_AUTO_EXTRA_ARGS="fsck.mode=skip"

# Il kernel dell'installer live 26.04 va in crash con overlayfs installando il
# desktop dentro curtin: si installa base+tool e il desktop al primo boot.
DESKTOP_INSTALL_MODE="firstboot"
DESKTOP_PACKAGE="lubuntu-desktop"
DISPLAY_MANAGER="sddm"

subiquity_install
