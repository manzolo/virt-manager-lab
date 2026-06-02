#!/usr/bin/env bash
# Installazione unattended Arch + niri (compositor Wayland) + noctalia (shell).
# Wrapper su install-arch.sh con profilo 'niri' (sddm + autologin niri-session;
# noctalia buildato da AUR al primo boot). VM creata: 'niri'.
#
# STATO: first-draft sperimentale (vedi docs/new-distros.md).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec env ARCH_PROFILE=niri bash "$SCRIPT_DIR/install-arch.sh" "$@"
