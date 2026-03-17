#!/usr/bin/env bash
set -euo pipefail

MIN_PYTHON="3.10"

log() {
  printf '[worai-install] %s\n' "$*"
}

fail() {
  printf '[worai-install] ERROR: %s\n' "$*" >&2
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

run_root() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    "$@"
  elif has_cmd sudo; then
    sudo "$@"
  else
    fail "Need root privileges (or sudo) to install Python packages."
  fi
}

python_cmd() {
  if has_cmd python3; then
    echo "python3"
    return
  fi
  if has_cmd python; then
    echo "python"
    return
  fi
  return 1
}

python_ok() {
  local py="$1"
  "$py" -c "import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)"
}

install_python_macos() {
  if ! has_cmd brew; then
    fail "Homebrew not found. Install Python 3.10+ from https://www.python.org/downloads/macos/ and re-run."
  fi
  log "Installing Python with Homebrew..."
  brew install python@3.12
}

install_python_linux() {
  log "Installing Python with available system package manager..."
  if has_cmd apt-get; then
    run_root apt-get update -y
    run_root apt-get install -y python3 python3-pip python3-venv
    return
  fi
  if has_cmd dnf; then
    run_root dnf install -y python3 python3-pip
    return
  fi
  if has_cmd yum; then
    run_root yum install -y python3 python3-pip
    return
  fi
  if has_cmd pacman; then
    run_root pacman -Sy --noconfirm python python-pip
    return
  fi
  if has_cmd zypper; then
    run_root zypper --non-interactive install python3 python3-pip
    return
  fi
  if has_cmd apk; then
    run_root apk add --no-cache python3 py3-pip
    return
  fi
  fail "No supported package manager found. Install Python 3.10+ manually and re-run."
}

ensure_python() {
  local py
  if py="$(python_cmd 2>/dev/null)" && python_ok "$py"; then
    log "Using $py ($("$py" --version 2>&1))."
    echo "$py"
    return
  fi

  case "$(uname -s)" in
    Darwin) install_python_macos ;;
    Linux) install_python_linux ;;
    *)
      fail "Unsupported OS for this installer. Install Python 3.10+ and pipx manually."
      ;;
  esac

  py="$(python_cmd 2>/dev/null || true)"
  [ -n "$py" ] || fail "Python command not found after installation."
  python_ok "$py" || fail "Python >= $MIN_PYTHON is required."
  log "Using $py ($("$py" --version 2>&1))."
  echo "$py"
}

ensure_pipx() {
  local py="$1"
  if has_cmd pipx; then
    echo "pipx"
    return
  fi
  log "Installing pipx..."
  "$py" -m pip install --user --upgrade pip pipx
  "$py" -m pipx ensurepath || true

  if has_cmd pipx; then
    echo "pipx"
    return
  fi
  if [ -x "$HOME/.local/bin/pipx" ]; then
    echo "$HOME/.local/bin/pipx"
    return
  fi
  fail "pipx was installed but is not on PATH. Open a new shell and run again."
}

install_or_upgrade_worai() {
  local pipx_bin="$1"
  if "$pipx_bin" runpip worai --version >/dev/null 2>&1; then
    log "Upgrading worai..."
    "$pipx_bin" upgrade worai
  else
    log "Installing worai..."
    "$pipx_bin" install worai
  fi
}

main() {
  log "Starting worai installer..."
  local py
  py="$(ensure_python)"

  local pipx_bin
  pipx_bin="$(ensure_pipx "$py")"

  install_or_upgrade_worai "$pipx_bin"

  log "Done."
  log "If this is your first pipx install, open a new terminal before running: worai --help"
  if has_cmd worai; then
    log "Installed version: $(worai --version 2>/dev/null || echo 'unknown')"
  fi
}

main "$@"
