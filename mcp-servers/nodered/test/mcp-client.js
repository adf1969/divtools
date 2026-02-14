import { spawn } from 'child_process';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const SERVER_PATH = join(__dirname, '../server.js');
const NODE_RED_ARG = process.env.NODE_RED_URL || 'http://divix:3mpms3@10.1.1.215:1880';

export class McpTestClient {
    constructor() {
        this.server = null;
        this.buf = '';
        this.pending = new Map();
        this.nextId = 1;
    }

    start() {
        this.server = spawn('node', [SERVER_PATH, NODE_RED_ARG], { 
            cwd: join(__dirname, '..'),
            env: { ...process.env }
        });

        this.server.stdout.on('data', data => {
            const s = data.toString();
            this.buf += s;
            const parts = this.buf.split('\n');
            this.buf = parts.pop();
            
            for (const p of parts) {
                if (!p.trim()) continue;
                try {
                    const msg = JSON.parse(p);
                    if (msg && msg.id && this.pending.has(msg.id)) {
                        const { resolve, reject, timeout } = this.pending.get(msg.id);
                        clearTimeout(timeout);
                        this.pending.delete(msg.id);
                        if (msg.error) {
                            reject(new Error(`MCP Error ${msg.error.code}: ${msg.error.message}`));
                        } else {
                            resolve(msg.result);
                        }
                    }
                } catch (err) {
                    console.error('[TestClient] Parse error:', err);
                }
            }
        });

        this.server.stderr.on('data', d => {
            // Uncomment to see server stderr during tests
            // process.stderr.write(d.toString());
        });
    }

    async stop() {
        if (this.server) {
            this.server.stdin.end();
            this.server.kill();
            this.server = null;
        }
    }

    request(method, params = {}) {
        if (!this.server) throw new Error('Server not started');
        
        const id = this.nextId++;
        const payload = { jsonrpc: '2.0', id, method };
        if (method === 'tools/call') {
            payload.params = params;
        }

        return new Promise((resolve, reject) => {
            const timeout = setTimeout(() => {
                this.pending.delete(id);
                reject(new Error(`RPC timeout for method ${method} (id=${id})`));
            }, 15000);

            this.pending.set(id, { resolve, reject, timeout });

            try {
                this.server.stdin.write(JSON.stringify(payload) + '\n');
            } catch (err) {
                clearTimeout(timeout);
                this.pending.delete(id);
                reject(err);
            }
        });
    }

    async callTool(name, args = {}) {
        return this.request('tools/call', { name, arguments: args });
    }

    async initialize() {
        return this.request('initialize');
    }
}
