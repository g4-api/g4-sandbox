#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGEJO_START="$SCRIPT_DIR/forgejo/start-forgejo.sh"

if [[ ! -f "$FORGEJO_START" ]]; then
    echo "[ERROR] The portable Forgejo box was not found at '$SCRIPT_DIR/forgejo'." >&2
    echo "[ERROR] This sandbox was published without the source-control subsystem." >&2
    exit 1
fi

if [[ ! -x "$FORGEJO_START" ]]; then
    chmod +x "$FORGEJO_START" || true
fi

exec "$FORGEJO_START" "$@"