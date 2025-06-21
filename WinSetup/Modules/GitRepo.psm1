# modules\GitRepo.psm1

function Run {
    param([Parameter(Mandatory=$true)][hashtable]$Config)

    Write-Log "=== [GitRepo Phase] ===" "INFO"

    $repoUrl = $Config.git.repo
    $branch = $Config.git.branch
    $allowlist = $Config.git.allowlist
    $localRepo = "$env:USERPROFILE\WinSetupRepo"

    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        Write-Log "Git not installed! Skipping repo phase." "ERROR"
        return
    }

    if (-not (Test-Path $localRepo)) {
        Write-Log "Cloning repository $repoUrl to $localRepo (branch: $branch)..." "INFO"
        git clone --branch $branch $repoUrl $localRepo
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to clone repository." "ERROR"
            exit 1
        }
    } else {
        Write-Log "Updating existing repository at $localRepo (branch: $branch)..." "INFO"
        Push-Location $localRepo
        git checkout $branch
        git pull
        Pop-Location
    }

    # Verify commit hash (tamper prevention)
    Push-Location $localRepo
    $commit = git rev-parse HEAD
    Pop-Location

    if ($allowlist -and ($allowlist -notcontains $commit)) {
        Write-Log "Repo commit $commit NOT in allowlist! Exiting for safety." "ERROR"
        exit 1
    }
    Write-Log "Repo commit $commit verified in allowlist." "INFO"
}
Export-ModuleMember -Function Run
