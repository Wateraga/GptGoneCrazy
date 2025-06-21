<#
.SYNOPSIS
Windows 11 Privacy and Security Setup Script

.DESCRIPTION
Applies common privacy and security configuration. Requires
Administrator privileges.
#>

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run with administrator privileges."
    exit 1
}

function Set-RegValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [Microsoft.Win32.RegistryValueKind]$Type = [Microsoft.Win32.RegistryValueKind]::DWord
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
}

# Disable telemetry collection
Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0

# Disable advertising ID
Set-RegValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'DisabledByGroupPolicy' 1

# Disable location services
Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 1

# Disable error reporting
Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1

# Enable firewall on all profiles
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True

# Enable Windows Defender PUA protection
Set-MpPreference -PUAProtection 1

Write-Host 'Privacy and security settings applied. A system restart may be required.'

