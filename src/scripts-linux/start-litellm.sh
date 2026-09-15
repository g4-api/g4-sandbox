#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITELLM_START="$SCRIPT_DIR/litellm/start-litellm.sh"

if [[ ! -f "$LITELLM_START" ]]; then
    echo "[ERROR] The portable LiteLLM box was not found at '$SCRIPT_DIR/litellm'." >&2
    echo "[ERROR] This sandbox was published without the LiteLLM subsystem." >&2
    exit 1
fi

if [[ ! -x "$LITELLM_START" ]]; then
    chmod +x "$LITELLM_START" || true
fi

exec "$LITELLM_START" "$@"
