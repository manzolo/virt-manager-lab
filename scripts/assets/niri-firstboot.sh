#!/usr/bin/env bash
# Setup una-tantum di niri + noctalia al primo boot (servizio niri-firstboot.service).
# noctalia/quickshell non sono nei repo ufficiali -> build da AUR con paru come utente.
# Placeholder __VM_USER__ reso da arch-bootstrap.sh durante l'install.
#
# STATO: first-draft sperimentale (vedi docs/new-distros.md): la build AUR non
# presidiata e' la parte piu' fragile.

set -uo pipefail
USERNAME="__VM_USER__"
MARK=/var/lib/niri-firstboot-done

log() { echo "[niri-firstboot] $*"; }

# Attendi rete.
for _ in $(seq 1 30); do ping -c1 -W2 archlinux.org >/dev/null 2>&1 && break; sleep 5; done

# Helper AUR (paru) come utente non-root, build noctalia + quickshell.
sudo -u "$USERNAME" bash -euo pipefail <<'USER'
cd "$HOME"
export MAKEFLAGS="-j$(nproc)"
if ! command -v paru >/dev/null 2>&1; then
  rm -rf /tmp/paru-bin && git clone --depth=1 https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
  ( cd /tmp/paru-bin && makepkg -si --noconfirm )
fi
# noctalia: nome pacchetto AUR da verificare (es. noctalia-shell / noctalia-git).
paru -S --noconfirm --needed quickshell || paru -S --noconfirm --needed quickshell-git || true
paru -S --noconfirm --needed noctalia-shell || paru -S --noconfirm --needed noctalia-git || true
# autostart di noctalia dentro niri
mkdir -p "$HOME/.config/niri"
if [ ! -f "$HOME/.config/niri/config.kdl" ]; then
  cat > "$HOME/.config/niri/config.kdl" <<'KDL'
// config minimale: avvia noctalia come shell
spawn-at-startup "noctalia-shell"
KDL
fi
USER

touch "$MARK"
systemctl disable niri-firstboot.service 2>/dev/null || true
log "completato"
