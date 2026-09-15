#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITELLM_STOP="$SCRIPT_DIR/litellm/stop-litellm.sh"

if [[ ! -f "$LITELLM_STOP" ]]; then
    echo "[ERROR] The portable LiteLLM box was not found at '$SCRIPT_DIR/litellm'." >&2
    echo "[ERROR] This sandbox was published without the LiteLLM subsystem." >&2
    exit 1
fi

if [[ ! -x "$LITELLM_STOP" ]]; then
    chmod +x "$LITELLM_STOP" || true
fi

exec "$LITELLM_STOP" "$@"
