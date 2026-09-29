#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LITELLM_START="$SCRIPT_DIR/litellm/start-litellm.sh"

# The box launcher runs the sandbox's bundled PowerShell; make it reachable
# even when this launcher is invoked via sudo, which resets PATH to
# secure_path. Setting PATH here is unaffected by that.
export PATH="$SCRIPT_DIR/bot-utilities/powershell:$PATH"

# PostgreSQL refuses to run as root, so when this launcher is invoked via sudo
# re-exec as the invoking or box-owning non-root user.
if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    RUN_AS="${SUDO_USER:-}"
    if [[ -z "$RUN_AS" || "$RUN_AS" == "root" ]]; then
        RUN_AS="$(stat -c '%U' "$SCRIPT_DIR/litellm" 2>/dev/null || true)"
    fi
    if [[ -z "$RUN_AS" || "$RUN_AS" == "root" ]]; then
        echo "[ERROR] Refusing to run the LiteLLM box as root (PostgreSQL forbids it)." >&2
        echo "[ERROR] Re-run from a normal account, or with sudo from one so SUDO_USER is set." >&2
        exit 1
    fi
    echo "Re-running as '$RUN_AS' (PostgreSQL refuses to run as root)..." >&2
    exec sudo -u "$RUN_AS" env PATH="$PATH" "$LITELLM_START" "$@"
fi

if [[ ! -f "$LITELLM_START" ]]; then
    echo "[ERROR] The portable LiteLLM box was not found at '$SCRIPT_DIR/litellm'." >&2
    echo "[ERROR] This sandbox was published without the LiteLLM subsystem." >&2
    exit 1
fi

if [[ ! -x "$LITELLM_START" ]]; then
    chmod +x "$LITELLM_START" || true
fi

exec "$LITELLM_START" "$@"
