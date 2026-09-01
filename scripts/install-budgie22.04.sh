#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export FLAVOR_ID="budgie22"
export FLAVOR_LABEL="Ubuntu Budgie 22.04"
export VM_NAME="ubuntu-budgie22.04"
export DESKTOP_PACKAGE="ubuntu-budgie-desktop"
export DISPLAY_MANAGER="lightdm"
export LIGHTDM_SESSION="ubuntu-budgie-desktop"
export PLYMOUTH_PACKAGE="plymouth-theme-ubuntu-budgie-logo"
export PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/ubuntu-budgie-logo/ubuntu-budgie-logo.plymouth"
export DISK_SIZE="30G"
export MEMORY="${MEMORY:-4096}"

exec "$SCRIPT_DIR/install-ubuntu-flavor.sh"
