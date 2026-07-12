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

# Install the bundled G4 engine client extension if this VS Code does not have it.
extension_id="g4-api.g4-engine-client"
vs_code_cli="$SCRIPT_DIR/bot-utilities/vs-code/bin/code"
vs_code_exe="$SCRIPT_DIR/bot-utilities/vs-code/code"
vsix_dir="$SCRIPT_DIR/bot-utilities/vsixs"

if [[ -x "$vs_code_cli" ]]; then
    if ! "$vs_code_cli" --list-extensions | grep -qi "^${extension_id}$"; then
        vsix_file="$(find "$vsix_dir" -maxdepth 1 -type f -name "${extension_id}*.vsix" 2>/dev/null | sort -Vr | head -n 1 || true)"

        if [[ -n "$vsix_file" ]]; then
            "$vs_code_cli" --install-extension "$vsix_file" || echo "Failed to install VS Code extension: $vsix_file" >&2
        else
            echo "VSIX file was not found: $vsix_dir/${extension_id}*.vsix" >&2
        fi
    fi
else
    echo "Bundled VS Code CLI was not found or is not executable: $vs_code_cli" >&2
fi

# Always launch bundled VS Code when the executable is available.
if [[ -x "$vs_code_exe" ]]; then
    "$vs_code_exe" &
elif [[ -x "$vs_code_cli" ]]; then
    "$vs_code_cli" &
else
    echo "Bundled VS Code executable was not found: $vs_code_exe" >&2
fi
