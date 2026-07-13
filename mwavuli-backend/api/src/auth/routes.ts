import { FastifyInstance } from 'fastify';
import { PoolClient } from 'pg';
import { z } from 'zod';
import { ANON, Principal, runAs } from '../db';
import { badRequest, conflict, unauthorized } from '../lib/errors';
import { parse } from '../lib/validate';
import { config } from '../config';
import { hashPassword, verifyPassword } from './password';
import { hashToken, newRefreshToken, signAccess } from './jwt';

const RegisterBody = z.object({
  email: z.string().email(),
  username: z.string().min(3).max(30).regex(/^[a-zA-Z0-9_]+$/),
  password: z.string().min(8).max(200),
  displayName: z.string().min(1).max(80),
  birthYear: z.number().int().min(1900),
  acceptTos: z.literal(true),
});

const LoginBody = z.object({
  identifier: z.string().min(1), // email or username
  password: z.string().min(1),
});

async function issueTokens(
  client: PoolClient,
  userId: string,
  role: string,
  ip: string | undefined,
  ua: string | undefined,
) {
  const access = signAccess(userId, role);
  const { raw, hash } = newRefreshToken();
  await client.query(
    `INSERT INTO refresh_tokens (user_id, token_hash, ip, user_agent, expires_at)
     VALUES ($1, $2, $3, $4, now() + ($5 || ' seconds')::interval)`,
    [userId, hash, ip ?? null, ua ?? null, String(config.JWT_REFRESH_TTL)],
  );
  return {
    accessToken: access,
    refreshToken: raw,
    tokenType: 'Bearer',
    expiresIn: config.JWT_ACCESS_TTL,
  };
}

export async function authRoutes(app: FastifyInstance) {
  // --- Register (with 13+ / COPPA gate) ---
  app.post('/v1/auth/register', async (req) => {
    const b = parse(RegisterBody, req.body);
    const age = new Date().getFullYear() - b.birthYear;
    if (age < 13) {
      // COPPA: we do not create accounts for under-13s.
      throw badRequest('You must be at least 13 years old to use mwavuli.');
    }
    return runAs(ANON, async (c) => {
      const dupe = await c.query(
        'SELECT 1 FROM users WHERE email = $1 OR username = $2',
        [b.email, b.username],
      );
      if (dupe.rowCount) throw conflict('Email or username already in use.');

      const { rows } = await c.query(
        `INSERT INTO users (email, username, password_hash, display_name, birth_year, is_13_plus)
         VALUES ($1,$2,$3,$4,$5,true)
         RETURNING id, username, display_name, role`,
        [b.email, b.username, hashPassword(b.password), b.displayName, b.birthYear],
      );
      const u = rows[0];
      await c.query(
        `INSERT INTO consents (user_id, kind, version, granted)
         VALUES ($1,'tos','2026-05',true), ($1,'privacy','2026-05',true)`,
        [u.id],
      );
      const tokens = await issueTokens(
        c, u.id, u.role, req.ip, req.headers['user-agent'] as string,
      );
      return { user: u, ...tokens };
    });
  });

  // --- Login ---
  app.post('/v1/auth/login', async (req) => {
    const b = parse(LoginBody, req.body);
    return runAs(ANON, async (c) => {
      const { rows } = await c.query(
        `SELECT id, username, display_name, role, password_hash
           FROM users
          WHERE (email = $1 OR username = $1) AND deleted_at IS NULL`,
        [b.identifier],
      );
      const u = rows[0];
      if (!u || !verifyPassword(b.password, u.password_hash)) {
        throw unauthorized('Invalid credentials.');
      }
      const tokens = await issueTokens(
        c, u.id, u.role, req.ip, req.headers['user-agent'] as string,
      );
      return {
        user: { id: u.id, username: u.username, display_name: u.display_name, role: u.role },
        ...tokens,
      };
    });
  });

  // --- Refresh (rotate) ---
  app.post('/v1/auth/refresh', async (req) => {
    const { refreshToken } = parse(
      z.object({ refreshToken: z.string().min(1) }),
      req.body,
    );
    return runAs(ANON, async (c) => {
      const { rows } = await c.query(
        `SELECT rt.id, rt.user_id, u.role
           FROM refresh_tokens rt JOIN users u ON u.id = rt.user_id
          WHERE rt.token_hash = $1 AND rt.revoked_at IS NULL
            AND rt.expires_at > now() AND u.deleted_at IS NULL`,
        [hashToken(refreshToken)],
      );
      const row = rows[0];
      if (!row) throw unauthorized('Invalid or expired refresh token.');
      await c.query('UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1', [row.id]);
      const tokens = await issueTokens(
        c, row.user_id, row.role, req.ip, req.headers['user-agent'] as string,
      );
      return tokens;
    });
  });

  // --- Logout (revoke a refresh token) ---
  app.post('/v1/auth/logout', async (req) => {
    const { refreshToken } = parse(
      z.object({ refreshToken: z.string().min(1) }),
      req.body,
    );
    await runAs(ANON, (c) =>
      c.query('UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash = $1', [
        hashToken(refreshToken),
      ]),
    );
    return { ok: true };
  });
}

export type { Principal };
