#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGEJO_BOX_DIR="$SCRIPT_DIR/forgejo"
FORGEJO_START="$FORGEJO_BOX_DIR/start-forgejo.sh"

if [[ ! -d "$FORGEJO_BOX_DIR" ]]; then
    echo "[ERROR] The portable Forgejo box was not found at '$FORGEJO_BOX_DIR'." >&2
    echo "[ERROR] This sandbox was published without the source-control subsystem." >&2
    exit 1
fi

if [[ ! -f "$FORGEJO_START" ]]; then
    echo "[ERROR] The Forgejo box at '$FORGEJO_BOX_DIR' is incomplete: 'start-forgejo.sh' is missing." >&2
    echo "[ERROR] The sandbox was published from a failed source-control deployment." >&2
    exit 1
fi

# The installer always lays the box out as bin/forgejo, data/forgejo.db and
# runner/forgejo-runner. Refuse to start when that layout is not intact: the
# generated launcher would otherwise fail later with an unrelated error (for
# example a missing run/ log directory) that hides the real cause.
for required_path in "bin/forgejo" "data/forgejo.db" "custom/conf/app.ini" "runner/forgejo-runner"; do
    if [[ ! -e "$FORGEJO_BOX_DIR/$required_path" ]]; then
        echo "[ERROR] The Forgejo box at '$FORGEJO_BOX_DIR' is incomplete: '$required_path' is missing." >&2
        echo "[ERROR] The sandbox was published from a failed source-control deployment." >&2
        exit 1
    fi
done

if [[ ! -x "$FORGEJO_START" ]]; then
    chmod +x "$FORGEJO_START" || true
fi

exec "$FORGEJO_START" "$@"