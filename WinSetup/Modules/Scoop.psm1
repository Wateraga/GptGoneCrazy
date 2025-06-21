# modules\Scoop.psm1

function Install-Scoop-App {
    param(
        [string]$App,
        [ref]$JobResults
    )
    try {
        scoop install $App -g | Out-Null
        Write-Log "Scoop installed: $App" "INFO"
        $JobResults.Value[$App] = "Success"
    } catch {
        Write-Log "Scoop app failed to install: $App ($($_.Exception.Message))" "WARN"
        $JobResults.Value[$App] = "Failed"
    }
}

function Run {
    param([Parameter(Mandatory=$true)][hashtable]$Config)

    Write-Log "=== [Scoop Phase] ===" "INFO"

    # Auto-update Scoop and buckets
    scoop update
    scoop update *

    $Buckets = $Config.buckets
    $Apps = $Config.apps.required
    $OptionalApps = @()
    if ($Config.apps.optional) {
        $OptionalApps = $Config.apps.optional
    }

    # Add buckets
    foreach ($bucket in $Buckets) {
        try {
            scoop bucket add $bucket | Out-Null
            Write-Log "Scoop bucket added: $bucket" "INFO"
        } catch {
            Write-Log "Failed to add bucket $bucket: $($_.Exception.Message)" "WARN"
        }
    }

    # Prompt for optional apps
    foreach ($oapp in $OptionalApps) {
        $response = Read-Host "Install optional app '$oapp'? [y/N]"
        if ($response -match '^(y|yes)$') {
            $Apps += $oapp
        }
    }

    # Parallel install for all required (and chosen optional) apps
    $JobResults = @{}
    $jobs = @()
    foreach ($app in $Apps) {
        $jobs += Start-Job -ScriptBlock ${function:Install-Scoop-App} -ArgumentList $app, ([ref]$JobResults)
    }
    Wait-Job $jobs
    foreach ($job in $jobs) { Receive-Job $job | Out-Null }

    # Verification: Check binaries
    foreach ($app in $Apps) {
        try {
            $bin = scoop which $app
            if ($bin) {
                Write-Log "Verified $app installed at $bin" "INFO"
            } else {
                Write-Log "Failed to verify $app binary (not in PATH/shims?)" "WARN"
            }
        } catch {
            Write-Log "Error verifying $app: $($_.Exception.Message)" "WARN"
        }
    }
}
Export-ModuleMember -Function Run
