#!/usr/bin/env bash
# Linux equivalent of Start-DevEnvironment.cmd
#
# Opens each service in its own terminal window, then launches VS Code.
# Note: the Windows dev environment also starts the UIA Driver Server and the
# UIA Recorder. Those are Windows-only UI Automation tools and have no Linux
# equivalent, so they are intentionally not launched here. Only the Hub runs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Open the given command in a new terminal window, trying common emulators.
# Falls back to a backgrounded process (with a warning) on headless hosts.
open_terminal() {
    local title="$1"
    local cmd="$2"

    if command -v gnome-terminal >/dev/null 2>&1; then
        gnome-terminal --title="$title" -- bash -lc "$cmd; exec bash"
    elif command -v konsole >/dev/null 2>&1; then
        konsole -p "tabtitle=$title" -e bash -lc "$cmd; exec bash" &
    elif command -v xterm >/dev/null 2>&1; then
        xterm -T "$title" -e bash -lc "$cmd; exec bash" &
    elif command -v x-terminal-emulator >/dev/null 2>&1; then
        x-terminal-emulator -e bash -lc "$cmd; exec bash" &
    else
        echo "No supported terminal emulator found; running '$title' in background." >&2
        bash -lc "$cmd" &
    fi
}

# Start the G4 Hub in its own terminal (reuses start-hub.sh).
open_terminal "G4 Hub" "'$SCRIPT_DIR/start-hub.sh'"

# Launch VS Code if the CLI is available; skip silently otherwise.
if command -v code >/dev/null 2>&1; then
    code &
fi
