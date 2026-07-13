import { createHash, randomBytes } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { config } from '../config';

export interface AccessClaims {
  sub: string;
  role: string;
}

export function signAccess(userId: string, role: string): string {
  return jwt.sign({ role }, config.JWT_SECRET, {
    subject: userId,
    expiresIn: config.JWT_ACCESS_TTL,
  });
}

export function verifyAccess(token: string): AccessClaims | null {
  try {
    const p = jwt.verify(token, config.JWT_SECRET) as jwt.JwtPayload;
    if (!p.sub) return null;
    return { sub: String(p.sub), role: String(p.role ?? 'user') };
  } catch {
    return null;
  }
}

// Refresh tokens are opaque random strings; only their SHA-256 is stored.
export function newRefreshToken(): { raw: string; hash: string } {
  const raw = randomBytes(32).toString('hex');
  return { raw, hash: hashToken(raw) };
}

export function hashToken(raw: string): string {
  return createHash('sha256').update(raw).digest('hex');
}
