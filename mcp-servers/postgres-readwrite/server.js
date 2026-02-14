#!/usr/bin/env node
/**
 * PostgreSQL MCP Server with Read-Write Support
 * Last Updated: 11/13/2025 22:15:00 PM CDT
 * 
 * This MCP server provides tools to query and modify PostgreSQL databases
 * with support for SELECT, INSERT, UPDATE, DELETE, and CREATE/ALTER operations.
 */

import pg from 'pg';
import * as readline from 'readline';

const { Pool } = pg;

// Support both connection string and individual environment variables
let dbConfig;
if (process.argv[2]) {
    // Connection string passed as command line argument (like official server)
    // Pool will parse the connection string automatically
    dbConfig = {
        connectionString: process.argv[2],
        connectionTimeoutMillis: 10000,
        idleTimeoutMillis: 30000,
        application_name: 'mcp-postgres-readwrite'
    };
} else {
    // Database configuration from environment variables
    dbConfig = {
        host: process.env.DB_HOST || '10.1.1.74',
        port: parseInt(process.env.DB_PORT || '5432', 10),
        user: process.env.DB_USER || 'divix',
        password: process.env.DB_PASSWORD || 'pass',
        database: process.env.DB_NAME || 'dthostmon',
        connectionTimeoutMillis: 10000,
        idleTimeoutMillis: 30000,
        application_name: 'mcp-postgres-readwrite'
    };
}

// Initialize connection pool
const pool = new Pool(dbConfig);

// Handle pool errors
pool.on('error', (err) => {
    console.error('[Pool Error]', err.message);
});

/**
 * Send JSON response to stdout with proper newline
 */
function sendResponse(data) {
    process.stdout.write(JSON.stringify(data) + '\n');
}

/**
 * Handle initialize method
 */
function handleInitialize(id) {
    sendResponse({
        jsonrpc: '2.0',
        id: id,
        result: {
            protocolVersion: '2024-11-05',
            capabilities: {
                tools: {}
            },
            serverInfo: {
                name: 'postgres-readwrite-mcp',
                version: '1.0.0'
            }
        }
    });
}

/**
 * Handle tools/list method
 */
function handleToolsList(id) {
    sendResponse({
        jsonrpc: '2.0',
        id: id,
        result: {
            tools: [
                {
                    name: 'execute_query',
                    description: 'Execute a SQL query (SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP)',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            sql: {
                                type: 'string',
                                description: 'The SQL query to execute'
                            }
                        },
                        required: ['sql']
                    }
                },
                {
                    name: 'get_schema',
                    description: 'Get database schema information',
                    inputSchema: {
                        type: 'object',
                        properties: {
                            table_name: {
                                type: 'string',
                                description: 'Optional: specific table name to get schema for'
                            }
                        }
                    }
                }
            ]
        }
    });
}

/**
 * Handle tools/call method
 */
async function handleToolsCall(id, toolName, args) {
    try {
        if (toolName === 'execute_query') {
            const sql = args.sql;
            const result = await pool.query(sql);

            sendResponse({
                jsonrpc: '2.0',
                id: id,
                result: {
                    content: [
                        {
                            type: 'text',
                            text: `Query executed successfully.\nRows affected: ${result.rowCount}\n\nResults:\n${JSON.stringify(result.rows, null, 2)}`
                        }
                    ]
                }
            });
        } else if (toolName === 'get_schema') {
            const tableName = args.table_name;
            let query;
            let params;

            if (tableName) {
                query = `
                    SELECT column_name, data_type, is_nullable 
                    FROM information_schema.columns 
                    WHERE table_name = $1 
                    ORDER BY ordinal_position
                `;
                params = [tableName];
            } else {
                query = `
                    SELECT table_name 
                    FROM information_schema.tables 
                    WHERE table_schema = 'public'
                    ORDER BY table_name
                `;
                params = [];
            }

            const result = await pool.query(query, params);

            sendResponse({
                jsonrpc: '2.0',
                id: id,
                result: {
                    content: [
                        {
                            type: 'text',
                            text: JSON.stringify(result.rows, null, 2)
                        }
                    ]
                }
            });
        } else {
            sendResponse({
                jsonrpc: '2.0',
                id: id,
                error: {
                    code: -32601,
                    message: `Unknown tool: ${toolName}`
                }
            });
        }
    } catch (err) {
        sendResponse({
            jsonrpc: '2.0',
            id: id,
            error: {
                code: -32000,
                message: `Tool execution failed: ${err.message}`
            }
        });
    }
}

/**
 * Main request handler
 */
async function handleRequest(request) {
    try {
        const { jsonrpc, id, method, params } = request;

        if (method === 'initialize') {
            handleInitialize(id);
        } else if (method === 'tools/list') {
            handleToolsList(id);
        } else if (method === 'tools/call') {
            const { name, arguments: args } = params;
            await handleToolsCall(id, name, args);
        } else {
            sendResponse({
                jsonrpc: '2.0',
                id: id,
                error: {
                    code: -32601,
                    message: `Unknown method: ${method}`
                }
            });
        }
    } catch (err) {
        console.error('[Request Error]', err.message);
    }
}

/**
 * Main entry point
 */
async function main() {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
        terminal: false
    });

    for await (const line of rl) {
        const trimmedLine = line.trim();
        if (trimmedLine) {
            try {
                const request = JSON.parse(trimmedLine);
                await handleRequest(request);
            } catch (err) {
                console.error('[JSON Parse Error]', err.message);
            }
        }
    }

    // Cleanup on exit
    await pool.end();
    process.exit(0);
}

main().catch(err => {
    console.error('[Fatal Error]', err.message);
    process.exit(1);
});
