#!/usr/bin/env node
/*
 * Node-RED MCP Server (local) - minimal wrapper for Node-RED admin REST API
 * Last Updated: 11/19/2025 18:45:00 PM CDT
 *
 * Provides tools to read and modify Node-RED flows, tabs and nodes using the
 * Node-RED Admin API. This is a lightweight MCP server designed to be run
 * locally (under ./mcp-servers/nodered/) and patched easily.
 */

import axios from 'axios';
import * as readline from 'readline';
import { v4 as uuidv4 } from 'uuid';
import * as fs from 'fs';

// Basic config - node-red url should be provided via the argument or env
let nodeRedUrl = process.argv[2] || process.env.NODE_RED_URL || 'http://127.0.0.1:1880';
let nodeRedAuth = process.argv[3] || process.env.NODE_RED_AUTH || null; // e.g. username:password

// Helper: Axios instance for node-red
const axiosOptions = {
    baseURL: nodeRedUrl,
    timeout: 20000,
    proxy: false // Force direct connection, ignore env proxies
};

if (nodeRedAuth) {
    // Basic auth
    const [user, pass] = nodeRedAuth.split(':');
    axiosOptions.auth = { username: user, password: pass };
}

const client = axios.create(axiosOptions);

// Logging function
function log(message) {
    const timestamp = new Date().toISOString();
    const logEntry = `[${timestamp}] ${message}\n`;
    fs.appendFileSync('/tmp/mcp-nodered.log', logEntry);
}

// Diagnostic startup info goes to stderr so MCP host/explorer can show it
// try {
//     const safeAuth = nodeRedAuth ? '***REDACTED***' : 'none';
//     // console.error(`[MCP-Server] PID=${process.pid} starting. NODE_RED_URL=${nodeRedUrl} AUTH=${safeAuth}`);
//     // console.error(`[MCP-Server] CWD=${process.cwd()}`);
// } catch (e) {
//     // swallow any diagnostic errors
// }

process.on('uncaughtException', (err) => {
    console.error('[MCP-Server][uncaughtException]', err && err.stack ? err.stack : err);
});
process.on('unhandledRejection', (err) => {
    console.error('[MCP-Server][unhandledRejection]', err && err.stack ? err.stack : err);
});

// Send JSON result to stdout
function sendResponse(data) {
    log(`SEND: ${JSON.stringify(data)}`);
    process.stdout.write(JSON.stringify(data) + '\n');
}

function sendError(id, code, message) {
    sendResponse({ jsonrpc: '2.0', id: id, error: { code, message } });
}

function handleInitialize(id) {
    sendResponse({
        jsonrpc: '2.0',
        id: id,
        result: {
            protocolVersion: '2024-11-05',
            capabilities: { tools: {} },
            serverInfo: { name: 'mcp-nodered-local', version: '1.0.0' }
        }
    });
}

function buildToolsList() {
    // Tools with description metadata to satisfy MCP clients
    const tools = [
        {
            name: 'ping',
            description: 'Simple ping test',
            inputSchema: { type: 'object', properties: {}, required: [] }
        },
        {
            name: 'get-flows',
            description: 'Retrieve all Node-RED flows and tabs (admin API /flows)',
            inputSchema: { type: 'object', properties: {}, required: [] }
        },
        {
            name: 'get-flow',
            description: 'Retrieve a specific flow/tab by id',
            inputSchema: { type: 'object', properties: { id: { type: 'string' } }, required: ['id'] }
        },
        {
            name: 'list-tabs',
            description: 'List all Node-RED tabs (label and id)',
            inputSchema: { type: 'object', properties: {}, required: [] }
        },
        {
            name: 'get-nodes',
            description: 'Get nodes on a specific tab (by tab id)',
            inputSchema: { type: 'object', properties: { tab_id: { type: 'string' } }, required: ['tab_id'] }
        },
        {
            name: 'get-node-info',
            description: 'Return node details given a node id',
            inputSchema: { type: 'object', properties: { node_id: { type: 'string' } }, required: ['node_id'] }
        },
        {
            name: 'update-flows',
            description: 'Replace the entire flows with provided Node-RED export JSON',
            inputSchema: {
                type: 'object',
                properties: {
                    flows: {
                        type: 'array',
                        items: { type: 'object' }   // ← this line fixes it
                        // you can be more specific if you want:
                        // items: { type: 'object', additionalProperties: true }
                    }
                },
                required: ['flows']
            }
        },
        {
            name: 'create-flow',
            description: 'Create a new tab (flow) and add nodes (append to existing flows)',
            inputSchema: {
                type: 'object',
                properties: {
                    label: {
                        type: 'string',
                        description: 'The label/name for the new tab'
                    },
                    nodes: {
                        type: 'array',
                        items: { type: 'object' },  // ← this line fixes it
                        description: 'Array of node objects to add to the new tab'
                    }
                },
                required: ['label']   // 'nodes' is optional → fine
            }
        },
        {
            name: 'delete-flow',
            description: 'Delete a flow/tab by id',
            inputSchema: { type: 'object', properties: { id: { type: 'string' } }, required: ['id'] }
        },
        {
            name: 'find-nodes-by-type',
            description: 'Find nodes by node type (e.g., "ha-get-entities")',
            inputSchema: { type: 'object', properties: { type: { type: 'string' } }, required: ['type'] }
        },
        {
            name: 'search-nodes',
            description: 'Search nodes by name or label',
            inputSchema: { type: 'object', properties: { q: { type: 'string' } }, required: ['q'] }
        },
        {
            name: 'api-help',
            description: 'Return Node-RED admin API status and endpoints available',
            inputSchema: { type: 'object', properties: {}, required: [] }
        }
        ,
        {
            name: 'update-flow',
            description: 'Update the nodes of a specific flow/tab by id (replaces the tab and nodes)',
            inputSchema: { type: 'object', properties: { id: { type: 'string' }, nodes: { type: 'array', items: { type: 'object' } }, label: { type: 'string' } }, required: ['id'] }
        },
        {
            name: 'get-flows-state',
            description: 'Return the state (disabled/enabled) of each flow tab',
            inputSchema: { type: 'object', properties: {}, required: [] }
        },
        {
            name: 'set-flows-state',
            description: 'Set the state (disabled/enabled) for a specific flow tab',
            inputSchema: { type: 'object', properties: { id: { type: 'string' }, disabled: { type: 'boolean' } }, required: ['id', 'disabled'] }
        },
        {
            name: 'get-flows-formatted',
            description: 'Return a simplified, formatted summary of the flows (label/id/node count)',
            inputSchema: { type: 'object', properties: {}, required: [] }
        },
        {
            name: 'get-diagnostics',
            description: 'Return simple diagnostics (node counts, unreachable nodes) for flows',
            inputSchema: { type: 'object', properties: {}, required: [] }
        },
        {
            name: 'inject',
            description: 'Trigger an inject node by ID',
            inputSchema: { type: 'object', properties: { id: { type: 'string', description: 'Inject node ID' } }, required: ['id'] }
        },
        {
            name: 'toggle-node-module',
            description: 'Enable or disable a Node-RED node module',
            inputSchema: { type: 'object', properties: { module: { type: 'string' }, enabled: { type: 'boolean' } }, required: ['module', 'enabled'] }
        },
        {
            name: 'visualize-flows',
            description: 'Get a structured visualization of flows with node type statistics',
            inputSchema: { type: 'object', properties: {}, required: [] }
        },
        {
            name: 'get-settings',
            description: 'Retrieve Node-RED runtime settings',
            inputSchema: { type: 'object', properties: {}, required: [] }
        }
    ];

    // Validate that array types define 'items' to satisfy MCP schema expectations
    tools.forEach(t => {
        function checkSchema(obj, path = '') {
            if (!obj || typeof obj !== 'object') return;
            if (obj.type === 'array') {
                if (!('items' in obj) || (obj.items && Object.keys(obj.items).length === 0)) {
                    console.warn(`[MCP-Server] Schema warning: tool ${t.name} schema at ${path} is array but missing 'items'. Adding default items.type='object'.`);
                    // mutate to provide a reasonable default
                    obj.items = { type: 'object' };
                }
            }
            Object.keys(obj).forEach(k => {
                const v = obj[k];
                if (v && typeof v === 'object') checkSchema(v, path ? `${path}.${k}` : k);
            });
        }
        if (t.inputSchema) checkSchema(t.inputSchema);
    });

    return tools;
}

async function handleToolsCall(id, toolName, args) {
    try {
        if (toolName === 'ping') {
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'text', text: 'pong' }] } });
        } else if (toolName === 'get-flows') {
            log(`TOOL CALL: ${toolName} args=${JSON.stringify(args)}`);
            const r = await client.get('/flows');
            log(`GOT FLOWS: ${r.data.length} items`);
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: r.data }] } });
        } else if (toolName === 'get-flow') {
            const flowId = args.id;
            const r = await client.get('/flows');
            const flow = r.data.find(x => x.id === flowId);
            if (!flow) {
                sendError(id, -32001, `Flow id ${flowId} not found`);
                return;
            }
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: flow }] } });
        } else if (toolName === 'list-tabs') {
            const r = await client.get('/flows');
            const tabs = r.data.filter(x => x.type === 'tab').map(t => ({ id: t.id, label: t.label }));
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: tabs }] } });
        } else if (toolName === 'get-nodes') {
            const tabId = args.tab_id;
            const r = await client.get('/flows');
            const nodes = r.data.filter(x => x.type !== 'tab' && x.z === tabId);
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: nodes }] } });
        } else if (toolName === 'get-node-info') {
            const nodeId = args.node_id;
            const r = await client.get('/flows');
            const node = r.data.find(x => x.id === nodeId);
            if (!node) {
                sendError(id, -32001, `Node id ${nodeId} not found`);
                return;
            }
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: node }] } });
        } else if (toolName === 'update-flows') {
            const flows = args.flows;
            const r = await client.post('/flows', flows);
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'text', text: 'Flows updated via POST /flows' }] } });
        } else if (toolName === 'update-flow') {
            // Replace a single flow/tab and associated nodes
            const flowId = args.id;
            const newNodes = Array.isArray(args.nodes) ? args.nodes : [];
            const newLabel = args.label;
            const r = await client.get('/flows');
            const flows = r.data;
            // Remove the existing tab and nodes
            const filtered = flows.filter(x => !(x.type === 'tab' && x.id === flowId) && !(x.z === flowId));
            // create new tab prop
            const tabObj = { id: flowId, type: 'tab', label: newLabel || (flows.find(x => x.id === flowId) || {}).label || 'flow', disabled: false, info: '' };
            newNodes.forEach(n => { n.z = flowId; if (!n.id) n.id = uuidv4().replace(/-/g, '').slice(0, 16); });
            const newFlows = filtered.concat([tabObj]).concat(newNodes);
            await client.post('/flows', newFlows);
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'text', text: `Flow ${flowId} updated` }] } });
        } else if (toolName === 'create-flow') {
            const label = args.label;
            const nodes = Array.isArray(args.nodes) ? args.nodes : [];
            const r = await client.get('/flows');
            const flows = r.data;
            // create tab
            const tabId = uuidv4().replace(/-/g, '').slice(0, 16);
            const tabObj = { id: tabId, type: 'tab', label: label, disabled: false, info: '' };
            // assign node z to tab id
            nodes.forEach(n => { n.z = tabId; if (!n.id) n.id = uuidv4().replace(/-/g, '').slice(0, 16); });
            const newFlows = flows.concat([tabObj]).concat(nodes);
            await client.post('/flows', newFlows);
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: { id: tabId, label } }] } });
        } else if (toolName === 'delete-flow') {
            const delId = args.id;
            const r = await client.get('/flows');
            const flows = r.data.filter(x => !(x.type === 'tab' && x.id === delId) && !(x.z === delId));
            await client.post('/flows', flows);
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'text', text: `Flow ${delId} deleted` }] } });
        } else if (toolName === 'find-nodes-by-type') {
            const nodeType = args.type;
            const r = await client.get('/flows');
            const nodes = r.data.filter(x => x.type !== 'tab' && x.type === nodeType);
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: nodes }] } });
        } else if (toolName === 'search-nodes') {
            const q = args.q.toLowerCase();
            const r = await client.get('/flows');
            const nodes = r.data.filter(x => x.type !== 'tab' && ((x.name && x.name.toLowerCase().includes(q)) || (x.label && x.label.toLowerCase().includes(q))));
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: nodes }] } });
        } else if (toolName === 'api-help') {
            // return basic API endpoints supported
            const info = {
                base: nodeRedUrl,
                endpoints: [
                    '/flows (GET/POST)',
                    '/nodes (palette listing)',
                    '/settings (various)'
                ]
            };
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: info }] } });
        } else if (toolName === 'get-flows-state') {
            const r = await client.get('/flows');
            const tabs = r.data.filter(x => x.type === 'tab').map(t => ({ id: t.id, label: t.label, disabled: !!t.disabled }));
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: tabs }] } });
        } else if (toolName === 'set-flows-state') {
            const flowId = args.id;
            const disabled = !!args.disabled;
            const r = await client.get('/flows');
            const flows = r.data.map(x => {
                if (x.type === 'tab' && x.id === flowId) return { ...x, disabled };
                return x;
            });
            await client.post('/flows', flows);
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'text', text: `Flow ${flowId} set disabled=${disabled}` }] } });
        } else if (toolName === 'get-flows-formatted') {
            const r = await client.get('/flows');
            const tabs = r.data.filter(x => x.type === 'tab').map(t => {
                const nodes = r.data.filter(n => n.z === t.id && n.type !== 'tab');
                return { id: t.id, label: t.label, node_count: nodes.length };
            });
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: tabs }] } });
        } else if (toolName === 'get-diagnostics') {
            const r = await client.get('/flows');
            const tabs = r.data.filter(x => x.type === 'tab').map(t => {
                const nodes = r.data.filter(n => n.z === t.id && n.type !== 'tab');
                return { id: t.id, label: t.label, node_count: nodes.length };
            });
            const total_nodes = r.data.filter(x => x.type !== 'tab').length;
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: { tabs, total_nodes } }] } });
        } else if (toolName === 'inject') {
            const injectId = args.id;
            await client.post(`/inject/${injectId}`);
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'text', text: `Inject node ${injectId} triggered` }] } });
        } else if (toolName === 'toggle-node-module') {
            const module = args.module;
            const enabled = args.enabled;
            await client.put(`/nodes/${module}`, { enabled });
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'text', text: `Module ${module} ${enabled ? 'enabled' : 'disabled'}` }] } });
        } else if (toolName === 'visualize-flows') {
            const r = await client.get('/flows');
            const flows = r.data;
            const tabs = flows.filter(node => node.type === 'tab');
            const nodesByTab = {};
            tabs.forEach(tab => {
                nodesByTab[tab.id] = flows.filter(node => node.z === tab.id);
            });
            const result = tabs.map(tab => {
                const nodes = nodesByTab[tab.id];
                const nodeTypes = {};
                nodes.forEach(node => {
                    if (!nodeTypes[node.type]) nodeTypes[node.type] = 0;
                    nodeTypes[node.type]++;
                });
                return {
                    id: tab.id,
                    name: tab.label || tab.name || 'Unnamed',
                    nodes: nodes.length,
                    nodeTypes: Object.entries(nodeTypes).map(([type, count]) => `${type}: ${count}`).join(', ')
                };
            });
            const output = ['# Node-RED Flow Structure', '', '## Tabs', ''];
            result.forEach(tab => {
                output.push(`### ${tab.name} (ID: ${tab.id})`);
                output.push(`- Number of nodes: ${tab.nodes}`);
                output.push(`- Node types: ${tab.nodeTypes}`);
                output.push('');
            });
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'text', text: output.join('\n') }] } });
        } else if (toolName === 'get-settings') {
            const settings = await client.get('/settings');
            sendResponse({ jsonrpc: '2.0', id: id, result: { content: [{ type: 'json', json: settings.data }] } });
        } else {
            sendError(id, -32601, `Unknown tool: ${toolName}`);
        }

    } catch (err) {
        sendError(id, -32000, `Tool execution failed: ${err.message}`);
    }
}

async function handleRequest(request) {
    log(`REQUEST: ${JSON.stringify(request)}`);
    const { jsonrpc, id, method, params } = request;
    if (method === 'initialize') {
        handleInitialize(id);
    } else if (method === 'tools/list') {
        sendResponse({ jsonrpc: '2.0', id: id, result: { tools: buildToolsList() } });
    } else if (method === 'tools/call') {
        const { name, arguments: args } = params;
        await handleToolsCall(id, name, args || {});
    } else {
        sendError(id, -32601, `Unknown method: ${method}`);
    }
}

async function main() {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: false });
    for await (const line of rl) {
        const trimmed = line.trim();
        if (!trimmed) continue;
        try {
            const request = JSON.parse(trimmed);
            await handleRequest(request);
        } catch (err) {
            console.error('[JSON Parse Error]', err.message);
        }
    }
}

main().catch(err => { console.error('[Fatal Error]', err.message); process.exit(1); });
