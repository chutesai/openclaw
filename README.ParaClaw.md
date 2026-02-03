# ParaClaw: Chutes x OpenClaw Integration

This branch implements a production-hardened, zero-PR adoption path for integrating Chutes AI into OpenClaw.

## Integration Highlights

1. **Integrated Onboarding**: Chutes AI is now a first-class `AuthChoice` in the core onboarding logic.
2. **Atomic Configuration**: Setup combines Providers, Models, Vision, and Aliases into a single schema-safe operation.
3. **Secure Secrets**: API keys are stored in isolated `auth-profiles.json`, never in `openclaw.json`, with auto-redaction from terminal history.
4. **Dynamic Discovery**: Latest model catalog is fetched directly from the Chutes API during setup.
5. **Cross-Platform**: Full parity support for macOS, Linux, and native Windows.

## Usage

### Route 1: Agent-First Skill (Autonomous)

Instruct an OpenClaw agent:
"Follow the instructions at `skills/chutes/SKILL.md` to set up Chutes."

### Route 2: Human-First Bootstrap (Onboarding)

#### Unified Installer (Recommended)

This script automatically detects your OS (macOS, Linux, WSL, or Git Bash) and routes to the correct installer:

```bash
curl -fsSL https://chutes.ai/openclaw/init | sh
```

#### Manual OS-Specific Installers

- **macOS/Linux**: `curl -fsSL https://chutes.ai/openclaw/init.sh | bash`
- **Windows (PowerShell)**: `curl -fsSL https://chutes.ai/openclaw/init.ps1 | powershell -ExecutionPolicy Bypass -File -`

---

## Local Development & Testing

If you are a developer or tester working on this branch, you can run the bootstrap logic directly from your local clone to verify changes before they go live.

### 1. Initial Setup

Clone the repository and switch to the development branch:

```bash
git clone https://github.com/chutesai/openclaw.git
cd openclaw
git checkout ParaClaw
```

### 2. Run the Bootstrap

Run the installer directly from the reference folder:

**macOS / Linux / WSL / Git Bash:**

```bash
bash external-reference/chutes-route2/init.sh
```

**Windows (PowerShell):**

```powershell
.\external-reference\chutes-route2\init.ps1
```

### 3. Clean Testing (Reset)

To test the "New User" journey multiple times, use the provided reset script to completely wipe your local OpenClaw environment:

```bash
# This will uninstall OpenClaw and delete ~/.openclaw
bash external-reference/chutes-route2/reset.sh
```

---

## Hardening Features

- **Reliability**: Monitors Gateway health during startup and automatically tails logs if initialization fails.
- **Safety**: Interactive onboarding is automatically skipped in non-TTY environments (CI/CD) to prevent hangs.
- **UX**: Real-time progress indicators for long-running operations (installations, gateway boot).
- **WSL Support**: Native detection and IP resolution for Windows Subsystem for Linux.
- **CI Ready**: Support for `--no-color` flag for clean log capture in automated environments.

## Technical Notes

- The bootstrap script uses `--auth-choice skip` for the core onboarding wizard to prevent redundant auth prompts, as it handles Chutes auth securely beforehand.
- All configuration updates are schema-validated using official CLI tools.
- A beautiful instance summary card is displayed at the end of every successful setup.
