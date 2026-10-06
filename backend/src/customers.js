import { query } from './db.js';
import { hashPassword, mapTenant } from './auth.js';
import { getVertical } from './verticals.js';
import { listResources } from './resources.js';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function mapCustomer(row, tenant = null) {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    sector: row.sector,
    sectorLabel: row.sector === 'kuafor' ? 'Kuaför' : 'Villa',
    name: row.name,
    email: row.email,
    phone: row.phone,
    role: 'customer',
    tenant: tenant || (row.t_id
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
      : null),
    visitCount: Number(row.visit_count ?? 0),
    totalSpent: Number(row.total_spent ?? 0),
  };
}

export async function listCustomers(tenantId) {
  const { rows } = await query(
    `SELECT c.*,
            (SELECT COUNT(*)::int FROM customer_entries e WHERE e.customer_id = c.id) AS visit_count,
            (SELECT COALESCE(SUM(e.amount), 0) FROM customer_entries e WHERE e.customer_id = c.id) AS total_spent
     FROM customers c WHERE c.tenant_id = $1 ORDER BY c.created_at DESC`,
    [tenantId],
  );
  return rows.map((row) => mapCustomer(row));
}

export async function createCustomerForTenant(tenant, body) {
  const name = String(body.name ?? '').trim();
  const email = String(body.email ?? '').trim().toLowerCase();
  const phone = String(body.phone ?? '').trim() || null;
  const password = String(body.password ?? '');
  if (!name) throw Object.assign(new Error('Ad zorunlu.'), { status: 400 });
  if (!EMAIL_RE.test(email)) throw Object.assign(new Error('E-posta geçersiz.'), { status: 400 });
  if (password.length < 6) throw Object.assign(new Error('Şifre en az 6 karakter olmalı.'), { status: 400 });

  const existing = await query('SELECT sector FROM customers WHERE lower(email) = $1', [email]);
  if (existing.rowCount) {
    const other = existing.rows[0].sector;
    const message = other === tenant.type
      ? 'Bu e-posta zaten bu işletmede kayıtlı.'
      : 'Bu e-posta diğer sektör uygulamasında kayıtlı. Aynı müşteri villa ve kuaförde olamaz.';
    throw Object.assign(new Error(message), { status: 409 });
  }

  const { rows } = await query(
    `INSERT INTO customers (tenant_id, sector, name, email, phone, password_hash)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [tenant.id, tenant.type, name, email, phone, hashPassword(password)],
  );
  return mapCustomer(rows[0], tenant);
}

export async function updateCustomerForTenant(tenant, id, body) {
  const current = await query('SELECT * FROM customers WHERE id = $1 AND tenant_id = $2', [id, tenant.id]);
  if (!current.rows[0]) throw Object.assign(new Error('Müşteri bulunamadı.'), { status: 404 });

  const name = String(body.name ?? current.rows[0].name).trim();
  const email = String(body.email ?? current.rows[0].email).trim().toLowerCase();
  const phone = body.phone === undefined ? current.rows[0].phone : String(body.phone ?? '').trim() || null;
  const password = String(body.password ?? '');
  if (!name) throw Object.assign(new Error('Ad zorunlu.'), { status: 400 });
  if (!EMAIL_RE.test(email)) throw Object.assign(new Error('E-posta geçersiz.'), { status: 400 });
  if (password && password.length < 6) throw Object.assign(new Error('Şifre en az 6 karakter olmalı.'), { status: 400 });

  if (email !== current.rows[0].email) {
    const existing = await query('SELECT id, sector FROM customers WHERE lower(email) = $1 AND id <> $2', [email, id]);
    if (existing.rowCount) {
      const other = existing.rows[0].sector;
      const message = other === tenant.type
        ? 'Bu e-posta zaten bu işletmede kayıtlı.'
        : 'Bu e-posta diğer sektör uygulamasında kayıtlı. Aynı müşteri villa ve kuaförde olamaz.';
      throw Object.assign(new Error(message), { status: 409 });
    }
  }

  const { rows } = await query(
    password
      ? `UPDATE customers SET name = $3, email = $4, phone = $5, password_hash = $6
         WHERE id = $1 AND tenant_id = $2 RETURNING *`
      : `UPDATE customers SET name = $3, email = $4, phone = $5
         WHERE id = $1 AND tenant_id = $2 RETURNING *`,
    password
      ? [id, tenant.id, name, email, phone, hashPassword(password)]
      : [id, tenant.id, name, email, phone],
  );
  return mapCustomer(rows[0], tenant);
}

export async function deleteCustomer(tenantId, id) {
  const { rowCount } = await query(
    'DELETE FROM customers WHERE id = $1 AND tenant_id = $2',
    [id, tenantId],
  );
  return rowCount > 0;
}

export async function getCustomerBusiness(customer) {
  if (!customer.tenantId) return null;
  const { rows } = await query(
    `SELECT * FROM tenants WHERE id = $1 AND status IN ('active', 'trial')`,
    [customer.tenantId],
  );
  if (!rows[0]) return null;
  const tenant = mapTenant(rows[0]);
  if (tenant.type !== customer.sector) return null;
  const resources = await listResources(tenant.id);
  return {
    tenant,
    vertical: getVertical(tenant.type),
    resources: resources.filter((item) => item.active),
  };
}
