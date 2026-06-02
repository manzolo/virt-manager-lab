#!/usr/bin/env bash
# Test end-to-end COMPLETO del lab: VM Linux + VM Windows in un unico run, con un
# solo report HTML. Riusa la config di test-linux.env e test-win.env e il motore
# condiviso scripts/test-lib.sh.
#
# Ordine: prima le VM Linux (piu' leggere/veloci), poi le Windows. Il parallelismo
# e' unico per tutto il run (le Windows usano 4-8 GB l'una: tienilo basso).
#
# Uso:
#   bash scripts/test-all.sh            # usa TEST_ALL_PARALLEL (default 2)
#   bash scripts/test-all.sh 3          # 3 in parallelo
#   TEST_ALL_OUTDIR=/data/e2e bash scripts/test-all.sh
#
# ATTENZIONE: REINSTALLA (cancella e ricrea) tutte le VM elencate nei due env.

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"
source "$SCRIPT_DIR/test-linux.env"   # TEST_ITEMS, TEST_EXCLUDED_ITEMS, timeout Linux
source "$SCRIPT_DIR/test-win.env"     # TEST_WIN_ITEMS, timeout Windows

# Parallelismo e output del run combinato (default prudenti: Windows e' pesante).
TEST_ALL_PARALLEL="${TEST_ALL_PARALLEL:-2}"
TEST_ALL_OUTDIR="${TEST_ALL_OUTDIR:-${TMPDIR:-/tmp}/vmlab-e2e-all}"
[ -n "${1:-}" ] && TEST_ALL_PARALLEL="$1"

TITLE="VM Lab — Test end-to-end (Linux + Windows)"
PARALLEL="$TEST_ALL_PARALLEL"
OUTDIR="$TEST_ALL_OUTDIR"
OPEN_BROWSER="${TEST_OPEN_BROWSER:-1}"

# Item unificati: prima Linux ("id|vm|script" + type linux), poi Windows
# ("id|vm|script|agent" -> type windows).
ITEMS=()
for _it in "${TEST_ITEMS[@]}"; do ITEMS+=("$_it|linux"); done
for _it in "${TEST_WIN_ITEMS[@]}"; do
  IFS='|' read -r _id _vm _script _agent <<<"$_it"
  ITEMS+=("$_id|$_vm|$_script|windows|$_agent")
done
EXCLUDED_ITEMS=("${TEST_EXCLUDED_ITEMS[@]}" "${TEST_WIN_EXCLUDED_ITEMS[@]}")

source "$SCRIPT_DIR/test-lib.sh"
engine_main
