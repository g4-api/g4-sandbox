#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR/bot-utilities/chromium-peek-x64"
exec "$SCRIPT_DIR/runtime/dotnet/dotnet" ChromiumPeek.dll
