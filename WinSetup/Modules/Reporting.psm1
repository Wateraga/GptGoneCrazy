# modules\Reporting.psm1

function Generate {
    param([Parameter(Mandatory=$true)][hashtable]$Config)

    Write-Log "=== [Reporting Phase] ===" "INFO"

    $logFile = $Global:LogFile
    $summaryReport = "$env:USERPROFILE\Desktop\WinSetup_Summary_$(Get-Date -Format yyyyMMdd_HHmmss).md"
    $allLogLines = Get-Content $logFile

    # Markdown summary
    $md = @()
    $md += "# WinSetup Run Summary"
    $md += "Date: $(Get-Date)"
    $md += ""
    $md += "## Role: $($Config.role)"
    $md += ""
    $md += "## Major Phases:"
    $md += "- Preflight (system info, snapshot, checks)"
    $md += "- Service hardening"
    $md += "- Firewall lockdown and diff"
    $md += "- Scoop/bucket/app install"
    $md += "- Git repo sync and verification"
    $md += "- Python automation handoff"
    $md += ""
    $md += "## Errors and Warnings"
    foreach ($line in $allLogLines) {
        if ($line -match '\[WARN\]|\[ERROR\]') { $md += "* $line" }
    }
    $md += ""
    $md += "## End of Run"

    $md | Out-File $summaryReport
    Write-Log "Markdown summary saved to $summaryReport" "INFO"

    # Event Log summary (optional, can be expanded)
    try {
        $summaryStr = $md -join "`n"
        Write-EventLog -LogName Application -Source "WinSetup" -EntryType Information -EventId 10001 -Message $summaryStr.Substring(0,[Math]::Min(8000, $summaryStr.Length))
        Write-Log "Event Log entry written." "INFO"
    } catch {
        Write-Log "Could not write Event Log entry (may require event source registration)." "WARN"
    }

    # Reboot prompt if needed
    $needReboot = $allLogLines | Select-String "require(s)? reboot|reboot required|restart needed"
    if ($needReboot) {
        Write-Log "A reboot is recommended after these changes. Prompting user..." "INFO"
        $resp = Read-Host "Reboot now? [y/N]"
        if ($resp -match '^(y|yes)$') {
            Restart-Computer
        }
    }
}
Export-ModuleMember -Function Generate
