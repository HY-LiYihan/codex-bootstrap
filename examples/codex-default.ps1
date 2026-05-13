# Edit YOUR_TOKEN and YOUR_CODEX_BASE_URL, then run this file or paste the command.
$env:AGENT='codex'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='YOUR_CODEX_BASE_URL'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
