# Codex Bootstrap for Windows PowerShell
# Usage: $env:CODEX_TOKEN='YOUR_TOKEN'; $env:CODEX_API_URL='https://gateway.example.com/v1'; irm https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/main/install.ps1 | iex

param(
    [string]$Token = $(if ($env:CODEX_TOKEN) { $env:CODEX_TOKEN } else { $env:OPENAI_API_KEY }),
    [string]$BaseUrl = $(if ($env:CODEX_API_URL) { $env:CODEX_API_URL } elseif ($env:OPENAI_BASE_URL) { $env:OPENAI_BASE_URL } else { "https://api.openai.com/v1" }),
    [string]$ProviderId = $(if ($env:CODEX_PROVIDER_ID) { $env:CODEX_PROVIDER_ID } else { "custom" }),
    [string]$ProviderEnvKey = $(if ($env:CODEX_PROVIDER_ENV_KEY) { $env:CODEX_PROVIDER_ENV_KEY } else { "CODEX_API_KEY" }),
    [string]$Model = $(if ($env:CODEX_MODEL) { $env:CODEX_MODEL } else { "gpt-5.5" }),
    [string]$ReasoningEffort = $(if ($env:CODEX_REASONING_EFFORT) { $env:CODEX_REASONING_EFFORT } else { "high" }),
    [string]$NpmRegistry = $(if ($env:CODEX_NPM_REGISTRY) { $env:CODEX_NPM_REGISTRY } else { "https://registry.npmmirror.com" }),
    [string]$BootstrapRepo = $(if ($env:BOOTSTRAP_REPO) { $env:BOOTSTRAP_REPO } else { "HY-LiYihan/codex-bootstrap" }),
    [string]$BootstrapRef = $(if ($env:BOOTSTRAP_REF) { $env:BOOTSTRAP_REF } else { "main" }),
    [string]$Profile = $(if ($env:CODEX_PROFILE) { $env:CODEX_PROFILE } else { "default" }),
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }),
    [string]$ProjectDir = $(if ($env:CODEX_PROJECT_DIR) { $env:CODEX_PROJECT_DIR } else { (Get-Location).Path }),
    [string]$LocalSource = "",
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$Force,
    [switch]$SkipCodexInstall,
    [switch]$SkipProfileUpdate,
    [switch]$NoBun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ConfigFile = Join-Path $CodexHome "config.toml"
$PrivateEnvFile = $(if ($env:CODEX_PRIVATE_ENV_FILE) { $env:CODEX_PRIVATE_ENV_FILE } else { Join-Path $CodexHome "private.env" })

function Write-Banner {
    Write-Host ""
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "| " -NoNewline -ForegroundColor Cyan
    Write-Host "Codex Bootstrap" -NoNewline -ForegroundColor White
    Write-Host "                                 |" -ForegroundColor Cyan
    Write-Host "| custom provider + Windows setup                 |" -ForegroundColor Cyan
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step { param([string]$Step, [string]$Message) Write-Host ""; Write-Host "[$Step] " -NoNewline -ForegroundColor Magenta; Write-Host $Message -ForegroundColor White }
function Write-Ok { param([string]$Message) Write-Host "[OK] " -NoNewline -ForegroundColor Green; Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Host "[WARN] " -NoNewline -ForegroundColor Yellow; Write-Host $Message }
function Write-Info { param([string]$Message) Write-Host "[INFO] " -NoNewline -ForegroundColor Blue; Write-Host $Message }
function Fail { param([string]$Message) Write-Host "[ERROR] " -NoNewline -ForegroundColor Red; Write-Host $Message; exit 1 }

function Show-Help {
    Write-Host @"
Codex Bootstrap for Windows

Usage:
  `$env:CODEX_TOKEN='YOUR_TOKEN'; `$env:CODEX_API_URL='https://gateway.example.com/v1'; irm https://raw.githubusercontent.com/HY-LiYihan/codex-bootstrap/main/install.ps1 | iex

Environment:
  CODEX_TOKEN or OPENAI_API_KEY       API key written to the provider env key
  CODEX_API_URL or OPENAI_BASE_URL    API base URL written to [model_providers.custom]
  CODEX_PROVIDER_ID                   Provider id (default: custom)
  CODEX_PROVIDER_ENV_KEY              Provider env key (default: CODEX_API_KEY)
  CODEX_MODEL                         Default model (default: gpt-5.5)
  CODEX_REASONING_EFFORT              Reasoning effort (default: high)
  CODEX_NPM_REGISTRY                  npm fallback registry (default: https://registry.npmmirror.com)
  BOOTSTRAP_REF                       Git branch/tag for templates (default: main)
"@
}

function Invoke-Run {
    param([string]$Description, [scriptblock]$Action)
    if ($DryRun) {
        Write-Host "DRY-RUN: $Description"
    } else {
        & $Action
    }
}

function Mask-Secret {
    param([string]$Value)
    if (-not $Value) { return "<missing>" }
    if ($Value.Length -le 8) { return "<hidden>" }
    return "$($Value.Substring(0, 4))...$($Value.Substring($Value.Length - 4))"
}

function Escape-TomlString {
    param([string]$Value)
    return $Value.Replace('\', '\\').Replace('"', '\"')
}

function Escape-PowerShellSingleQuotedString {
    param([string]$Value)
    return $Value.Replace("'", "''")
}

function Assert-EnvKey {
    if ($ProviderEnvKey -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        Fail "Invalid CODEX_PROVIDER_ENV_KEY: $ProviderEnvKey"
    }
}

function Get-SourceDir {
    if ($LocalSource) {
        if (-not (Test-Path $LocalSource)) { Fail "Local source not found: $LocalSource" }
        return (Resolve-Path $LocalSource).Path
    }

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("codex-bootstrap-" + [Guid]::NewGuid().ToString("N"))
    $zip = "$tmp.zip"
    $url = "https://github.com/$BootstrapRepo/archive/$BootstrapRef.zip"
    Write-Info "Downloading bootstrap assets from $BootstrapRepo@$BootstrapRef"
    Invoke-Run "download $url" { Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing }
    Invoke-Run "expand $zip" { Expand-Archive -Path $zip -DestinationPath $tmp -Force }
    if ($DryRun) { return $tmp }
    $child = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
    if (-not $child) { Fail "Unable to expand bootstrap assets" }
    return $child.FullName
}

function Load-Profile {
    param([string]$SourceDir)
    $profileFile = Join-Path $SourceDir "profiles\$Profile.env"
    if (-not (Test-Path $profileFile)) {
        Write-Warn "Profile not found: $Profile; using built-in defaults"
        return
    }

    $content = Get-Content $profileFile -Raw
    if ($content -match 'CODEX_MODEL:=([^}\"]+)') { $script:Model = $Matches[1] }
    if ($content -match 'CODEX_REASONING_EFFORT:=([^}\"]+)') { $script:ReasoningEffort = $Matches[1] }
    Write-Ok "Loaded profile: $Profile"
}

function Test-CommandExists {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Ensure-Bun {
    if (Test-CommandExists "bun") {
        $version = (& bun --version 2>$null)
        Write-Ok "Bun found: v$version"
        return $true
    }
    if ($NoBun) { return $false }
    Write-Info "Installing Bun with the official PowerShell installer"
    Invoke-Run "install Bun" { powershell -NoProfile -ExecutionPolicy Bypass -Command "irm bun.sh/install.ps1 | iex" }
    $bunBin = Join-Path $env:USERPROFILE ".bun\bin"
    if (Test-Path $bunBin) { $env:Path = "$bunBin;$env:Path" }
    return (Test-CommandExists "bun")
}

function Install-Codex {
    if ($SkipCodexInstall) {
        Write-Info "Skipping Codex install"
        return
    }
    if ((Test-CommandExists "codex") -and (-not $Force)) {
        Write-Ok "Codex already installed: $((Get-Command codex).Source)"
        return
    }

    if (Ensure-Bun) {
        Invoke-Run "bun install -g @openai/codex" { & bun install -g '@openai/codex' }
        return
    }

    if (-not (Test-CommandExists "npm")) {
        Fail "npm is required when Bun is unavailable. Install Node.js or rerun without -NoBun."
    }
    if ($DryRun) {
        Invoke-Run "npm install -g @openai/codex" { & npm install -g '@openai/codex' }
        return
    }

    try {
        & npm install -g '@openai/codex'
        if ($LASTEXITCODE -eq 0) { return }
        throw "npm install exited with $LASTEXITCODE"
    } catch {
        Write-Warn "npm default registry install failed; retrying with $NpmRegistry"
        & npm install -g '@openai/codex' "--registry=$NpmRegistry"
    }
}

function Backup-File {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    $backup = "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Invoke-Run "copy $Path to $backup" { Copy-Item -Path $Path -Destination $backup -Force }
    Write-Ok "Backup created: $backup"
}

function Write-PrivateEnv {
    if (-not $Token) { Fail "Missing CODEX_TOKEN or OPENAI_API_KEY" }
    Write-Info "Secret file: $PrivateEnvFile"
    Write-Info "Provider env key: $ProviderEnvKey"
    Invoke-Run "create $CodexHome" { New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null }
    $tokenEscaped = Escape-PowerShellSingleQuotedString $Token
    $content = "# Managed by codex-bootstrap. Do not commit this file.`n`$" + "env:$ProviderEnvKey = '$tokenEscaped'`n"
    Invoke-Run "write $ProviderEnvKey to $PrivateEnvFile" { [System.IO.File]::WriteAllText($PrivateEnvFile, $content, [System.Text.UTF8Encoding]::new($false)) }
    Invoke-Run "set user environment variable $ProviderEnvKey" { [System.Environment]::SetEnvironmentVariable($ProviderEnvKey, $Token, [System.EnvironmentVariableTarget]::User) }
    Invoke-Run "set current session environment variable $ProviderEnvKey" { Set-Item -Path "Env:$ProviderEnvKey" -Value $Token }
    Write-Ok "Private env and user environment are ready"
}

function Write-CodexConfig {
    Invoke-Run "create $CodexHome" { New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null }
    Backup-File $ConfigFile

    $provider = Escape-TomlString $ProviderId
    $envKey = Escape-TomlString $ProviderEnvKey
    $modelEscaped = Escape-TomlString $Model
    $effort = Escape-TomlString $ReasoningEffort
    $url = Escape-TomlString $BaseUrl
    $project = Escape-TomlString $ProjectDir

    $config = @"
# Managed by codex-bootstrap.
# This intentionally uses a custom provider, matching the simple gateway-oriented Codex setup.
model = "$modelEscaped"
model_reasoning_effort = "$effort"
preferred_auth_method = "apikey"
disable_response_storage = true
model_provider = "$provider"
windows_wsl_setup_acknowledged = true

[model_providers."$provider"]
name = "$provider"
base_url = "$url"
wire_api = "responses"
env_key = "$envKey"

[plugins."browser-use@openai-bundled"]
enabled = true

[projects."$project"]
trust_level = "trusted"
"@
    Invoke-Run "write $ConfigFile" { [System.IO.File]::WriteAllText($ConfigFile, $config, [System.Text.UTF8Encoding]::new($false)) }
    Write-Ok "Config file ready: $ConfigFile"
}

function Install-RulesAndAgents {
    param([string]$SourceDir)
    $rulesSrc = Join-Path $SourceDir "templates\default.rules"
    $agentsSrc = Join-Path $SourceDir "templates\AGENTS.md"
    $rulesDir = Join-Path $CodexHome "rules"
    $rulesDest = Join-Path $rulesDir "default.rules"

    if (Test-Path $rulesSrc) {
        Invoke-Run "create $rulesDir" { New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null }
        Backup-File $rulesDest
        Invoke-Run "copy $rulesSrc to $rulesDest" { Copy-Item -Path $rulesSrc -Destination $rulesDest -Force }
        Write-Ok "Default rules installed"
    }

    if (Test-Path $agentsSrc) {
        $agentsDest = Join-Path $ProjectDir "AGENTS.md"
        if ((Test-Path $agentsDest) -and (-not $Force)) {
            Write-Warn "AGENTS.md already exists; keeping it. Use -Force to overwrite."
        } else {
            Backup-File $agentsDest
            Invoke-Run "copy $agentsSrc to $agentsDest" { Copy-Item -Path $agentsSrc -Destination $agentsDest -Force }
            Write-Ok "Project AGENTS.md installed"
        }
    }
}

function Update-PowerShellProfile {
    if ($SkipProfileUpdate) { return }
    $sourceLine = ". `"$PrivateEnvFile`""
    Invoke-Run "create PowerShell profile directory" { New-Item -ItemType Directory -Path (Split-Path $PROFILE) -Force | Out-Null }
    if ((Test-Path $PROFILE) -and ((Get-Content $PROFILE -Raw) -like "*$sourceLine*")) {
        Write-Ok "PowerShell profile already loads private env"
        return
    }
    Invoke-Run "append private env loader to PowerShell profile" { Add-Content -Path $PROFILE -Value "`n# Codex Bootstrap secrets`n$sourceLine" }
    Write-Ok "PowerShell profile configured: $PROFILE"
}

function Main {
    if ($Help) { Show-Help; return }
    Write-Banner
    Assert-EnvKey

    Write-Step "1/7" "Inspect system and bootstrap settings"
    Write-Info "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Info "Provider: $ProviderId"
    Write-Info "Provider env key: $ProviderEnvKey"
    Write-Info "Model: $Model"
    Write-Info "Reasoning effort: $ReasoningEffort"
    Write-Info "npm fallback registry: $NpmRegistry"
    Write-Info "Base URL: $BaseUrl"
    if ($Token) { Write-Info "API key: $(Mask-Secret $Token)" }

    Write-Step "2/7" "Load profile and template assets"
    $sourceDir = Get-SourceDir
    Load-Profile $sourceDir

    Write-Step "3/7" "Install or verify Codex CLI"
    Install-Codex

    Write-Step "4/7" "Write private API key"
    Write-PrivateEnv

    Write-Step "5/7" "Write Codex custom provider config"
    Write-CodexConfig

    Write-Step "6/7" "Install rules and project instructions"
    Install-RulesAndAgents $sourceDir

    Write-Step "7/7" "Ensure PowerShell loads private env"
    Update-PowerShellProfile

    Write-Ok "Codex bootstrap completed"
    Write-Info "Restart PowerShell or run: . `"$PrivateEnvFile`""
    Write-Info "Try: codex --search"
}

Main
