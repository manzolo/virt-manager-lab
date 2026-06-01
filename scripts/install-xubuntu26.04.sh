#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export UBUNTU_VERSION="26.04"
export UBUNTU_POINT_VERSION="26.04"
export OS_VARIANT_CANDIDATE="ubuntu26.04"
export OS_VARIANT_FALLBACK="ubuntu25.10"
export FLAVOR_ID="xubuntu26"
export FLAVOR_LABEL="Xubuntu 26.04"
export VM_NAME="xubuntu26.04"
export DESKTOP_PACKAGE="xubuntu-desktop"
export DISPLAY_MANAGER="lightdm"
export LIGHTDM_SESSION="xubuntu"
export PLYMOUTH_PACKAGE="plymouth-theme-xubuntu-logo"
export PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/xubuntu-logo/xubuntu-logo.plymouth"
export DISK_SIZE="30G"
export MEMORY="${MEMORY:-4096}"

exec "$SCRIPT_DIR/install-ubuntu-flavor22.04.sh"
