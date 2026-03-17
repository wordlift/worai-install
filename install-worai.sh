#!/usr/bin/env bash
set -euo pipefail

MIN_PYTHON="3.10"

log() {
  printf '[worai-install] %s\n' "$*" >&2
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

  # Prefer system package managers first (works better with externally-managed Python).
  case "$(uname -s)" in
    Darwin)
      if has_cmd brew; then
        log "Installing pipx with Homebrew..."
        if ! brew install pipx >&2; then
          log "Homebrew pipx install failed; falling back to pip user install..."
        fi
      fi
      ;;
    Linux)
      if has_cmd apt-get; then
        run_root apt-get update -y >&2
        run_root apt-get install -y pipx >&2 || true
      elif has_cmd dnf; then
        run_root dnf install -y pipx >&2 || true
      elif has_cmd yum; then
        run_root yum install -y pipx >&2 || true
      elif has_cmd pacman; then
        run_root pacman -Sy --noconfirm python-pipx >&2 || true
      elif has_cmd zypper; then
        run_root zypper --non-interactive install pipx >&2 || true
      elif has_cmd apk; then
        run_root apk add --no-cache pipx >&2 || true
      fi
      ;;
  esac

  if has_cmd pipx; then
    echo "pipx"
    return
  fi

  # Fallback: user install with pip. Some environments require --break-system-packages.
  log "Installing pipx with pip --user..."
  "$py" -m ensurepip --upgrade >/dev/null 2>&1 || true
  if ! "$py" -m pip install --user --upgrade pipx >&2; then
    log "Retrying pipx install with --break-system-packages..."
    "$py" -m pip install --user --break-system-packages --upgrade pipx \
      >&2 \
      || fail "Unable to install pipx. Install it manually (e.g. 'brew install pipx') and re-run."
  fi

  "$py" -m pipx ensurepath >&2 || true
  local user_base
  user_base="$("$py" -c 'import site; print(site.USER_BASE)' 2>/dev/null || true)"
  if [ -n "$user_base" ] && [ -x "$user_base/bin/pipx" ]; then
    echo "$user_base/bin/pipx"
    return
  fi
  if [ -x "/opt/homebrew/bin/pipx" ]; then
    echo "/opt/homebrew/bin/pipx"
    return
  fi
  if [ -x "/usr/local/bin/pipx" ]; then
    echo "/usr/local/bin/pipx"
    return
  fi
  if [ -x "$HOME/.local/bin/pipx" ]; then
    echo "$HOME/.local/bin/pipx"
    return
  fi
  fail "pipx install finished but pipx is not on PATH yet. Open a new shell and run again."
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
  "$pipx_bin" ensurepath >/dev/null 2>&1 || true

  local installed_version
  installed_version="$("$pipx_bin" runpip worai show worai 2>/dev/null | awk '/^Version:/{print $2; exit}' || true)"
  local user_base
  user_base="$("$py" -c 'import site; print(site.USER_BASE)' 2>/dev/null || true)"

  log "Done."
  log "worai ${installed_version:-unknown} successfully installed"
  if has_cmd worai; then
    log "Installed version: $(worai --version 2>/dev/null || echo 'unknown')"
    return
  fi

  local worai_candidate=""
  if [ -n "$user_base" ] && [ -x "$user_base/bin/worai" ]; then
    worai_candidate="$user_base/bin/worai"
  elif [ -x "$HOME/.local/bin/worai" ]; then
    worai_candidate="$HOME/.local/bin/worai"
  fi

  if [ -n "$worai_candidate" ]; then
    local worai_dir
    worai_dir="$(dirname "$worai_candidate")"
    log "worai is installed at: $worai_candidate"
    log "Current shell PATH does not include: $worai_dir"
    log "Run now: export PATH=\"$worai_dir:\$PATH\" && hash -r"
    log "Then run: worai --help"
  else
    log "If this is your first pipx install, open a new terminal before running: worai --help"
  fi
}

main "$@"
