CREATE TABLE IF NOT EXISTS tenants (
  id SERIAL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  slug VARCHAR(80) NOT NULL UNIQUE,
  type VARCHAR(30) NOT NULL,
  status VARCHAR(30) NOT NULL DEFAULT 'active',
  plan VARCHAR(30) NOT NULL DEFAULT 'trial',
  phone VARCHAR(50),
  email VARCHAR(200),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT tenants_type_valid CHECK (type IN ('villa', 'kuafor')),
  CONSTRAINT tenants_status_valid CHECK (status IN ('active', 'trial', 'suspended'))
);

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL,
  email VARCHAR(200) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role VARCHAR(30) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT users_role_valid CHECK (role IN ('super_admin', 'owner', 'staff')),
  CONSTRAINT users_tenant_role CHECK (
    (role = 'super_admin' AND tenant_id IS NULL) OR
    (role <> 'super_admin' AND tenant_id IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS resources (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  name VARCHAR(200) NOT NULL,
  region VARCHAR(200),
  description TEXT,
  color VARCHAR(20) NOT NULL DEFAULT '#0D9488',
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE resources ADD COLUMN IF NOT EXISTS region VARCHAR(200);
ALTER TABLE resources ADD COLUMN IF NOT EXISTS description TEXT;

ALTER TABLE reservations ADD COLUMN IF NOT EXISTS tenant_id INTEGER REFERENCES tenants(id) ON DELETE CASCADE;
ALTER TABLE reservations ADD COLUMN IF NOT EXISTS resource_id INTEGER REFERENCES resources(id) ON DELETE SET NULL;
ALTER TABLE reservations ADD COLUMN IF NOT EXISTS start_time TIME;
ALTER TABLE reservations ADD COLUMN IF NOT EXISTS duration_min INTEGER;

CREATE INDEX IF NOT EXISTS idx_users_tenant ON users (tenant_id);
CREATE INDEX IF NOT EXISTS idx_resources_tenant ON resources (tenant_id);
CREATE INDEX IF NOT EXISTS idx_reservations_tenant ON reservations (tenant_id);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions (expires_at);

CREATE TABLE IF NOT EXISTS customers (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  sector VARCHAR(30) NOT NULL,
  name VARCHAR(200) NOT NULL,
  email VARCHAR(200) NOT NULL UNIQUE,
  phone VARCHAR(50),
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT customers_sector_valid CHECK (sector IN ('villa', 'kuafor'))
);

ALTER TABLE customers ADD COLUMN IF NOT EXISTS tenant_id INTEGER REFERENCES tenants(id) ON DELETE CASCADE;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS sector VARCHAR(30);

CREATE TABLE IF NOT EXISTS customer_sessions (
  token TEXT PRIMARY KEY,
  customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS booking_requests (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  resource_id INTEGER REFERENCES resources(id) ON DELETE SET NULL,
  guest_name VARCHAR(200) NOT NULL,
  phone VARCHAR(50),
  email VARCHAR(200),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  start_time TIME,
  duration_min INTEGER,
  type VARCHAR(50) NOT NULL,
  notes TEXT,
  status VARCHAR(30) NOT NULL DEFAULT 'pending',
  reservation_id INTEGER REFERENCES reservations(id) ON DELETE SET NULL,
  reject_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT booking_requests_status_valid CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
  CONSTRAINT booking_requests_dates_valid CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS notifications (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  body TEXT NOT NULL,
  type VARCHAR(50) NOT NULL DEFAULT 'request',
  read_at TIMESTAMPTZ,
  payload JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_customers_email ON customers (email);
CREATE INDEX IF NOT EXISTS idx_customers_tenant ON customers (tenant_id);
CREATE INDEX IF NOT EXISTS idx_customers_sector ON customers (sector);
CREATE INDEX IF NOT EXISTS idx_booking_requests_tenant ON booking_requests (tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_booking_requests_customer ON booking_requests (customer_id);
CREATE INDEX IF NOT EXISTS idx_notifications_tenant ON notifications (tenant_id, created_at DESC);

CREATE TABLE IF NOT EXISTS password_resets (
  token TEXT PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_password_resets_user ON password_resets (user_id);

CREATE TABLE IF NOT EXISTS gallery_albums (
  id SERIAL PRIMARY KEY,
  tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  title VARCHAR(200) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS gallery_photos (
  id SERIAL PRIMARY KEY,
  album_id INTEGER NOT NULL REFERENCES gallery_albums(id) ON DELETE CASCADE,
  tenant_id INTEGER NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  filename VARCHAR(80) NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gallery_albums_tenant ON gallery_albums (tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gallery_photos_album ON gallery_photos (album_id, sort_order);

CREATE TABLE IF NOT EXISTS reservation_reminders (
  reservation_id INTEGER NOT NULL REFERENCES reservations(id) ON DELETE CASCADE,
  send_date DATE NOT NULL,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (reservation_id, send_date)
);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tenants_updated_at ON tenants;
CREATE TRIGGER trg_tenants_updated_at
BEFORE UPDATE ON tenants
FOR EACH ROW
EXECUTE PROCEDURE set_updated_at();

CREATE OR REPLACE FUNCTION set_reservations_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_reservations_updated_at ON reservations;
CREATE TRIGGER trg_reservations_updated_at
BEFORE UPDATE ON reservations
FOR EACH ROW
EXECUTE PROCEDURE set_reservations_updated_at();
