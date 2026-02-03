# OpenClaw Config Structure Reference

Reference for understanding the config schema that the bootstrap script needs to work with.

## Config File Location
```
~/.openclaw/openclaw.json
```

## Gateway Mode
Required for gateway to start:
```json
{
  "gateway": {
    "mode": "local"
  }
}
```

## Models Provider Config
```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "chutes": {
        "baseUrl": "https://llm.chutes.ai/v1",
        "api": "openai-completions",
        "models": [
          {
            "id": "zai-org/GLM-4.7-Flash",
            "name": "GLM 4.7 Flash",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 128000,
            "maxTokens": 4096,
            "cost": {
              "input": 0,
              "output": 0,
              "cacheRead": 0,
              "cacheWrite": 0
            }
          }
        ]
      }
    }
  }
}
```

## Auth Profile Reference
Auth profiles are stored separately and referenced in config:
```json
{
  "auth": {
    "profiles": {
      "chutes:default": {
        "mode": "api_key"
      }
    }
  }
}
```

The actual credentials are stored in:
```
~/.openclaw/agents/<agentId>/agent/auth-profiles.json
```

## Default Model Config
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

## Important Notes

1. **No secrets in config**: API keys are stored in auth-profiles, not in `openclaw.json`
2. **Schema validation**: Config is validated against a strict schema at startup
3. **Config patching**: Use `openclaw config set` or gateway `config.patch` for safe updates
4. **Hot reload**: Some config changes can be hot-reloaded, others require gateway restart
