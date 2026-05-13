# Codex Config Notes

The current bootstrap default intentionally uses a custom provider because this is the most direct shape for API gateway setups:

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
model_provider = "custom"
approval_policy = "never"
sandbox_mode = "danger-full-access"

[model_providers."custom"]
name = "custom"
base_url = "https://your-gateway.example.com/v1"
wire_api = "responses"
env_key = "CODEX_API_KEY"
```

If you want to mimic another installer more closely, override the provider name and env key:

```bash
CODEX_PROVIDER_ID="sss" CODEX_PROVIDER_ENV_KEY="SSS_API_KEY" ./install.sh
```

The API key is still stored in `~/.codex/private.env` instead of being written directly into `.zshrc` or `.bashrc`.

## Baseline usability defaults

The bootstrap also writes:

- `preferred_auth_method = "apikey"` so gateway tokens are used directly.
- `disable_response_storage = true` to reduce remote response retention.
- `[plugins."browser-use@openai-bundled"] enabled = true` so bundled browser tooling is available when compatible.
- `[projects."<project>"] trust_level = "trusted"` so the current project is ready without repeated trust prompts.
- `approval_policy = "never"` and `sandbox_mode = "danger-full-access"` for fully autonomous local execution.

Because this is a high-permission setup, the installed `AGENTS.md` and `default.rules` emphasize path checks, secret protection, backups, and narrow verification after edits.
