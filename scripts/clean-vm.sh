#!/usr/bin/env bash
# Rimuove una VM e SOLO il suo disco qcow2 principale.
# NON tocca ISO, altri dischi aggiuntivi o volumi in altri pool.
# Uso: bash scripts/clean-vm.sh <nome-vm-libvirt>
set -uo pipefail

vm="${1:-}"
[ -n "$vm" ] || { echo "Uso: $0 <nome-vm>"; exit 2; }

if ! virsh dominfo "$vm" >/dev/null 2>&1; then
    echo "[clean] VM '$vm' non definita, niente da fare."
    exit 0
fi

# Disco qcow2 principale: prima sorgente che termina in .qcow2 (le ISO sono .iso e non vengono toccate)
disk="$(virsh domblklist "$vm" 2>/dev/null | awk '$2 ~ /\.qcow2$/ {print $2; exit}')"

virsh destroy "$vm" >/dev/null 2>&1 || true
virsh undefine "$vm" --snapshots-metadata --nvram >/dev/null 2>&1 \
    || virsh undefine "$vm" --snapshots-metadata >/dev/null 2>&1 || true

if [ -n "$disk" ] && [ -f "$disk" ]; then
    rm -f "$disk"
    virsh pool-refresh hdd >/dev/null 2>&1 || true
    echo "[clean] '$vm' rimossa + disco $disk eliminato (ISO e altri dischi non toccati)."
else
    echo "[clean] '$vm' rimossa; nessun disco qcow2 principale trovato da eliminare."
fi
