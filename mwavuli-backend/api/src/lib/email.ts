import nodemailer, { Transporter } from 'nodemailer';
import { config } from '../config';

let transporter: Transporter | null = null;

if (config.SMTP_HOST && config.SMTP_HOST.trim().length > 0) {
  const tlsServername =
    config.SMTP_SERVERNAME ||
    (config.SMTP_HOST === 'host.docker.internal' || /^\d+\.\d+\.\d+\.\d+$/.test(config.SMTP_HOST)
      ? 'mail.ds.co.ug'
      : undefined);

  transporter = nodemailer.createTransport({
    host: config.SMTP_HOST,
    port: config.SMTP_PORT,
    secure: config.SMTP_SECURE,
    auth:
      config.SMTP_USER && config.SMTP_USER.trim().length > 0
        ? {
            user: config.SMTP_USER,
            pass: config.SMTP_PASS,
          }
        : undefined,
    tls: tlsServername
      ? {
          servername: tlsServername,
        }
      : undefined,
  });
}

export async function sendPasswordResetEmail(params: {
  to: string;
  code: string;
  username?: string;
}): Promise<boolean> {
  const { to, code, username } = params;

  if (!transporter) {
    console.warn(
      `[Email] SMTP_HOST not configured. Password reset code for ${to} (${username || 'User'}): ${code}`,
    );
    return false;
  }

  const subject = `Your Mwavuli Password Reset Code: ${code}`;
  const greeting = username ? `Hi ${username},` : 'Hello,';

  const textContent = `${greeting}

You requested a password reset for your Mwavuli account.

Your 6-digit verification code is: ${code}

This code will expire in 15 minutes. If you did not request this password reset, please ignore this email or secure your account.

Happy tree mapping,
The Mwavuli Team
`;

  const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f7f9f6; color: #1c2a1e; margin: 0; padding: 20px; }
    .container { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 32px; box-shadow: 0 4px 20px rgba(0,0,0,0.06); border: 1px solid #e2ebd8; }
    .header { text-align: center; margin-bottom: 24px; }
    .brand { font-size: 26px; font-weight: 800; color: #1e5622; letter-spacing: -0.5px; }
    .subtitle { font-size: 13px; color: #5a6e5d; margin-top: 4px; }
    .code-box { background: #f0f7ec; border: 1px dashed #2d7d32; border-radius: 12px; padding: 18px; text-align: center; margin: 24px 0; }
    .code { font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #1e5622; font-family: monospace; }
    .notice { font-size: 13px; color: #667085; line-height: 1.5; margin-top: 20px; }
    .footer { text-align: center; margin-top: 32px; font-size: 12px; color: #98a2b3; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="brand">🌳 Mwavuli</div>
      <div class="subtitle">Identify, map & celebrate trees together</div>
    </div>
    <p>${greeting}</p>
    <p>You recently requested to reset your password for your Mwavuli account. Use the 6-digit verification code below to complete the reset process:</p>
    
    <div class="code-box">
      <div class="code">${code}</div>
    </div>

    <p class="notice">This verification code is valid for <strong>15 minutes</strong>. If you did not request a password reset, you can safely ignore this email.</p>
    
    <div class="footer">
      &copy; ${new Date().getFullYear()} Mwavuli. All rights reserved.
    </div>
  </div>
</body>
</html>
`;

  try {
    const fromAddress =
      config.SMTP_FROM && config.SMTP_FROM.trim().length > 0
        ? config.SMTP_FROM
        : '"Mwavuli Support" <support@mwavuli.com>';

    const info = await transporter.sendMail({
      from: fromAddress,
      to,
      subject,
      text: textContent,
      html: htmlContent,
    });
    console.info(`[Email] Password reset code sent to ${to} (MessageId: ${info.messageId})`);
    return true;
  } catch (err) {
    console.error(`[Email] Failed to send password reset code to ${to}:`, err);
    return false;
  }
}
