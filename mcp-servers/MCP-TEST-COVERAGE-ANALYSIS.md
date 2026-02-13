# Node-RED + Home Assistant MCP Integration Analysis

**Date:** November 20, 2025  
**Status:** Planning Phase

## Project Goals (from NODERED-PROJECT.md)

The Node-RED project has these core objectives:
1. **Create reusable Node-RED flows** for Home Assistant automation and monitoring
2. **Organize flows** by category (Automation, Notification, Monitoring, Integration, Data Processing)
3. **Establish MCP integration** for programmatic flow creation and testing
4. **Test flows** before deployment

Key outstanding decision: **MCP Integration for Node-RED** (Q2 in NODERED-PROJECT-HISTORY.md)

---

## Current Tool & Test Coverage Analysis

### Node-RED MCP Server (`/mcp-servers/nodered/`)
✅ **Status**: Implemented and tested

**Implemented Tools:**
- `create-flow` ✓ (tested)
- `delete-flow` ✓ (tested)
- `get-flow` ✓ (tested)
- `get-flows` ✓ (untested directly)
- `get-flows-formatted` ✓ (tested)
- `update-flow` ✓ (untested)
- `update-flows` ✓ (untested)
- `list-tabs` ✓ (tested)
- `get-flows-state` ✓ (untested)
- `set-flows-state` ✓ (untested)
- `get-nodes` ✓ (untested)
- `get-node-info` ✓ (untested)
- `find-nodes-by-type` ✓ (tested)
- `search-nodes` ✓ (untested)
- `get-diagnostics` ✓ (tested)
- `visualize-flows` ✓ (tested)
- `get-settings` ✓ (tested)
- `api-help` ✓ (tested)
- `inject` ✓ (untested)
- `toggle-node-module` ✓ (untested)

**Test Files:**
- `test/flow_lifecycle.test.js` - Tests create, get, delete flow (1 test)
- `test/read_only_tools.test.js` - Tests read-only tools (7 tests)

**Missing Tests:**
- `update-flow` (modify flow structure)
- `update-flows` (bulk replace)
- `get-flows` (full flows)
- `get-flows-state` / `set-flows-state` (enable/disable)
- `get-nodes` (nodes on tab)
- `get-node-info` (specific node details)
- `search-nodes` (node search)
- `inject` (trigger injection)
- `toggle-node-module` (enable/disable modules)

### Home Assistant MCP Server
❌ **Status**: NOT IMPLEMENTED

**Issue**: No Home Assistant MCP server exists in `/mcp-servers/`. 

**Requirement**: To complete the project goals, we need ability to:
- Retrieve Home Assistant device IDs and entity IDs
- Query entity state and attributes
- Understand available automations, scripts, and services
- Validate that flows reference valid HASS entities before deployment

---

## The MCP Tool Usage Problem

**Observed Issue**: You (Copilot) can write code to interact with MCP servers but struggle to USE the MCP tools via the integrated MCP client in VS Code.

**Root Cause**: MCP client integration in VS Code is complex and the official Home Assistant MCP server has schema validation issues.

**Proposed Solution**: 
Instead of relying on VS Code's integrated MCP client, use **bash scripts as the primary interface** to MCP servers:
1. Spin up MCP servers independently (Node.js processes)
2. Call them via stdin/stdout JSON-RPC from bash scripts
3. Parse JSON responses in bash
4. Use bash scripts as utilities that other tools can invoke

**Benefits:**
- No dependency on VS Code MCP client
- Bash scripts are composable and testable
- Can run MCP servers in background
- No need to keep all tools "in memory"
- Simpler error handling and logging

---

## Recommended Action Plan

### Phase 1: Complete Node-RED Test Coverage (Priority: HIGH)
Add missing tests for Node-RED MCP tools:

1. **test/flow_modification.test.js** (NEW)
   - Test `update-flow` (modify tabs and nodes)
   - Test `update-flows` (bulk replace)
   - Test `get-flows` (retrieve full flows)

2. **test/flow_state.test.js** (NEW)
   - Test `get-flows-state` (check enabled/disabled)
   - Test `set-flows-state` (enable/disable flows)

3. **test/node_operations.test.js** (NEW)
   - Test `get-nodes` (get nodes on tab)
   - Test `get-node-info` (get single node)
   - Test `search-nodes` (search by name)

4. **test/advanced_tools.test.js** (NEW)
   - Test `inject` (trigger inject node)
   - Test `toggle-node-module` (enable/disable modules)

### Phase 2: Create Home Assistant Bash Wrapper (Priority: HIGH)
Create a bash-based interface to Home Assistant API (no MCP needed):

**Location**: `/home/divix/divtools/scripts/hass_api_wrapper.sh`

**Functions**:
- `hass_get_entities` - List all entities with filters
- `hass_get_device_ids` - Get device IDs
- `hass_get_device_info` - Get device details
- `hass_get_services` - List available services
- `hass_get_automations` - List automations
- `hass_get_scripts` - List scripts

This can be used by Node-RED flow creation tools to validate entity references.

### Phase 3: Create Home Assistant MCP Server (Priority: MEDIUM)
If deemed necessary after Phase 1 & 2, create a proper Home Assistant MCP server:

**Location**: `/home/divix/divtools/mcp-servers/homeassistant/`

Would follow the same pattern as Node-RED MCP server.

### Phase 4: Update Copilot Instructions (Priority: HIGH)
Update `.github/copilot-instructions.md` to reflect:
- Preference for **bash script wrappers** over relying on VS Code MCP client
- Guidelines for when to create MCP servers vs bash wrappers
- Process for testing bash wrappers instead of MCP tools

---

## Implementation Priority

1. ✅ **Complete Node-RED test coverage** (4 new test files)
2. ✅ **Create Home Assistant bash wrapper** 
3. 🔵 **Create Home Assistant MCP server** (if bash wrapper insufficient)
4. ✅ **Update copilot-instructions.md**

---

## Next Steps

Ready to:
- [ ] Add missing Node-RED tests
- [ ] Create HASS bash wrapper with test cases
- [ ] Create HASS MCP server if needed
- [ ] Update copilot instructions
