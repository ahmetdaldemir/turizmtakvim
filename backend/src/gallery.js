import { randomBytes } from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { env } from './config.js';
import { query } from './db.js';

const rootDir = path.dirname(fileURLToPath(import.meta.url));
export const galleryRoot = path.join(rootDir, '..', 'uploads', 'gallery');

const FILE_RE = /^[a-f0-9]{32}\.(jpe?g|png|webp)$/i;
const EXT_BY_TYPE = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

function photoUrl(tenantId, filename) {
  return `${env.appUrl}/api/gallery/files/${tenantId}/${filename}`;
}

function mapAlbum(row, photos = null) {
  const album = {
    id: row.id,
    title: row.title,
    photoCount: Number(row.photo_count ?? photos?.length ?? 0),
    coverUrl: row.cover ? photoUrl(row.tenant_id, row.cover) : photos?.[0]?.url ?? null,
    createdAt: row.created_at,
  };
  if (photos) album.photos = photos;
  return album;
}

export function assertKuafor(tenantType) {
  if (tenantType !== 'kuafor') {
    const error = new Error('Galeri yalnızca kuaför uygulamasındadır.');
    error.status = 403;
    throw error;
  }
}

export async function listAlbums(tenantId) {
  const { rows } = await query(
    `SELECT a.id, a.tenant_id, a.title, a.created_at,
            (SELECT COUNT(*)::int FROM gallery_photos p WHERE p.album_id = a.id) AS photo_count,
            (SELECT p.filename FROM gallery_photos p
             WHERE p.album_id = a.id ORDER BY p.sort_order, p.id LIMIT 1) AS cover
     FROM gallery_albums a
     WHERE a.tenant_id = $1
     ORDER BY a.created_at DESC`,
    [tenantId],
  );
  return rows.map((row) => mapAlbum(row));
}

export async function getAlbum(tenantId, id) {
  const { rows } = await query(
    `SELECT id, tenant_id, title, created_at FROM gallery_albums WHERE id = $1 AND tenant_id = $2`,
    [id, tenantId],
  );
  if (!rows[0]) return null;
  const photos = await query(
    `SELECT id, filename, sort_order FROM gallery_photos
     WHERE album_id = $1 AND tenant_id = $2
     ORDER BY sort_order, id`,
    [id, tenantId],
  );
  return mapAlbum(
    { ...rows[0], photo_count: photos.rows.length, cover: photos.rows[0]?.filename },
    photos.rows.map((row, index) => ({
      id: row.id,
      url: photoUrl(tenantId, row.filename),
      sortOrder: row.sort_order ?? index,
    })),
  );
}

export async function createAlbum(tenantId, title, files) {
  const name = String(title ?? '').trim();
  if (!name) {
    const error = new Error('Albüm adı zorunlu.');
    error.status = 400;
    throw error;
  }
  if (!files?.length) {
    const error = new Error('En az bir görsel seçin.');
    error.status = 400;
    throw error;
  }
  if (files.length > 20) {
    const error = new Error('Bir albümde en fazla 20 görsel olabilir.');
    error.status = 400;
    throw error;
  }

  const { rows } = await query(
    `INSERT INTO gallery_albums (tenant_id, title) VALUES ($1, $2) RETURNING id, tenant_id, title, created_at`,
    [tenantId, name],
  );
  const album = rows[0];
  const dir = path.join(galleryRoot, String(tenantId));
  await fs.mkdir(dir, { recursive: true });

  try {
    for (const [index, file] of files.entries()) {
      const ext = EXT_BY_TYPE[file.mimetype] || '.jpg';
      const filename = `${randomBytes(16).toString('hex')}${ext}`;
      await fs.writeFile(path.join(dir, filename), file.buffer);
      await query(
        `INSERT INTO gallery_photos (album_id, tenant_id, filename, sort_order)
         VALUES ($1, $2, $3, $4)`,
        [album.id, tenantId, filename, index],
      );
    }
  } catch (error) {
    await query('DELETE FROM gallery_albums WHERE id = $1 AND tenant_id = $2', [album.id, tenantId]);
    throw error;
  }

  return getAlbum(tenantId, album.id);
}

export async function deleteAlbum(tenantId, id) {
  const { rows } = await query(
    `SELECT filename FROM gallery_photos WHERE album_id = $1 AND tenant_id = $2`,
    [id, tenantId],
  );
  const { rowCount } = await query(
    'DELETE FROM gallery_albums WHERE id = $1 AND tenant_id = $2',
    [id, tenantId],
  );
  if (!rowCount) return false;
  await Promise.all(
    rows.map((row) =>
      fs.unlink(path.join(galleryRoot, String(tenantId), row.filename)).catch(() => {}),
    ),
  );
  return true;
}

export async function resolveFile(tenantId, filename) {
  if (!FILE_RE.test(filename)) return null;
  const { rowCount } = await query(
    `SELECT 1 FROM gallery_photos WHERE tenant_id = $1 AND filename = $2 LIMIT 1`,
    [tenantId, filename],
  );
  if (!rowCount) return null;
  const filePath = path.join(galleryRoot, String(tenantId), filename);
  try {
    await fs.access(filePath);
  } catch {
    return null;
  }
  return filePath;
}
