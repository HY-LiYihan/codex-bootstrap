# Codex++ addon bootstrap for Windows PowerShell.
param(
    [string]$Repo = $(if ($env:CODEX_PLUS_PLUS_REPO) { $env:CODEX_PLUS_PLUS_REPO } else { "BigPizzaV3/CodexPlusPlus" }),
    [string]$Ref = $(if ($env:CODEX_PLUS_PLUS_REF) { $env:CODEX_PLUS_PLUS_REF } else { "v1.0.7" }),
    [string]$InstallRoot = $(if ($env:CODEX_PLUS_PLUS_INSTALL_ROOT) { $env:CODEX_PLUS_PLUS_INSTALL_ROOT } else { "" }),
    [string]$PipArgs = $(if ($env:CODEX_PLUS_PLUS_PIP_ARGS) { $env:CODEX_PLUS_PLUS_PIP_ARGS } else { "" }),
    [string]$ProviderSync = $(if ($env:CODEX_PLUS_PLUS_PROVIDER_SYNC) { $env:CODEX_PLUS_PLUS_PROVIDER_SYNC } else { "0" }),
    [switch]$SkipSetup = $($env:CODEX_PLUS_PLUS_SKIP_SETUP -eq '1'),
    [switch]$Launch = $($env:CODEX_PLUS_PLUS_LAUNCH -eq '1'),
    [switch]$DryRun,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$PythonExe = ""

function Write-Step { param([string]$Step,[string]$Message) Write-Host ""; Write-Host "[$Step] " -NoNewline -ForegroundColor Magenta; Write-Host $Message -ForegroundColor White }
function Write-Ok { param([string]$Message) Write-Host "[OK] " -NoNewline -ForegroundColor Green; Write-Host $Message }
function Write-Info { param([string]$Message) Write-Host "[INFO] " -NoNewline -ForegroundColor Blue; Write-Host $Message }
function Write-Warn { param([string]$Message) Write-Host "[WARN] " -NoNewline -ForegroundColor Yellow; Write-Host $Message }
function Fail { param([string]$Message) Write-Host "[ERROR] " -NoNewline -ForegroundColor Red; Write-Host $Message; exit 1 }

function Show-Help {
    Write-Host @"
Codex++ Addon Bootstrap

Usage:
  `$env:AGENT='codexplusplus'; irm https://raw.githubusercontent.com/HY-LiYihan/agent-bootstrap/stable/install.ps1 | iex

Options:
  -Repo OWNER/REPO      Upstream Codex++ repo (default: BigPizzaV3/CodexPlusPlus)
  -Ref REF             Upstream Codex++ git ref/tag (default: v1.0.7)
  -InstallRoot DIR     Pass install root to Codex++ setup
  -SkipSetup           Install Python package only; do not create app/shortcut
  -ProviderSync VALUE  Set 1/true/yes/on to enable provider metadata sync
  -Launch              Launch Codex++ after install/setup
  -DryRun              Print intended commands without running them

Environment:
  CODEX_PLUS_PLUS_REF           Upstream git ref/tag (default: v1.0.7)
  CODEX_PLUS_PLUS_REPO          Upstream repo (default: BigPizzaV3/CodexPlusPlus)
  CODEX_PLUS_PLUS_INSTALL_ROOT  Optional setup install root
  CODEX_PLUS_PLUS_PIP_ARGS      Extra pip args
  CODEX_PLUS_PLUS_PROVIDER_SYNC Set 1 to enable provider metadata sync
  CODEX_PLUS_PLUS_SKIP_SETUP    Set 1 to skip setup
  CODEX_PLUS_PLUS_LAUNCH        Set 1 to launch after setup
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

function Test-PythonVersion {
    param([string]$Command, [string[]]$PrefixArgs = @())
    try {
        $code = "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)"
        $allArgs = @($PrefixArgs + @('-c', $code))
        & $Command @allArgs 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Find-Python {
    $candidates = @(
        @{ Command = 'py'; Args = @('-3.13') },
        @{ Command = 'py'; Args = @('-3.12') },
        @{ Command = 'py'; Args = @('-3.11') },
        @{ Command = 'python3'; Args = @() },
        @{ Command = 'python'; Args = @() }
    )
    foreach ($candidate in $candidates) {
        if (-not (Get-Command $candidate.Command -ErrorAction SilentlyContinue)) { continue }
        if (Test-PythonVersion -Command $candidate.Command -PrefixArgs $candidate.Args) {
            $script:PythonExe = ($candidate.Command + $(if ($candidate.Args.Count -gt 0) { ' ' + ($candidate.Args -join ' ') } else { '' }))
            return @{ Command = $candidate.Command; Args = $candidate.Args }
        }
    }
    return $null
}

function Invoke-Python {
    param([hashtable]$Python, [string[]]$Args)
    $cmd = $Python.Command
    $allArgs = @($Python.Args + $Args)
    & $cmd @allArgs
}

function Ensure-Pip {
    param([hashtable]$Python)
    Invoke-Python $Python @('-m', 'pip', '--version') *> $null
    if ($LASTEXITCODE -eq 0) { return }
    Write-Warn "pip is missing; trying ensurepip"
    Invoke-Run "python -m ensurepip --upgrade" { Invoke-Python $Python @('-m', 'ensurepip', '--upgrade') }
    Invoke-Python $Python @('-m', 'pip', '--version') *> $null
    if ($LASTEXITCODE -ne 0) { Fail "pip is required for Codex++ install" }
}

function Install-Package {
    param([hashtable]$Python)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "git is required to install Codex++ from GitHub" }
    Ensure-Pip $Python
    $packageUrl = "git+https://github.com/$Repo.git@$Ref"
    $pipArgsList = @('-m', 'pip', 'install', '--user', '--upgrade')
    if ($PipArgs) { $pipArgsList += ($PipArgs -split '\s+') }
    $pipArgsList += $packageUrl
    Invoke-Run "python -m pip install --user --upgrade $packageUrl" { Invoke-Python $Python $pipArgsList }
}

function Invoke-CodexPlusPlusSetup {
    param([hashtable]$Python)
    if ($SkipSetup) { Write-Info "Skipping Codex++ setup"; return }
    $args = @('-m', 'codex_session_delete', 'setup')
    if ($InstallRoot) { $args += @('--install-root', $InstallRoot) }
    Invoke-Run "python -m codex_session_delete setup" { Invoke-Python $Python $args }
}

function Set-CodexPlusPlusFeatures {
    $enabled = $ProviderSync -match '^(1|true|yes|on)$'
    $settingsDir = Join-Path $env:USERPROFILE ".codex-session-delete"
    $settingsFile = Join-Path $settingsDir "settings.json"
    $settings = @{ providerSyncEnabled = $enabled }
    Invoke-Run "write $settingsFile with providerSyncEnabled=$enabled" {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        [System.IO.File]::WriteAllText($settingsFile, ($settings | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))
    }
}

function Invoke-CodexPlusPlusLaunch {
    param([hashtable]$Python)
    if (-not $Launch) { return }
    Invoke-Run "python -m codex_session_delete launch" { Invoke-Python $Python @('-m', 'codex_session_delete', 'launch') }
}

function Main {
    if ($Help) { Show-Help; return }
    Write-Host ""
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "| Codex++ Addon Bootstrap                         |" -ForegroundColor Cyan
    Write-Host "| external Codex App enhancer                     |" -ForegroundColor Cyan
    Write-Host "+--------------------------------------------------+" -ForegroundColor Cyan

    Write-Step "1/6" "Inspect Codex++ settings"
    Write-Info "Upstream: $Repo@$Ref"
    if ($InstallRoot) { Write-Info "Install root: $InstallRoot" }
    Write-Info "Provider sync: $ProviderSync"

    Write-Step "2/6" "Find Python 3.11+"
    $python = Find-Python
    if (-not $python) { Fail "Python 3.11+ is required. Install Python 3.11 or newer, then rerun." }
    $pythonCommand = $python.Command
    $version = (& $pythonCommand @($python.Args + @('--version')) 2>&1)
    Write-Ok "Python: $version ($PythonExe)"

    Write-Step "3/6" "Install Codex++ from GitHub"
    Install-Package $python
    Write-Ok "Codex++ Python package installed"

    Write-Step "4/6" "Create Codex++ launcher"
    Invoke-CodexPlusPlusSetup $python
    Write-Ok "Codex++ setup step completed"

    Write-Step "5/6" "Configure Codex++ features"
    Set-CodexPlusPlusFeatures
    Write-Ok "Codex++ feature settings ready"

    Write-Step "6/6" "Finish"
    Invoke-CodexPlusPlusLaunch $python
    Write-Ok "Codex++ addon ready"
    Write-Info "Launch later with: $PythonExe -m codex_session_delete launch"
    Write-Info "Update later with: $PythonExe -m codex_session_delete update"
}

Main
