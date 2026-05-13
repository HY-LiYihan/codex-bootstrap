# Agent Bootstrap default/menu entrypoint for Windows PowerShell.
# Default: $env:AGENT_TOKEN='YOUR_TOKEN'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex
# Menu:    $env:AGENT_BOOTSTRAP_MENU='1'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex
param([switch]$Menu)

$ErrorActionPreference = 'Stop'
$repo = if ($env:BOOTSTRAP_REPO) { $env:BOOTSTRAP_REPO } else { 'HY-LiYihan/agent-bootstrap' }
$ref = if ($env:BOOTSTRAP_REF) { $env:BOOTSTRAP_REF } else { 'stable' }
$raw = "https://raw.githubusercontent.com/$repo/$ref"

function Ask-Value {
    param([string]$Prompt, [string]$Default = '')
    if ($Default) { $answer = Read-Host "$Prompt [$Default]" } else { $answer = Read-Host $Prompt }
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer
}

function Invoke-AgentInstaller {
    param(
        [string]$Agent,
        [string]$Token,
        [string]$BaseUrl,
        [string]$Model = ''
    )
    $env:AGENT = $Agent
    $env:AGENT_TOKEN = $Token
    $env:AGENT_BASE_URL = $BaseUrl
    if ($Model) { $env:AGENT_MODEL = $Model }

    if ($env:AGENT_BOOTSTRAP_LOCAL_SOURCE -and (Test-Path (Join-Path $env:AGENT_BOOTSTRAP_LOCAL_SOURCE 'install.ps1'))) {
        & (Join-Path $env:AGENT_BOOTSTRAP_LOCAL_SOURCE 'install.ps1')
        return
    }
    irm "$raw/install.ps1" | iex
}

function Show-Banner {
    param([string]$Title, [string]$Subtitle)
    Write-Host ''
    Write-Host '+--------------------------------------------------+' -ForegroundColor Cyan
    Write-Host (("| $Title").PadRight(51) + '|') -ForegroundColor Cyan
    Write-Host (("| $Subtitle").PadRight(51) + '|') -ForegroundColor Cyan
    Write-Host '+--------------------------------------------------+' -ForegroundColor Cyan
    Write-Host ''
}

$useMenu = $Menu -or ($env:AGENT_BOOTSTRAP_MENU -eq '1')

if (-not $useMenu) {
    $token = if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } elseif ($env:CODEX_TOKEN) { $env:CODEX_TOKEN } else { '' }
    $baseUrl = if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } elseif ($env:CODEX_API_URL) { $env:CODEX_API_URL } else { 'https://codex1.sssaicode.com/api/v1' }
    if (-not $token) {
        Write-Host '[ERROR] Missing AGENT_TOKEN. Example: $env:AGENT_TOKEN=''YOUR_TOKEN''; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex' -ForegroundColor Red
        Write-Host '[INFO] For interactive setup: $env:AGENT_BOOTSTRAP_MENU=''1''; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/agent.ps1 | iex' -ForegroundColor Cyan
        exit 1
    }
    Show-Banner 'Agent Bootstrap Default' 'Codex full-auto ready'
    Write-Host "[INFO] Agent: codex" -ForegroundColor Cyan
    Write-Host "[INFO] Base URL: $baseUrl" -ForegroundColor Cyan
    Invoke-AgentInstaller -Agent 'codex' -Token $token -BaseUrl $baseUrl
    return
}

Show-Banner 'Agent Bootstrap Interactive' 'one menu -> one ready agent'
Write-Host 'Choose an install target:'
Write-Host '  1) Codex full-auto default (recommended)'
Write-Host '  2) Claude Code'
Write-Host '  3) OpenClaw'
Write-Host '  4) All three agents with the same token/base URL'
Write-Host '  q) Quit'

$choice = Ask-Value 'Select' '1'
switch ($choice.ToLowerInvariant()) {
    { $_ -in @('1', 'codex') } { $agent = 'codex'; break }
    { $_ -in @('2', 'claude', 'claudecode', 'claude-code') } { $agent = 'claudecode'; break }
    { $_ -in @('3', 'openclaw', 'claw') } { $agent = 'openclaw'; break }
    { $_ -in @('4', 'all') } { $agent = 'all'; break }
    { $_ -in @('q', 'quit') } { Write-Host '[WARN] Cancelled' -ForegroundColor Yellow; return }
    default { throw "Unknown choice: $choice" }
}

if ($agent -eq 'codex') {
    $token = Ask-Value 'API token' $(if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } elseif ($env:CODEX_TOKEN) { $env:CODEX_TOKEN } else { '' })
    $baseUrl = Ask-Value 'Codex API base URL' $(if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } elseif ($env:CODEX_API_URL) { $env:CODEX_API_URL } else { 'https://codex1.sssaicode.com/api/v1' })
    Invoke-AgentInstaller -Agent 'codex' -Token $token -BaseUrl $baseUrl
} elseif ($agent -eq 'claudecode') {
    $token = Ask-Value 'API token' $(if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } elseif ($env:CLAUDE_TOKEN) { $env:CLAUDE_TOKEN } elseif ($env:CLAUDE_CLIENT_TOKEN) { $env:CLAUDE_CLIENT_TOKEN } else { '' })
    $baseUrl = Ask-Value 'Claude API base URL' $(if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } elseif ($env:CLAUDE_API_URL) { $env:CLAUDE_API_URL } else { 'https://node-hk.sssaicode.com/api' })
    Invoke-AgentInstaller -Agent 'claudecode' -Token $token -BaseUrl $baseUrl
} elseif ($agent -eq 'openclaw') {
    $token = Ask-Value 'API token' $(if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } elseif ($env:OPENCLAW_TOKEN) { $env:OPENCLAW_TOKEN } else { '' })
    $baseUrl = Ask-Value 'OpenClaw base URL' $(if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } elseif ($env:OPENCLAW_BASE_URL) { $env:OPENCLAW_BASE_URL } else { 'https://node-hk.sssaicode.com/api' })
    $model = Ask-Value 'OpenClaw model' $(if ($env:AGENT_MODEL) { $env:AGENT_MODEL } elseif ($env:OPENCLAW_MODEL) { $env:OPENCLAW_MODEL } else { 'anthropic/claude-opus-4-7' })
    Invoke-AgentInstaller -Agent 'openclaw' -Token $token -BaseUrl $baseUrl -Model $model
} else {
    $sharedToken = Ask-Value 'Shared API token' $(if ($env:AGENT_TOKEN) { $env:AGENT_TOKEN } else { '' })
    $sharedBase = Ask-Value 'Shared non-Codex base URL' $(if ($env:AGENT_BASE_URL) { $env:AGENT_BASE_URL } else { 'https://node-hk.sssaicode.com/api' })
    $codexBase = Ask-Value 'Codex API base URL' $(if ($env:CODEX_API_URL) { $env:CODEX_API_URL } else { 'https://codex1.sssaicode.com/api/v1' })
    $model = Ask-Value 'OpenClaw model' $(if ($env:AGENT_MODEL) { $env:AGENT_MODEL } elseif ($env:OPENCLAW_MODEL) { $env:OPENCLAW_MODEL } else { 'anthropic/claude-opus-4-7' })

    Invoke-AgentInstaller -Agent 'codex' -Token $sharedToken -BaseUrl $codexBase
    Invoke-AgentInstaller -Agent 'claudecode' -Token $sharedToken -BaseUrl $sharedBase
    Invoke-AgentInstaller -Agent 'openclaw' -Token $sharedToken -BaseUrl $sharedBase -Model $model
}

Write-Host '[OK] Agent Bootstrap finished' -ForegroundColor Green
