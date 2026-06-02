#!/usr/bin/env bash
# Setup una-tantum di niri + noctalia al primo boot (servizio niri-firstboot.service).
# noctalia/quickshell non sono nei repo ufficiali -> build da AUR con paru come utente.
# Placeholder __VM_USER__ reso da arch-bootstrap.sh durante l'install.
#
# STATO: first-draft sperimentale (vedi docs/new-distros.md): la build AUR non
# presidiata e' la parte piu' fragile.

set -euo pipefail
USERNAME="__VM_USER__"
MARK=/var/lib/niri-firstboot-done
SUDOERS=/etc/sudoers.d/99-niri-firstboot

log() { echo "[niri-firstboot] $*"; }
cleanup() { rm -f "$SUDOERS"; }
trap cleanup EXIT

# Attendi rete.
for _ in $(seq 1 30); do ping -c1 -W2 archlinux.org >/dev/null 2>&1 && break; sleep 5; done

# paru usa sudo per pacman durante l'installazione dei pacchetti AUR. Il servizio
# non ha un TTY, quindi serve una regola temporanea e stretta per questo firstboot.
printf '%s ALL=(root) NOPASSWD: /usr/bin/pacman\n' "$USERNAME" > "$SUDOERS"
chmod 0440 "$SUDOERS"

sudo -u "$USERNAME" bash -euo pipefail <<'USER'
mkdir -p "$HOME/.config/niri"
if [ ! -f "$HOME/.config/niri/config.kdl" ]; then
  : > "$HOME/.config/niri/config.kdl"
fi
grep -qxF 'spawn-at-startup "foot"' "$HOME/.config/niri/config.kdl" ||
  printf '\nspawn-at-startup "foot"\n' >> "$HOME/.config/niri/config.kdl"
grep -qxF 'spawn-at-startup "quickshell" "-c" "noctalia-shell"' "$HOME/.config/niri/config.kdl" ||
  printf 'spawn-at-startup "quickshell" "-c" "noctalia-shell"\n' >> "$HOME/.config/niri/config.kdl"
USER

# Helper AUR (yay) come utente non-root, build noctalia.
pacman -Rns --noconfirm quickshell 2>/dev/null || true
sudo -u "$USERNAME" bash -euo pipefail <<'USER'
cd "$HOME"
export MAKEFLAGS="-j1"
export CMAKE_BUILD_PARALLEL_LEVEL=1
if ! command -v yay >/dev/null 2>&1; then
  rm -rf /tmp/yay-bin && git clone --depth=1 https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
  ( cd /tmp/yay-bin && makepkg -si --noconfirm --needed )
fi
yay -S --noconfirm --needed --answerdiff None --answerclean None noctalia-shell || \
  yay -S --noconfirm --needed --answerdiff None --answerclean None noctalia-git
USER

touch "$MARK"
systemctl disable niri-firstboot.service 2>/dev/null || true
log "completato"
