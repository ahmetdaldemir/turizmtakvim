import { spawn } from 'node:child_process';
import { env } from './config.js';

function recipientsOf(to) {
  return (Array.isArray(to) ? to : [to])
    .map((value) => String(value || '').trim())
    .filter(Boolean);
}

async function sendViaSmtp({ to, subject, text, html }) {
  const nodemailer = (await import('nodemailer')).default;
  const transporter = nodemailer.createTransport({
    host: env.smtpHost,
    port: env.smtpPort,
    secure: env.smtpSecure || env.smtpPort === 465,
    auth: env.smtpUser ? { user: env.smtpUser, pass: env.smtpPass } : undefined,
  });
  return transporter.sendMail({
    from: env.mailFrom,
    to: to.join(', '),
    subject,
    text,
    html: html || text.replace(/\n/g, '<br>'),
  });
}

function sendViaSendmail({ to, subject, text }) {
  return new Promise((resolve, reject) => {
    const proc = spawn('/usr/sbin/sendmail', ['-t', '-i'], { stdio: ['pipe', 'ignore', 'pipe'] });
    let stderr = '';
    proc.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });
    proc.on('error', reject);
    proc.on('close', (code) => {
      if (code === 0) resolve({ accepted: to });
      else reject(new Error(stderr.trim() || `sendmail exited ${code}`));
    });
    proc.stdin.end(
      [`From: ${env.mailFrom}`, `To: ${to.join(', ')}`, `Subject: ${subject}`, `Content-Type: text/plain; charset=UTF-8`, '', text, ''].join('\n'),
    );
  });
}

export async function sendMail({ to, subject, text, html }) {
  const recipients = recipientsOf(to);
  if (recipients.length === 0) return { skipped: true };

  if (env.smtpHost) {
    try {
      const info = await sendViaSmtp({ to: recipients, subject, text, html });
      console.log('mail sent smtp', subject, recipients.join(', '));
      return info;
    } catch (error) {
      console.error('smtp mail failed', error.message);
    }
  }

  try {
    const info = await sendViaSendmail({ to: recipients, subject, text });
    console.log('mail sent sendmail', subject, recipients.join(', '));
    return info;
  } catch (error) {
    console.error('sendmail failed', error.message);
  }

  console.log('MAIL NOT SENT', subject, recipients.join(', '));
  throw new Error('E-posta gönderilemedi.');
}
