#!/usr/bin/env bash
set -euo pipefail

# Codex++ is an optional Codex App enhancer. It does not need an API token.
AGENT=codexplusplus bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
