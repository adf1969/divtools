# AGENTS.md - Node-RED Project Guidelines

## Project Type
Node-RED flow development for Home Assistant automation and monitoring.

---

## Critical Development Instructions

### Version Compatibility Check
**ALWAYS perform this check when writing code or creating configurations:**

1. **Determine the current version** of the system you're writing FOR (Node-RED, Home Assistant, node-red-contrib-home-assistant-websocket, etc.)
2. **Compare with training cutoff** - Check when the model was trained vs current version
3. **If current version is NEWER** than training cutoff:
   - Search and locate the **most recent official documentation**
   - Review the **CHANGELOG** for breaking changes
   - Check **GitHub issues** for recent bug reports
   - Update your context to ensure accuracy
4. **Document your research** - Note the version you validated against

This prevents generating code that is **incompatible** with the current live system version.

---

## MCP Tools Reference

### Node-RED MCP Server Overview
The Node-RED project includes a **Model Context Protocol (MCP) Server** located at `/home/divix/divtools/mcp-servers/nodered/server.js` that provides programmatic access to Node-RED flows, nodes, and settings. 

**IMPORTANT**: These MCP tools listed in VS Code are **tool definitions** only. To use them, you must:
1. Run the test suite to verify tools work: `cd /home/divix/divtools/mcp-servers/nodered && npm test`
2. Use the test client pattern for programmatic access
3. Refer to the comprehensive test suite at `/home/divix/divtools/mcp-servers/nodered/test/*.test.js` for usage examples

### Available Tools (20 total)

#### Flow Management Tools

| Tool                    | Purpose                                             | Test File                                           | Example Usage                         |
| ----------------------- | --------------------------------------------------- | --------------------------------------------------- | ------------------------------------- |
| **get-flows**           | Retrieve all flows (tabs + nodes) as complete array | `flow_modification.test.js`                         | Get raw flow data for analysis/backup |
| **get-flows-formatted** | Get simplified list of flow tabs with node counts   | `flow_lifecycle.test.js`, `read_only_tools.test.js` | List all flows for UI display         |
| **get-flow**            | Get a specific flow by ID                           | `flow_lifecycle.test.js`                            | Inspect single flow properties        |
| **create-flow**         | Create a new flow tab with initial nodes            | `flow_lifecycle.test.js`                            | Add new automation tabs               |
| **delete-flow**         | Delete a flow tab by ID                             | `flow_lifecycle.test.js`                            | Remove deprecated flows               |
| **update-flows**        | ⚠️ **DANGEROUS**: Replaces ALL flows - use carefully | `flow_modification.test.js`                         | Only if merging with all existing     |
| **update-flow**         | ✅ **SAFE**: Update single flow by ID                | `flow_modification.test.js`                         | Modify existing flow (RECOMMENDED)    |

#### Node Operations

| Tool                   | Purpose                                               | Test File                 | Example Usage               |
| ---------------------- | ----------------------------------------------------- | ------------------------- | --------------------------- |
| **get-nodes**          | Get nodes on a specific tab by ID                     | `node_operations.test.js` | List nodes in a flow        |
| **get-node-info**      | Get detailed info on single node                      | `node_operations.test.js` | Inspect node properties     |
| **search-nodes**       | Search nodes by name or label                         | `node_operations.test.js` | Find specific nodes         |
| **find-nodes-by-type** | Find all nodes of a type (e.g., "switch", "function") | `read_only_tools.test.js` | Analyze flow patterns       |
| **inject**             | Trigger an inject node by ID                          | `advanced_tools.test.js`  | Send test payloads to flows |

#### Flow State & Settings

| Tool                | Purpose                                      | Test File                 | Example Usage                |
| ------------------- | -------------------------------------------- | ------------------------- | ---------------------------- |
| **get-flows-state** | Get enabled/disabled state for each flow tab | `flow_state.test.js`      | Check which flows are active |
| **set-flows-state** | Enable/disable flow tabs                     | `flow_state.test.js`      | Activate/deactivate flows    |
| **get-settings**    | Get Node-RED runtime settings                | `read_only_tools.test.js` | Check server configuration   |
| **get-diagnostics** | Get node count, unreachable nodes, warnings  | `read_only_tools.test.js` | Health check flows           |

#### Debugging & Discovery

| Tool                   | Purpose                                           | Test File                 | Example Usage                    |
| ---------------------- | ------------------------------------------------- | ------------------------- | -------------------------------- |
| **visualize-flows**    | Get structured visualization with node type stats | `read_only_tools.test.js` | Understand flow architecture     |
| **api-help**           | Display Node-RED admin API endpoints              | `read_only_tools.test.js` | Reference available API routes   |
| **toggle-node-module** | Enable/disable Node-RED modules                   | `advanced_tools.test.js`  | Manage node package availability |

### How to Use MCP Tools

#### Option 1: Run Test Suite (Verify Tools Work)
```bash
cd /home/divix/divtools/mcp-servers/nodered
npm test

# All 20 tools tested across 6 test files:
# - read_only_tools.test.js: 7 tools
# - flow_lifecycle.test.js: 4 tools
# - flow_modification.test.js: 3 tools  
# - node_operations.test.js: 3 tools
# - flow_state.test.js: 2 tools
# - advanced_tools.test.js: 2 tools
```

#### Option 2: Use Test Client Pattern (Programmatic Access)
See `/home/divix/divtools/mcp-servers/nodered/test/mcp-client.js` for client implementation:

```javascript
// Spawn server with Node-RED URL and auth
const server = spawn('node', [
    '/home/divix/divtools/mcp-servers/nodered/server.js',
    'http://divix:3mpms3@10.1.1.215:1880'
]);

// Send JSON-RPC request to stdin
server.stdin.write(JSON.stringify({
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: {
        name: 'get-flows',
        arguments: {}
    }
}) + '\n');

// Read JSON response from stdout
server.stdout.on('data', (data) => {
    const result = JSON.parse(data);
    console.log(result.result); // Array of flows
});
```

#### Option 3: Direct Server Invocation (CLI)
```bash
# Start MCP server with Node-RED credentials
node /home/divix/divtools/mcp-servers/nodered/server.js http://divix:3mpms3@10.1.1.215:1880

# Send tool call via stdin (JSON-RPC format)
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get-flows","arguments":{}}}' | node /home/divix/divtools/mcp-servers/nodered/server.js http://divix:3mpms3@10.1.1.215:1880
```

### Why MCP Tool Definitions Show Empty

When you call an MCP tool in VS Code (like `mcp_nodered-dt_get-flows`), it may return empty because:

1. **The MCP server process is NOT running**: MCP tools are definitions that require a running server process
2. **VS Code integration is limited**: VS Code can call MCP tools only if the server is properly configured in settings
3. **Authentication required**: The server needs Node-RED credentials to establish connection
4. **No persistent connection**: Each tool call would need to spawn a fresh server process

**Solution**: Always use the test suite or run the server process explicitly before using tools.

### Test Coverage Map

All 20 tools have comprehensive test coverage:

```
/home/divix/divtools/mcp-servers/nodered/test/
├── read_only_tools.test.js ................. [list-tabs, get-flows-formatted, get-diagnostics, 
│                                               get-settings, visualize-flows, api-help, find-nodes-by-type]
├── flow_lifecycle.test.js .................. [create-flow, get-flow, get-flows-formatted, delete-flow]
├── flow_modification.test.js ............... [update-flow, update-flows, get-flows]
├── node_operations.test.js ................. [get-nodes, get-node-info, search-nodes]
├── flow_state.test.js ...................... [get-flows-state, set-flows-state]
└── advanced_tools.test.js .................. [inject, toggle-node-module]
```

Each test file includes:
- ✅ Setup/teardown procedures
- ✅ Success cases with assertions
- ✅ Error handling verification
- ✅ Real Node-RED instance integration
- ✅ Proper cleanup after tests

---

## Node-RED HTTP API Server (RECOMMENDED)

**IMPORTANT**: Due to VS Code MCP client limitations with large JSON responses, use the **Node-RED HTTP API Server** instead of MCP tools for reliable Node-RED flow access.

### Overview
The Node-RED HTTP API Server provides **RESTful HTTP endpoints** that mirror MCP functionality but work reliably with VS Code and other tools. Located at `/home/divix/divtools/mcp-servers/nodered_http/`.

### Server Management Script

Use the control script for easy server management:

```bash
# Start the server
/home/divix/divtools/mcp-servers/nodered_http/start_nodered_http.sh start

# Check status
/home/divix/divtools/mcp-servers/nodered_http/start_nodered_http.sh status

# Stop the server
/home/divix/divtools/mcp-servers/nodered_http/start_nodered_http.sh stop

# Restart the server
/home/divix/divtools/mcp-servers/nodered_http/start_nodered_http.sh restart
```

### Available HTTP Endpoints

All endpoints return JSON responses. Server runs on `http://localhost:3001` by default.

#### Health Check
```bash
curl -X GET http://localhost:3001/health
# Returns: {"status":"ok","timestamp":"2025-11-20T16:00:00.000Z"}
```

#### Flow Management
```bash
# Get all flows (returns complete flow data - 103+ flows)
curl -X POST http://localhost:3001/tools/get-flows -H "Content-Type: application/json" -d '{}'

# Get specific flow by ID
curl -X POST http://localhost:3001/tools/get-flow -H "Content-Type: application/json" -d '{"id": "shop_light_motion_tab"}'

# ⭐ NEW - SIMPLIFIED: Get flow by NAME (not ID!)
curl -X POST http://localhost:3001/tools/get-flow-by-name -H "Content-Type: application/json" -d '{"name": "Shop Light - Motion"}'

# ⭐ NEW - SIMPLIFIED: Get flow + ALL its nodes in ONE request!
curl -X POST http://localhost:3001/tools/get-flow-with-nodes -H "Content-Type: application/json" -d '{"id": "shop_light_motion_tab"}'

# Create new flow
curl -X POST http://localhost:3001/tools/create-flow -H "Content-Type: application/json" -d '{"label": "New Flow", "nodes": []}'

# Update existing flow
curl -X POST http://localhost:3001/tools/update-flow -H "Content-Type: application/json" -d '{"id": "flow_id", "nodes": [...]}'

# Delete flow
curl -X POST http://localhost:3001/tools/delete-flow -H "Content-Type: application/json" -d '{"id": "flow_id"}'
```

#### Node Operations
```bash
# Get nodes on a specific tab
curl -X POST http://localhost:3001/tools/get-nodes -H "Content-Type: application/json" -d '{"tabId": "flow_id"}'

# Get detailed info on single node
curl -X POST http://localhost:3001/tools/get-node-info -H "Content-Type: application/json" -d '{"id": "node_id"}'

# Search nodes by name/label
curl -X POST http://localhost:3001/tools/search-nodes -H "Content-Type: application/json" -d '{"query": "motion"}'

# Find nodes by type
curl -X POST http://localhost:3001/tools/find-nodes-by-type -H "Content-Type: application/json" -d '{"type": "switch"}'
```

#### Flow State & Settings
```bash
# Get enabled/disabled state for each flow
curl -X POST http://localhost:3001/tools/get-flows-state -H "Content-Type: application/json" -d '{}'

# Enable/disable flow tabs
curl -X POST http://localhost:3001/tools/set-flows-state -H "Content-Type: application/json" -d '{"flows": [{"id": "flow_id", "enabled": true}]}'

# Get Node-RED runtime settings
curl -X POST http://localhost:3001/tools/get-settings -H "Content-Type: application/json" -d '{}'

# Get diagnostics (node count, warnings)
curl -X POST http://localhost:3001/tools/get-diagnostics -H "Content-Type: application/json" -d '{}'
```

#### Advanced Operations
```bash
# Trigger an inject node
curl -X POST http://localhost:3001/tools/inject -H "Content-Type: application/json" -d '{"id": "inject_node_id"}'

# Enable/disable Node-RED modules
curl -X POST http://localhost:3001/tools/toggle-node-module -H "Content-Type: application/json" -d '{"module": "module_name", "enabled": true}'

# Get structured visualization with node stats
curl -X POST http://localhost:3001/tools/visualize-flows -H "Content-Type: application/json" -d '{}'

# Display available API endpoints
curl -X POST http://localhost:3001/tools/api-help -H "Content-Type: application/json" -d '{}'
```

### Response Format

All endpoints return JSON in this format:
```json
{
  "success": true,
  "data": { /* endpoint-specific data */ }
}
```

Or on error:
```json
{
  "success": false,
  "error": "Error message"
}
```

### Configuration

The server is configured with these defaults (can be modified in `start_nodered_http.sh`):
- **Node-RED URL**: `http://10.1.1.215:1880`
- **Authentication**: `divix:3mpms3`
- **HTTP Port**: `3001`
- **PID File**: `nodered_http.pid`
- **Log File**: `nodered_http.log`

### When to Use HTTP API vs MCP

| Scenario | Use HTTP API | Use MCP |
|----------|-------------|---------|
| Getting all flows | ✅ **RECOMMENDED** | ❌ May return empty |
| Large JSON responses | ✅ **RECOMMENDED** | ❌ VS Code client bug |
| Programmatic access | ✅ **RECOMMENDED** | ⚠️ Requires manual server management |
| VS Code integration | ✅ **RECOMMENDED** | ❌ Unreliable |
| **Getting flow by name** | ✅ **NEW: One simple request!** | ❌ Complex multi-step process |
| **Getting flow + nodes** | ✅ **NEW: One simple request!** | ❌ 15+ commands required |

### Chat Integration

**When you ask about Node-RED flows**, the AI will automatically:
1. Check if the HTTP server is running
2. Start it if needed using the control script
3. **NEW**: Use simplified endpoints for faster results
4. Parse and present the results clearly

**Example queries that work:**
- "Show me all my Node-RED flows"
- "Check the shop light motion flow" *(now uses get-flow-by-name)*
- "Get details about flow ID xyz"
- "List all switch nodes in my flows"

**The process is now dramatically simplified:**
- **Before**: 15+ commands, complex parsing, multiple API calls
- **After**: 1-2 simple curl requests with clear JSON responses

---

## Home Assistant WebSocket Node Types Reference

**CRITICAL**: When creating flows, always use the correct node types from the **node-red-contrib-home-assistant-websocket** module.

### Node Metadata Fields

**IMPORTANT - Field Names Matter**:
- ✅ **Use `info`** for flow/tab descriptions (not `desc`)
- ✅ **Use `info`** for node descriptions (not `desc`)
- Each tab object must have: `id`, `type: "tab"`, `label`, `disabled`, `info`
- Each node object must have: `id`, `type`, `z` (tab id), `name`, `info` (description)

The `info` field supports **Markdown formatting** for rich documentation.

### Home Assistant WebSocket Node Code Reference

The complete source code defining all Home Assistant node types is available at:
- 📖 **Build.js Node Mapping**: https://raw.githubusercontent.com/zachowj/node-red-contrib-home-assistant-websocket/667cb8416e3f172e212e68088906a520d6797a08/build.js

This file contains the **nodeMap** that defines:
- Directory names and their corresponding node types
- All available Home Assistant nodes and their IDs
- Node configuration templates

### Home Assistant WebSocket Integration Repository

The complete source code and documentation for Node-RED's Home Assistant integration:
- 📖 **GitHub Repository**: https://github.com/zachowj/node-red-contrib-home-assistant-websocket
- Includes examples, cookbooks, and raw node definitions
- Source code reference for all Home Assistant node functionality
- Development environment setup for custom nodes
- **CRITICAL**: This codebase is essential for understanding Node-RED ↔ Home Assistant interaction

### Common Node Types

| Node Type              | Purpose                              | Uses                                                |
| ---------------------- | ------------------------------------ | --------------------------------------------------- |
| `server-state-changed` | Trigger on entity state changes      | Motion sensors, light changes, temperature updates  |
| `api-current-state`    | Get current state of HA entity       | Check if light is ON, get temperature value         |
| `api-call-service`     | Call Home Assistant service          | Turn light ON/OFF, lock/unlock door, set brightness |
| `trigger`              | Delay with configurable restart mode | Wait N minutes, restart on new input                |
| `function`             | JavaScript function node             | Custom logic, calculations, conditions              |
| `switch`               | Branch flow based on conditions      | Route ON vs OFF events, check conditions            |
| `debug`                | Output to debug sidebar              | Inspect message flow, troubleshoot                  |
| `comment`              | Document flow logic                  | Explain complex sections, reference docs            |

### Important Distinctions

⚠️ **DO NOT USE**:
- ❌ `action` → Use `api-call-service` instead
- ❌ `current_state` → Use `api-current-state` instead
- ❌ `ha-call-service` → Use `api-call-service` instead
- ❌ `ha-get-entities` (for service calls) → Use `api-call-service` instead
- ❌ `desc` field → Use `info` field instead (for all node/tab descriptions)

### Reference Documentation

For complete node type documentation and configuration options:
- 📖 **Official Docs**: https://zachowj.github.io/node-red-contrib-home-assistant-websocket/
- 📖 **Node Types**: https://zachowj.github.io/node-red-contrib-home-assistant-websocket/docs/
- 📖 **Configuration**: https://zachowj.github.io/node-red-contrib-home-assistant-websocket/docs/node/
- 🔧 **Build Configuration** (Node Type Mappings): https://raw.githubusercontent.com/zachowj/node-red-contrib-home-assistant-websocket/667cb8416e3f172e212e68088906a520d6797a08/build.js

When creating or updating flows, always reference these docs to avoid node type errors.

---

## Build/Lint/Test Commands

### Flow Management
- **Export Flows**: Use Node-RED UI to export flows as JSON
- **Import Flows**: Drag and drop JSON files into Node-RED editor
- **Validate JSON**: Use JSON linter for syntax validation

### Testing
- **Node-RED Test Environment**: Use Node-RED's built-in test capabilities
- **Test Flows**: Create flows with test injection nodes (`inject` nodes with specific payloads)
- **Debug Output**: Use `debug` nodes to inspect message flow and values
- **Integration Testing**: Test with actual Home Assistant entities in non-production environment first

### Documentation
- Document flow purpose and dependencies in Node-RED comments
- Include HASS entity references in flow descriptions
- Update FLOW-LIST.md after creating or modifying flows

---

## Code Style Guidelines

### General
- **Flow Naming**: Descriptive names following snake_case (e.g., `living_room_motion_alert`)
- **Comments**: Include clear descriptions in flow tabs and node labels
- **Organization**: Group related flows by category (see folder structure)

### Node-RED Flow Conventions
- **Node Labels**: Use clear, descriptive labels for all nodes
- **Comments**: Use `comment` nodes to explain complex logic
- **Flow Organization**: Keep related flows on same tab or clearly separate tabs
- **Entity References**: Document HASS entity IDs used by flows
- **Dependencies**: Note any external integrations or services required

### Home Assistant Integration
- **Entity IDs**: Use consistent HASS entity naming conventions
- **Service Calls**: Document service names and required parameters
- **State Conditions**: Be explicit about state values being tested
- **Error Handling**: Include error catch and fallback nodes for robustness

---

## File Organization

```
projects/hass/nodered/
├── AGENTS.md                          # This file
├── docs/
│   ├── NODERED-PROJECT.md            # Project overview
│   ├── HASS-SERVER-INFO.md           # Server versions and history
│   ├── FLOW-LIST.md                  # Master flow registry
│   └── NODERED-PROJECT-HISTORY.md    # Design decisions and history
├── flows/                            # Node-RED flow JSON exports
│   ├── automation/                   # Home automation flows
│   │   ├── motion_detection.json
│   │   ├── scene_management.json
│   │   └── ...
│   ├── monitoring/                   # System and state monitoring
│   │   ├── temperature_monitor.json
│   │   ├── energy_tracking.json
│   │   └── ...
│   ├── notifications/                # Alerts and notifications
│   │   ├── mobile_alerts.json
│   │   ├── email_notifications.json
│   │   └── ...
│   ├── integration/                  # External service integration
│   │   ├── weather_integration.json
│   │   ├── calendar_sync.json
│   │   └── ...
│   └── data_processing/              # Data transformation
│       ├── data_aggregation.json
│       ├── log_processing.json
│       └── ...
└── tests/                            # Test flows and test data
    └── flow_tests/
        ├── automation_tests.json
        ├── test_data.json
        └── ...
```

---

## Node Documentation Requirements

**EVERY node in EVERY flow MUST include comprehensive documentation in the Description field.**

### Why Description Fields Matter
- Node-RED Description fields support **Markdown formatting**
- They make flows self-documenting and maintainable
- They preserve intent and design decisions for future troubleshooting
- They help quickly understand complex flow logic

### Required Documentation for All Nodes

**For every node you create, fill in the Description field with:**

1. **Purpose/What It Does**
   - Single sentence explaining the node's role in the flow
   - Example: "Detects when motion sensor changes state from OFF to ON"

2. **Inputs (What data arrives at this node)**
   - What message properties are expected
   - What triggers the node
   - Example: "Receives msg.payload with new_state from motion sensor"

3. **Processing (What the node does with the data)**
   - How the node processes the input
   - Any transformations or logic applied
   - Example: "Extracts state value and compares to previous state"

4. **Outputs (What data leaves this node)**
   - What message properties are set
   - Where the message goes
   - Example: "Sends msg.payload = 'on' to switch node if state changed to ON"

5. **Edge Cases/Important Notes (Optional but recommended)**
   - Special conditions to watch for
   - Known limitations
   - Configuration requirements
   - Example: "Ignores OFF events - flow uses timeout for light off"

### Node Description Template (Markdown Format)

```markdown
## [Node Purpose: 1 sentence]

**Input:**
- msg.property: description

**Processing:**
- What happens to the data

**Output:**
- msg.property: description

**Notes:**
- Important edge cases or configuration details
```

### Examples

#### Example 1: Switch Node
```markdown
## Check if motion sensor is ON

**Input:**
- msg.payload.new_state.state: "on" or "off" from motion sensor

**Processing:**
- Splits message into two outputs based on state value
- Output 1: When state = "on"
- Output 2: When state = "off"

**Output:**
- Output 1: msg passed through when motion detected
- Output 2: msg passed through when motion stops

**Notes:**
- Flow ignores OFF events (handled by timeout)
- Debug node on output 2 helps troubleshoot OFF suppression
```

#### Example 2: Function Node
```markdown
## Calculate day vs night timeout

**Input:**
- Current time from Node-RED context

**Processing:**
- Gets current time and compares to night_start/night_end times
- Returns 5 minute timeout for night, 15 minutes for day
- Sets node status display showing "Day: 15m" or "Night: 5m"

**Output:**
- msg.payload.timeout_minutes: number (5 or 15)
- msg.payload.is_night: boolean (true if night time)

**Notes:**
- Times hardcoded: 17:01:16 to 06:55:02
- Could be updated to use input_datetime helpers for dynamic times
```

#### Example 3: Home Assistant Action Node
```markdown
## Turn zapper plug ON

**Input:**
- msg payload with action trigger

**Processing:**
- Calls Home Assistant switch.turn_on service
- Targets: switch.sonoff_10020bac04

**Output:**
- Service result confirmation to debug node

**Notes:**
- Only called when night time AND shop light is OFF
- Debug action node logs all zapper control events
- See flow logic for conditions that trigger this node
```

### Implementation Rule

**When creating ANY node, fill the Description field FIRST before configuring the node.**

This ensures you think through:
- What data the node needs
- What the node should do with that data
- What the node produces
- How it fits into the larger flow

---

## Implementation Procedures

````
```

---

## Implementation Procedures

These procedures outline the exact steps for implementing Node-RED flows based on entries in the Flow Definition section of `FLOW-LIST.md`.

### Procedure 1: Implement a NEW Flow

**Prerequisites:**
- Flow is defined in FLOW-LIST.md under Flow Definitions with status "Planning"
- Home Assistant is accessible via API (HASS_API_TOKEN set)
- Node-RED instance is accessible

**Steps:**

1. **Add to Flow Registry** (if not already present)
   - Add a row to the Flow Registry table in FLOW-LIST.md
   - Include: Flow Name, Flow Tab, Category, Status (set to "In Development"), Version (1.0.0), Last Modified (today's date)
   - Create a hyperlink from the flow name to its definition section

2. **Identify Required Entities & Devices**
   - Review the Flow Definition's "Inputs & Entities" section
   - Use `/home/divix/divtools/scripts/hass/hass_api_wrapper.sh` to query Home Assistant for required entities:
     ```bash
     # Example: List all lights in the Shop area
     cd /home/divix/divtools/scripts/hass
     ./hass_api_wrapper.sh entity-details light --area shop --format json
     
     # Example: List motion sensors
     cd /home/divix/divtools/scripts/hass
     ./hass_api_wrapper.sh entities-by-type binary_sensor --format json
     ```
   - Cross-reference entity IDs in the Flow Definition with actual entities from HA
   - Document any missing entities that need to be created in Home Assistant

3. **Create Node-RED Flow JSON**
   - Use existing flow files in `flows/[category]/` as templates
   - Structure the JSON following Node-RED export format (array of node objects)
   - First object must have `"type": "tab"` to define the flow tab itself
   - Add nodes according to "Node List (Suggested)" in the Flow Definition
   - Configure triggers, conditions, and actions as specified in "Core Logic/Mapping"
   - Include descriptive labels on all nodes
   - Add comment nodes explaining complex logic
   - For Home Assistant server connections, reference `"server": "server_config"` in all HASS nodes
   - **Verify JSON structure**: Use the vitest test suite to verify flows work before deploying
     - See test examples in `/home/divix/divtools/mcp-servers/nodered/test/flow_lifecycle.test.js`

4. **Save Flow File**
   - Save the JSON export to: `flows/[category]/[flow_name_snake_case].json`
   - Example: `flows/automation/shop_light_motion.json`
   - Flow JSON must be a valid array of node objects with proper tab definition
   - Run JSON linter to catch syntax errors

5. **Import into Node-RED** 
   - ⚠️ **IMPORTANT**: Use MANUAL IMPORT (UI-based) - this is the recommended, safer approach
   
   - **Manual Import** (UI-based - RECOMMENDED):
     1. Access Node-RED UI at http://10.1.1.215:1880
     2. Open Node-RED menu (hamburger icon) → Import
     3. Paste the contents of the JSON flow file
     4. **BEFORE CLICKING IMPORT**: In the dialog, check "Create new flow (disabled)" checkbox if available
     5. Click Import
     6. Flow will be imported in DISABLED state
   
   - **After Import - Enable Only After Verification**:
     1. ✅ Verify flow structure in Node-RED UI
     2. ✅ Check all nodes are present and connected
     3. ✅ Verify node configurations (entity IDs, services, etc.)
     4. ✅ Use debug nodes and inject to test logic
     5. Only after verification: Right-click flow tab → Enable to activate it
   
   - **Test the flow** (with flow still disabled):
     1. Use `inject` tool to trigger test payloads
     2. Enable debug nodes to inspect message flow
     3. Verify all node connections are correct and data flows properly
     4. Run vitest test suite: `cd /home/divix/divtools/mcp-servers/nodered && npm test`
   
   - **Alternative: Using MCP Tools** (Advanced - programmatic/CLI import):
     - ⚠️ Only use if manual import is not feasible
     - Start the MCP server: `node /home/divix/divtools/mcp-servers/nodered/server.js http://divix:3mpms3@10.1.1.215:1880`
     - Load flow JSON file and parse it
     - Set the tab's `"disabled"` property to `true` (CRITICAL for first-time flows and updates)
     - Use `update-flow` tool to update a SINGLE flow: `mcp_nodered_update_flow("flow_tab_id", flowObject)`
     - For new flows, use `create-flow` tool with `"disabled": true` (see `/home/divix/divtools/mcp-servers/nodered/test/flow_lifecycle.test.js`)
     - FOR ALL FLOWS (NEW & UPDATED): Set `"disabled": true` on the tab object BEFORE importing
     - Verify import with `get-flows-formatted` to list tabs

6. **Update FLOW-LIST.md**
   - Update the flow's status: "In Development" → "Testing"
   - Set "Implementation File" to: `flows/[category]/[flow_name].json`
   - Update "Last Modified" date
   - Ensure version is set correctly (1.0.0 for new flows)
   - **Document**: "Deployed as disabled for testing - enable after verification"

### Procedure 2: Add Features to an EXISTING Flow

**Prerequisites:**
- Flow is already implemented with status "Complete" or "Testing"
- Flow Definition has been updated with new requirements
- Node-RED instance is accessible

#### Understanding the IMPROVEMENTS Section

Each flow in FLOW-LIST.md includes an **IMPROVEMENTS** section that tracks potential enhancements and feature additions. These improvements are:
- Documented as `IMP##` entries with clear descriptions and context
- Organized by category (configuration, layout, logic refinement, etc.)
- Referenced within the flow's JSON `info` field (in the tab description)
- Tracked across versions as implementation targets

**Important Improvements Standards:**

All flows MUST comply with these organizational improvements:

**IMP04b: Node Grouping (REQUIRED FOR ALL FLOWS)**
- Wrap all functional nodes in a **Group** with the flow name
- Exception: Do NOT include global-config nodes (like `server` type) in the group
- Use consistent group styling:
  ```json
  "style": {
    "stroke": "#2b2b2b",
    "stroke-opacity": "1",
    "fill": "#181818",
    "fill-opacity": "0.5",
    "label": true,
    "label-position": "nw",
    "color": "#cccccc"
  }
  ```
- Benefits: Easier to reorganize flows, cleaner visual appearance, simplified maintenance

**IMP05: Node Positioning (REQUIRED FOR ALL FLOWS)**
- Organize nodes in a **left-to-right, top-to-bottom** layout:
  - **First node (trigger):** Far left at x=100
  - **Sequential nodes:** Below previous at y+60
  - **Branch nodes:** x+400 for separate columns (upper branch at original y, lower branches at y+60 intervals)
  - **Continuation after branches:** Stack vertically from branch output
  - **Multiple inputs on one node:** Offset to next column so input wires don't cross
- Goal: Related nodes "stacked" vertically with branches expanding rightward
- Improves readability and makes flow logic visually apparent
- Example structure:
  ```
  Column 1 (x=100):  Trigger
                     └─ Switch
                     └─ Action1
  
  Column 2 (x=500):  Condition Check
                     └─ Action2
                        (Branch from Switch)
  ```

**When Implementing Improvements:**
1. Reference the specific `IMP##` ID in your commit message and flow documentation
2. Update the flow's tab `info` field to indicate which improvements have been addressed
3. Update FLOW-LIST.md to mark improvements as "Implemented" with completion date
4. Update the flow's version number (MAJOR.MINOR.PATCH) to reflect the changes

**Steps:**

1. **Review Changes in Flow Definition**
   - Read the updated "Purpose", "Core Logic/Mapping", and "Test Cases" sections
   - Identify what new nodes, triggers, or logic need to be added
   - Note any changes to entity requirements in "Inputs & Entities"

2. **Query New Entities (if needed)**
   - If new entities are required, use `hass_api_wrapper.sh` to verify they exist:
     ```bash
     ./hass_api_wrapper.sh entity-details [type] --area [area] --format json
     ```
   - The `hass_api_wrapper.sh` already correctly sources the needed .env files. You do not need to do
     that as well, as that is redundant.
   - Update the Flow Definition with actual entity IDs

3. **Update the Node-RED Flow**
   - Open the flow file: `flows/[category]/[flow_name].json` in a JSON editor or Node-RED UI
   - Add new nodes as specified in the updated definition
   - Modify existing logic as needed
   - Update node labels and add new comment nodes for clarity

4. **Re-import and Test in Node-RED**
   - Export the updated flow JSON
   - In Node-RED, delete the old version of the flow (create backup first)
   - Re-import the updated JSON
   - Run through test cases in the Flow Definition to verify functionality

5. **Update FLOW-LIST.md**
   - Update status to "Testing" (if not already)
   - Increment Version: MAJOR (breaking changes) or MINOR (new features)
   - Update "Last Modified" date
   - Update "Purpose" or other sections if the description changed

6. **Deploy to Production**
   - Once testing is complete, set status to "Complete"
   - Verify the flow works in the production Node-RED instance
   - Document any configuration or setup required in "Missing Info" or update that section

### Procedure 3: Track and Resolve Flow Testing Issues

**Overview:**
Each flow in FLOW-LIST.md now contains a **TESTING section** that tracks issues discovered during implementation and testing. This provides a centralized issue tracker for flow quality and completeness.

**TESTING Section Structure:**

```markdown
**TESTING:**
- Test [number]:
  - Issue [number]:
    - [Description of the problem]
    - [Questions or investigation needed]
    - Status: [Active | Fixed]
```

**How to Use**:

1. **Review TESTING Sections** in `/home/divix/divtools/projects/hass/nodered/docs/FLOW-LIST.md`
   - Each flow with status "Testing" or higher has a TESTING section
   - Issues are numbered sequentially within each test iteration
   - Each issue includes clear description and status

2. **Interpret Issue Status**:
   - **Status: Active** - Problem still exists, needs investigation/resolution
   - **Status: Fixed** - Issue has been resolved, solution documented

3. **Address Active Issues**:
   - Read the issue description carefully
   - Investigate the root cause
   - Implement a fix or workaround
   - Update the issue with:
     - Solution/Resolution
     - Any code changes made
     - Status changed to "Fixed"
   - Re-test the flow to confirm fix

4. **Document Resolutions**:
   - Update FLOW-LIST.md with resolution details
   - Include specific node changes, file updates, or configuration changes
   - Update flow version if changes are significant (MINOR or PATCH increment)
   - Update "Last Modified" date
   - Update flow status if appropriate (e.g., "Testing" → "Completed" if all issues fixed)

5. **Report Back**:
   - For implementation questions (marked with `❓ OUTSTANDING`), provide answers
   - For node type issues, verify correct node names and properties
   - For debug node purposes, clarify intended functionality
   - Document lessons learned for future flows

**Key Issue Types**:

1. **Node Type Mismatch**
   - Issue: Flow references node types that don't exist in Node-RED
   - Solution: Find correct node type name and update flow JSON
   - Example: `current-state` → `current_state`, `ha-call-service` → `action`

2. **Missing Functionality**
   - Issue: Debug nodes or helper nodes without clear purpose
   - Solution: Clarify purpose with `❓ OUTSTANDING` tag or remove if unnecessary
   - Example: Debug nodes for monitoring, helper nodes for logic

3. **Configuration Questions**
   - Issue: Unclear entity references or timeout values
   - Solution: Provide explicit values or make configurable
   - Example: Night start/end times, debounce delay values

4. **Integration Issues**
   - Issue: Flow cannot communicate with Home Assistant
   - Solution: Verify HA server config, entity IDs, service names
   - Example: Service call parameters, entity state filters

---

### Procedure 4: Test a Flow Implementation

**Prerequisites:**
- Flow has been imported into a Node-RED development instance
- Home Assistant is accessible from Node-RED

**Test Execution:**

1. **Unit-level Testing** (individual nodes)
   - Use inject nodes to send test payloads to each trigger node
   - Verify output with debug nodes
   - Check message properties and payloads match expectations

2. **Integration Testing** (flow as a whole)
   - Trigger the flow using real Home Assistant events (state changes, service calls)
   - Monitor debug output to follow the flow's execution
   - Verify that service calls to Home Assistant are made correctly

3. **Edge Case Testing**
   - Test the conditions specified in the Flow Definition's "Test Cases" section
   - Test boundary values and error scenarios
   - Verify debounce/throttle behavior if applicable

4. **Performance Testing**
   - Monitor CPU and memory usage during flow execution
   - Check that flows with time-based triggers fire at expected intervals
   - Verify no excessive polling or redundant operations

5. **Documentation of Results**
   - Record test results in NODERED-PROJECT-HISTORY.md if issues found
   - Update Flow Definition if test results reveal missing info
   - Mark flow as "Complete" once all test cases pass

---

## Flow Development Workflow

### 1. Planning Phase
1. Create entry in FLOW-LIST.md with status "Planning"
2. Define flow purpose, inputs, and expected outputs
3. Identify HASS entities and services needed
4. Document any dependencies or prerequisites

### 2. Development Phase
1. Create flow in Node-RED development instance
2. Add descriptive labels to all nodes
3. Include comment nodes explaining complex logic
4. Update status to "In Development" in FLOW-LIST.md

### 3. Testing Phase
1. Test with injection nodes and debug output
2. Verify all HASS service calls work correctly
3. Test error conditions and edge cases
4. Test in non-production environment with real HASS instance
5. Update status to "Testing" in FLOW-LIST.md

### 4. Deployment Phase
1. Export flow as JSON from Node-RED
2. Save to appropriate `flows/[category]/` directory
3. Update FLOW-LIST.md with:
   - Implementation filename
   - Version (increment MINOR version)
   - Last Modified date
4. Update status to "Complete"
5. Import into production Node-RED instance

### 5. Maintenance Phase
1. Monitor flow execution in Node-RED logs
2. For updates: increment PATCH version
3. For significant changes: increment MINOR version
4. Always update FLOW-LIST.md and NODERED-PROJECT-HISTORY.md

---

## Versioning

### Version Format
Use semantic versioning: **MAJOR.MINOR.PATCH**
- **MAJOR**: Breaking changes to flow structure or HASS dependencies
- **MINOR**: New features or significant logic changes
- **PATCH**: Bug fixes, small improvements

### Version Tracking
Track versions in FLOW-LIST.md with "Last Modified" date in YYYY-MM-DD format.

Example:
| Living Room Motion | Motion-triggered alert notification | automation | Complete | 1.2.3 | 2025-11-19 | flows/automation/motion_detection.json | Requires motion sensor entity |

---

## Flow Categories

### Automation
Home automation flows that control devices and create scenes.
- Examples: Motion-triggered lighting, Scene management, Scheduled actions
- Typical Nodes: State change triggers, HASS call service, conditional logic

### Monitoring
Flows that track system state, values, and generate reports.
- Examples: Temperature monitoring, Energy tracking, Status dashboards
- Typical Nodes: HASS state poll, time-based triggers, data aggregation

### Notifications
Flows that generate and deliver alerts and messages.
- Examples: Mobile alerts, Email notifications, Log notifications
- Typical Nodes: Trigger conditions, notification nodes, message formatting

### Integration
Flows that connect external services and APIs with Home Assistant.
- Examples: Weather data integration, Calendar sync, API endpoints
- Typical Nodes: HTTP request, data transformation, HASS update service

### Data Processing
Flows that transform, aggregate, or process data from multiple sources.
- Examples: Data aggregation, Log processing, Statistical calculation
- Typical Nodes: JSON parsing, function nodes, data aggregation

---

## Best Practices

### Node Management
- Label every node clearly (use meaningful names, not defaults)
- Group related nodes logically on canvas
- Use comment nodes to explain non-obvious logic
- Keep flows readable (avoid excessive crossing wires)

### Error Handling
- Include catch nodes for error scenarios
- Add fallback paths for critical flows
- Log errors to help with debugging
- Don't let errors silently fail

### Performance
- Avoid excessive polling of HASS states
- Use event-based triggers where possible
- Throttle notifications to prevent spam
- Clean up old flows regularly

### Documentation
- Add description in flow properties
- Comment complex logic with explanation nodes
- Document HASS entity IDs in node labels or comments
- Keep FLOW-LIST.md synchronized with actual flows

### Testing
- Test with inject nodes before deploying
- Use debug nodes to verify message content
- Test error conditions
- Verify HASS service calls have expected results
- Test in non-production environment first

---

## Common Patterns

### HASS State Monitoring
```
[trigger: entity state change] → [condition: check state value] → [action: call service] → [debug]
```

### Timed Automation
```
[trigger: time-based] → [condition: day/time check] → [action: multiple services] → [notification]
```

### Data Aggregation
```
[multiple triggers] → [collect state values] → [aggregate/calculate] → [store/notify]
```

---

## Debugging Tips

### Common Issues
- **Entity not found**: Verify exact HASS entity ID (case-sensitive)
- **Service call fails**: Check HASS service name and required parameters
- **Flow not triggering**: Verify trigger conditions and node connectivity
- **Unexpected output**: Use debug nodes to inspect message payloads

### Debug Workflow
1. Enable debug nodes on all key points
2. Use Node-RED debug panel to inspect messages
3. Check Node-RED logs for errors
4. Verify HASS entity IDs and service names
5. Test with inject node with known payload
6. Review Home Assistant automations logs

---

## MCP Tool Usage Reference Guide

This section provides practical examples of how to use each of the 20 MCP tools for common tasks.

### Flow Management Examples

#### Create a New Flow with create-flow
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/flow_lifecycle.test.js`

```javascript
// Start MCP server
const server = spawn('node', [
    '/home/divix/divtools/mcp-servers/nodered/server.js',
    'http://divix:3mpms3@10.1.1.215:1880'
]);

// Create new flow tab
const payload = {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: {
        name: 'create-flow',
        arguments: {
            label: 'My New Automation',
            nodes: [
                {
                    id: 'node1',
                    type: 'inject',
                    name: 'Test Inject',
                    z: 'tab123'
                }
            ]
        }
    }
};
server.stdin.write(JSON.stringify(payload) + '\n');
```

#### Get All Flows with get-flows
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/flow_modification.test.js`

Returns complete array of all flows including all nodes. Use this to:
- Back up current flows
- Analyze flow structure
- Prepare for flow updates

```javascript
// Send request
const payload = {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: {
        name: 'get-flows',
        arguments: {}
    }
};

// Response contains: Array of all tab and node objects
// Use this to merge new flows before calling update-flows
```

### ⚠️ CRITICAL: update-flows Safety Rules

**`update-flows` REPLACES THE ENTIRE FLOWS ARRAY.** If you don't include all existing flows, they will be DELETED.

**NEVER** call `update-flows` with only the flows you're adding/modifying. This will destroy all other flows.

**SAFE WORKFLOW:**
1. ✅ Call `get-flows` to retrieve ALL current flows
2. ✅ Merge your changes into the complete array
3. ✅ Call `update-flows` with the merged array containing ALL flows (old + new/modified)

**UNSAFE (DO NOT DO):**
```javascript
// ❌ WRONG - This deletes all other flows!
const newFlows = [shop_light_motion_flow, bug_zapper_plug_flow];
mcp_nodered_update_flows(newFlows);  // All other flows gone forever
```

**SAFE (DO THIS):**
```javascript
// ✅ CORRECT - Get all, merge, then update
const allExistingFlows = get_flows();  // Get current state
const myNewFlow = [shop_light_motion_flow];

// Filter out the old version if updating, keep everything else
const safeFlows = [
    ...allExistingFlows.filter(f => f.id !== 'shop_light_motion_tab'),
    ...myNewFlow  // Add updated version
];

mcp_nodered_update_flows(safeFlows);  // All flows preserved
```

**PREFERRED ALTERNATIVE:** Use `update-flow` for single flow updates instead:
```javascript
// ✅ BEST - Modify only the target flow, leave everything else untouched
mcp_nodered_update_flow('shop_light_motion_tab', updatedFlowObject);
```

#### Update All Flows with update-flows (DANGEROUS - USE WITH CAUTION)
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/flow_modification.test.js`

```javascript
// 1. Get current flows
const currentFlows = await getFlowsResponse; // Get from get-flows above

// 2. Prepare new flow
const newFlow = JSON.parse(fs.readFileSync('flows/automation/my_flow.json'));

// 3. Merge: Combine currentFlows array with new flow nodes
const mergedFlows = [...currentFlows, ...newFlow];

// 4. Update with merged array
const updatePayload = {
    jsonrpc: '2.0',
    id: 2,
    method: 'tools/call',
    params: {
        name: 'update-flows',
        arguments: {
            flows: mergedFlows
        }
    }
};
server.stdin.write(JSON.stringify(updatePayload) + '\n');
```

#### Delete a Flow with delete-flow
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/flow_lifecycle.test.js`

```javascript
const deletePayload = {
    jsonrpc: '2.0',
    id: 3,
    method: 'tools/call',
    params: {
        name: 'delete-flow',
        arguments: {
            id: 'shop_light_motion_tab'  // The tab's ID
        }
    }
};
```

### Node Operations Examples

#### Search for Nodes with search-nodes
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/node_operations.test.js`

Find nodes by name or label to locate nodes in flows:

```javascript
const searchPayload = {
    jsonrpc: '2.0',
    id: 4,
    method: 'tools/call',
    params: {
        name: 'search-nodes',
        arguments: {
            q: 'Motion Sensor'  // Search for nodes with this name/label
        }
    }
};
```

#### Find Nodes by Type with find-nodes-by-type
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/read_only_tools.test.js`

Get all nodes of a specific type (e.g., all function nodes, all switches):

```javascript
const findPayload = {
    jsonrpc: '2.0',
    id: 5,
    method: 'tools/call',
    params: {
        name: 'find-nodes-by-type',
        arguments: {
            type: 'function'  // Find all function nodes
        }
    }
};
// Returns array of all function nodes across all flows
```

#### Get Node Details with get-node-info
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/node_operations.test.js`

```javascript
const nodeInfoPayload = {
    jsonrpc: '2.0',
    id: 6,
    method: 'tools/call',
    params: {
        name: 'get-node-info',
        arguments: {
            node_id: 'node_1'  // Specific node ID
        }
    }
};
```

### Flow State Management Examples

#### Check Which Flows are Active with get-flows-state
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/flow_state.test.js`

```javascript
const statePayload = {
    jsonrpc: '2.0',
    id: 7,
    method: 'tools/call',
    params: {
        name: 'get-flows-state',
        arguments: {}
    }
};
// Returns: { id: 'tab123', disabled: false }
```

#### Disable/Enable Flows with set-flows-state
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/flow_state.test.js`

```javascript
// Disable a flow
const disablePayload = {
    jsonrpc: '2.0',
    id: 8,
    method: 'tools/call',
    params: {
        name: 'set-flows-state',
        arguments: {
            id: 'shop_light_motion_tab',
            disabled: true
        }
    }
};

// Enable a flow
const enablePayload = {
    jsonrpc: '2.0',
    id: 9,
    method: 'tools/call',
    params: {
        name: 'set-flows-state',
        arguments: {
            id: 'shop_light_motion_tab',
            disabled: false
        }
    }
};
```

### Testing & Debugging Examples

#### Trigger an Inject Node with inject
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/advanced_tools.test.js`

Send test data to a flow by triggering an inject node:

```javascript
const injectPayload = {
    jsonrpc: '2.0',
    id: 10,
    method: 'tools/call',
    params: {
        name: 'inject',
        arguments: {
            id: 'test_inject_node'  // Inject node's ID
        }
    }
};
```

#### Analyze Flow Health with get-diagnostics
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/read_only_tools.test.js`

Check for issues, unreachable nodes, and warnings:

```javascript
const diagPayload = {
    jsonrpc: '2.0',
    id: 11,
    method: 'tools/call',
    params: {
        name: 'get-diagnostics',
        arguments: {}
    }
};
// Returns: { nodeCount: 25, unreachableNodes: [], warnings: [...] }
```

#### Visualize Flow Architecture with visualize-flows
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/read_only_tools.test.js`

Get structured view of flow composition:

```javascript
const vizPayload = {
    jsonrpc: '2.0',
    id: 12,
    method: 'tools/call',
    params: {
        name: 'visualize-flows',
        arguments: {}
    }
};
// Returns formatted summary with node type statistics
```

### Discovery Examples

#### Get Server Configuration with get-settings
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/read_only_tools.test.js`

```javascript
const settingsPayload = {
    jsonrpc: '2.0',
    id: 13,
    method: 'tools/call',
    params: {
        name: 'get-settings',
        arguments: {}
    }
};
// Returns Node-RED configuration, environment, loaded modules
```

#### Get Available API Endpoints with api-help
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/read_only_tools.test.js`

```javascript
const helpPayload = {
    jsonrpc: '2.0',
    id: 14,
    method: 'tools/call',
    params: {
        name: 'api-help',
        arguments: {}
    }
};
// Returns documentation of available API routes
```

#### List All Flow Tabs with list-tabs
**Test Reference**: `/home/divix/divtools/mcp-servers/nodered/test/read_only_tools.test.js`

```javascript
const tabsPayload = {
    jsonrpc: '2.0',
    id: 15,
    method: 'tools/call',
    params: {
        name: 'list-tabs',
        arguments: {}
    }
};
// Returns: [{ id: 'tab1', label: 'Shop Light - Motion' }, ...]
```

### Advanced Examples

#### Complete Flow Import Workflow
```bash
#!/bin/bash
# 1. Start MCP server
node /home/divix/divtools/mcp-servers/nodered/server.js http://divix:3mpms3@10.1.1.215:1880 &
SERVER_PID=$!

# 2. Get current flows
curl -X POST http://localhost:9999/tools/call \
  -H 'Content-Type: application/json' \
  -d '{"method":"tools/call","params":{"name":"get-flows","arguments":{}}}'

# 3. Read new flow
NEW_FLOW=$(cat flows/automation/my_new_flow.json)

# 4. Merge and update (you'd parse and merge in practice)
# 5. Check result
curl -X POST http://localhost:9999/tools/call \
  -H 'Content-Type: application/json' \
  -d '{"method":"tools/call","params":{"name":"get-flows-formatted","arguments":{}}}'

# 6. Stop server
kill $SERVER_PID
```

---

## References

### Documentation
- **FLOW-LIST.md**: Master registry of all flows
- **NODERED-PROJECT-HISTORY.md**: Design decisions and architecture
- **HASS-SERVER-INFO.md**: Server versions and capabilities

### MCP Tools Documentation
- **Server Code**: `/home/divix/divtools/mcp-servers/nodered/server.js`
- **Test Suite**: `/home/divix/divtools/mcp-servers/nodered/test/` (6 test files, 20 tools, 100% coverage)
- **Test Client**: `/home/divix/divtools/mcp-servers/nodered/test/mcp-client.js` (JSON-RPC client reference)

### External Resources
- [Node-RED Official Docs](https://nodered.org/docs/)
- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [Home Assistant Node-RED Addon](https://github.com/hassio-addons/addon-node-red)
- [Node-RED Home Assistant Integration](https://nodered.org/docs/user-guide/editor/palette/core)

### divtools Integration
- See parent directory for divtools project guidelines
- Follow divtools folder structure conventions
- Refer to divtools AGENTS.md for cross-project standards