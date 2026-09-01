#!/usr/bin/env bash
# Installazione unattended Lubuntu 22.04 LTS — lubuntu22
# Base: Ubuntu live-server 22.04.5 + autoinstall + lubuntu-desktop.
# Il lavoro vero lo fa scripts/lib/subiquity-install.sh: qui solo la config.
#
# Uso: bash scripts/install-lubuntu22.04.sh
#      echo S | bash scripts/install-lubuntu22.04.sh   (non interattivo)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/subiquity-install.sh"

VM_NAME="lubuntu22.04"
LABEL="Lubuntu 22.04"
DISK_SIZE="30G"
MEMORY="2048"
OS_VARIANTS="ubuntu22.04"
ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-22.04.5-live-server-amd64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/lubuntu-22.04.5-autoinstall.iso"
ISO_URL="https://releases.ubuntu.com/22.04.5/ubuntu-22.04.5-live-server-amd64.iso"
AUTOINSTALL_TEMPLATE="$UNATTENDED_DIR/lubuntu22.04-autoinstall.yaml"
GRUB_AUTO_EXTRA_ARGS="fsck.mode=skip"

subiquity_install
