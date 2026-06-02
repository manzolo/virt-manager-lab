#!/usr/bin/env bash
# Rigenera il PDF del cheat sheet virsh da docs/virsh-cheatsheet.html.
# Usa Chrome/Chromium headless (--print-to-pdf): rispetta colori e layout CSS.
#
# Uso: bash scripts/gen-cheatsheet.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/docs"
SRC="$DOCS_DIR/virsh-cheatsheet.html"
PDF="$DOCS_DIR/virsh-cheatsheet.pdf"

[[ -f "$SRC" ]] || { echo "Sorgente mancante: $SRC" >&2; exit 1; }

# Trova un browser Chromium-compatibile.
BROWSER=""
for b in google-chrome google-chrome-stable chromium chromium-browser chrome; do
    if command -v "$b" >/dev/null 2>&1; then BROWSER="$b"; break; fi
done
[[ -n "$BROWSER" ]] || { echo "Nessun Chrome/Chromium trovato (serve per --print-to-pdf)." >&2; exit 1; }

PROFILE="$(mktemp -d)"
trap 'rm -rf "$PROFILE"' EXIT

echo "[*] Genero $PDF con $BROWSER..."
"$BROWSER" --headless=new --disable-gpu --no-sandbox \
    --no-pdf-header-footer \
    --user-data-dir="$PROFILE" \
    --print-to-pdf="$PDF" \
    "file://$SRC" >/dev/null 2>&1

[[ -s "$PDF" ]] || { echo "Generazione fallita: $PDF non creato." >&2; exit 1; }
echo "    -> $PDF ($(du -h "$PDF" | cut -f1))"
