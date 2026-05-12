# OpenClaw bootstrap wrapper for Windows PowerShell.
param([switch]$DryRun)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script = Join-Path $scriptDir 'install.js'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Host '[ERROR] Node.js is required for OpenClaw bootstrap' -ForegroundColor Red
  exit 1
}
if ($DryRun) { node $script --dry-run } else { node $script }
