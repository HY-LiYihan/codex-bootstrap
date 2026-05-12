# Codex Config Notes

The important compatibility choice is keeping the built-in provider:

```toml
model_provider = "openai"
openai_base_url = "https://your-gateway.example.com/v1"
```

Avoid this as the default when plugin compatibility matters:

```toml
model_provider = "custom"

[model_providers.custom]
base_url = "https://your-gateway.example.com/v1"
env_key = "CUSTOM_API_KEY"
wire_api = "responses"
```

The custom provider form can be useful for experiments, but the official provider path is a safer default for Codex plugins, apps, MCP tools, and subagent behavior.
