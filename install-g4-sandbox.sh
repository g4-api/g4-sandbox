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
    $SUDO apt-get install -y curl git tar gzip ca-certificates
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y curl git tar gzip ca-certificates
  elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y curl git tar gzip ca-certificates
  elif command -v zypper >/dev/null 2>&1; then
    $SUDO zypper --non-interactive install curl git tar gzip ca-certificates
  elif command -v apk >/dev/null 2>&1; then
    $SUDO apk add --no-cache curl git tar gzip ca-certificates
  else
    echo "Unsupported package manager. Please install curl, git, tar, gzip manually."
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
  arch="$(get_ps_arch)"

  log "Downloading portable PowerShell for linux-$arch"
  mkdir -p "$PS_DIR" "$TOOLS_DIR"

  curl -fsSL "https://aka.ms/powershell-release?tag=stable&os=linux&arch=$arch" -o "$PS_ARCHIVE"
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
  download_portable_powershell
  clone_repo
  publish_sandbox

  log "Done"
}

main "$@"