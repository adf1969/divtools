/*
 * Test Suite: Read-Only Tools
 * Description: Validates the functionality of read-only tools that retrieve information from Node-RED.
 * Tools Tested: list-tabs, get-flows-formatted, get-diagnostics, get-settings, visualize-flows, api-help, find-nodes-by-type
 */

import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { McpTestClient } from './mcp-client.js';

describe('Read-Only Tools (Information Retrieval)', () => {
    let client;

    beforeAll(async () => {
        client = new McpTestClient();
        client.start();
        await client.initialize();
    });

    afterAll(async () => {
        await client.stop();
    });

    it('should list all tabs using list-tabs', async () => {
        const res = await client.callTool('list-tabs');
        const tabs = res.content[0].json;
        expect(Array.isArray(tabs), 'list-tabs should return an array').toBe(true);
        if (tabs.length > 0) {
            expect(tabs[0]).toHaveProperty('id');
            expect(tabs[0]).toHaveProperty('label');
        }
    });

    it('should get formatted flow summaries using get-flows-formatted', async () => {
        const res = await client.callTool('get-flows-formatted');
        const tabs = res.content[0].json;
        expect(Array.isArray(tabs), 'get-flows-formatted should return an array').toBe(true);
        if (tabs.length > 0) {
            expect(tabs[0]).toHaveProperty('node_count');
        }
    });

    it('should get diagnostics using get-diagnostics', async () => {
        const res = await client.callTool('get-diagnostics');
        const diag = res.content[0].json;
        expect(diag).toHaveProperty('total_nodes');
        expect(diag).toHaveProperty('tabs');
        expect(Array.isArray(diag.tabs)).toBe(true);
    });

    it('should get runtime settings using get-settings', async () => {
        const res = await client.callTool('get-settings');
        const settings = res.content[0].json;
        expect(settings).toBeDefined();
        // Check for some common Node-RED settings properties
        expect(settings).toHaveProperty('version');
    });

    it('should generate a markdown visualization using visualize-flows', async () => {
        const res = await client.callTool('visualize-flows');
        const text = res.content[0].text;
        expect(typeof text).toBe('string');
        expect(text).toContain('# Node-RED Flow Structure');
    });

    it('should get API help information using api-help', async () => {
        const res = await client.callTool('api-help');
        const info = res.content[0].json;
        expect(info).toHaveProperty('base');
        expect(info).toHaveProperty('endpoints');
    });

    it('should find nodes by type using find-nodes-by-type', async () => {
        // 'inject' is a very common node type
        const res = await client.callTool('find-nodes-by-type', { type: 'inject' });
        const nodes = res.content[0].json;
        expect(Array.isArray(nodes), 'find-nodes-by-type should return an array').toBe(true);
        // We might not have inject nodes, but the call should succeed
    });
});
