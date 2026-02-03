---
name: chutes
description: Configure Chutes as your AI model provider. Chutes provides access to high-performance models including GLM, Kimi, Qwen, DeepSeek, and more.
homepage: https://chutes.ai
metadata:
  {
    "openclaw":
      {
        "emoji": "🚀",
        "requires": {},
      },
  }
---

# Chutes Model Provider

Configure Chutes as your OpenClaw model provider. Chutes offers access to multiple high-performance models.

## Overview

Chutes is an OpenAI-compatible API provider that gives you access to models like:
- **GLM 4.7 Flash** - Fast, efficient general-purpose model
- **Kimi K2.5** - Vision-capable model
- **Qwen 3 235B** - Large model with tools support
- **DeepSeek V3.2** - Advanced model with tools
- **Mistral Small 3.1** - Tools-capable model
- **Hermes 4 14B** - Compact tools model

## Setup Steps

### 1. Check Current Status

First, verify if Chutes is already configured:

```bash
openclaw models status
```

Look for:
- Chutes provider in the list
- Active auth profile for Chutes
- Any existing `CHUTES_API_KEY` environment variable

If Chutes is already configured and working, you can skip to step 5 (Verify Setup).

### 2. Get Your API Key

1. Visit https://chutes.ai
2. Sign up or log in to your account
3. Navigate to your API keys section
4. Create a new API key or copy an existing one

**Important:** Keep your API key secure. Never commit it to version control or share it publicly.

### 3. Add Authentication

Use OpenClaw's official auth command to securely store your API key:

```bash
openclaw models auth paste-token --provider chutes
```

This command will:
- Prompt you to paste your Chutes API key
- Store it securely in the auth-profiles store (`~/.openclaw/agents/<agentId>/agent/auth-profiles.json`)
- **Not** write secrets to `openclaw.json` (config remains clean)

The token is stored per-agent, so each agent can have its own Chutes credentials.

### 4. Apply Provider Configuration

Use the `gateway` tool to apply the Chutes provider configuration. This is schema-safe and hot-reloadable:

```json
{
  "action": "config.patch",
  "raw": "{\"models\":{\"providers\":{\"chutes\":{\"baseUrl\":\"https://llm.chutes.ai/v1\",\"api\":\"openai-completions\"}}}}"
}
```

**Using the gateway tool:**
- Action: `config.patch`
- Raw: JSON5 string with the provider config
- The gateway validates against the schema before applying
- Changes are hot-reloaded if the gateway supports it

**Alternative:** If you prefer CLI, you can use:
```bash
openclaw config set models.providers.chutes.baseUrl "https://llm.chutes.ai/v1"
openclaw config set models.providers.chutes.api "openai-completions"
```

### 5. Set Default Model (Optional)

You can optionally set Chutes as your default model. The recommended default is:

```
chutes/zai-org/GLM-4.7-Flash
```

To set it:
```bash
openclaw config set agents.defaults.model.primary "chutes/zai-org/GLM-4.7-Flash"
```

**Discover available models:**
You can fetch the latest available models from Chutes:
```bash
curl https://llm.chutes.ai/v1/models
```

Or check what OpenClaw has discovered:
```bash
openclaw models status --json | jq '.providers.chutes.models'
```

### 6. Verify Setup

Run a status check to confirm everything is working:

```bash
openclaw models status
```

You should see:
- Chutes provider listed
- Auth profile active (shows `chutes:default` or similar)
- Models available for use

**Optional test completion:**
You can verify the API key works by making a test request through OpenClaw's model system, or by checking the status output for any auth errors.

## Model Catalog

Chutes provides access to these models (reference from OpenClaw's catalog):

### General Purpose

- **`chutes/zai-org/GLM-4.7-Flash`** (Default)
  - Fast, efficient model
  - Context: 128K tokens
  - Max output: 4K tokens
  - Input: text

### Vision Models

- **`chutes/moonshotai/Kimi-K2.5-TEE`**
  - Vision-capable (text + image)
  - Context: 256K tokens
  - Max output: 8K tokens

### Large Models with Tools

- **`chutes/Qwen/Qwen3-235B-A22B-Instruct-2507-TEE`**
  - Tools support
  - Context: 262K tokens
  - Max output: 4K tokens

- **`chutes/deepseek-ai/DeepSeek-V3.2-TEE`**
  - Tools support
  - Context: 202K tokens
  - Max output: 4K tokens

- **`chutes/chutesai/Mistral-Small-3.1-24B-Instruct-2503`**
  - Tools support
  - Context: 131K tokens
  - Max output: 4K tokens

- **`chutes/NousResearch/Hermes-4-14B`**
  - Tools support
  - Context: 40K tokens
  - Max output: 4K tokens

### Model IDs

When referencing models in config or commands, use the provider-qualified format:
- `chutes/<model-id>`

For example:
- `chutes/zai-org/GLM-4.7-Flash`
- `chutes/moonshotai/Kimi-K2.5-TEE`

## Troubleshooting

**Auth profile not found:**
- Re-run `openclaw models auth paste-token --provider chutes`
- Check that the profile was created: `openclaw models status --json | jq '.auth.profiles'`

**Provider not appearing:**
- Verify config was applied: `openclaw config get models.providers.chutes`
- Check for schema errors in config: `openclaw doctor`

**API key not working:**
- Verify key is valid at https://chutes.ai
- Check for rate limits or account issues
- Review `openclaw models status --json` for detailed error messages

**Models not discovered:**
- OpenClaw will fall back to the built-in catalog if the API is unreachable
- Check network connectivity to `https://llm.chutes.ai`
- Models are discovered on gateway startup or config reload

## Security Notes

- **Never commit API keys** to version control
- API keys are stored in `~/.openclaw/agents/<agentId>/agent/auth-profiles.json` (not in `openclaw.json`)
- Use `openclaw models auth paste-token` instead of manually editing config files
- Each agent can have separate credentials

## Idempotency

This skill is **idempotent** - you can run it multiple times safely:
- It checks existing configuration before making changes
- Won't duplicate auth profiles
- Won't overwrite existing provider config unnecessarily

## External Reference

This skill can also be accessed from:
- **Hosted version:** https://chutes.ai/openclaw/skill.md (for agents to fetch remotely)

Agents can be instructed to follow the instructions at that URL to self-configure Chutes.
