#!/usr/bin/env bash
# v2p-deploy — scrive il disco di una VM (qcow2) su un DISCO FISICO reale.
# Flusso: scegli la VM -> scegli il disco fisico di destinazione -> conferme di
# sicurezza -> qemu-img convert -O raw sul device. Utile per portare su hardware
# vero una VM provata e che piace (es. ubuntu26).
#
# Uso:
#   sudo bash scripts/v2p-deploy.sh [VM]          # interattivo
#   bash scripts/v2p-deploy.sh ubuntu26.04        # si auto-eleva con sudo
#   V2P_DRYRUN=1 bash scripts/v2p-deploy.sh ...    # NON scrive: mostra solo il piano
#   bash scripts/v2p-deploy.sh --dry-run ...
#
# ============================ ATTENZIONE ===================================
# Operazione DISTRUTTIVA: AZZERA completamente il disco di destinazione.
# Lo script rifiuta il disco di sistema e i device con partizioni montate, e
# chiede di digitare per esteso il path del device prima di scrivere.
# ===========================================================================

set -uo pipefail

# ---- parsing argomenti ----
DRYRUN="${V2P_DRYRUN:-0}"
VM=""
for a in "$@"; do
  case "$a" in
    --dry-run) DRYRUN=1 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    -*) echo "Opzione sconosciuta: $a" >&2; exit 2 ;;
    *) VM="$a" ;;
  esac
done

# ---- auto-elevazione (serve root per scrivere sul device) ----
if [[ $EUID -ne 0 ]]; then
  echo "[*] Servono privilegi di root: rilancio con sudo..."
  exec sudo -E V2P_DRYRUN="$DRYRUN" bash "$0" ${VM:+"$VM"}
fi

c_red=$'\e[31m'; c_grn=$'\e[32m'; c_yel=$'\e[33m'; c_bold=$'\e[1m'; c_off=$'\e[0m'
die() { echo "${c_red}Errore:${c_off} $*" >&2; exit 1; }
hr() { printf '%s\n' "----------------------------------------------------------------"; }

for cmd in virsh qemu-img lsblk findmnt blockdev; do
  command -v "$cmd" >/dev/null || die "comando mancante: $cmd"
done

# ---- 1. Selezione VM ----
mapfile -t VMS < <(virsh list --all --name 2>/dev/null | sed '/^$/d')
[[ ${#VMS[@]} -gt 0 ]] || die "nessuna VM definita in libvirt."

if [[ -z "$VM" ]]; then
  echo "${c_bold}VM disponibili:${c_off}"
  select choice in "${VMS[@]}"; do [[ -n "${choice:-}" ]] && { VM="$choice"; break; }; done
fi
printf '%s\n' "${VMS[@]}" | grep -qxF "$VM" || die "VM '$VM' non trovata."

state="$(virsh domstate "$VM" 2>/dev/null | head -n1)"
[[ "$state" == "shut off" ]] || die "la VM '$VM' e' '$state': spegnila prima (virsh shutdown $VM)."

# ---- 2. Disco sorgente della VM ----
mapfile -t SRCS < <(virsh domblklist "$VM" --details 2>/dev/null \
  | awk '$2=="disk" && $4 ~ /\/.*\.(qcow2|raw|img|vhd|vmdk|vdi)$/ {print $4}')
[[ ${#SRCS[@]} -gt 0 ]] || die "nessun disco-immagine trovato per '$VM'."
if [[ ${#SRCS[@]} -eq 1 ]]; then
  SRC="${SRCS[0]}"
else
  echo "${c_bold}Dischi della VM:${c_off}"
  select s in "${SRCS[@]}"; do [[ -n "${s:-}" ]] && { SRC="$s"; break; }; done
fi
[[ -f "$SRC" ]] || die "disco sorgente non accessibile: $SRC"

VSIZE_BYTES="$(qemu-img info --output=json "$SRC" 2>/dev/null \
  | sed -n 's/.*"virtual-size": \([0-9]*\).*/\1/p' | head -n1)"
[[ -n "$VSIZE_BYTES" ]] || VSIZE_BYTES=0

echo; hr
echo "${c_bold}Sorgente:${c_off} $SRC"
qemu-img info "$SRC" 2>/dev/null | grep -E 'file format|virtual size|disk size'
hr

# ---- 3. Disco di sistema (da escludere) ----
root_src="$(findmnt -no SOURCE / 2>/dev/null)"
sys_pk="$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -n1)"
[[ -n "$sys_pk" ]] || sys_pk="$(lsblk -no NAME "$root_src" 2>/dev/null | head -n1)"
SYS_DISK="/dev/${sys_pk}"

# ---- 4. Elenco dischi fisici candidati ----
echo "${c_bold}Dischi fisici rilevati${c_off} (disco di sistema escluso: ${c_yel}${SYS_DISK}${c_off}):"
echo
lsblk -dpno NAME,SIZE,TYPE,TRAN,MODEL | awk '$3=="disk"'
echo
mapfile -t DISKS < <(lsblk -dpno NAME,TYPE | awk '$2=="disk"{print $1}' | grep -vxF "$SYS_DISK")
[[ ${#DISKS[@]} -gt 0 ]] || die "nessun disco fisico di destinazione disponibile (oltre al sistema)."

echo "${c_bold}Scegli il disco di DESTINAZIONE${c_off} (verra' ${c_red}AZZERATO${c_off}):"
TARGET=""
select d in "${DISKS[@]}"; do [[ -n "${d:-}" ]] && { TARGET="$d"; break; }; done
[[ -b "$TARGET" ]] || die "device non valido: $TARGET"

# ---- 5. Controlli di sicurezza sul target ----
[[ "$TARGET" != "$SYS_DISK" ]] || die "rifiuto: '$TARGET' e' il disco di sistema."
[[ "$(lsblk -dno TYPE "$TARGET")" == "disk" ]] || die "'$TARGET' non e' un disco intero."

mounted="$(lsblk -nro NAME,MOUNTPOINT "$TARGET" | awk 'NF==2{print "  /dev/"$1" -> "$2}')"
if [[ -n "$mounted" ]]; then
  echo "${c_red}Il disco ha partizioni MONTATE:${c_off}"; echo "$mounted"
  die "smonta tutto prima di procedere (rischio perdita dati sul sistema host)."
fi

TSIZE_BYTES="$(blockdev --getsize64 "$TARGET" 2>/dev/null || echo 0)"
TSIZE_H="$(lsblk -dno SIZE "$TARGET")"
if (( VSIZE_BYTES > 0 && TSIZE_BYTES > 0 && TSIZE_BYTES < VSIZE_BYTES )); then
  die "il disco di destinazione ($TSIZE_H) e' piu' piccolo dell'immagine ($(numfmt --to=iec "$VSIZE_BYTES"))."
fi

echo; hr
echo "${c_bold}RIEPILOGO${c_off}"
echo "  VM            : $VM"
echo "  Immagine      : $SRC"
echo "  Dimensione    : $(numfmt --to=iec "${VSIZE_BYTES:-0}" 2>/dev/null) (virtuale)"
echo "  ${c_red}Destinazione  : $TARGET  ($TSIZE_H)  <-- verra' AZZERATO${c_off}"
lsblk -po NAME,SIZE,FSTYPE,LABEL,MODEL "$TARGET"
hr

# ---- 6. Dry-run: stop qui ----
if [[ "$DRYRUN" == "1" ]]; then
  echo "${c_yel}[DRY-RUN]${c_off} nessuna scrittura. Comando che verrebbe eseguito:"
  echo "    qemu-img convert -p -O raw -t none -W \"$SRC\" \"$TARGET\""
  exit 0
fi

# ---- 7. Conferma esplicita ----
echo "${c_red}${c_bold}Tutti i dati su $TARGET saranno PERSI in modo irreversibile.${c_off}"
read -rp "Per confermare digita ESATTAMENTE il device ($TARGET): " typed
[[ "$typed" == "$TARGET" ]] || die "conferma non corrispondente: annullato."
read -rp "Ultima conferma, scrivo l'immagine su $TARGET? [scrivi: CONFERMO] " ok
[[ "$ok" == "CONFERMO" ]] || die "annullato."

# ---- 8. Scrittura ----
echo "[*] Azzero le firme di partizione esistenti su $TARGET..."
wipefs -a "$TARGET" >/dev/null 2>&1 || true
echo "[*] Scrivo l'immagine (puo' richiedere parecchio tempo)..."
qemu-img convert -p -O raw -t none -W "$SRC" "$TARGET" || die "qemu-img convert fallito."
sync
command -v partprobe >/dev/null && partprobe "$TARGET" 2>/dev/null || true

echo
echo "${c_grn}[+] Fatto.${c_off} Immagine di '$VM' scritta su $TARGET."
echo "    Le VM del lab usano boot UEFI: assicurati che la macchina fisica avvii in UEFI."
echo "    Se il disco fisico e' piu' grande, puoi estendere l'ultima partizione con:"
echo "      sudo growpart $TARGET <N> && sudo resize2fs ${TARGET}<N>   # ext4"
