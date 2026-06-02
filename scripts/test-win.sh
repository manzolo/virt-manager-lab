#!/usr/bin/env bash
# Test end-to-end delle installazioni Windows del lab.
# Per ogni VM: reinstalla da zero (script create_*) -> attende che il QEMU guest
# agent risponda (= Windows ha completato OOBE/autologon e virtio-win-guest-tools
# ha installato l'agente) -> verifica via guest-exec (cmd.exe) host/tools/virtiofs
# -> screenshot -> spegne. Esegue N VM in parallelo (default 2) e a fine run scrive
# un report HTML con PASS/WARN/FAIL di ognuna.
# Per le VM Linux vedi scripts/test-linux.sh; per entrambe scripts/test-all.sh.
#
# Le VM senza canale guest-agent (es. Windows 7: --channel none) non sono
# interrogabili: vengono solo avviate, attese e fotografate (esito WARN).
#
# Uso:
#   bash scripts/test-win.sh            # usa TEST_WIN_PARALLEL da test-win.env (2)
#   bash scripts/test-win.sh 1          # 1 alla volta
#   TEST_WIN_OUTDIR=/data/win-e2e bash scripts/test-win.sh
#
# ATTENZIONE: REINSTALLA (cancella e ricrea) le VM elencate in test-win.env.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"
source "$SCRIPT_DIR/test-win.env"
[ -n "${1:-}" ] && TEST_WIN_PARALLEL="$1"

# Mappa la config Windows nelle variabili attese dal motore (scripts/test-lib.sh).
TITLE="VM Lab — Test end-to-end Windows"
PARALLEL="$TEST_WIN_PARALLEL"
OUTDIR="$TEST_WIN_OUTDIR"
OPEN_BROWSER="${TEST_OPEN_BROWSER:-1}"

# Item unificati: inserisce il type 'windows' nelle righe "id|vm|script|agent".
ITEMS=()
for _it in "${TEST_WIN_ITEMS[@]}"; do
  IFS='|' read -r _id _vm _script _agent <<<"$_it"
  ITEMS+=("$_id|$_vm|$_script|windows|$_agent")
done
EXCLUDED_ITEMS=("${TEST_WIN_EXCLUDED_ITEMS[@]}")

source "$SCRIPT_DIR/test-lib.sh"
engine_main
