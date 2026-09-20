import pg from 'pg';
import { env } from './config.js';

const { Pool, types } = pg;

types.setTypeParser(types.builtins.DATE, (value) => value);

export const pool = new Pool({
  host: env.dbHost,
  port: env.dbPort,
  user: env.dbUser,
  password: env.dbPassword,
  database: env.dbName,
  max: 10,
  idleTimeoutMillis: 30_000,
  connectionTimeoutMillis: 10_000,
});

export async function query(text, params) {
  const result = await pool.query(text, params);
  return result;
}
