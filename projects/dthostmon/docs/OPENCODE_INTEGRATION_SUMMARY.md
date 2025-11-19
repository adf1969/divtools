# OpenCode Server Integration - Summary

## Overview

Successfully integrated OpenCode Server into dthostmon to provide unified, multi-model AI analysis without managing individual API keys in the application.

## Changes Made

### 1. Docker Configuration

**Dockerfile Updates:**
- Added `curl` to system dependencies (needed for OpenCode installation)
- Added OpenCode CLI installation: `curl -L https://get.opencode.ai/linux | bash`
- Created `/root/.local/share/opencode` directory for auth files

**dca-dthostmon.yml Updates:**
- Added volume mount: `~/.local/share/opencode/auth.json:/root/.local/share/opencode/auth.json:ro`
- Exposed port 4096 for OpenCode Server: `"4096:4096"`

### 2. AI Analyzer Module

**File:** `src/dthostmon/core/ai_analyzer.py`

**Replaced entire implementation:**
- Removed direct Grok and Ollama API calls
- Removed `_call_grok()` and `_call_ollama()` methods
- Added `OpenCodeServerManager` class to manage headless server

**New Features:**
- Automatic OpenCode Server startup in headless mode
- Discovers available authenticated models via `/config/providers` endpoint
- Tries preferred models in order: Grok → Claude → GPT-4 → Ollama
- REST API integration for sending prompts: `/session/:id/message`
- Automatic fallback if models unavailable

**Model Priority List:**
1. `grok/grok-beta` (primary)
2. `anthropic/claude-3-5-sonnet` (fallback)
3. `openai/gpt-4` (fallback)
4. `ollama/llama3.1` (local fallback)

### 3. Configuration Updates

**config/dthostmon.yaml:**
- Replaced individual model config with unified OpenCode config:
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

**.env file:**
- Removed `GROK_API_KEY`, `GROK_API_URL`, `OLLAMA_HOST`, `OLLAMA_MODEL`
- Added comments explaining OpenCode authentication via host `opencode auth login`
- No API keys needed in environment file anymore

### 4. Documentation

**PRD Updates (docs/PRD.md):**
- Updated "AI Model Integration" section
- Added detailed "AI Integration - OpenCode Server Architecture" section
- Documented:
  - How OpenCode Server works in headless mode
  - Benefits of unified architecture
  - Supported models
  - API endpoints used
  - Configuration example

**PROJECT-HISTORY Updates (docs/PROJECT-HISTORY.md):**
- Added new architectural decision: "AI Model Integration: OpenCode Server (Headless Mode)"
- Explained problem (managing multiple API keys)
- Documented solution and architecture
- Benefits vs original approach
- Setup instructions in YAML format

**README Updates (README.md):**
- Added OpenCode CLI to prerequisites
- Added "AI Model Setup" section with quick start instructions
- Noted that API keys no longer needed in .env
- Referenced OPENCODE_SETUP.md for detailed instructions

**New File: OPENCODE_SETUP.md**
- Comprehensive setup guide for OpenCode authentication
- Step-by-step instructions
- Multiple provider examples
- Troubleshooting section
- Security considerations
- Verification steps

### 5. No Environment File Changes Required

The .env file now has:
```env
# Authentication handled via OpenCode Server
# Run on host: opencode auth login
# No API keys needed here
```

This is a significant simplification - all authentication is on the host, not in the application.

## Benefits

1. **Single Credential Management Point:** Host-level setup, not application-level
2. **No API Keys in Code:** Credentials never exposed in config files or environment variables
3. **Easy Model Switching:** Add new provider on host with `opencode auth login`, automatically available
4. **Fallback Support:** Multiple models with automatic fallback
5. **Offline Support:** Local Ollama always available as fallback
6. **Future-Proof:** Any model that OpenCode supports is automatically supported by dthostmon

## User Instructions

### For dthostmon Users

1. **On your divtools host:**
   ```bash
   curl -L https://get.opencode.ai/linux | bash
   opencode auth login  # Choose your AI provider(s)
   ```

2. **Start dthostmon:**
   ```bash
   docker compose up
   ```

3. **That's it!** Docker automatically uses your authenticated providers.

### Adding New Models Later

Just run on host:
```bash
opencode auth login  # Add new provider
docker compose restart  # Restart container
```

No code changes needed!

## Technical Details

### OpenCode Server Integration Points

- **Server Management:** Automatically starts in headless mode (port 4096)
- **Model Discovery:** Queries `/config/providers` to find available models
- **Analysis Requests:** Sends prompts via `/session/:id/message` endpoint
- **Authentication:** Uses credentials from `~/.local/share/opencode/auth.json`

### Supported Models (Depends on OpenCode Auth)

Via OpenCode, dthostmon can use:
- Grok Code Fast 1 (x.ai)
- Anthropic Claude (various versions)
- OpenAI GPT-3.5, GPT-4, GPT-4o
- Ollama (local models)
- Any other model that OpenCode supports

## Files Changed

1. `dthostmon.Dockerfile` - Added OpenCode installation
2. `dca-dthostmon.yml` - Added auth volume mount and port 4096
3. `src/dthostmon/core/ai_analyzer.py` - Complete rewrite for OpenCode
4. `config/dthostmon.yaml` - Unified AI configuration
5. `.env` - Removed API key variables
6. `docs/PRD.md` - Updated architecture section
7. `docs/PROJECT-HISTORY.md` - Added architectural decision documentation
8. `README.md` - Updated setup instructions
9. `OPENCODE_SETUP.md` - New comprehensive setup guide

## Migration Notes

If upgrading from previous version:
1. You don't need to update `.env` API keys anymore
2. Instead, run `opencode auth login` on your host once
3. Docker container automatically uses authenticated providers
4. All existing code that calls AIAnalyzer works unchanged

## Next Steps

- Users should follow OPENCODE_SETUP.md to configure their AI providers
- Test with different models to find preferred provider for their use case
- Consider adding model-specific prompt tuning based on provider capabilities
