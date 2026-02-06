# Chutes x OpenClaw Bootstrap Script (Windows)
# Instant onboarding for Chutes-powered OpenClaw
# Usage: curl -fsSL https://chutes.ai/openclaw/init.ps1 | powershell -ExecutionPolicy Bypass -File -

$ErrorActionPreference = "Stop"

# Handle --no-color flag
$useColor = $true
foreach ($arg in $args) {
    if ($arg -eq "--no-color") {
        $useColor = $false
        break
    }
}

# Constants
$CHUTES_BASE_URL = "https://llm.chutes.ai/v1"
$CHUTES_DEFAULT_MODEL_REF = "chutes/zai-org/GLM-4.7-TEE"
$CHUTES_FAST_MODEL_REF = "chutes/zai-org/GLM-4.7-Flash"
$GATEWAY_PORT = 18789

# Helper functions
function Log-Info($msg) { 
    if ($useColor) { Write-Host "info: $msg" -ForegroundColor Cyan }
    else { Write-Host "info: $msg" }
}
function Log-Success($msg) { 
    if ($useColor) { Write-Host "success: $msg" -ForegroundColor Green }
    else { Write-Host "success: $msg" }
}
function Log-Warn($msg) { 
    if ($useColor) { Write-Host "warning: $msg" -ForegroundColor Yellow }
    else { Write-Host "warning: $msg" }
}
function Log-Error($msg) { 
    if ($useColor) { Write-Host "error: $msg" -ForegroundColor Red }
    else { Write-Host "error: $msg" }
    exit 1 
}

function Check-NodeVersion {
    Log-Info "Checking Node.js and npm version..."
    if (!(Get-Command node -ErrorAction SilentlyContinue)) {
        Log-Error "Node.js is not installed. OpenClaw requires Node.js 22+. Visit https://nodejs.org to install it."
    }
    if (!(Get-Command npm -ErrorAction SilentlyContinue)) {
        Log-Error "npm is not installed. OpenClaw requires npm for global installation. Please install Node.js which includes npm."
    }
    $nodeVer = node -v
    $major = [int]($nodeVer -replace 'v', '' -split '\.')[0]
    if ($major -lt 22) { Log-Error "Node.js version $nodeVer is too old. Need Node.js 22+." }
    Log-Success "Node.js version $nodeVer OK."
}

function Check-OpenClawInstalled {
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        try { openclaw --version | Out-Null; return $true } catch { return $false }
    }
    return $false
}

function Install-OpenClaw {
    Log-Info "Installing OpenClaw globally..."
    npm uninstall -g openclaw 2>$null
    npm install -g openclaw@latest long@latest
    if (!(Check-OpenClawInstalled)) { Log-Error "Failed to verify OpenClaw installation." }
    Log-Success "OpenClaw installed."
}

function Seed-InitialConfig {
    if (!(Test-Path (Join-Path $HOME ".openclaw\openclaw.json"))) {
        Log-Info "Initializing OpenClaw config..."
        openclaw onboard --non-interactive --accept-risk --auth-choice skip 2>$null
    }
    $mode = openclaw config get gateway.mode 2>$null
    if ($mode -ne "local" -and $mode -ne "remote") {
        openclaw config set gateway.mode local 2>$null
    }
}

function Add-ChutesAuth {
    Log-Info "Checking Chutes authentication..."
    $status = openclaw models status --json 2>$null | ConvertFrom-Json
    $hasAuth = $false
    if ($status.auth.providers) {
        foreach ($p in $status.auth.providers) {
            if ($p.provider -eq "chutes" -and $p.profiles.count -gt 0) { $hasAuth = $true; break }
        }
    }
    if ($status.auth.shellEnvFallback.appliedKeys -contains "CHUTES_API_KEY") { $hasAuth = $true }

    if ($hasAuth) { Log-Success "Chutes authentication already configured."; return }

    if ($env:CHUTES_API_KEY) {
        Log-Info "Using CHUTES_API_KEY from environment."
        $env:CHUTES_API_KEY | openclaw models auth paste-token --provider chutes 2>$null
    } else {
        Log-Info "Redirecting to OpenClaw's official auth helper..."
        # Read token from the console (works even when script is piped)
        $secureToken = Read-Host -Prompt "Paste token for chutes" -AsSecureString
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $plainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        $plainToken | openclaw models auth paste-token --provider chutes 2>$null
        Write-Host -NoNewline "$([char]27)[12A$([char]27)[J"
    }
    Log-Success "Chutes authentication added."
}

function Start-OnboardingWithGuard {
    $onboardLog = Join-Path $env:TEMP "openclaw-onboard.log"
    $onboardFlag = Join-Path $env:TEMP "openclaw-onboard.guard"
    Remove-Item $onboardLog -Force -ErrorAction SilentlyContinue
    Remove-Item $onboardFlag -Force -ErrorAction SilentlyContinue

    $transcriptStarted = $false
    try {
        Start-Transcript -Path $onboardLog -Append | Out-Null
        $transcriptStarted = $true
    } catch {}

    $proc = $null
    try {
        $proc = Start-Process openclaw -ArgumentList "onboard --auth-choice skip --skip-ui" -NoNewWindow -PassThru
    } catch {
        openclaw onboard --auth-choice skip --skip-ui
        if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch {} }
        return
    }

    $guard = Start-Job -ScriptBlock {
        param($logPath, $pid, $flagPath)
        $elapsed = 0
        $maxWait = 3600
        while ($elapsed -lt $maxWait) {
            if (-not (Get-Process -Id $pid -ErrorAction SilentlyContinue)) { return }
            if (Test-Path $logPath) {
                try {
                    $tail = Get-Content -Path $logPath -Tail 200 -ErrorAction SilentlyContinue
                    if ($tail -match "Onboarding complete.") {
                        Start-Sleep -Seconds 1
                        if (Get-Process -Id $pid -ErrorAction SilentlyContinue) {
                            "killed" | Set-Content -Path $flagPath -Force
                            Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                        }
                        return
                    }
                } catch {}
            }
            Start-Sleep -Seconds 1
            $elapsed++
        }
    } -ArgumentList $onboardLog, $proc.Id, $onboardFlag

    $proc.WaitForExit()
    $exitCode = $proc.ExitCode

    if ($guard) { Stop-Job $guard -ErrorAction SilentlyContinue; Remove-Job $guard -ErrorAction SilentlyContinue }
    if ($transcriptStarted) { try { Stop-Transcript | Out-Null } catch {} }

    if ($exitCode -ne 0) {
        $completed = $false
        if (Test-Path $onboardFlag) {
            $completed = $true
        } elseif (Test-Path $onboardLog) {
            try {
                $content = Get-Content -Path $onboardLog -Raw -ErrorAction SilentlyContinue
                if ($content -match "Onboarding complete.") { $completed = $true }
            } catch {}
        }
        if ($completed) {
            Log-Info "Onboarding complete. Continuing setup..."
            return
        }
        throw "Onboarding exited with code $exitCode."
    }
}

function Apply-AtomicConfig {
    Log-Info "Fetching latest model list from Chutes API..."
    $modelsJson = node -e @"
async function run() {
  try {
    const res = await fetch('https://llm.chutes.ai/v1/models');
    if (!res.ok) throw new Error('API request failed');
    const data = await res.json();
    const mapped = data.data.map(m => ({
      id: m.id,
      name: m.id,
      reasoning: m.supported_features?.includes('reasoning') || false,
      input: (m.input_modalities || ['text']).filter(i => i === 'text' || i === 'image'),
      cost: { input: m.pricing?.prompt || 0, output: m.pricing?.completion || 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: m.context_length || 128000,
      maxTokens: m.max_output_length || 4096
    }));
    console.log(JSON.stringify(mapped));
  } catch (e) { process.exit(1); }
}
run();
"@
    if (!$modelsJson) {
        log-warn "Using defaults."
        $modelsJson = '[{"id":"zai-org/GLM-4.7-TEE","name":"GLM 4.7 TEE","reasoning":false,"input":["text"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":128000,"maxTokens":4096},{"id":"zai-org/GLM-4.7-Flash","name":"GLM 4.7 Flash","reasoning":false,"input":["text"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":128000,"maxTokens":4096}]'
    }

    Log-Info "Applying configuration suite..."
    $providerConfig = node -e "console.log(JSON.stringify({baseUrl: '$CHUTES_BASE_URL', api: 'openai-completions', auth: 'api-key', models: $modelsJson}))"
    openclaw config set models.providers.chutes --json $providerConfig 2>$null

    $agentDefaults = node -e @"
    const modelsJson = $modelsJson;
    const modelEntries = {};
    modelsJson.forEach(m => { modelEntries['chutes/' + m.id] = {}; });
    modelEntries['chutes-fast'] = { alias: '$CHUTES_FAST_MODEL_REF' };
    modelEntries['chutes-vision'] = { alias: 'chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506' };
    modelEntries['chutes-pro'] = { alias: 'chutes/deepseek-ai/DeepSeek-V3.2-TEE' };
    console.log(JSON.stringify({
      model: { primary: '$CHUTES_DEFAULT_MODEL_REF', fallbacks: ['chutes/deepseek-ai/DeepSeek-V3.2-TEE', 'chutes/Qwen/Qwen3-32B'] },
      imageModel: { primary: 'chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506', fallbacks: ['chutes/Qwen/Qwen3-32B'] },
      models: modelEntries
    }));
"@
    openclaw config set agents.defaults --json $agentDefaults 2>$null
    openclaw config set auth.profiles.`"chutes:manual`" --json '{"provider":"chutes","mode":"api_key"}' 2>$null
    Log-Success "Configuration applied (Allowlist open)."
}

function Start-Gateway {
    Log-Info "Restarting Gateway..."
    $procs = if ($PSVersionTable.PSVersion.Major -ge 7) {
        Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*openclaw gateway*" }
    } else {
        Get-CimInstance Win32_Process -Filter "Name = 'node.exe' AND CommandLine LIKE '%openclaw gateway%'" | ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
    }
    if ($procs) { $procs | Stop-Process -Force -Confirm:$false }
    Start-Sleep -s 1
    $logPath = Join-Path $env:TEMP "openclaw-gateway.log"
    Start-Process openclaw -ArgumentList "gateway run --bind loopback --port $GATEWAY_PORT" -NoNewWindow -RedirectStandardOutput $logPath -RedirectStandardError $logPath
    $count = 0; $success = $false
    while ($count -lt 15) {
        try { Invoke-RestMethod "http://127.0.0.1:$GATEWAY_PORT/health" -ErrorAction Stop | Out-Null; $success = $true; break } catch { Start-Sleep -s 1; $count++; Write-Host -NoNewline "." }
    }
    Write-Host ""
    if ($success) { Log-Success "Gateway ready." } else { Log-Error "Gateway failed. Check $logPath" }
}

function Show-Summary {
    $version = openclaw --version
    $color = if ($useColor) { "White" } else { "Default" }
    Write-Host "----------------------------------------------------------------------" -ForegroundColor $color
    Write-Host "   🚀 ParaClaw Instance Summary (OpenClaw X Chutes)" -ForegroundColor Green
    Write-Host "----------------------------------------------------------------------" -ForegroundColor $color
    Write-Host "   Version:           $version" -ForegroundColor $color
    Write-Host "   Gateway URL:       http://localhost:$GATEWAY_PORT" -ForegroundColor $color
    Write-Host "   Primary Model:     $CHUTES_DEFAULT_MODEL_REF" -ForegroundColor $color
    Write-Host "   Vision Model:      chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506" -ForegroundColor $color
    Write-Host "----------------------------------------------------------------------" -ForegroundColor $color
    Write-Host "   Next Steps: 'openclaw tui' or 'openclaw dashboard'" -ForegroundColor $color
    Write-Host "----------------------------------------------------------------------" -ForegroundColor $color
}

# Main
try {
    $color = if ($useColor) { "White" } else { "Default" }
    $color2 = if ($useColor) { "Red" } else { "Default" }
    Write-Host -NoNewline "   ___                  " -ForegroundColor $color
    Write-Host "___ _                " -ForegroundColor $color2
    Write-Host -NoNewline "  / _ \__ _ _ __ __ _  " -ForegroundColor $color
    Write-Host "/ __\ | __ ___      __" -ForegroundColor $color2
    Write-Host -NoNewline " / /_)/ _` | '__/ _` |" -ForegroundColor $color
    Write-Host "/ /  | |/ _` \ \ /\ / /" -ForegroundColor $color2
    Write-Host -NoNewline "/ ___/ (_| | | | (_| " -ForegroundColor $color
    Write-Host "/ /___| | (_| |\ V  V / " -ForegroundColor $color2
    Write-Host -NoNewline "\/    \__,_|_|  \__,_" -ForegroundColor $color
    Write-Host "\____/|_|\__,_| \_/\_/  " -ForegroundColor $color2
    Write-Host "          OpenClaw X Chutes"
    Check-NodeVersion
    $isNew = $false
    if (!(Check-OpenClawInstalled) -or !(Test-Path (Join-Path $HOME ".openclaw\openclaw.json"))) { $isNew = $true }
    if ($isNew) {
        Log-Info "New user journey detected..."
        if (!(Check-OpenClawInstalled)) { Install-OpenClaw }
        Seed-InitialConfig
        Add-ChutesAuth
        Apply-AtomicConfig
        Log-Info "Launching interactive onboarding..."
        Start-OnboardingWithGuard
    } else {
        Log-Info "Existing user journey detected..."
        Add-ChutesAuth
        Apply-AtomicConfig
    }
    Start-Gateway
    Show-Summary
    if ($isNew) {
        $choice = Read-Host "Launch TUI now? (y/n)"
        if ($choice -eq "y") { openclaw tui --message "Wake up, my friend!" }
    }
    Log-Success "Setup complete!"
} catch { Log-Error $_.Exception.Message }
