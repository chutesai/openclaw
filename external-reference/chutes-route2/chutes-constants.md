# Chutes Configuration Constants

Reference values for building the Route 2 bootstrap script.

## Base URL
```
CHUTES_BASE_URL="https://llm.chutes.ai/v1"
```

## Default Model
```
CHUTES_DEFAULT_MODEL_ID="zai-org/GLM-4.7-Flash"
CHUTES_DEFAULT_MODEL_REF="chutes/zai-org/GLM-4.7-Flash"
```

## Model Specifications
```
CHUTES_DEFAULT_CONTEXT_WINDOW=128000
CHUTES_DEFAULT_MAX_TOKENS=4096
```

## Provider Config Structure

The provider config that needs to be applied:

```json
{
  "models": {
    "providers": {
      "chutes": {
        "baseUrl": "https://llm.chutes.ai/v1",
        "api": "openai-completions"
      }
    }
  }
}
```

## Default Model Config

To set Chutes as the default model:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "chutes/zai-org/GLM-4.7-Flash"
      }
    }
  }
}
```

## Model Catalog

Available Chutes models (for reference/display):

1. `chutes/zai-org/GLM-4.7-Flash` - Default, fast, general-purpose
2. `chutes/deepseek-ai/DeepSeek-V3.2-TEE` - Pro/Reasoning, tools-capable
3. `chutes/Qwen/Qwen3-32B` - High performance, tools-capable
4. `chutes/chutesai/Mistral-Small-3.2-24B-Instruct-2506` - Balanced performance vision model
5. `chutes/chutesai/Mistral-Small-3.1-24B-Instruct-2503` - Balanced performance, tools
6. `chutes/NousResearch/Hermes-4-14B` - Compact and efficient, tools
