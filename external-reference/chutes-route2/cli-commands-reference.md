# OpenClaw CLI Commands Reference

Commands needed for the Route 2 bootstrap script.

## Check Installation
```bash
openclaw --version
```

## Check Status
```bash
openclaw models status
```

## Add Authentication
```bash
openclaw models auth paste-token --provider chutes
```

This command:
- Prompts for API key input
- Stores in `~/.openclaw/agents/<agentId>/agent/auth-profiles.json`
- Updates config to reference the auth profile
- Does NOT write secrets to `openclaw.json`

## Configure Provider
```bash
openclaw config set models.providers.chutes.baseUrl "https://llm.chutes.ai/v1"
openclaw config set models.providers.chutes.api "openai-completions"
```

## Set Default Model
```bash
openclaw config set agents.defaults.model.primary "chutes/zai-org/GLM-4.7-Flash"
```

## Gateway Commands
```bash
# Start gateway (if not running)
openclaw gateway run

# Check if gateway is running
openclaw gateway status
```

## Setup/Onboarding
```bash
# Initial setup (creates config if missing)
openclaw setup

# Interactive configuration wizard
openclaw configure
```

## Node Version Requirement
OpenClaw requires Node.js 22+.

Check with:
```bash
node --version
```
