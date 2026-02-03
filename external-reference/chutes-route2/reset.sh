#!/usr/bin/env bash

# Chutes x OpenClaw Reset Script
# Use this to completely wipe OpenClaw and all Chutes integration data for a fresh start.

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "info: $1"; }
log_success() { echo -e "${GREEN}success: $1${NC}"; }
log_warn() { echo -e "${YELLOW}warning: $1${NC}"; }

echo -e "${RED}--- FULL SYSTEM RESET ---${NC}"
log_info "This will kill all OpenClaw processes, uninstall the global CLI, and wipe all local data/secrets."

# 1. Kill any running OpenClaw processes
log_info "Killing running OpenClaw processes..."
pkill -9 -f openclaw 2>/dev/null || true
pkill -9 -f "openclaw-gateway" 2>/dev/null || true
sleep 1

# 2. Uninstall OpenClaw globally from all potential package managers
log_info "Uninstalling OpenClaw globally..."
pnpm remove -g openclaw 2>/dev/null || true
npm uninstall -g openclaw 2>/dev/null || true
bun remove -g openclaw 2>/dev/null || true

# 3. Truly nuke the config and data using absolute paths
log_info "Wiping configuration and local data (~/.openclaw)..."
rm -rf "$HOME/.openclaw"
rm -rf "$HOME/.config/openclaw"

# 4. Unset session environment variables
log_info "Clearing Chutes environment variables..."
unset CHUTES_API_KEY
unset CHUTES_OAUTH_TOKEN

# 5. Clear terminal hash
log_info "Clearing terminal command cache..."
hash -r 2>/dev/null || true

# 6. Final status check
echo ""
echo -e "${GREEN}--- RESET COMPLETE ---${NC}"
if ! command -v openclaw >/dev/null 2>&1; then
  log_success "Binary: Deleted"
else
  log_warn "Binary: Still found at $(which openclaw). You may need to manually delete it."
fi

if [ ! -d "$HOME/.openclaw" ]; then
  log_success "Config dir: Deleted"
else
  log_warn "Config dir: STILL EXISTS at $HOME/.openclaw"
fi

if [ -z "${CHUTES_API_KEY:-""}" ]; then
  log_success "API Key: Cleared from this session"
else
  log_warn "API Key: STILL SET. Run 'unset CHUTES_API_KEY' manually if this persists."
fi

echo ""
log_info "You are now starting with a 100% clean slate."
log_info "Run './init.sh' to start the fresh onboarding journey."
