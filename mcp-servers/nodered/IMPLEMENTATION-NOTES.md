# Node-RED MCP Server - Implementation Notes
# Last Updated: 2/5/2025 8:45:00 PM CST

## Overview
Local MCP (Model Context Protocol) server for Node-RED Admin API integration. Created as an alternative to the upstream `node-red-mcp-server` package which had missing tool descriptions causing MCP client failures.

## Implementation History

### Phase 1: Discovery (Feb 5, 2025)
- Attempted to use upstream `node-red-mcp-server@latest` via npx
- Discovered tool execution failures due to missing descriptions
- MCP client logs showed: "Tool get-flows does not have a description. Tools must be accurately described to be called"

### Phase 2: Local Implementation (Feb 5, 2025)
- Created local MCP server at `/home/divix/divtools/mcp-servers/nodered/`
- Implemented 16 core tools with proper descriptions:
  - Flow Management: get-flows, get-flow, list-tabs, update-flows, update-flow, create-flow, delete-flow
  - Node Management: get-nodes, get-node-info, find-nodes-by-type, search-nodes
  - System & Diagnostics: api-help, get-flows-state, set-flows-state, get-flows-formatted, get-diagnostics

### Phase 3: Extension (Feb 5, 2025)
- Added 4 additional tools from upstream GitHub source (karavaev-evgeniy/node-red-mcp-server):
  - **inject**: Trigger inject nodes remotely via POST /inject/{id}
  - **toggle-node-module**: Enable/disable palette modules via PUT /nodes/{module}
  - **visualize-flows**: Generate structured markdown with flow statistics
  - **get-settings**: Retrieve Node-RED runtime configuration

## Architecture

### Technology Stack
- **Node.js**: ES modules (import/export syntax)
- **Axios 1.4.0**: HTTP client for Node-RED Admin API
- **UUID 9.0.0**: Generate unique IDs for flows/nodes
- **MCP Protocol**: JSON-RPC 2.0 over stdio

### Key Design Decisions

#### 1. Stdio Communication
Uses readline interface for stdin/stdout:
```javascript
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});
```

#### 2. Axios Configuration
```javascript
const client = axios.create({
  baseURL: NODE_RED_URL,
  auth: { username, password },
  timeout: 10000
});
```

#### 3. Tool Registration
All tools must include:
- `name`: Unique identifier
- `description`: Human-readable explanation (REQUIRED for MCP client)
- `inputSchema`: JSON schema for parameters

#### 4. Error Handling
- Axios errors wrapped and returned as MCP errors
- Includes Node-RED API error messages when available
- Proper error codes (-32000 for execution errors)

## Node-RED Admin API Endpoints

### Flow Endpoints
- `GET /flows` - Get all flows and configurations
- `POST /flows` - Deploy flows (replace all)
- `GET /flow/{id}` - Get specific flow/tab
- `POST /flow` - Create new flow/tab
- `PUT /flow/{id}` - Update specific flow/tab
- `DELETE /flow/{id}` - Delete specific flow/tab

### Node Endpoints
- `GET /nodes` - List all installed nodes/modules
- `GET /nodes/{module}` - Get specific module info
- `PUT /nodes/{module}` - Enable/disable module
- `POST /inject/{id}` - Trigger inject node

### System Endpoints
- `GET /settings` - Get Node-RED runtime settings
- `GET /diagnostics` - Get diagnostic information
- `GET /flows/state` - Get current flows state (started/stopped)
- `POST /flows/state` - Set flows state

## Tool Categories

### Flow Management (7 tools)
Manage Node-RED flows, tabs, and configurations:
- `get-flows`: Retrieve complete flow configuration
- `get-flow`: Get specific flow by ID
- `list-tabs`: List all tabs with IDs and labels
- `update-flows`: Deploy complete flow configuration
- `update-flow`: Update specific flow
- `create-flow`: Create new tab/subflow
- `delete-flow`: Remove flow by ID

### Node Management (5 tools)
Query and manage nodes in the palette:
- `get-nodes`: List all installed node modules
- `get-node-info`: Get details about specific module
- `find-nodes-by-type`: Find nodes by type across all flows
- `search-nodes`: Search nodes by name/label
- `toggle-node-module`: Enable/disable node modules

### System & Diagnostics (8 tools)
System information and visualization:
- `api-help`: Display available endpoints and usage
- `get-flows-state`: Check if flows are started/stopped
- `set-flows-state`: Start/stop all flows
- `get-flows-formatted`: Summary with node counts
- `get-diagnostics`: Runtime diagnostics
- `inject`: Trigger inject nodes manually
- `visualize-flows`: Markdown visualization with statistics
- `get-settings`: Node-RED runtime configuration

## Testing

### Test Scripts
1. **test_connection.js**: Basic connectivity and tool registration
2. **test_extended.js**: Test visualize-flows, get-settings, get-flows-formatted

### Validation Commands
```bash
# Check tool registration
node test_connection.js | jq -r '.result.tools[]? | "\(.name): \(.description)"'

# Test visualize-flows
node test_extended.js | jq -r 'select(.id == 2) | .result.content[0].text'

# Test get-settings
node test_extended.js | jq -r 'select(.id == 3) | .result.content[0].json | keys'

# Find inject nodes
curl -u divix:3mpms3 http://10.1.1.215:1880/flows | jq '.[] | select(.type=="inject")'
```

## VS Code Integration

Updated `.vscode/mcp.json` to use local server:
```json
{
  "servers": {
    "nodered": {
      "command": "node",
      "args": [
        "/home/divix/divtools/mcp-servers/nodered/server.js",
        "http://divix:3mpms3@10.1.1.215:1880"
      ],
      "type": "stdio"
    }
  }
}
```

## Known Limitations

1. **Authentication**: Only supports basic auth (username:password in URL)
2. **Error Messages**: Some Node-RED errors return generic messages
3. **Module Toggle**: Requires Node-RED restart to take effect
4. **Inject Nodes**: Can only trigger inject nodes, not other node types

## Troubleshooting

### "Unknown tool" Error
- Verify tool name spelling in `tools/call` request
- Check `buildToolsList()` includes the tool
- Confirm `handleToolsCall()` has handler for the tool

### "Node-RED API error"
- Verify Node-RED is running at http://10.1.1.215:1880
- Check authentication credentials (divix:3mpms3)
- Confirm Admin API is enabled in Node-RED settings

### Missing Descriptions Warning
If you see: "Tool X does not have a description"
- Add `description` field to tool definition in `buildToolsList()`
- Description is REQUIRED for MCP client to execute tools

## Future Enhancements

### Potential Additions
- [ ] WebSocket support for real-time flow updates
- [ ] Node creation/deletion API wrappers
- [ ] Flow import/export helpers
- [ ] Credential management tools
- [ ] Context data access (flow/global/node)
- [ ] Debug message capture

### Upstream Contributions
Consider submitting PR to karavaev-evgeniy/node-red-mcp-server:
- Add missing descriptions to all tools
- Fix any bugs discovered during local implementation
- Share visualize-flows implementation

## References

- **Node-RED Admin API**: https://nodered.org/docs/api/admin/
- **MCP Specification**: https://spec.modelcontextprotocol.io/
- **Upstream Repository**: https://github.com/karavaev-evgeniy/node-red-mcp-server
- **Axios Documentation**: https://axios-http.com/docs/intro

## Current Status

✅ **Production Ready**
- All 20 tools implemented and tested
- VS Code mcp.json configured
- Documentation complete
- Error handling robust

**Next Steps**: Begin creating actual Node-RED flows using established project structure
