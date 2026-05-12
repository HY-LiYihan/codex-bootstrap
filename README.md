# Codex Bootstrap

Personal Codex bootstrapper for a simple gateway-oriented setup. It writes a `custom` model provider into Codex config, stores the API key locally, and supports macOS, Linux, and Windows entrypoints.

## Seven-Step Flow

Both `install.sh` and `install.ps1` follow the same 7-step flow:

1. Inspect system and bootstrap settings: print OS/shell or PowerShell context, provider, model, reasoning effort, base URL, and masked token status.
2. Load profile and template assets: load `profiles/<name>.env` and templates from the GitHub repo, tag, branch, or local checkout.
3. Install or verify Codex CLI: reuse an existing `codex` binary unless `--force`/`-Force` is used; otherwise install `@openai/codex` with Bun first and npm fallback.
4. Write private API key: write the token into a local private env file and set the provider env key for the current user/session.
5. Write Codex custom provider config: generate `config.toml` with `model_provider = "custom"`, `gpt-5.5`, and `high` reasoning by default.
6. Install rules and project instructions: install global `default.rules` and a project `AGENTS.md` template when available.
7. Ensure shell loads private env: update shell startup on macOS/Linux or PowerShell profile/user environment on Windows.

## Quick Start

macOS:

```bash
CODEX_TOKEN="YOUR_TOKEN" \
CODEX_API_URL="https://codex1.sssaicode.com/api/v1" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/main/install.sh)"
```

Linux:

```bash
CODEX_TOKEN="YOUR_TOKEN" \
CODEX_API_URL="https://codex1.sssaicode.com/api/v1" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/main/install.sh)"
```

Windows PowerShell:

```powershell
$env:CODEX_TOKEN='YOUR_TOKEN'
$env:CODEX_API_URL='https://codex1.sssaicode.com/api/v1'
irm https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/main/install.ps1 | iex
```

Local dry run on macOS/Linux:

```bash
CODEX_TOKEN="test-token" ./install.sh --local . --dry-run --skip-codex-install --skip-shell-rc --yes
```

Local dry run on Windows:

```powershell
$env:CODEX_TOKEN='test-token'
.\install.ps1 -LocalSource . -DryRun -SkipCodexInstall -SkipProfileUpdate
```

## Generated Config

Default generated TOML:

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

Provider/env customization, for example to mimic an `sss` provider layout:

macOS/Linux:

```bash
CODEX_PROVIDER_ID="sss" \
CODEX_PROVIDER_ENV_KEY="SSS_API_KEY" \
CODEX_TOKEN="YOUR_TOKEN" \
CODEX_API_URL="https://codex1.sssaicode.com/api/v1" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/main/install.sh)"
```

Windows:

```powershell
$env:CODEX_PROVIDER_ID='sss'
$env:CODEX_PROVIDER_ENV_KEY='SSS_API_KEY'
$env:CODEX_TOKEN='YOUR_TOKEN'
$env:CODEX_API_URL='https://codex1.sssaicode.com/api/v1'
irm https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/main/install.ps1 | iex
```

## Bash Options

```text
--profile NAME       Apply profiles/NAME.env
--project DIR        Write AGENTS.md into this project directory
--repo OWNER/REPO    Download assets from another GitHub repository
--ref REF            Download assets from a tag or branch
--local DIR          Use local assets instead of GitHub download
--dry-run            Print planned changes only
--yes                Skip prompts
--force              Reinstall/overwrite managed files
--skip-codex-install Do not install @openai/codex
--skip-shell-rc      Do not update .zshrc/.bashrc
--no-bun             Do not install Bun automatically
```

## Release Flow

Use `main` as the development entrypoint and tags as stable entrypoints.

```bash
git tag v2
git push origin main v2
```

Then use:

```bash
curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/v2/install.sh
```

## Security Notes

- Do not commit real tokens.
- Prefer passing tokens through `CODEX_TOKEN` or `OPENAI_API_KEY` at install time.
- macOS/Linux writes secrets to `~/.codex/private.env` and sources it from shell startup.
- Windows writes secrets to `%USERPROFILE%\.codex\private.env`, updates the PowerShell profile, and sets the user environment variable.
- Rotate any token that has been pasted into chats, logs, shell history, or public files.
