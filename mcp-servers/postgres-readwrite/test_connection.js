#!/usr/bin/env node
/**
 * Test connection to PostgreSQL database
 */

import pg from 'pg';

const { Pool } = pg;

const dbConfig = {
    host: process.env.DB_HOST || '10.1.1.74',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    user: process.env.DB_USER || 'divix',
    password: process.env.DB_PASSWORD || 'passwd',
    database: process.env.DB_NAME || 'dthostmon'
};

console.log('Testing connection with config:', {
    host: dbConfig.host,
    port: dbConfig.port,
    user: dbConfig.user,
    database: dbConfig.database,
    password: '***'
});

const pool = new Pool(dbConfig);

// Add event listeners for debugging
pool.on('connect', () => {
    console.log('Pool connected');
});

pool.on('error', (err) => {
    console.error('Pool error:', err.message);
});

pool.query('SELECT version()', (err, result) => {
    if (err) {
        console.error('Connection failed:', err.message);
        console.error('Error code:', err.code);
        console.error('Full error:', err);
        process.exit(1);
    } else {
        console.log('Connection successful!');
        console.log('PostgreSQL version:', result.rows[0].version);
        pool.end();
        process.exit(0);
    }
});
