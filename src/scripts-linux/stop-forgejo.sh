#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGEJO_BOX_DIR="$SCRIPT_DIR/forgejo"
FORGEJO_STOP="$FORGEJO_BOX_DIR/stop-forgejo.sh"

if [[ ! -d "$FORGEJO_BOX_DIR" ]]; then
    echo "[ERROR] The portable Forgejo box was not found at '$FORGEJO_BOX_DIR'." >&2
    echo "[ERROR] This sandbox was published without the source-control subsystem." >&2
    exit 1
fi

if [[ ! -f "$FORGEJO_STOP" ]]; then
    echo "[ERROR] The Forgejo box at '$FORGEJO_BOX_DIR' is incomplete: 'stop-forgejo.sh' is missing." >&2
    echo "[ERROR] The sandbox was published from a failed source-control deployment." >&2
    exit 1
fi

if [[ ! -x "$FORGEJO_STOP" ]]; then
    chmod +x "$FORGEJO_STOP" || true
fi

exec "$FORGEJO_STOP" "$@"