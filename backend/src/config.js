import dotenv from 'dotenv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(rootDir, '..', '.env') });

function required(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} ortam değişkeni tanımlı değil.`);
  }
  return value;
}

export const env = {
  port: Number(process.env.PORT || 3000),
  host: process.env.HOST || '0.0.0.0',
  dbHost: required('DB_HOST'),
  dbPort: Number(process.env.DB_PORT || 5432),
  dbUser: required('DB_USER'),
  dbPassword: required('DB_PASSWORD'),
  dbName: required('DB_NAME'),
  smtpHost: process.env.SMTP_HOST || '',
  smtpPort: Number(process.env.SMTP_PORT || 587),
  smtpUser: process.env.SMTP_USER || '',
  smtpPass: process.env.SMTP_PASS || '',
  smtpSecure: process.env.SMTP_SECURE === '1' || process.env.SMTP_SECURE === 'true',
  mailFrom: process.env.MAIL_FROM || 'Müsait Villam <noreply@musaitvillam.com>',
  appUrl: (process.env.APP_URL || 'https://musaitvillam.com').replace(/\/$/, ''),
};
