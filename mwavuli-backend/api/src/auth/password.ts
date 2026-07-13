import { randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

// scrypt (built into Node — no native deps). Format: scrypt$<salt>$<key>.
// For a large production deployment argon2id is also a fine choice; the
// verify function keys off the scheme prefix so both can coexist.
const KEYLEN = 64;

export function hashPassword(password: string): string {
  const salt = randomBytes(16);
  const key = scryptSync(password, salt, KEYLEN);
  return `scrypt$${salt.toString('hex')}$${key.toString('hex')}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  const [scheme, saltHex, keyHex] = stored.split('$');
  if (scheme !== 'scrypt' || !saltHex || !keyHex) return false;
  const salt = Buffer.from(saltHex, 'hex');
  const key = Buffer.from(keyHex, 'hex');
  const test = scryptSync(password, salt, key.length);
  return key.length === test.length && timingSafeEqual(key, test);
}
