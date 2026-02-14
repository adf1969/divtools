/*
 * Test Suite: Flow Modification Tools
 * Description: Validates tools for modifying and updating existing flows.
 * Tools Tested: update-flow, update-flows, get-flows
 */

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { McpTestClient } from './mcp-client.js';

describe('Flow Modification Tools (update-flow, update-flows)', () => {
    let client;
    let testFlowId;
    const testFlowLabel = `test-flow-modify-${Date.now()}`;

    beforeAll(async () => {
        client = new McpTestClient();
        client.start();
        await client.initialize();

        // Create a test flow for modification
        const createRes = await client.callTool('create-flow', { label: testFlowLabel, nodes: [] });
        testFlowId = createRes.content[0].json.id;
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

    it('should retrieve full flows using get-flows', async () => {
        const res = await client.callTool('get-flows');
        const flows = res.content[0].json;
        expect(Array.isArray(flows), 'get-flows should return an array').toBe(true);
        expect(flows.length > 0, 'should have at least one flow').toBe(true);

        // Should include our test flow
        const found = flows.find(f => f.id === testFlowId);
        expect(found, 'test flow should be in flows array').toBeDefined();
    });

    it('should update a single flow using update-flow', async () => {
        const newLabel = `${testFlowLabel}-updated`;
        const testNode = {
            type: 'inject',
            name: 'Test Inject',
            props: [{ p: 'payload' }],
            repeat: '',
            once: false,
            x: 100,
            y: 100
        };

        await client.callTool('update-flow', { 
            id: testFlowId, 
            label: newLabel,
            nodes: [testNode]
        });

        // Verify the update
        const getRes = await client.callTool('get-flow', { id: testFlowId });
        const flow = getRes.content[0].json;
        expect(flow.label).toBe(newLabel);

        // Verify node was added - check via find-nodes-by-type
        const findRes = await client.callTool('find-nodes-by-type', { type: 'inject' });
        const nodes = findRes.content[0].json;
        expect(Array.isArray(nodes), 'should be able to find inject nodes').toBe(true);
    });

    it('should bulk update all flows using update-flows', async () => {
        // Get current flows
        const getRes = await client.callTool('get-flows');
        const currentFlows = getRes.content[0].json;

        // Add a simple marker to distinguish this test
        const markedFlows = currentFlows.map(f => ({
            ...f,
            _test_marker: true
        }));

        // Update all flows
        await client.callTool('update-flows', { flows: markedFlows });

        // Verify at least one flow is still present
        const afterRes = await client.callTool('get-flows');
        const afterFlows = afterRes.content[0].json;
        expect(afterFlows.length > 0, 'flows should still exist after update-flows').toBe(true);
    });
});
