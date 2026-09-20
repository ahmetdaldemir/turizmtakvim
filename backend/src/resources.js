import { query } from './db.js';

const COLORS = ['#0D9488', '#0284C7', '#7C3AED', '#BE185D', '#EA580C', '#16A34A'];

export function mapResource(row) {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    name: row.name,
    region: row.region || null,
    description: row.description || null,
    color: row.color,
    active: row.active,
  };
}

export async function listResources(tenantId) {
  const { rows } = await query(
    'SELECT * FROM resources WHERE tenant_id = $1 ORDER BY name ASC',
    [tenantId],
  );
  return rows.map(mapResource);
}

export async function createResource(tenantId, body) {
  const name = String(body.name ?? '').trim();
  const region = String(body.region ?? '').trim();
  const description = String(body.description ?? '').trim() || null;
  if (!name) throw Object.assign(new Error('Ad zorunlu.'), { status: 400 });
  if (!region) throw Object.assign(new Error('Bölge zorunlu.'), { status: 400 });
  const existing = await query('SELECT COUNT(*)::int AS count FROM resources WHERE tenant_id = $1', [tenantId]);
  const color = String(body.color ?? COLORS[existing.rows[0].count % COLORS.length]);
  const { rows } = await query(
    `INSERT INTO resources (tenant_id, name, region, description, color, active)
     VALUES ($1, $2, $3, $4, $5, TRUE) RETURNING *`,
    [tenantId, name, region, description, color],
  );
  return mapResource(rows[0]);
}

export async function updateResource(tenantId, id, body) {
  const { rows } = await query(
    'SELECT * FROM resources WHERE id = $1 AND tenant_id = $2',
    [id, tenantId],
  );
  if (!rows[0]) return null;
  const current = rows[0];
  const name = body.name != null ? String(body.name).trim() : current.name;
  const region = body.region != null ? String(body.region).trim() : current.region;
  const description = body.description === undefined
    ? current.description
    : (String(body.description).trim() || null);
  const color = body.color ?? current.color;
  const active = body.active == null ? current.active : Boolean(body.active);
  if (!name) throw Object.assign(new Error('Ad zorunlu.'), { status: 400 });
  if (!region) throw Object.assign(new Error('Bölge zorunlu.'), { status: 400 });
  const updated = await query(
    `UPDATE resources SET name = $1, region = $2, description = $3, color = $4, active = $5
     WHERE id = $6 AND tenant_id = $7 RETURNING *`,
    [name, region, description, color, active, id, tenantId],
  );
  return mapResource(updated.rows[0]);
}

export async function deleteResource(tenantId, id) {
  const { rowCount } = await query(
    'DELETE FROM resources WHERE id = $1 AND tenant_id = $2',
    [id, tenantId],
  );
  return rowCount > 0;
}
