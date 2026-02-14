#!/usr/bin/env node
/*
 * Node-RED HTTP API Server - Direct REST API access to Node-RED admin API
 * Last Updated: 11/20/2025 11:30:00 PM CDT
 *
 * Provides direct HTTP REST endpoints for Node-RED flows and nodes management.
 * Bypasses VS Code MCP client issues by providing direct API access.
 */

import axios from 'axios';
import express from 'express';
import { v4 as uuidv4 } from 'uuid';

// Basic config - node-red url should be provided via the argument or env
let nodeRedUrl = process.argv[2] || process.env.NODE_RED_URL || 'http://127.0.0.1:1880';
let nodeRedAuth = process.argv[3] || process.env.NODE_RED_AUTH || null; // e.g. username:password
let httpPort = process.argv[4] || process.env.HTTP_PORT || 3001;

console.log(`[HTTP-Server] Starting on port ${httpPort}, Node-RED URL: ${nodeRedUrl}`);

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

const app = express();
app.use(express.json());

// Tool implementations (same as MCP server)
async function getFlows() {
    const r = await client.get('/flows');
    return r.data;
}

async function getFlow(flowId) {
    const r = await client.get('/flows');
    const flow = r.data.find(x => x.id === flowId);
    if (!flow) {
        throw new Error(`Flow id ${flowId} not found`);
    }
    return flow;
}

async function listTabs() {
    const r = await client.get('/flows');
    const tabs = r.data.filter(x => x.type === 'tab').map(t => ({ id: t.id, label: t.label }));
    return tabs;
}

async function getNodes(tabId) {
    const r = await client.get('/flows');
    const nodes = r.data.filter(x => x.type !== 'tab' && x.z === tabId);
    return nodes;
}

async function getNodeInfo(nodeId) {
    const r = await client.get('/flows');
    const node = r.data.find(x => x.id === nodeId);
    if (!node) {
        throw new Error(`Node id ${nodeId} not found`);
    }
    return node;
}

async function updateFlows(flows) {
    const r = await client.post('/flows', flows);
    return 'Flows updated via POST /flows';
}

async function updateFlow(flowId, nodes, label) {
    const r = await client.get('/flows');
    const flows = r.data;
    // Remove the existing tab and nodes
    const filtered = flows.filter(x => !(x.type === 'tab' && x.id === flowId) && !(x.z === flowId));
    // create new tab prop
    const tabObj = { id: flowId, type: 'tab', label: label || (flows.find(x => x.id === flowId) || {}).label || 'flow', disabled: false, info: '' };
    nodes.forEach(n => { n.z = flowId; if (!n.id) n.id = uuidv4().replace(/-/g, '').slice(0, 16); });
    const newFlows = filtered.concat([tabObj]).concat(nodes);
    await client.post('/flows', newFlows);
    return `Flow ${flowId} updated`;
}

async function createFlow(label, nodes) {
    const r = await client.get('/flows');
    const flows = r.data;
    // create tab
    const tabId = uuidv4().replace(/-/g, '').slice(0, 16);
    const tabObj = { id: tabId, type: 'tab', label: label, disabled: false, info: '' };
    // assign node z to tab id
    nodes.forEach(n => { n.z = tabId; if (!n.id) n.id = uuidv4().replace(/-/g, '').slice(0, 16); });
    const newFlows = flows.concat([tabObj]).concat(nodes);
    await client.post('/flows', newFlows);
    return { id: tabId, label };
}

async function deleteFlow(flowId) {
    const r = await client.get('/flows');
    const flows = r.data.filter(x => !(x.type === 'tab' && x.id === flowId) && !(x.z === flowId));
    await client.post('/flows', flows);
    return `Flow ${flowId} deleted`;
}

async function findNodesByType(nodeType) {
    const r = await client.get('/flows');
    const nodes = r.data.filter(x => x.type !== 'tab' && x.type === nodeType);
    return nodes;
}

async function searchNodes(q) {
    const query = q.toLowerCase();
    const r = await client.get('/flows');
    const nodes = r.data.filter(x => x.type !== 'tab' && ((x.name && x.name.toLowerCase().includes(query)) || (x.label && x.label.toLowerCase().includes(query))));
    return nodes;
}

async function getFlowsState() {
    const r = await client.get('/flows');
    const tabs = r.data.filter(x => x.type === 'tab').map(t => ({ id: t.id, label: t.label, disabled: !!t.disabled }));
    return tabs;
}

async function setFlowsState(flowId, disabled) {
    const r = await client.get('/flows');
    const flows = r.data.map(x => {
        if (x.type === 'tab' && x.id === flowId) return { ...x, disabled };
        return x;
    });
    await client.post('/flows', flows);
    return `Flow ${flowId} set disabled=${disabled}`;
}

async function getFlowsFormatted() {
    const r = await client.get('/flows');
    const tabs = r.data.filter(x => x.type === 'tab').map(t => {
        const nodes = r.data.filter(n => n.z === t.id && n.type !== 'tab');
        return { id: t.id, label: t.label, node_count: nodes.length };
    });
    return tabs;
}

async function getDiagnostics() {
    const r = await client.get('/flows');
    const tabs = r.data.filter(x => x.type === 'tab').map(t => {
        const nodes = r.data.filter(n => n.z === t.id && n.type !== 'tab');
        return { id: t.id, label: t.label, node_count: nodes.length };
    });
    const total_nodes = r.data.filter(x => x.type !== 'tab').length;
    return { tabs, total_nodes };
}

async function inject(injectId) {
    await client.post(`/inject/${injectId}`);
    return `Inject node ${injectId} triggered`;
}

async function toggleNodeModule(module, enabled) {
    await client.put(`/nodes/${module}`, { enabled });
    return `Module ${module} ${enabled ? 'enabled' : 'disabled'}`;
}

async function visualizeFlows() {
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
    return output.join('\n');
}

async function getSettings() {
    const settings = await client.get('/settings');
    return settings.data;
}

// IMPROVED FUNCTIONS - Simpler API for common operations
async function getFlowByName(name) {
    const r = await client.get('/flows');
    // Try exact match first, then partial match
    let flow = r.data.find(x => x.type === 'tab' && x.label === name);
    if (!flow) {
        flow = r.data.find(x => x.type === 'tab' && x.label && x.label.toLowerCase().includes(name.toLowerCase()));
    }
    if (!flow) {
        throw new Error(`Flow with name "${name}" not found`);
    }
    return flow;
}

async function getFlowWithNodes(flowId) {
    const r = await client.get('/flows');
    const flow = r.data.find(x => x.id === flowId);
    if (!flow) {
        throw new Error(`Flow id ${flowId} not found`);
    }
    const nodes = r.data.filter(x => x.type !== 'tab' && x.z === flowId);
    return {
        flow: flow,
        nodes: nodes
    };
}

// HTTP Routes
app.post('/tools/get-flows', async (req, res) => {
    try {
        const result = await getFlows();
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/get-flow', async (req, res) => {
    try {
        const { id } = req.body;
        const result = await getFlow(id);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/list-tabs', async (req, res) => {
    try {
        const result = await listTabs();
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/get-nodes', async (req, res) => {
    try {
        const { tab_id } = req.body;
        const result = await getNodes(tab_id);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/get-node-info', async (req, res) => {
    try {
        const { node_id } = req.body;
        const result = await getNodeInfo(node_id);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// IMPROVED ENDPOINTS - Simpler API for common operations
app.post('/tools/get-flow-by-name', async (req, res) => {
    try {
        const { name } = req.body;
        const result = await getFlowByName(name);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/get-flow-with-nodes', async (req, res) => {
    try {
        const { id } = req.body;
        const result = await getFlowWithNodes(id);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/update-flows', async (req, res) => {
    try {
        const { flows } = req.body;
        const result = await updateFlows(flows);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/update-flow', async (req, res) => {
    try {
        const { id, nodes, label } = req.body;
        const result = await updateFlow(id, nodes, label);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/create-flow', async (req, res) => {
    try {
        const { label, nodes } = req.body;
        const result = await createFlow(label, nodes);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/delete-flow', async (req, res) => {
    try {
        const { id } = req.body;
        const result = await deleteFlow(id);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/find-nodes-by-type', async (req, res) => {
    try {
        const { type } = req.body;
        const result = await findNodesByType(type);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/search-nodes', async (req, res) => {
    try {
        const { q } = req.body;
        const result = await searchNodes(q);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/get-flows-state', async (req, res) => {
    try {
        const result = await getFlowsState();
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/set-flows-state', async (req, res) => {
    try {
        const { id, disabled } = req.body;
        const result = await setFlowsState(id, disabled);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/get-flows-formatted', async (req, res) => {
    try {
        const result = await getFlowsFormatted();
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/get-diagnostics', async (req, res) => {
    try {
        const result = await getDiagnostics();
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/inject', async (req, res) => {
    try {
        const { id } = req.body;
        const result = await inject(id);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/toggle-node-module', async (req, res) => {
    try {
        const { module, enabled } = req.body;
        const result = await toggleNodeModule(module, enabled);
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/visualize-flows', async (req, res) => {
    try {
        const result = await visualizeFlows();
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/tools/get-settings', async (req, res) => {
    try {
        const result = await getSettings();
        res.json({ success: true, data: result });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API documentation
app.get('/api-docs', (req, res) => {
    const docs = {
        description: 'Node-RED HTTP API Server',
        endpoints: [
            'POST /tools/get-flows - Get all flows',
            'POST /tools/get-flow - Get specific flow by id',
            'POST /tools/get-flow-by-name - Get flow by name/label (NEW - SIMPLIFIED)',
            'POST /tools/get-flow-with-nodes - Get flow + all its nodes in one response (NEW - SIMPLIFIED)',
            'POST /tools/list-tabs - List all tabs',
            'POST /tools/get-nodes - Get nodes for a tab',
            'POST /tools/get-node-info - Get node details',
            'POST /tools/update-flows - Replace all flows',
            'POST /tools/update-flow - Update specific flow',
            'POST /tools/create-flow - Create new flow',
            'POST /tools/delete-flow - Delete flow',
            'POST /tools/find-nodes-by-type - Find nodes by type',
            'POST /tools/search-nodes - Search nodes by name/label',
            'POST /tools/get-flows-state - Get flow states',
            'POST /tools/set-flows-state - Set flow state',
            'POST /tools/get-flows-formatted - Get formatted flow summary',
            'POST /tools/get-diagnostics - Get diagnostics',
            'POST /tools/inject - Trigger inject node',
            'POST /tools/toggle-node-module - Enable/disable module',
            'POST /tools/visualize-flows - Get flow visualization',
            'POST /tools/get-settings - Get Node-RED settings',
            'GET /health - Health check',
            'GET /api-docs - This documentation'
        ]
    };
    res.json(docs);
});

app.listen(httpPort, () => {
    console.log(`[HTTP-Server] Listening on port ${httpPort}`);
    console.log(`[HTTP-Server] API docs: http://localhost:${httpPort}/api-docs`);
    console.log(`[HTTP-Server] Health check: http://localhost:${httpPort}/health`);
});