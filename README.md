# Codex Bootstrap

Personal Codex bootstrapper for a simple gateway-oriented setup. It writes a `custom` model provider into `~/.codex/config.toml`, stores the API key in `~/.codex/private.env`, and keeps the install flow colorful and easy to read.

## Quick Start

Stable tag example:

```bash
CODEX_TOKEN="YOUR_TOKEN" \
CODEX_API_URL="https://api.example.com/v1" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/v1/install.sh)"
```

Development branch example:

```bash
CODEX_TOKEN="YOUR_TOKEN" \
CODEX_API_URL="https://api.example.com/v1" \
BOOTSTRAP_REF="main" \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/main/install.sh)" -- --profile experimental
```

Local dry run:

```bash
CODEX_TOKEN="test-token" ./install.sh --local . --dry-run --profile default
```

## What It Does

- Installs `@openai/codex` if missing, using Bun first and npm as fallback.
- Writes `~/.codex/private.env` with `CODEX_API_KEY` and file mode `600`.
- Writes `~/.codex/config.toml` with `model_provider = "custom"` and `[model_providers."custom"]`.
- Defaults to `model = "gpt-5.5"` and `model_reasoning_effort = "high"`.
- Enables the bundled browser plugin entry when available.
- Installs `~/.codex/rules/default.rules` and a project `AGENTS.md` template.
- Backs up existing config/rule files before replacing them.

## Generated Config

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "custom"

[model_providers."custom"]
name = "custom"
base_url = "https://api.example.com/v1"
wire_api = "responses"
env_key = "CODEX_API_KEY"
```

## Options

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

Provider/env customization:

```bash
CODEX_PROVIDER_ID="sss" \
CODEX_PROVIDER_ENV_KEY="SSS_API_KEY" \
CODEX_TOKEN="YOUR_TOKEN" \
CODEX_API_URL="https://api.example.com/v1" \
./install.sh --local .
```

## Release Flow

Use `main` as the development entrypoint and tags as stable entrypoints.

```bash
git tag v1
git push origin main v1
```

Then use:

```bash
curl -fsSL https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/v1/install.sh
```

## Security Notes

- Do not commit real tokens.
- Prefer passing tokens through `CODEX_TOKEN` or `OPENAI_API_KEY` at install time.
- The script writes secrets to `~/.codex/private.env`, not to this repository.
- Rotate any token that has been pasted into chats, logs, shell history, or public files.
