/*
 * Test Suite: Flow Lifecycle Management
 * Description: Validates the creation, verification, and deletion of Node-RED flows (tabs).
 * Tools Tested: create-flow, get-flow, get-flows-formatted, delete-flow
 */

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { McpTestClient } from './mcp-client.js';

describe('Flow Lifecycle Tools (create-flow, delete-flow)', () => {
    let client;

    beforeAll(async () => {
        client = new McpTestClient();
        client.start();
        await client.initialize();
    });

    afterAll(async () => {
        await client.stop();
    });

    it('should successfully create a new flow, verify it exists, and then delete it', async () => {
        const ts = Date.now();
        const label = `Flow-Test-Vitest-${ts}`;

        // 1. Verify it doesn't exist (using get-flows-formatted)
        const before = await client.callTool('get-flows-formatted');
        const beforeTabs = (before.content[0].json) || [];
        expect(beforeTabs.find(t => t.label === label), 'Flow should not exist before creation').toBeUndefined();

        // 2. Create flow (using create-flow)
        const createRes = await client.callTool('create-flow', { label, nodes: [] });
        const created = createRes.content[0].json;
        expect(created, 'create-flow should return the created flow object').toBeDefined();
        expect(created.id, 'Created flow should have an ID').toBeDefined();
        expect(created.label, 'Created flow should have the correct label').toBe(label);
        const newId = created.id;

        // 3. Verify existence via get-flows-formatted
        const after = await client.callTool('get-flows-formatted');
        const afterTabs = after.content[0].json;
        const found = afterTabs.find(t => t.id === newId || t.label === label);
        expect(found, 'New flow should appear in get-flows-formatted list').toBeDefined();

        // 4. Verify details via get-flow
        const getRes = await client.callTool('get-flow', { id: newId });
        const gotFlow = getRes.content[0].json;
        expect(gotFlow, 'get-flow should return the flow details').toBeDefined();
        expect(gotFlow.id).toBe(newId);
        expect(gotFlow.type).toBe('tab');

        // 5. Delete flow (using delete-flow)
        await client.callTool('delete-flow', { id: newId });

        // 6. Verify removal (using get-flows-formatted)
        const final = await client.callTool('get-flows-formatted');
        const finalTabs = final.content[0].json;
        expect(finalTabs.find(t => t.id === newId), 'Flow should be removed after delete-flow').toBeUndefined();
    });
});
