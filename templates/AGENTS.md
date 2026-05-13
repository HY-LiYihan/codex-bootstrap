# Project Agent Instructions

- Work autonomously until the requested task is handled end-to-end: inspect, implement, verify, and summarize.
- Use the repository's existing style, tooling, scripts, and tests before introducing new conventions.
- Keep the main conversation responsive: delegate long exploration, status checks, broad scans, and slow verification to subagents when practical.
- Prefer `rg` / `rg --files` for search, and run the narrowest useful test or syntax check after edits.
- Do not expose secrets from `.env`, `~/.codex/private.env`, shell history, keychains, local config files, or CI variables.
- Preserve user work: do not revert unrelated changes, do not run destructive git commands, and create backups before changing user-level agent configuration.
- Prefer official Codex/OpenAI compatibility for plugins, apps, MCP tools, and subagents unless the project explicitly requires a custom provider.
- When Codex is configured with `approval_policy = "never"` and `sandbox_mode = "danger-full-access"`, act carefully: make small reversible edits, avoid broad filesystem mutations, and verify paths before writes.
- For frontend work, preserve the existing design system unless the task explicitly asks for a redesign.
- For documentation, keep commands copy-pasteable and avoid committing real tokens.
