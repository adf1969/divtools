# Home Assistant Official MCP Server Guide
# Last Updated: 2/5/2025 9:30:00 PM CST

## Overview

**Home Assistant MCP Server** is the **official**, native Model Context Protocol integration in Home Assistant. It's built into Home Assistant Core as of version 2025.2 and provides native integration between LLM clients (like Claude Desktop, Cursor, VS Code Copilot) and your Home Assistant instance.

**Repository**: https://github.com/home-assistant/core/tree/dev/homeassistant/components/mcp_server

## What This Means for You

✅ **Official**: Maintained by Home Assistant core team
✅ **Native**: Built into Home Assistant, no separate packages needed
✅ **Reliable**: Uses proven Assist API backend
✅ **Exposed Entities**: Respects Home Assistant's exposed entities (security)
✅ **Transport Agnostic**: Supports both stdio and HTTP with SSE (Server-Sent Events)

## Architecture

### How It Works

```
Claude Desktop (MCP Client)
    ↓
mcp-proxy (local gateway - stdio transport)
    ↓
HTTP/SSE to Home Assistant
    ↓
Home Assistant MCP Server integration
    ↓
Home Assistant Assist API
    ↓
Your entities & automations
```

### Two Transport Modes

1. **Stdio** (requires mcp-proxy gateway)
   - What we're using in VS Code Copilot
   - Local MCP proxy bridges stdio ↔ HTTP/SSE
   - Works with Claude Desktop, Cursor, VS Code

2. **Streamable HTTP with SSE** (direct)
   - Home Assistant natively supports this
   - Stateless protocol
   - More efficient for remote connections

## Installation Steps

### Step 1: Install MCP Server in Home Assistant

The MCP server is **built into Home Assistant Core 2025.2+**. You just need to enable it:

1. Go to: **Settings → Devices & Services**
2. Click the blue **"Create Integration"** button
3. Search for **"Model Context Protocol Server"**
4. Click to add it
5. Complete the setup flow

This creates the `/api/mcp` endpoint on your Home Assistant instance.

### Step 2: Create Long-Lived Access Token

You need an access token for authentication:

1. Go to: **Settings → Account → Security** (bottom of page)
2. Scroll to **"Long-Lived Access Tokens"**
3. Click **"Create Token"**
4. Name it: `MCP Client` or similar
5. Copy the token (you'll use it in next step)

**⚠️ IMPORTANT**: Store this safely. VS Code already has your token in `.vscode/mcp.json`.

### Step 3: Install mcp-proxy Locally

The `mcp-proxy` package bridges stdio ↔ HTTP for clients that only support stdio:

```bash
# Using uv (recommended)
uv tool install git+https://github.com/sparfenyuk/mcp-proxy

# Or using pip
pip install mcp-proxy
```

Verify installation:
```bash
mcp-proxy --help
```

### Step 4: VS Code Configuration (Already Done)

Your `.vscode/mcp.json` is already configured:

```json
{
  "servers": {
    "homeassistant": {
      "command": "mcp-proxy",
      "args": [
        "--transport=streamablehttp",
        "--stateless",
        "http://10.1.1.215:8123/api/mcp"
      ],
      "env": {
        "API_ACCESS_TOKEN": "<your_token>"
      },
      "type": "stdio"
    }
  }
}
```

## What Tools Are Available?

### The MCP Server Exposes Tools from Home Assistant's Assist API

The tools available depend on your **configured LLM in Home Assistant**. The MCP server doesn't define its own tools—it exposes whatever tools your conversation agent supports.

### Typical Tools Available (based on Assist API)

1. **Entity Control**
   - Turn lights on/off
   - Adjust brightness
   - Set color temperature / RGB color
   - Control climate (heating/cooling)
   - Control locks, covers, switches
   - Control media players
   - etc.

2. **Entity Queries**
   - Get state of any entity
   - Get properties and attributes
   - Get history (if enabled)
   - List devices by domain (lights, switches, etc.)

3. **Automations**
   - Trigger automations
   - List automations
   - Get automation status

4. **Information**
   - Get system information
   - List areas
   - List devices
   - Get weather information
   - etc.

### Example Tools You Can Use

Based on your exposed entities:

```
# Lights
- Turn on/off lights
- Set brightness (0-100%)
- Set color temperature (mireds or Kelvin)
- Set RGB color [R, G, B]

# Switches
- Turn on/off any switch
- Get switch state

# Locks
- Lock/unlock doors
- Get lock status

# Climate
- Set temperature
- Set mode (heat, cool, auto)
- Set fan mode

# Covers
- Open/close blinds
- Set position

# Media Players
- Play/pause
- Next/previous track
- Set volume
- Select source
```

## List Devices Capability

### ✅ YES - You Can List Devices

The MCP server exposes the Assist API which includes device discovery:

**What you can get:**
- All devices in your Home Assistant
- Devices by area (Living Room, Bedroom, etc.)
- Entities within each device
- Entity states and attributes
- Entity properties and capabilities

**How to use it in Copilot:**
```
"List all my light entities"
"Show me all switches in the kitchen"
"What devices do I have in the bedroom?"
"List all the thermostats"
```

The AI will use the exposed device/entity tools to retrieve this information.

### Exposure Control

**Important**: You control what devices the MCP client can see via:

**Settings → Voice assistants → Expose devices**

Only devices you expose here will be available to the MCP client. This is a security feature.

## Make Changes to Devices

### ✅ YES - You Can Control Devices

The MCP server fully supports entity control through the Assist API:

**Supported Actions:**
- Turn devices on/off
- Set attributes (brightness, color, temperature, etc.)
- Trigger automations
- Set areas and device assignments

**Configuration Control:**

The MCP Server has a **"Control Home Assistant"** toggle in its settings:

1. Go to: **Settings → Devices & Services → Model Context Protocol Server**
2. Click on the integration
3. Toggle **"Control Home Assistant"** ON
4. Save

When enabled, the MCP client can:
- ✅ Control exposed entities
- ✅ Trigger automations
- ✅ Make state changes
- ❌ Cannot modify configuration
- ❌ Cannot install add-ons
- ❌ Cannot modify automations themselves

## Prompts Feature

The MCP server also exposes **Prompts** from your configured LLM:

These are natural language instructions that tell the AI:
- How to control entities
- What to ask before making changes
- Safety guidelines
- Domain-specific instructions

The AI uses these prompts to stay safe and provide better responses.

## Supported vs Unsupported MCP Features

| Feature | Support | Notes |
|---------|---------|-------|
| **Tools** | ✅ Yes | Expose Assist API tools |
| **Prompts** | ✅ Yes | Configured via LLM |
| **Resources** | ❌ No | Planned for future |
| **Sampling** | ❌ No | Not applicable |
| **Notifications** | ❌ No | Planned for future |

## Security Considerations

1. **Exposed Entities**
   - Only expose entities you want the MCP client to control
   - Settings → Voice assistants → Expose devices

2. **Long-Lived Token**
   - Store securely (don't commit to git)
   - Can be revoked anytime in Account settings
   - Create separate tokens for different clients

3. **Control Toggle**
   - Disable if you only want read-only access
   - Can be enabled/disabled anytime

4. **Network Access**
   - If using remote Home Assistant, ensure firewall rules
   - Use HTTPS/SSL for production
   - Token is sent in Authorization header

## Troubleshooting

### mcp-proxy not found

```bash
# Verify installation
which mcp-proxy

# If not found, install it
uv tool install git+https://github.com/sparfenyuk/mcp-proxy
```

### Connection errors in VS Code

**"MCP Server Home Assistant Disconnected"**

1. Verify Home Assistant is running: `http://10.1.1.215:8123`
2. Check MCP Server integration is enabled in Home Assistant
3. Verify the long-lived token is correct
4. Check mcp-proxy can reach Home Assistant:
   ```bash
   curl http://10.1.1.215:8123/api/mcp \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

### "401 Unauthorized"

- Wrong or expired token
- Create a new long-lived access token
- Update the token in `.vscode/mcp.json`

### "404 Not Found"

- MCP Server integration not enabled in Home Assistant
- Add the integration via Settings → Devices & Services

## Next Steps

1. **Enable MCP Server in Home Assistant**
   - Go to Settings → Devices & Services
   - Create Model Context Protocol Server integration

2. **Create Long-Lived Token**
   - Settings → Account → Security
   - Create and note the token

3. **Verify mcp-proxy is Installed**
   ```bash
   which mcp-proxy
   ```

4. **Reload VS Code**
   - Command Palette: "Developer: Reload Window"
   - Or restart VS Code entirely

5. **Test in Copilot Chat**
   ```
   "List all my lights"
   "Turn on the office lights"
   "Show me all devices in the living room"
   ```

## Comparison with Previous Approaches

| Approach | Type | Schema Issues | Maintenance | Official |
|----------|------|---------------|-------------|----------|
| **Official MCP** | Built-in | ✅ No | ✅ Built-in | ✅ Yes |
| **jango-mcp** | 3rd party | ❌ Yes (RGB) | ❓ Community | ❌ No |
| **home-assistant-mcp-server** | 3rd party | ❓ Unknown | ❓ Community | ❌ No |
| **Local MCP** | Custom | ✅ Controlled | ⚠️ Manual | ❌ No |

**Recommendation**: Use the **Official MCP Server**—it's the most reliable and well-maintained.

## References

- **Official Integration**: https://www.home-assistant.io/integrations/mcp_server/
- **MCP Specification**: https://modelcontextprotocol.io/
- **Assist API**: Part of Home Assistant Core conversation support
- **mcp-proxy GitHub**: https://github.com/sparfenyuk/mcp-proxy
- **Home Assistant Exposed Devices**: https://www.home-assistant.io/voice_control/voice_remote_expose_devices/

## Status

- [x] Official MCP Server integration available in Home Assistant
- [x] VS Code mcp.json configured for mcp-proxy
- [ ] MCP Server enabled in Home Assistant (user action required)
- [ ] mcp-proxy installed locally (user action required)
- [ ] Long-lived token created (user action required)
- [ ] Devices exposed in Home Assistant settings (user action required)
