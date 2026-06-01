#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export UBUNTU_VERSION="26.04"
export UBUNTU_POINT_VERSION="26.04"
export OS_VARIANT_CANDIDATE="ubuntu26.04"
export OS_VARIANT_FALLBACK="ubuntu25.10"
export FLAVOR_ID="kubuntu26"
export FLAVOR_LABEL="Kubuntu 26.04"
export VM_NAME="kubuntu26.04"
export DESKTOP_PACKAGE="kubuntu-desktop"
export DISPLAY_MANAGER="sddm"
export SDDM_SESSION="plasma"
export LIGHTDM_SESSION="plasma"
export PLYMOUTH_PACKAGE="plymouth-theme-kubuntu-logo"
export PLYMOUTH_THEME_PATH="/usr/share/plymouth/themes/kubuntu-logo/kubuntu-logo.plymouth"
export DISK_SIZE="35G"
export MEMORY="${MEMORY:-4096}"

exec "$SCRIPT_DIR/install-ubuntu-flavor22.04.sh"
