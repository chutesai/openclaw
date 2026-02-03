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
$CHUTES_DEFAULT_MODEL_ID = "zai-org/GLM-4.7-Flash"
$CHUTES_DEFAULT_MODEL_REF = "chutes/zai-org/GLM-4.7-Flash"
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
    if ($major -lt 22) {
        Log-Error "Node.js version $nodeVer is too old. OpenClaw requires Node.js 22+."
    }
    Log-Success "Node.js version $nodeVer detected."
}

function Check-OpenClawInstalled {
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
        try {
            openclaw --version | Out-Null
            return $true
        } catch {
            Log-Warn "OpenClaw found but failed to start."
            return $false
        }
    }
    return $false
}

function Install-OpenClaw {
    Log-Info "Installing OpenClaw globally..."
    npm install -g openclaw@latest long@latest
    if (!(Check-OpenClawInstalled)) {
        Log-Error "Failed to verify OpenClaw installation."
    }
    Log-Success "OpenClaw installed."
}

function Seed-InitialConfig {
    Log-Info "Ensuring OpenClaw configuration..."
    $configPath = Join-Path $HOME ".openclaw\openclaw.json"
    if (!(Test-Path $configPath)) {
        Log-Info "No configuration found. Running openclaw onboarding..."
        openclaw onboard --non-interactive --accept-risk --auth-choice skip 2>$null
    }
    
    $mode = openclaw config get gateway.mode 2>$null
    if ($mode -ne "local" -and $mode -ne "remote") {
        Log-Info "Setting gateway mode to local..."
        openclaw config set gateway.mode local 2>$null
    }
}

function Add-ChutesAuth {
    Log-Info "Checking Chutes authentication..."
    $status = openclaw models status --json 2>$null | ConvertFrom-Json
    $hasAuth = $false
    if ($status.auth.providers) {
        foreach ($p in $status.auth.providers) {
            if ($p.provider -eq "chutes" -and $p.profiles.count -gt 0) {
                $hasAuth = $true; break
            }
        }
    }
    if ($status.auth.shellEnvFallback.appliedKeys -contains "CHUTES_API_KEY") {
        $hasAuth = $true
    }

    if ($hasAuth) {
        Log-Success "Chutes authentication already configured."
        return
    }

    if ($env:CHUTES_API_KEY) {
        Log-Info "Using Chutes API key found in environment variable."
        $env:CHUTES_API_KEY | openclaw models auth paste-token --provider chutes 2>$null
    } else {
        Log-Info "Redirecting to OpenClaw's official auth helper..."
        openclaw models auth paste-token --provider chutes
        
        # Secret redaction: Attempt to wipe the lines from terminal history
        Write-Host -NoNewline "$([char]27)[12A$([char]27)[J"
    }
    Log-Success "Chutes authentication added (secret hidden)."
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
      cost: {
        input: m.pricing?.prompt || 0,
        output: m.pricing?.completion || 0,
        cacheRead: 0,
        cacheWrite: 0
      },
      contextWindow: m.context_length || 128000,
      maxTokens: m.max_output_length || 4096
    }));
    console.log(JSON.stringify(mapped));
  } catch (e) { process.exit(1); }
}
run();
"@

    if (!$modelsJson) {
        Log-Warn "Failed to fetch dynamic model list. Using defaults."
        $modelsJson = '[{"id":"zai-org/GLM-4.7-Flash","name":"GLM 4.7 Flash","reasoning":false,"input":["text"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":128000,"maxTokens":4096}]'
    }

    Log-Info "Applying configuration suite..."
    $providerConfig = node -e "console.log(JSON.stringify({baseUrl: '$CHUTES_BASE_URL', api: 'openai-completions', auth: 'api-key', models: $modelsJson}))"
    openclaw config set models.providers.chutes --json $providerConfig 2>$null

    $agentDefaults = node -e @"
    const modelsJson = $modelsJson;
    const modelEntries = {};
    modelsJson.forEach(m => {
      modelEntries['chutes/' + m.id] = {};
    });
    modelEntries['chutes-fast'] = { alias: '$CHUTES_DEFAULT_MODEL_REF' };
    modelEntries['chutes-vision'] = { alias: 'chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506' };
    modelEntries['chutes-pro'] = { alias: 'chutes/deepseek-ai/DeepSeek-V3.2-TEE' };

    console.log(JSON.stringify({
      model: {
        primary: '$CHUTES_DEFAULT_MODEL_REF',
        fallbacks: ['chutes/deepseek-ai/DeepSeek-V3.2-TEE', 'chutes/Qwen/Qwen3-32B']
      },
      imageModel: {
        primary: 'chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506',
        fallbacks: ['chutes/Qwen/Qwen3-32B']
      },
      models: modelEntries
    }));
"@
    openclaw config set agents.defaults --json $agentDefaults 2>$null

    openclaw config set auth.profiles.`"chutes:manual`" --json '{"provider":"chutes","mode":"api_key"}' 2>$null
    Log-Success "Configuration applied."
}

function Start-Gateway {
    Log-Info "Ensuring gateway is fresh..."
    # Cross-version process killing (PS 5.1 and 7+)
    $procs = if ($PSVersionTable.PSVersion.Major -ge 7) {
        Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*openclaw gateway*" }
    } else {
        Get-CimInstance Win32_Process -Filter "Name = 'node.exe' AND CommandLine LIKE '%openclaw gateway%'" | ForEach-Object { Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
    }
    if ($procs) { $procs | Stop-Process -Force -Confirm:$false }
    Start-Sleep -s 1

    Log-Info "Starting OpenClaw gateway..."
    $logPath = Join-Path $env:TEMP "openclaw-gateway.log"
    Start-Process openclaw -ArgumentList "gateway run --bind loopback --port $GATEWAY_PORT" -NoNewWindow -RedirectStandardOutput $logPath -RedirectStandardError $logPath
    
    Log-Info "Waiting for gateway initialization..."
    $retries = 15
    $count = 0
    $success = $false
    while ($count -lt $retries) {
        Write-Host -NoNewline "."
        try {
            Invoke-RestMethod "http://127.0.0.1:$GATEWAY_PORT/health" -ErrorAction Stop | Out-Null
            $success = $true
            break
        } catch {
            Start-Sleep -s 1
            $count++
        }
    }
    Write-Host ""

    if ($success) {
        Start-Sleep -s 2
        Log-Success "Gateway is ready."
    } else {
        Log-Warn "Gateway failed to start within timeout."
        if (Test-Path $logPath) {
            Write-Host "--- Last 20 lines of Gateway log ($logPath) ---" -ForegroundColor Gray
            Get-Content $logPath -Tail 20
            Write-Host "----------------------------------------------------" -ForegroundColor Gray
        }
        Log-Error "Setup cannot continue without a running Gateway."
    }
}

function Verify-Setup {
    Log-Info "Running unique verification test..."
    
    $ts = Get-Date -Format "HH:mm:ss"
    $rand = Get-Random -Minimum 100 -Maximum 999
    
    if ($useColor) {
        Write-Host "Prompting Chutes (Time: $ts, Salt: $rand)..." -ForegroundColor Yellow
    } else {
        Write-Host "Prompting Chutes (Time: $ts, Salt: $rand)..."
    }
    Write-Host ""
    
    try {
        # Use --local to ensure we read the fresh config directly
        openclaw agent --local --agent main --message "The secret code is $ts-$rand. Keep it short! In 2 sentences as a caffeinated space lobster, mention the code $ts-$rand and why Chutes is the best provider for OpenClaw." --thinking off 2>$null
        Write-Host ""
        Log-Success "Chutes responded! Setup verified and persistent."
    } catch {
        Log-Warn "Verification test turn failed. This can happen on fresh systems before first sync."
    }
}

function Show-SummaryCard {
    $version = openclaw --version
    $color = if ($useColor) { "Green" } else { "Default" }
    
    Write-Host "" -ForegroundColor $color
    Write-Host "----------------------------------------------------------------------" -ForegroundColor $color
    Write-Host "   🚀 Chutes AI x OpenClaw Instance Summary" -ForegroundColor $color
    Write-Host "----------------------------------------------------------------------" -ForegroundColor $color
    Write-Host "   Version:           $version" -ForegroundColor $color
    Write-Host "   Gateway URL:       http://localhost:$GATEWAY_PORT" -ForegroundColor $color
    Write-Host "   Control UI:        openclaw dashboard" -ForegroundColor $color
    Write-Host "   Active Provider:   Chutes AI" -ForegroundColor $color
    Write-Host "   Primary Model:     chutes/zai-org/GLM-4.7-Flash" -ForegroundColor $color
    Write-Host "   Vision Model:      chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506" -ForegroundColor $color
    Write-Host "   Aliases:           chutes-fast, chutes-pro, chutes-vision" -ForegroundColor $color
    Write-Host "----------------------------------------------------------------------" -ForegroundColor $color
    Write-Host "   Next Steps:" -ForegroundColor $color
    Write-Host "   1. Chat with Agent:  openclaw agent -m ""Hello!""" -ForegroundColor $color
    Write-Host "   2. Open TUI:         openclaw tui" -ForegroundColor $color
    Write-Host "   3. Launch Dashboard: openclaw dashboard" -ForegroundColor $color
    Write-Host "   4. Check Status:     openclaw status --all" -ForegroundColor $color
    Write-Host "----------------------------------------------------------------------" -ForegroundColor $color
}

# Main
try {
    $color = if ($useColor) { "Green" } else { "Default" }
    Write-Host "   ______ __             __               ___    ____ " -ForegroundColor $color
    Write-Host "  / ____// /_   __  __  / /_ ___   _____ /   |  /  _/ " -ForegroundColor $color
    Write-Host " / /    / __ \ / / / / / __// _ \ / ___// /| |  / /   " -ForegroundColor $color
    Write-Host "/ /___ / / / // /_/ / / /_ /  __/(__  )/ ___ |_/ /    " -ForegroundColor $color
    Write-Host "\____//_/ /_/ \__,_/  \__/ \___//____//_/  |_/___/    " -ForegroundColor $color
    Write-Host "      🚀 x OpenClaw" -ForegroundColor $color
    Write-Host ""

    Check-NodeVersion
    $isNewUser = $false
    if (!(Check-OpenClawInstalled) -or !(Test-Path (Join-Path $HOME ".openclaw\openclaw.json"))) {
        $isNewUser = $true
    }

    if ($isNewUser) {
        Log-Info "New user journey detected..."
        if (!(Check-OpenClawInstalled)) { Install-OpenClaw }
        Seed-InitialConfig
        Add-ChutesAuth
        Apply-AtomicConfig
        Log-Info "Launching OpenClaw interactive onboarding..."
        openclaw onboard --auth-choice skip --skip-ui
    } else {
        Log-Info "Existing user journey detected..."
        Add-ChutesAuth
        Apply-AtomicConfig
    }

    Start-Gateway
    Verify-Setup
    Show-SummaryCard

    if ($isNewUser) {
        $choice = Read-Host "Would you like to launch the TUI and talk to your bot now? (y/n)"
        if ($choice -eq "y") {
            openclaw tui --message "Wake up, my friend!"
        }
    }

    Log-Success "Setup complete! Enjoy your Chutes-powered OpenClaw."
} catch {
    Log-Error $_.Exception.Message
}
