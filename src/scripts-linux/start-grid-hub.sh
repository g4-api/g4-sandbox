#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_HOST="${1:-}"
HUB_PORT="${2:-4444}"

if [[ -z "$HUB_HOST" ]]; then
    HUB_HOST="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit } }' || true)"
fi
if [[ -z "$HUB_HOST" ]]; then
    HUB_HOST="localhost"
fi

JAVA="$SCRIPT_DIR/runtime/jdk/bin/java"
SELENIUM_JAR="$SCRIPT_DIR/selenium-grid/selenium-server.jar"

cd "$SCRIPT_DIR/selenium-grid"
exec "$JAVA" -jar "$SELENIUM_JAR" hub --host "$HUB_HOST" --port "$HUB_PORT"
