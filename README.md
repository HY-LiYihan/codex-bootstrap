# Codex Bootstrap

Personal Codex bootstrapper that keeps the official `openai` provider enabled while routing API calls through `openai_base_url` when needed. This preserves the best chance of compatibility with Codex plugins, apps, MCP, browser tools, and subagents.

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
- Writes `~/.codex/private.env` with `OPENAI_API_KEY` and file mode `600`.
- Writes `~/.codex/config.toml` with `model_provider = "openai"` and `openai_base_url = "$CODEX_API_URL"`.
- Enables stable Codex features such as plugins, browser use, multi-agent support, tool search, and workspace dependencies.
- Enables the bundled browser plugin when available.
- Installs `~/.codex/rules/default.rules` and a project `AGENTS.md` template.
- Backs up existing config/rule files before replacing them.

## Why Not A Custom Provider?

Custom providers can work for model calls, but some Codex plugin/app/MCP paths are most compatible with the built-in `openai` provider. This bootstrapper keeps the official provider and only changes the base URL.

The generated core config looks like this:

```toml
model_provider = "openai"
openai_base_url = "https://api.example.com/v1"
preferred_auth_method = "apikey"
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
