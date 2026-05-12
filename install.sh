#!/usr/bin/env bash
# Codex Bootstrap
# Safe-ish GitHub curl entrypoint for installing Codex and applying personal config.

set -euo pipefail
IFS=$'\n\t'

BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-HY-LiYihan/codex-bootstrap}"
BOOTSTRAP_REF="${BOOTSTRAP_REF:-main}"
BOOTSTRAP_PROFILE="${CODEX_PROFILE:-default}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG_FILE="$CODEX_HOME/config.toml"
PRIVATE_ENV_FILE="${CODEX_PRIVATE_ENV_FILE:-$CODEX_HOME/private.env}"
API_BASE_URL="${CODEX_API_URL:-${OPENAI_BASE_URL:-https://api.openai.com/v1}}"
API_KEY="${CODEX_TOKEN:-${OPENAI_API_KEY:-}}"
PROVIDER_ID="${CODEX_PROVIDER_ID:-custom}"
PROVIDER_ENV_KEY="${CODEX_PROVIDER_ENV_KEY:-CODEX_API_KEY}"
MODEL="${CODEX_MODEL:-gpt-5.5}"
REASONING_EFFORT="${CODEX_REASONING_EFFORT:-high}"
PROJECT_DIR="${CODEX_PROJECT_DIR:-$PWD}"
NPM_REGISTRY="${CODEX_NPM_REGISTRY:-https://registry.npmmirror.com}"
LOCAL_SOURCE=""
DRY_RUN=0
YES=0
FORCE=0
SKIP_CODEX_INSTALL=0
SKIP_SHELL_RC=0
INSTALL_BUN=1
OS_ID=""
OS_NAME=""
ARCH_NAME=""
SHELL_NAME=""
SHELL_RC=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
  printf "\n"
  printf "%b+--------------------------------------------------+%b\n" "$CYAN" "$NC"
  printf "%b|%b %bCodex Bootstrap%b                                 %b|%b\n" "$CYAN" "$NC" "$BOLD" "$NC" "$CYAN" "$NC"
  printf "%b|%b custom provider + colorful one-click setup     %b|%b\n" "$CYAN" "$NC" "$CYAN" "$NC"
  printf "%b+--------------------------------------------------+%b\n\n" "$CYAN" "$NC"
}

log_step() { printf "\n%b[%s]%b %b%s%b\n" "$MAGENTA" "$1" "$NC" "$BOLD" "$2" "$NC"; }
log_ok() { printf "%b[OK]%b %s\n" "$GREEN" "$NC" "$1"; }
log_warn() { printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"; }
log_info() { printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$1"; }
fail() { printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2; exit 1; }

usage() {
  cat <<USAGE
Codex Bootstrap

Usage:
  CODEX_TOKEN="..." CODEX_API_URL="https://gateway.example.com/v1" bash -c "\$(curl -fsSL <install-url>)"

Options:
  --profile NAME       Profile to apply from profiles/NAME.env (default: ${BOOTSTRAP_PROFILE})
  --project DIR        Project directory for AGENTS.md generation (default: current directory)
  --repo OWNER/REPO    GitHub repo to download templates from (default: ${BOOTSTRAP_REPO})
  --ref REF            Git ref/tag/branch to download templates from (default: ${BOOTSTRAP_REF})
  --local DIR          Use a local checkout instead of downloading from GitHub
  --dry-run            Show intended changes without writing files or installing packages
  --yes                Do not prompt before high-impact actions
  --force              Allow reinstalling Codex and overwriting managed files
  --skip-codex-install Do not install or update @openai/codex
  --skip-shell-rc      Do not add source line to shell startup file
  --no-bun             Do not install Bun automatically; use npm if available
  -h, --help           Show this help

Environment:
  CODEX_TOKEN or OPENAI_API_KEY       API key written to the provider env key
  CODEX_API_URL or OPENAI_BASE_URL    API base URL written to [model_providers.custom]
  CODEX_PROVIDER_ID                   Provider id (default: ${PROVIDER_ID})
  CODEX_PROVIDER_ENV_KEY              Provider env key (default: ${PROVIDER_ENV_KEY})
  CODEX_MODEL                         Default model (default: ${MODEL})
  CODEX_REASONING_EFFORT              Reasoning effort (default: ${REASONING_EFFORT})
  CODEX_NPM_REGISTRY                  npm fallback registry (default: ${NPM_REGISTRY})
  CODEX_PROFILE                       Profile name (default: default)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) BOOTSTRAP_PROFILE="${2:?missing profile}"; shift 2 ;;
    --project) PROJECT_DIR="${2:?missing project dir}"; shift 2 ;;
    --repo) BOOTSTRAP_REPO="${2:?missing repo}"; shift 2 ;;
    --ref) BOOTSTRAP_REF="${2:?missing ref}"; shift 2 ;;
    --local) LOCAL_SOURCE="${2:?missing local dir}"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --yes) YES=1; shift ;;
    --force) FORCE=1; shift ;;
    --skip-codex-install) SKIP_CODEX_INSTALL=1; shift ;;
    --skip-shell-rc) SKIP_SHELL_RC=1; shift ;;
    --no-bun) INSTALL_BUN=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done

command_exists() { command -v "$1" >/dev/null 2>&1; }
validate_env_key() {
  [[ "$PROVIDER_ENV_KEY" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || fail "Invalid CODEX_PROVIDER_ENV_KEY: $PROVIDER_ENV_KEY"
}

detect_platform() {
  local kernel
  kernel="$(uname -s 2>/dev/null || printf unknown)"
  ARCH_NAME="$(uname -m 2>/dev/null || printf unknown)"

  case "$kernel" in
    Darwin)
      OS_ID="macos"
      OS_NAME="macOS"
      ;;
    Linux)
      OS_ID="linux"
      OS_NAME="Linux"
      if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_NAME="${PRETTY_NAME:-${NAME:-Linux}}"
      fi
      ;;
    *)
      fail "Unsupported OS for install.sh: $kernel. Use install.ps1 on Windows."
      ;;
  esac

  if [[ "${SHELL:-}" == *zsh* ]]; then
    SHELL_NAME="zsh"
    SHELL_RC="$HOME/.zshrc"
  elif [[ "${SHELL:-}" == *bash* ]]; then
    SHELL_NAME="bash"
    if [[ "$OS_ID" == "macos" ]]; then
      SHELL_RC="$HOME/.bash_profile"
    else
      SHELL_RC="$HOME/.bashrc"
    fi
  else
    SHELL_NAME="${SHELL##*/}"
    SHELL_RC="$HOME/.profile"
  fi
}

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN:"
    printf " %q" "$@"
    printf "\n"
  else
    "$@"
  fi
}

toml_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf "%s" "$value"
}

confirm() {
  local message="$1"
  if [[ "$YES" == "1" || "$DRY_RUN" == "1" ]]; then
    return 0
  fi
  printf "%s [y/N] " "$message"
  read -r reply
  [[ "$reply" == "y" || "$reply" == "Y" || "$reply" == "yes" || "$reply" == "YES" ]]
}

detect_shell_rc() {
  if [[ -n "$SHELL_RC" ]]; then
    printf "%s" "$SHELL_RC"
  elif [[ "${SHELL:-}" == *zsh* ]]; then
    printf "%s/.zshrc" "$HOME"
  else
    printf "%s/.bashrc" "$HOME"
  fi
}

mask_secret() {
  local value="$1"
  if [[ ${#value} -le 8 ]]; then
    printf "<hidden>"
  else
    printf "%s...%s" "${value:0:4}" "${value: -4}"
  fi
}

load_profile() {
  local source_dir="$1"
  local profile_file="$source_dir/profiles/$BOOTSTRAP_PROFILE.env"
  if [[ -f "$profile_file" ]]; then
    # shellcheck disable=SC1090
    source "$profile_file"
    MODEL="${CODEX_MODEL:-$MODEL}"
    REASONING_EFFORT="${CODEX_REASONING_EFFORT:-$REASONING_EFFORT}"
    log_ok "Loaded profile: $BOOTSTRAP_PROFILE"
  else
    log_warn "Profile not found: $BOOTSTRAP_PROFILE; using built-in defaults"
  fi
}

download_source() {
  if [[ -n "$LOCAL_SOURCE" ]]; then
    [[ -d "$LOCAL_SOURCE" ]] || fail "Local source not found: $LOCAL_SOURCE"
    printf "%s" "$LOCAL_SOURCE"
    return 0
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local url="https://github.com/${BOOTSTRAP_REPO}/archive/${BOOTSTRAP_REF}.tar.gz"
  log_info "Downloading bootstrap assets from $BOOTSTRAP_REPO@$BOOTSTRAP_REF" >&2
  if command_exists curl; then
    curl -fsSL "$url" | tar -xz -C "$tmp_dir" --strip-components=1
  elif command_exists wget; then
    wget -qO- "$url" | tar -xz -C "$tmp_dir" --strip-components=1
  else
    fail "curl or wget is required"
  fi
  printf "%s" "$tmp_dir"
}

ensure_bun() {
  [[ "$INSTALL_BUN" == "1" ]] || return 1
  if command_exists bun; then
    log_ok "Bun found: $(bun --version)"
    return 0
  fi

  log_info "Bun is missing; installing Bun runtime"
  if [[ "$DRY_RUN" == "1" ]]; then
    run bash -c 'curl -fsSL https://bun.sh/install | bash'
  else
    if curl -fsSL --connect-timeout 15 https://bun.sh/install | bash; then
      log_ok "Bun installed with official installer"
    else
      log_warn "Official Bun installer failed; npm fallback may still work"
    fi
  fi

  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  command_exists bun || return 1
}

install_codex() {
  if [[ "$SKIP_CODEX_INSTALL" == "1" ]]; then
    log_info "Skipping Codex install"
    return 0
  fi

  if command_exists codex && [[ "$FORCE" != "1" ]]; then
    log_ok "Codex already installed: $(command -v codex)"
    return 0
  fi

  log_step "Codex" "Installing @openai/codex"
  if ensure_bun; then
    run bun install -g @openai/codex
    return 0
  fi

  command_exists npm || fail "npm is required when Bun is unavailable. Install Node.js or rerun without --no-bun."
  if run npm install -g @openai/codex; then
    return 0
  fi
  log_warn "npm default registry install failed; retrying with $NPM_REGISTRY"
  run npm install -g @openai/codex --registry="$NPM_REGISTRY"
}

backup_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local backup="$file.backup.$(date +%Y%m%d_%H%M%S)"
  run cp "$file" "$backup"
  log_ok "Backup created: $backup"
}

write_private_env() {
  [[ -n "$API_KEY" ]] || fail "Missing CODEX_TOKEN or OPENAI_API_KEY"
  log_step "4/7" "Write private API key"
  log_info "Secret file: $PRIVATE_ENV_FILE"
  log_info "Provider env key: $PROVIDER_ENV_KEY"
  run mkdir -p "$(dirname "$PRIVATE_ENV_FILE")"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN: write %s=%s to %s\n" "$PROVIDER_ENV_KEY" "$(mask_secret "$API_KEY")" "$PRIVATE_ENV_FILE"
  else
    umask 077
    cat > "$PRIVATE_ENV_FILE" <<ENVEOF
# Managed by codex-bootstrap. Do not commit this file.
export $PROVIDER_ENV_KEY="$API_KEY"
ENVEOF
    chmod 600 "$PRIVATE_ENV_FILE"
  fi
  log_ok "Private env ready: $PRIVATE_ENV_FILE"
}

write_config() {
  log_step "5/7" "Write Codex custom provider config"
  run mkdir -p "$CODEX_HOME"
  backup_file "$CONFIG_FILE"
  local provider_escaped env_key_escaped model_escaped effort_escaped url_escaped project_escaped
  provider_escaped="$(toml_escape "$PROVIDER_ID")"
  env_key_escaped="$(toml_escape "$PROVIDER_ENV_KEY")"
  model_escaped="$(toml_escape "$MODEL")"
  effort_escaped="$(toml_escape "$REASONING_EFFORT")"
  url_escaped="$(toml_escape "$API_BASE_URL")"
  project_escaped="$(toml_escape "$PROJECT_DIR")"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN: write %s with model_provider=%s base_url=%s env_key=%s\n" "$CONFIG_FILE" "$PROVIDER_ID" "$API_BASE_URL" "$PROVIDER_ENV_KEY"
    return 0
  fi

  cat > "$CONFIG_FILE" <<TOML
# Managed by codex-bootstrap.
# This intentionally uses a custom provider, matching the simple gateway-oriented Codex setup.
model = "$model_escaped"
model_reasoning_effort = "$effort_escaped"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "$provider_escaped"

[model_providers."$provider_escaped"]
name = "$provider_escaped"
base_url = "$url_escaped"
wire_api = "responses"
env_key = "$env_key_escaped"

[plugins."browser-use@openai-bundled"]
enabled = true

[projects."$project_escaped"]
trust_level = "trusted"
TOML
}

install_rules_and_templates() {
  local source_dir="$1"
  local rules_src="$source_dir/templates/default.rules"
  local agents_src="$source_dir/templates/AGENTS.md"

  if [[ -f "$rules_src" ]]; then
    log_step "6/7" "Install rules and project instructions"
    run mkdir -p "$CODEX_HOME/rules"
    backup_file "$CODEX_HOME/rules/default.rules"
    run cp "$rules_src" "$CODEX_HOME/rules/default.rules"
  fi

  if [[ -f "$agents_src" ]]; then
    log_info "Installing project AGENTS.md into $PROJECT_DIR"
    run mkdir -p "$PROJECT_DIR"
    if [[ -f "$PROJECT_DIR/AGENTS.md" && "$FORCE" != "1" ]]; then
      log_warn "AGENTS.md already exists; keeping it. Use --force to overwrite."
    else
      backup_file "$PROJECT_DIR/AGENTS.md"
      run cp "$agents_src" "$PROJECT_DIR/AGENTS.md"
    fi
  fi
}

setup_shell_rc() {
  [[ "$SKIP_SHELL_RC" == "0" ]] || return 0
  local shell_rc
  shell_rc="$(detect_shell_rc)"
  local source_line="[ -f \"$PRIVATE_ENV_FILE\" ] && source \"$PRIVATE_ENV_FILE\""
  log_step "7/7" "Ensure shell loads private env"
  if [[ "$DRY_RUN" == "1" ]]; then
    printf "DRY-RUN: ensure source line exists in %s\n" "$shell_rc"
    return 0
  fi
  touch "$shell_rc"
  if ! grep -Fq "$source_line" "$shell_rc"; then
    {
      printf "\n# Codex Bootstrap secrets\n"
      printf "%s\n" "$source_line"
    } >> "$shell_rc"
  fi
  log_ok "Shell startup configured: $shell_rc"
}

main() {
  print_banner
  validate_env_key
  detect_platform
  log_step "1/7" "Inspect system and bootstrap settings"
  log_info "OS: $OS_NAME ($OS_ID/$ARCH_NAME)"
  log_info "Shell: ${SHELL_NAME:-unknown}, rc: $(detect_shell_rc)"
  log_info "Profile: $BOOTSTRAP_PROFILE"
  log_info "Provider: $PROVIDER_ID"
  log_info "Provider env key: $PROVIDER_ENV_KEY"
  log_info "Model: $MODEL"
  log_info "Reasoning effort: $REASONING_EFFORT"
  log_info "Base URL: $API_BASE_URL"
  [[ -n "$API_KEY" ]] && log_info "API key: $(mask_secret "$API_KEY")"

  local source_dir
  log_step "2/7" "Load profile and template assets"
  source_dir="$(download_source)"
  load_profile "$source_dir"
  log_step "3/7" "Install or verify Codex CLI"
  install_codex
  write_private_env
  write_config
  install_rules_and_templates "$source_dir"
  setup_shell_rc

  log_ok "Codex bootstrap completed"
  log_info "Reload shell env with: source $(detect_shell_rc)"
  log_info "Try: codex --search"
}

main "$@"
