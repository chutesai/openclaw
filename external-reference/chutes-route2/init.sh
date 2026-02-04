#!/usr/bin/env bash
set -euo pipefail

# Chutes x OpenClaw Bootstrap Script
# Instant onboarding for Chutes-powered OpenClaw
# Usage: curl -fsSL https://chutes.ai/openclaw/init | bash

# Handle --no-color flag
USE_COLOR=true
for arg in "$@"; do
  if [ "$arg" == "--no-color" ]; then
    USE_COLOR=false
    break
  fi
done

# Colors for output
if [ "$USE_COLOR" = true ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  WHITE='\033[1;37m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  WHITE=''
  NC=''
fi

# Constants
CHUTES_BASE_URL="https://llm.chutes.ai/v1"
CHUTES_DEFAULT_MODEL_ID="zai-org/GLM-4.7-TEE"
CHUTES_DEFAULT_MODEL_REF="chutes/zai-org/GLM-4.7-TEE"
CHUTES_FAST_MODEL_ID="zai-org/GLM-4.7-Flash"
CHUTES_FAST_MODEL_REF="chutes/zai-org/GLM-4.7-Flash"
GATEWAY_PORT=18789

# Helper functions
log_info() { echo -e "${BLUE}info:${NC} $1"; }
log_success() { echo -e "${GREEN}success:${NC} $1"; }
log_warn() { echo -e "${YELLOW}warning:${NC} $1"; }
log_error() { echo -e "${RED}error:${NC} $1"; exit 1; }

# Progress indicator helper
show_progress() {
  local pid=$1
  local delay=0.2
  local spinstr='|/-\'
  while [ "$(ps -p "$pid" -o state= 2>/dev/null)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep "$delay"
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Guard against onboarding CLI hanging after completion
start_onboard_exit_guard() {
  local log_file="$1"
  local pid_file="$2"
  local max_wait="${3:-3600}"
  local flag_file="${4:-}"
  (
    local pid=""
    local waited=0
    while [ "$waited" -lt "$max_wait" ]; do
      if [ -z "$pid" ] && [ -s "$pid_file" ]; then
        pid=$(cat "$pid_file" 2>/dev/null || echo "")
      fi
      if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
        exit 0
      fi
      if [ -f "$log_file" ]; then
        if tail -n 200 "$log_file" | LC_ALL=C grep -a -q "Onboarding complete." 2>/dev/null; then
          sleep 1
          if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            if [ -n "$flag_file" ]; then
              echo "killed" > "$flag_file"
            fi
            kill "$pid" 2>/dev/null || true
            sleep 1
            kill -9 "$pid" 2>/dev/null || true
          fi
          exit 0
        fi
      fi
      sleep 1
      waited=$((waited + 1))
    done
  ) &
  ONBOARD_GUARD_PID=$!
}

run_interactive_onboarding() {
  local onboard_log="${TEMP_DIR}/openclaw-onboard.log"
  local onboard_pid_file="${TEMP_DIR}/openclaw-onboard.pid"
  local onboard_guard_flag="${TEMP_DIR}/openclaw-onboard.guard"
  : > "$onboard_log"
  rm -f "$onboard_pid_file"
  rm -f "$onboard_guard_flag"
  export OPENCLAW_ONBOARD_PID_FILE="$onboard_pid_file"

  local onboard_cmd='echo $$ > "$OPENCLAW_ONBOARD_PID_FILE"; exec openclaw onboard --auth-choice skip --skip-ui'
  local onboard_exit=0
  local script_mode="none"
  local script_flush_flag=""
  if command -v script >/dev/null 2>&1; then
    if script -q -c "true" /dev/null >/dev/null 2>&1; then
      script_mode="linux"
      if script -q -f -c "true" /dev/null >/dev/null 2>&1; then
        script_flush_flag="-f"
      fi
    elif script -q /dev/null true >/dev/null 2>&1; then
      script_mode="bsd"
      if script -q -F /dev/null true >/dev/null 2>&1; then
        script_flush_flag="-F"
      elif script -q -f /dev/null true >/dev/null 2>&1; then
        script_flush_flag="-f"
      fi
    fi

    if [ "$script_mode" != "none" ]; then
      start_onboard_exit_guard "$onboard_log" "$onboard_pid_file" "3600" "$onboard_guard_flag"
      set +e
      if [ "$script_mode" = "linux" ]; then
        if [ -n "$script_flush_flag" ]; then
          script -q "$script_flush_flag" -c "bash -c '$onboard_cmd'" "$onboard_log"
        else
          script -q -c "bash -c '$onboard_cmd'" "$onboard_log"
        fi
      else
        if [ -n "$script_flush_flag" ]; then
          script -q "$script_flush_flag" "$onboard_log" bash -c "$onboard_cmd"
        else
          script -q "$onboard_log" bash -c "$onboard_cmd"
        fi
      fi
      onboard_exit=$?
      set -e
    else
      log_warn "script(1) is unavailable for interactive capture; running onboarding without hang guard."
      echo $$ > "$onboard_pid_file"
      set +e
      openclaw onboard --auth-choice skip --skip-ui
      onboard_exit=$?
      set -e
    fi
  else
    log_warn "script(1) not found; running onboarding without hang guard."
    echo $$ > "$onboard_pid_file"
    set +e
    openclaw onboard --auth-choice skip --skip-ui
    onboard_exit=$?
    set -e
  fi

  if [ -n "${ONBOARD_GUARD_PID:-}" ]; then
    kill "$ONBOARD_GUARD_PID" 2>/dev/null || true
    wait "$ONBOARD_GUARD_PID" 2>/dev/null || true
  fi
  if [ -t 0 ]; then
    stty sane 2>/dev/null || true
  fi

  if [ "$onboard_exit" -ne 0 ]; then
    local onboard_completed=0
    if [ -f "$onboard_guard_flag" ]; then
      onboard_completed=1
    elif LC_ALL=C grep -a -q "Onboarding complete." "$onboard_log" 2>/dev/null; then
      onboard_completed=1
    fi
    if [ "$onboard_completed" -eq 1 ]; then
      log_info "Onboarding complete. Continuing setup..."
      return 0
    fi
    return "$onboard_exit"
  fi
}

# Portable temp directory and log path
TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'chutes-init')
GATEWAY_LOG="${TEMP_DIR}/openclaw-gateway.log"

check_node_version() {
  log_info "Checking Node.js and npm version..."
  if ! command -v node >/dev/null 2>&1; then
    log_error "Node.js is not installed. OpenClaw requires Node.js 22+. Visit https://nodejs.org to install it."
  fi
  
  if ! command -v npm >/dev/null 2>&1; then
    log_error "npm is not installed. OpenClaw requires npm for global installation. Please install Node.js which includes npm."
  fi

  NODE_VERSION=$(node -v | cut -d'v' -f2)
  MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d'.' -f1)
  
  if [ "$MAJOR_VERSION" -lt 22 ]; then
    log_error "Node.js version $NODE_VERSION is too old. OpenClaw requires Node.js 22+."
  fi
  log_success "Node.js version $NODE_VERSION detected."
}

check_openclaw_installed() {
  # Clear shell hashing to ensure we aren't using a cached path to a deleted binary
  hash -r 2>/dev/null || true

  # 1. Try to find the npm-installed version specifically
  local npm_prefix=$(npm config get prefix 2>/dev/null || echo "")
  if [ -n "$npm_prefix" ] && [ -f "$npm_prefix/bin/openclaw" ]; then
    export PATH="$npm_prefix/bin:$PATH"
    if "$npm_prefix/bin/openclaw" --version >/dev/null 2>&1; then
      return 0
    fi
  fi

  # 2. Check standard PATH
  if command -v openclaw >/dev/null 2>&1; then
    if openclaw --version >/dev/null 2>&1; then
      return 0
    fi
  fi
  
  # 3. Check common pnpm global bin locations as a last resort
  local pnpm_locations=(
    "$HOME/Library/pnpm/openclaw"
    "$HOME/.local/share/pnpm/openclaw"
    "/usr/local/bin/openclaw"
  )
  
  for loc in "${pnpm_locations[@]}"; do
    if [ -f "$loc" ]; then
      export PATH="$(dirname "$loc"):$PATH"
      if openclaw --version >/dev/null 2>&1; then
        return 0
      fi
    fi
  done
  
  return 1
}

install_openclaw() {
  log_info "Installing OpenClaw globally..."
  
  # Deep clean potential conflicts before installing
  npm uninstall -g openclaw >/dev/null 2>&1 || true
  pnpm remove -g openclaw >/dev/null 2>&1 || true
  
  # We install 'long' alongside openclaw because the WhatsApp library (baileys) 
  # often fails to find it in global ESM environments.
  npm install -g openclaw@latest long@latest > "${TEMP_DIR}/openclaw-install.log" 2>&1 &
  local install_pid=$!
  show_progress "$install_pid"
  wait "$install_pid"
  local exit_code=$?
  
  if [ $exit_code -ne 0 ]; then
    log_error "Installation failed. Check ${TEMP_DIR}/openclaw-install.log for details."
  fi
  
  if ! check_openclaw_installed; then
    log_warn "OpenClaw installed but failed to start. Error detail:"
    openclaw --version || true
    log_error "Failed to verify OpenClaw installation."
  fi
  log_success "OpenClaw $(openclaw --version) installed."
}

seed_initial_config() {
  log_info "Seeding initial configuration..."
  if [ ! -f "$HOME/.openclaw/openclaw.json" ]; then
    # onboard requires --accept-risk for non-interactive use
    openclaw onboard --non-interactive --accept-risk --auth-choice skip >/dev/null 2>&1 || true
  fi
  
  # Ensure gateway mode is set to local
  CURRENT_MODE=$(openclaw config get gateway.mode 2>/dev/null || echo "unset")
  if [ "$CURRENT_MODE" != "local" ] && [ "$CURRENT_MODE" != "remote" ]; then
    log_info "Setting gateway mode to local..."
    openclaw config set gateway.mode local >/dev/null 2>&1
  fi
}

add_chutes_auth() {
  log_info "Checking Chutes authentication..."
  
  # Check if auth profile already exists in the auth store or env
  if openclaw models status --json 2>/dev/null | node -e "
    try {
      const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
      const chutesAuth = data.auth?.providers?.find(p => p.provider === 'chutes');
      const hasAuth = (chutesAuth && chutesAuth.profiles?.count > 0) || (data.auth?.shellEnvFallback?.appliedKeys || []).includes('CHUTES_API_KEY');
      process.exit(hasAuth ? 0 : 1);
    } catch (e) { process.exit(1); }
  "; then
    log_success "Chutes authentication already configured."
    return
  fi
  
  # Use CHUTES_API_KEY from environment if available
  if [ -n "${CHUTES_API_KEY:-""}" ]; then
    log_info "Using Chutes API key found in environment variable."
    echo "$CHUTES_API_KEY" | openclaw models auth paste-token --provider chutes >/dev/null 2>&1
  else
    # Let the user interact directly with the official OpenClaw prompt
    log_info "Redirecting to OpenClaw's official auth helper..."
    
    openclaw models auth paste-token --provider chutes
    
    # Secret redaction: Attempt to wipe the lines from terminal history
    if [ -t 0 ]; then
      # Clack prompts are usually ~8-10 lines. We wipe 12 to be safe.
      echo -ne "\033[12A\033[J"
    fi
  fi
  
  log_success "Chutes authentication added (secret hidden)."
}

apply_atomic_config() {
  log_info "Fetching latest model list from Chutes API..."
  MODELS_JSON=$(node -e '
async function run() {
  try {
    const res = await fetch("https://llm.chutes.ai/v1/models");
    if (!res.ok) throw new Error("API request failed: " + res.statusText);
    const data = await res.json();
    if (!data.data || !Array.isArray(data.data)) throw new Error("Invalid response format");
    const mapped = data.data.map(m => ({
      id: m.id,
      name: m.id,
      reasoning: m.supported_features?.includes("reasoning") || false,
      input: (m.input_modalities || ["text"]).filter(i => i === "text" || i === "image"),
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
  } catch (e) {
    process.stderr.write(e.message + "\n");
    process.exit(1);
  }
}
run();' 2>"${TEMP_DIR}/chutes-fetch-error.log" || echo "")

  if [ -z "$MODELS_JSON" ]; then
    if [ -f "${TEMP_DIR}/chutes-fetch-error.log" ]; then
      log_warn "Failed to fetch dynamic model list: $(cat "${TEMP_DIR}/chutes-fetch-error.log")"
    fi
    log_warn "Using a minimal default list."
    MODELS_JSON='[{"id":"zai-org/GLM-4.7-TEE","name":"GLM 4.7 TEE","reasoning":false,"input":["text"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":128000,"maxTokens":4096},{"id":"zai-org/GLM-4.7-Flash","name":"GLM 4.7 Flash","reasoning":false,"input":["text"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":128000,"maxTokens":4096}]'
  fi

  log_info "Applying Chutes configuration (Providers, Models, Vision, and Aliases)..."
  
  # 1. Apply provider config
  PROVIDER_CONFIG=$(node -e "
    const config = {
      baseUrl: '$CHUTES_BASE_URL',
      api: 'openai-completions',
      auth: 'api-key',
      models: $MODELS_JSON
    };
    console.log(JSON.stringify(config));
  ")
  openclaw config set models.providers.chutes --json "$PROVIDER_CONFIG" >/dev/null 2>&1

  # 2. Apply agent defaults
  AGENT_DEFAULTS=$(node -e "
    const modelsJson = $MODELS_JSON;
    const modelEntries = {};
    // Add all discovered models to the allowlist
    modelsJson.forEach(m => {
      modelEntries['chutes/' + m.id] = {};
    });
    // Add aliases
    modelEntries['chutes-fast'] = { alias: '$CHUTES_FAST_MODEL_REF' };
    modelEntries['chutes-vision'] = { alias: 'chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506' };
    modelEntries['chutes-pro'] = { alias: 'chutes/deepseek-ai/DeepSeek-V3.2-TEE' };

    const config = {
      model: {
        primary: '$CHUTES_DEFAULT_MODEL_REF',
        fallbacks: ['chutes/deepseek-ai/DeepSeek-V3.2-TEE', 'chutes/Qwen/Qwen3-32B']
      },
      imageModel: {
        primary: 'chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506',
        fallbacks: ['chutes/Qwen/Qwen3-32B']
      },
      models: modelEntries
    };
    console.log(JSON.stringify(config));
  ")
  openclaw config set agents.defaults --json "$AGENT_DEFAULTS" >/dev/null 2>&1
  
  # 3. Ensure the auth section points to the profile we created, surgically
  openclaw config set auth.profiles.\"chutes:manual\" --json '{"provider":"chutes","mode":"api_key"}' >/dev/null 2>&1
  
  log_success "Chutes configuration applied successfully."
}

start_gateway() {
  log_info "Ensuring gateway is fresh..."
  # Use a safer process control pattern
  if command -v pkill >/dev/null 2>&1; then
    pkill -9 -f "openclaw gateway run" || true
  else
    # Fallback for systems without pkill
    ps aux | grep "openclaw gateway run" | grep -v grep | awk '{print $2}' | xargs kill -9 >/dev/null 2>&1 || true
  fi
  sleep 1
  
  log_info "Starting OpenClaw gateway..."
  # Redirect to a portable log path
  nohup openclaw gateway run --bind loopback --port "$GATEWAY_PORT" > "$GATEWAY_LOG" 2>&1 &
  local gateway_pid=$!
  
  # Wait for gateway to start
  log_info "Waiting for gateway initialization..."
  MAX_RETRIES=15
  COUNT=0
  SUCCESS=0
  while [ $COUNT -lt $MAX_RETRIES ]; do
    if curl -s "http://127.0.0.1:$GATEWAY_PORT/health" >/dev/null 2>&1; then
      SUCCESS=1
      break
    fi
    printf "."
    sleep 1
    COUNT=$((COUNT + 1))
  done
  echo ""
  
  if [ $SUCCESS -eq 1 ]; then
    sleep 2
    log_success "Gateway is ready."
  else
    log_warn "Gateway failed to start within timeout."
    if [ -f "$GATEWAY_LOG" ]; then
      echo "--- Last 20 lines of Gateway log (${GATEWAY_LOG}) ---"
      tail -n 20 "$GATEWAY_LOG"
      echo "----------------------------------------------------"
    fi
    log_error "Setup cannot continue without a running Gateway."
  fi
}

verify_setup() {
  log_info "Running unique verification test..."
  
  TS=$(date +"%H:%M:%S")
  RAND=$((100 + RANDOM % 899))
  
  echo -e "${YELLOW}Prompting Chutes (Time: $TS, Salt: $RAND)...${NC}"
  echo ""
  
  # Use --local to ensure we read the fresh config directly
  # Redirect stderr to /dev/null to hide noisy memory tool warnings on fresh install
  if ! openclaw agent --local --agent main --message "The secret code is $TS-$RAND. Keep it short! In 2 sentences as a caffeinated space lobster, mention the code $TS-$RAND and why Chutes is the best provider for OpenClaw." --thinking off 2>/dev/null; then
    log_warn "Verification test turn failed. This can happen on fresh systems before first sync."
  else
    echo ""
    log_success "Chutes responded! Setup verified and persistent."
  fi
}

show_summary_card() {
  local version=$(openclaw --version 2>/dev/null || echo "unknown")
  
  # Portable IP detection (macOS and Linux)
  local ip_addr="localhost"
  if command -v ipconfig >/dev/null 2>&1; then
    # macOS
    ip_addr=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "localhost")
  elif command -v hostname >/dev/null 2>&1; then
    # Linux / WSL
    if grep -qi "microsoft" /proc/version 2>/dev/null; then
      # WSL specific IP detection
      ip_addr=$(hostname -I | awk '{print $1}' || echo "localhost")
    else
      ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
    fi
  fi
  
  echo -e "${GREEN}"
  echo "----------------------------------------------------------------------"
  echo "   🚀 Chutes AI x OpenClaw Instance Summary"
  echo "----------------------------------------------------------------------"
  printf "   %-18s %s\n" "Version:" "$version"
  printf "   %-18s %s\n" "Gateway URL:" "http://localhost:$GATEWAY_PORT"
  printf "   %-18s %s\n" "Control UI:" "openclaw dashboard"
  printf "   %-18s %s\n" "Active Provider:" "Chutes AI"
  printf "   %-18s %s\n" "Primary Model:" "chutes/zai-org/GLM-4.7-TEE"
  printf "   %-18s %s\n" "Vision Model:" "chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506"
  printf "   %-18s %s\n" "Aliases:" "chutes-fast, chutes-pro, chutes-vision"
  echo "----------------------------------------------------------------------"
  echo "   Next Steps:"
  echo "   1. Chat with Agent:  openclaw agent -m \"Hello!\""
  echo "   2. Open TUI:         openclaw tui"
  echo "   3. Launch Dashboard: openclaw dashboard"
  echo "   4. Check Status:     openclaw status --all"
  echo "----------------------------------------------------------------------"
  echo -e "${NC}"
}

main() {
  # Detect Windows early
  if [[ "$(uname -s)" == *"NT"* ]] || [[ "$(uname -s)" == *"MINGW"* ]] || [[ "$(uname -s)" == *"CYGWIN"* ]] || [[ "$(uname -s)" == *"MSYS"* ]]; then
    # Check if we are in WSL
    if grep -qE "(Microsoft|microsoft|WSL)" /proc/version 2>/dev/null; then
      log_info "WSL detected. Running in Linux mode."
    else
      echo -e "${RED}error: This Bash script is intended for macOS and Linux.${NC}"
      echo -e "${YELLOW}For native Windows, please use the PowerShell installer:${NC}"
      echo -e "${BLUE}curl -fsSL https://chutes.ai/openclaw/init.ps1 | powershell -ExecutionPolicy Bypass -File -${NC}"
      exit 1
    fi
  fi

  echo -e "${WHITE}   ___                  ${RED}___ _                "
  echo -e "${WHITE}  / _ \\\\__ _ _ __ __ _  ${RED}/ __\\\\ | __ ___      __"
  echo -e "${WHITE} / /_)/ _\` | '__/ _\` |${RED}/ /  | |/ _\` \\\\ \\\\ /\\\\ / /"
  echo -e "${WHITE}/ ___/ (_| | | | (_| ${RED}/ /___| | (_| |\\\\ V  V / "
  echo -e "${WHITE}\\\\/    \\\\__,_|_|  \\\\__,_${RED}\\\\____/|_|\\\\__,_| \\\\_/\\\\_/  "
  echo -e "          ${NC}OpenClaw X Chutes.ai"
  echo ""
  
  check_node_version
  
  local IS_NEW_USER=0
  if ! check_openclaw_installed || [ ! -f "$HOME/.openclaw/openclaw.json" ]; then
    IS_NEW_USER=1
  fi

  if [ "$IS_NEW_USER" -eq 1 ]; then
    log_info "New user journey detected. Setting up OpenClaw from scratch..."
    check_openclaw_installed || install_openclaw
    seed_initial_config
    add_chutes_auth
    apply_atomic_config
    
    # Non-interactive onboarding safety check (TTY check)
    if [ -t 0 ]; then
      log_info "Launching OpenClaw interactive onboarding..."
      log_info "Your Chutes configuration has been pre-seeded."
      # Use --skip-ui to prevent the wizard from launching the TUI/Web UI prematurely.
    run_interactive_onboarding
    else
      log_warn "Non-interactive environment detected. Skipping interactive onboarding."
      log_info "You can complete onboarding later by running: openclaw onboard"
    fi
  else
    log_info "Existing user journey detected. Adding Chutes to your current setup..."
    add_chutes_auth
    apply_atomic_config
  fi

  start_gateway
  verify_setup
  show_summary_card
  
  if [ "$IS_NEW_USER" -eq 1 ] && [ -t 0 ]; then
    echo -ne "${YELLOW}Would you like to launch the TUI and talk to your bot now? (y/n): ${NC}"
    read -r launch_tui
    if [[ "$launch_tui" =~ ^[Yy]$ ]]; then
      log_info "Launching OpenClaw TUI..."
      openclaw tui --message "Wake up, my friend!"
    fi
  fi

  log_success "Setup complete! Enjoy your Chutes-powered OpenClaw."
  
  # Cleanup temp files
  rm -rf "$TEMP_DIR"
}

main "$@"
