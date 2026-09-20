import { query } from './db.js';
import { hashPassword, mapTenant } from './auth.js';
import { getVertical } from './verticals.js';

function slugify(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 60) || `isletme-${Date.now()}`;
}

export async function listTenants() {
  const { rows } = await query(
    `SELECT t.*,
            (SELECT COUNT(*)::int FROM users u WHERE u.tenant_id = t.id) AS user_count,
            (SELECT COUNT(*)::int FROM reservations r WHERE r.tenant_id = t.id) AS reservation_count,
            (SELECT COUNT(*)::int FROM resources res WHERE res.tenant_id = t.id) AS resource_count,
            (SELECT COUNT(*)::int FROM customers c WHERE c.tenant_id = t.id) AS customer_count,
            (SELECT u.name FROM users u WHERE u.tenant_id = t.id AND u.role = 'owner' ORDER BY u.id LIMIT 1) AS owner_name,
            (SELECT u.email FROM users u WHERE u.tenant_id = t.id AND u.role = 'owner' ORDER BY u.id LIMIT 1) AS owner_email
     FROM tenants t
     ORDER BY t.created_at DESC`,
  );
  return rows.map((row) => ({
    ...mapTenant(row),
    userCount: row.user_count,
    reservationCount: row.reservation_count,
    resourceCount: row.resource_count,
    customerCount: row.customer_count,
    ownerName: row.owner_name,
    ownerEmail: row.owner_email,
  }));
}

export async function panelStats() {
  const { rows } = await query(
    `SELECT
       (SELECT COUNT(*)::int FROM tenants) AS tenants,
       (SELECT COUNT(*)::int FROM tenants WHERE type = 'villa') AS villas,
       (SELECT COUNT(*)::int FROM tenants WHERE type = 'kuafor') AS kuaforler,
       (SELECT COUNT(*)::int FROM users WHERE role <> 'super_admin') AS users,
       (SELECT COUNT(*)::int FROM reservations) AS reservations`,
  );
  return rows[0];
}

export async function createTenant(body) {
  const name = String(body.name ?? '').trim();
  const type = String(body.type ?? '').trim();
  const ownerName = String(body.ownerName ?? '').trim();
  const ownerEmail = String(body.ownerEmail ?? '').trim().toLowerCase();
  const ownerPassword = String(body.ownerPassword ?? '');
  if (!name) throw Object.assign(new Error('İşletme adı zorunlu.'), { status: 400 });
  getVertical(type);
  if (!ownerName || !ownerEmail || ownerPassword.length < 6) {
    throw Object.assign(new Error('İşletme sahibi adı, e-posta ve en az 6 karakter şifre gerekli.'), { status: 400 });
  }
  const taken = await query('SELECT 1 FROM users WHERE lower(email) = $1', [ownerEmail]);
  if (taken.rowCount) {
    throw Object.assign(new Error('Bu e-posta ile bir SaaS kullanıcısı zaten var.'), { status: 409 });
  }

  let slug = slugify(body.slug || name);
  const existing = await query('SELECT 1 FROM tenants WHERE slug = $1', [slug]);
  if (existing.rowCount) slug = `${slug}-${Date.now().toString().slice(-4)}`;

  const tenantResult = await query(
    `INSERT INTO tenants (name, slug, type, status, plan, phone, email)
     VALUES ($1, $2, $3, 'trial', 'trial', $4, $5)
     RETURNING *`,
    [name, slug, type, body.phone || null, body.email || ownerEmail],
  );
  const tenant = tenantResult.rows[0];
  await query(
    `INSERT INTO users (tenant_id, name, email, password_hash, role)
     VALUES ($1, $2, $3, $4, 'owner')`,
    [tenant.id, ownerName, ownerEmail, hashPassword(ownerPassword)],
  );
  const color = type === 'kuafor' ? '#BE185D' : '#0D9488';
  const resourceName = type === 'kuafor' ? 'Merkez Şube' : 'Villa 1';
  await query(
    `INSERT INTO resources (tenant_id, name, color) VALUES ($1, $2, $3)`,
    [tenant.id, resourceName, color],
  );
  return mapTenant(tenant);
}

export async function updateTenant(id, body) {
  const { rows } = await query('SELECT * FROM tenants WHERE id = $1', [id]);
  if (!rows[0]) return null;
  const current = rows[0];
  const name = body.name != null ? String(body.name).trim() : current.name;
  const status = body.status ?? current.status;
  const plan = body.plan ?? current.plan;
  const phone = body.phone === undefined ? current.phone : body.phone;
  const email = body.email === undefined ? current.email : body.email;
  if (!['active', 'trial', 'suspended'].includes(status)) {
    throw Object.assign(new Error('Geçersiz durum.'), { status: 400 });
  }
  const updated = await query(
    `UPDATE tenants SET name = $1, status = $2, plan = $3, phone = $4, email = $5
     WHERE id = $6 RETURNING *`,
    [name, status, plan, phone, email, id],
  );
  return mapTenant(updated.rows[0]);
}

export async function getTenant(id) {
  const { rows } = await query(
    `SELECT t.* FROM tenants t WHERE t.id = $1 AND t.status IN ('active', 'trial')`,
    [id],
  );
  return rows[0] ? mapTenant(rows[0]) : null;
}

export async function listPublicBusinesses(type) {
  const params = [];
  let where = `t.status IN ('active', 'trial')`;
  if (type) {
    params.push(type);
    where += ` AND t.type = $${params.length}`;
  }
  const { rows } = await query(
    `SELECT t.* FROM tenants t WHERE ${where} ORDER BY t.name ASC`,
    params,
  );
  return rows.map(mapTenant);
}
