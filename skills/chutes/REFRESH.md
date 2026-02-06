# Chutes Model Refresh Guide

This document describes how to maintain a fresh list of Chutes models. Since Chutes is a high-velocity platform, hardcoding model IDs is not recommended.

## Automated Discovery Logic

The following logic is used to synchronize the Chutes model catalog with your local OpenClaw configuration.

### The Logic Loop

1. **Fetch**: Query `https://llm.chutes.ai/v1/models`.
2. **Map**: Transform the OpenAI-compatible response into OpenClaw's provider model schema.
   - Detect `reasoning` capability from `supported_features`.
   - Map `input_modalities` to OpenClaw's `input` array.
   - Extract pricing into `cost`.
3. **Patch**: Retrieve current `models.providers.chutes` config, replace only the `models` key with the new list, and write it back.

### Implementation (Node.js snippet)

If you are writing a custom tool to do this, use this pattern:

```javascript
const response = await fetch("https://llm.chutes.ai/v1/models");
const { data } = await response.json();

const models = data.map((m) => ({
  id: m.id,
  name: m.id,
  reasoning: m.supported_features?.includes("reasoning") || false,
  input: (m.input_modalities || ["text"]).filter((i) => i === "text" || i === "image"),
  cost: {
    input: m.pricing?.prompt || 0,
    output: m.pricing?.completion || 0,
  },
  contextWindow: m.context_length || 128000,
  maxTokens: m.max_output_length || 4096,
}));

// Use OpenClaw CLI or API to patch config
// openclaw config set models.providers.chutes.models --json JSON.stringify(models)
```

## Scheduling

### Cron (Linux/macOS/WSL)

Run every 4 hours to catch new model releases:

```cron
0 */4 * * * /path/to/update_chutes_models.sh
```

### Task Scheduler (Windows)

Create a task that runs `powershell.exe -File C:\path\to\update_chutes_models.ps1` every 4 hours.

## Why Refresh?

Chutes often adds specialized models for specific use cases (e.g., medical, coding, or high-security TEE variants). By automating the refresh, your agent will automatically see these new models in `openclaw models status` and can use them immediately via their full ID.
