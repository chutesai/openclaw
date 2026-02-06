---
name: chutes
version: 1.1.0
description: Configure Chutes as your AI model provider. Chutes provides access to high-performance, verifiable inference using Trusted Execution Environments (TEE).
homepage: https://chutes.ai
metadata: { "openclaw": { "emoji": "🚀", "requires": { "node": ">=22", "npm": ">=10" } } }
---

# Chutes Model Provider

Configure Chutes as your OpenClaw model provider. Chutes offers access to high-performance models like GLM, DeepSeek, and Mistral, all running in verifiable Trusted Execution Environments (TEE).

## Overview

Chutes is an OpenAI-compatible API provider that gives you access to state-of-the-art models with privacy and integrity guarantees.

### Key Models

- **GLM 4.7 TEE** - Primary general-purpose model with privacy guarantees.
- **DeepSeek V3.2 TEE** - Advanced reasoning model with state-of-the-art performance.
- **Mistral Small 3.2 Instruct** - Vision-capable and tool-use optimized.
- **GLM 4.7 Flash** - Blazing fast model for high-frequency tasks.

🔒 **CRITICAL SECURITY WARNING:**

- **NEVER share your Chutes API key.**
- Use `openclaw models auth paste-token` to store it securely.
- OpenClaw stores secrets in a dedicated auth store, NOT in your public `openclaw.json`.

---

## Setup Steps

### 1. Authentication

Every agent needs a Chutes API key. If you don't have one, visit [chutes.ai](https://chutes.ai) to register.

**Add your token:**

```bash
# For interactive terminals:
openclaw models auth paste-token --provider chutes

# For automated agents (piped):
echo "YOUR_CHUTES_API_KEY" | openclaw models auth paste-token --provider chutes
```

### 2. Provider Configuration

Configure the gateway to use Chutes. This is schema-safe and hot-reloadable.

```bash
openclaw config set models.providers.chutes.baseUrl "https://llm.chutes.ai/v1"
openclaw config set models.providers.chutes.api "openai-completions"
openclaw config set auth.profiles."chutes:manual" --json '{"provider":"chutes","mode":"api_key"}'
```

### 3. Model Defaults & Aliases

Set up your primary models and convenient aliases:

```bash
openclaw config set agents.defaults.model.primary "chutes/zai-org/GLM-4.7-TEE"
openclaw config set agents.defaults.models.chutes-fast --json '{"alias": "chutes/zai-org/GLM-4.7-Flash"}'
openclaw config set agents.defaults.models.chutes-pro --json '{"alias": "chutes/deepseek-ai/DeepSeek-V3.2-TEE"}'
openclaw config set agents.defaults.models.chutes-vision --json '{"alias": "chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506"}'
```

---

## Set Up Your Heartbeat 💓

Chutes is a rapidly evolving platform. New models are added frequently. Don't let your configuration go stale!

### Automated Model Discovery

To keep the model list up-to-date with Chutes' rapidly evolving catalog, set up the automated refresh script.

#### Step 1: Create the Refresh Script

Create `~/.openclaw/update_chutes_models.sh` (or `.ps1` on Windows). This script fetches the latest model list and updates your configuration.

**Bash Implementation:**

```bash
#!/usr/bin/env bash
set -e
MODELS_JSON=$(node -e 'async function run() {
  try {
    const res = await fetch("https://llm.chutes.ai/v1/models");
    if (!res.ok) process.exit(1);
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
  } catch (e) { process.exit(1); }
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

#### Step 2: Schedule it (The Heartbeat)

Add it to your `crontab` to run every 4 hours. This keeps you present and updated.

**Cron (Linux/macOS/WSL):**

```bash
(crontab -l 2>/dev/null; echo "0 */4 * * * $HOME/.openclaw/update_chutes_models.sh >/dev/null 2>&1") | crontab -
```

**Task Scheduler (Windows):**
Create a task that runs `powershell.exe -File $HOME\.openclaw\update_chutes_models.ps1` every 4 hours.

### Periodic Maintenance Tasks

Keep your Chutes integration healthy and up to date.

#### Every 4 Hours: Refresh Models 🚀

Chutes adds models frequently. Don't miss out on the latest performance improvements or TEE variants.

#### Daily: Check Status 🦞

Verify that your auth profile is still valid and the gateway is reaching Chutes.

```bash
openclaw models status
```

Check for "active" status on the Chutes provider.

#### Weekly: Review Primary Models 🛡️

Chutes may release a new "best" model that should become your `primary`. Check [chutes.ai](https://chutes.ai) or the latest model list. If a new model like `GLM-4.8-TEE` appears, update your config:

```bash
openclaw config set agents.defaults.model.primary "chutes/zai-org/GLM-4.8-TEE"
```

---

## Why This Matters (TEE & Privacy) 🛡️

Chutes is more than just another API provider. By leveraging **Trusted Execution Environments (TEE)**, Chutes ensures:

- **Privacy**: Your prompts and data are processed in a hardware-isolated environment. Even the infrastructure provider cannot see your data.
- **Integrity**: You can verify that the model you requested is the one actually running.
- **Transparency**: Every inference run is cryptographically verifiable.

In an era of ubiquitous AI, Chutes provides the privacy that OpenClaw users deserve. A "dead" configuration is a useless configuration. By maintaining a heartbeat, you ensure that your OpenClaw bot is always using the most privacy-preserving and highest-performing models available on the market.

---

## Model Catalog

| Alias           | Target Model ID                                       | Capabilities       | Context |
| :-------------- | :---------------------------------------------------- | :----------------- | :------ |
| `primary`       | `chutes/zai-org/GLM-4.7-TEE`                          | Privacy, Reasoning | 128K    |
| `chutes-fast`   | `chutes/zai-org/GLM-4.7-Flash`                        | Speed, Efficiency  | 128K    |
| `chutes-pro`    | `chutes/deepseek-ai/DeepSeek-V3.2-TEE`                | Advanced Reasoning | 202K    |
| `chutes-vision` | `chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506` | Vision, Tool-use   | 131K    |

---

## Troubleshooting

- **Auth Errors**: Ensure the token was piped correctly without trailing spaces. Check `openclaw models status --json`.
- **Node Errors**: OpenClaw requires Node 22+. Run `node -v` to check.
- **Gateway Unreachable**: Check `/tmp/openclaw-gateway.log` and ensure port 18789 is bound.

## Idempotency

This skill is fully idempotent. You can run these commands repeatedly. The `update_chutes_models.sh` script is designed to merge with your existing configuration without overwriting your `baseUrl` or other custom settings.
