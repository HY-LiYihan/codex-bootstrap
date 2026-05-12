#!/usr/bin/env bash
# Agent Bootstrap dispatcher for macOS/Linux.

set -euo pipefail
IFS=$'\n\t'

BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-HY-LiYihan/agent-bootstrap}"
BOOTSTRAP_REF="${BOOTSTRAP_REF:-stable}"
AGENT="${AGENT:-}"
LOCAL_SOURCE="${AGENT_BOOTSTRAP_LOCAL_SOURCE:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { printf "%b[INFO]%b %s\n" "$BLUE" "$NC" "$1"; }
ok() { printf "%b[OK]%b %s\n" "$GREEN" "$NC" "$1"; }
warn() { printf "%b[WARN]%b %s\n" "$YELLOW" "$NC" "$1"; }
fail() { printf "%b[ERROR]%b %s\n" "$RED" "$NC" "$1" >&2; exit 1; }

usage() {
  cat <<USAGE
Agent Bootstrap

Usage:
  AGENT=codex bash -c "\$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
  AGENT=claudecode bash -c "\$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
  AGENT=openclaw bash -c "\$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"

Aliases:
  codex, claudecode, claude, openclaw

You can also pass the agent as the first argument:
  bash -c "\$(curl -fsSL .../install.sh)" -- codex
USAGE
}

normalize_agent() {
  case "$1" in
    codex|openai-codex) printf "codex" ;;
    claude|claudecode|claude-code) printf "claudecode" ;;
    openclaw|claw) printf "openclaw" ;;
    *) return 1 ;;
  esac
}

download_source() {
  if [[ -n "$LOCAL_SOURCE" ]]; then
    [[ -d "$LOCAL_SOURCE" ]] || fail "Local source not found: $LOCAL_SOURCE"
    printf "%s" "$LOCAL_SOURCE"
    return 0
  fi

  local tmp_dir url
  tmp_dir="$(mktemp -d)"
  url="https://github.com/${BOOTSTRAP_REPO}/archive/${BOOTSTRAP_REF}.tar.gz"
  info "Downloading agent bootstrap assets from $BOOTSTRAP_REPO@$BOOTSTRAP_REF" >&2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" | tar -xz -C "$tmp_dir" --strip-components=1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url" | tar -xz -C "$tmp_dir" --strip-components=1
  else
    fail "curl or wget is required"
  fi
  printf "%s" "$tmp_dir"
}

main() {
  printf "\n%b+--------------------------------------------------+%b\n" "$CYAN" "$NC"
  printf "%b|%b %bAgent Bootstrap%b                                 %b|%b\n" "$CYAN" "$NC" "$BOLD" "$NC" "$CYAN" "$NC"
  printf "%b|%b codex / claudecode / openclaw                 %b|%b\n" "$CYAN" "$NC" "$CYAN" "$NC"
  printf "%b+--------------------------------------------------+%b\n\n" "$CYAN" "$NC"

  local passthrough=()
  if [[ -z "$AGENT" && $# -gt 0 ]]; then
    case "${1:-}" in
      codex|openai-codex|claude|claudecode|claude-code|openclaw|claw)
        AGENT="$1"
        shift
        ;;
    esac
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --local) LOCAL_SOURCE="${2:?missing local dir}"; shift 2 ;;
      --repo) BOOTSTRAP_REPO="${2:?missing repo}"; shift 2 ;;
      --ref) BOOTSTRAP_REF="${2:?missing ref}"; shift 2 ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        if [[ -z "$AGENT" ]]; then
          case "$1" in
            codex|openai-codex|claude|claudecode|claude-code|openclaw|claw)
              AGENT="$1"
              shift
              continue
              ;;
          esac
        fi
        passthrough+=("$1")
        shift
        ;;
    esac
  done

  if [[ -z "$AGENT" ]]; then
    usage
    fail "Missing AGENT. Set AGENT=codex, AGENT=claudecode, or AGENT=openclaw."
  fi

  local normalized source_dir installer
  normalized="$(normalize_agent "$AGENT")" || fail "Unknown agent: $AGENT"
  source_dir="$(download_source)"
  installer="$source_dir/agents/$normalized/install.sh"

  [[ -f "$installer" ]] || fail "Installer not found: $installer"
  ok "Selected agent: $normalized"
  if [[ "$normalized" == "codex" ]]; then
    bash "$installer" --local "$source_dir" "${passthrough[@]}"
  else
    bash "$installer" "${passthrough[@]}"
  fi
}

main "$@"
