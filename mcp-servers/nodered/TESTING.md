# Node-RED MCP Server - Testing Guide

## Quick Test Commands

### Test Server Initialization
```bash
cd /home/divix/divtools/mcp-servers/nodered
node test_connection.js
```

### Test Extended Features
```bash
node test_extended.js
```

## Tool Testing Examples

### 1. Test inject tool
Trigger an inject node (replace ID with actual inject node ID from your flows):
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"inject","arguments":{"id":"b46ca61bb10f6e30"}}}' | node server.js http://divix:3mpms3@10.1.1.215:1880
```

### 2. Test visualize-flows
Get structured visualization of all flows:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"visualize-flows","arguments":{}}}' | node server.js http://divix:3mpms3@10.1.1.215:1880
```

### 3. Test get-settings
Retrieve Node-RED runtime settings:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get-settings","arguments":{}}}' | node server.js http://divix:3mpms3@10.1.1.215:1880
```

### 4. Test toggle-node-module
Enable/disable a node module (requires actual module name):
```bash
# To disable a module
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"toggle-node-module","arguments":{"module":"node-red-contrib-some-module","enabled":false}}}' | node server.js http://divix:3mpms3@10.1.1.215:1880

# To enable a module
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"toggle-node-module","arguments":{"module":"node-red-contrib-some-module","enabled":true}}}' | node server.js http://divix:3mpms3@10.1.1.215:1880
```

### 5. Test get-flows-formatted
Get summary of flows with node counts:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get-flows-formatted","arguments":{}}}' | node server.js http://divix:3mpms3@10.1.1.215:1880
```

### 6. Test list-tabs
List all tabs:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list-tabs","arguments":{}}}' | node server.js http://divix:3mpms3@10.1.1.215:1880
```

### 7. Test find-nodes-by-type
Find all nodes of a specific type:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"find-nodes-by-type","arguments":{"type":"inject"}}}' | node server.js http://divix:3mpms3@10.1.1.215:1880
```

### 8. Test get-diagnostics
Get overall diagnostics:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get-diagnostics","arguments":{}}}' | node server.js http://divix:3mpms3@10.1.1.215:1880
```

## Integration with VS Code

Add to `.vscode/mcp.json`:

```json
{
  "servers": {
    "nodered-local": {
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

## Validation Checklist

After making changes to server.js, verify:

- [ ] Server initializes without errors
- [ ] All 20 tools are registered (check with test_connection.js)
- [ ] Each tool has a description
- [ ] No "missing description" warnings
- [ ] visualize-flows returns formatted markdown
- [ ] get-settings returns valid JSON
- [ ] inject triggers nodes successfully
- [ ] toggle-node-module can enable/disable modules

## Troubleshooting

### Error: "Node-RED API error"
- Verify Node-RED is running at the specified URL
- Check authentication credentials
- Confirm Node-RED admin API is enabled

### Error: "Unknown tool"
- Tool name might be misspelled
- Verify tool is listed in buildToolsList()
- Check handleToolsCall() has handler for the tool

### Tool returns empty/null
- Some endpoints require specific Node-RED configuration
- Check Node-RED version compatibility
- Verify the entity/node being queried exists
