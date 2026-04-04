#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/g4-api/g4-sandbox.git"
WORK_DIR="/tmp/g4-sandbox"
OUTPUT_DIR="/opt/g4-sandbox"

log() {
  printf '\n[+] %s\n' "$1"
}

require_sudo() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    SUDO="sudo"
  else
    SUDO=""
  fi
}

install_base_tools() {
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update
    $SUDO apt-get install -y curl git ca-certificates gnupg
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y curl git ca-certificates gnupg
  elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y curl git ca-certificates gnupg
  elif command -v zypper >/dev/null 2>&1; then
    $SUDO zypper --non-interactive install curl git ca-certificates gpg2
  else
    echo "Unsupported package manager. Install curl/git manually first."
    exit 1
  fi
}

install_powershell() {
  if command -v pwsh >/dev/null 2>&1; then
    log "PowerShell already installed"
    return
  fi

  . /etc/os-release

  case "${ID:-}" in
    ubuntu)
      log "Installing PowerShell on Ubuntu"
      curl -fsSL -o /tmp/packages-microsoft-prod.deb "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb"
      $SUDO dpkg -i /tmp/packages-microsoft-prod.deb
      rm -f /tmp/packages-microsoft-prod.deb
      $SUDO apt-get update
      $SUDO apt-get install -y powershell
      ;;
    debian)
      log "Installing PowerShell on Debian"
      curl -fsSL -o /tmp/packages-microsoft-prod.deb "https://packages.microsoft.com/config/debian/${VERSION_ID}/packages-microsoft-prod.deb"
      $SUDO dpkg -i /tmp/packages-microsoft-prod.deb
      rm -f /tmp/packages-microsoft-prod.deb
      $SUDO apt-get update
      $SUDO apt-get install -y powershell
      ;;
    rhel|rocky|almalinux|ol|fedora)
      log "Installing PowerShell on RPM-based distro"
      MAJOR_VERSION="${VERSION_ID%%.*}"
      curl -fsSL -o /tmp/packages-microsoft-prod.rpm "https://packages.microsoft.com/config/rhel/${MAJOR_VERSION}/packages-microsoft-prod.rpm"
      $SUDO rpm -i /tmp/packages-microsoft-prod.rpm
      rm -f /tmp/packages-microsoft-prod.rpm

      if command -v dnf >/dev/null 2>&1; then
        $SUDO dnf install -y powershell
      else
        $SUDO yum install -y powershell
      fi
      ;;
    opensuse*|sles)
      log "Installing PowerShell on SUSE"
      $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
      curl -fsSL https://packages.microsoft.com/config/rhel/8/prod.repo | $SUDO tee /etc/zypp/repos.d/microsoft.repo >/dev/null
      $SUDO zypper refresh
      $SUDO zypper --non-interactive install powershell
      ;;
    *)
      echo "Unsupported distro for automatic PowerShell install: ${ID:-unknown}"
      echo "Install pwsh manually, then rerun."
      exit 1
      ;;
  esac
}

clone_repo() {
  log "Cloning g4-sandbox"
  rm -rf "$WORK_DIR"
  git clone --depth 1 "$REPO_URL" "$WORK_DIR"
}

publish_sandbox() {
  log "Publishing G4 sandbox to $OUTPUT_DIR"
  $SUDO mkdir -p "$OUTPUT_DIR"

  pwsh -NoLogo -NoProfile -File "$WORK_DIR/src/Publish-G4Sandbox.ps1" \
    -OperatingSystem "Linux" \
    -OutputDirectory "$OUTPUT_DIR"
}

main() {
  require_sudo
  install_base_tools
  install_powershell
  clone_repo
  publish_sandbox
  log "Done"
}

main "$@"