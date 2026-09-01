#!/usr/bin/env bash
# Helper del registro VM (vms.tsv), unica fonte di verita' dell'inventario lab.
#
# Uso:
#   bash scripts/vms-registry.sh --check       # valida il registro (exit != 0 se KO)
#   bash scripts/vms-registry.sh --ids         # elenca gli ID
#   bash scripts/vms-registry.sh --rows        # righe dati "id|vm|script|family|agent|e2e|group|note"
#   bash scripts/vms-registry.sh --items linux # "id|vm|script"        delle VM Linux con e2e=yes
#   bash scripts/vms-registry.sh --items windows  # "id|vm|script|agent" delle Windows con e2e=yes
#   bash scripts/vms-registry.sh --excluded linux # "id|vm|motivo" delle VM con e2e=no
#
# Le righe dati si riconoscono dal primo campo che inizia con [a-z0-9]:
# commenti e intestazione iniziano con '#'.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY="${VMLAB_REGISTRY:-$REPO_DIR/vms.tsv}"

# Motori condivisi: non sono entry point di installazione, quindi non compaiono
# nel registro. Elencarli qui evita falsi positivi nel controllo di copertura.
ENGINE_SCRIPTS=(
  scripts/install-ubuntu-flavor.sh
  scripts/install-enterprise-linux.sh
)

rows() { awk -F'\t' '$1 ~ /^[a-z0-9]/ {print}' "$REGISTRY"; }

cmd_rows() { rows | awk -F'\t' '{print $1"|"$2"|"$3"|"$4"|"$5"|"$6"|"$7"|"$8}'; }
cmd_ids()  { rows | cut -f1; }

cmd_items() {
    local family="$1"
    if [ "$family" = windows ]; then
        rows | awk -F'\t' -v f="$family" '$4==f && $6=="yes" {print $1"|"$2"|"$3"|"$5}'
    else
        rows | awk -F'\t' -v f="$family" '$4==f && $6=="yes" {print $1"|"$2"|"$3}'
    fi
}

cmd_excluded() {
    local family="$1"
    rows | awk -F'\t' -v f="$family" \
        '$4==f && $6!="yes" {print $1"|"$2"|"($8=="" ? "esclusa dal registro" : $8)}'
}

cmd_check() {
    local errors=0 warnings=0 lineno=0 line
    local -A seen_id=() seen_vm=()

    [ -f "$REGISTRY" ] || { echo "ERRORE: registro non trovato: $REGISTRY" >&2; exit 1; }

    while IFS= read -r line; do
        lineno=$((lineno + 1))
        [[ "$line" =~ ^[a-z0-9] ]] || continue

        local nf; nf=$(awk -F'\t' '{print NF}' <<<"$line")
        if [ "$nf" -ne 8 ]; then
            echo "ERRORE riga $lineno: 8 campi attesi, trovati $nf (separatore TAB?)" >&2
            errors=$((errors + 1)); continue
        fi

        local id vm script family agent e2e group note
        IFS=$'\t' read -r id vm script family agent e2e group note <<<"$line"

        [ -n "${seen_id[$id]:-}" ] && { echo "ERRORE riga $lineno: id duplicato '$id'" >&2; errors=$((errors+1)); }
        [ -n "${seen_vm[$vm]:-}" ] && { echo "ERRORE riga $lineno: nome VM duplicato '$vm'" >&2; errors=$((errors+1)); }
        seen_id[$id]=1; seen_vm[$vm]=1

        [ -f "$REPO_DIR/$script" ] || { echo "ERRORE riga $lineno ($id): script mancante '$script'" >&2; errors=$((errors+1)); }

        case "$family" in linux|windows) ;;
            *) echo "ERRORE riga $lineno ($id): family '$family' non valida (linux|windows)" >&2; errors=$((errors+1)) ;;
        esac
        case "$agent" in yes|no) ;;
            *) echo "ERRORE riga $lineno ($id): agent '$agent' non valido (yes|no)" >&2; errors=$((errors+1)) ;;
        esac
        case "$e2e" in yes|no) ;;
            *) echo "ERRORE riga $lineno ($id): e2e '$e2e' non valido (yes|no)" >&2; errors=$((errors+1)) ;;
        esac
        [[ "$group" == *[[:space:]]* || -z "$group" ]] && \
            { echo "ERRORE riga $lineno ($id): group '$group' vuoto o con spazi" >&2; errors=$((errors+1)); }
        [ "$e2e" = no ] && [ -z "$note" ] && \
            { echo "ERRORE riga $lineno ($id): e2e=no richiede il motivo nel campo note" >&2; errors=$((errors+1)); }

        [ -f "$REPO_DIR/vms/$vm.md" ] || \
            { echo "AVVISO ($id): manca la scheda vms/$vm.md" >&2; warnings=$((warnings + 1)); }
    done < "$REGISTRY"

    # Copertura inversa: ogni script di installazione deve essere nel registro
    # (o dichiarato come motore condiviso), altrimenti e' codice orfano.
    local s rel
    while IFS= read -r s; do
        rel="${s#"$REPO_DIR"/}"
        [[ " ${ENGINE_SCRIPTS[*]} " == *" $rel "* ]] && continue
        grep -qF "	$rel	" "$REGISTRY" || \
            { echo "AVVISO: '$rel' non e' referenziato dal registro" >&2; warnings=$((warnings + 1)); }
    done < <(find "$REPO_DIR/scripts" -name 'install-*.sh' -o -name 'create_*_vm.sh' | sort)

    local n; n=$(rows | wc -l)
    echo "Registro: $n VM, $errors errori, $warnings avvisi."
    [ "$errors" -eq 0 ]
}

case "${1:---check}" in
    --check)    cmd_check ;;
    --ids)      cmd_ids ;;
    --rows)     cmd_rows ;;
    --items)    cmd_items "${2:?famiglia richiesta: linux|windows}" ;;
    --excluded) cmd_excluded "${2:?famiglia richiesta: linux|windows}" ;;
    *) echo "Uso: $0 [--check|--ids|--rows|--items FAMILY|--excluded FAMILY]" >&2; exit 2 ;;
esac
