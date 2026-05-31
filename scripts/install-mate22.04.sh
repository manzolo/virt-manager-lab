#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export FLAVOR_ID="mate22"
export FLAVOR_LABEL="Ubuntu MATE 22.04"
export VM_NAME="ubuntu-mate22.04"
export DESKTOP_PACKAGE="ubuntu-mate-desktop"
export DISPLAY_MANAGER="lightdm"
export PLYMOUTH_PACKAGE="plymouth-theme-ubuntu-mate-logo"
export PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/ubuntu-mate-logo/ubuntu-mate-logo.plymouth"
export DISK_SIZE="30G"
export MEMORY="2048"

exec "$SCRIPT_DIR/install-ubuntu-flavor22.04.sh"
