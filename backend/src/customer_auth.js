import { randomBytes } from 'node:crypto';
import { query } from './db.js';
import { mapTenant, verifyPassword } from './auth.js';
import { mapCustomer } from './customers.js';

const SESSION_DAYS = 30;

async function createCustomerSession(customerId) {
  const token = randomBytes(32).toString('hex');
  const expires = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
  await query(
    'INSERT INTO customer_sessions (token, customer_id, expires_at) VALUES ($1, $2, $3)',
    [token, customerId, expires.toISOString()],
  );
  return { token, expiresAt: expires.toISOString() };
}

function withTenant(row) {
  if (!row.t_id) return mapCustomer(row);
  return mapCustomer(
    row,
    mapTenant({
      id: row.t_id,
      name: row.t_name,
      slug: row.t_slug,
      type: row.t_type,
      status: row.t_status,
      plan: row.t_plan,
      phone: row.t_phone,
      email: row.t_email,
      created_at: row.t_created,
    }),
  );
}

const CUSTOMER_SELECT = `SELECT c.*, t.id AS t_id, t.name AS t_name, t.slug AS t_slug, t.type AS t_type,
        t.status AS t_status, t.plan AS t_plan, t.phone AS t_phone, t.email AS t_email,
        t.created_at AS t_created
     FROM customers c
     LEFT JOIN tenants t ON t.id = c.tenant_id`;

export async function loginCustomer(email, password, sector) {
  if (sector !== 'villa' && sector !== 'kuafor') {
    throw Object.assign(new Error('Geçersiz uygulama.'), { status: 400 });
  }
  const { rows } = await query(
    `${CUSTOMER_SELECT} WHERE lower(c.email) = lower($1)`,
    [String(email || '').trim()],
  );
  const row = rows[0];
  if (!row || !verifyPassword(password, row.password_hash)) {
    throw Object.assign(new Error('E-posta veya şifre hatalı.'), { status: 401 });
  }
  if (row.sector !== sector) {
    const other = row.sector === 'kuafor' ? 'kuaför' : 'villa';
    throw Object.assign(
      new Error(`Bu hesap ${other} müşteri uygulamasına aittir. Diğer sektörü göremez.`),
      { status: 403 },
    );
  }
  if (row.t_status === 'suspended') {
    throw Object.assign(new Error('İşletme hesabı durdurulmuş.'), { status: 403 });
  }
  const session = await createCustomerSession(row.id);
  return { ...session, user: withTenant(row) };
}

export async function logoutCustomer(token) {
  if (token) await query('DELETE FROM customer_sessions WHERE token = $1', [token]);
}

export async function loadCustomerSession(token) {
  if (!token) return null;
  const { rows } = await query(
    `${CUSTOMER_SELECT}
     JOIN customer_sessions s ON s.customer_id = c.id
     WHERE s.token = $1`,
    [token],
  );
  const row = rows[0];
  if (!row) return null;
  const { rows: sessionRows } = await query(
    'SELECT expires_at FROM customer_sessions WHERE token = $1',
    [token],
  );
  if (!sessionRows[0] || new Date(sessionRows[0].expires_at) < new Date()) {
    await query('DELETE FROM customer_sessions WHERE token = $1', [token]);
    return null;
  }
  return withTenant(row);
}

export function requireCustomer(req, res, next) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  loadCustomerSession(match ? match[1].trim() : null)
    .then((customer) => {
      if (!customer) return res.status(401).json({ error: 'Oturum gerekli.' });
      req.customer = customer;
      next();
    })
    .catch(next);
}

export function requireCustomerSector(sector) {
  return (req, res, next) => {
    if (req.customer?.sector !== sector) {
      return res.status(403).json({ error: 'Bu uygulama bu müşteri için değil.' });
    }
    next();
  };
}
