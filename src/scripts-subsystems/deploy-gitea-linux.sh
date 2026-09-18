#!/usr/bin/env bash

# ==============================================================================
# Gitea sandbox installer
# ==============================================================================
#
# Purpose: Install or update a boxed native Gitea server under /opt/gitea.
# Usage: sudo bash deploy-gitea-linux.sh [--help]
# Compatibility: Bash 4.4 or newer on any Linux/Unix host with standard GNU
#                tools. The installer runs elevated with sudo only to create and
#                own the deployment folder; Gitea then runs as the invoking
#                user, with no systemd unit and no OS service account, entirely
#                inside the deployment folder.
#
# PURPOSE
#   Install or update a boxed native Gitea server with its application, SQLite
#   database, repositories, logs, configuration, and generated SSH host keys
#   contained under /opt/gitea by default. No Docker, no external database, no
#   systemd unit, and no OS service account are used.
#
# WHAT THE SCRIPT DOES
#   1. Resolves the latest stable Gitea version when GITEA_VERSION is unset.
#      Resolution uses the official go-gitea/gitea GitHub release API. The
#      script stops with an error if the version cannot be resolved or validated;
#      there is no hard-coded fallback version.
#   2. Downloads the official Linux AMD64 binary and SHA-256 checksum from
#      dl.gitea.com, then refuses installation unless verification succeeds.
#   3. Creates the /opt/gitea directory structure and hands ownership to the
#      runtime user (the account that invoked sudo).
#   4. On a fresh installation, generates application secrets, initializes the
#      SQLite database, disables public registration, and creates this account:
#
#        Username: admin
#        Password: sk-12345
#
#      The administrator is NOT required to change the password after login.
#   5. Runs the idempotent database migration.
#   6. Starts Gitea in place as a background process (runner-style) with a PID
#      file and log under GITEA_ROOT, then waits for its health endpoint.
#   7. Generates start-gitea.sh and stop-gitea.sh wrappers for reboots.
#
# SUPPORTED OPERATING SYSTEMS
#   Primary supported target:
#     - Debian GNU/Linux 13 (Trixie), x86_64
#
#   Expected to work:
#     - Other x86_64/AMD64 Linux distributions with standard GNU tools,
#       provided all prerequisites listed below exist.
#
#   Not supported by this script:
#     - Windows or macOS (Gitea itself supports them, but this Bash installer
#       targets Linux)
#     - ARM, ARM64/AArch64, or other non-AMD64 architectures
#
# PREREQUISITES
#   - Root access through sudo (only to create and own the installation root)
#   - Internet access to api.github.com and dl.gitea.com during installation
#   - Bash, curl, Git, runuser, ip, sha256sum, and common GNU tools
#   - Ports 3001/TCP and 2223/TCP available unless overridden
#
# BASIC USAGE
#   Run the installer with sudo from the account that should own the deployment:
#
#     sudo ./install-gitea.sh
#
#   The elevated run creates and owns /opt/gitea, then drops to the invoking
#   account (GITEA_USER) to install, migrate, and start Gitea. No OS account is
#   created and no systemd unit is installed.
#
# PIN A SPECIFIC VERSION
#
#     sudo GITEA_VERSION=1.27.3 ./install-gitea.sh
#
# CONFIGURATION OVERRIDES
#   Set any of these environment variables before the script name:
#
#     GITEA_VERSION        Release version; omit to resolve latest stable
#     GITEA_ROOT           Installation root          (default: /opt/gitea)
#     GITEA_USER           Runtime account that owns the data and runs the
#                          process (default: the account that invoked sudo;
#                          no OS account is created)
#     GITEA_IP             Advertised LAN IPv4        (default: auto-detected)*
#     GITEA_HTTP_PORT      Web interface port         (default: 3001)*
#     GITEA_SSH_PORT       Built-in Git SSH port      (default: 2223)*
#     GITEA_ADMIN_EMAIL    Administrator email        (default: admin@localhost)*
#
#   * These values initialize a new installation. On an existing installation,
#     app.ini and administrator accounts are deliberately preserved. Change
#     existing settings in app.ini rather than expecting a rerun to rewrite them.
#
#   Example with explicit network settings:
#
#     sudo GITEA_IP=192.168.1.33 GITEA_HTTP_PORT=3001 \
#       GITEA_SSH_PORT=2223 ./install-gitea.sh
#
# FIRST SIGN-IN
#   Open the URL printed at the end of the installation and sign in with:
#
#     Username: admin
#     Password: sk-12345
#
#   The password-change prompt is explicitly disabled. Because this password is
#   documented and predictable, use this configuration only on a trusted lab
#   network or change the password manually before exposing Gitea elsewhere.
#
# RERUNS AND UPGRADES
#   The script is safe to rerun. When the SQLite database already exists, it
#   preserves the existing configuration, secrets, database, repositories, and
#   administrator accounts. It replaces the Gitea binary, runs the idempotent
#   database migration, stops and restarts the in-place server process, and
#   checks its health. Back up /opt/gitea before production upgrades.
#
# NETWORK AND SECURITY NOTES
#   - The web interface listens on all interfaces and is advertised by LAN IP.
#   - HTTP is unencrypted on port 3001. Keep it on a trusted LAN or place it
#     behind a TLS reverse proxy before exposure to an untrusted network.
#   - Gitea's built-in SSH server listens on port 2223 by default.
#   - Public account registration is disabled on fresh installations.
#   - Ports differ from the Forgejo installer defaults so both can coexist.
#   - Everything (binaries, configuration, database, repositories, logs, and
#     PID files) stays under GITEA_ROOT. No systemd unit and no OS service
#     account or group are created.
#   - Gitea runs as a background process owned by $GITEA_USER, not a systemd
#     service or OS user account. start-gitea.sh and stop-gitea.sh manage it;
#     run them as $GITEA_USER, or with sudo to drop to that user. Re-run
#     ./start-gitea.sh after a reboot.
#   - Stop any running Gitea server first (./stop-gitea.sh) before running this
#     installer; otherwise it exits without changing anything.
#
# ==============================================================================

if (( BASH_VERSINFO[0] < 4 ||
      (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
    printf 'This installer requires Bash 4.4 or newer.\n' >&2
    exit 2
fi

set -Eeuo pipefail

GITEA_VERSION="${GITEA_VERSION:-}"
GITEA_ROOT="${GITEA_ROOT:-/opt/gitea}"
GITEA_USER="${GITEA_USER:-${SUDO_USER:-}}"
HTTP_PORT="${GITEA_HTTP_PORT:-3001}"
SSH_PORT="${GITEA_SSH_PORT:-2223}"
ADMIN_USER="admin"
ADMIN_PASSWORD="sk-12345"
ADMIN_EMAIL="${GITEA_ADMIN_EMAIL:-admin@localhost}"

BIN_DIR="$GITEA_ROOT/bin"
BIN_PATH="$BIN_DIR/gitea"
CONFIG_DIR="$GITEA_ROOT/custom/conf"
CONFIG_PATH="$CONFIG_DIR/app.ini"
DATA_DIR="$GITEA_ROOT/data"
DB_PATH="$DATA_DIR/gitea.db"
LOG_DIR="$GITEA_ROOT/log"
SERVER_PID_FILE="$GITEA_ROOT/gitea.pid"
SERVER_LOG_FILE="$LOG_DIR/gitea.log"

usage() {
    cat <<'EOF_USAGE'
Usage:
  sudo bash deploy-gitea-linux.sh [--help]

Options:
  -h, --help               Show this help text and exit.

The installer is driven by optional environment variables set before the
command. See CONFIGURATION OVERRIDES and RERUNS AND UPGRADES in the header for
the full list; GITEA_VERSION pins the release binary instead of resolving the
latest stable version.
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
        echo "Only the elevated run can create and own $GITEA_ROOT; Gitea then runs" >&2
        echo "as a non-root account, never as root." >&2
        exit 1
    fi

    if [[ -z "$GITEA_USER" || "$GITEA_USER" == "root" ]]; then
        echo "Could not determine the runtime user to own $GITEA_ROOT." >&2
        echo "Run elevated from a normal account, or set GITEA_USER explicitly." >&2
        exit 1
    fi

    if ! id "$GITEA_USER" >/dev/null 2>&1; then
        echo "The runtime user does not exist: $GITEA_USER" >&2
        echo "This installer never creates accounts; set GITEA_USER to an existing user." >&2
        exit 1
    fi

    for command_name in curl sha256sum git install runuser ip awk grep sed head pgrep pkill tail; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            echo "Required command is missing: $command_name" >&2
            exit 1
        fi
    done

    if [[ -z "$GITEA_VERSION" ]]; then
        RELEASE_API_URL="https://api.github.com/repos/go-gitea/gitea/releases/latest"
        echo "GITEA_VERSION was not provided; resolving the latest stable release..."

        if ! RELEASE_JSON="$(curl --fail --location --silent --show-error \
            -H 'Accept: application/vnd.github+json' \
            -H 'X-GitHub-Api-Version: 2022-11-28' \
            "$RELEASE_API_URL")"; then
            echo "ERROR: GITEA_VERSION was not provided and the latest stable version could not be resolved." >&2
            echo "Set it explicitly, for example: GITEA_VERSION=1.27.3 bash $0" >&2
            exit 1
        fi

        GITEA_VERSION="$(
            printf '%s' "$RELEASE_JSON" |
                grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"v?[^"[:space:]]+"' |
                head -n 1 |
                sed -E 's/^.*"v?([^"[:space:]]+)"$/\1/' || true
        )"

        if [[ -z "$GITEA_VERSION" ]]; then
            echo "ERROR: GITEA_VERSION was not provided and the release API returned no usable stable version." >&2
            echo "Set it explicitly, for example: GITEA_VERSION=1.27.3 bash $0" >&2
            exit 1
        fi

        echo "Resolved latest stable Gitea version: $GITEA_VERSION"
    else
        GITEA_VERSION="${GITEA_VERSION#v}"
        echo "Using requested Gitea version: $GITEA_VERSION"
    fi

    if [[ ! "$GITEA_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]]; then
        echo "ERROR: Invalid or unresolved Gitea version: '$GITEA_VERSION'" >&2
        exit 1
    fi

    ARCH="$(uname -m)"
    if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
        echo "This installer currently targets Linux AMD64; detected: $ARCH" >&2
        exit 1
    fi

    if [[ -n "${GITEA_IP:-}" ]]; then
        LAN_IP="$GITEA_IP"
    else
        LAN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}')"
        if [[ -z "$LAN_IP" ]]; then
            LAN_IP="$(hostname -I | awk '{print $1}')"
        fi
    fi

    if [[ -z "$LAN_IP" ]]; then
        echo "Could not determine a LAN IPv4 address. Re-run with GITEA_IP=x.x.x.x." >&2
        exit 1
    fi

    # The boxed model: no systemd unit and no service account. A running server
    # is detected directly and must be stopped before installing.

    if pgrep -f "$BIN_PATH.*web" >/dev/null 2>&1; then
        echo "A Gitea server process is already running." >&2
        echo "Stop it first: $GITEA_ROOT/stop-gitea.sh" >&2
        exit 1
    fi

    install -d -o "$GITEA_USER" -g "$GITEA_USER" -m 0755 \
        "$GITEA_ROOT" \
        "$BIN_DIR" \
        "$GITEA_ROOT/custom" \
        "$CONFIG_DIR" \
        "$DATA_DIR" \
        "$LOG_DIR"

    STAGING_DIR="$GITEA_ROOT/.staging"
    install -d -o "$GITEA_USER" -g "$GITEA_USER" -m 0700 "$STAGING_DIR"
    DOWNLOAD_DIR="$(mktemp -d "$STAGING_DIR/download.XXXXXX")"
    CONFIG_TMP="$(mktemp "$STAGING_DIR/config.XXXXXX")"
    START_SCRIPT_TMP="$(mktemp "$STAGING_DIR/start.XXXXXX")"
    STOP_SCRIPT_TMP="$(mktemp "$STAGING_DIR/stop.XXXXXX")"
    STARTED_SERVER_PID=""
    SETUP_SUCCEEDED=false
    cleanup() {
        if [[ "$SETUP_SUCCEEDED" != true && -n "$STARTED_SERVER_PID" ]]; then
            kill "$STARTED_SERVER_PID" 2>/dev/null || true
            rm -f "$SERVER_PID_FILE"
        fi
        rm -f "$CONFIG_TMP" "$START_SCRIPT_TMP" "$STOP_SCRIPT_TMP"
        rm -f "$DOWNLOAD_DIR/gitea-${GITEA_VERSION}-linux-amd64"
        rm -f "$DOWNLOAD_DIR/gitea-${GITEA_VERSION}-linux-amd64.sha256"
        rmdir "$DOWNLOAD_DIR" 2>/dev/null || true
        rmdir "$STAGING_DIR" 2>/dev/null || true
    }
    trap cleanup EXIT

    cd "$DOWNLOAD_DIR"
    BASE_URL="https://dl.gitea.com/gitea/${GITEA_VERSION}"

    if ! curl --fail --location --progress-bar --show-error --remote-name \
        "$BASE_URL/gitea-${GITEA_VERSION}-linux-amd64"; then
        echo "ERROR: Could not download Gitea $GITEA_VERSION for Linux AMD64." >&2
        exit 1
    fi

    if ! curl --fail --location --progress-bar --show-error --remote-name \
        "$BASE_URL/gitea-${GITEA_VERSION}-linux-amd64.sha256"; then
        echo "ERROR: Could not download the SHA-256 checksum for Gitea $GITEA_VERSION." >&2
        exit 1
    fi

    if ! sha256sum --check "gitea-${GITEA_VERSION}-linux-amd64.sha256"; then
        echo "ERROR: Gitea binary checksum verification failed. Nothing was installed." >&2
        exit 1
    fi

    install -o "$GITEA_USER" -g "$GITEA_USER" -m 0755 \
        "gitea-${GITEA_VERSION}-linux-amd64" "$BIN_PATH"

    cd "$GITEA_ROOT"

    run_gitea() {
        runuser -u "$GITEA_USER" -- env \
            HOME="$GITEA_ROOT" \
            USER="$GITEA_USER" \
            GITEA_WORK_DIR="$GITEA_ROOT" \
            GITEA_CUSTOM="$GITEA_ROOT/custom" \
            "$BIN_PATH" \
            --work-path "$GITEA_ROOT" \
            --custom-path "$GITEA_ROOT/custom" \
            --config "$CONFIG_PATH" \
            "$@"
    }

    NEW_INSTALL=false
    if [[ ! -f "$DB_PATH" ]]; then
        NEW_INSTALL=true

        SECRET_KEY="$(runuser -u "$GITEA_USER" -- env HOME="$GITEA_ROOT" "$BIN_PATH" generate secret SECRET_KEY)"
        INTERNAL_TOKEN="$(runuser -u "$GITEA_USER" -- env HOME="$GITEA_ROOT" "$BIN_PATH" generate secret INTERNAL_TOKEN)"
        LFS_JWT_SECRET="$(runuser -u "$GITEA_USER" -- env HOME="$GITEA_ROOT" "$BIN_PATH" generate secret JWT_SECRET)"
        OAUTH2_JWT_SECRET="$(runuser -u "$GITEA_USER" -- env HOME="$GITEA_ROOT" "$BIN_PATH" generate secret JWT_SECRET)"

        cat >"$CONFIG_TMP" <<EOF
APP_NAME = Gitea
RUN_USER = $GITEA_USER
RUN_MODE = prod
WORK_PATH = $GITEA_ROOT

[repository]
ROOT = $DATA_DIR/repositories

[server]
DOMAIN = $LAN_IP
HTTP_ADDR = 0.0.0.0
HTTP_PORT = $HTTP_PORT
ROOT_URL = http://$LAN_IP:$HTTP_PORT/
APP_DATA_PATH = $DATA_DIR
LFS_START_SERVER = true
OFFLINE_MODE = true
START_SSH_SERVER = true
SSH_DOMAIN = $LAN_IP
SSH_PORT = $SSH_PORT
SSH_LISTEN_HOST = 0.0.0.0
SSH_LISTEN_PORT = $SSH_PORT
BUILTIN_SSH_SERVER_USER = $GITEA_USER

[database]
DB_TYPE = sqlite3
PATH = $DB_PATH

[security]
INSTALL_LOCK = true
SECRET_KEY = $SECRET_KEY
INTERNAL_TOKEN = $INTERNAL_TOKEN

[service]
DISABLE_REGISTRATION = true

[lfs]
JWT_SECRET = $LFS_JWT_SECRET

[oauth2]
JWT_SECRET = $OAUTH2_JWT_SECRET

[log]
MODE = console,file
LEVEL = Info
ROOT_PATH = $LOG_DIR
EOF

        install -o "$GITEA_USER" -g "$GITEA_USER" -m 0640 "$CONFIG_TMP" "$CONFIG_PATH"
    elif [[ ! -f "$CONFIG_PATH" ]]; then
        echo "Database exists but configuration is missing: $CONFIG_PATH" >&2
        exit 1
    fi

    # Gitea documents this command as idempotent, so it is used for both fresh
    # installations and upgrades before the server is started.

    run_gitea migrate

    if [[ "$NEW_INSTALL" == true ]]; then
        run_gitea admin user create \
            --username "$ADMIN_USER" \
            --password "$ADMIN_PASSWORD" \
            --email "$ADMIN_EMAIL" \
            --admin \
            --must-change-password=false
    fi

    # The boxed model starts the server as a background process in place, the
    # same way the generated start/stop wrappers manage it.

    HEALTH_URL="http://127.0.0.1:$HTTP_PORT/api/healthz"

    wait_for_health() {
        local attempt

        for attempt in {1..30}; do
            if curl --fail --silent --show-error --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
                return 0
            fi
            if [[ "$attempt" -eq 30 ]]; then
                echo "Gitea did not become healthy. Recent server log:" >&2
                tail -n 50 "$SERVER_LOG_FILE" >&2
                return 1
            fi
            sleep 1
        done
    }

    start_server_process() {
        runuser -u "$GITEA_USER" -- nohup env \
            HOME="$GITEA_ROOT" \
            USER="$GITEA_USER" \
            GITEA_WORK_DIR="$GITEA_ROOT" \
            GITEA_CUSTOM="$GITEA_ROOT/custom" \
            "$BIN_PATH" web \
            --work-path "$GITEA_ROOT" \
            --custom-path "$GITEA_ROOT/custom" \
            --config "$CONFIG_PATH" \
            >>"$SERVER_LOG_FILE" 2>&1 &
        STARTED_SERVER_PID=$!
        disown "$STARTED_SERVER_PID" 2>/dev/null || true
        printf '%s\n' "$STARTED_SERVER_PID" >"$SERVER_PID_FILE"
        chown "$GITEA_USER:$GITEA_USER" "$SERVER_PID_FILE" 2>/dev/null || true

        sleep 2
        if ! kill -0 "$STARTED_SERVER_PID" 2>/dev/null; then
            echo "ERROR: Gitea stopped immediately after starting." >&2
            if [[ -f "$SERVER_LOG_FILE" ]]; then
                echo "Recent server log ($SERVER_LOG_FILE):" >&2
                tail -n 50 "$SERVER_LOG_FILE" >&2
            fi
            rm -f "$SERVER_PID_FILE"
            exit 1
        fi
    }

    start_server_process
    wait_for_health

    # Generate start and stop launchers so a reboot or an explicit stop can be
    # followed by a single start-gitea.sh invocation. The launchers manage the
    # server in place by PID file, then by process match; no systemd unit is
    # involved, and they run the server as $GITEA_USER.

    cat >"$START_SCRIPT_TMP" <<'EOF_START_LAUNCHER'
#!/usr/bin/env bash

# ==============================================================================
# Start Gitea.
# ==============================================================================
#
# PURPOSE
#   Starts the Gitea server as an in-place background process inside the
#   deployment folder. No service account and no systemd unit are involved.
#   When run as root the process is dropped to RUN_USER with runuser; otherwise
#   it starts as the current user. Idempotent; safe to run again after a reboot.
#
# USAGE
#   ./start-gitea.sh          (as RUN_USER)
#   sudo ./start-gitea.sh     (drops to RUN_USER)
#
# EXIT CODES
#   0   Gitea is running.

set -Eeuo pipefail

RUN_USER="__RUN_USER__"
GITEA_ROOT="__GITEA_ROOT__"
BIN_PATH="__BIN_PATH__"
CONFIG_PATH="__CONFIG_PATH__"
SERVER_PID_FILE="__SERVER_PID_FILE__"
SERVER_LOG_FILE="__SERVER_LOG_FILE__"
HEALTH_URL="__HEALTH_URL__"

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
    local server_command=(env "HOME=$GITEA_ROOT" "GITEA_WORK_DIR=$GITEA_ROOT" \
        "GITEA_CUSTOM=$GITEA_ROOT/custom" "$BIN_PATH" web \
        --work-path "$GITEA_ROOT" --custom-path "$GITEA_ROOT/custom" \
        --config "$CONFIG_PATH")

    if [[ "${EUID}" -eq 0 ]]; then
        runuser -u "$RUN_USER" -- nohup "${server_command[@]}" >>"$SERVER_LOG_FILE" 2>&1 &
    else
        nohup "${server_command[@]}" >>"$SERVER_LOG_FILE" 2>&1 &
    fi
    server_pid=$!
    disown "$server_pid" 2>/dev/null || true

    sleep 2
    if ! kill -0 "$server_pid" 2>/dev/null; then
        echo "Gitea stopped immediately after starting." >&2
        if [[ -f "$SERVER_LOG_FILE" ]]; then
            echo "Recent server log ($SERVER_LOG_FILE):" >&2
            tail -n 50 "$SERVER_LOG_FILE" >&2
        fi
        return 1
    fi
    printf '%s\n' "$server_pid" >"$SERVER_PID_FILE"
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
    echo "Gitea did not become healthy within 30 seconds." >&2
    if [[ -f "$SERVER_LOG_FILE" ]]; then
        echo "Recent server log ($SERVER_LOG_FILE):" >&2
        tail -n 50 "$SERVER_LOG_FILE" >&2
    fi
    exit 1
fi

echo "Gitea is running."
echo "Web: http://127.0.0.1:__HTTP_PORT__/"
EOF_START_LAUNCHER

    sed -e "s|__RUN_USER__|$GITEA_USER|g" \
        -e "s|__GITEA_ROOT__|$GITEA_ROOT|g" \
        -e "s|__BIN_PATH__|$BIN_PATH|g" \
        -e "s|__CONFIG_PATH__|$CONFIG_PATH|g" \
        -e "s|__SERVER_PID_FILE__|$SERVER_PID_FILE|g" \
        -e "s|__SERVER_LOG_FILE__|$SERVER_LOG_FILE|g" \
        -e "s|__HEALTH_URL__|$HEALTH_URL|g" \
        -e "s|__HTTP_PORT__|$HTTP_PORT|g" \
        "$START_SCRIPT_TMP" >"$GITEA_ROOT/start-gitea.sh"
    chmod 0755 "$GITEA_ROOT/start-gitea.sh"
    chown "$GITEA_USER:$GITEA_USER" "$GITEA_ROOT/start-gitea.sh"

    cat >"$STOP_SCRIPT_TMP" <<'EOF_STOP_LAUNCHER'
#!/usr/bin/env bash

# ==============================================================================
# Stop Gitea.
# ==============================================================================
#
# PURPOSE
#   Stops the Gitea server (by PID file, then by process match) that runs as a
#   background process inside the deployment folder. No systemd unit is
#   involved. When run as root the process signals are dropped to RUN_USER with
#   runuser; otherwise they act as the current user. Idempotent; run
#   start-gitea.sh to bring it back up.
#
# USAGE
#   ./stop-gitea.sh          (as RUN_USER)
#   sudo ./stop-gitea.sh     (drops to RUN_USER)
#
# EXIT CODES
#   0   Gitea is stopped.

set -Eeuo pipefail

RUN_USER="__RUN_USER__"
BIN_PATH="__BIN_PATH__"
SERVER_PID_FILE="__SERVER_PID_FILE__"

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
    local binary_basename
    local process_pattern
    local attempt

    binary_basename="${binary_path##*/}"
    process_pattern="[${binary_basename:0:1}]${binary_basename:1}.*web"

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

stop_by_pid_file "$SERVER_PID_FILE"
stop_by_pattern "$BIN_PATH"

echo "Gitea is stopped."
EOF_STOP_LAUNCHER

    sed -e "s|__RUN_USER__|$GITEA_USER|g" \
        -e "s|__BIN_PATH__|$BIN_PATH|g" \
        -e "s|__SERVER_PID_FILE__|$SERVER_PID_FILE|g" \
        "$STOP_SCRIPT_TMP" >"$GITEA_ROOT/stop-gitea.sh"
    chmod 0755 "$GITEA_ROOT/stop-gitea.sh"
    chown "$GITEA_USER:$GITEA_USER" "$GITEA_ROOT/stop-gitea.sh"

    SETUP_SUCCEEDED=true

    echo
    echo "Gitea is running."
    echo "Web: http://$LAN_IP:$HTTP_PORT/"
    echo "SSH: $GITEA_USER@$LAN_IP:$SSH_PORT"
    echo "Version: $($BIN_PATH --version)"
    echo "Runtime user: $GITEA_USER"
    echo "PID file: $SERVER_PID_FILE"
    echo "Server log: $SERVER_LOG_FILE"
    echo "Stop: $GITEA_ROOT/stop-gitea.sh"
    echo "Start (also after reboot): $GITEA_ROOT/start-gitea.sh"

    if [[ "$NEW_INSTALL" == true ]]; then
        echo
        echo "Administrator credentials:"
        echo "Username: $ADMIN_USER"
        echo "Password: $ADMIN_PASSWORD"
        echo "Password change on first login: disabled"
    fi
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
