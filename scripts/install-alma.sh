#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EL_DISTRO=alma exec "$SCRIPT_DIR/install-enterprise-linux.sh" "$@"
