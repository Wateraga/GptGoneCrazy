# modules\Services.psm1

function Run {
    param(
        [Parameter(Mandatory=$true)][hashtable]$Config,
        [Parameter(Mandatory=$true)][string]$Role
    )

    Write-Log "=== [Services Phase: $Role] ===" "INFO"

    $disableList = $Config.services.$Role.disable
    $enableList = $Config.services.$Role.enable

    foreach ($svcPattern in $disableList) {
        $matches = Get-Service | Where-Object { $_.Name -like $svcPattern }
        foreach ($svc in $matches) {
            $before = $svc.Status
            try {
                Set-Service -Name $svc.Name -StartupType Disabled
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                $after = (Get-Service $svc.Name).Status
                Write-Log "Service $($svc.Name): $before -> $after (Disabled)" "INFO"
            } catch {
                Write-Log "Failed to disable $($svc.Name) ($before): $($_.Exception.Message)" "WARN"
            }
        }
    }
    foreach ($svcPattern in $enableList) {
        $matches = Get-Service | Where-Object { $_.Name -like $svcPattern }
        foreach ($svc in $matches) {
            $before = $svc.Status
            try {
                Set-Service -Name $svc.Name -StartupType Automatic
                Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
                $after = (Get-Service $svc.Name).Status
                Write-Log "Service $($svc.Name): $before -> $after (Enabled)" "INFO"
            } catch {
                Write-Log "Failed to enable $($svc.Name) ($before): $($_.Exception.Message)" "WARN"
            }
        }
    }
}
Export-ModuleMember -Function Run
