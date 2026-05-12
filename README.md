# Agent Bootstrap

One-click bootstrapper for multiple AI coding agents. It currently supports Codex, Claude Code, and OpenClaw, with shared `stable` / `latest` install tags and cross-platform entrypoints.

## Supported Agents

- `codex`: configures OpenAI Codex CLI with a custom gateway provider.
- `claudecode`: installs/configures Claude Code with `ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_BASE_URL`.
- `openclaw`: writes OpenClaw model and auth JSON config.

Aliases:

- `codex`, `openai-codex`
- `claudecode`, `claude`, `claude-code`
- `openclaw`, `claw`

## Quick Start

Codex on macOS/Linux:

```bash
CODEX_TOKEN="YOUR_TOKEN" \
CODEX_API_URL="https://codex1.sssaicode.com/api/v1" \
AGENT=codex \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

Codex on Windows PowerShell:

```powershell
$env:AGENT='codex'
$env:CODEX_TOKEN='YOUR_TOKEN'
$env:CODEX_API_URL='https://codex1.sssaicode.com/api/v1'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

Claude Code on macOS/Linux:

```bash
CLAUDE_TOKEN="YOUR_TOKEN" \
CLAUDE_API_URL="https://node-hk.sssaicode.com/api" \
AGENT=claudecode \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

Claude Code on Windows PowerShell:

```powershell
$env:AGENT='claudecode'
$env:CLAUDE_CLIENT_TOKEN='YOUR_TOKEN'
$env:CLAUDE_API_URL='https://node-hk.sssaicode.com/api'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

OpenClaw on macOS/Linux:

```bash
OPENCLAW_TOKEN="YOUR_TOKEN" \
OPENCLAW_BASE_URL="https://node-hk.sssaicode.com/api" \
OPENCLAW_MODEL="anthropic/claude-opus-4-7" \
AGENT=openclaw \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

OpenClaw on Windows PowerShell:

```powershell
$env:AGENT='openclaw'
$env:OPENCLAW_TOKEN='YOUR_TOKEN'
$env:OPENCLAW_BASE_URL='https://node-hk.sssaicode.com/api'
$env:OPENCLAW_MODEL='anthropic/claude-opus-4-7'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

## What Gets Written

Codex:

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "custom"

[model_providers."custom"]
name = "custom"
base_url = "https://codex1.sssaicode.com/api/v1"
wire_api = "responses"
env_key = "CODEX_API_KEY"
```

Claude Code:

- `~/.claude/settings.json` with `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`, timeout, and traffic-reduction env values.
- `~/.claude.json` with onboarding marked complete.

OpenClaw:

- `~/.openclaw/openclaw.json`
- `~/.openclaw/agents/main/agent/auth-profiles.json`

## Local Dry Runs

macOS/Linux:

```bash
AGENT=codex AGENT_BOOTSTRAP_LOCAL_SOURCE=. CODEX_TOKEN=test-token ./install.sh --dry-run --skip-codex-install --skip-shell-rc --yes
AGENT=claudecode AGENT_BOOTSTRAP_LOCAL_SOURCE=. CLAUDE_TOKEN=test-token ./install.sh --dry-run --skip-claude-install
AGENT=openclaw AGENT_BOOTSTRAP_LOCAL_SOURCE=. OPENCLAW_TOKEN=test-token ./install.sh --dry-run
```

Windows PowerShell:

```powershell
$env:CODEX_TOKEN='test-token'; .\agents\codex\install.ps1 -LocalSource . -DryRun -SkipCodexInstall -SkipProfileUpdate
$env:CLAUDE_CLIENT_TOKEN='test-token'; .\agents\claudecode\install.ps1 -DryRun -SkipInstall
$env:OPENCLAW_TOKEN='test-token'; .\agents\openclaw\install.ps1 -DryRun
```

## Release Flow

Use semantic version tags for immutable releases, and move `stable` / `latest` to the recommended release so install commands do not need to change.

- `stable`: recommended default install target.
- `latest`: alias for the newest published install target.
- `vX.Y`: immutable version tags for pinning and rollback.

```bash
git tag -f stable
git tag -f latest
git push -f origin stable latest
```

## Security Notes

- Do not commit real tokens.
- Prefer passing tokens through environment variables at install time.
- Rotate any token that has been pasted into chats, logs, shell history, or public files.
