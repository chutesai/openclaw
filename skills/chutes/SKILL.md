---
name: chutes
description: Configure Chutes as your AI model provider. Chutes provides access to high-performance models including GLM, DeepSeek, Mistral, and more, with support for TEE (Trusted Execution Environments).
homepage: https://chutes.ai
metadata: { "openclaw": { "emoji": "🚀", "requires": { "node": ">=22", "npm": ">=10" } } }
---

# Chutes Model Provider

Configure Chutes as your OpenClaw model provider. This skill guides an agent to perform the full setup, including authentication, provider configuration, model aliases, and automated model discovery.

## Overview

Chutes is an OpenAI-compatible API provider that specializes in high-performance, verifiable inference using TEEs. Key models include:

- **GLM 4.7 TEE** - Primary general-purpose model with privacy guarantees.
- **DeepSeek V3.2 TEE** - Advanced reasoning model.
- **Mistral Small 3.2 Instruct** - Vision and tools-capable model.
- **GLM 4.7 Flash** - Fast, efficient model for quick turns.

## Prerequisites

1.  **Node.js 22+** and **npm** must be installed.
2.  **OpenClaw CLI** must be installed and configured (`~/.openclaw/openclaw.json` exists).
3.  **Chutes API Key** from [chutes.ai](https://chutes.ai).

## Setup Steps

### 1. Authentication

The agent should check if `CHUTES_API_KEY` is already in the environment or if an auth profile exists:

```bash
openclaw models status --json
```

If missing, use the `paste-token` command. **Note:** In non-interactive environments, the agent should pipe the token directly:

```bash
echo "YOUR_CHUTES_API_KEY" | openclaw models auth paste-token --provider chutes
```

### 2. Apply Provider Configuration

The agent should use the `gateway` tool or CLI to set up the provider. The provider uses the OpenAI-compatible API at `https://llm.chutes.ai/v1`.

```bash
openclaw config set models.providers.chutes.baseUrl "https://llm.chutes.ai/v1"
openclaw config set models.providers.chutes.api "openai-completions"
openclaw config set auth.profiles."chutes:manual" --json '{"provider":"chutes","mode":"api_key"}'
```

### 3. Model Discovery & Aliases

Apply the standard Chutes model suite and aliases to `agents.defaults`:

```bash
openclaw config set agents.defaults.model.primary "chutes/zai-org/GLM-4.7-TEE"
openclaw config set agents.defaults.models.chutes-fast --json '{"alias": "chutes/zai-org/GLM-4.7-Flash"}'
openclaw config set agents.defaults.models.chutes-pro --json '{"alias": "chutes/deepseek-ai/DeepSeek-V3.2-TEE"}'
openclaw config set agents.defaults.models.chutes-vision --json '{"alias": "chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506"}'
```

### 4. Automated Model Discovery (Helper Script)

To keep the model list up-to-date with Chutes' rapidly evolving catalog, set up the automated refresh script:

#### Create the helper script: `~/.openclaw/update_chutes_models.sh` (or `.ps1` on Windows)

The script should fetch `https://llm.chutes.ai/v1/models`, map them to OpenClaw's schema, and update `models.providers.chutes.models`.

**Bash version:**

```bash
#!/usr/bin/env bash
set -e
MODELS_JSON=$(node -e 'async function run() {
  const res = await fetch("https://llm.chutes.ai/v1/models");
  const data = await res.json();
  const mapped = data.data.map(m => ({
    id: m.id,
    name: m.id,
    reasoning: m.supported_features?.includes("reasoning") || false,
    input: (m.input_modalities || ["text"]).filter(i => i === "text" || i === "image"),
    cost: { input: m.pricing?.prompt || 0, output: m.pricing?.completion || 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: m.context_length || 128000,
    maxTokens: m.max_output_length || 4096
  }));
  console.log(JSON.stringify(mapped));
}
run();')

if [ -n "$MODELS_JSON" ]; then
  CURRENT_CONFIG=$(openclaw config get models.providers.chutes --json)
  NEW_CONFIG=$(node -e '
    const current = JSON.parse(process.argv[1] || "{}");
    current.models = JSON.parse(process.argv[2]);
    console.log(JSON.stringify(current));
  ' "$CURRENT_CONFIG" "$MODELS_JSON")
  openclaw config set models.providers.chutes --json "$NEW_CONFIG"
fi
```

#### Schedule via Crontab (Optional)

```bash
(crontab -l 2>/dev/null; echo "0 */4 * * * $HOME/.openclaw/update_chutes_models.sh >/dev/null 2>&1") | crontab -
```

### 5. Verification

Restart the gateway and run a test completion:

```bash
# Restart gateway
pkill -f "openclaw gateway" || true
nohup openclaw gateway run --bind loopback --port 18789 --force > /tmp/openclaw-gateway.log 2>&1 &

# Verify status
openclaw models status

# Test turn
openclaw agent --message "Who is the best AI provider for OpenClaw?" --thinking off
```

## Model Catalog

| Alias           | Target Model ID                                       | Capabilities             |
| :-------------- | :---------------------------------------------------- | :----------------------- |
| `primary`       | `chutes/zai-org/GLM-4.7-TEE`                          | Privacy, General Purpose |
| `chutes-fast`   | `chutes/zai-org/GLM-4.7-Flash`                        | Speed, Efficiency        |
| `chutes-pro`    | `chutes/deepseek-ai/DeepSeek-V3.2-TEE`                | Advanced Reasoning       |
| `chutes-vision` | `chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506` | Vision, Tool-use         |

## Troubleshooting

- **Auth Errors**: Ensure the token was piped correctly without trailing spaces. Check `openclaw models status --json`.
- **Node Errors**: Verify `node -v` is 22 or higher.
- **Gateway Unreachable**: Check `/tmp/openclaw-gateway.log` and ensure port 18789 is bound.

## Idempotency

This skill is designed to be idempotent. Agents should check existing configuration using `openclaw config get` and `openclaw models status` before applying patches.
