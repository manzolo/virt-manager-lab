#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export UBUNTU_VERSION="24.04"
export UBUNTU_POINT_VERSION="24.04.4"
export OS_VARIANT_CANDIDATE="ubuntu24.04"
export OS_VARIANT_FALLBACK="ubuntu24.04"
export FLAVOR_ID="budgie24"
export FLAVOR_LABEL="Ubuntu Budgie 24.04"
export VM_NAME="ubuntu-budgie24.04"
export DESKTOP_PACKAGE="ubuntu-budgie-desktop"
export DISPLAY_MANAGER="lightdm"
export LIGHTDM_SESSION="ubuntu-budgie-desktop"
export PLYMOUTH_PACKAGE="plymouth-theme-ubuntu-budgie-logo"
export PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/ubuntu-budgie-logo/ubuntu-budgie-logo.plymouth"
export DISK_SIZE="30G"
export MEMORY="${MEMORY:-4096}"

exec "$SCRIPT_DIR/install-ubuntu-flavor22.04.sh"
