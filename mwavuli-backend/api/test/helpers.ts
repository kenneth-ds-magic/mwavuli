import { Pool } from 'pg';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/server';

let _app: Promise<FastifyInstance> | null = null;
export function getApp(): Promise<FastifyInstance> {
  return (_app ??= buildApp());
}

let _n = 0;
export function uniq(prefix = 'u'): string {
  return `${prefix}${Date.now()}${_n++}`;
}

export function auth(token: string) {
  return { authorization: `Bearer ${token}` };
}

export interface Session {
  accessToken: string;
  refreshToken: string;
  user: { id: string; username: string; role: string };
  username: string;
}

export async function registerUser(app: FastifyInstance): Promise<Session> {
  const u = uniq();
  const res = await app.inject({
    method: 'POST',
    url: '/v1/auth/register',
    payload: {
      email: `${u}@example.com`, username: u, password: 'password123',
      displayName: 'Test User', birthYear: 1990, acceptTos: true,
    },
  });
  if (res.statusCode !== 200) throw new Error('register failed: ' + res.body);
  return { ...(res.json() as object), username: u } as Session;
}

const privUrl = process.env.MIGRATE_DATABASE_URL ?? process.env.DATABASE_URL;
let _pool: Pool | null = null;
function priv(): Pool {
  return (_pool ??= new Pool({ connectionString: privUrl }));
}

/** Promote a user to admin (privileged connection). Re-login for a new token. */
export async function promoteToAdmin(username: string): Promise<void> {
  await priv().query(`UPDATE users SET role='admin' WHERE username=$1`, [username]);
}

export async function login(app: FastifyInstance, identifier: string, password = 'password123') {
  const res = await app.inject({
    method: 'POST', url: '/v1/auth/login',
    payload: { identifier, password },
  });
  return res;
}

export async function createOakTree(
  app: FastifyInstance,
  token: string,
  opts: { isFuzzy?: boolean; visibility?: string } = {},
) {
  return app.inject({
    method: 'POST', url: '/v1/trees', headers: auth(token),
    payload: {
      commonName: 'English Oak', scientificName: 'Quercus robur', health: 'healthy',
      visibility: opts.visibility ?? 'public', isFuzzy: opts.isFuzzy ?? true,
      lat: 43.6489, lng: -79.3817, features: ['Heritage'], photos: [],
    },
  });
}
