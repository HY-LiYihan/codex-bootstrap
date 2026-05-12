# Codex Config Notes

The current bootstrap default intentionally uses a custom provider because this is the most direct shape for API gateway setups:

```toml
model = "gpt-5.5"
model_reasoning_effort = "high"
model_provider = "custom"

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
