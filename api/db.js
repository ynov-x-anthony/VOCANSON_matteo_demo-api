'use strict';

// Connexion PostgreSQL. Aucune valeur en dur : tout vient de variables
// d'environnement (bonne pratique 12-factor) ou de Docker Secrets via PGPASSWORD_FILE.
// En Compose, PGHOST = le nom du service "db", resolu par le DNS interne de Docker.

const fs = require('fs');
const { Pool } = require('pg');

let password = process.env.PGPASSWORD || 'demo';
if (process.env.PGPASSWORD_FILE && fs.existsSync(process.env.PGPASSWORD_FILE)) {
  password = fs.readFileSync(process.env.PGPASSWORD_FILE, 'utf8').trim();
}

const pool = new Pool({
  host: process.env.PGHOST || 'db',
  port: Number(process.env.PGPORT || 5432),
  user: process.env.PGUSER || 'demo',
  password: password,
  database: process.env.PGDATABASE || 'demo',
  max: Number(process.env.PGPOOL_MAX || 5),
  connectionTimeoutMillis: 3000,
});

pool.on('error', (err) => {
  console.error(JSON.stringify({ level: 'error', msg: 'pg pool error', err: err.message }));
});

async function ping() {
  const { rows } = await pool.query('SELECT 1 AS ok');
  return rows[0].ok === 1;
}

async function listProducts() {
  const { rows } = await pool.query(
    'SELECT id, name, price_cents, created_at FROM products ORDER BY id DESC LIMIT 100'
  );
  return rows;
}

async function addProduct(name, priceCents) {
  const { rows } = await pool.query(
    'INSERT INTO products (name, price_cents) VALUES ($1, $2) RETURNING id, name, price_cents, created_at',
    [name, priceCents]
  );
  return rows[0];
}

module.exports = { pool, ping, listProducts, addProduct };
