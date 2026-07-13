import { Pool, PoolClient } from 'pg';
import { config } from './config';

export const pool = new Pool({ connectionString: config.DATABASE_URL });

export type Role = 'anon' | 'user' | 'moderator' | 'admin';

export interface Principal {
  userId: string | null;
  role: Role;
}

export const ANON: Principal = { userId: null, role: 'anon' };

/**
 * Run `fn` inside a transaction with the RLS GUCs (`app.user_id`,
 * `app.user_role`) set for `principal`. Every request-scoped query MUST go
 * through here so row-level security is enforced. `set_config(..., true)` is
 * transaction-local, so the settings reset on COMMIT/ROLLBACK.
 */
export async function runAs<T>(
  principal: Principal,
  fn: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query("SELECT set_config('app.user_id', $1, true)", [
      principal.userId ?? '',
    ]);
    await client.query("SELECT set_config('app.user_role', $1, true)", [
      principal.role,
    ]);
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
