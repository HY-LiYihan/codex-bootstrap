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

There are two entry styles:

1. Default one-line install: no menu, installs Codex after you explicitly pass both token and base URL.
2. Interactive menu: choose Codex, Claude Code, OpenClaw, or all agents.

Default one-line install on macOS/Linux:

```bash
wget https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -O agent && AGENT_TOKEN="YOUR_TOKEN" AGENT_BASE_URL="YOUR_BASE_URL" . ./agent
```

This is the shortest recommended path: no menu and no hidden base URL. `AGENT_TOKEN` and `AGENT_BASE_URL` are both required.

Default one-line install on Windows PowerShell:

```powershell
$env:AGENT_TOKEN='YOUR_TOKEN'; $env:AGENT_BASE_URL='YOUR_BASE_URL'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex
```

Interactive menu, similar in spirit to `wget http://fishros.com/install -O fishros && . fishros`:

macOS/Linux:

```bash
wget https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -O agent && . ./agent --menu
```

If `wget` is unavailable:

```bash
curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -o agent && . ./agent --menu
```

Windows PowerShell:

```powershell
$env:AGENT_BOOTSTRAP_MENU='1'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex
```

The default one-line mode writes the high-autonomy Codex config, but it does not provide a built-in key or base URL. The interactive menu shows common URL options as hints and still asks you to enter the value.

Online editable examples:

- [examples/codex-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/codex-default.sh)
- [examples/claudecode-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/claudecode-default.sh)
- [examples/openclaw-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/openclaw-default.sh)
- [examples/codex-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/codex-default.ps1)
- [examples/claudecode-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/claudecode-default.ps1)
- [examples/openclaw-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/openclaw-default.ps1)

Direct one-line install remains supported:

The main contract is deliberately simple:

- `AGENT`: `codex`, `claudecode`, or `openclaw`
- `AGENT_TOKEN`: the API token for that agent/gateway
- `AGENT_BASE_URL`: the API gateway/base URL for that agent
- `AGENT_MODEL`: optional model override for agents that use a model setting

macOS/Linux:

```bash
AGENT=codex AGENT_TOKEN="YOUR_TOKEN" AGENT_BASE_URL="YOUR_CODEX_BASE_URL" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

```bash
AGENT=claudecode AGENT_TOKEN="YOUR_TOKEN" AGENT_BASE_URL="YOUR_CLAUDE_BASE_URL" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

```bash
AGENT=openclaw AGENT_TOKEN="YOUR_TOKEN" AGENT_BASE_URL="YOUR_OPENCLAW_BASE_URL" AGENT_MODEL="anthropic/claude-opus-4-7" bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
```

Windows PowerShell:

```powershell
$env:AGENT='codex'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='YOUR_CODEX_BASE_URL'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

```powershell
$env:AGENT='claudecode'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='YOUR_CLAUDE_BASE_URL'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

```powershell
$env:AGENT='openclaw'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='YOUR_OPENCLAW_BASE_URL'
$env:AGENT_MODEL='anthropic/claude-opus-4-7'
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
approval_policy = "never"
sandbox_mode = "danger-full-access"

[model_providers."custom"]
name = "custom"
base_url = "YOUR_CODEX_BASE_URL"
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
AGENT=codex AGENT_TOKEN=test-token AGENT_BASE_URL=https://codex1.sssaicode.com/api/v1 AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run --skip-codex-install --skip-shell-rc --yes
AGENT=claudecode AGENT_TOKEN=test-token AGENT_BASE_URL=https://node-hk.sssaicode.com/api AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run --skip-claude-install
AGENT=openclaw AGENT_TOKEN=test-token AGENT_BASE_URL=https://node-hk.sssaicode.com/api AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run
```

Windows PowerShell:

```powershell
$env:CODEX_TOKEN='test-token'; .\agents\codex\install.ps1 -LocalSource . -DryRun -SkipCodexInstall -SkipProfileUpdate
$env:CLAUDE_CLIENT_TOKEN='test-token'; .\agents\claudecode\install.ps1 -DryRun -SkipInstall
$env:OPENCLAW_TOKEN='test-token'; .\agents\openclaw\install.ps1 -DryRun
```

## Agent Switch

`switch.js` is the provider/profile switcher layer. It is the part meant to replace the day-to-day value of tools like `ccswitch`: save one gateway profile once, then apply it across Codex, Claude Code, and OpenClaw.

Add a profile:

```bash
node switch.js add sss \
  --token YOUR_TOKEN \
  --base-url https://node-hk.sssaicode.com/api \
  --codex-url https://codex1.sssaicode.com/api/v1 \
  --openclaw-model anthropic/claude-opus-4-7
```

Apply it everywhere:

```bash
node switch.js use sss
```

Apply it only to Claude Code:

```bash
node switch.js use sss --agents claudecode
```

Fixed curl entrypoints:

macOS/Linux:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/switch.sh)" -- add sss --token YOUR_TOKEN --base-url https://node-hk.sssaicode.com/api
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/switch.sh)" -- use sss
```

Windows PowerShell:

```powershell
$tmp = Join-Path $env:TEMP 'agent-switch.ps1'
Invoke-WebRequest -Uri https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/switch.ps1 -OutFile $tmp
& $tmp add sss --token YOUR_TOKEN --base-url https://node-hk.sssaicode.com/api
& $tmp use sss
```

Check state:

```bash
node switch.js list
node switch.js current
node switch.js doctor
```

Claude Code note:

- The switcher writes `~/.agent-bootstrap/claude-code-env.sh` and `~/.agent-bootstrap/claude-code-env.ps1`.
- Those files unset `CLAUDE_CODE_OAUTH_TOKEN`, because that variable can override API-token based Claude Code settings.
- Run `node switch.js shell-hook` to print the shell/profile line to source the active Claude environment.

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
