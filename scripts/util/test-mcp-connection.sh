#!/bin/bash
# Test MCP connection with proper protocol sequence
# Last Updated: 2/5/2025 10:00:00 PM CST

echo "Testing MCP connection to Home Assistant..."
echo "=========================================="

# MCP initialize request
INIT_REQUEST='{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-06-18",
    "capabilities": {
      "tools": {}
    },
    "clientInfo": {
      "name": "mcp-test-client",
      "version": "1.0.0"
    }
  }
}'

# MCP tools/list request
TOOLS_REQUEST='{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list"
}'

echo "1. Sending initialize request..."
echo "$INIT_REQUEST" | /home/divix/divtools/scripts/mcp-proxy \
  --transport=streamablehttp \
  --stateless \
  --headers Authorization "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIxY2Y2NjRhZTcyZGI0MjkyYmM5ZDNiYmQ5MDdkYjNjZSIsImlhdCI6MTc2MzU3NDQ2MSwiZXhwIjoyMDc4OTM0NDYxfQ.IjL0NbE9rOsNvdlz8W5LCQ31Fn4HtWVto-P4vnIDETY" \
  http://10.1.1.215:8123/api/mcp 2>&1 | head -10

echo ""
echo "2. Sending tools/list request..."
echo "$TOOLS_REQUEST" | /home/divix/divtools/scripts/mcp-proxy \
  --transport=streamablehttp \
  --stateless \
  --headers Authorization "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIxY2Y2NjRhZTcyZGI0MjkyYmM5ZDNiYmQ5MDdkYjNjZSIsImlhdCI6MTc2MzU3NDQ2MSwiZXpwIjoyMDc4OTM0NDYxfQ.IjL0NbE9rOsNvdlz8W5LCQ31Fn4HtWVto-P4vnIDETY" \
  http://10.1.1.215:8123/api/mcp 2>&1 | head -10

echo ""
echo "=========================================="
echo "Test complete. Check for successful responses above."