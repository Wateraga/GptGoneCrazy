<#
    WinSetup.ps1 — Modular Windows Hardening & Bootstrap Orchestrator
    Place this script in the root directory along with modules/, config.yaml, and WinSetup.py.
#>

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- Elevation Prompt ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Script is not running as Administrator. Relaunching with elevation..."
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- SHA256 Self-Check (trusted hashes in allowlist_hashes.txt) ---
$AllowlistFile = Join-Path $ScriptRoot "allowlist_hashes.txt"
if (-not (Test-Path $AllowlistFile)) {
    Write-Host "WARNING: No allowlist_hashes.txt found! Hash verification skipped."
} else {
    $trustedHashes = Get-Content $AllowlistFile
    $selfHash = Get-FileHash $PSCommandPath -Algorithm SHA256 | Select-Object -ExpandProperty Hash
    if ($trustedHashes -notcontains $selfHash) {
        Write-Error "Script hash mismatch! Exiting for safety."
        exit 1
    }
}

# --- Import Required Modules ---
$requiredModules = @('Powershell-Yaml', 'PSUpdate')
foreach ($mod in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Install-Module $mod -Force -Scope CurrentUser
    }
    Import-Module $mod -Force
}

# --- Load Config YAML ---
$configFile = Join-Path $ScriptRoot "config.yaml"
if (-not (Test-Path $configFile)) {
    Write-Error "Missing config.yaml! Exiting."
    exit 1
}
$config = Import-Yaml $configFile
$role = $config.role

# --- Import Phase Modules ---
Import-Module (Join-Path $ScriptRoot "modules\Preflight.psm1")
Import-Module (Join-Path $ScriptRoot "modules\Services.psm1")
Import-Module (Join-Path $ScriptRoot "modules\Firewall.psm1")
Import-Module (Join-Path $ScriptRoot "modules\Scoop.psm1")
Import-Module (Join-Path $ScriptRoot "modules\GitRepo.psm1")
Import-Module (Join-Path $ScriptRoot "modules\PythonHandoff.psm1")
Import-Module (Join-Path $ScriptRoot "modules\Reporting.psm1")

# --- Global Logging Setup ---
$Global:LogFile = "$env:USERPROFILE\Desktop\WinSetup_log.txt"
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")][string]$Type = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Type) {
        "INFO"  { Write-Host "[$timestamp] [+] $Message" -ForegroundColor Green }
        "WARN"  { Write-Host "[$timestamp] [!] $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "[$timestamp] [-] $Message" -ForegroundColor Red }
    }
    Add-Content -Path $Global:LogFile -Value "[$timestamp][$Type] $Message"
}

# --- Execute Phases in Order ---
trap {
    Write-Log "Unhandled error: $($_.Exception.Message)" "ERROR"
    exit 1
}

try {
    Preflight::Run -Config $config -Role $role
    Services::Run -Config $config -Role $role
    Firewall::Run -Config $config
    Scoop::Run -Config $config
    GitRepo::Run -Config $config
    PythonHandoff::Run -Config $config
    Reporting::Generate -Config $config
    Write-Log "All phases completed successfully." "INFO"
} catch {
    Write-Log "Critical error during execution: $($_.Exception.Message)" "ERROR"
    exit 1
}
