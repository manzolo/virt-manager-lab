#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export FLAVOR_ID="kubuntu22"
export FLAVOR_LABEL="Kubuntu 22.04"
export VM_NAME="kubuntu22.04"
export DESKTOP_PACKAGE="kubuntu-desktop"
export DISPLAY_MANAGER="sddm"
export SDDM_SESSION="plasma"
export PLYMOUTH_PACKAGE="plymouth-theme-kubuntu-logo"
export PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/kubuntu-logo/kubuntu-logo.plymouth"
export DISK_SIZE="35G"
export MEMORY="3072"

exec "$SCRIPT_DIR/install-ubuntu-flavor22.04.sh"
