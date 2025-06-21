<#
.SYNOPSIS
    Fully automates Windows Update, handling multiple reboots and cleanup.
.DESCRIPTION
    - Installs all pending updates.
    - Handles reboot as needed.
    - Re-invokes itself at logon until updates are fully complete.
    - Cleans up scheduled tasks and script remnants.
.NOTES
    Requires PowerShell 5+ and administrative privileges.
#>

#--- CONFIGURATION ---
$TaskName = "AutoWinUpdate_Complete"
$ScriptPath = $MyInvocation.MyCommand.Path

function Add-Log {
    param($msg)
    Write-Host "[$(Get-Date -f 'yyyy-MM-dd HH:mm:ss')] $msg"
}

function Schedule-SelfAtLogon {
    Add-Log "Scheduling script to resume at next logon..."
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId "BUILTIN\Administrators" -RunLevel Highest
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
}

function Remove-SelfSchedule {
    Add-Log "Removing scheduled task if exists..."
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
}

function Is-RebootPending {
    # Checks common locations for reboot requirements
    $pending = $false

    $rebootKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
    )
    foreach ($key in $rebootKeys) {
        if (Test-Path $key) { $pending = $true }
    }
    return $pending
}

function Run-WindowsUpdate {
    Add-Log "Importing Windows Update module..."
    Import-Module PSWindowsUpdate -ErrorAction SilentlyContinue

    # Install PSWindowsUpdate if not present (downloads from PSGallery)
    if (-not (Get-Command Get-WindowsUpdate -ErrorAction SilentlyContinue)) {
        Add-Log "PSWindowsUpdate module not found, installing..."
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
        Import-Module PSWindowsUpdate
    }

    # Main update loop
    Add-Log "Searching for available updates..."
    $updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot -Install -AutoReboot
    Add-Log "Update command issued, checking for further actions."
}

#--- MAIN LOGIC ---
Add-Log "=== Windows Automated Update Cycle Start ==="

# Ensure script is scheduled for post-reboot if not already
if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
    Schedule-SelfAtLogon
}

# Run Windows Update
Run-WindowsUpdate

# Check if a reboot is required (wait a bit for detection)
Start-Sleep 15
if (Is-RebootPending) {
    Add-Log "Reboot is pending. System will reboot in 15 seconds..."
    Start-Sleep 15
    Restart-Computer -Force
    exit
}

# Double-check for remaining updates
Add-Log "Re-checking for remaining updates..."
$remaining = Get-WindowsUpdate -AcceptAll -IgnoreReboot -Install -AutoReboot -ErrorAction SilentlyContinue

if ($remaining) {
    Add-Log "Further updates found, will repeat after reboot if required."
    if (Is-RebootPending) {
        Restart-Computer -Force
        exit
    }
} else {
    Add-Log "No further updates found. Cleaning up..."
    Remove-SelfSchedule
    Add-Log "=== Windows is up to date and cleanup is complete. ==="
}

# Optionally delete this script after run (uncomment if desired)
# Remove-Item -Path $ScriptPath -Force

exit 0
