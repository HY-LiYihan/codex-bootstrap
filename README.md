# Agent Bootstrap

One-click bootstrapper for multiple AI coding agents and Codex App addons. It currently supports Codex, Claude Code, OpenClaw, and Codex++, with shared `stable` / `latest` install tags and cross-platform entrypoints.

## Supported Agents

- `codex`: configures OpenAI Codex CLI with a custom gateway provider.
- `claudecode`: installs/configures Claude Code with `ANTHROPIC_AUTH_TOKEN` and `ANTHROPIC_BASE_URL`.
- `openclaw`: writes OpenClaw model and auth JSON config.

## Supported Addons

- `codexplusplus`: installs [BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus), an external Codex App enhancer that unlocks plugin entry points, session deletion/export, timeline, and provider metadata sync. It does not write API keys or provider config.

Aliases:

- `codex`, `openai-codex`
- `claudecode`, `claude`, `claude-code`
- `openclaw`, `claw`
- `codexplusplus`, `codex-plus-plus`, `codex++`, `cpp`

## Quick Start

There are three entry styles:

1. macOS/Linux wizard: one command, then enter `base_url` and `key`, choose high-autonomy or safe Codex config, and optionally install Codex++.
2. Direct install: pass env values up front for non-interactive setup.
3. Interactive menu: choose Codex, Claude Code, OpenClaw, Codex++, or all provider-configured agents.

macOS/Linux wizard:

```bash
wget https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -O agent && . ./agent
```

If `wget` is unavailable:

```bash
curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -o agent && . ./agent
```

If you already have env vars set but still want the wizard:

```bash
wget https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -O agent && . ./agent --wizard
```

The wizard never uses a hidden key or base URL. It asks for both values explicitly, then offers:

- `Maximum autonomy`: writes `approval_policy = "never"` and `sandbox_mode = "danger-full-access"`.
- `Official safe defaults`: leaves approval policy, sandbox mode, and project trust at Codex defaults.
- `Codex++ addon`: optional install, optional provider sync, optional immediate launch.

Non-interactive Codex install on macOS/Linux:

```bash
wget https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent -O agent && AGENT_TOKEN="YOUR_TOKEN" AGENT_BASE_URL="YOUR_BASE_URL" . ./agent
```

Non-interactive Codex install on Windows PowerShell:

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

The default non-interactive mode writes the high-autonomy Codex config, but it does not provide a built-in key or base URL. The wizard and menu show common URL options as hints and still ask you to enter the value.

Online editable examples:

- [examples/codex-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/codex-default.sh)
- [examples/claudecode-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/claudecode-default.sh)
- [examples/openclaw-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/openclaw-default.sh)
- [examples/codexplusplus-default.sh](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/codexplusplus-default.sh)
- [examples/codex-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/codex-default.ps1)
- [examples/claudecode-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/claudecode-default.ps1)
- [examples/openclaw-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/openclaw-default.ps1)
- [examples/codexplusplus-default.ps1](https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/examples/codexplusplus-default.ps1)

Direct one-line install remains supported:

The main contract is deliberately simple:

- `AGENT`: `codex`, `claudecode`, `openclaw`, or `codexplusplus`
- `AGENT_TOKEN`: the API token for that agent/gateway
- `AGENT_BASE_URL`: the API gateway/base URL for that agent
- `AGENT_MODEL`: optional model override for agents that use a model setting
- `CODEX_SECURITY_PROFILE`: `max` or `safe`, default `max`
- `CODEX_PLUS_PLUS_REF`: optional upstream Codex++ ref/tag, default `v1.0.7`

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

```bash
AGENT=codexplusplus bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.sh)"
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

```powershell
$env:AGENT='codexplusplus'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
```

## What Gets Written

Codex, maximum-autonomy profile:

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

Codex, safe profile:

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "custom"

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

Codex++:

- Installs the upstream Python package from `BigPizzaV3/CodexPlusPlus`, pinned by default to `v1.0.7`.
- Runs `python -m codex_session_delete setup`.
- Writes `~/.codex-session-delete/settings.json` with `providerSyncEnabled` when provider sync is selected.
- On macOS, upstream setup creates `/Applications/Codex++.app`.
- On Windows, upstream setup creates the `Codex++` shortcut/launcher integration.
- It may later write Codex++ runtime data under `~/.codex-session-delete` and provider-sync backups under `~/.codex/backups_state/provider-sync` when used.
- It does not change Codex provider credentials; use `AGENT=codex` first for `~/.codex/config.toml`.

## Local Dry Runs

macOS/Linux:

```bash
AGENT=codex AGENT_TOKEN=test-token AGENT_BASE_URL=https://codex1.sssaicode.com/api/v1 AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run --skip-codex-install --skip-shell-rc --yes
AGENT=claudecode AGENT_TOKEN=test-token AGENT_BASE_URL=https://node-hk.sssaicode.com/api AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run --skip-claude-install
AGENT=openclaw AGENT_TOKEN=test-token AGENT_BASE_URL=https://node-hk.sssaicode.com/api AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run
AGENT=codexplusplus AGENT_BOOTSTRAP_LOCAL_SOURCE=. ./install.sh --dry-run --skip-setup --provider-sync
```

Windows PowerShell:

```powershell
$env:CODEX_TOKEN='test-token'; .\agents\codex\install.ps1 -LocalSource . -DryRun -SkipCodexInstall -SkipProfileUpdate
$env:CLAUDE_CLIENT_TOKEN='test-token'; .\agents\claudecode\install.ps1 -DryRun -SkipInstall
$env:OPENCLAW_TOKEN='test-token'; .\agents\openclaw\install.ps1 -DryRun
.\agents\codexplusplus\install.ps1 -DryRun -SkipSetup -ProviderSync 1
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
