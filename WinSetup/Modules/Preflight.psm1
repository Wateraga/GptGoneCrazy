# modules\Preflight.psm1

function Run {
    param(
        [Parameter(Mandatory=$true)][hashtable]$Config,
        [Parameter(Mandatory=$true)][string]$Role
    )

    Write-Log "=== [Preflight Phase] ===" "INFO"

    # System Info and Snapshots
    try {
        $hwInfo = Get-ComputerInfo | Select-Object OsName, WindowsProductName, OsVersion, CsTotalPhysicalMemory
        $hwOut = "$env:USERPROFILE\Desktop\sysinfo_$(Get-Date -Format yyyyMMdd_HHmmss).txt"
        $hwInfo | Out-File $hwOut
        Write-Log "System info snapshot written to $hwOut" "INFO"
    } catch {
        Write-Log "Failed to capture system info." "WARN"
    }

    # Disk Space Check
    $freeGB = (Get-PSDrive C).Free / 1GB
    if ($freeGB -lt 10) {
        Write-Log "WARNING: Less than 10GB free disk space!" "WARN"
    }

    # Connectivity Check
    $testSites = @("github.com", "scoop.sh", "google.com")
    foreach ($site in $testSites) {
        try {
            if (Test-Connection $site -Count 1 -Quiet) {
                Write-Log "Connectivity to $site: OK" "INFO"
            } else {
                Write-Log "No connectivity to $site" "WARN"
            }
        } catch {
            Write-Log "Error pinging $site" "WARN"
        }
    }

    # Registry Snapshot
    try {
        $regBackup = "$env:USERPROFILE\Desktop\registry_backup_$(Get-Date -Format yyyyMMdd_HHmmss).reg"
        reg export HKLM $regBackup /y | Out-Null
        Write-Log "Registry exported to $regBackup" "INFO"
    } catch {
        Write-Log "Registry export failed." "WARN"
    }

    # Service Snapshot
    try {
        $svcBackup = "$env:USERPROFILE\Desktop\services_backup_$(Get-Date -Format yyyyMMdd_HHmmss).txt"
        Get-Service | Select-Object Name,Status,StartType | Out-File $svcBackup
        Write-Log "Services snapshot written to $svcBackup" "INFO"
    } catch {
        Write-Log "Service snapshot failed." "WARN"
    }

    # Create Restore Point
    try {
        Checkpoint-Computer -Description "WinSetup Preflight Restore" -RestorePointType "MODIFY_SETTINGS"
        Write-Log "Restore point created." "INFO"
    } catch {
        Write-Log "Restore point not created (unsupported or policy)." "WARN"
    }
}
Export-ModuleMember -Function Run
