#!/usr/bin/env bash
# Installazione unattended Lubuntu 20.04 LTS — lubuntu20
# Base: Ubuntu live-server 20.04.6 + autoinstall + lubuntu-desktop.
# Il lavoro vero lo fa scripts/lib/subiquity-install.sh: qui solo la config.
#
# Uso: bash scripts/install-lubuntu20.04.sh
#      echo S | bash scripts/install-lubuntu20.04.sh   (non interattivo)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/subiquity-install.sh"

VM_NAME="lubuntu20.04"
LABEL="Lubuntu 20.04"
DISK_SIZE="25G"
MEMORY="2048"
OS_VARIANTS="ubuntu20.04"
ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-20.04.6-live-server-amd64.iso"
ISO_AUTO="$STORAGE/Iso/Distro/lubuntu-20.04.6-autoinstall.iso"
ISO_URL="https://releases.ubuntu.com/20.04.6/ubuntu-20.04.6-live-server-amd64.iso"
AUTOINSTALL_TEMPLATE="$UNATTENDED_DIR/lubuntu20.04-autoinstall.yaml"
GRUB_AUTO_EXTRA_ARGS="fsck.mode=skip"

subiquity_install
