#!/usr/bin/env bash
# Setup idempotente dell'host per il lab: dipendenze, pool libvirt, rete default.
#   bash scripts/setup.sh           configura cio' che manca (idempotente)
#   bash scripts/setup.sh --check   SOLO verifica, non cambia nulla (exit !=0 se qualcosa manca)
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lab.env"
STORAGE="$VM_BASE_DIR/storage"

MODE="configure"; [ "${1:-}" = "--check" ] && MODE="check"
FAIL=0

g(){ printf '  \033[32mok\033[0m   %s\n' "$1"; }                 # ok
a(){ printf '  \033[33m++\033[0m   %s\n' "$1"; }                 # azione (solo configure)
e(){ printf '  \033[31m!!\033[0m   %s\n' "$1"; FAIL=1; }         # problema

echo "== 1. Pacchetti =="
declare -A PKG=(
  [qemu-system-x86]=qemu-system-x86_64 [qemu-utils]=qemu-img [virtinst]=virt-install
  [virt-viewer]=remote-viewer [libvirt-daemon-system]="" [libvirt-clients]=virsh [xorriso]=xorriso [wget]=wget
  [libguestfs-tools]=virt-customize [imagemagick]=convert [python3]=python3 [ovmf]=""
)
missing=()
for pkg in "${!PKG[@]}"; do
  cmd="${PKG[$pkg]}"
  if { [ -n "$cmd" ] && command -v "$cmd" >/dev/null 2>&1; } || { [ -z "$cmd" ] && dpkg -s "$pkg" >/dev/null 2>&1; }; then
    g "$pkg${cmd:+ ($cmd)}"
  else
    missing+=("$pkg")
    [ "$MODE" = check ] && e "manca: $pkg" || a "manca: $pkg"
  fi
done
if (( ${#missing[@]} )) && [ "$MODE" = configure ]; then
  a "installo: ${missing[*]}"
  sudo apt-get update -qq && sudo apt-get install -y "${missing[@]}" || e "installazione pacchetti fallita"
fi

echo "== 2. libvirt / gruppi utente =="
if systemctl is-active --quiet libvirtd 2>/dev/null || systemctl is-active --quiet virtqemud 2>/dev/null; then
  g "servizio libvirt attivo"
elif [ "$MODE" = check ]; then e "servizio libvirt non attivo"
else a "abilito libvirtd"; sudo systemctl enable --now libvirtd 2>/dev/null || e "avvio libvirtd fallito"; fi
for grp in libvirt kvm; do
  if id -nG | tr ' ' '\n' | grep -qx "$grp"; then g "utente nel gruppo $grp"
  else e "utente NON nel gruppo $grp  ->  sudo usermod -aG $grp $USER  (poi ri-login)"; fi
done

echo "== 3. Pool storage =="
# Una sola lettura dello stato (evita chiamate virsh ripetute e race)
POOL_LIST="$(LC_ALL=C virsh pool-list --all 2>/dev/null)"
pstate(){ awk -v n="$1" '$1==n{print $2}' <<<"$POOL_LIST"; }
pools=( "hdd:$STORAGE/hd" "shared:$STORAGE/shared" "Linux:$STORAGE/Iso/Distro"
        "Windows:$STORAGE/Iso/Windows" "addons:$STORAGE/Iso/addons"
        "Utility:$STORAGE/Iso/Utility" "floppy:$STORAGE/floppy" )
for entry in "${pools[@]}"; do
  name="${entry%%:*}"; path="${entry#*:}"; st="$(pstate "$name")"
  if [ "$st" = "active" ]; then g "pool $name (attivo)"; continue; fi
  if [ "$MODE" = check ]; then
    [ -n "$st" ] && e "pool $name definito ma non attivo" || e "pool $name assente"
    continue
  fi
  mkdir -p "$path"
  if [ -n "$st" ]; then
    a "avvio pool $name"; virsh pool-start "$name" >/dev/null 2>&1 || true
  else
    a "creo pool $name -> $path"
    virsh pool-define-as "$name" dir --target "$path" >/dev/null 2>&1 || e "define $name fallito"
    virsh pool-build "$name" >/dev/null 2>&1 || true
    virsh pool-start "$name" >/dev/null 2>&1 || true
  fi
  virsh pool-autostart "$name" >/dev/null 2>&1 || true
done

echo "== 4. Rete libvirt 'default' =="
NET_STATE="$(LC_ALL=C virsh net-list --all 2>/dev/null | awk '$1=="default"{print $2}')"
if [ "$NET_STATE" = "active" ]; then
  g "rete default attiva"
elif [ -n "$NET_STATE" ]; then
  if [ "$MODE" = check ]; then e "rete default definita ma non attiva"
  else a "avvio rete default"; virsh net-start default >/dev/null 2>&1 || true; virsh net-autostart default >/dev/null 2>&1 || true; fi
else
  e "rete 'default' assente (virsh net-define da /usr/share/libvirt/networks/default.xml)"
fi

echo ""
if [ "$MODE" = check ]; then
  if (( FAIL )); then echo "CHECK: problemi rilevati (vedi !! sopra)."; exit 1
  else echo "CHECK: tutto ok."; exit 0; fi
else
  echo "Setup completato. Prossimo passo: 'make setup-check' per verificare, poi 'make <id>'."
fi
