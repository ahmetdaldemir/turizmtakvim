import cors from 'cors';
import express from 'express';
import multer from 'multer';
import { env } from './config.js';
import { pool } from './db.js';
import { bearer, login, logout, requireAdmin, requireAuth, requireTenant, requestPasswordReset, resetPasswordWithToken, updateProfile } from './auth.js';
import { statuses, verticals } from './verticals.js';
import { assertKuafor, createAlbum, deleteAlbum, getAlbum, listAlbums, resolveFile } from './gallery.js';
import {
  cancelReservation,
  createReservation,
  deleteReservation,
  getReservation,
  listReservations,
  updateReservation,
} from './reservations.js';
import { createResource, deleteResource, listResources, updateResource } from './resources.js';
import { createTenant, listTenants, panelStats, updateTenant } from './tenants.js';
import { loginCustomer, logoutCustomer, requireCustomer } from './customer_auth.js';
import { createCustomerForTenant, deleteCustomer, getCustomerBusiness, listCustomers } from './customers.js';
import {
  approveRequest,
  cancelCustomerRequest,
  createRequest,
  listRequestsForCustomer,
  listRequestsForTenant,
  publicAvailability,
  rejectRequest,
  updateCustomerRequest,
} from './requests.js';
import { listNotifications, markAllRead, markRead, unreadCount } from './notifications.js';
import { startReminderJob } from './reminders.js';

const app = express();
app.use(cors());
app.use(express.json({ limit: '100kb' }));

const galleryUpload = multer({
  storage: multer.memoryStorage(),
  limits: { files: 20, fileSize: 8 * 1024 * 1024 },
  fileFilter(_req, file, done) {
    if (!/^image\/(jpeg|jpg|png|webp)$/i.test(file.mimetype)) {
      done(Object.assign(new Error('Yalnızca JPEG, PNG veya WebP yükleyin.'), { status: 400 }));
      return;
    }
    done(null, true);
  },
});

function requireKuaforTenant(req, res, next) {
  try {
    assertKuafor(req.vertical?.key);
    next();
  } catch (error) {
    res.status(error.status || 403).json({ error: error.message });
  }
}

function asyncHandler(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

function parseId(value) {
  const id = Number(value);
  if (!Number.isInteger(id) || id <= 0) {
    const error = new Error('Geçersiz numara.');
    error.status = 400;
    throw error;
  }
  return id;
}

app.get('/api/health', asyncHandler(async (_req, res) => {
  await pool.query('SELECT 1');
  res.json({ ok: true, product: 'saas' });
}));

app.get('/api/catalog', (_req, res) => {
  res.json({ verticals, statuses });
});

app.post('/api/auth/login', asyncHandler(async (req, res) => {
  try {
    res.json(await login(req.body?.email, req.body?.password));
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.post('/api/auth/forgot-password', asyncHandler(async (req, res) => {
  try {
    await requestPasswordReset(req.body?.email);
  } catch (error) {
    console.error('forgot-password', error.message);
  }
  res.json({ ok: true, message: 'E-posta kayıtlıysa sıfırlama bağlantısı gönderildi.' });
}));

app.post('/api/auth/reset-password', asyncHandler(async (req, res) => {
  try {
    await resetPasswordWithToken(req.body?.token, req.body?.password);
    res.json({ ok: true });
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.patch('/api/auth/profile', requireAuth, asyncHandler(async (req, res) => {
  try {
    res.json({ user: await updateProfile(req.user.id, req.body ?? {}) });
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.post('/api/customer/auth/register', (_req, res) => {
  res.status(403).json({
    error: 'Müşteri kaydı kapalı. Sizi ekleyen işletme yöneticisi hesabınızı oluşturur.',
  });
});

app.post('/api/customer/auth/login', asyncHandler(async (req, res) => {
  try {
    res.json(await loginCustomer(req.body?.email, req.body?.password, req.body?.sector));
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.post('/api/customer/auth/logout', requireCustomer, asyncHandler(async (req, res) => {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  await logoutCustomer(match ? match[1].trim() : null);
  res.status(204).end();
}));

app.get('/api/customer/me', requireCustomer, (req, res) => {
  res.json({ user: req.customer });
});

app.get('/api/customer/business', requireCustomer, asyncHandler(async (req, res) => {
  const business = await getCustomerBusiness(req.customer);
  if (!business) return res.status(404).json({ error: 'İşletmeniz bulunamadı.' });
  res.json(business);
}));

app.get('/api/public/businesses', requireCustomer, asyncHandler(async (req, res) => {
  const business = await getCustomerBusiness(req.customer);
  res.json(business ? [business.tenant] : []);
}));

app.get('/api/public/businesses/:id', requireCustomer, asyncHandler(async (req, res) => {
  const business = await getCustomerBusiness(req.customer);
  if (!business || business.tenant.id !== parseId(req.params.id)) {
    return res.status(403).json({ error: 'Bu işletmeyi göremezsiniz.' });
  }
  res.json(business);
}));

app.get('/api/public/businesses/:id/availability', requireCustomer, asyncHandler(async (req, res) => {
  const business = await getCustomerBusiness(req.customer);
  if (!business || business.tenant.id !== parseId(req.params.id)) {
    return res.status(403).json({ error: 'Bu işletmeyi göremezsiniz.' });
  }
  const now = new Date();
  const year = Number(req.query.year || now.getFullYear());
  const month = Number(req.query.month || now.getMonth() + 1);
  const availability = await publicAvailability(business.tenant.id, {
    year,
    month,
    resourceId: req.query.resourceId,
  });
  if (!availability) return res.status(404).json({ error: 'İşletme bulunamadı.' });
  res.json(availability);
}));

app.get('/api/customers', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  res.json(await listCustomers(req.tenantId));
}));

app.post('/api/customers', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  try {
    res.status(201).json(await createCustomerForTenant(req.user.tenant, req.body ?? {}));
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.delete('/api/customers/:id', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  const deleted = await deleteCustomer(req.tenantId, parseId(req.params.id));
  if (!deleted) return res.status(404).json({ error: 'Müşteri bulunamadı.' });
  res.status(204).end();
}));

app.get('/api/gallery/albums', requireAuth, requireTenant, requireKuaforTenant, asyncHandler(async (req, res) => {
  res.json(await listAlbums(req.tenantId));
}));

app.get('/api/gallery/albums/:id', requireAuth, requireTenant, requireKuaforTenant, asyncHandler(async (req, res) => {
  const album = await getAlbum(req.tenantId, parseId(req.params.id));
  if (!album) return res.status(404).json({ error: 'Albüm bulunamadı.' });
  res.json(album);
}));

app.post(
  '/api/gallery/albums',
  requireAuth,
  requireTenant,
  requireKuaforTenant,
  galleryUpload.array('photos', 20),
  asyncHandler(async (req, res) => {
    try {
      res.status(201).json(await createAlbum(req.tenantId, req.body?.title, req.files));
    } catch (error) {
      error.status = error.status || 400;
      throw error;
    }
  }),
);

app.delete('/api/gallery/albums/:id', requireAuth, requireTenant, requireKuaforTenant, asyncHandler(async (req, res) => {
  const deleted = await deleteAlbum(req.tenantId, parseId(req.params.id));
  if (!deleted) return res.status(404).json({ error: 'Albüm bulunamadı.' });
  res.status(204).end();
}));

app.get('/api/customer/gallery/albums', requireCustomer, asyncHandler(async (req, res) => {
  if (req.customer.sector !== 'kuafor' || !req.customer.tenantId) {
    return res.status(403).json({ error: 'Galeri yalnızca kuaför müşterilerine açıktır.' });
  }
  res.json(await listAlbums(req.customer.tenantId));
}));

app.get('/api/customer/gallery/albums/:id', requireCustomer, asyncHandler(async (req, res) => {
  if (req.customer.sector !== 'kuafor' || !req.customer.tenantId) {
    return res.status(403).json({ error: 'Galeri yalnızca kuaför müşterilerine açıktır.' });
  }
  const album = await getAlbum(req.customer.tenantId, parseId(req.params.id));
  if (!album) return res.status(404).json({ error: 'Albüm bulunamadı.' });
  res.json(album);
}));

app.get('/api/gallery/files/:tenantId/:filename', asyncHandler(async (req, res) => {
  const tenantId = parseId(req.params.tenantId);
  const filePath = await resolveFile(tenantId, req.params.filename);
  if (!filePath) return res.status(404).json({ error: 'Görsel bulunamadı.' });
  res.sendFile(filePath);
}));

app.post('/api/customer/requests', requireCustomer, asyncHandler(async (req, res) => {
  try {
    res.status(201).json(await createRequest(req.customer, req.body ?? {}));
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.get('/api/customer/requests', requireCustomer, asyncHandler(async (req, res) => {
  res.json(await listRequestsForCustomer(req.customer.id));
}));

app.patch('/api/customer/requests/:id', requireCustomer, asyncHandler(async (req, res) => {
  try {
    res.json(await updateCustomerRequest(req.customer, parseId(req.params.id), req.body ?? {}));
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.post('/api/customer/requests/:id/cancel', requireCustomer, asyncHandler(async (req, res) => {
  try {
    res.json(await cancelCustomerRequest(req.customer, parseId(req.params.id)));
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.post('/api/auth/logout', requireAuth, asyncHandler(async (req, res) => {
  await logout(bearer(req));
  res.status(204).end();
}));

app.get('/api/auth/me', requireAuth, (req, res) => {
  res.json({ user: req.user });
});

app.get('/api/panel/stats', requireAuth, requireAdmin, asyncHandler(async (_req, res) => {
  res.json(await panelStats());
}));

app.get('/api/panel/tenants', requireAuth, requireAdmin, asyncHandler(async (_req, res) => {
  res.json(await listTenants());
}));

app.post('/api/panel/tenants', requireAuth, requireAdmin, asyncHandler(async (req, res) => {
  try {
    res.status(201).json(await createTenant(req.body ?? {}));
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.patch('/api/panel/tenants/:id', requireAuth, requireAdmin, asyncHandler(async (req, res) => {
  const updated = await updateTenant(parseId(req.params.id), req.body ?? {});
  if (!updated) return res.status(404).json({ error: 'İşletme bulunamadı.' });
  res.json(updated);
}));

app.get('/api/resources', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  res.json(await listResources(req.tenantId));
}));

app.post('/api/resources', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  try {
    res.status(201).json(await createResource(req.tenantId, req.body ?? {}));
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.put('/api/resources/:id', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  const updated = await updateResource(req.tenantId, parseId(req.params.id), req.body ?? {});
  if (!updated) return res.status(404).json({ error: 'Kayıt bulunamadı.' });
  res.json(updated);
}));

app.delete('/api/resources/:id', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  const deleted = await deleteResource(req.tenantId, parseId(req.params.id));
  if (!deleted) return res.status(404).json({ error: 'Kayıt bulunamadı.' });
  res.status(204).end();
}));

app.get('/api/reservations', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  const { from, to, status, type } = req.query;
  res.json(await listReservations(req.tenantId, req.vertical, { from, to, status, type }));
}));

app.get('/api/reservations/:id', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  const reservation = await getReservation(req.tenantId, req.vertical, parseId(req.params.id));
  if (!reservation) return res.status(404).json({ error: 'Kayıt bulunamadı.' });
  res.json(reservation);
}));

app.post('/api/reservations', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  try {
    res.status(201).json(await createReservation(req.tenantId, req.vertical, req.body ?? {}));
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.put('/api/reservations/:id', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  try {
    const updated = await updateReservation(
      req.tenantId,
      req.vertical,
      parseId(req.params.id),
      req.body ?? {},
    );
    if (!updated) return res.status(404).json({ error: 'Kayıt bulunamadı.' });
    res.json(updated);
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.post('/api/reservations/:id/cancel', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  const cancelled = await cancelReservation(req.tenantId, req.vertical, parseId(req.params.id));
  if (!cancelled) return res.status(404).json({ error: 'Kayıt bulunamadı.' });
  res.json(cancelled);
}));

app.delete('/api/reservations/:id', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  const deleted = await deleteReservation(req.tenantId, parseId(req.params.id));
  if (!deleted) return res.status(404).json({ error: 'Kayıt bulunamadı.' });
  res.status(204).end();
}));

app.get('/api/requests', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  res.json(await listRequestsForTenant(req.tenantId, req.query.status));
}));

app.post('/api/requests/:id/approve', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  try {
    const result = await approveRequest(req.tenantId, req.vertical, parseId(req.params.id));
    if (!result) return res.status(404).json({ error: 'Talep bulunamadı.' });
    res.json(result);
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.post('/api/requests/:id/reject', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  try {
    const rejected = await rejectRequest(req.tenantId, parseId(req.params.id), req.body?.reason);
    if (!rejected) return res.status(404).json({ error: 'Talep bulunamadı.' });
    res.json(rejected);
  } catch (error) {
    error.status = error.status || 400;
    throw error;
  }
}));

app.get('/api/notifications', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  res.json(await listNotifications(req.tenantId));
}));

app.get('/api/notifications/unread-count', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  res.json({ count: await unreadCount(req.tenantId) });
}));

app.post('/api/notifications/read-all', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  await markAllRead(req.tenantId);
  res.status(204).end();
}));

app.post('/api/notifications/:id/read', requireAuth, requireTenant, asyncHandler(async (req, res) => {
  const item = await markRead(req.tenantId, parseId(req.params.id));
  if (!item) return res.status(404).json({ error: 'Bildirim bulunamadı.' });
  res.json(item);
}));

app.use((error, _req, res, _next) => {
  const status = error.status || 500;
  res.status(status).json({
    error: status === 500 ? 'Sunucu hatası.' : error.message,
  });
});

const server = app.listen(env.port, env.host, () => {
  console.log(`API http://${env.host}:${env.port}`);
  startReminderJob();
});

async function shutdown() {
  server.close();
  await pool.end();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
