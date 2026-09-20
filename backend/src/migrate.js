import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool } from './db.js';
import { hashPassword } from './auth.js';

const rootDir = path.dirname(fileURLToPath(import.meta.url));

async function migrate() {
  const schema = await fs.readFile(path.join(rootDir, 'schema.sql'), 'utf8');
  await pool.query(schema);

  const admin = await pool.query("SELECT id FROM users WHERE role = 'super_admin' LIMIT 1");
  if (admin.rowCount === 0) {
    await pool.query(
      `INSERT INTO users (tenant_id, name, email, password_hash, role)
       VALUES (NULL, 'SaaS Admin', 'admin@takvim.app', $1, 'super_admin')`,
      [hashPassword('Admin123!')],
    );
    console.log('SaaS admin oluşturuldu: admin@takvim.app');
  }

  let villaId;
  const villa = await pool.query("SELECT id FROM tenants WHERE slug = 'demo-villa'");
  if (villa.rowCount === 0) {
    const created = await pool.query(
      `INSERT INTO tenants (name, slug, type, status, plan, email)
       VALUES ('Müsait Villam Demo', 'demo-villa', 'villa', 'active', 'pro', 'villa@takvim.app')
       RETURNING id`,
    );
    villaId = created.rows[0].id;
    await pool.query(
      `INSERT INTO users (tenant_id, name, email, password_hash, role)
       VALUES ($1, 'Villa Sahibi', 'villa@takvim.app', $2, 'owner')`,
      [villaId, hashPassword('Demo123!')],
    );
    await pool.query(
      `INSERT INTO resources (tenant_id, name, color) VALUES
       ($1, 'Villa Limon', '#0D9488'),
       ($1, 'Villa Deniz', '#0284C7')`,
      [villaId],
    );
    console.log('Demo villa işletmesi: villa@takvim.app');
  } else {
    villaId = villa.rows[0].id;
  }

  let kuaforId;
  const kuafor = await pool.query("SELECT id FROM tenants WHERE slug = 'demo-kuafor'");
  if (kuafor.rowCount === 0) {
    const created = await pool.query(
      `INSERT INTO tenants (name, slug, type, status, plan, email)
       VALUES ('Elif Kuaför Demo', 'demo-kuafor', 'kuafor', 'active', 'pro', 'kuafor@takvim.app')
       RETURNING id`,
    );
    kuaforId = created.rows[0].id;
    await pool.query(
      `INSERT INTO users (tenant_id, name, email, password_hash, role)
       VALUES ($1, 'Kuaför Sahibi', 'kuafor@takvim.app', $2, 'owner')`,
      [kuaforId, hashPassword('Demo123!')],
    );
    await pool.query(
      `INSERT INTO resources (tenant_id, name, color) VALUES
       ($1, 'Elif', '#BE185D'),
       ($1, 'Can', '#7C3AED')`,
      [kuaforId],
    );
    console.log('Demo kuaför işletmesi: kuafor@takvim.app');
  } else {
    kuaforId = kuafor.rows[0].id;
  }

  await pool.query('UPDATE reservations SET tenant_id = $1 WHERE tenant_id IS NULL', [villaId]);

  const villaCount = await pool.query(
    'SELECT COUNT(*)::int AS count FROM reservations WHERE tenant_id = $1',
    [villaId],
  );
  if (villaCount.rows[0].count === 0) {
    const resources = await pool.query(
      'SELECT id, name FROM resources WHERE tenant_id = $1 ORDER BY id',
      [villaId],
    );
    const limon = resources.rows[0]?.id;
    const deniz = resources.rows[1]?.id;
    await pool.query(
      `INSERT INTO reservations
        (tenant_id, resource_id, guest_name, phone, email, start_date, end_date, type, status, notes)
       VALUES
        ($1, $2, 'Ayşe Demir', '0532 111 22 33', 'ayse@example.com', '2026-09-07', '2026-09-12', 'konaklama', 'onaylandi', 'Deniz manzaralı'),
        ($1, $3, 'John Miller', '0533 444 55 66', 'john@example.com', '2026-09-10', '2026-09-14', 'konaklama', 'onaylandi', 'Kapadokya'),
        ($1, $2, 'Elif Kaya', '0541 777 88 99', 'elif@example.com', '2026-09-08', '2026-09-12', 'konaklama', 'beklemede', 'Erken giriş'),
        ($1, $3, 'Mehmet Yıldız', '0505 123 45 67', 'mehmet@example.com', '2026-09-18', '2026-09-22', 'konaklama', 'onaylandi', 'Aile, 4 kişi'),
        ($1, $2, 'Sara Rossi', '0555 000 11 22', 'sara@example.com', '2026-09-20', '2026-09-25', 'konaklama', 'onaylandi', NULL),
        ($1, $3, 'Can Özkan', '0532 987 65 43', 'can@example.com', '2026-09-03', '2026-09-06', 'konaklama', 'iptal', 'İptal')`,
      [villaId, limon, deniz],
    );
    console.log('Villa örnek rezervasyonları eklendi.');
  }

  const kuaforCount = await pool.query(
    'SELECT COUNT(*)::int AS count FROM reservations WHERE tenant_id = $1',
    [kuaforId],
  );
  if (kuaforCount.rows[0].count === 0) {
    const resources = await pool.query(
      'SELECT id, name FROM resources WHERE tenant_id = $1 ORDER BY id',
      [kuaforId],
    );
    const elif = resources.rows[0]?.id;
    const can = resources.rows[1]?.id;
    await pool.query(
      `INSERT INTO reservations
        (tenant_id, resource_id, guest_name, phone, start_date, end_date, start_time, duration_min, type, status, notes)
       VALUES
        ($1, $2, 'Zeynep Ak', '0532 200 11 22', '2026-09-07', '2026-09-07', '10:00', 45, 'randevu', 'onaylandi', NULL),
        ($1, $3, 'Burak Şen', '0533 300 22 33', '2026-09-07', '2026-09-07', '11:30', 90, 'randevu', 'onaylandi', 'Ombre'),
        ($1, $2, 'Selin Nur', '0541 400 33 44', '2026-09-08', '2026-09-08', '14:00', 60, 'randevu', 'beklemede', NULL),
        ($1, $3, 'Deniz Kılıç', '0505 500 44 55', '2026-09-09', '2026-09-09', '16:00', 30, 'randevu', 'onaylandi', NULL)`,
      [kuaforId, elif, can],
    );
    console.log('Kuaför örnek randevuları eklendi.');
  }

  await pool.query(
    `UPDATE customers c
     SET tenant_id = t.id, sector = t.type
     FROM tenants t
     WHERE c.tenant_id IS NULL AND c.email IN ('musteri@takvim.app') AND t.id = $1`,
    [kuaforId],
  );
  await pool.query(
    `UPDATE customers c SET sector = t.type FROM tenants t WHERE c.tenant_id = t.id AND (c.sector IS NULL OR c.sector <> t.type)`,
  );
  await pool.query(
    `UPDATE customers SET tenant_id = $1, sector = 'kuafor' WHERE tenant_id IS NULL`,
    [kuaforId],
  );

  const kuaforCustomer = await pool.query("SELECT id FROM customers WHERE email = 'musteri@takvim.app'");
  if (kuaforCustomer.rowCount === 0) {
    const created = await pool.query(
      `INSERT INTO customers (tenant_id, sector, name, email, phone, password_hash)
       VALUES ($1, 'kuafor', 'Ayşe Müşteri', 'musteri@takvim.app', '0532 000 11 22', $2)
       RETURNING id`,
      [kuaforId, hashPassword('Demo123!')],
    );
    const pending = await pool.query(
      `SELECT COUNT(*)::int AS count FROM booking_requests WHERE tenant_id = $1 AND status = 'pending'`,
      [kuaforId],
    );
    if (pending.rows[0].count === 0) {
      const staff = await pool.query(
        'SELECT id FROM resources WHERE tenant_id = $1 ORDER BY id LIMIT 1',
        [kuaforId],
      );
      await pool.query(
        `INSERT INTO booking_requests
          (tenant_id, customer_id, resource_id, guest_name, phone, email, start_date, end_date, start_time, duration_min, type, notes, status)
         VALUES ($1, $2, $3, 'Ayşe Müşteri', '0532 000 11 22', 'musteri@takvim.app', '2026-09-10', '2026-09-10', '13:00', 45, 'randevu', 'Saç kesimi', 'pending')`,
        [kuaforId, created.rows[0].id, staff.rows[0]?.id],
      );
      await pool.query(
        `INSERT INTO notifications (tenant_id, title, body, type, payload)
         VALUES ($1, 'Yeni randevu talebi', 'Ayşe Müşteri 2026-09-10 13:00 için talep oluşturdu.', 'request', $2)`,
        [kuaforId, JSON.stringify({ demo: true })],
      );
    }
    console.log('Demo kuaför müşteri: musteri@takvim.app');
  } else {
    await pool.query(
      `UPDATE customers SET tenant_id = $1, sector = 'kuafor' WHERE email = 'musteri@takvim.app'`,
      [kuaforId],
    );
  }

  const villaCustomer = await pool.query("SELECT id FROM customers WHERE email = 'villa.musteri@takvim.app'");
  if (villaCustomer.rowCount === 0) {
    await pool.query(
      `INSERT INTO customers (tenant_id, sector, name, email, phone, password_hash)
       VALUES ($1, 'villa', 'Mehmet Villa Müşteri', 'villa.musteri@takvim.app', '0532 111 00 22', $2)`,
      [villaId, hashPassword('Demo123!')],
    );
    console.log('Demo villa müşteri: villa.musteri@takvim.app');
  }

  await pool.query(
    `UPDATE reservations r SET type = 'konaklama'
     FROM tenants t WHERE r.tenant_id = t.id AND t.type = 'villa' AND r.type <> 'konaklama'`,
  );
  await pool.query(
    `UPDATE reservations r SET type = 'randevu'
     FROM tenants t WHERE r.tenant_id = t.id AND t.type = 'kuafor' AND r.type <> 'randevu'`,
  );
  await pool.query(
    `UPDATE booking_requests br SET type = 'konaklama'
     FROM tenants t WHERE br.tenant_id = t.id AND t.type = 'villa' AND br.type <> 'konaklama'`,
  );
  await pool.query(
    `UPDATE booking_requests br SET type = 'randevu'
     FROM tenants t WHERE br.tenant_id = t.id AND t.type = 'kuafor' AND br.type <> 'randevu'`,
  );

  await pool.query('ALTER TABLE booking_requests DROP CONSTRAINT IF EXISTS booking_requests_status_valid');
  await pool.query(`
    DO $$ BEGIN
      ALTER TABLE booking_requests
      ADD CONSTRAINT booking_requests_status_valid
      CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled'));
    EXCEPTION WHEN duplicate_object THEN NULL;
    END $$;
  `);

  await pool.query('ALTER TABLE customers ALTER COLUMN tenant_id SET NOT NULL');
  await pool.query('ALTER TABLE customers ALTER COLUMN sector SET NOT NULL');
  await pool.query(`
    DO $$ BEGIN
      ALTER TABLE customers ADD CONSTRAINT customers_sector_valid CHECK (sector IN ('villa', 'kuafor'));
    EXCEPTION WHEN duplicate_object THEN NULL;
    END $$;
  `);

  console.log('SaaS veritabanı hazır.');
}

migrate()
  .catch((error) => {
    console.error('Migrasyon başarısız:', error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await pool.end();
  });
