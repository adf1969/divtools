# OpenCode Server Setup Guide for dthostmon

## Overview

dthostmon uses OpenCode Server in headless mode to provide unified access to multiple AI models (Grok, Claude, GPT-4, Ollama, etc.) without managing individual API keys in the application.

## Prerequisites

1. OpenCode CLI installed on your system
   ```bash
   curl -L https://get.opencode.ai/linux | bash
   ```

2. Docker installed with Docker Compose

## Setup Steps

### 1. Authenticate with Providers on Host

Run this command on your divtools host to configure authentication with AI providers:

```bash
opencode auth login
```

This interactive command will guide you through:
- Selecting a provider (Grok, OpenAI, Anthropic, Ollama, etc.)
- Entering your API key for that provider
- Credentials are saved to `~/.local/share/opencode/auth.json`

You can add multiple providers by running the command multiple times.

**Example:**
```bash
# Add Grok support
opencode auth login
# -> Select "Grok"
# -> Enter your Grok API key from x.ai

# Add OpenAI support
opencode auth login
# -> Select "OpenAI"
# -> Enter your OpenAI API key

# List authenticated providers
opencode auth list
```

### 2. Verify Authentication File

The authentication file is created automatically:

```bash
cat ~/.local/share/opencode/auth.json
```

This file will contain your credentials in a structured format. It's mounted read-only into the Docker container.

### 3. Start dthostmon

The Docker container will automatically:
1. Mount `~/.local/share/opencode/auth.json` from host
2. Start OpenCode Server in headless mode on port 4096
3. Access all authenticated models without API keys in the application

```bash
cd /home/divix/divtools/projects/dthostmon
docker compose up
```

### 4. Verify Setup

Check that OpenCode Server is running and accessible:

```bash
# From host
curl http://localhost:4096/config/providers

# From inside container
docker compose exec dthostmon curl http://localhost:4096/config/providers
```

You should see a list of available providers and their models.

## Model Preference Order

dthostmon tries models in this order:

1. **grok/grok-beta** - Grok Code Fast 1 (primary choice)
2. **anthropic/claude-3-5-sonnet** - Claude 3.5 Sonnet (fallback)
3. **openai/gpt-4** - GPT-4 (fallback)
4. **ollama/llama3.1** - Local Ollama (always available)

The application uses the first available authenticated model from this list.

## Configuration

The OpenCode configuration is in `config/dthostmon.yaml`:

```yaml
ai:
  opencode:
    host: localhost
    port: 4096
    auto_start: true
    preferred_models:
      - grok/grok-beta
      - anthropic/claude-3-5-sonnet
      - openai/gpt-4
      - ollama/llama3.1
```

To modify preferred models or server settings, edit this file.

## Troubleshooting

### OpenCode Server won't start

Check if OpenCode CLI is properly installed:
```bash
opencode --version
```

Install or update if needed:
```bash
curl -L https://get.opencode.ai/linux | bash
```

### No models available

Verify you've authenticated with at least one provider:
```bash
opencode auth list
```

If empty, run:
```bash
opencode auth login
```

### Can't connect to OpenCode Server from application

Check if the server is running:
```bash
curl http://localhost:4096/app
```

If it's not running, check Docker logs:
```bash
docker compose logs dthostmon
```

### Specific model not available

Check available authenticated models:
```bash
opencode models
```

The output shows available models in format `provider/model`. These match the `preferred_models` list in config.

### Using local Ollama without API keys

Ollama is always available if installed locally:
```bash
# Check if Ollama is running
curl http://localhost:11434

# Pull a model if needed
ollama pull llama2
```

dthostmon will automatically use Ollama as final fallback.

## Docker Volume Mounts

The auth file is mounted as read-only:

```yaml
volumes:
  - ~/.local/share/opencode/auth.json:/root/.local/share/opencode/auth.json:ro
```

This means:
- Your host credentials are safe (read-only in container)
- Container can access credentials for authentication
- Changes on host are immediately available to container

## Adding New Providers Later

To add a new AI provider after initial setup:

1. On host: `opencode auth login` (select new provider)
2. Restart container: `docker compose restart`
3. Application automatically uses new provider

No code or configuration file changes needed!

## Security Considerations

1. **API Keys:** Never stored in application code or config files
2. **Host Credentials:** Mounted read-only into container
3. **No Environment Variables:** Don't hardcode API keys in `.env`
4. **Encryption:** OpenCode stores credentials securely in `auth.json`

## Environment File

The `.env` file NO LONGER needs individual API keys:

```env
# OLD (don't use):
# GROK_API_KEY=xxxx
# OPENAI_API_KEY=xxxx

# NEW (authentication via OpenCode Server):
# No API keys needed here - all handled by ~/.local/share/opencode/auth.json
```

## Further Reading

- [OpenCode CLI Documentation](https://opencode.ai/docs/cli/)
- [OpenCode Server Documentation](https://opencode.ai/docs/server/)
- [OpenCode Authentication](https://opencode.ai/docs/cli/#auth)
