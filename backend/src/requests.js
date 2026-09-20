import { query } from './db.js';
import { getVertical } from './verticals.js';
import { createReservation, hasConflict, listReservations, slotHours, updateReservation, validatePayload } from './reservations.js';
import { notifyTenant } from './notifications.js';
import { listResources } from './resources.js';
import { getTenant } from './tenants.js';

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

function toTime(value) {
  if (!value) return null;
  return String(value).slice(0, 5);
}

const requestStatuses = {
  pending: { label: 'Onay bekliyor', color: '#D97706' },
  approved: { label: 'Onaylandı', color: '#16A34A' },
  rejected: { label: 'Reddedildi', color: '#DC2626' },
  cancelled: { label: 'İptal', color: '#9CA3AF' },
};

function istanbulToday() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

const SELECT = `SELECT br.*, t.name AS tenant_name, t.type AS tenant_type,
       c.name AS customer_name, res.name AS resource_name, res.color AS resource_color
  FROM booking_requests br
  JOIN tenants t ON t.id = br.tenant_id
  JOIN customers c ON c.id = br.customer_id
  LEFT JOIN resources res ON res.id = br.resource_id`;

export function mapRequest(row) {
  const vertical = getVertical(row.tenant_type);
  const typeMeta = vertical.types[row.type] ?? Object.values(vertical.types)[0];
  const statusMeta = requestStatuses[row.status] ?? requestStatuses.pending;
  return {
    id: row.id,
    tenantId: row.tenant_id,
    tenantName: row.tenant_name,
    tenantType: row.tenant_type,
    customerId: row.customer_id,
    customerName: row.customer_name,
    resourceId: row.resource_id,
    resourceName: row.resource_name,
    guestName: row.guest_name,
    phone: row.phone,
    email: row.email,
    startDate: toIsoDate(row.start_date),
    endDate: toIsoDate(row.end_date),
    startTime: toTime(row.start_time),
    durationMin: row.duration_min,
    type: row.type,
    typeLabel: typeMeta.label,
    color: row.resource_color || typeMeta.color || '#D97706',
    status: row.status,
    statusLabel: statusMeta.label,
    statusColor: statusMeta.color,
    notes: row.notes,
    reservationId: row.reservation_id,
    rejectReason: row.reject_reason,
    createdAt: row.created_at,
    canEdit: ['pending', 'approved'].includes(row.status) && toIsoDate(row.start_date) >= istanbulToday(),
    canCancel:
      row.status === 'pending' ||
      (row.status === 'approved' && toIsoDate(row.start_date) >= istanbulToday()),
  };
}

async function getRequestRow(id) {
  const { rows } = await query(`${SELECT} WHERE br.id = $1`, [id]);
  return rows[0] || null;
}

export async function createRequest(customer, body) {
  const tenant = await getTenant(Number(body.tenantId || customer.tenantId));
  if (!tenant) throw Object.assign(new Error('İşletme bulunamadı.'), { status: 404 });
  if (customer.sector !== tenant.type) {
    throw Object.assign(new Error('Bu işletme sizin sektörünüzde değil.'), { status: 403 });
  }
  if (customer.tenantId && customer.tenantId !== tenant.id) {
    throw Object.assign(new Error('Yalnızca sizi ekleyen işletmeden randevu alabilirsiniz.'), { status: 403 });
  }
  const vertical = getVertical(tenant.type);
  const defaultType = Object.keys(vertical.types)[0];
  const typeKey = vertical.types[body.type] ? body.type : defaultType;
  const service = vertical.types[typeKey] || {};
  const data = validatePayload(
    {
      guestName: customer.name,
      phone: body.phone || customer.phone,
      email: customer.email,
      startDate: body.startDate,
      endDate: body.endDate,
      startTime: body.startTime,
      durationMin: body.durationMin ?? service.durationMin ?? 60,
      type: typeKey,
      status: 'beklemede',
      notes: body.notes,
      resourceId: body.resourceId,
    },
    vertical,
  );

  const busy = await hasConflict(tenant.id, {
    resourceId: data.resource_id,
    startDate: data.start_date,
    endDate: data.end_date,
    startTime: data.start_time,
    durationMin: data.duration_min,
  });
  if (busy) {
    throw Object.assign(new Error('Bu zaman dilimi rezerve. Müsait bir tarih seçin.'), { status: 409 });
  }

  const { rows } = await query(
    `INSERT INTO booking_requests
      (tenant_id, customer_id, resource_id, guest_name, phone, email, start_date, end_date,
       start_time, duration_min, type, notes, status)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,'pending')
     RETURNING id`,
    [
      tenant.id,
      customer.id,
      data.resource_id,
      data.guest_name,
      data.phone,
      data.email,
      data.start_date,
      data.end_date,
      data.start_time,
      data.duration_min,
      data.type,
      data.notes,
    ],
  );
  const when = data.start_time
    ? `${data.start_date} ${data.start_time}`
    : `${data.start_date} – ${data.end_date}`;
  await notifyTenant(tenant.id, {
    title: 'Yeni randevu talebi',
    body: `${customer.name} ${when} için talep oluşturdu.`,
    type: 'request',
    payload: { requestId: rows[0].id },
  });
  return mapRequest(await getRequestRow(rows[0].id));
}

export async function listRequestsForCustomer(customerId) {
  const { rows } = await query(
    `${SELECT} WHERE br.customer_id = $1 ORDER BY br.created_at DESC`,
    [customerId],
  );
  return rows.map(mapRequest);
}

export async function listRequestsForTenant(tenantId, status) {
  const params = [tenantId];
  let where = 'br.tenant_id = $1';
  if (status) {
    params.push(status);
    where += ` AND br.status = $${params.length}`;
  }
  const { rows } = await query(
    `${SELECT} WHERE ${where} ORDER BY br.created_at DESC`,
    params,
  );
  return rows.map(mapRequest);
}

export async function approveRequest(tenantId, vertical, id) {
  const row = await getRequestRow(id);
  if (!row || row.tenant_id !== tenantId) return null;
  if (row.status !== 'pending') {
    throw Object.assign(new Error('Bu talep zaten işlenmiş.'), { status: 400 });
  }
  const busy = await hasConflict(tenantId, {
    resourceId: row.resource_id,
    startDate: toIsoDate(row.start_date),
    endDate: toIsoDate(row.end_date),
    startTime: toTime(row.start_time),
    durationMin: row.duration_min,
  });
  if (busy) {
    throw Object.assign(new Error('Takvimde çakışma var. Talebi reddedin veya tarihi değiştirin.'), { status: 409 });
  }
  const reservation = await createReservation(tenantId, vertical, {
    guestName: row.guest_name,
    phone: row.phone,
    email: row.email,
    startDate: toIsoDate(row.start_date),
    endDate: toIsoDate(row.end_date),
    startTime: toTime(row.start_time),
    durationMin: row.duration_min,
    type: row.type,
    status: 'onaylandi',
    notes: row.notes,
    resourceId: row.resource_id,
  });
  await query(
    `UPDATE booking_requests
     SET status = 'approved', reservation_id = $1, updated_at = NOW()
     WHERE id = $2`,
    [reservation.id, id],
  );
  return { request: mapRequest(await getRequestRow(id)), reservation };
}

export async function rejectRequest(tenantId, id, reason) {
  const row = await getRequestRow(id);
  if (!row || row.tenant_id !== tenantId) return null;
  if (row.status !== 'pending') {
    throw Object.assign(new Error('Bu talep zaten işlenmiş.'), { status: 400 });
  }
  await query(
    `UPDATE booking_requests
     SET status = 'rejected', reject_reason = $1, updated_at = NOW()
     WHERE id = $2`,
    [reason || 'Uygun değil', id],
  );
  return mapRequest(await getRequestRow(id));
}

export async function updateCustomerRequest(customer, id, body) {
  const row = await getRequestRow(id);
  if (!row || row.customer_id !== customer.id) {
    throw Object.assign(new Error('Talep bulunamadı.'), { status: 404 });
  }
  if (!['pending', 'approved'].includes(row.status)) {
    throw Object.assign(new Error('Bu kayıt düzenlenemez.'), { status: 400 });
  }
  if (toIsoDate(row.start_date) < istanbulToday()) {
    throw Object.assign(new Error('Geçmiş kayıt düzenlenemez.'), { status: 400 });
  }
  const vertical = getVertical(row.tenant_type);
  const data = validatePayload(
    {
      guestName: row.guest_name,
      phone: body.phone === undefined ? row.phone : body.phone,
      email: row.email,
      startDate: body.startDate ?? toIsoDate(row.start_date),
      endDate: body.endDate ?? toIsoDate(row.end_date),
      startTime: body.startTime === undefined ? toTime(row.start_time) : body.startTime,
      durationMin: body.durationMin ?? row.duration_min,
      type: body.type ?? row.type,
      status: 'beklemede',
      notes: body.notes === undefined ? row.notes : body.notes,
      resourceId: body.resourceId === undefined ? row.resource_id : body.resourceId,
    },
    vertical,
  );
  const busy = await hasConflict(
    row.tenant_id,
    {
      resourceId: data.resource_id,
      startDate: data.start_date,
      endDate: data.end_date,
      startTime: data.start_time,
      durationMin: data.duration_min,
    },
    row.reservation_id,
  );
  if (busy) {
    throw Object.assign(new Error('Bu zaman dilimi rezerve. Müsait bir tarih seçin.'), { status: 409 });
  }
  await query(
    `UPDATE booking_requests
     SET resource_id = $1, start_date = $2, end_date = $3, start_time = $4, duration_min = $5,
         type = $6, notes = $7, phone = $8, updated_at = NOW()
     WHERE id = $9`,
    [
      data.resource_id,
      data.start_date,
      data.end_date,
      data.start_time,
      data.duration_min,
      data.type,
      data.notes,
      data.phone,
      id,
    ],
  );
  if (row.status === 'approved' && row.reservation_id) {
    await updateReservation(row.tenant_id, vertical, row.reservation_id, {
      startDate: data.start_date,
      endDate: data.end_date,
      startTime: data.start_time,
      durationMin: data.duration_min,
      resourceId: data.resource_id,
      notes: data.notes,
      phone: data.phone,
    });
  }
  const when = data.start_time
    ? `${data.start_date} ${data.start_time}`
    : `${data.start_date} – ${data.end_date}`;
  await notifyTenant(row.tenant_id, {
    title: 'Randevu güncellendi',
    body: `${row.guest_name} kaydını ${when} olarak değiştirdi.`,
    type: 'request',
    payload: { requestId: id },
  });
  return mapRequest(await getRequestRow(id));
}

export async function cancelCustomerRequest(customer, id) {
  const row = await getRequestRow(id);
  if (!row || row.customer_id !== customer.id) {
    throw Object.assign(new Error('Talep bulunamadı.'), { status: 404 });
  }
  if (row.status === 'pending') {
    await query(
      `UPDATE booking_requests SET status = 'cancelled', updated_at = NOW() WHERE id = $1`,
      [id],
    );
  } else if (row.status === 'approved') {
    if (toIsoDate(row.start_date) < istanbulToday()) {
      throw Object.assign(new Error('Geçmiş rezervasyon iptal edilemez.'), { status: 400 });
    }
    if (row.reservation_id) {
      await query(
        `UPDATE reservations SET status = 'iptal' WHERE id = $1 AND tenant_id = $2`,
        [row.reservation_id, row.tenant_id],
      );
    }
    await query(
      `UPDATE booking_requests SET status = 'cancelled', updated_at = NOW() WHERE id = $1`,
      [id],
    );
  } else {
    throw Object.assign(new Error('Bu kayıt iptal edilemez.'), { status: 400 });
  }
  await notifyTenant(row.tenant_id, {
    title: 'Randevu iptal edildi',
    body: `${row.guest_name} ${toIsoDate(row.start_date)} kaydını iptal etti.`,
    type: 'request',
    payload: { requestId: id },
  });
  return mapRequest(await getRequestRow(id));
}

export async function publicAvailability(tenantId, { year, month, resourceId }) {
  const tenant = await getTenant(tenantId);
  if (!tenant) return null;
  const vertical = getVertical(tenant.type);
  const resources = await listResources(tenantId);
  const start = `${year}-${String(month).padStart(2, '0')}-01`;
  const endDate = new Date(Date.UTC(Number(year), Number(month), 0));
  const end = endDate.toISOString().slice(0, 10);
  const reservations = (await listReservations(tenantId, vertical, { from: start, to: end }))
    .filter((item) => item.status !== 'iptal')
    .filter((item) => !resourceId || item.resourceId === Number(resourceId));

  const occupiedDates = {};
  const occupiedSlots = [];
  for (const item of reservations) {
    let cursor = new Date(`${item.startDate}T00:00:00Z`);
    const last = new Date(`${item.endDate}T00:00:00Z`);
    while (cursor <= last) {
      const date = cursor.toISOString().slice(0, 10);
      occupiedDates[date] = true;
      if (item.startTime) {
        occupiedSlots.push({
          date,
          startTime: item.startTime,
          durationMin: item.durationMin,
          resourceId: item.resourceId,
        });
      }
      cursor.setUTCDate(cursor.getUTCDate() + 1);
    }
  }

  return {
    tenant,
    vertical,
    resources: resources.filter((item) => item.active),
    occupiedDates: Object.keys(occupiedDates),
    occupiedSlots,
    slots: vertical.timeEnabled ? slotHours(vertical) : [],
  };
}
