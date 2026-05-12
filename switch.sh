#!/usr/bin/env bash
set -euo pipefail
BOOTSTRAP_REPO="${BOOTSTRAP_REPO:-HY-LiYihan/agent-bootstrap}"
BOOTSTRAP_REF="${BOOTSTRAP_REF:-stable}"
if ! command -v node >/dev/null 2>&1; then
  echo "[ERROR] Node.js is required for agent switch" >&2
  exit 1
fi
if [[ -f "${AGENT_BOOTSTRAP_LOCAL_SOURCE:-}/switch.js" ]]; then
  node "$AGENT_BOOTSTRAP_LOCAL_SOURCE/switch.js" "$@"
else
  tmp="$(mktemp)"
  curl -fsSL "https://raw.githubusercontent.com/${BOOTSTRAP_REPO}/${BOOTSTRAP_REF}/switch.js" -o "$tmp"
  node "$tmp" "$@"
fi
