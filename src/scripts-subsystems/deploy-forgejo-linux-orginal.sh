#!/usr/bin/env bash

# ==============================================================================
# Forgejo sandbox installer
# ==============================================================================
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
#   3. Creates a restricted forgejo service account and the /opt/forgejo folder
#      structure with explicit ownership and permissions.
#   4. On a fresh installation, generates application secrets, initializes the
#      SQLite database, disables public registration, and creates an initial
#      administrator with a temporary random password.
#   5. Installs and enables a hardened systemd service.
#   6. Starts Forgejo and waits for its health endpoint to respond successfully.
#
# SUPPORTED OPERATING SYSTEMS
#   Verified:
#     - Debian GNU/Linux 13 (Trixie), x86_64, with systemd
#
#   Expected to work:
#     - Other x86_64/AMD64 Linux distributions using systemd and standard GNU
#       user-management tools, provided all prerequisites listed below exist.
#
#   Not supported by this script:
#     - Windows or macOS
#     - ARM, ARM64/AArch64, or other non-AMD64 architectures
#     - Linux distributions without systemd
#     - Containers that do not run systemd as PID 1
#
# PREREQUISITES
#   - Root access through sudo
#   - Internet access to codeberg.org during installation or upgrade
#   - Bash, curl, Git, systemd, runuser, ip, sha256sum, and common GNU tools
#   - Ports 3000/TCP and 2222/TCP available unless overridden
#
# BASIC USAGE
#   Make the script executable and run it as root:
#
#     chmod +x install-forgejo.sh
#     sudo ./install-forgejo.sh
#
#   The command above automatically installs the latest stable release.
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
#     FORGEJO_USER           Linux service account      (default: forgejo)
#     FORGEJO_GROUP          Linux service group        (default: forgejo)
#     FORGEJO_IP             Advertised LAN IPv4        (default: auto-detected)*
#     FORGEJO_HTTP_PORT      Web interface port         (default: 3000)*
#     FORGEJO_SSH_PORT       Built-in Git SSH port      (default: 2222)*
#     FORGEJO_ADMIN_USER     Initial administrator      (default: forgejo-admin)*
#     FORGEJO_ADMIN_EMAIL    Initial administrator mail (default: local address)*
#     FORGEJO_ADMIN_PASSWORD Initial administrator password (default: random)*
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
#   On a fresh installation, the script prints the administrator username and
#   temporary password. It also writes them to:
#
#     /opt/forgejo/initial-admin.txt
#
#   Sign in, change the temporary password, and remove that file using the exact
#   cleanup command printed by the installer.
#
# RERUNS AND UPGRADES
#   The script is safe to rerun. When the SQLite database already exists, it
#   preserves the existing configuration, secrets, database, repositories, and
#   administrator accounts. It replaces the Forgejo binary, refreshes the
#   systemd unit, restarts the service, and checks its health.
#
# NETWORK AND SECURITY NOTES
#   - The web interface listens on all interfaces and is advertised by LAN IP.
#   - HTTP is unencrypted on port 3000. Keep it on a trusted LAN or place it
#     behind a TLS reverse proxy before exposure to an untrusted network.
#   - Forgejo's built-in SSH server listens on port 2222 by default.
#   - Public account registration is disabled on fresh installations.
#   - The Forgejo application data stays under FORGEJO_ROOT, but the installer
#     also creates a Linux service account and /etc/systemd/system/forgejo.service.
#   - Stop any manually started foreground Forgejo process before running this
#     installer; otherwise it exits without changing the running process.
#
# ==============================================================================

set -Eeuo pipefail

FORGEJO_VERSION="${FORGEJO_VERSION:-}"
FORGEJO_ROOT="${FORGEJO_ROOT:-/opt/forgejo}"
FORGEJO_USER="${FORGEJO_USER:-forgejo}"
FORGEJO_GROUP="${FORGEJO_GROUP:-forgejo}"
HTTP_PORT="${FORGEJO_HTTP_PORT:-3000}"
SSH_PORT="${FORGEJO_SSH_PORT:-2222}"

BIN_DIR="$FORGEJO_ROOT/bin"
BIN_PATH="$BIN_DIR/forgejo"
CONFIG_DIR="$FORGEJO_ROOT/custom/conf"
CONFIG_PATH="$CONFIG_DIR/app.ini"
DATA_DIR="$FORGEJO_ROOT/data"
DB_PATH="$DATA_DIR/forgejo.db"
LOG_DIR="$FORGEJO_ROOT/log"
SERVICE_PATH="/etc/systemd/system/forgejo.service"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this installer as root: sudo bash $0" >&2
    exit 1
fi

for command_name in curl sha256sum git systemctl runuser ip awk grep sed head; do
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
        echo "Set it explicitly, for example: sudo FORGEJO_VERSION=16.0.4 bash $0" >&2
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
        echo "Set it explicitly, for example: sudo FORGEJO_VERSION=16.0.4 bash $0" >&2
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

if [[ -n "${FORGEJO_IP:-}" ]]; then
    LAN_IP="$FORGEJO_IP"
else
    LAN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i == "src") {print $(i+1); exit}}')"
    if [[ -z "$LAN_IP" ]]; then
        LAN_IP="$(hostname -I | awk '{print $1}')"
    fi
fi

if [[ -z "$LAN_IP" ]]; then
    echo "Could not determine a LAN IPv4 address. Re-run with FORGEJO_IP=x.x.x.x." >&2
    exit 1
fi

systemctl stop forgejo.service 2>/dev/null || true

if id "$FORGEJO_USER" >/dev/null 2>&1 && pgrep -u "$FORGEJO_USER" -f "$BIN_PATH.*web" >/dev/null 2>&1; then
    echo "A manually started Forgejo process is still running." >&2
    echo "Stop it with Ctrl+C, then run this installer again." >&2
    exit 1
fi

if ! id "$FORGEJO_USER" >/dev/null 2>&1; then
    useradd --system --home-dir "$FORGEJO_ROOT" --shell /usr/sbin/nologin "$FORGEJO_USER"
fi

install -d -o "$FORGEJO_USER" -g "$FORGEJO_GROUP" -m 0750 \
    "$FORGEJO_ROOT" \
    "$BIN_DIR" \
    "$FORGEJO_ROOT/custom" \
    "$CONFIG_DIR" \
    "$DATA_DIR" \
    "$LOG_DIR"

DOWNLOAD_DIR="$(mktemp -d)"
CONFIG_TMP="$(mktemp)"
SERVICE_TMP="$(mktemp)"
cleanup() {
    rm -f "$CONFIG_TMP" "$SERVICE_TMP"
    rm -f "$DOWNLOAD_DIR/forgejo-${FORGEJO_VERSION}-linux-amd64"
    rm -f "$DOWNLOAD_DIR/forgejo-${FORGEJO_VERSION}-linux-amd64.sha256"
    rmdir "$DOWNLOAD_DIR" 2>/dev/null || true
}
trap cleanup EXIT

cd "$DOWNLOAD_DIR"
BASE_URL="https://codeberg.org/forgejo/forgejo/releases/download/v${FORGEJO_VERSION}"

curl --fail --location --silent --show-error --remote-name \
    "$BASE_URL/forgejo-${FORGEJO_VERSION}-linux-amd64"
curl --fail --location --silent --show-error --remote-name \
    "$BASE_URL/forgejo-${FORGEJO_VERSION}-linux-amd64.sha256"

sha256sum --check "forgejo-${FORGEJO_VERSION}-linux-amd64.sha256"

install -o "$FORGEJO_USER" -g "$FORGEJO_GROUP" -m 0750 \
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

    SECRET_KEY="$(runuser -u "$FORGEJO_USER" -- "$BIN_PATH" generate secret SECRET_KEY)"
    INTERNAL_TOKEN="$(runuser -u "$FORGEJO_USER" -- "$BIN_PATH" generate secret INTERNAL_TOKEN)"
    LFS_JWT_SECRET="$(runuser -u "$FORGEJO_USER" -- "$BIN_PATH" generate secret JWT_SECRET)"
    OAUTH2_JWT_SECRET="$(runuser -u "$FORGEJO_USER" -- "$BIN_PATH" generate secret JWT_SECRET)"

    cat >"$CONFIG_TMP" <<EOF
APP_NAME = Forgejo
RUN_USER = $FORGEJO_USER
RUN_MODE = prod
WORK_PATH = $FORGEJO_ROOT

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
BUILTIN_SSH_SERVER_USER = $FORGEJO_USER

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

    install -o "$FORGEJO_USER" -g "$FORGEJO_GROUP" -m 0640 "$CONFIG_TMP" "$CONFIG_PATH"
    run_forgejo migrate

    ADMIN_USER="${FORGEJO_ADMIN_USER:-forgejo-admin}"
    ADMIN_EMAIL="${FORGEJO_ADMIN_EMAIL:-forgejo-admin@localhost}"
    ADMIN_PASSWORD="${FORGEJO_ADMIN_PASSWORD:-$(od -An -N18 -tx1 /dev/urandom | tr -d ' \n')}"

    run_forgejo admin user create \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASSWORD" \
        --email "$ADMIN_EMAIL" \
        --admin \
        --must-change-password

    CREDENTIAL_FILE="$FORGEJO_ROOT/initial-admin.txt"
    cat >"$CREDENTIAL_FILE" <<EOF
Forgejo URL: http://$LAN_IP:$HTTP_PORT/
Username: $ADMIN_USER
Temporary password: $ADMIN_PASSWORD
EOF
    chown root:root "$CREDENTIAL_FILE"
    chmod 0600 "$CREDENTIAL_FILE"
elif [[ ! -f "$CONFIG_PATH" ]]; then
    echo "Database exists but configuration is missing: $CONFIG_PATH" >&2
    exit 1
fi

cat >"$SERVICE_TMP" <<EOF
[Unit]
Description=Forgejo self-hosted Git service
Documentation=https://forgejo.org/docs/latest/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$FORGEJO_USER
Group=$FORGEJO_GROUP
WorkingDirectory=$FORGEJO_ROOT
Environment=HOME=$FORGEJO_ROOT
Environment=USER=$FORGEJO_USER
ExecStart=$BIN_PATH --work-path $FORGEJO_ROOT --config $CONFIG_PATH web
Restart=always
RestartSec=3s
LimitNOFILE=65535
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=$FORGEJO_ROOT

[Install]
WantedBy=multi-user.target
EOF

install -o root -g root -m 0644 "$SERVICE_TMP" "$SERVICE_PATH"
systemctl daemon-reload
systemctl enable --now forgejo.service

HEALTH_URL="http://127.0.0.1:$HTTP_PORT/api/healthz"
for attempt in {1..30}; do
    if curl --fail --silent --show-error --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
        break
    fi
    if [[ "$attempt" -eq 30 ]]; then
        echo "Forgejo did not become healthy. Recent service log:" >&2
        journalctl -u forgejo.service -n 50 --no-pager >&2
        exit 1
    fi
    sleep 1
done

echo
echo "Forgejo is running."
echo "Web: http://$LAN_IP:$HTTP_PORT/"
echo "SSH: $FORGEJO_USER@$LAN_IP:$SSH_PORT"
echo "Version: $($BIN_PATH --version)"
echo "Service: systemctl status forgejo --no-pager"

if [[ "$NEW_INSTALL" == true ]]; then
    echo
    echo "Initial administrator credentials:"
    cat "$FORGEJO_ROOT/initial-admin.txt"
    echo
    echo "Sign in, change the temporary password, then remove the credential file:"
    echo "sudo rm $FORGEJO_ROOT/initial-admin.txt"
fi