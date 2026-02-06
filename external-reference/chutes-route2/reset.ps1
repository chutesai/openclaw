# Chutes x OpenClaw Reset Script (Windows)
# Use this to completely wipe OpenClaw and all Chutes integration data for a fresh start.

$ErrorActionPreference = "Continue"

function Log-Info($msg) { Write-Host "info: $msg" -ForegroundColor Cyan }
function Log-Success($msg) { Write-Host "success: $msg" -ForegroundColor Green }
function Log-Warn($msg) { Write-Host "warning: $msg" -ForegroundColor Yellow }

Write-Host "--- FULL SYSTEM RESET ---" -ForegroundColor Red
Log-Info "This will kill all OpenClaw processes, uninstall the global CLI, and wipe all local data/secrets."

# 1. Kill any running OpenClaw processes
Log-Info "Killing running OpenClaw processes..."
$procs = if ($PSVersionTable.PSVersion.Major -ge 7) {
    Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*openclaw*" }
} else {
    Get-CimInstance Win32_Process -Filter "Name = 'node.exe' AND CommandLine LIKE '%openclaw%'" | ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
}
if ($procs) { $procs | Stop-Process -Force -Confirm:$false }
Start-Sleep -s 1

# 2. Uninstall OpenClaw globally
Log-Info "Uninstalling OpenClaw globally..."
npm uninstall -g openclaw 2>$null

# 3. Wipe config and data
Log-Info "Wiping configuration and local data ($HOME\.openclaw)..."
if (Test-Path (Join-Path $HOME ".openclaw")) {
    Remove-Item (Join-Path $HOME ".openclaw") -Recurse -Force -ErrorAction SilentlyContinue
}

# 4. Clear environment variables
Log-Info "Clearing Chutes environment variables..."
$env:CHUTES_API_KEY = $null
$env:CHUTES_OAUTH_TOKEN = $null

# 5. Remove scheduled model update jobs (crontab-compatible)
Log-Info "Removing scheduled model update jobs from crontab..."
if (Get-Command crontab -ErrorAction SilentlyContinue) {
    $current = crontab -l 2>$null | Where-Object { $_ -notlike "*update_chutes_models.ps1*" }
    if ($current) {
        $current | crontab -
    } else {
        # If no other jobs remain, clear crontab
        "" | crontab - 2>$null
    }
    Log-Success "Crontab: Cleaned"
}

# 6. Final status check
Write-Host ""
Write-Host "--- RESET COMPLETE ---" -ForegroundColor Green
if (!(Get-Command openclaw -ErrorAction SilentlyContinue)) {
    Log-Success "Binary: Deleted"
} else {
    Log-Warn "Binary: Still found. You may need to manually uninstall it."
}

if (!(Test-Path (Join-Path $HOME ".openclaw"))) {
    Log-Success "Config dir: Deleted"
} else {
    Log-Warn "Config dir: STILL EXISTS at $HOME\.openclaw"
}

Write-Host ""
Log-Info "You are now starting with a 100% clean slate."
Log-Info "Run './init.ps1' to start the fresh onboarding journey."
