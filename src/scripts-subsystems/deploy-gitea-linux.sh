#!/usr/bin/env bash

# ==============================================================================
# Gitea sandbox installer
# ==============================================================================
#
# PURPOSE
#   Installs or updates a native Gitea server with its application, SQLite
#   database, repositories, logs, configuration, and generated SSH host keys
#   contained under /opt/gitea by default. It does not use Docker or require an
#   external database.
#
# WHAT THE SCRIPT DOES
#   1. Resolves the latest stable Gitea version when GITEA_VERSION is unset.
#      Resolution uses the official go-gitea/gitea GitHub release API. The
#      script stops with an error if the version cannot be resolved or validated;
#      there is no hard-coded fallback version.
#   2. Downloads the official Linux AMD64 binary and SHA-256 checksum from
#      dl.gitea.com, then refuses installation unless verification succeeds.
#   3. Creates a restricted gitea service account and the /opt/gitea directory
#      structure with explicit ownership and permissions.
#   4. On a fresh installation, generates application secrets, initializes the
#      SQLite database, disables public registration, and creates this account:
#
#        Username: admin
#        Password: sk-12345
#
#      The administrator is NOT required to change the password after login.
#   5. Installs and enables a hardened systemd service.
#   6. Starts Gitea and waits for its health endpoint to respond successfully.
#
# SUPPORTED OPERATING SYSTEMS
#   Primary supported target:
#     - Debian GNU/Linux 13 (Trixie), x86_64, with systemd
#
#   Expected to work:
#     - Other x86_64/AMD64 Linux distributions using systemd and standard GNU
#       user-management tools, provided all prerequisites listed below exist.
#
#   Not supported by this script:
#     - Windows or macOS (Gitea itself supports them, but this Bash installer
#       creates a Linux account and systemd service)
#     - ARM, ARM64/AArch64, or other non-AMD64 architectures
#     - Linux distributions without systemd
#     - Containers that do not run systemd as PID 1
#
# PREREQUISITES
#   - Root access through sudo
#   - Internet access to api.github.com and dl.gitea.com during installation
#   - Bash, curl, Git, systemd, runuser, ip, sha256sum, and common GNU tools
#   - Ports 3001/TCP and 2223/TCP available unless overridden
#
# BASIC USAGE
#
#     chmod +x install-gitea.sh
#     sudo ./install-gitea.sh
#
#   The command above automatically installs the latest stable release.
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
#     GITEA_USER           Linux service account      (default: gitea)
#     GITEA_GROUP          Linux service group        (default: gitea)
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
#   database migration, refreshes the systemd unit, restarts the service, and
#   checks its health. Back up /opt/gitea before production upgrades.
#
# NETWORK AND SECURITY NOTES
#   - The web interface listens on all interfaces and is advertised by LAN IP.
#   - HTTP is unencrypted on port 3001. Keep it on a trusted LAN or place it
#     behind a TLS reverse proxy before exposure to an untrusted network.
#   - Gitea's built-in SSH server listens on port 2223 by default.
#   - Public account registration is disabled on fresh installations.
#   - Ports differ from the Forgejo installer defaults so both can coexist.
#   - Application data stays under GITEA_ROOT, but the installer also creates a
#     Linux service account and /etc/systemd/system/gitea.service.
#   - Stop any manually started foreground Gitea process before running this
#     installer; otherwise it exits without changing the running process.
#
# ==============================================================================

set -Eeuo pipefail

GITEA_VERSION="${GITEA_VERSION:-}"
GITEA_ROOT="${GITEA_ROOT:-/opt/gitea}"
GITEA_USER="${GITEA_USER:-gitea}"
GITEA_GROUP="${GITEA_GROUP:-gitea}"
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
SERVICE_PATH="/etc/systemd/system/gitea.service"

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

if [[ -z "$GITEA_VERSION" ]]; then
    RELEASE_API_URL="https://api.github.com/repos/go-gitea/gitea/releases/latest"
    echo "GITEA_VERSION was not provided; resolving the latest stable release..."

    if ! RELEASE_JSON="$(curl --fail --location --silent --show-error \
        -H 'Accept: application/vnd.github+json' \
        -H 'X-GitHub-Api-Version: 2022-11-28' \
        "$RELEASE_API_URL")"; then
        echo "ERROR: GITEA_VERSION was not provided and the latest stable version could not be resolved." >&2
        echo "Set it explicitly, for example: sudo GITEA_VERSION=1.27.3 bash $0" >&2
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
        echo "Set it explicitly, for example: sudo GITEA_VERSION=1.27.3 bash $0" >&2
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

systemctl stop gitea.service 2>/dev/null || true

if id "$GITEA_USER" >/dev/null 2>&1 && pgrep -u "$GITEA_USER" -f "$BIN_PATH.*web" >/dev/null 2>&1; then
    echo "A manually started Gitea process is still running." >&2
    echo "Stop it with Ctrl+C, then run this installer again." >&2
    exit 1
fi

if ! getent group "$GITEA_GROUP" >/dev/null 2>&1; then
    groupadd --system "$GITEA_GROUP"
fi

if ! id "$GITEA_USER" >/dev/null 2>&1; then
    useradd \
        --system \
        --gid "$GITEA_GROUP" \
        --home-dir "$GITEA_ROOT" \
        --shell /usr/sbin/nologin \
        "$GITEA_USER"
fi

install -d -o "$GITEA_USER" -g "$GITEA_GROUP" -m 0750 \
    "$GITEA_ROOT" \
    "$BIN_DIR" \
    "$GITEA_ROOT/custom" \
    "$CONFIG_DIR" \
    "$DATA_DIR" \
    "$LOG_DIR"

DOWNLOAD_DIR="$(mktemp -d)"
CONFIG_TMP="$(mktemp)"
SERVICE_TMP="$(mktemp)"
cleanup() {
    rm -f "$CONFIG_TMP" "$SERVICE_TMP"
    rm -f "$DOWNLOAD_DIR/gitea-${GITEA_VERSION}-linux-amd64"
    rm -f "$DOWNLOAD_DIR/gitea-${GITEA_VERSION}-linux-amd64.sha256"
    rmdir "$DOWNLOAD_DIR" 2>/dev/null || true
}
trap cleanup EXIT

cd "$DOWNLOAD_DIR"
BASE_URL="https://dl.gitea.com/gitea/${GITEA_VERSION}"

if ! curl --fail --location --silent --show-error --remote-name \
    "$BASE_URL/gitea-${GITEA_VERSION}-linux-amd64"; then
    echo "ERROR: Could not download Gitea $GITEA_VERSION for Linux AMD64." >&2
    exit 1
fi

if ! curl --fail --location --silent --show-error --remote-name \
    "$BASE_URL/gitea-${GITEA_VERSION}-linux-amd64.sha256"; then
    echo "ERROR: Could not download the SHA-256 checksum for Gitea $GITEA_VERSION." >&2
    exit 1
fi

if ! sha256sum --check "gitea-${GITEA_VERSION}-linux-amd64.sha256"; then
    echo "ERROR: Gitea binary checksum verification failed. Nothing was installed." >&2
    exit 1
fi

install -o "$GITEA_USER" -g "$GITEA_GROUP" -m 0750 \
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

    SECRET_KEY="$(runuser -u "$GITEA_USER" -- "$BIN_PATH" generate secret SECRET_KEY)"
    INTERNAL_TOKEN="$(runuser -u "$GITEA_USER" -- "$BIN_PATH" generate secret INTERNAL_TOKEN)"
    LFS_JWT_SECRET="$(runuser -u "$GITEA_USER" -- "$BIN_PATH" generate secret JWT_SECRET)"
    OAUTH2_JWT_SECRET="$(runuser -u "$GITEA_USER" -- "$BIN_PATH" generate secret JWT_SECRET)"

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

    install -o "$GITEA_USER" -g "$GITEA_GROUP" -m 0640 "$CONFIG_TMP" "$CONFIG_PATH"
elif [[ ! -f "$CONFIG_PATH" ]]; then
    echo "Database exists but configuration is missing: $CONFIG_PATH" >&2
    exit 1
fi

# Gitea documents this command as idempotent, so it is used for both fresh
# installations and upgrades before the service is started.
run_gitea migrate

if [[ "$NEW_INSTALL" == true ]]; then
    run_gitea admin user create \
        --username "$ADMIN_USER" \
        --password "$ADMIN_PASSWORD" \
        --email "$ADMIN_EMAIL" \
        --admin \
        --must-change-password=false
fi

cat >"$SERVICE_TMP" <<EOF
[Unit]
Description=Gitea self-hosted Git service
Documentation=https://docs.gitea.com/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$GITEA_USER
Group=$GITEA_GROUP
WorkingDirectory=$GITEA_ROOT
Environment=HOME=$GITEA_ROOT
Environment=USER=$GITEA_USER
Environment=GITEA_WORK_DIR=$GITEA_ROOT
Environment=GITEA_CUSTOM=$GITEA_ROOT/custom
ExecStart=$BIN_PATH --work-path $GITEA_ROOT --custom-path $GITEA_ROOT/custom --config $CONFIG_PATH web
Restart=always
RestartSec=3s
LimitNOFILE=65535
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict
ReadWritePaths=$GITEA_ROOT

[Install]
WantedBy=multi-user.target
EOF

install -o root -g root -m 0644 "$SERVICE_TMP" "$SERVICE_PATH"
systemctl daemon-reload
systemctl enable --now gitea.service

HEALTH_URL="http://127.0.0.1:$HTTP_PORT/api/healthz"
for attempt in {1..30}; do
    if curl --fail --silent --show-error --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
        break
    fi
    if [[ "$attempt" -eq 30 ]]; then
        echo "Gitea did not become healthy. Recent service log:" >&2
        journalctl -u gitea.service -n 50 --no-pager >&2
        exit 1
    fi
    sleep 1
done

echo
echo "Gitea is running."
echo "Web: http://$LAN_IP:$HTTP_PORT/"
echo "SSH: $GITEA_USER@$LAN_IP:$SSH_PORT"
echo "Version: $($BIN_PATH --version)"
echo "Service: systemctl status gitea --no-pager"

if [[ "$NEW_INSTALL" == true ]]; then
    echo
    echo "Administrator credentials:"
    echo "Username: $ADMIN_USER"
    echo "Password: $ADMIN_PASSWORD"
    echo "Password change on first login: disabled"
fi