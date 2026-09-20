import { statuses } from './verticals.js';
import { query } from './db.js';

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const TIME_RE = /^\d{2}:\d{2}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

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

export function mapReservation(row, vertical) {
  const typeMeta = vertical.types[row.type] ?? Object.values(vertical.types)[0];
  const statusMeta = statuses[row.status] ?? statuses.onaylandi;
  const color = row.resource_color || typeMeta.color;
  return {
    id: row.id,
    tenantId: row.tenant_id,
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
    color,
    status: row.status,
    statusLabel: statusMeta.label,
    statusColor: statusMeta.color,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function parseOptionalString(value, max) {
  if (value == null || value === '') return null;
  const text = String(value).trim();
  if (!text) return null;
  if (text.length > max) throw new Error(`Alan ${max} karakteri aşamaz.`);
  return text;
}

export function validatePayload(body, vertical) {
  const data = {};
  const guestName = String(body.guestName ?? '').trim();
  if (!guestName) throw new Error(`${vertical.customerLabel} adı zorunludur.`);
  data.guest_name = guestName;
  data.phone = parseOptionalString(body.phone, 50);
  const email = parseOptionalString(body.email, 200);
  if (email && !EMAIL_RE.test(email)) throw new Error('E-posta adresi geçersiz.');
  data.email = email;

  const startDate = String(body.startDate ?? '').trim();
  if (!DATE_RE.test(startDate)) throw new Error('Tarih YYYY-MM-DD olmalı.');
  data.start_date = startDate;

  if (vertical.dateMode === 'single') {
    data.end_date = startDate;
  } else {
    const endDate = String(body.endDate ?? startDate).trim();
    if (!DATE_RE.test(endDate)) throw new Error('Bitiş tarihi YYYY-MM-DD olmalı.');
    if (endDate < startDate) throw new Error('Bitiş tarihi başlangıçtan önce olamaz.');
    data.end_date = endDate;
  }

  if (vertical.timeEnabled) {
    const startTime = String(body.startTime ?? '10:00').trim();
    if (!TIME_RE.test(startTime)) throw new Error('Saat HH:MM olmalı.');
    data.start_time = startTime;
    const duration = Number(body.durationMin ?? 60);
    if (!Number.isInteger(duration) || duration < 15 || duration > 480) {
      throw new Error('Süre 15-480 dakika olmalı.');
    }
    data.duration_min = duration;
  } else {
    data.start_time = null;
    data.duration_min = null;
  }

  const defaultType = Object.keys(vertical.types)[0];
  const type = vertical.types[body.type] ? String(body.type) : defaultType;
  data.type = type;

  const status = String(body.status ?? 'onaylandi');
  if (!statuses[status]) throw new Error('Geçersiz durum.');
  data.status = status;
  data.notes = parseOptionalString(body.notes, 2000);
  data.resource_id = body.resourceId ? Number(body.resourceId) : null;
  if (data.resource_id != null && (!Number.isInteger(data.resource_id) || data.resource_id <= 0)) {
    throw new Error('Geçersiz kaynak.');
  }
  return data;
}

function minutesOf(time) {
  const [h, m] = String(time).slice(0, 5).split(':').map(Number);
  return h * 60 + m;
}

function timesOverlap(aStart, aDur, bStart, bDur) {
  if (!aStart || !bStart) return true;
  const a0 = minutesOf(aStart);
  const a1 = a0 + (aDur || 60);
  const b0 = minutesOf(bStart);
  const b1 = b0 + (bDur || 60);
  return a0 < b1 && b0 < a1;
}

export async function hasConflict(tenantId, slot, ignoreReservationId) {
  const clauses = [
    'r.tenant_id = $1',
    "r.status <> 'iptal'",
    'r.end_date >= $2',
    'r.start_date <= $3',
  ];
  const params = [tenantId, slot.startDate, slot.endDate];
  if (slot.resourceId) {
    params.push(slot.resourceId);
    clauses.push(`r.resource_id = $${params.length}`);
  }
  if (ignoreReservationId) {
    params.push(ignoreReservationId);
    clauses.push(`r.id <> $${params.length}`);
  }
  const { rows } = await query(
    `SELECT r.start_date, r.end_date, r.start_time, r.duration_min FROM reservations r WHERE ${clauses.join(' AND ')}`,
    params,
  );
  return rows.some((row) => {
    const start = toIsoDate(row.start_date);
    const end = toIsoDate(row.end_date);
    if (end < slot.startDate || start > slot.endDate) return false;
    if (slot.startTime) {
      return timesOverlap(slot.startTime, slot.durationMin, toTime(row.start_time), row.duration_min);
    }
    return true;
  });
}

export function slotHours(vertical) {
  const start = minutesOf(vertical.workStart || '09:00');
  const end = minutesOf(vertical.workEnd || '19:00');
  const step = vertical.slotMinutes || 30;
  const slots = [];
  for (let t = start; t + step <= end; t += step) {
    const h = String(Math.floor(t / 60)).padStart(2, '0');
    const m = String(t % 60).padStart(2, '0');
    slots.push(`${h}:${m}`);
  }
  return slots;
}

function eachDate(startDate, endDate, callback) {
  const current = new Date(`${startDate}T00:00:00Z`);
  const end = new Date(`${endDate}T00:00:00Z`);
  while (current <= end) {
    callback(current.toISOString().slice(0, 10));
    current.setUTCDate(current.getUTCDate() + 1);
  }
}

const SELECT = `SELECT r.*, res.name AS resource_name, res.color AS resource_color
  FROM reservations r
  LEFT JOIN resources res ON res.id = r.resource_id`;

export async function listReservations(tenantId, vertical, { from, to, status, type } = {}) {
  const clauses = ['r.tenant_id = $1'];
  const params = [tenantId];
  if (from) {
    const start = String(from).slice(0, 10);
    if (!DATE_RE.test(start)) {
      throw Object.assign(new Error('Başlangıç tarihi YYYY-MM-DD olmalı.'), { status: 400 });
    }
    params.push(start);
    clauses.push(`r.end_date >= $${params.length}`);
  }
  if (to) {
    const end = String(to).slice(0, 10);
    if (!DATE_RE.test(end)) {
      throw Object.assign(new Error('Bitiş tarihi YYYY-MM-DD olmalı.'), { status: 400 });
    }
    params.push(end);
    clauses.push(`r.start_date <= $${params.length}`);
  }
  if (status) {
    params.push(status);
    clauses.push(`r.status = $${params.length}`);
  }
  if (type) {
    params.push(type);
    clauses.push(`r.type = $${params.length}`);
  }
  const { rows } = await query(
    `${SELECT} WHERE ${clauses.join(' AND ')} ORDER BY r.start_date ASC, r.start_time ASC NULLS LAST, r.id ASC`,
    params,
  );
  return rows.map((row) => mapReservation(row, vertical));
}

export async function getReservation(tenantId, vertical, id) {
  const { rows } = await query(`${SELECT} WHERE r.id = $1 AND r.tenant_id = $2`, [id, tenantId]);
  return rows[0] ? mapReservation(rows[0], vertical) : null;
}

export async function createReservation(tenantId, vertical, payload) {
  const data = validatePayload(payload, vertical);
  const conflict = await hasConflict(tenantId, {
    resourceId: data.resource_id,
    startDate: data.start_date,
    endDate: data.end_date,
    startTime: data.start_time,
    durationMin: data.duration_min,
  });
  if (conflict) {
    throw Object.assign(new Error('Bu tarih/saat dolu. Başka bir zaman seçin.'), { status: 409 });
  }
  const { rows } = await query(
    `INSERT INTO reservations
      (tenant_id, resource_id, guest_name, phone, email, start_date, end_date, start_time, duration_min, type, status, notes)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     RETURNING *`,
    [
      tenantId,
      data.resource_id,
      data.guest_name,
      data.phone,
      data.email,
      data.start_date,
      data.end_date,
      data.start_time,
      data.duration_min,
      data.type,
      data.status,
      data.notes,
    ],
  );
  return getReservation(tenantId, vertical, rows[0].id);
}

export async function updateReservation(tenantId, vertical, id, payload) {
  const existing = await getReservation(tenantId, vertical, id);
  if (!existing) return null;
  const data = validatePayload(
    {
      guestName: payload.guestName ?? existing.guestName,
      phone: payload.phone === undefined ? existing.phone : payload.phone,
      email: payload.email === undefined ? existing.email : payload.email,
      startDate: payload.startDate ?? existing.startDate,
      endDate: payload.endDate ?? existing.endDate,
      startTime: payload.startTime ?? existing.startTime,
      durationMin: payload.durationMin ?? existing.durationMin,
      type: payload.type ?? existing.type,
      status: payload.status ?? existing.status,
      notes: payload.notes === undefined ? existing.notes : payload.notes,
      resourceId: payload.resourceId === undefined ? existing.resourceId : payload.resourceId,
    },
    vertical,
  );
  if (data.status !== 'iptal') {
    const conflict = await hasConflict(
      tenantId,
      {
        resourceId: data.resource_id,
        startDate: data.start_date,
        endDate: data.end_date,
        startTime: data.start_time,
        durationMin: data.duration_min,
      },
      id,
    );
    if (conflict) {
      throw Object.assign(new Error('Bu tarih/saat dolu. Başka bir zaman seçin.'), { status: 409 });
    }
  }
  await query(
    `UPDATE reservations
     SET resource_id = $1, guest_name = $2, phone = $3, email = $4, start_date = $5,
         end_date = $6, start_time = $7, duration_min = $8, type = $9, status = $10, notes = $11
     WHERE id = $12 AND tenant_id = $13`,
    [
      data.resource_id,
      data.guest_name,
      data.phone,
      data.email,
      data.start_date,
      data.end_date,
      data.start_time,
      data.duration_min,
      data.type,
      data.status,
      data.notes,
      id,
      tenantId,
    ],
  );
  return getReservation(tenantId, vertical, id);
}

export async function cancelReservation(tenantId, vertical, id) {
  const existing = await getReservation(tenantId, vertical, id);
  if (!existing) return null;
  if (existing.status === 'iptal') return existing;
  await query(
    `UPDATE reservations SET status = 'iptal' WHERE id = $1 AND tenant_id = $2`,
    [id, tenantId],
  );
  await query(
    `UPDATE booking_requests
     SET status = 'cancelled', updated_at = NOW()
     WHERE reservation_id = $1 AND status = 'approved'`,
    [id],
  );
  return getReservation(tenantId, vertical, id);
}

export async function deleteReservation(tenantId, id) {
  const { rowCount } = await query(
    'DELETE FROM reservations WHERE id = $1 AND tenant_id = $2',
    [id, tenantId],
  );
  return rowCount > 0;
}

export async function calendarMarks(tenantId, vertical, { year, month }) {
  const start = `${year}-${String(month).padStart(2, '0')}-01`;
  const endDate = new Date(Date.UTC(Number(year), Number(month), 0));
  const end = endDate.toISOString().slice(0, 10);
  const reservations = await listReservations(tenantId, vertical, { from: start, to: end });
  const days = {};
  for (const reservation of reservations) {
    if (reservation.status === 'iptal') continue;
    eachDate(reservation.startDate, reservation.endDate, (date) => {
      if (date < start || date > end) return;
      if (!days[date]) days[date] = [];
      days[date].push({
        id: reservation.id,
        type: reservation.type,
        color: reservation.color,
        guestName: reservation.guestName,
        status: reservation.status,
        startTime: reservation.startTime,
      });
    });
  }
  return { start, end, days };
}
