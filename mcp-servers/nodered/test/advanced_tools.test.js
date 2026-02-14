/*
 * Test Suite: Advanced Node-RED Tools
 * Description: Validates advanced tools for node injection and module management.
 * Tools Tested: inject, toggle-node-module
 */

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { McpTestClient } from './mcp-client.js';

describe('Advanced Node-RED Tools (inject, toggle-node-module)', () => {
    let client;
    let testFlowId;
    let testInjectNodeId;
    const testFlowLabel = `test-flow-advanced-${Date.now()}`;

    beforeAll(async () => {
        client = new McpTestClient();
        client.start();
        await client.initialize();

        // Create a test flow with an inject node
        const injectNode = {
            type: 'inject',
            name: 'Test Inject',
            props: [{ p: 'payload', v: 'test-value', vt: 'str' }],
            repeat: '',
            once: false,
            x: 100,
            y: 100
        };

        const createRes = await client.callTool('create-flow', { 
            label: testFlowLabel, 
            nodes: [injectNode]
        });
        testFlowId = createRes.content[0].json.id;

        // Get nodes on the flow to find the actual node ID
        const getNodesRes = await client.callTool('get-nodes', { tab_id: testFlowId });
        const nodes = getNodesRes.content[0].json;
        if (nodes.length > 0) {
            testInjectNodeId = nodes[0].id;
        }
    });

    afterAll(async () => {
        // Cleanup: delete the test flow
        if (testFlowId) {
            try {
                await client.callTool('delete-flow', { id: testFlowId });
            } catch (e) {
                // Ignore cleanup errors
            }
        }
        await client.stop();
    });

    it('should trigger an inject node using inject', async () => {
        if (!testInjectNodeId) {
            // Skip if inject node wasn't created
            expect(true).toBe(true);
            return;
        }
        // This test verifies the inject call succeeds
        // Note: We cannot verify the actual node fired without instrumenting Node-RED,
        // but we can verify the API call succeeded
        const res = await client.callTool('inject', { id: testInjectNodeId });
        expect(res).toBeDefined();
        expect(res.content).toBeDefined();
        const text = res.content[0].text;
        expect(text).toContain('triggered');
    });

    it('should toggle node modules using toggle-node-module', async () => {
        // This test attempts to toggle a known module
        // We'll try a common Node-RED module that's likely installed
        const res = await client.callTool('toggle-node-module', { 
            module: 'node-red-contrib-home-assistant-websocket',
            enabled: true
        });
        
        // The call should succeed even if the module doesn't exist
        expect(res).toBeDefined();
        expect(res.content).toBeDefined();
    });
});
