#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export FLAVOR_ID="xubuntu22"
export FLAVOR_LABEL="Xubuntu 22.04"
export VM_NAME="xubuntu22.04"
export DESKTOP_PACKAGE="xubuntu-desktop"
export DISPLAY_MANAGER="lightdm"
export PLYMOUTH_PACKAGE="plymouth-theme-xubuntu-logo"
export PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/xubuntu-logo/xubuntu-logo.plymouth"
export DISK_SIZE="30G"
export MEMORY="2048"

exec "$SCRIPT_DIR/install-ubuntu-flavor22.04.sh"
