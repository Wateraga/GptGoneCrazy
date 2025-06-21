# modules\Firewall.psm1

function Block-Telemetry {
    # Known MS telemetry/advertising domains/IPs (expand as needed)
    $telemetryHosts = @(
        "settings-win.data.microsoft.com",
        "vortex-win.data.microsoft.com",
        "telemetry.microsoft.com",
        "telecommand.telemetry.microsoft.com",
        "watson.telemetry.microsoft.com"
    )
    foreach ($host in $telemetryHosts) {
        try {
            New-NetFirewallRule -DisplayName "Block Telemetry $host" -Direction Outbound -Action Block -RemoteAddress $host -Profile Any -ErrorAction SilentlyContinue
            Write-Log "Blocked telemetry/advertising: $host" "INFO"
        } catch {
            Write-Log "Failed to block $host: $($_.Exception.Message)" "WARN"
        }
    }
}

function Snapshot-Firewall {
    param([string]$Path)
    netsh advfirewall export $Path | Out-Null
    Write-Log "Firewall rule snapshot saved to $Path" "INFO"
}

function Diff-Firewall {
    param([string]$Before, [string]$After)
    $beforeContent = Get-Content $Before
    $afterContent = Get-Content $After
    $diff = Compare-Object $beforeContent $afterContent
    if ($diff) {
        $diffPath = "$env:USERPROFILE\Desktop\firewall_diff_$(Get-Date -Format yyyyMMdd_HHmmss).txt"
        $diff | Out-File $diffPath
        Write-Log "Firewall rule diff saved to $diffPath" "INFO"
    } else {
        Write-Log "No firewall changes detected (diff empty)." "INFO"
    }
}

function Run {
    param([Parameter(Mandatory=$true)][hashtable]$Config)

    Write-Log "=== [Firewall Phase] ===" "INFO"

    $fwBefore = "$env:USERPROFILE\Desktop\firewall_before.wfw"
    $fwAfter = "$env:USERPROFILE\Desktop\firewall_after.wfw"
    Snapshot-Firewall -Path $fwBefore

    # Set default profile (defense in depth)
    Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultInboundAction Block -DefaultOutboundAction Allow

    # Detect trusted subnet (if auto, else use config)
    $trustedSubnet = $Config.firewall.trusted_subnet
    if ($trustedSubnet -eq "auto") {
        $adapter = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Dhcp" -and $_.IPAddress -notlike "169.254*" } | Select-Object -First 1
        if ($adapter) {
            $ip = $adapter.IPAddress
            $trustedSubnet = $ip.Substring(0, $ip.LastIndexOf('.') + 1) + "0/24"
            Write-Log "Auto-detected trusted subnet: $trustedSubnet" "INFO"
        } else {
            $trustedSubnet = "192.168.1.0/24"
            Write-Log "Could not auto-detect subnet, using fallback: $trustedSubnet" "WARN"
        }
    }
    try {
        if (Get-NetFirewallRule -DisplayName "Allow Trusted Subnet" -ErrorAction SilentlyContinue) {
            Remove-NetFirewallRule -DisplayName "Allow Trusted Subnet" | Out-Null
        }
        New-NetFirewallRule -DisplayName "Allow Trusted Subnet" -Direction Inbound -Action Allow -RemoteAddress $trustedSubnet -Profile Domain,Private
        Write-Log "Firewall rule added for trusted subnet: $trustedSubnet" "INFO"
    } catch {
        Write-Log "Failed to add trusted subnet firewall rule: $($_.Exception.Message)" "ERROR"
    }

    # Telemetry/advertising block if enabled
    if ($Config.firewall.block_telemetry -eq $true) {
        Block-Telemetry
    }

    # Save and diff after rules
    Snapshot-Firewall -Path $fwAfter
    if ($Config.firewall.detailed_diff -eq $true) {
        Diff-Firewall -Before $fwBefore -After $fwAfter
    }
}
Export-ModuleMember -Function Run
