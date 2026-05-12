# Agent Switch PowerShell wrapper.
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$RemainingArgs)
$repo = if ($env:BOOTSTRAP_REPO) { $env:BOOTSTRAP_REPO } else { 'HY-LiYihan/agent-bootstrap' }
$ref = if ($env:BOOTSTRAP_REF) { $env:BOOTSTRAP_REF } else { 'stable' }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Host '[ERROR] Node.js is required for agent switch' -ForegroundColor Red
  exit 1
}
if ($env:AGENT_BOOTSTRAP_LOCAL_SOURCE -and (Test-Path (Join-Path $env:AGENT_BOOTSTRAP_LOCAL_SOURCE 'switch.js'))) {
  node (Join-Path $env:AGENT_BOOTSTRAP_LOCAL_SOURCE 'switch.js') @RemainingArgs
} else {
  $tmp = Join-Path $env:TEMP ('agent-switch-' + [Guid]::NewGuid().ToString('N') + '.js')
  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$repo/$ref/switch.js" -OutFile $tmp -UseBasicParsing
  node $tmp @RemainingArgs
}
