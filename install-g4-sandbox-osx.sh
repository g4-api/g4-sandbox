#!/usr/bin/env bash
# Purpose: One-line macOS installer for the G4 sandbox. Bootstraps a portable PowerShell 7 (no Homebrew, no .pkg,
#          no sudo), clones g4-sandbox, and runs Publish-G4Sandbox.ps1 -OperatingSystem MacOs with it.
# Usage:   curl -fsSL https://raw.githubusercontent.com/g4-api/g4-sandbox/main/install-g4-sandbox-osx.sh | bash
#          curl -fsSL .../install-g4-sandbox-osx.sh | bash -s -- --output-dir "$HOME/g4" -- -SkipScm
#          install-g4-sandbox-osx.sh [--output-dir PATH] [--help] [-- PUBLISH-ARGUMENTS...]
# Inputs:  GITHUB_TOKEN / GH_TOKEN (optional) are inherited by the publish for private release assets.
# Output:  The published sandbox in the output directory (default: $HOME/g4-sandbox). Progress on standard output,
#          diagnostics on standard error.
# Side effects: Downloads PowerShell and the repository into a unique, self-deleting work directory. Nothing is
#          installed globally and no shell profile, PATH, or system setting is changed.
# Exit codes: 0 success, 1 runtime failure, 2 invalid usage or unsupported host.
# Compatibility: Stock macOS Bash 3.2 or newer, macOS on Apple Silicon (arm64) or Intel (x86_64).
#          Linux uses install-g4-sandbox.sh; Windows uses install-g4-sandbox.ps1.

set -Eeuo pipefail

readonly REPO_URL='https://github.com/g4-api/g4-sandbox.git'
readonly PS_VERSION='7.6.0'

# SHA-256 digests GitHub publishes for the pinned PowerShell release assets. Pinning the version and its digests
# means the interpreter that runs the whole publish is verified before it is ever executed.
readonly PS_SHA256_ARM64='bb52db90e964ee0b91e93f559b350878c6b27c12fd51830d8eca1793712b9639'
readonly PS_SHA256_X64='7c6279cfead06324451a10ff741883086c9a00f024baea924bb9d3c106fe0c82'

OUTPUT_DIR="${HOME:-}/g4-sandbox"
ROOT_WORK_DIR=''
PUBLISH_ARGS=()

log() {
    printf '\n[+] %s\n' "$1"
}

fail() {
    printf 'install-g4-sandbox-osx: %s\n' "$1" >&2
    exit 1
}

fail_usage() {
    printf 'install-g4-sandbox-osx: %s\nRun with --help for usage.\n' "$1" >&2
    exit 2
}

usage() {
    # shellcheck disable=SC2016 # $HOME is printed literally as documentation.
    printf '%s\n' \
        'Usage: install-g4-sandbox-osx.sh [--output-dir PATH] [--help] [-- PUBLISH-ARGUMENTS...]' \
        '' \
        'Installs the G4 sandbox on macOS. A portable PowerShell 7 is downloaded into a temporary' \
        'work directory, verified, and used to run Publish-G4Sandbox.ps1 -OperatingSystem MacOs.' \
        '' \
        'Options:' \
        '  --output-dir PATH  Where the sandbox is published (default: $HOME/g4-sandbox).' \
        '  -h, --help         Show this help and exit.' \
        '  --                 Pass every following argument to Publish-G4Sandbox.ps1 (for example -SkipScm).' \
        '' \
        'One line:' \
        '  curl -fsSL https://raw.githubusercontent.com/g4-api/g4-sandbox/main/install-g4-sandbox-osx.sh | bash'
}

# Parse options; everything after '--' is forwarded to the publish script unchanged.
parse_arguments() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output-dir)
                [ "$#" -ge 2 ] && [ -n "$2" ] || fail_usage '--output-dir requires a path.'
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            --)
                shift
                PUBLISH_ARGS=("$@")
                return 0
                ;;
            *)
                fail_usage "Unknown option '$1'."
                ;;
        esac
    done
}

# Refuse anything but a normal macOS user session: the LiteLLM box builds PostgreSQL, which refuses to run as root.
assert_macos_host() {
    [ "$(uname -s)" = 'Darwin' ] ||
        fail_usage 'This installer supports macOS only. Use install-g4-sandbox.sh on Linux.'

    if [ "$(id -u)" -eq 0 ]; then
        fail_usage 'Run this installer as your normal user, not root or sudo (PostgreSQL refuses to run as root).'
    fi

    [ -n "${HOME:-}" ] || fail_usage 'HOME is not set.'
}

# Verify the stock tools this installer relies on. /usr/bin/git is only a stub until the Xcode Command Line Tools
# are installed, and invoking the stub opens an install dialog instead of failing, so check for the tools first.
assert_prerequisites() {
    local tool_name git_path

    for tool_name in curl tar shasum df mktemp; do
        command -v "$tool_name" >/dev/null 2>&1 || fail "Required command '$tool_name' is not available."
    done

    git_path="$(command -v git 2>/dev/null || true)"
    [ -n "$git_path" ] || fail 'git is required. Install the Xcode Command Line Tools: xcode-select --install'

    if [ "$git_path" = '/usr/bin/git' ] && ! xcode-select -p >/dev/null 2>&1; then
        fail 'git needs the Xcode Command Line Tools. Install them with: xcode-select --install'
    fi
}

# Resolve the native PowerShell architecture. A shell running under Rosetta reports x86_64 on Apple Silicon, so
# the hardware flag decides; the native arm64 build is always preferred there.
get_ps_arch() {
    local machine
    machine="$(uname -m)"

    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = '1' ]; then
        printf 'arm64\n'
        return 0
    fi

    case "$machine" in
        arm64) printf 'arm64\n' ;;
        x86_64) printf 'x64\n' ;;
        *) fail "Unsupported architecture: $machine" ;;
    esac
}

# Place the work directory on the roomiest local candidate so the LiteLLM and Chrome staging cannot fill a small
# volume. mktemp gives every run its own directory, so a crashed earlier run can never collide with this one.
create_work_dir() {
    local best='' best_kb=0 parent free_kb

    for parent in "${TMPDIR:-/tmp}" "$HOME/Library/Caches" '/tmp'; do
        [ -d "$parent" ] || continue
        free_kb="$(df -Pk "$parent" 2>/dev/null | awk 'NR==2 {print $4}')"

        if [ -n "$free_kb" ] && [ "$free_kb" -gt "$best_kb" ]; then
            best_kb="$free_kb"
            best="$parent"
        fi
    done

    [ -n "$best" ] || best='/tmp'
    ROOT_WORK_DIR="$(mktemp -d "${best%/}/g4-sandbox-bootstrap.XXXXXX")" ||
        fail "Could not create a work directory under '$best'."
}

# Publish writes subsystem deploy logs into its own work directory and deletes it at the end of every run. Keep
# any such log next to the sandbox so a failed deployment stays inspectable after the installer exits.
preserve_deploy_logs() {
    local logs_found preserved_dir log_file
    [ -n "$ROOT_WORK_DIR" ] && [ -d "$ROOT_WORK_DIR" ] || return 0

    logs_found="$(find "$ROOT_WORK_DIR" -maxdepth 4 -name '*-deploy.log' -type f 2>/dev/null || true)"
    [ -n "$logs_found" ] || return 0

    preserved_dir="${OUTPUT_DIR%/}-publish-logs"
    mkdir -p "$preserved_dir" 2>/dev/null || preserved_dir="$OUTPUT_DIR"

    while IFS= read -r log_file; do
        [ -n "$log_file" ] || continue
        cp -f "$log_file" "$preserved_dir/" 2>/dev/null || true
    done <<EOF
$logs_found
EOF

    if [ -d "$preserved_dir" ]; then
        log "Preserved deploy logs in $preserved_dir"
        for log_file in "$preserved_dir"/*; do
            if [ -e "$log_file" ]; then
                printf '  %s\n' "${log_file##*/}"
            fi
        done
    fi
}

# Remove only this run's mktemp directory; the pattern check keeps a corrupted variable from deleting anything else.
cleanup() {
    local exit_status=$?

    preserve_deploy_logs || true

    case "$ROOT_WORK_DIR" in
        */g4-sandbox-bootstrap.*)
            [ -d "$ROOT_WORK_DIR" ] && rm -rf -- "$ROOT_WORK_DIR"
            ;;
    esac

    return "$exit_status"
}

# Download, verify, and unpack the pinned portable PowerShell, then prove it starts.
download_portable_powershell() {
    local arch expected_sha actual_sha ps_file ps_url ps_archive

    arch="$(get_ps_arch)"
    case "$arch" in
        arm64) expected_sha="$PS_SHA256_ARM64" ;;
        x64) expected_sha="$PS_SHA256_X64" ;;
    esac

    ps_file="powershell-${PS_VERSION}-osx-${arch}.tar.gz"
    ps_url="https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/${ps_file}"
    ps_archive="$TOOLS_DIR/$ps_file"

    log "Downloading portable PowerShell ${PS_VERSION} for osx-${arch}"
    mkdir -p "$PS_DIR" || fail "Could not create '$PS_DIR'."

    curl --fail --location --silent --show-error --retry 3 \
        --output "$ps_archive" \
        "$ps_url" ||
        fail "Could not download '$ps_url'."

    actual_sha="$(shasum -a 256 "$ps_archive" | awk '{print $1}')"
    [ "$actual_sha" = "$expected_sha" ] ||
        fail "SHA-256 mismatch for '$ps_file'. Expected $expected_sha; received ${actual_sha:-nothing}."

    tar -xzf "$ps_archive" -C "$PS_DIR" || fail "Could not extract '$ps_file'."
    chmod +x "$PS_DIR/pwsh" || fail "Could not mark '$PS_DIR/pwsh' executable."

    # curl does not set the quarantine flag, but clear it anyway in case the archive arrived another way;
    # Gatekeeper would otherwise block pwsh and its libraries on first load.
    if command -v xattr >/dev/null 2>&1; then
        xattr -r -d com.apple.quarantine "$PS_DIR" 2>/dev/null || true
    fi

    # shellcheck disable=SC2016 # The expression is PowerShell, evaluated by pwsh, not by Bash.
    "$PS_DIR/pwsh" -NoLogo -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' >/dev/null ||
        fail "The downloaded PowerShell at '$PS_DIR/pwsh' does not start."
}

clone_repo() {
    log 'Cloning g4-sandbox'
    git clone --depth 1 "$REPO_URL" "$REPO_DIR" </dev/null || fail "Could not clone '$REPO_URL'."
}

publish_sandbox() {
    log "Publishing G4 sandbox to $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR" || fail "Could not create '$OUTPUT_DIR'."

    cd "$SRC_DIR" || fail "Repository source folder '$SRC_DIR' is missing."

    # Standard input is detached: under 'curl ... | bash' it is the installer script itself.
    "$PS_DIR/pwsh" -NoLogo -NoProfile -File './Publish-G4Sandbox.ps1' \
        -OperatingSystem 'MacOs' \
        -OutputDirectory "$OUTPUT_DIR" \
        ${PUBLISH_ARGS[@]+"${PUBLISH_ARGS[@]}"} </dev/null ||
        fail 'Publish-G4Sandbox.ps1 failed.'
}

main() {
    parse_arguments "$@"
    assert_macos_host
    assert_prerequisites

    # The publish runs from the repository's src folder, so a relative output path is anchored to the caller's
    # directory here, before any directory change.
    case "$OUTPUT_DIR" in
        /*) ;;
        *) OUTPUT_DIR="$PWD/$OUTPUT_DIR" ;;
    esac

    trap cleanup EXIT
    create_work_dir
    REPO_DIR="$ROOT_WORK_DIR/repo"
    SRC_DIR="$REPO_DIR/src"
    TOOLS_DIR="$ROOT_WORK_DIR/tools"
    PS_DIR="$TOOLS_DIR/powershell"

    download_portable_powershell
    clone_repo
    publish_sandbox

    log "Done. The G4 sandbox is in $OUTPUT_DIR"
}

main "$@"
