#!/usr/bin/env bash
# Installazione unattended Lubuntu 24.04 LTS — lubuntu24
# Base: Ubuntu live-server 24.04.4 + autoinstall + lubuntu-desktop.
# Il lavoro vero lo fa scripts/lib/subiquity-install.sh: qui solo la config.
#
# Uso: bash scripts/install-lubuntu24.04.sh
#      echo S | bash scripts/install-lubuntu24.04.sh   (non interattivo)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/subiquity-install.sh"

VM_NAME="lubuntu24.04"
LABEL="Lubuntu 24.04"
DISK_SIZE="35G"
MEMORY="4096"
OS_VARIANTS="ubuntu24.04"
ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-24.04.4-live-server-amd64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/lubuntu-24.04.4-autoinstall.iso"
ISO_URL="https://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-live-server-amd64.iso"
AUTOINSTALL_TEMPLATE="$UNATTENDED_DIR/lubuntu24.04-autoinstall.yaml"
GRUB_AUTO_EXTRA_ARGS="fsck.mode=skip"

subiquity_install
