import { query } from './db.js';

export async function notifyTenant(tenantId, { title, body, type = 'request', payload = null }) {
  const { rows } = await query(
    `INSERT INTO notifications (tenant_id, title, body, type, payload)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [tenantId, title, body, type, payload],
  );
  return mapNotification(rows[0]);
}

export function mapNotification(row) {
  return {
    id: row.id,
    tenantId: row.tenant_id,
    title: row.title,
    body: row.body,
    type: row.type,
    read: Boolean(row.read_at),
    payload: row.payload,
    createdAt: row.created_at,
  };
}

export async function listNotifications(tenantId) {
  const { rows } = await query(
    `SELECT * FROM notifications WHERE tenant_id = $1 ORDER BY created_at DESC LIMIT 100`,
    [tenantId],
  );
  return rows.map(mapNotification);
}

export async function unreadCount(tenantId) {
  const { rows } = await query(
    `SELECT COUNT(*)::int AS count FROM notifications WHERE tenant_id = $1 AND read_at IS NULL`,
    [tenantId],
  );
  return rows[0].count;
}

export async function markRead(tenantId, id) {
  const { rows } = await query(
    `UPDATE notifications SET read_at = NOW()
     WHERE id = $1 AND tenant_id = $2 RETURNING *`,
    [id, tenantId],
  );
  return rows[0] ? mapNotification(rows[0]) : null;
}

export async function markAllRead(tenantId) {
  await query(
    `UPDATE notifications SET read_at = NOW() WHERE tenant_id = $1 AND read_at IS NULL`,
    [tenantId],
  );
}
