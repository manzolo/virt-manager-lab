#!/usr/bin/env bash
# =============================================================================
# Motore comune delle installazioni unattended basate su subiquity
# (Ubuntu e derivate: ISO live-server o desktop + autoinstall).
#
# Prima esisteva una copia quasi identica di questo codice in ogni script
# install-*.sh: stesso download ISO, stesso xorriso, stesso virt-install,
# stessa attesa del first boot. Qui sta una volta sola.
#
# USO: lo script chiamante imposta le variabili di configurazione e chiama
# subiquity_install. Esempio minimo (scripts/install-ubuntu24.04.sh):
#
#     source "$SCRIPT_DIR/lib/subiquity-install.sh"
#     VM_NAME="ubuntu24.04"
#     LABEL="Ubuntu 24.04"
#     ISO_ORIG="$STORAGE/Iso/Distro/ubuntu-24.04.3-desktop-amd64.iso"
#     ...
#     subiquity_install
#
# CONFIGURAZIONE
#   Obbligatorie: VM_NAME, LABEL, ISO_ORIG, ISO_AUTO, ISO_URL, AUTOINSTALL_TEMPLATE
#   Opzionali (default fra parentesi):
#     DISK_PATH   ($STORAGE/hd/$VM_NAME.qcow2)   DISK_SIZE (30G)
#     MEMORY      (4096)                          VCPUS     (2)
#     OS_VARIANTS (ubuntu22.04)  candidati os-variant in ordine di preferenza
#     GRUB_AUTO_EXTRA_ARGS ("")  argomenti kernel extra sulla voce automatica
#     GRUB_AUTO_ARGS   (quiet splash ---)
#     GRUB_MANUAL_LABEL (Ubuntu Server Install (manual))
#     GRUB_MANUAL_ARGS  (quiet ---)
#     DESKTOP_INSTALL_MODE (packages|firstboot, default packages)
#     DESKTOP_PACKAGE / DISPLAY_MANAGER   richiesti solo con firstboot
#     FIRSTBOOT_AUTOSTART, FIRSTBOOT_WAIT_DESKTOP,
#     FIRSTBOOT_BASE_TIMEOUT (7200), FIRSTBOOT_DESKTOP_TIMEOUT (14400),
#     FIRSTBOOT_POLL_INTERVAL (30)
#
# HOOK
#   render_autoinstall <src> <dst>
#     Se lo script chiamante la definisce, viene usata al posto del semplice
#     render_template di lab.env. Serve a chi deve generare blocchi YAML
#     (vedi scripts/install-ubuntu-flavor22.04.sh).
# =============================================================================

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$_LIB_DIR/.." && pwd)"
# Il repo si individua dalla posizione dello script, non da un percorso fisso:
# cosi' la cartella del clone puo' chiamarsi come si vuole.
REPO_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"

# shellcheck source=../lab.env
source "$SCRIPTS_DIR/lab.env"

STORAGE="$VM_BASE_DIR/storage"
UNATTENDED_DIR="$REPO_DIR"
SHARED_DIR="${SHARED_DIR:-$STORAGE/shared}"

# -----------------------------------------------------------------------------
# File temporanei: un solo trap EXIT per tutti. Un trap RETURN per funzione non
# andrebbe bene, perche' quello annidato (render_autoinstall dentro _build_iso)
# sostituirebbe quello esterno lasciando file orfani.
# -----------------------------------------------------------------------------
_TMP_FILES=()
# mktemp_tracked NOME_VARIABILE TEMPLATE
# Assegna alla variabile indicata invece di stampare: con $(...) la creazione
# avverrebbe in una subshell e l'aggiunta a _TMP_FILES andrebbe persa.
mktemp_tracked() {
    local -n _mkt_out="$1"
    _mkt_out="$(mktemp "$2")"
    _TMP_FILES+=("$_mkt_out")
}
_cleanup_tmp() {
    if (( ${#_TMP_FILES[@]} > 0 )); then
        rm -f "${_TMP_FILES[@]}"
    fi
}
trap _cleanup_tmp EXIT

# -----------------------------------------------------------------------------
# Attese e interrogazione del guest (usate dal flusso first boot)
# -----------------------------------------------------------------------------
wait_for_vm_state() {
    local expected="$1" timeout="$2" label="$3"
    local elapsed=0 state

    while (( elapsed <= timeout )); do
        state="$(LC_ALL=C virsh domstate "$VM_NAME" 2>/dev/null | head -n 1 || true)"
        if [[ "$state" == "$expected" ]]; then
            echo "$label: $state"
            return 0
        fi

        echo "$label: ${state:-non definita} (${elapsed}s/${timeout}s)"
        sleep "$FIRSTBOOT_POLL_INTERVAL"
        elapsed=$((elapsed + FIRSTBOOT_POLL_INTERVAL))
    done

    echo "Timeout aspettando '$expected' per $VM_NAME ($label)."
    return 1
}

guest_agent_ready() {
    virsh qemu-agent-command "$VM_NAME" '{"execute":"guest-ping"}' >/dev/null 2>&1
}

guest_exec_quiet() {
    local cmd="$1" encoded payload output pid status exitcode

    encoded="$(printf '%s' "$cmd" | base64 | tr -d '\n')"
    payload="{\"execute\":\"guest-exec\",\"arguments\":{\"path\":\"/bin/sh\",\"arg\":[\"-lc\",\"printf %s $encoded | base64 -d | /bin/sh\"],\"capture-output\":true}}"

    output="$(virsh qemu-agent-command "$VM_NAME" "$payload" 2>/dev/null)" || return 125
    pid="$(sed -n 's/.*"pid":\([0-9][0-9]*\).*/\1/p' <<< "$output")"
    [[ -n "$pid" ]] || return 125

    for _ in {1..60}; do
        status="$(virsh qemu-agent-command "$VM_NAME" "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$pid}}" 2>/dev/null)" || return 125
        if [[ "$status" == *'"exited":true'* ]]; then
            exitcode="$(sed -n 's/.*"exitcode":\([0-9][0-9]*\).*/\1/p' <<< "$status")"
            return "${exitcode:-1}"
        fi
        sleep 1
    done

    return 124
}

wait_for_firstboot_desktop() {
    local elapsed=0 check_cmd

    check_cmd="systemctl get-default | grep -qx graphical.target && systemctl is-active --quiet ${DISPLAY_MANAGER} && dpkg-query -W ${DESKTOP_PACKAGE} >/dev/null 2>&1 && ! systemctl is-enabled --quiet lab-desktop.service"

    while (( elapsed <= FIRSTBOOT_DESKTOP_TIMEOUT )); do
        if guest_agent_ready && guest_exec_quiet "$check_cmd"; then
            echo "Desktop first boot completato per $VM_NAME."
            return 0
        fi

        echo "Attendo desktop first boot di $VM_NAME (${elapsed}s/${FIRSTBOOT_DESKTOP_TIMEOUT}s)..."
        sleep "$FIRSTBOOT_POLL_INTERVAL"
        elapsed=$((elapsed + FIRSTBOOT_POLL_INTERVAL))
    done

    echo "Timeout aspettando il desktop first boot di $VM_NAME."
    echo "Diagnosi guest: /var/log/lab-desktop.log, /var/log/apt/term.log, systemctl status lab-desktop.service"
    return 1
}

run_firstboot_if_requested() {
    [[ "$DESKTOP_INSTALL_MODE" == "firstboot" ]] || return 0
    [[ "$FIRSTBOOT_AUTOSTART" == "true" ]] || return 0

    echo ""
    echo "[+] Attendo lo spegnimento dell'autoinstall base di $VM_NAME..."
    wait_for_vm_state "shut off" "$FIRSTBOOT_BASE_TIMEOUT" "Autoinstall base" || return 1

    echo "[+] Avvio $VM_NAME per installare il desktop al primo boot..."
    virsh start "$VM_NAME"

    [[ "$FIRSTBOOT_WAIT_DESKTOP" == "true" ]] || return 0
    wait_for_firstboot_desktop
}

# -----------------------------------------------------------------------------
# Passi dell'installazione
# -----------------------------------------------------------------------------

# Sceglie il primo os-variant riconosciuto da virt-install. Il probe --print-xml
# puo' fallire transitoriamente con piu' install in parallelo (make test-linux):
# ogni candidato viene riprovato prima di essere scartato.
_resolve_os_variant() {
    local candidate
    OS_VARIANT=""
    for candidate in $OS_VARIANTS; do
        [[ -n "$candidate" ]] || continue
        for _try in 1 2 3 4 5 6; do
            if virt-install --os-variant "$candidate" --print-xml &>/dev/null; then
                OS_VARIANT="$candidate"
                echo "OS variant: $OS_VARIANT"
                return 0
            fi
            sleep 2
        done
    done

    echo "Nessun os-variant valido tra: $OS_VARIANTS"
    return 1
}

_check_deps() {
    local cmd
    for cmd in wget xorriso qemu-img virt-install virsh; do
        command -v "$cmd" >/dev/null || { echo "Comando mancante: $cmd"; return 1; }
    done
}

_fetch_iso() {
    [[ -f "$ISO_ORIG" ]] && return 0
    echo "ISO originale non trovata: $ISO_ORIG"
    echo "Download in corso da: $ISO_URL"
    mkdir -p "$(dirname "$ISO_ORIG")"
    wget --show-progress -O "$ISO_ORIG" "$ISO_URL"
    echo "Download completato."
}

# Se la VM esiste chiede conferma (default S) e la rimuove. Con stdin non
# interattivo, 'echo S |' basta a rispondere: e' quello che fa make reinstall-<id>.
_confirm_and_remove_existing_vm() {
    virsh dominfo "$VM_NAME" &>/dev/null || return 0

    echo "La VM '$VM_NAME' esiste gia'."
    read -rp "Vuoi eliminarla e reinstallare? [S/n] " risposta
    risposta="${risposta:-S}"
    if [[ ! "$risposta" =~ ^[sS]$ ]]; then
        echo "Installazione annullata."
        exit 0
    fi

    echo "Fermo e rimuovo la VM..."
    virsh destroy "$VM_NAME" 2>/dev/null || true
    virsh undefine "$VM_NAME" --snapshots-metadata --nvram 2>/dev/null || \
    virsh undefine "$VM_NAME" --snapshots-metadata 2>/dev/null || true
}

_reset_disk() {
    echo "Creo il disco $DISK_PATH ($DISK_SIZE)..."
    rm -f "$DISK_PATH"
    qemu-img create -f qcow2 -o preallocation=off "$DISK_PATH" "$DISK_SIZE"
    virsh pool-refresh hdd
}

# Costruisce l'ISO con l'autoinstall dentro.
# -boot_image any replay preserva El Torito, la EFI appended partition e tutti i
# boot record dell'originale: senza, xorriso scarta il boot record e il firmware
# UEFI non trova piu' il bootloader.
_build_iso() {
    local grubcfg meta rendered auto_cmdline
    echo "Preparo ISO autoinstall $LABEL..."

    # Composta a parte per non lasciare doppi spazi quando non ci sono args extra.
    auto_cmdline="autoinstall ds=nocloud\;s=/cdrom/"
    [[ -n "$GRUB_AUTO_EXTRA_ARGS" ]] && auto_cmdline="$auto_cmdline $GRUB_AUTO_EXTRA_ARGS"
    auto_cmdline="$auto_cmdline $GRUB_AUTO_ARGS"
    rm -f "$ISO_AUTO"

    mktemp_tracked grubcfg  "/tmp/$VM_NAME-grub.XXXXX"
    mktemp_tracked meta     "/tmp/$VM_NAME-meta.XXXXX"
    mktemp_tracked rendered "/tmp/$VM_NAME-autoinstall.XXXXX.yaml"
    touch "$meta"

    # Hook: chi deve generare blocchi YAML definisce render_autoinstall.
    if declare -F render_autoinstall >/dev/null; then
        render_autoinstall "$AUTOINSTALL_TEMPLATE" "$rendered"
    else
        render_template "$AUTOINSTALL_TEMPLATE" "$rendered"
    fi

    cat > "$grubcfg" <<GRUBCFG
set default=0
set timeout=10

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Automated $LABEL Install" {
    set gfxpayload=keep
    linux   /casper/vmlinuz $auto_cmdline
    initrd  /casper/initrd
}
menuentry "$GRUB_MANUAL_LABEL" {
    set gfxpayload=keep
    linux   /casper/vmlinuz $GRUB_MANUAL_ARGS
    initrd  /casper/initrd
}
if [ "\$grub_platform" = "efi" ]; then
menuentry 'UEFI Firmware Settings' { fwsetup }
fi
GRUBCFG

    xorriso \
        -indev  "$ISO_ORIG" \
        -outdev "$ISO_AUTO" \
        -boot_image any replay \
        -map "$grubcfg"  /boot/grub/grub.cfg \
        -map "$rendered" /user-data \
        -map "$meta"     /meta-data \
        -commit -eject all 2>&1 | grep -v "^xorriso : UPDATE" || true

    echo "ISO pronta: $ISO_AUTO"
}

_create_vm() {
    echo "Creo e avvio la VM '$VM_NAME'..."
    virt-install \
        --name "$VM_NAME" \
        --memory "$MEMORY" \
        --vcpus "$VCPUS" \
        --machine q35 \
        --cpu host-passthrough \
        --os-variant "$OS_VARIANT" \
        --disk "$DISK_PATH",bus=virtio,driver.discard=unmap \
        --cdrom "$ISO_AUTO" \
        --network network=default,model=virtio \
        --graphics spice \
        --video virtio \
        --sound ich9 \
        --boot uefi \
        --memorybacking source.type=memfd,access.mode=shared \
        --filesystem "source.dir=$SHARED_DIR,target.dir=host_shared,driver.type=virtiofs,accessmode=passthrough" \
        --controller type=scsi,model=virtio-scsi \
        --rng /dev/urandom,model=virtio \
        --memballoon model=virtio \
        --watchdog i6300esb \
        --noautoconsole \
        --noreboot
}

# -----------------------------------------------------------------------------
# Entry point
# -----------------------------------------------------------------------------
subiquity_install() {
    : "${VM_NAME:?VM_NAME non impostato}"
    : "${LABEL:?LABEL non impostato}"
    : "${ISO_ORIG:?ISO_ORIG non impostato}"
    : "${ISO_AUTO:?ISO_AUTO non impostato}"
    : "${ISO_URL:?ISO_URL non impostato}"
    : "${AUTOINSTALL_TEMPLATE:?AUTOINSTALL_TEMPLATE non impostato}"

    DISK_PATH="${DISK_PATH:-$STORAGE/hd/$VM_NAME.qcow2}"
    DISK_SIZE="${DISK_SIZE:-30G}"
    MEMORY="${MEMORY:-4096}"
    VCPUS="${VCPUS:-2}"
    OS_VARIANTS="${OS_VARIANTS:-ubuntu22.04}"

    GRUB_AUTO_EXTRA_ARGS="${GRUB_AUTO_EXTRA_ARGS:-}"
    GRUB_AUTO_ARGS="${GRUB_AUTO_ARGS:-quiet splash ---}"
    GRUB_MANUAL_LABEL="${GRUB_MANUAL_LABEL:-Ubuntu Server Install (manual)}"
    GRUB_MANUAL_ARGS="${GRUB_MANUAL_ARGS:-quiet ---}"

    DESKTOP_INSTALL_MODE="${DESKTOP_INSTALL_MODE:-packages}"
    case "$DESKTOP_INSTALL_MODE" in
        packages) ;;
        firstboot)
            : "${DESKTOP_PACKAGE:?DESKTOP_PACKAGE richiesto con DESKTOP_INSTALL_MODE=firstboot}"
            : "${DISPLAY_MANAGER:?DISPLAY_MANAGER richiesto con DESKTOP_INSTALL_MODE=firstboot}"
            ;;
        *)
            echo "DESKTOP_INSTALL_MODE non valido: $DESKTOP_INSTALL_MODE (packages|firstboot)"
            return 1
            ;;
    esac

    if [[ -z "${FIRSTBOOT_AUTOSTART+x}" ]]; then
        [[ "$DESKTOP_INSTALL_MODE" == "firstboot" ]] && FIRSTBOOT_AUTOSTART="true" || FIRSTBOOT_AUTOSTART="false"
    fi
    FIRSTBOOT_WAIT_DESKTOP="${FIRSTBOOT_WAIT_DESKTOP:-$FIRSTBOOT_AUTOSTART}"
    FIRSTBOOT_BASE_TIMEOUT="${FIRSTBOOT_BASE_TIMEOUT:-7200}"
    FIRSTBOOT_DESKTOP_TIMEOUT="${FIRSTBOOT_DESKTOP_TIMEOUT:-14400}"
    FIRSTBOOT_POLL_INTERVAL="${FIRSTBOOT_POLL_INTERVAL:-30}"

    _check_deps
    [[ -f "$AUTOINSTALL_TEMPLATE" ]] || { echo "Mancante: $AUTOINSTALL_TEMPLATE"; return 1; }

    _resolve_os_variant
    _fetch_iso
    _confirm_and_remove_existing_vm
    _reset_disk
    _build_iso
    _create_vm

    echo ""
    echo "[+] VM $VM_NAME avviata, installazione in corso."
    echo "    Connettiti con: virt-viewer $VM_NAME"
    echo ""
    if [[ "$DESKTOP_INSTALL_MODE" == "firstboot" && "$FIRSTBOOT_AUTOSTART" == "true" ]]; then
        echo "    Al termine della base install la VM viene riavviata automaticamente"
        echo "    per completare il desktop al primo boot."
        run_firstboot_if_requested
    else
        echo "    Al termine la VM si spegne automaticamente."
        echo "    Per avviarla: virsh start $VM_NAME"
    fi
}
