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
  };
}

export async function listCustomers(tenantId) {
  const { rows } = await query(
    `SELECT c.* FROM customers c WHERE c.tenant_id = $1 ORDER BY c.created_at DESC`,
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
