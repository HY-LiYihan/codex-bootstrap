# Project Agent Instructions

- Use the repository's existing style, tooling, and tests before introducing new conventions.
- Keep the main conversation responsive: delegate long exploration, status checks, and verification to subagents when practical.
- Do not expose secrets from `.env`, `~/.codex/private.env`, shell history, keychains, or local config files.
- Prefer official Codex/OpenAI provider compatibility for plugins, apps, MCP tools, and subagents.
- Before risky edits, create backups or keep changes small enough to review and revert easily.
