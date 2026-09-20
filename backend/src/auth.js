import { randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';
import { query } from './db.js';
import { getVertical } from './verticals.js';

const SESSION_DAYS = 30;

export function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  const hash = scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${hash}`;
}

export function verifyPassword(password, stored) {
  const [salt, hash] = String(stored).split(':');
  if (!salt || !hash) return false;
  const check = scryptSync(password, salt, 64);
  const actual = Buffer.from(hash, 'hex');
  if (check.length !== actual.length) return false;
  return timingSafeEqual(actual, check);
}

export function mapUser(row, tenant = null) {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    name: row.name,
    email: row.email,
    role: row.role,
    isAdmin: row.role === 'super_admin',
    tenant,
    vertical: tenant ? getVertical(tenant.type) : null,
  };
}

export function mapTenant(row) {
  return {
    id: row.id,
    name: row.name,
    slug: row.slug,
    type: row.type,
    typeLabel: getVertical(row.type).label,
    status: row.status,
    plan: row.plan,
    phone: row.phone,
    email: row.email,
    createdAt: row.created_at,
  };
}

export async function createSession(userId) {
  const token = randomBytes(32).toString('hex');
  const expires = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
  await query(
    'INSERT INTO sessions (token, user_id, expires_at) VALUES ($1, $2, $3)',
    [token, userId, expires.toISOString()],
  );
  return { token, expiresAt: expires.toISOString() };
}

export async function login(email, password) {
  const { rows } = await query(
    `SELECT u.*, t.id AS t_id, t.name AS t_name, t.slug AS t_slug, t.type AS t_type,
            t.status AS t_status, t.plan AS t_plan, t.phone AS t_phone, t.email AS t_email,
            t.created_at AS t_created
     FROM users u
     LEFT JOIN tenants t ON t.id = u.tenant_id
     WHERE lower(u.email) = lower($1)`,
    [String(email || '').trim()],
  );
  const row = rows[0];
  if (!row || !verifyPassword(password, row.password_hash)) {
    const error = new Error('E-posta veya şifre hatalı.');
    error.status = 401;
    throw error;
  }
  if (row.tenant_id && row.t_status === 'suspended') {
    const error = new Error('İşletme hesabı durdurulmuş.');
    error.status = 403;
    throw error;
  }
  const tenant = row.tenant_id
    ? mapTenant({
        id: row.t_id,
        name: row.t_name,
        slug: row.t_slug,
        type: row.t_type,
        status: row.t_status,
        plan: row.t_plan,
        phone: row.t_phone,
        email: row.t_email,
        created_at: row.t_created,
      })
    : null;
  const session = await createSession(row.id);
  return { ...session, user: mapUser(row, tenant) };
}

export async function logout(token) {
  if (token) {
    await query('DELETE FROM sessions WHERE token = $1', [token]);
  }
}

export async function loadSession(token) {
  if (!token) return null;
  const { rows } = await query(
    `SELECT s.token, s.expires_at, u.*, t.id AS t_id, t.name AS t_name, t.slug AS t_slug,
            t.type AS t_type, t.status AS t_status, t.plan AS t_plan, t.phone AS t_phone,
            t.email AS t_email, t.created_at AS t_created
     FROM sessions s
     JOIN users u ON u.id = s.user_id
     LEFT JOIN tenants t ON t.id = u.tenant_id
     WHERE s.token = $1`,
    [token],
  );
  const row = rows[0];
  if (!row) return null;
  if (new Date(row.expires_at) < new Date()) {
    await query('DELETE FROM sessions WHERE token = $1', [token]);
    return null;
  }
  const tenant = row.tenant_id
    ? mapTenant({
        id: row.t_id,
        name: row.t_name,
        slug: row.t_slug,
        type: row.t_type,
        status: row.t_status,
        plan: row.t_plan,
        phone: row.t_phone,
        email: row.t_email,
        created_at: row.t_created,
      })
    : null;
  return mapUser(row, tenant);
}

export function bearer(req) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

export function requireAuth(req, res, next) {
  loadSession(bearer(req))
    .then((user) => {
      if (!user) {
        return res.status(401).json({ error: 'Oturum gerekli.' });
      }
      req.user = user;
      next();
    })
    .catch(next);
}

export function requireAdmin(req, res, next) {
  if (req.user?.role !== 'super_admin') {
    return res.status(403).json({ error: 'Panel yetkisi yok.' });
  }
  next();
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const RESET_HOURS = 2;

function tenantFromJoin(row) {
  if (!row.tenant_id) return null;
  return mapTenant({
    id: row.t_id,
    name: row.t_name,
    slug: row.t_slug,
    type: row.t_type,
    status: row.t_status,
    plan: row.t_plan,
    phone: row.t_phone,
    email: row.t_email,
    created_at: row.t_created,
  });
}

const USER_JOIN = `SELECT u.*, t.id AS t_id, t.name AS t_name, t.slug AS t_slug, t.type AS t_type,
            t.status AS t_status, t.plan AS t_plan, t.phone AS t_phone, t.email AS t_email,
            t.created_at AS t_created
     FROM users u
     LEFT JOIN tenants t ON t.id = u.tenant_id`;

export async function loadUserById(id) {
  const { rows } = await query(`${USER_JOIN} WHERE u.id = $1`, [id]);
  const row = rows[0];
  if (!row) return null;
  return mapUser(row, tenantFromJoin(row));
}

export async function updateProfile(userId, body) {
  const { rows } = await query('SELECT * FROM users WHERE id = $1', [userId]);
  const row = rows[0];
  if (!row) {
    const error = new Error('Kullanıcı bulunamadı.');
    error.status = 404;
    throw error;
  }

  const name = String(body?.name ?? row.name).trim();
  if (!name) {
    const error = new Error('Ad zorunludur.');
    error.status = 400;
    throw error;
  }

  const email = String(body?.email ?? row.email).trim().toLowerCase();
  if (!EMAIL_RE.test(email)) {
    const error = new Error('E-posta adresi geçersiz.');
    error.status = 400;
    throw error;
  }

  const newPassword = String(body?.newPassword ?? '').trim();
  const emailChanged = email !== String(row.email).toLowerCase();
  if (emailChanged || newPassword) {
    const currentPassword = String(body?.currentPassword ?? '');
    if (!currentPassword || !verifyPassword(currentPassword, row.password_hash)) {
      const error = new Error('Mevcut şifre hatalı.');
      error.status = 400;
      throw error;
    }
  }
  if (newPassword && newPassword.length < 6) {
    const error = new Error('Yeni şifre en az 6 karakter olmalı.');
    error.status = 400;
    throw error;
  }

  if (emailChanged) {
    const taken = await query(
      'SELECT 1 FROM users WHERE lower(email) = $1 AND id <> $2',
      [email, userId],
    );
    if (taken.rowCount > 0) {
      const error = new Error('Bu e-posta başka bir hesapta kayıtlı.');
      error.status = 409;
      throw error;
    }
  }

  const passwordHash = newPassword ? hashPassword(newPassword) : row.password_hash;
  await query(
    'UPDATE users SET name = $1, email = $2, password_hash = $3 WHERE id = $4',
    [name, email, passwordHash, userId],
  );
  return loadUserById(userId);
}

export async function requestPasswordReset(email) {
  const normalized = String(email || '').trim().toLowerCase();
  if (!EMAIL_RE.test(normalized)) return;

  const { rows } = await query(
    'SELECT id, name, email FROM users WHERE lower(email) = $1',
    [normalized],
  );
  const user = rows[0];
  if (!user) return;

  await query('DELETE FROM password_resets WHERE user_id = $1 AND used_at IS NULL', [user.id]);
  const token = randomBytes(32).toString('hex');
  const expires = new Date(Date.now() + RESET_HOURS * 60 * 60 * 1000);
  await query(
    'INSERT INTO password_resets (token, user_id, expires_at) VALUES ($1, $2, $3)',
    [token, user.id, expires.toISOString()],
  );

  const { env } = await import('./config.js');
  const { sendMail } = await import('./mailer.js');
  const link = `${env.appUrl}/yonetim/?reset=${token}`;
  try {
    await sendMail({
      to: user.email,
      subject: 'Şifre sıfırlama',
      text: [
        `Merhaba ${user.name},`,
        ``,
        `Yönetim hesabınız için şifre sıfırlama isteği aldık.`,
        `Bağlantı ${RESET_HOURS} saat geçerlidir:`,
        link,
        ``,
        `Bu isteği siz yapmadıysanız bu e-postayı yok sayın.`,
        ``,
        `Müsait Villam`,
      ].join('\n'),
    });
  } catch (error) {
    console.error('forgot-password mail failed', error.message);
  }
}

export async function resetPasswordWithToken(token, password) {
  const value = String(token || '').trim();
  const nextPassword = String(password || '');
  if (!value) {
    const error = new Error('Sıfırlama bağlantısı geçersiz.');
    error.status = 400;
    throw error;
  }
  if (nextPassword.length < 6) {
    const error = new Error('Şifre en az 6 karakter olmalı.');
    error.status = 400;
    throw error;
  }

  const { rows } = await query(
    `SELECT token, user_id, expires_at, used_at
     FROM password_resets WHERE token = $1`,
    [value],
  );
  const row = rows[0];
  if (!row || row.used_at || new Date(row.expires_at) < new Date()) {
    const error = new Error('Sıfırlama bağlantısı geçersiz veya süresi dolmuş.');
    error.status = 400;
    throw error;
  }

  await query('UPDATE users SET password_hash = $1 WHERE id = $2', [
    hashPassword(nextPassword),
    row.user_id,
  ]);
  await query('UPDATE password_resets SET used_at = NOW() WHERE token = $1', [value]);
  await query('DELETE FROM sessions WHERE user_id = $1', [row.user_id]);
}

export function requireTenant(req, res, next) {
  if (req.user?.role === 'super_admin') {
    return res.status(403).json({ error: 'Bu alan işletme uygulamasına aittir.' });
  }
  if (!req.user?.tenantId) {
    return res.status(403).json({ error: 'İşletme bulunamadı.' });
  }
  if (req.user.tenant?.status === 'suspended') {
    return res.status(403).json({ error: 'İşletme hesabı durdurulmuş.' });
  }
  req.tenantId = req.user.tenantId;
  req.vertical = req.user.vertical;
  next();
}
