# Local Node-RED MCP Server

This local MCP server wraps Node-RED's Admin API and provides a set of tools for reading and managing flows via the Model Context Protocol (MCP).

## Usage

Start the server using the Node-RED URL and optional basic auth as arguments:

```bash
# Basic example (no auth)
node server.js http://127.0.0.1:1880

# Use if Node-RED has basic auth credentials included
node server.js http://127.0.0.1:1880 username:password

# Or set environment variables
NODE_RED_URL=http://127.0.0.1:1880 NODE_RED_AUTH=username:password node server.js
```

## Tools Implemented

### Flow Management
- **get-flows** - Retrieve all Node-RED flows and tabs
- **get-flow** - Retrieve a specific flow/tab by ID
- **update-flows** - Replace entire flows configuration
- **update-flow** - Update a specific flow/tab by ID
- **create-flow** - Create a new tab with optional nodes
- **delete-flow** - Delete a flow/tab by ID
- **list-tabs** - List all Node-RED tabs (label and ID)
- **get-flows-state** - Get disabled/enabled state of flows
- **set-flows-state** - Set disabled/enabled state for a flow
- **get-flows-formatted** - Simplified summary of flows with node counts
- **visualize-flows** - Structured visualization with node type statistics

### Node Management
- **get-nodes** - Get nodes on a specific tab
- **get-node-info** - Return details for a specific node
- **find-nodes-by-type** - Find nodes by type (e.g., "ha-get-entities")
- **search-nodes** - Search nodes by name or label
- **inject** - Trigger an inject node by ID
- **toggle-node-module** - Enable/disable a Node-RED node module

### System & Diagnostics
- **get-settings** - Retrieve Node-RED runtime settings
- **get-diagnostics** - Return diagnostics (node counts, statistics)
- **api-help** - Return Node-RED admin API endpoints available

## Implementation Notes

## Notes
- This server uses POST /flows to set flows; this will re-deploy all flows and should be used with care.
- For production use, consider forking upstream node-red-mcp-server and contributing the `description` metadata fix.

