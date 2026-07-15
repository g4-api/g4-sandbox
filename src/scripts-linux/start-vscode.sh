#!/usr/bin/env bash
# Installs or upgrades the bundled G4 extension, then launches bundled VS Code.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

extension_id="g4-api.g4-engine-client"
vs_code_cli="$SCRIPT_DIR/bot-utilities/vs-code/bin/code"
vs_code_exe="$SCRIPT_DIR/bot-utilities/vs-code/code"
vsix_dir="$SCRIPT_DIR/bot-utilities/vsixs"

# Reads the authoritative version from the package manifest inside a VSIX.
read_vsix_version() {
    local vsix_file="$1"
    local version

    if command -v unzip >/dev/null 2>&1; then
        version="$(unzip -p "$vsix_file" extension/package.json 2>/dev/null \
            | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
            | head -n 1 || true)"

        if [[ -n "$version" ]]; then
            printf '%s\n' "$version"
            return
        fi
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "$vsix_file" <<'PYTHON'
import json
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    with archive.open("extension/package.json") as package:
        print(json.load(package)["version"])
PYTHON
    fi
}

# Returns success only when the first numeric dotted version is newer.
version_is_newer() {
    local candidate="$1"
    local installed="$2"
    local candidate_parts
    local installed_parts
    local part_count
    local index
    local candidate_part
    local installed_part

    if [[ ! "$candidate" =~ ^[0-9]+(\.[0-9]+)*$ ]] || [[ ! "$installed" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        return 2
    fi

    IFS='.' read -r -a candidate_parts <<< "$candidate"
    IFS='.' read -r -a installed_parts <<< "$installed"

    part_count="${#candidate_parts[@]}"
    if (( ${#installed_parts[@]} > part_count )); then
        part_count="${#installed_parts[@]}"
    fi

    for ((index = 0; index < part_count; index++)); do
        candidate_part=$((10#${candidate_parts[index]:-0}))
        installed_part=$((10#${installed_parts[index]:-0}))

        if (( candidate_part > installed_part )); then
            return 0
        fi
        if (( candidate_part < installed_part )); then
            return 1
        fi
    done

    return 1
}

if [[ -x "$vs_code_cli" ]]; then
    vsix_file="$(find "$vsix_dir" -maxdepth 1 -type f -name "${extension_id}*.vsix" 2>/dev/null | sort -Vr | head -n 1 || true)"

    if [[ -n "$vsix_file" ]]; then
        installed_entry="$("$vs_code_cli" --list-extensions --show-versions 2>/dev/null | grep -i "^${extension_id}@" | head -n 1 || true)"
        installed_version="${installed_entry#*@}"
        bundled_version="$(read_vsix_version "$vsix_file" || true)"
        install_extension=false

        if [[ -z "$installed_entry" ]]; then
            echo "Installing VS Code extension from '$vsix_file'."
            install_extension=true
        elif [[ -z "$bundled_version" ]]; then
            echo "Could not read the bundled extension version from '$vsix_file'." >&2
        elif version_is_newer "$bundled_version" "$installed_version"; then
            echo "Updating VS Code extension from $installed_version to $bundled_version."
            install_extension=true
        else
            comparison_status=$?
            if (( comparison_status == 2 )); then
                echo "Could not compare installed version '$installed_version' with bundled version '$bundled_version'." >&2
            fi
        fi

        if [[ "$install_extension" == true ]]; then
            "$vs_code_cli" --install-extension "$vsix_file" \
                || echo "Failed to install VS Code extension: $vsix_file" >&2
        fi
    else
        echo "VSIX file was not found: $vsix_dir/${extension_id}*.vsix" >&2
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
