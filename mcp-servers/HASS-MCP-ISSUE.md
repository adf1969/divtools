# Home Assistant MCP Server - RGB Schema Issue
# Last Updated: 2/5/2025 9:15:00 PM CST

## Error Encountered

```
Request Failed: 400 
{
  "error": {
    "message": "Invalid schema for function 'mcp_homeassistant_control': 
                [{'type': 'number'}, {'type': 'number'}, {'type': 'number'}] 
                is not of type 'object', 'boolean'.",
    "code": "invalid_request_body"
  }
}
```

**Copilot Request ID**: 5008633d-c3ec-4eba-990e-dcff241ccb3d

## Root Cause

The **`@jango-blockchained/homeassistant-mcp`** package has an **invalid JSON Schema** for the `rgb_color` parameter in the `mcp_homeassistant_control` tool.

### What's Wrong

The schema uses Python-like syntax instead of valid JSON Schema:
```json
// INCORRECT (Python-style)
[{'type': 'number'}, {'type': 'number'}, {'type': 'number'}]
```

### What It Should Be

According to JSON Schema specification, arrays should be defined as:

**Option 1: Array with uniform items**
```json
{
  "type": "array",
  "items": {
    "type": "number"
  },
  "minItems": 3,
  "maxItems": 3,
  "description": "RGB color values [red, green, blue]"
}
```

**Option 2: Tuple validation (stricter)**
```json
{
  "type": "array",
  "prefixItems": [
    {"type": "number", "minimum": 0, "maximum": 255},
    {"type": "number", "minimum": 0, "maximum": 255},
    {"type": "number", "minimum": 0, "maximum": 255}
  ],
  "minItems": 3,
  "maxItems": 3
}
```

## Impact

When Copilot tries to call `mcp_homeassistant2_control` or `mcp_homeassistant2_lights_control` with RGB color values, the request is **rejected by the AI model** before even reaching the MCP server, because the tool schema doesn't validate.

## Affected Tools

From the available tool references, these tools likely have the same schema issue:
- `mcp_homeassistant2_control`
- `mcp_homeassistant2_lights_control`
- `mcp_homeassistant2_climate_control` (if it uses RGB)
- Any other tool that accepts `rgb_color` parameter

## Resolution

### Temporary Fix (Implemented)

1. **Disabled** the problematic `homeassistant-jango` server in `.vscode/mcp.json`
2. **Enabled** the `home-assistant-mcp-server@latest` package instead
3. Removed trailing comma from homeassistant config (JSON syntax fix)

### Long-Term Fix

**Option A: Report Upstream**
- File bug report at: https://github.com/jango-blockchained/homeassistant-mcp/issues
- Include this error message and correct schema examples
- Request fix for RGB color parameter schemas

**Option B: Create Local MCP Server**
- Similar to what we did for Node-RED
- Implement proper JSON schemas for all parameters
- Add validation for RGB values (0-255 range)
- Location: `/home/divix/divtools/mcp-servers/homeassistant/`

**Option C: Fork and Fix**
- Fork `@jango-blockchained/homeassistant-mcp`
- Fix all parameter schemas
- Submit PR to upstream
- Use local fork until PR is merged

## Testing the Fix

After VS Code restarts/reloads the MCP servers, test with:

1. **List devices**: Should now work without schema errors
   ```
   Use mcp_homeassistant_list_devices to get all light entities
   ```

2. **Control lights**: Test RGB color setting
   ```
   Use mcp_homeassistant_lights_control to set light.test_light to RGB [255, 128, 0]
   ```

3. **Get state**: Verify entity states
   ```
   Use mcp_homeassistant_control with action "get_state" for entity light.office
   ```

## Additional Notes

### Why This Happened

The `@jango-blockchained/homeassistant-mcp` package appears to have:
1. Used Python-style dict syntax `{'type': 'number'}` instead of JSON `{"type": "number"}`
2. Not validated schemas against JSON Schema specification
3. Possibly auto-generated schemas from Python code without proper conversion

### Related Issues

The comment in mcp.json mentions:
```json
"--legacy-schema"  // this is the one that fixes the crash
```

This suggests:
- The package has **multiple schema formats**
- The `--legacy-schema` flag was used to work around **previous crashes**
- The legacy schema format has **invalid RGB definitions**
- Need to test **without** `--legacy-schema` flag to see if newer schema is correct

## Validation Command

Check if the new MCP server has valid schemas:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | \
  npx -y home-assistant-mcp-server@latest --stdio 2>&1 | \
  jq -r '.result.tools[] | select(.name | contains("control")) | .inputSchema'
```

## Status

- [x] Issue identified
- [x] Problematic server disabled
- [x] Alternative server enabled
- [ ] Test new server functionality
- [ ] Report issue upstream if still present
- [ ] Consider creating local MCP server if issues persist

## References

- **JSON Schema Spec**: https://json-schema.org/understanding-json-schema/reference/array.html
- **MCP Spec**: https://spec.modelcontextprotocol.io/specification/architecture/
- **Jango HA MCP**: https://github.com/jango-blockchained/homeassistant-mcp
- **Alternative Server**: https://www.npmjs.com/package/home-assistant-mcp-server
