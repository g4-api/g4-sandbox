#!/usr/bin/env bash
# Linux equivalent of Start-Hub.cmd
# Starts the G4 Hub service using the bundled .NET runtime.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR/g4-hub"
exec "$SCRIPT_DIR/runtime/dotnet/dotnet" G4.Services.Hub.dll
