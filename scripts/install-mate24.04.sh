#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export UBUNTU_VERSION="24.04"
export UBUNTU_POINT_VERSION="24.04.4"
export OS_VARIANT_CANDIDATE="ubuntu24.04"
export OS_VARIANT_FALLBACK="ubuntu24.04"
export FLAVOR_ID="mate24"
export FLAVOR_LABEL="Ubuntu MATE 24.04"
export VM_NAME="ubuntu-mate24.04"
export DESKTOP_PACKAGE="ubuntu-mate-desktop"
export DISPLAY_MANAGER="lightdm"
export LIGHTDM_SESSION="mate"
export PLYMOUTH_PACKAGE="plymouth-theme-ubuntu-mate-logo"
export PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/ubuntu-mate-logo/ubuntu-mate-logo.plymouth"
export DISK_SIZE="30G"
export MEMORY="${MEMORY:-4096}"

exec "$SCRIPT_DIR/install-ubuntu-flavor.sh"
