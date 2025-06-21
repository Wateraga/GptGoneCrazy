# modules\PythonHandoff.psm1

function Run {
    param([Parameter(Mandatory=$true)][hashtable]$Config)

    Write-Log "=== [Python Handoff Phase] ===" "INFO"

    $python = scoop which python
    if (-not $python) {
        Write-Log "Python not found in Scoop shims. Aborting Python handoff." "ERROR"
        return
    }

    # Gather context: role, subnet, config file
    $role = $Config.role
    $configFile = (Join-Path $PSScriptRoot "..\config.yaml")
    $subnet = ""
    # Try to get subnet from previous firewall phase (otherwise autodetect)
    try {
        $adapter = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Dhcp" -and $_.IPAddress -notlike "169.254*" } | Select-Object -First 1
        if ($adapter) {
            $ip = $adapter.IPAddress
            $subnet = $ip.Substring(0, $ip.LastIndexOf('.') + 1) + "0/24"
        }
    } catch {
        $subnet = "192.168.1.0/24"
    }

    $pythonScript = (Join-Path $PSScriptRoot "..\WinSetup.py")

    $args = @("--role", "$role", "--subnet", "$subnet", "--config", "$configFile")

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $python
    $processInfo.Arguments = "$pythonScript $($args -join ' ')"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $processInfo
    [void]$proc.Start()

    Write-Log "Started Python: $($processInfo.FileName) $($processInfo.Arguments)" "INFO"

    # Real-time log streaming
    while (-not $proc.HasExited) {
        $outLine = $proc.StandardOutput.ReadLine()
        if ($outLine) { Write-Log "[PY] $outLine" "INFO" }
        $errLine = $proc.StandardError.ReadLine()
        if ($errLine) { Write-Log "[PY-ERR] $errLine" "ERROR" }
        Start-Sleep -Milliseconds 100
    }
    # Final drain
    while (($line = $proc.StandardOutput.ReadLine()) -ne $null) {
        Write-Log "[PY] $line" "INFO"
    }
    while (($line = $proc.StandardError.ReadLine()) -ne $null) {
        Write-Log "[PY-ERR] $line" "ERROR"
    }

    # Handle errors
    if ($proc.ExitCode -ne 0) {
        Write-Log "Python script failed (exit code $($proc.ExitCode)). Marker written for safe retry." "ERROR"
        New-Item "$env:USERPROFILE\python_failed.marker" -Force
    }
}
Export-ModuleMember -Function Run
