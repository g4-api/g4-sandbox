#!/usr/bin/env bash

# ==============================================================================
# Forgejo sandbox installer
# ==============================================================================
#
# Purpose: Install or update a sandboxed native Forgejo server plus one local
#          host-mode Actions runner, fully contained under /opt/forgejo.
# Usage: sudo bash deploy-forgejo-linux.sh [--help]
#        Optional runtime configuration is supplied as environment variables;
#        see CONFIGURATION OVERRIDES and RERUNS AND UPGRADES below.
# Compatibility: Bash 4.4 or newer on any Linux/Unix host with standard GNU
#                tools. The installer runs elevated with sudo only to create and
#                own the deployment folder; Forgejo and its runner then run as
#                the invoking user, with no systemd unit and no OS service
#                account, entirely inside the deployment folder.
#
# PURPOSE
#   Installs or updates a native Forgejo server with its application, SQLite
#   database, repositories, logs, configuration, and generated SSH host keys
#   contained under /opt/forgejo by default. It does not use Docker or require
#   an external database.
#
# WHAT THE SCRIPT DOES
#   1. Resolves the latest stable Forgejo version when FORGEJO_VERSION is unset.
#      Resolution uses Forgejo's official Codeberg release API. The script stops
#      with an error if the version cannot be resolved or validated; there is no
#      hard-coded fallback version.
#   2. Downloads the official Linux AMD64 binary and SHA-256 checksum, then
#      refuses to install the binary unless checksum verification succeeds.
#   3. Creates the /opt/forgejo folder structure and hands ownership to the
#      runtime user (the account that invoked sudo).
#   4. On a fresh installation, generates application secrets, initializes the
#      SQLite database, disables public registration, and creates an initial
#      administrator with a fixed development password (g4-admin / sk-12345).
#   5. Starts Forgejo in place as a background process (runner-style) with a
#      PID file and log under FORGEJO_ROOT, waits for its health endpoint, and
#      restarts it in place when an existing configuration needs Actions.
#   7. Enables Forgejo Actions and installs the latest stable Forgejo Runner. It
#      registers one global host runner with the linux:host label using offline
#      registration (a shared secret), writes the runner's server.connections
#      configuration, and starts it as a detached background process whose
#      workflows run as the invoking user.
#   8. Generates start-forgejo.sh and stop-forgejo.sh wrappers that start and
#      stop Forgejo and the local runner together in place.
#
# SUPPORTED OPERATING SYSTEMS
#   Verified:
#     - Debian GNU/Linux 13 (Trixie), x86_64
#
#   Expected to work:
#     - Other x86_64/AMD64 Linux distributions with standard GNU tools,
#       provided all prerequisites listed below exist.
#
#   Not supported by this script:
#     - Windows or macOS
#     - ARM, ARM64/AArch64, or other non-AMD64 architectures
#
# PREREQUISITES
#   - Root access through sudo (only to create and own the installation root)
#   - Internet access to codeberg.org and data.forgejo.org during installation
#   - Bash, curl, Git, runuser, ip, sha256sum, and common GNU tools
#   - Ports 3000/TCP and 2222/TCP available unless overridden
#
# BASIC USAGE
#   Run the installer with sudo from the account that should own the deployment:
#
#     sudo ./install-forgejo.sh
#
#   The elevated run creates and owns /opt/forgejo, then drops to the invoking
#   account (FORGEJO_USER) to install, migrate, and start Forgejo and its
#   runner. No OS account is created and no systemd unit is installed.
#
# PIN A SPECIFIC VERSION
#
#     sudo FORGEJO_VERSION=16.0.4 ./install-forgejo.sh
#
# CONFIGURATION OVERRIDES
#   Set any of these environment variables before the script name:
#
#     FORGEJO_VERSION        Release version; omit to resolve latest stable
#     FORGEJO_ROOT           Installation root          (default: /opt/forgejo)
#     FORGEJO_USER           Runtime account that owns the data and runs the
#                            processes (default: the account that invoked sudo;
#                            no OS account is created)
#     FORGEJO_IP             Advertised LAN IPv4        (default: 127.0.0.1 loopback,)*
#                                                        portable to any host
#     FORGEJO_HTTP_PORT      Web interface port         (default: 3000)*
#     FORGEJO_SSH_PORT       Built-in Git SSH port      (default: 2222)*
#     FORGEJO_ADMIN_USER     Initial administrator      (default: g4-admin)*
#     FORGEJO_ADMIN_EMAIL    Initial administrator mail (default: local address)*
#     FORGEJO_ADMIN_PASSWORD Initial administrator password (default: sk-12345)*
#     FORGEJO_RUNNER_VERSION Runner release version; omit to resolve latest
#     FORGEJO_RUNNER_LABELS  Runner labels              (default: linux:host)
#
#   * These values initialize a new installation. On an existing installation,
#     app.ini and administrator accounts are deliberately preserved. Change
#     existing settings in app.ini rather than expecting a rerun to rewrite them.
#
#   Example with explicit network settings:
#
#     sudo FORGEJO_IP=192.168.1.33 FORGEJO_HTTP_PORT=3000 \
#       FORGEJO_SSH_PORT=2222 ./install-forgejo.sh
#
# FIRST SIGN-IN
#   On a fresh installation, the script prints the fixed administrator
#   credentials and also writes them to:
#
#     /opt/forgejo/initial-admin.txt
#
#   Default credentials:   g4-admin / sk-12345
#   The password-change prompt is disabled. This is a local development
#   password; either override FORGEJO_ADMIN_PASSWORD for a strong password or
#   keep the instance on a trusted network / behind a TLS reverse proxy.
#
# RERUNS AND UPGRADES
#   The script is safe to rerun. When the SQLite database already exists, it
#   preserves the existing configuration, secrets, database, repositories, and
#   administrator accounts. It replaces the Forgejo binary, stops and restarts
#   the in-place server process, and checks its health.
#
#   The runner is registered idempotently from a shared secret that is reused
#   across reruns, so upgrades keep the same runner identity instead of creating
#   duplicates. The connection is written to runner/config.yml.
#
# NETWORK AND SECURITY NOTES
#   - The web interface listens on all interfaces and is advertised by LAN IP.
#   - HTTP is unencrypted on port 3000. Keep it on a trusted LAN or place it
#     behind a TLS reverse proxy before exposure to an untrusted network.
#   - Forgejo's built-in SSH server listens on port 2222 by default.
#   - Public account registration is disabled on fresh installations.
#   - Forgejo Actions is enabled and a linux:host runner executes workflows
#     directly on the host as $FORGEJO_USER; workflow code is not sandboxed.
#   - The server and runner are background processes owned by $FORGEJO_USER, not
#     systemd services or OS user accounts. start-forgejo.sh and stop-forgejo.sh
#     manage the full stack; run them as $FORGEJO_USER, or with sudo to drop to
#     that user. Re-run ./start-forgejo.sh after a reboot.
#   - Everything (binaries, configuration, database, repositories, logs, and
#     PID files) stays under FORGEJO_ROOT. No systemd unit and no OS service
#     account or group are created.
#   - Stop any running Forgejo server or runner first (./stop-forgejo.sh) before
#     running this installer; otherwise it exits without changing anything.
#
# ==============================================================================

if (( BASH_VERSINFO[0] < 4 ||
      (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
    printf 'This installer requires Bash 4.4 or newer.\n' >&2
    exit 2
fi

set -Eeuo pipefail

FORGEJO_VERSION="${FORGEJO_VERSION:-}"
FORGEJO_ROOT="${FORGEJO_ROOT:-/opt/forgejo}"
FORGEJO_USER="${FORGEJO_USER:-${SUDO_USER:-}}"
HTTP_PORT="${FORGEJO_HTTP_PORT:-3000}"
SSH_PORT="${FORGEJO_SSH_PORT:-2222}"

BIN_DIR="$FORGEJO_ROOT/bin"
BIN_PATH="$BIN_DIR/forgejo"
CONFIG_DIR="$FORGEJO_ROOT/custom/conf"
CONFIG_PATH="$CONFIG_DIR/app.ini"
DATA_DIR="$FORGEJO_ROOT/data"
DB_PATH="$DATA_DIR/forgejo.db"
LOG_DIR="$FORGEJO_ROOT/log"
SERVER_PID_FILE="$FORGEJO_ROOT/forgejo.pid"
SERVER_LOG_FILE="$LOG_DIR/forgejo.log"
RUNNER_DIR="$FORGEJO_ROOT/runner"
RUNNER_BIN="$RUNNER_DIR/forgejo-runner"
RUNNER_IDENTITY="$RUNNER_DIR/.runner"
RUNNER_CONFIG_FILE="$RUNNER_DIR/config.yml"
RUNNER_PID_FILE="$RUNNER_DIR/forgejo-runner.pid"
RUNNER_LOG="$LOG_DIR/forgejo-runner.log"
RUNNER_LABELS="${FORGEJO_RUNNER_LABELS:-linux:host}"
RUNNER_VERSION="${FORGEJO_RUNNER_VERSION:-}"

usage() {
    cat <<'EOF_USAGE'
Usage:
  sudo bash deploy-forgejo-linux.sh [--help]

Options:
  -h, --help               Show this help text and exit.

The installer is driven by optional environment variables set before the
command. See CONFIGURATION OVERRIDES and RERUNS AND UPGRADES in the header for
the full list; FORGEJO_VERSION and FORGEJO_RUNNER_VERSION pin the two release
binaries instead of resolving the latest stable versions.
EOF_USAGE
}

main() {
    for argument in "$@"; do
        case $argument in
            -h|--help)
                usage
                exit 0
                ;;
            *)
                printf 'Unknown option: %s\n' "$argument" >&2
                usage >&2
                exit 2
                ;;
        esac
    done

    if [[ "${EUID}" -ne 0 ]]; then
        echo "Run this installer elevated as root (see USAGE): bash $0" >&2
        echo "Only the elevated run can create and own $FORGEJO_ROOT; Forgejo and" >&2
        echo "its runner then run as a non-root account, never as root." >&2
        exit 1
    fi

    if [[ -z "$FORGEJO_USER" || "$FORGEJO_USER" == "root" ]]; then
        echo "Could not determine the runtime user to own $FORGEJO_ROOT." >&2
        echo "Run elevated from a normal account, or set FORGEJO_USER explicitly." >&2
        exit 1
    fi

    if ! id "$FORGEJO_USER" >/dev/null 2>&1; then
        echo "The runtime user does not exist: $FORGEJO_USER" >&2
        echo "This installer never creates accounts; set FORGEJO_USER to an existing user." >&2
        exit 1
    fi

    for command_name in curl sha256sum git install runuser awk grep sed head pgrep pkill tail; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            echo "Required command is missing: $command_name" >&2
            exit 1
        fi
    done

    if [[ -z "$FORGEJO_VERSION" ]]; then
        RELEASE_API_URL="https://codeberg.org/api/v1/repos/forgejo/forgejo/releases/latest"
        echo "FORGEJO_VERSION was not provided; resolving the latest stable release..."

        if ! RELEASE_JSON="$(curl --fail --location --silent --show-error "$RELEASE_API_URL")"; then
            echo "ERROR: FORGEJO_VERSION was not provided and the latest stable version could not be resolved." >&2
            echo "Set it explicitly, for example: FORGEJO_VERSION=16.0.4 bash $0" >&2
            exit 1
        fi

        FORGEJO_VERSION="$(
            printf '%s' "$RELEASE_JSON" |
                grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"v?[^"[:space:]]+"' |
                head -n 1 |
                sed -E 's/^.*"v?([^"[:space:]]+)"$/\1/' || true
        )"

        if [[ -z "$FORGEJO_VERSION" ]]; then
        echo "ERROR: FORGEJO_VERSION was not provided and the release API returned no usable stable version." >&2
            echo "Set it explicitly, for example: FORGEJO_VERSION=16.0.4 bash $0" >&2
            exit 1
        fi

        echo "Resolved latest stable Forgejo version: $FORGEJO_VERSION"
    else
        FORGEJO_VERSION="${FORGEJO_VERSION#v}"
        echo "Using requested Forgejo version: $FORGEJO_VERSION"
    fi

    if [[ ! "$FORGEJO_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]]; then
        echo "ERROR: Invalid or unresolved Forgejo version: '$FORGEJO_VERSION'" >&2
        exit 1
    fi

    ARCH="$(uname -m)"
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
        echo "This installer currently targets Linux AMD64; detected: $ARCH" >&2
        exit 1
    fi

    # Advertised address. Loopback by default so the box is relocatable and the
    # published sandbox works unchanged on any host; override for LAN visibility.
    LAN_IP="${FORGEJO_IP:-127.0.0.1}"

    # The boxed model: no systemd unit and no service account. A server or
    # runner left over from a previous attempt is stopped before installing, so
    # re-runs over a stale partial stage do not abort.

    if pgrep -f "$BIN_PATH.*web" >/dev/null 2>&1; then
        echo "Stopping leftover Forgejo server under $FORGEJO_ROOT."
        pkill -f "$BIN_PATH.*web" >/dev/null 2>&1 || true
    fi

    if pgrep -f "$RUNNER_BIN.*daemon" >/dev/null 2>&1; then
        echo "Stopping leftover Forgejo runner under $FORGEJO_ROOT."
        pkill -f "$RUNNER_BIN.*daemon" >/dev/null 2>&1 || true
    fi

    sleep 1

    install -d -o "$FORGEJO_USER" -g "$FORGEJO_USER" -m 0755 \
        "$FORGEJO_ROOT" \
        "$BIN_DIR" \
        "$FORGEJO_ROOT/custom" \
        "$CONFIG_DIR" \
        "$DATA_DIR" \
        "$LOG_DIR" \
        "$RUNNER_DIR"

    STAGING_DIR="$FORGEJO_ROOT/.staging"
    install -d -o "$FORGEJO_USER" -g "$FORGEJO_USER" -m 0700 "$STAGING_DIR"
    DOWNLOAD_DIR="$(mktemp -d "$STAGING_DIR/download.XXXXXX")"
    CONFIG_TMP="$(mktemp "$STAGING_DIR/config.XXXXXX")"
    RUNNER_CONFIG_TMP="$(mktemp "$STAGING_DIR/runner-config.XXXXXX")"
    START_SCRIPT_TMP="$(mktemp "$STAGING_DIR/start.XXXXXX")"
    STOP_SCRIPT_TMP="$(mktemp "$STAGING_DIR/stop.XXXXXX")"
    STARTED_SERVER_PID=""
    SETUP_SUCCEEDED=false
    cleanup() {
        if [[ "$SETUP_SUCCEEDED" != true && -n "$STARTED_SERVER_PID" ]]; then
            kill "$STARTED_SERVER_PID" 2>/dev/null || true
            rm -f "$SERVER_PID_FILE"
        fi
        rm -f "$CONFIG_TMP" "$RUNNER_CONFIG_TMP" "$START_SCRIPT_TMP" "$STOP_SCRIPT_TMP"
        rm -f "$DOWNLOAD_DIR/forgejo-${FORGEJO_VERSION}-linux-amd64"
        rm -f "$DOWNLOAD_DIR/forgejo-${FORGEJO_VERSION}-linux-amd64.sha256"
        if [[ -n "$RUNNER_VERSION" ]]; then
            rm -f "$DOWNLOAD_DIR/forgejo-runner-${RUNNER_VERSION}-linux-amd64"
            rm -f "$DOWNLOAD_DIR/forgejo-runner-${RUNNER_VERSION}-linux-amd64.sha256"
        fi
        rmdir "$DOWNLOAD_DIR" 2>/dev/null || true
        rmdir "$STAGING_DIR" 2>/dev/null || true
    }
    trap cleanup EXIT

    cd "$DOWNLOAD_DIR"
    BASE_URL="https://codeberg.org/forgejo/forgejo/releases/download/v${FORGEJO_VERSION}"

    curl --fail --location --progress-bar --show-error --remote-name \
        "$BASE_URL/forgejo-${FORGEJO_VERSION}-linux-amd64"
    curl --fail --location --progress-bar --show-error --remote-name \
        "$BASE_URL/forgejo-${FORGEJO_VERSION}-linux-amd64.sha256"

    sha256sum --check "forgejo-${FORGEJO_VERSION}-linux-amd64.sha256"

    install -o "$FORGEJO_USER" -g "$FORGEJO_USER" -m 0755 \
        "forgejo-${FORGEJO_VERSION}-linux-amd64" "$BIN_PATH"

    cd "$FORGEJO_ROOT"

    run_forgejo() {
        runuser -u "$FORGEJO_USER" -- env \
            HOME="$FORGEJO_ROOT" \
            USER="$FORGEJO_USER" \
            "$BIN_PATH" \
            --work-path "$FORGEJO_ROOT" \
            --config "$CONFIG_PATH" \
            "$@"
    }

    NEW_INSTALL=false
    if [[ ! -f "$DB_PATH" ]]; then
        NEW_INSTALL=true

        SECRET_KEY="$(runuser -u "$FORGEJO_USER" -- env HOME="$FORGEJO_ROOT" "$BIN_PATH" generate secret SECRET_KEY)"
        INTERNAL_TOKEN="$(runuser -u "$FORGEJO_USER" -- env HOME="$FORGEJO_ROOT" "$BIN_PATH" generate secret INTERNAL_TOKEN)"
        LFS_JWT_SECRET="$(runuser -u "$FORGEJO_USER" -- env HOME="$FORGEJO_ROOT" "$BIN_PATH" generate secret JWT_SECRET)"
        OAUTH2_JWT_SECRET="$(runuser -u "$FORGEJO_USER" -- env HOME="$FORGEJO_ROOT" "$BIN_PATH" generate secret JWT_SECRET)"

        cat >"$CONFIG_TMP" <<EOF
APP_NAME = Forgejo
RUN_USER = $FORGEJO_USER
RUN_MODE = prod

[repository]
ROOT = data/repositories

[server]
DOMAIN = $LAN_IP
HTTP_ADDR = 0.0.0.0
HTTP_PORT = $HTTP_PORT
ROOT_URL = http://$LAN_IP:$HTTP_PORT/
APP_DATA_PATH = data
LFS_START_SERVER = true
OFFLINE_MODE = true
START_SSH_SERVER = true
SSH_DOMAIN = $LAN_IP
SSH_PORT = $SSH_PORT
SSH_LISTEN_HOST = 0.0.0.0
SSH_LISTEN_PORT = $SSH_PORT
BUILTIN_SSH_SERVER_USER = $FORGEJO_USER

[database]
DB_TYPE = sqlite3
PATH = data/forgejo.db

[security]
INSTALL_LOCK = true
SECRET_KEY = $SECRET_KEY
INTERNAL_TOKEN = $INTERNAL_TOKEN

[service]
DISABLE_REGISTRATION = true

[actions]
ENABLED = true

[lfs]
JWT_SECRET = $LFS_JWT_SECRET

[oauth2]
JWT_SECRET = $OAUTH2_JWT_SECRET

[log]
MODE = console,file
LEVEL = Info
ROOT_PATH = log
EOF

        install -o "$FORGEJO_USER" -g "$FORGEJO_USER" -m 0640 "$CONFIG_TMP" "$CONFIG_PATH"
        run_forgejo migrate

        ADMIN_USER="${FORGEJO_ADMIN_USER:-g4-admin}"
        ADMIN_EMAIL="${FORGEJO_ADMIN_EMAIL:-forgejo-admin@localhost}"
        ADMIN_PASSWORD="${FORGEJO_ADMIN_PASSWORD:-sk-12345}"

        run_forgejo admin user create \
            --username "$ADMIN_USER" \
            --password "$ADMIN_PASSWORD" \
            --email "$ADMIN_EMAIL" \
            --admin \
            --must-change-password=false

        CREDENTIAL_FILE="$FORGEJO_ROOT/initial-admin.txt"
        cat >"$CREDENTIAL_FILE" <<EOF
Forgejo URL: http://$LAN_IP:$HTTP_PORT/
Username: $ADMIN_USER
Password: $ADMIN_PASSWORD
EOF
        chown "$FORGEJO_USER:$FORGEJO_USER" "$CREDENTIAL_FILE"
        chmod 0600 "$CREDENTIAL_FILE"
    elif [[ ! -f "$CONFIG_PATH" ]]; then
        echo "Database exists but configuration is missing: $CONFIG_PATH" >&2
        exit 1
    fi

    # The boxed model starts the server as a background process in place, the same
    # way the runner and the generated start/stop wrappers manage it.

    HEALTH_URL="http://127.0.0.1:$HTTP_PORT/api/healthz"

    start_server_process() {
        runuser -u "$FORGEJO_USER" -- nohup env \
            HOME="$FORGEJO_ROOT" \
            USER="$FORGEJO_USER" \
            "$BIN_PATH" web \
            --work-path "$FORGEJO_ROOT" \
            --config "$CONFIG_PATH" \
            >>"$SERVER_LOG_FILE" 2>&1 &
        STARTED_SERVER_PID=$!
        disown "$STARTED_SERVER_PID" 2>/dev/null || true
        printf '%s\n' "$STARTED_SERVER_PID" >"$SERVER_PID_FILE"
        chown "$FORGEJO_USER:$FORGEJO_USER" "$SERVER_PID_FILE" 2>/dev/null || true

        sleep 2
        if ! kill -0 "$STARTED_SERVER_PID" 2>/dev/null; then
            echo "ERROR: Forgejo stopped immediately after starting." >&2
            if [[ -f "$SERVER_LOG_FILE" ]]; then
                echo "Recent server log ($SERVER_LOG_FILE):" >&2
                tail -n 50 "$SERVER_LOG_FILE" >&2
            fi
            rm -f "$SERVER_PID_FILE"
            exit 1
        fi
    }

    stop_server_process() {
        local server_pid

        if [[ -f "$SERVER_PID_FILE" ]]; then
            server_pid="$(cat "$SERVER_PID_FILE" 2>/dev/null || true)"
            if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
                kill "$server_pid" 2>/dev/null || true
            fi
            rm -f "$SERVER_PID_FILE"
        fi
    }

    wait_for_health() {
        local attempt

        for attempt in {1..30}; do
            if curl --fail --silent --show-error --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
                return 0
            fi
            if [[ "$attempt" -eq 30 ]]; then
                echo "Forgejo did not become healthy. Recent server log:" >&2
                tail -n 50 "$SERVER_LOG_FILE" >&2
                return 1
            fi
            sleep 1
        done
    }

    start_server_process
    wait_for_health

    # ==============================================================================
    # Local Actions runner
    # ==============================================================================

    # Forgejo Actions must be enabled before a runner can register. Fresh
    # installations already carry [actions] ENABLED = true; existing installations
    # are updated in place and restarted so the setting is live before the runner
    # is registered.

    ensure_actions_enabled() {
        local updated_config

        updated_config="$(
            awk '
                /^[[:space:]]*\[/ {
                    in_actions = ($0 ~ /^[[:space:]]*\[actions\]/)
                    if (in_actions) {
                        actions_section_seen = 1
                        print
                        print "ENABLED = true"
                        next
                    }
                    print
                    next
                }
                in_actions && /^[[:space:]]*ENABLED[[:space:]]*=/ { next }
                { print }
                END {
                    if (!actions_section_seen) {
                        print "[actions]"
                        print "ENABLED = true"
                    }
                }
            ' "$CONFIG_PATH"
        )"

        if [[ "$(<"$CONFIG_PATH")" == "$updated_config" ]]; then
            return 1
        fi

        printf '%s\n' "$updated_config" >"$CONFIG_TMP"
        install -o "$FORGEJO_USER" -g "$FORGEJO_USER" -m 0640 "$CONFIG_TMP" "$CONFIG_PATH"
        return 0
    }

    if ensure_actions_enabled; then
        echo "Enabled Forgejo Actions in $CONFIG_PATH; restarting the server in place."
        stop_server_process
        start_server_process
        wait_for_health
    fi

    # Resolve the Runner version from the official release API unless an override
    # was provided, then validate it as a stable semantic version.

    if [[ -z "$RUNNER_VERSION" ]]; then
        RUNNER_RELEASE_API_URL="https://data.forgejo.org/api/v1/repos/forgejo/runner/releases/latest"
        echo "FORGEJO_RUNNER_VERSION was not provided; resolving the latest stable Forgejo Runner release..."
        if ! RUNNER_RELEASE_JSON="$(curl --fail --location --silent --show-error "$RUNNER_RELEASE_API_URL")"; then
            echo "ERROR: FORGEJO_RUNNER_VERSION was not provided and the latest stable Runner version could not be resolved." >&2
            echo "Set it explicitly, for example: FORGEJO_RUNNER_VERSION=13.1.0 bash $0" >&2
            exit 1
        fi

        RUNNER_VERSION="$(
            printf '%s' "$RUNNER_RELEASE_JSON" |
                grep -oE '"name"[[:space:]]*:[[:space:]]*"v?[^"[:space:]]+"' |
                head -n 1 |
                sed -E 's/^.*"v?([^"[:space:]]+)"$/\1/' || true
        )"

        if [[ -z "$RUNNER_VERSION" ]]; then
            echo "ERROR: The Forgejo Runner release API returned no usable version." >&2
            echo "Set it explicitly, for example: FORGEJO_RUNNER_VERSION=13.1.0 bash $0" >&2
            exit 1
        fi

        echo "Resolved latest stable Forgejo Runner version: $RUNNER_VERSION"
    else
        RUNNER_VERSION="${RUNNER_VERSION#v}"
        echo "Using requested Forgejo Runner version: $RUNNER_VERSION"
    fi

    if [[ ! "$RUNNER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]]; then
        echo "ERROR: Invalid or unresolved Forgejo Runner version: '$RUNNER_VERSION'" >&2
        exit 1
    fi

    # Download the Runner binary and its SHA-256 checksum, refuse to install on a
    # checksum mismatch, and place the verified binary inside the runner directory.

    RUNNER_BASE_URL="https://code.forgejo.org/forgejo/runner/releases/download/v${RUNNER_VERSION}"

    (
        cd "$DOWNLOAD_DIR" || exit 1

        curl --fail --location --progress-bar --show-error --remote-name \
            "$RUNNER_BASE_URL/forgejo-runner-${RUNNER_VERSION}-linux-amd64"
        curl --fail --location --progress-bar --show-error --remote-name \
            "$RUNNER_BASE_URL/forgejo-runner-${RUNNER_VERSION}-linux-amd64.sha256"

        if ! sha256sum --check "forgejo-runner-${RUNNER_VERSION}-linux-amd64.sha256"; then
            echo "ERROR: Forgejo Runner binary checksum verification failed." >&2
            exit 1
        fi
    )

    install -o "$FORGEJO_USER" -g "$FORGEJO_USER" -m 0755 \
        "$DOWNLOAD_DIR/forgejo-runner-${RUNNER_VERSION}-linux-amd64" "$RUNNER_BIN"
    echo "Forgejo Runner $RUNNER_VERSION downloaded and verified."

    # Forgejo Runner v12 and newer read their connection from the server.connections
    # map of a YAML config file; the legacy `register` command and the `.runner`
    # identity file are deprecated and no longer feed the daemon. Prepare that
    # config so the daemon starts with a usable connection.

    RUNNER_NAME="g4-linux"
    RUNNER_SECRET=""

    # Reuse a previously issued runner secret so reruns keep the same identity:
    # first from an existing config, then from a legacy .runner identity file.
    # Only a 40-character hexadecimal secret can be reused; anything else is
    # replaced by a fresh secret.
    if [[ -f "$RUNNER_CONFIG_FILE" ]]; then
        RUNNER_SECRET="$(sed -nE 's/^[[:space:]]*token:[[:space:]]*(.*[^[:space:]])[[:space:]]*$/\1/p' "$RUNNER_CONFIG_FILE" | head -n 1)"
    fi
    if [[ ! "$RUNNER_SECRET" =~ ^[0-9a-f]{40}$ && -f "$RUNNER_IDENTITY" ]]; then
        RUNNER_SECRET="$(sed -nE 's/.*"token"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p' "$RUNNER_IDENTITY" | head -n 1)"
    fi

    if [[ ! "$RUNNER_SECRET" =~ ^[0-9a-f]{40}$ ]]; then
        RUNNER_SECRET="$(run_forgejo forgejo-cli actions generate-secret)"
        if [[ ! "$RUNNER_SECRET" =~ ^[0-9a-f]{40}$ ]]; then
            echo "ERROR: The runner secret could not be generated." >&2
            exit 1
        fi
    fi

    # Offline registration: hand the shared secret to Forgejo and receive the
    # runner uuid. It is idempotent for a given name and secret, so reruns do not
    # create duplicate runners. The secret is never printed.

    RUNNER_REGISTER_OUTPUT="$(run_forgejo forgejo-cli actions register \
        --name "$RUNNER_NAME" \
        --secret "$RUNNER_SECRET")"

    RUNNER_UUID="$(printf '%s\n' "$RUNNER_REGISTER_OUTPUT" |
        grep -oE '[0-9a-fA-F-]{36}' | tail -n 1)"
    if [[ -z "$RUNNER_UUID" ]]; then
        RUNNER_UUID="$(printf '%s\n' "$RUNNER_REGISTER_OUTPUT" |
            awk 'NF { last = $0 } END { print last }')"
    fi

    if [[ -z "$RUNNER_UUID" ]]; then
        echo "ERROR: The runner registration returned no uuid." >&2
        exit 1
    fi

    cat >"$RUNNER_CONFIG_TMP" <<EOF
log:
  level: info

runner:
  file: runner/.runner
  capacity: 1
  timeout: 3h
  labels:
    - $RUNNER_LABELS

server:
  connections:
    forgejo:
      url: http://127.0.0.1:$HTTP_PORT/
      uuid: $RUNNER_UUID
      token: $RUNNER_SECRET
EOF

    install -o "$FORGEJO_USER" -g "$FORGEJO_USER" -m 0600 \
        "$RUNNER_CONFIG_TMP" "$RUNNER_CONFIG_FILE"

    echo "Configured runner: $RUNNER_NAME ($RUNNER_LABELS)"

    # Start the runner daemon as a detached background process (runner-style) and
    # record its PID; verify it survived startup.

    runuser -u "$FORGEJO_USER" -- nohup env \
        HOME="$FORGEJO_ROOT" \
        USER="$FORGEJO_USER" \
        "$RUNNER_BIN" daemon \
        --config "$RUNNER_CONFIG_FILE" \
        >>"$RUNNER_LOG" 2>&1 &
    RUNNER_PID=$!
    disown "$RUNNER_PID" 2>/dev/null || true

    sleep 2
    if ! kill -0 "$RUNNER_PID" 2>/dev/null; then
        echo "ERROR: The runner stopped immediately after starting." >&2
        if [[ -f "$RUNNER_LOG" ]]; then
            echo "Recent runner log ($RUNNER_LOG):" >&2
            tail -n 20 "$RUNNER_LOG" >&2
        fi
        exit 1
    fi
    printf '%s\n' "$RUNNER_PID" >"$RUNNER_PID_FILE"
    chown "$FORGEJO_USER:$FORGEJO_USER" "$RUNNER_PID_FILE" 2>/dev/null || true

    # Generate full-stack start and stop launchers so a reboot or an explicit stop
    # can be followed by a single start-forgejo.sh invocation. The launchers manage
    # both processes in place by PID file, then by process match; no systemd unit is
    # involved, and they run the processes as $FORGEJO_USER.

    cat >"$START_SCRIPT_TMP" <<'EOF_START_LAUNCHER'
#!/usr/bin/env bash

# ==============================================================================
# Start Forgejo and its local host-mode Actions runner.
# ==============================================================================
#
# PURPOSE
#   Starts the Forgejo server and the local linux:host runner as in-place
#   background processes inside the deployment folder. No service account and
#   no systemd unit are involved. When run as root the processes are dropped to
#   RUN_USER with runuser; otherwise they start as the current user.
#   Idempotent; safe to run again after a reboot.
#
# USAGE
#   ./start-forgejo.sh          (as RUN_USER)
#   sudo ./start-forgejo.sh     (drops to RUN_USER)
#
# EXIT CODES
#   0   Forgejo and its runner are running.

set -Eeuo pipefail

RUN_USER="__RUN_USER__"
HTTP_PORT="__HTTP_PORT__"

# The box is relocatable: every path below is derived from this launcher's own
# location, so the published sandbox works unchanged from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGEJO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
BIN_PATH="$FORGEJO_ROOT/bin/forgejo"
CONFIG_PATH="$FORGEJO_ROOT/app.ini"
SERVER_PID_FILE="$FORGEJO_ROOT/run/forgejo.pid"
SERVER_LOG_FILE="$FORGEJO_ROOT/run/forgejo.log"
HEALTH_URL="http://127.0.0.1:$HTTP_PORT/api/healthz"
RUNNER_BIN="$FORGEJO_ROOT/bin/forgejo-runner"
RUNNER_CONFIG_FILE="$FORGEJO_ROOT/runner/config.yml"
RUNNER_PID_FILE="$FORGEJO_ROOT/run/forgejo-runner.pid"
RUNNER_LOG="$FORGEJO_ROOT/run/forgejo-runner.log"

cd "$FORGEJO_ROOT"

server_is_running() {
    local server_pid
    local server_basename
    local process_pattern

    if [[ -f "$SERVER_PID_FILE" ]]; then
        server_pid="$(cat "$SERVER_PID_FILE" 2>/dev/null || true)"
        if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
            return 0
        fi
        rm -f "$SERVER_PID_FILE"
    fi

    server_basename="${BIN_PATH##*/}"
    process_pattern="[${server_basename:0:1}]${server_basename:1}.*web"
    pgrep -f "$process_pattern" >/dev/null 2>&1
}

start_server() {
    local server_pid
    local server_command=(env "HOME=$FORGEJO_ROOT" "$BIN_PATH" web \
        --work-path "$FORGEJO_ROOT" --config "$CONFIG_PATH")

    if [[ "${EUID}" -eq 0 ]]; then
        runuser -u "$RUN_USER" -- nohup "${server_command[@]}" >>"$SERVER_LOG_FILE" 2>&1 &
    else
        nohup "${server_command[@]}" >>"$SERVER_LOG_FILE" 2>&1 &
    fi
    server_pid=$!
    disown "$server_pid" 2>/dev/null || true

    sleep 2
    if ! kill -0 "$server_pid" 2>/dev/null; then
        echo "Forgejo stopped immediately after starting." >&2
        if [[ -f "$SERVER_LOG_FILE" ]]; then
            echo "Recent server log ($SERVER_LOG_FILE):" >&2
            tail -n 50 "$SERVER_LOG_FILE" >&2
        fi
        return 1
    fi
    printf '%s\n' "$server_pid" >"$SERVER_PID_FILE"
}

runner_is_running() {
    local runner_pid
    local runner_basename
    local process_pattern

    if [[ -f "$RUNNER_PID_FILE" ]]; then
        runner_pid="$(cat "$RUNNER_PID_FILE" 2>/dev/null || true)"
        if [[ -n "$runner_pid" ]] && kill -0 "$runner_pid" 2>/dev/null; then
            return 0
        fi
        rm -f "$RUNNER_PID_FILE"
    fi

    runner_basename="${RUNNER_BIN##*/}"
    process_pattern="[${runner_basename:0:1}]${runner_basename:1}.*daemon"
    pgrep -f "$process_pattern" >/dev/null 2>&1
}

start_runner() {
    local runner_pid
    local runner_command=(env "HOME=$FORGEJO_ROOT" "$RUNNER_BIN" daemon \
        --config "$RUNNER_CONFIG_FILE")

    if [[ "${EUID}" -eq 0 ]]; then
        runuser -u "$RUN_USER" -- nohup "${runner_command[@]}" >>"$RUNNER_LOG" 2>&1 &
    else
        nohup "${runner_command[@]}" >>"$RUNNER_LOG" 2>&1 &
    fi
    runner_pid=$!
    disown "$runner_pid" 2>/dev/null || true

    sleep 2
    if ! kill -0 "$runner_pid" 2>/dev/null; then
        echo "The runner stopped immediately after starting." >&2
        if [[ -f "$RUNNER_LOG" ]]; then
            echo "Recent runner log ($RUNNER_LOG):" >&2
            tail -n 20 "$RUNNER_LOG" >&2
        fi
        return 1
    fi
    printf '%s\n' "$runner_pid" >"$RUNNER_PID_FILE"
}

if ! server_is_running; then
    if ! start_server; then
        exit 1
    fi
fi

HEALTH_UNREACHABLE=true
for attempt in {1..30}; do
    if curl --fail --silent --show-error --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
        HEALTH_UNREACHABLE=false
        break
    fi
    sleep 1
done

if [[ "$HEALTH_UNREACHABLE" == true ]]; then
    echo "Forgejo did not become healthy within 30 seconds." >&2
    if [[ -f "$SERVER_LOG_FILE" ]]; then
        echo "Recent server log ($SERVER_LOG_FILE):" >&2
        tail -n 50 "$SERVER_LOG_FILE" >&2
    fi
    exit 1
fi

if ! runner_is_running; then
    if ! start_runner; then
        exit 1
    fi
fi

echo "Forgejo and its local runner are running."
echo "Web: http://127.0.0.1:__HTTP_PORT__/"
EOF_START_LAUNCHER

    sed -e "s|__RUN_USER__|$FORGEJO_USER|g" \
        -e "s|__HTTP_PORT__|$HTTP_PORT|g" \
        "$START_SCRIPT_TMP" >"$FORGEJO_ROOT/start-forgejo.sh"
    chmod 0755 "$FORGEJO_ROOT/start-forgejo.sh"
    chown "$FORGEJO_USER:$FORGEJO_USER" "$FORGEJO_ROOT/start-forgejo.sh"

    cat >"$STOP_SCRIPT_TMP" <<'EOF_STOP_LAUNCHER'
#!/usr/bin/env bash

# ==============================================================================
# Stop Forgejo and its local host-mode Actions runner.
# ==============================================================================
#
# PURPOSE
#   Stops the local runner and server (by PID file, then by process match) that
#   run as background processes inside the deployment folder. No systemd unit
#   is involved. When run as root the process signals are dropped to RUN_USER
#   with runuser; otherwise they act as the current user. Idempotent; run
#   start-forgejo.sh to bring the full stack back up.
#
# USAGE
#   ./stop-forgejo.sh          (as RUN_USER)
#   sudo ./stop-forgejo.sh     (drops to RUN_USER)
#
# EXIT CODES
#   0   Forgejo and its runner are stopped.

set -Eeuo pipefail

RUN_USER="__RUN_USER__"

# The box is relocatable: every path below is derived from this launcher's own
# location, so the published sandbox works unchanged from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGEJO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
BIN_PATH="$FORGEJO_ROOT/bin/forgejo"
SERVER_PID_FILE="$FORGEJO_ROOT/run/forgejo.pid"
RUNNER_BIN="$FORGEJO_ROOT/bin/forgejo-runner"
RUNNER_PID_FILE="$FORGEJO_ROOT/run/forgejo-runner.pid"

cd "$FORGEJO_ROOT"

as_owner() {
    if [[ "${EUID}" -eq 0 ]]; then
        runuser -u "$RUN_USER" -- "$@"
    else
        "$@"
    fi
}

stop_by_pid_file() {
    local pid_file=$1
    local process_pid

    if [[ -f "$pid_file" ]]; then
        process_pid="$(cat "$pid_file" 2>/dev/null || true)"
        if [[ -n "$process_pid" ]] && kill -0 "$process_pid" 2>/dev/null; then
            as_owner kill "$process_pid" 2>/dev/null || true
        fi
        rm -f "$pid_file"
    fi
}

stop_by_pattern() {
    local binary_path=$1
    local match_word=$2
    local binary_basename
    local process_pattern
    local attempt

    binary_basename="${binary_path##*/}"
    process_pattern="[${binary_basename:0:1}]${binary_basename:1}.*${match_word}"

    if as_owner pgrep -f "$process_pattern" >/dev/null 2>&1; then
        as_owner pkill -f "$process_pattern" 2>/dev/null || true
        for attempt in {1..20}; do
            if ! as_owner pgrep -f "$process_pattern" >/dev/null 2>&1; then
                return 0
            fi
            sleep 1
        done
        as_owner pkill -9 -f "$process_pattern" 2>/dev/null || true
    fi
}

stop_by_pid_file "$RUNNER_PID_FILE"
stop_by_pattern "$RUNNER_BIN" daemon

stop_by_pid_file "$SERVER_PID_FILE"
stop_by_pattern "$BIN_PATH" web

echo "Forgejo and its local runner are stopped."
EOF_STOP_LAUNCHER

    sed -e "s|__RUN_USER__|$FORGEJO_USER|g" \
        "$STOP_SCRIPT_TMP" >"$FORGEJO_ROOT/stop-forgejo.sh"
    chmod 0755 "$FORGEJO_ROOT/stop-forgejo.sh"
    chown "$FORGEJO_USER:$FORGEJO_USER" "$FORGEJO_ROOT/stop-forgejo.sh"

    SETUP_SUCCEEDED=true

    echo
    echo "Forgejo is running."
    echo "Web: http://$LAN_IP:$HTTP_PORT/"
    echo "SSH: $FORGEJO_USER@$LAN_IP:$SSH_PORT"
    echo "Version: $($BIN_PATH --version)"
    echo "PID file: $SERVER_PID_FILE"
    echo "Server log: $SERVER_LOG_FILE"
    echo "Stop: $FORGEJO_ROOT/stop-forgejo.sh"
    echo "Start (also after reboot): $FORGEJO_ROOT/start-forgejo.sh"
    echo "Runner: g4-linux ($RUNNER_LABELS, runs as $FORGEJO_USER)"
    echo "Runner version: $RUNNER_VERSION"
    echo "Launchers: $FORGEJO_ROOT/start-forgejo.sh and $FORGEJO_ROOT/stop-forgejo.sh"

    if [[ "$NEW_INSTALL" == true ]]; then
        echo
        echo "Initial administrator credentials:"
        cat "$FORGEJO_ROOT/initial-admin.txt"
        echo
        echo "Password change on first login: disabled"
        echo "Remove the credential file when you no longer need it:"
        echo "rm $FORGEJO_ROOT/initial-admin.txt"
    fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
