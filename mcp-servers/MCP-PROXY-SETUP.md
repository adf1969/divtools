# mcp-proxy Installation & Setup Guide
# Last Updated: 2/5/2025 9:50:00 PM CST

## Installation Summary

✅ **COMPLETED**: mcp-proxy is now installed and configured

### What Was Done

1. **Installed mcp-proxy** via pip3 into your divtools virtual environment
   - Location: `/home/divix/divtools/scripts/venvs/dthostmon/lib/python3.12/site-packages/mcp_proxy/`
   - Version: 0.10.0

2. **Created wrapper script** for easy access
   - Location: `/home/divix/divtools/scripts/mcp-proxy`
   - Purpose: Wraps the Python module to make it accessible from command line
   - Permissions: Executable

3. **Updated mcp.json** to use the wrapper script
   - Updated: `/home/divix/divtools/.vscode/mcp.json`
   - Changed from: `"command": "mcp-proxy"`
   - Changed to: `"command": "/home/divix/divtools/scripts/mcp-proxy"`

## Installation Location & Architecture

### Directory Structure
```
/home/divix/divtools/
├── scripts/
│   └── mcp-proxy                                    ← Wrapper script (executable)
├── scripts/venvs/dthostmon/
│   └── lib/python3.12/site-packages/
│       └── mcp_proxy/                               ← Actual Python package
└── .vscode/
    └── mcp.json                                     ← Configuration (updated)
```

### How It Works

When VS Code calls `mcp-proxy`:

```
VS Code Copilot
    ↓ (calls)
/home/divix/divtools/scripts/mcp-proxy
    ↓ (wrapper script)
/home/divix/divtools/scripts/venvs/dthostmon/bin/python -m mcp_proxy
    ↓ (runs Python module)
mcp-proxy 0.10.0
    ↓ (connects to)
http://10.1.1.215:8123/api/mcp
    ↓
Home Assistant MCP Server
```

## Testing the Installation

### Test 1: Verify wrapper script works

```bash
/home/divix/divtools/scripts/mcp-proxy --version
```

Expected output:
```
__main__.py 0.10.0
```

### Test 2: Test connection to Home Assistant (when MCP is enabled)

```bash
/home/divix/divtools/scripts/mcp-proxy \
  --transport=streamablehttp \
  --stateless \
  --headers Authorization "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIxY2Y2NjRhZTcyZGI0MjkyYmM5ZDNiYmQ5MDdkYjNjZSIsImlhdCI6MTc2MzU3NDQ2MSwiZXhwIjoyMDc4OTM0NDYxfQ.IjL0NbE9rOsNvdlz8W5LCQ31Fn4HtWVto-P4vnIDETY" \
  http://10.1.1.215:8123/api/mcp
```

This should connect and show a prompt waiting for MCP messages.

### Test 3: Direct pip verification

```bash
/home/divix/divtools/scripts/venvs/dthostmon/bin/python -m pip show mcp-proxy
```

Expected output:
```
Name: mcp-proxy
Version: 0.10.0
Summary: A proxy for MCP (Model Context Protocol) servers
...
```

## Next Steps (On Your Home Assistant Instance)

To complete the setup, you need to enable the MCP Server in Home Assistant:

### 1. Enable MCP Server Integration

1. Go to Home Assistant: `http://10.1.1.215:8123`
2. Navigate to: **Settings → Devices & Services**
3. Click blue **"Create Integration"** button
4. Search for: **"Model Context Protocol Server"**
5. Click to add it
6. Complete the configuration flow

### 2. Create Long-Lived Access Token

1. Go to: **Settings → Account → Security** (scroll to bottom)
2. Find: **"Long-Lived Access Tokens"**
3. Click: **"Create Token"**
4. Name it: `mcp-proxy` or similar
5. Copy the token value

**Note**: The token in `.vscode/mcp.json` is already set to your existing one, so if it's correct, no changes needed.

### 3. Expose Devices You Want to Control

1. Go to: **Settings → Voice assistants**
2. Scroll to: **"Expose devices"**
3. Toggle on the devices/areas you want accessible to the MCP client
4. Save

### 4. Verify MCP Server Control Permission

1. Go to: **Settings → Devices & Services**
2. Click on: **"Model Context Protocol Server"**
3. Look for: **"Control Home Assistant"** toggle
4. Toggle **ON** if you want Copilot to be able to control devices
5. Toggle **OFF** if you only want read-only access

## Wrapper Script Details

File: `/home/divix/divtools/scripts/mcp-proxy`

```bash
#!/bin/bash
# mcp-proxy wrapper script
VENV_PYTHON="/home/divix/divtools/scripts/venvs/dthostmon/bin/python"
MCP_PROXY_MODULE="-m mcp_proxy"
exec "$VENV_PYTHON" $MCP_PROXY_MODULE "$@"
```

**What it does**:
- Uses Python from the divtools virtual environment
- Loads the mcp_proxy module
- Passes all arguments (`"$@"`) through to mcp-proxy
- Uses `exec` to replace the script process (efficient)

## Adding mcp-proxy to System PATH (Optional)

If you want to use `mcp-proxy` from anywhere without the full path:

```bash
# Create symlink in a PATH directory
sudo ln -s /home/divix/divtools/scripts/mcp-proxy /usr/local/bin/mcp-proxy

# Test it
mcp-proxy --version
```

## mcp-proxy Command Reference

### Basic Usage

**Connect to SSE server (what we use)**:
```bash
mcp-proxy --transport=streamablehttp --stateless http://10.1.1.215:8123/api/mcp
```

**Connect to stdio server**:
```bash
mcp-proxy some-command
```

**Run multiple servers**:
```bash
mcp-proxy \
  --named-server "server1" "command1" \
  --named-server "server2" "command2"
```

### Common Options

```bash
# Verify SSL certificates (default)
--verify-ssl

# Skip SSL verification (for self-signed certs)
--no-verify-ssl

# Set debug logging
--debug

# Set log level (debug, info, warning, error)
--log-level debug

# Set custom headers
-H Authorization "Bearer TOKEN"

# Use SSE transport (default)
--transport sse

# Use streamablehttp transport
--transport streamablehttp

# Stateless mode (no connection state)
--stateless
```

### Current Configuration

Your `.vscode/mcp.json` uses:
```
--transport=streamablehttp  # Protocol for Home Assistant
--stateless                 # No connection state needed
http://10.1.1.215:8123/api/mcp  # Home Assistant MCP endpoint
```

## Troubleshooting

### "command not found: mcp-proxy"

If you see this error in VS Code:
1. Reload VS Code: Command Palette → "Developer: Reload Window"
2. Verify wrapper script exists: `ls -la /home/divix/divtools/scripts/mcp-proxy`
3. Verify it's executable: `ls -l /home/divix/divtools/scripts/mcp-proxy` should show `x` permission

### "Connection refused"

Usually means Home Assistant MCP server isn't enabled:
1. Go to Home Assistant Settings → Devices & Services
2. Check if "Model Context Protocol Server" integration is listed
3. If not, click "Create Integration" and add it

### "401 Unauthorized"

Wrong or expired access token:
1. Get a fresh long-lived access token from Home Assistant
2. Update it in `.vscode/mcp.json` in the `API_ACCESS_TOKEN` field
3. Reload VS Code

### "404 Not Found"

Home Assistant doesn't have the MCP endpoint:
1. Verify Home Assistant version is 2025.2 or later
2. Make sure MCP Server integration is installed and enabled
3. Check the URL is correct: `http://10.1.1.215:8123/api/mcp`

## Verification Checklist

- [x] mcp-proxy installed (version 0.10.0)
- [x] Wrapper script created at `/home/divix/divtools/scripts/mcp-proxy`
- [x] Wrapper script is executable
- [x] mcp.json updated to use wrapper script
- [ ] Home Assistant MCP Server integration enabled (user action)
- [ ] Long-lived access token created (user action)
- [ ] Devices exposed in Home Assistant settings (user action)
- [ ] Device reloaded in VS Code after enabling integration (user action)

## References

- **mcp-proxy GitHub**: https://github.com/sparfenyuk/mcp-proxy
- **mcp-proxy PyPI**: https://pypi.org/project/mcp-proxy/
- **Home Assistant MCP Server**: https://www.home-assistant.io/integrations/mcp_server/
- **MCP Specification**: https://modelcontextprotocol.io/
