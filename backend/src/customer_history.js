import { query } from './db.js';
import { mapCustomer } from './customers.js';
import { mapRequest } from './requests.js';

function istanbulToday() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

function toIsoDate(value) {
  if (!value) return null;
  if (typeof value === 'string') return value.slice(0, 10);
  if (value instanceof Date) {
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, '0');
    const d = String(value.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  return String(value).slice(0, 10);
}

function parseAmount(value) {
  if (value == null || value === '') return 0;
  const amount = Number(String(value).replace(/\s/g, '').replace(',', '.'));
  if (!Number.isFinite(amount) || amount < 0) {
    const error = new Error('Tutar geçersiz.');
    error.status = 400;
    throw error;
  }
  return Math.round(amount * 100) / 100;
}

function parseDate(value) {
  const date = toIsoDate(value) || istanbulToday();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    const error = new Error('Tarih geçersiz.');
    error.status = 400;
    throw error;
  }
  return date;
}

async function getOwnedCustomer(tenantId, customerId) {
  const { rows } = await query(
    'SELECT * FROM customers WHERE id = $1 AND tenant_id = $2',
    [customerId, tenantId],
  );
  if (!rows[0]) {
    const error = new Error('Müşteri bulunamadı.');
    error.status = 404;
    throw error;
  }
  return rows[0];
}

function mapEntry(row) {
  return {
    id: row.id,
    kind: 'service',
    title: row.title,
    amount: Number(row.amount || 0),
    notes: row.notes,
    occurredOn: toIsoDate(row.occurred_on),
    createdAt: row.created_at,
    canEdit: true,
  };
}

export async function getCustomerHistory(tenantId, customerId) {
  const customer = await getOwnedCustomer(tenantId, customerId);
  const entries = await query(
    `SELECT * FROM customer_entries
     WHERE tenant_id = $1 AND customer_id = $2
     ORDER BY occurred_on DESC, id DESC`,
    [tenantId, customerId],
  );
  const requests = await query(
    `SELECT br.*, t.name AS tenant_name, t.type AS tenant_type,
            c.name AS customer_name, res.name AS resource_name, res.color AS resource_color
     FROM booking_requests br
     JOIN tenants t ON t.id = br.tenant_id
     JOIN customers c ON c.id = br.customer_id
     LEFT JOIN resources res ON res.id = br.resource_id
     WHERE br.tenant_id = $1 AND br.customer_id = $2
     ORDER BY br.start_date DESC, br.id DESC`,
    [tenantId, customerId],
  );

  const services = entries.rows.map(mapEntry);
  const requestItems = requests.rows.map((row) => {
    const item = mapRequest(row);
    return {
      id: item.id,
      kind: 'request',
      title: item.typeLabel || 'Randevu',
      amount: null,
      notes: [item.resourceName, item.startTime, item.notes].filter(Boolean).join(' · ') || null,
      occurredOn: item.startDate,
      createdAt: item.createdAt,
      status: item.status,
      statusLabel: item.statusLabel,
      statusColor: item.statusColor,
      canEdit: false,
    };
  });

  const timeline = [...services, ...requestItems].sort((a, b) => {
    if (a.occurredOn !== b.occurredOn) return a.occurredOn < b.occurredOn ? 1 : -1;
    return (b.id || 0) - (a.id || 0);
  });

  const totalSpent = services.reduce((sum, item) => sum + item.amount, 0);
  const dates = services.map((item) => item.occurredOn).filter(Boolean);

  return {
    customer: mapCustomer(customer),
    stats: {
      visitCount: services.length,
      requestCount: requestItems.length,
      totalSpent: Math.round(totalSpent * 100) / 100,
      firstVisit: dates.at(-1) || null,
      lastVisit: dates[0] || null,
    },
    timeline,
  };
}

export async function createCustomerEntry(tenantId, customerId, body) {
  await getOwnedCustomer(tenantId, customerId);
  const title = String(body?.title ?? '').trim();
  if (!title) {
    const error = new Error('İşlem adı zorunlu.');
    error.status = 400;
    throw error;
  }
  const amount = parseAmount(body?.amount);
  const occurredOn = parseDate(body?.occurredOn);
  const notes = String(body?.notes ?? '').trim() || null;
  const { rows } = await query(
    `INSERT INTO customer_entries (tenant_id, customer_id, occurred_on, title, amount, notes)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [tenantId, customerId, occurredOn, title, amount, notes],
  );
  return mapEntry(rows[0]);
}

export async function updateCustomerEntry(tenantId, customerId, entryId, body) {
  await getOwnedCustomer(tenantId, customerId);
  const current = await query(
    'SELECT * FROM customer_entries WHERE id = $1 AND tenant_id = $2 AND customer_id = $3',
    [entryId, tenantId, customerId],
  );
  if (!current.rows[0]) {
    const error = new Error('Kayıt bulunamadı.');
    error.status = 404;
    throw error;
  }
  const title = String(body?.title ?? current.rows[0].title).trim();
  if (!title) {
    const error = new Error('İşlem adı zorunlu.');
    error.status = 400;
    throw error;
  }
  const amount = body?.amount === undefined ? Number(current.rows[0].amount) : parseAmount(body.amount);
  const occurredOn = body?.occurredOn === undefined ? toIsoDate(current.rows[0].occurred_on) : parseDate(body.occurredOn);
  const notes = body?.notes === undefined ? current.rows[0].notes : String(body.notes ?? '').trim() || null;
  const { rows } = await query(
    `UPDATE customer_entries
     SET title = $4, amount = $5, occurred_on = $6, notes = $7
     WHERE id = $1 AND tenant_id = $2 AND customer_id = $3
     RETURNING *`,
    [entryId, tenantId, customerId, title, amount, occurredOn, notes],
  );
  return mapEntry(rows[0]);
}

export async function deleteCustomerEntry(tenantId, customerId, entryId) {
  const { rowCount } = await query(
    'DELETE FROM customer_entries WHERE id = $1 AND tenant_id = $2 AND customer_id = $3',
    [entryId, tenantId, customerId],
  );
  return rowCount > 0;
}
