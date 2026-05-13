# Edit YOUR_TOKEN, then run this file or paste the command.
$env:AGENT='claudecode'
$env:AGENT_TOKEN='YOUR_TOKEN'
$env:AGENT_BASE_URL='https://node-hk.sssaicode.com/api'
irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex
