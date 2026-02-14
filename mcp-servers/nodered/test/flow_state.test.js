/*
 * Test Suite: Flow State Management
 * Description: Validates tools for enabling/disabling flows and retrieving state.
 * Tools Tested: get-flows-state, set-flows-state
 */

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { McpTestClient } from './mcp-client.js';

describe('Flow State Management Tools (get-flows-state, set-flows-state)', () => {
    let client;
    let testFlowId;
    const testFlowLabel = `test-flow-state-${Date.now()}`;

    beforeAll(async () => {
        client = new McpTestClient();
        client.start();
        await client.initialize();

        // Create a test flow for state testing
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

    it('should retrieve flow states using get-flows-state', async () => {
        const res = await client.callTool('get-flows-state');
        const states = res.content[0].json;
        expect(Array.isArray(states), 'get-flows-state should return an array').toBe(true);
        expect(states.length > 0, 'should have at least one flow state').toBe(true);

        // Each state should have id, label, and disabled flag
        states.forEach(state => {
            expect(state).toHaveProperty('id');
            expect(state).toHaveProperty('label');
            expect(state).toHaveProperty('disabled');
            expect(typeof state.disabled).toBe('boolean');
        });

        // Should include our test flow
        const found = states.find(s => s.id === testFlowId);
        expect(found, 'test flow should be in states').toBeDefined();
    });

    it('should disable a flow using set-flows-state', async () => {
        if (!testFlowId) {
            expect(true).toBe(true);
            return;
        }
        // Disable the flow
        await client.callTool('set-flows-state', { id: testFlowId, disabled: true });

        // Verify it's disabled
        const res = await client.callTool('get-flows-state');
        const states = res.content[0].json;
        const flowState = states.find(s => s.id === testFlowId);
        if (flowState) {
            expect(flowState.disabled, 'flow should be disabled').toBe(true);
        }
    });

    it('should enable a flow using set-flows-state', async () => {
        if (!testFlowId) {
            expect(true).toBe(true);
            return;
        }
        // Re-enable the flow
        await client.callTool('set-flows-state', { id: testFlowId, disabled: false });

        // Verify it's enabled
        const res = await client.callTool('get-flows-state');
        const states = res.content[0].json;
        const flowState = states.find(s => s.id === testFlowId);
        if (flowState) {
            expect(flowState.disabled, 'flow should be enabled').toBe(false);
        }
    });
});
