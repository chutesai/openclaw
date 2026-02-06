---
name: chutes
version: 1.1.0
description: Configure Chutes as your AI model provider. Chutes provides access to high-performance, verifiable inference using Trusted Execution Environments (TEE).
homepage: https://chutes.ai
metadata: { "openclaw": { "emoji": "🚀", "requires": { "node": ">=22", "npm": ">=10" } } }
---

# Chutes Model Provider

Configure Chutes as your OpenClaw model provider. Chutes offers access to high-performance models like GLM, DeepSeek, and Mistral, all running in verifiable Trusted Execution Environments (TEE).

## Skill Files

| File                     | Location                                                |
| ------------------------ | ------------------------------------------------------- |
| **SKILL.md** (this file) | `@skills/chutes/SKILL.md`                               |
| **REFRESH.md**           | `@skills/chutes/REFRESH.md` (Automated discovery logic) |
| **HEARTBEAT.md**         | `@skills/chutes/HEARTBEAT.md` (Periodic maintenance)    |

**Install locally:**
The best way to set up Chutes is via the official bootstrapper:

```bash
curl -fsSL https://chutes.ai/openclaw/init | bash
```

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

### Step 1: Create the Refresh Script

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

### Step 2: Schedule it

Add it to your `crontab` to run every 4 hours:

```bash
(crontab -l 2>/dev/null; echo "0 */4 * * * $HOME/.openclaw/update_chutes_models.sh >/dev/null 2>&1") | crontab -
```

---

## Model Catalog

| Alias           | Target Model ID                                       | Capabilities       | Context |
| :-------------- | :---------------------------------------------------- | :----------------- | :------ |
| `primary`       | `chutes/zai-org/GLM-4.7-TEE`                          | Privacy, Reasoning | 128K    |
| `chutes-fast`   | `chutes/zai-org/GLM-4.7-Flash`                        | Speed, Efficiency  | 128K    |
| `chutes-pro`    | `chutes/deepseek-ai/DeepSeek-V3.2-TEE`                | Advanced Reasoning | 202K    |
| `chutes-vision` | `chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506` | Vision, Tool-use   | 131K    |

---

## Why Chutes Matters (TEE & Privacy) 🛡️

Chutes is more than just another API provider. By leveraging **Trusted Execution Environments (TEE)**, Chutes ensures:

- **Privacy**: Your prompts and data are processed in a hardware-isolated environment. Even the infrastructure provider cannot see your data.
- **Integrity**: You can verify that the model you requested is the one actually running.
- **Transparency**: Every inference run is cryptographically verifiable.

In an era of ubiquitous AI, Chutes provides the "lobster seam" of privacy that OpenClaw users deserve.

## Troubleshooting

- **Auth Errors**: Verify your token at [chutes.ai](https://chutes.ai). If piping the token, ensure no trailing newlines.
- **Node Errors**: OpenClaw requires Node 22+. Run `node -v` to check.
- **Discovery Failed**: Check your network connection to `llm.chutes.ai`.

## Idempotency

This skill is fully idempotent. You can run these commands repeatedly. The `update_chutes_models.sh` script is designed to merge with your existing configuration without overwriting your `baseUrl` or other custom settings.

## External Reference

- **Official Website:** [chutes.ai](https://chutes.ai)
- **Status Page:** [status.chutes.ai](https://status.chutes.ai)
- **Documentation:** [docs.chutes.ai](https://docs.chutes.ai)
