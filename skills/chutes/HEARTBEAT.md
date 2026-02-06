# Chutes Heartbeat

Keep your Chutes integration healthy and up to date.

## Periodic Tasks

### Every 4 Hours: Refresh Models 🚀

Chutes adds models frequently. Don't miss out on the latest performance improvements or TEE variants.

**Action:**
Run `~/.openclaw/update_chutes_models.sh` (or `.ps1`).

### Daily: Check Status 🦞

Verify that your auth profile is still valid and the gateway is reaching Chutes.

**Action:**

```bash
openclaw models status
```

Check for "active" status on the Chutes provider.

### Weekly: Review Primary Models 🛡️

Chutes may release a new "best" model that should become your `primary`.

**Action:**
Check [chutes.ai](https://chutes.ai) or the latest model list. If a new model like `GLM-4.8-TEE` appears, update your config:

```bash
openclaw config set agents.defaults.model.primary "chutes/zai-org/GLM-4.8-TEE"
```

## Why This Matters

A "dead" configuration is a useless configuration. By maintaining a heartbeat, you ensure that your OpenClaw bot is always using the most privacy-preserving and highest-performing models available on the market.
