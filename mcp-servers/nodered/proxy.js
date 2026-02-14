#!/usr/bin/env node
"use strict";
// MCP stdio -> TCP proxy for Node-RED MCP server
// Spawns the existing server.js as a child and exposes a localhost TCP port
// Last Updated: 11/20/2025 21:59:00 PM CDT

import net from 'net';
import { spawn } from 'child_process';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { v4 as uuidv4 } from 'uuid';

// args: [ node-red-url [ auth ] [ port ] ]
const nodeRedUrl = process.argv[2] || process.env.NODE_RED_URL || 'http://127.0.0.1:1880';
const nodeRedAuth = process.argv[3] || process.env.NODE_RED_AUTH || null;
const listenPort = parseInt(process.argv[4] || process.env.MCP_PROXY_PORT || '50010', 10);

console.error(`[MCP-Proxy] starting. NODE_RED_URL=${nodeRedUrl} AUTH=${nodeRedAuth ? '***REDACTED***' : 'none'} PORT=${listenPort}`);

// Resolve server.js path relative to this proxy file so it works when VS Code
// launches the proxy from a different working directory.
const __dirname = dirname(fileURLToPath(import.meta.url));
const serverScript = join(__dirname, 'server.js');
const spawnArgs = [serverScript, nodeRedUrl];
if (nodeRedAuth) spawnArgs.push(nodeRedAuth);

const child = spawn('node', spawnArgs, {
    cwd: __dirname,
    stdio: ['pipe', 'pipe', 'inherit']
});

child.on('error', (err) => console.error('[MCP-Proxy] child error', err));
child.on('exit', (code, sig) => console.error(`[MCP-Proxy] child exited code=${code} sig=${sig}`));

// Buffers and parsing for child's stdout (newline-delimited JSON)
let childBuf = '';
child.stdout.on('data', (chunk) => {
    childBuf += chunk.toString();
    const parts = childBuf.split('\n');
    childBuf = parts.pop();
    for (const p of parts) {
        if (!p.trim()) continue;
        try {
            const msg = JSON.parse(p);
            handleChildMessage(msg);
        } catch (err) {
            console.error('[MCP-Proxy] failed to parse child message', err, p.slice(0, 200));
        }
    }
});

// Map globalId -> { socket, origId }
const pending = new Map();

function handleChildMessage(msg) {
    // responses have an id; route them back to the original client
    if (msg && Object.prototype.hasOwnProperty.call(msg, 'id')) {
        const globalId = String(msg.id);
        const entry = pending.get(globalId);
        if (entry) {
            const { socket, origId } = entry;
            // rewrite id back to original
            msg.id = origId;
            try {
                socket.write(JSON.stringify(msg) + '\n');
            } catch (err) {
                console.error('[MCP-Proxy] failed to forward to client', err.message);
            }
            pending.delete(globalId);
        } else {
            // no mapping — log and ignore
            console.error('[MCP-Proxy] no pending mapping for id', globalId);
        }
    } else {
        // Notifications or other messages: ignore or log
        console.error('[MCP-Proxy] child message without id (ignored)');
    }
}

// TCP server accepting clients
const server = net.createServer((socket) => {
    console.error('[MCP-Proxy] client connected', socket.remoteAddress, socket.remotePort);
    let buf = '';

    socket.on('data', (chunk) => {
        buf += chunk.toString();
        const parts = buf.split('\n');
        buf = parts.pop();
        for (const p of parts) {
            if (!p.trim()) continue;
            try {
                const obj = JSON.parse(p);
                handleClientMessage(socket, obj);
            } catch (err) {
                console.error('[MCP-Proxy] failed to parse client JSON', err.message, p.slice(0,200));
            }
        }
    });

    socket.on('close', () => console.error('[MCP-Proxy] client disconnected'));
    socket.on('error', (err) => console.error('[MCP-Proxy] client socket error', err.message));
});

// handle listen errors (EADDRINUSE etc.) so we log a clear message and exit
server.on('error', (err) => {
    console.error('[MCP-Proxy] server error', err && err.code ? err.code : err);
    if (err && err.code === 'EADDRINUSE') {
        console.error(`[MCP-Proxy] address already in use 127.0.0.1:${listenPort}`);
    }
    // ensure child process is killed on fatal server errors
    try { child.kill(); } catch (e) {}
    process.exit(1);
});

server.listen(listenPort, '127.0.0.1', () => {
    console.error('[MCP-Proxy] listening on 127.0.0.1:' + listenPort);
});

function handleClientMessage(socket, msg) {
    // For any request with an id, rewrite the id to a global id so we can map the response
    if (msg && Object.prototype.hasOwnProperty.call(msg, 'id')) {
        const origId = msg.id;
        const globalId = uuidv4();
        // store mapping
        pending.set(globalId, { socket, origId });
        msg.id = globalId;
        // forward to child
        child.stdin.write(JSON.stringify(msg) + '\n');
    } else {
        // notification (no id) — forward as-is
        child.stdin.write(JSON.stringify(msg) + '\n');
    }
}

// Graceful shutdown
function shutdown() {
    console.error('[MCP-Proxy] shutting down');
    try { server.close(); } catch (e) {}
    try { child.kill(); } catch (e) {}
    process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
