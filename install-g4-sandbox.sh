#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/g4-api/g4-sandbox.git"
ROOT_WORK_DIR="/tmp/g4-sandbox-bootstrap"
REPO_DIR="$ROOT_WORK_DIR/repo"
SRC_DIR="$REPO_DIR/src"
TOOLS_DIR="$ROOT_WORK_DIR/tools"
PS_DIR="$TOOLS_DIR/powershell"
PS_ARCHIVE="$TOOLS_DIR/powershell.tar.gz"
OUTPUT_DIR="/opt/g4-sandbox"

SUDO=""

log() {
  printf '\n[+] %s\n' "$1"
}

cleanup() {
  rm -rf "$ROOT_WORK_DIR"
}

require_sudo() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    SUDO="sudo"
  fi
}

install_base_tools() {
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update
    $SUDO apt-get install -y curl git tar gzip ca-certificates file
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y curl git tar gzip ca-certificates file
  elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y curl git tar gzip ca-certificates file
  elif command -v zypper >/dev/null 2>&1; then
    $SUDO zypper --non-interactive install curl git tar gzip ca-certificates file
  elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache curl git tar gzip ca-certificates file
  else
    echo "Unsupported package manager. Please install curl, git, tar, gzip, and file manually."
    exit 1
  fi
}

install_icu() {
  log "Installing ICU runtime"

  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update

    if ! $SUDO apt-get install -y libicu-dev; then
      $SUDO apt-get install -y libicu72 || \
      $SUDO apt-get install -y libicu71 || \
      $SUDO apt-get install -y libicu70 || \
      $SUDO apt-get install -y libicu67 || \
      $SUDO apt-get install -y libicu66 || \
      $SUDO apt-get install -y libicu63
    fi
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y libicu
  elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y libicu
  elif command -v zypper >/dev/null 2>&1; then
    $SUDO zypper --non-interactive install libicu
  elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache icu-libs
  else
    echo "Unsupported package manager. Please install ICU manually."
    exit 1
  fi
}

get_ps_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x64" ;;
    aarch64|arm64) echo "arm64" ;;
    *)
      echo "Unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac
}

download_portable_powershell() {
  local arch
  local ps_version
  local ps_file
  local ps_url

  ps_version="7.6.0"
  arch="$(get_ps_arch)"

  case "$arch" in
    x64)
      ps_file="powershell-${ps_version}-linux-x64.tar.gz"
      ;;
    arm64)
      ps_file="powershell-${ps_version}-linux-arm64.tar.gz"
      ;;
    *)
      echo "Unsupported architecture: $arch"
      exit 1
      ;;
  esac

  ps_url="https://github.com/PowerShell/PowerShell/releases/download/v${ps_version}/${ps_file}"

  log "Downloading portable PowerShell ${ps_version} for linux-${arch}"
  mkdir -p "$PS_DIR" "$TOOLS_DIR"

  curl --fail --location --silent --show-error \
    --user-agent "Mozilla/5.0" \
    --output "$PS_ARCHIVE" \
    "$ps_url"

  if ! file "$PS_ARCHIVE" | grep -qi 'gzip compressed'; then
    echo "Downloaded file is not a gzip archive."
    echo "Detected type:"
    file "$PS_ARCHIVE" || true
    echo
    echo "First 20 lines of response:"
    head -20 "$PS_ARCHIVE" || true
    exit 1
  fi

  tar -xzf "$PS_ARCHIVE" -C "$PS_DIR"
  chmod +x "$PS_DIR/pwsh"
}

clone_repo() {
  log "Cloning g4-sandbox"
  mkdir -p "$ROOT_WORK_DIR"
  git clone --depth 1 "$REPO_URL" "$REPO_DIR"
}

publish_sandbox() {
  log "Publishing G4 sandbox to $OUTPUT_DIR"
  $SUDO mkdir -p "$OUTPUT_DIR"

  cd "$SRC_DIR"

  "$PS_DIR/pwsh" -NoLogo -NoProfile -File "./Publish-G4Sandbox.ps1" \
    -OperatingSystem "Linux" \
    -OutputDirectory "$OUTPUT_DIR"
}

main() {
  trap cleanup EXIT

  require_sudo
  install_base_tools
  install_icu
  download_portable_powershell
  clone_repo
  publish_sandbox

  log "Done"
}

main "$@"