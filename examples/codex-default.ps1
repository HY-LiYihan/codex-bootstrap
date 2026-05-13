# Edit YOUR_TOKEN, then run this file or paste the command.
$env:AGENT='codex'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='https://codex1.sssaicode.com/api/v1'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
