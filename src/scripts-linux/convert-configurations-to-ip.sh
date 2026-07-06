#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOST="${1:-}"

if [[ -z "$TARGET_HOST" ]]; then
    TARGET_HOST="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }' || true)"
fi
if [[ -z "$TARGET_HOST" ]]; then
    echo "ERROR: could not detect an IPv4 address and no IP argument was given." >&2
    exit 1
fi

CONFIG_DIR="$SCRIPT_DIR/selenium-grid/configurations"

echo "Converting relay urls in $CONFIG_DIR/*.toml to host $TARGET_HOST"
shopt -s nullglob
for file in "$CONFIG_DIR"/*.toml; do
    tmp="$(mktemp)"
    sed -E "s#(url[[:space:]]*=[[:space:]]*\"https?://)[^:/\"]+#\1${TARGET_HOST}#g" "$file" > "$tmp"
    if cmp -s "$file" "$tmp"; then
        echo "  Unchanged: $(basename "$file")"
    else
        cat "$tmp" > "$file"
        echo "  Updated:   $(basename "$file")"
    fi
    rm -f "$tmp"
done
