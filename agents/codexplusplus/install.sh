#!/usr/bin/env bash
# Codex++ addon bootstrap for macOS/Linux.

set -euo pipefail
IFS=$'\n\t'

CODEX_PLUS_PLUS_REPO="${CODEX_PLUS_PLUS_REPO:-BigPizzaV3/CodexPlusPlus}"
CODEX_PLUS_PLUS_REF="${CODEX_PLUS_PLUS_REF:-v1.0.7}"
CODEX_PLUS_PLUS_INSTALL_ROOT="${CODEX_PLUS_PLUS_INSTALL_ROOT:-}"
CODEX_PLUS_PLUS_PIP_ARGS="${CODEX_PLUS_PLUS_PIP_ARGS:-}"
CODEX_PLUS_PLUS_PROVIDER_SYNC="${CODEX_PLUS_PLUS_PROVIDER_SYNC:-0}"
DRY_RUN=0
SKIP_SETUP=0
LAUNCH=0
FORCE_SETUP=0
PYTHON_BIN=""
OS_ID=""
ARCH_NAME=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; BOLD='\033[1m'; NC='\033[0m'

banner() {
  printf "\n%b+--------------------------------------------------+%b\n" "$CYAN" "$NC"
  printf "%b|%b %bCodex++ Addon Bootstrap%b                         %b|%b\n" "$CYAN" "$NC" "$BOLD" "$NC" "$CYAN" "$NC"
  printf "%b|%b external Codex App enhancer                    %b|%b\n" "$CYAN" "$NC" "$CYAN" "$NC"
  printf "%b+--------------------------------------------------+%b\n\n" "$CYAN" "$NC"
}

step() { printf "\n%b[%s]%b %b%s%b\n" "$MAGENTA" "$1" "$NC" "$BOLD" "$2" "$NC"; }
ok() { printf "%b[OK]%b %s\n" "$GREEN" "$NC" "$1"; }
info() { printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$1"; }
warn() { printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"; }
fail() { printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2; exit 1; }

usage() {
  cat <<USAGE
Codex++ Addon Bootstrap

Usage:
  AGENT=codexplusplus bash -c "\$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"

Options:
  --ref REF              Upstream Codex++ git ref/tag (default: ${CODEX_PLUS_PLUS_REF})
  --repo OWNER/REPO      Upstream Codex++ repo (default: ${CODEX_PLUS_PLUS_REPO})
  --install-root DIR     Pass install root to Codex++ setup
  --skip-setup           Install Python package only; do not create app/shortcut
  --provider-sync        Enable Codex++ provider metadata sync
  --no-provider-sync     Disable Codex++ provider metadata sync
  --force-setup          Try setup even on Linux/unknown platforms
  --launch               Launch Codex++ after install/setup
  --dry-run              Print intended commands without running them
  -h, --help             Show this help

Environment:
  CODEX_PLUS_PLUS_REF           Upstream git ref/tag (default: v1.0.7)
  CODEX_PLUS_PLUS_REPO          Upstream repo (default: BigPizzaV3/CodexPlusPlus)
  CODEX_PLUS_PLUS_INSTALL_ROOT  Optional setup install root
  CODEX_PLUS_PLUS_PIP_ARGS      Extra pip args, for example: --break-system-packages
  CODEX_PLUS_PLUS_PROVIDER_SYNC Set 1 to enable provider metadata sync
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ref) CODEX_PLUS_PLUS_REF="${2:?missing ref}"; shift 2 ;;
    --repo) CODEX_PLUS_PLUS_REPO="${2:?missing repo}"; shift 2 ;;
    --install-root) CODEX_PLUS_PLUS_INSTALL_ROOT="${2:?missing install root}"; shift 2 ;;
    --skip-setup) SKIP_SETUP=1; shift ;;
    --provider-sync) CODEX_PLUS_PLUS_PROVIDER_SYNC=1; shift ;;
    --no-provider-sync) CODEX_PLUS_PLUS_PROVIDER_SYNC=0; shift ;;
    --force-setup) FORCE_SETUP=1; shift ;;
    --launch) LAUNCH=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

command_exists() { command -v "$1" >/dev/null 2>&1; }

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN:"
    printf " %q" "$@"
    printf "\n"
  else
    "$@"
  fi
}

detect_platform() {
  local kernel
  kernel="$(uname -s 2>/dev/null || printf unknown)"
  ARCH_NAME="$(uname -m 2>/dev/null || printf unknown)"
  case "$kernel" in
    Darwin) OS_ID="macos" ;;
    Linux) OS_ID="linux" ;;
    *) OS_ID="unknown" ;;
  esac
}

find_python() {
  local candidate
  for candidate in python3.13 python3.12 python3.11 python3 python; do
    command_exists "$candidate" || continue
    if "$candidate" - <<'PY' >/dev/null 2>&1
import sys
raise SystemExit(0 if sys.version_info >= (3, 11) else 1)
PY
    then
      PYTHON_BIN="$candidate"
      return 0
    fi
  done
  return 1
}

ensure_pip() {
  if "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
    return 0
  fi
  warn "pip is missing for $PYTHON_BIN; trying ensurepip"
  run "$PYTHON_BIN" -m ensurepip --upgrade
  "$PYTHON_BIN" -m pip --version >/dev/null 2>&1 || fail "pip is required for Codex++ install"
}

install_package() {
  local package_url
  package_url="git+https://github.com/${CODEX_PLUS_PLUS_REPO}.git@${CODEX_PLUS_PLUS_REF}"
  command_exists git || fail "git is required to install Codex++ from GitHub"
  ensure_pip
  if [[ -n "$CODEX_PLUS_PLUS_PIP_ARGS" ]]; then
    # shellcheck disable=SC2086
    run "$PYTHON_BIN" -m pip install --user --upgrade $CODEX_PLUS_PLUS_PIP_ARGS "$package_url"
  else
    run "$PYTHON_BIN" -m pip install --user --upgrade "$package_url"
  fi
}

setup_launcher() {
  if [[ "$SKIP_SETUP" == "1" ]]; then
    info "Skipping Codex++ setup"
    return 0
  fi
  if [[ "$OS_ID" == "linux" && "$FORCE_SETUP" != "1" ]]; then
    warn "Codex++ upstream setup currently targets macOS and Windows Codex App paths; Linux setup skipped. Use --force-setup if you know your app path is compatible."
    return 0
  fi
  if [[ "$OS_ID" == "unknown" && "$FORCE_SETUP" != "1" ]]; then
    warn "Unknown OS; setup skipped. Use --force-setup to try anyway."
    return 0
  fi

  if [[ -n "$CODEX_PLUS_PLUS_INSTALL_ROOT" ]]; then
    run "$PYTHON_BIN" -m codex_session_delete setup --install-root "$CODEX_PLUS_PLUS_INSTALL_ROOT"
  else
    run "$PYTHON_BIN" -m codex_session_delete setup
  fi
}

configure_features() {
  local settings_dir settings_file enabled
  settings_dir="$HOME/.codex-session-delete"
  settings_file="$settings_dir/settings.json"
  case "$CODEX_PLUS_PLUS_PROVIDER_SYNC" in
    1|true|yes|on) enabled=true ;;
    *) enabled=false ;;
  esac

  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN: write %s with providerSyncEnabled=%s\n" "$settings_file" "$enabled"
    return 0
  fi

  mkdir -p "$settings_dir"
  cat > "$settings_file" <<JSON
{
  "providerSyncEnabled": $enabled
}
JSON
}

launch_codex_plus_plus() {
  [[ "$LAUNCH" == "1" ]] || return 0
  run "$PYTHON_BIN" -m codex_session_delete launch
}

main() {
  banner
  detect_platform
  step "1/6" "Inspect Codex++ settings"
  info "OS: ${OS_ID}/${ARCH_NAME}"
  info "Upstream: ${CODEX_PLUS_PLUS_REPO}@${CODEX_PLUS_PLUS_REF}"
  [[ -n "$CODEX_PLUS_PLUS_INSTALL_ROOT" ]] && info "Install root: $CODEX_PLUS_PLUS_INSTALL_ROOT"
  info "Provider sync: $CODEX_PLUS_PLUS_PROVIDER_SYNC"

  step "2/6" "Find Python 3.11+"
  find_python || fail "Python 3.11+ is required. Install Python 3.11 or newer, then rerun."
  ok "Python: $($PYTHON_BIN --version 2>&1) ($PYTHON_BIN)"

  step "3/6" "Install Codex++ from GitHub"
  install_package
  ok "Codex++ Python package installed"

  step "4/6" "Create Codex++ launcher"
  setup_launcher
  ok "Codex++ setup step completed"

  step "5/6" "Configure Codex++ features"
  configure_features
  ok "Codex++ feature settings ready"

  step "6/6" "Finish"
  launch_codex_plus_plus
  ok "Codex++ addon ready"
  info "Launch later with: $PYTHON_BIN -m codex_session_delete launch"
  info "Update later with: $PYTHON_BIN -m codex_session_delete update"
}

main
