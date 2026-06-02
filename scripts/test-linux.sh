#!/usr/bin/env bash
# Test end-to-end delle installazioni Linux del lab.
# Per ogni VM: reinstalla da zero -> attende lo spegnimento (autoinstall ok) ->
# riavvia -> verifica via guest-agent che il desktop sia pronto (graphical.target
# + display-manager attivo) -> screenshot. Esegue N VM in parallelo (default 4)
# e a fine run scrive un report HTML con PASS/WARN/FAIL di ognuna.
# Per le VM Windows vedi scripts/test-win.sh; per entrambe scripts/test-all.sh.
#
# Uso:
#   bash scripts/test-linux.sh            # usa TEST_PARALLEL da test-linux.env (4)
#   bash scripts/test-linux.sh 6          # 6 in parallelo
#   TEST_OUTDIR=/data/e2e bash scripts/test-linux.sh
#
# ATTENZIONE: REINSTALLA (cancella e ricrea) le VM elencate in test-linux.env.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"
source "$SCRIPT_DIR/test-linux.env"
[ -n "${1:-}" ] && TEST_PARALLEL="$1"

# Mappa la config Linux nelle variabili attese dal motore (scripts/test-lib.sh).
TITLE="VM Lab — Test end-to-end Linux"
PARALLEL="$TEST_PARALLEL"
OUTDIR="$TEST_OUTDIR"
OPEN_BROWSER="${TEST_OPEN_BROWSER:-1}"

# Item unificati: aggiunge il type 'linux' alle righe "id|vm|script".
ITEMS=()
for _it in "${TEST_ITEMS[@]}"; do ITEMS+=("$_it|linux"); done
EXCLUDED_ITEMS=("${TEST_EXCLUDED_ITEMS[@]}")

source "$SCRIPT_DIR/test-lib.sh"
engine_main
