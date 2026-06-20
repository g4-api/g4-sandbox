#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_URI="${1:-http://localhost:4444/wd/hub}"
NODE_PORT="${2:-5552}"

JAVA="$SCRIPT_DIR/runtime/jdk/bin/java"
SELENIUM_JAR="$SCRIPT_DIR/selenium-grid/selenium-server.jar"
CHROME_DRIVER="$SCRIPT_DIR/drivers/chrome/chromedriver"
NODE_CONFIG="$SCRIPT_DIR/selenium-grid/configurations/chrome-node.toml"

(
    cd "$SCRIPT_DIR/selenium-grid"
    "$JAVA" -jar "$SELENIUM_JAR" hub --session-request-timeout 42300
) &

(
    cd "$SCRIPT_DIR/drivers/chrome"
    "$CHROME_DRIVER" --port=9513
) &

cd "$SCRIPT_DIR/selenium-grid"
exec "$JAVA" -jar "$SELENIUM_JAR" node --hub "$HUB_URI" --config "$NODE_CONFIG" --port "$NODE_PORT"
