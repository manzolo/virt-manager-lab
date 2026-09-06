#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$SCRIPT_DIR/lab.env" ]]; then
    # shellcheck source-path=SCRIPTDIR
    # shellcheck source=lab.env.example
    source "$SCRIPT_DIR/lab.env"
    export VM_BASE_DIR VM_USER VM_PASS VM_PASS_HASH VM_REALNAME
fi
if [[ "${1:-}" == install ]]; then
    shift
    exec python3 "$SCRIPT_DIR/install-network-vm.py" "$@"
fi
exec python3 "$SCRIPT_DIR/lab-network.py" "$@"
