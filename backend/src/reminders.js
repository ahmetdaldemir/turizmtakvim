import { query } from './db.js';
import { sendMail } from './mailer.js';

const INTERVAL_MS = 30 * 60 * 1000;

function istanbulToday() {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
}

function addDays(isoDate, days) {
  const [year, month, day] = isoDate.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day + days));
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  const d = String(date.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

function daysUntil(fromIso, toIso) {
  const [fy, fm, fd] = fromIso.split('-').map(Number);
  const [ty, tm, td] = toIso.split('-').map(Number);
  const from = Date.UTC(fy, fm - 1, fd);
  const to = Date.UTC(ty, tm - 1, td);
  return Math.round((to - from) / 86400000);
}

function formatTrDate(isoDate) {
  return new Intl.DateTimeFormat('tr-TR', {
    timeZone: 'Europe/Istanbul',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(new Date(`${isoDate}T12:00:00+03:00`));
}

function formatTime(value) {
  if (!value) return '';
  return String(value).slice(0, 5);
}

function uniqueEmails(...values) {
  const seen = new Set();
  for (const value of values) {
    const email = String(value || '').trim().toLowerCase();
    if (email.includes('@')) seen.add(email);
  }
  return [...seen];
}

function reminderCopy(row, daysLeft) {
  const kind = row.tenant_type === 'kuafor' ? 'randevu' : 'konaklama';
  const when = formatTrDate(String(row.start_date).slice(0, 10));
  const time = formatTime(row.start_time);
  const resource = row.resource_name || (row.tenant_type === 'kuafor' ? 'şube' : 'villa');
  const remaining =
    daysLeft === 0 ? 'Bugün' : daysLeft === 1 ? '1 gün kaldı' : `${daysLeft} gün kaldı`;
  const timeLine = time ? `\nSaat: ${time}` : '';

  const text = [
    `Merhaba,`,
    ``,
    `${row.guest_name} için ${resource} ${kind} hatırlatması.`,
    `Tarih: ${when}${timeLine}`,
    `Kalan süre: ${remaining}`,
    `İşletme: ${row.tenant_name}`,
    row.phone ? `Telefon: ${row.phone}` : null,
    ``,
    `Müsait Villam`,
  ]
    .filter((line) => line !== null)
    .join('\n');

  return {
    subject: `Rezervasyon hatırlatması — ${remaining}`,
    text,
  };
}

export async function sendDueReminders() {
  const today = istanbulToday();
  const until = addDays(today, 7);
  const { rows } = await query(
    `SELECT r.id, r.guest_name, r.phone, r.email, r.start_date, r.start_time, r.type,
            t.name AS tenant_name, t.type AS tenant_type,
            res.name AS resource_name,
            owner.email AS owner_email
     FROM reservations r
     JOIN tenants t ON t.id = r.tenant_id
     LEFT JOIN resources res ON res.id = r.resource_id
     LEFT JOIN LATERAL (
       SELECT email FROM users
       WHERE tenant_id = t.id AND role = 'owner'
       ORDER BY id
       LIMIT 1
     ) owner ON TRUE
     WHERE r.status = 'onaylandi'
       AND r.start_date BETWEEN $1::date AND $2::date
     ORDER BY r.start_date, r.id`,
    [today, until],
  );

  let sent = 0;
  for (const row of rows) {
    const claimed = await query(
      `INSERT INTO reservation_reminders (reservation_id, send_date)
       VALUES ($1, $2::date)
       ON CONFLICT (reservation_id, send_date) DO NOTHING`,
      [row.id, today],
    );
    if (claimed.rowCount === 0) continue;

    const recipients = uniqueEmails(row.email, row.owner_email);
    if (recipients.length === 0) continue;

    const startDate = String(row.start_date).slice(0, 10);
    const { subject, text } = reminderCopy(row, daysUntil(today, startDate));
    try {
      await sendMail({ to: recipients, subject, text });
      sent += 1;
    } catch (error) {
      await query(
        'DELETE FROM reservation_reminders WHERE reservation_id = $1 AND send_date = $2::date',
        [row.id, today],
      );
      console.error('reminder mail failed', row.id, error.message);
    }
  }
  if (sent > 0) console.log(`reservation reminders sent: ${sent}`);
  return sent;
}

export function startReminderJob() {
  const run = () => {
    sendDueReminders().catch((error) => {
      console.error('reminder job failed', error.message);
    });
  };
  run();
  return setInterval(run, INTERVAL_MS);
}
