/* Apply db/migrations/*.sql in order, tracked in schema_migrations.
 * Run with a PRIVILEGED connection (migrations create extensions + roles):
 *   MIGRATE_DATABASE_URL=postgres://postgres:...@host/mwavuli npm run migrate
 */
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { Client } from 'pg';

const url = process.env.MIGRATE_DATABASE_URL ?? process.env.DATABASE_URL;

async function main() {
  if (!url) throw new Error('Set MIGRATE_DATABASE_URL or DATABASE_URL');
  const dir =
    process.env.MIGRATIONS_DIR ?? join(__dirname, '..', '..', 'db', 'migrations');
  const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();

  const client = new Client({ connectionString: url });
  await client.connect();
  await client.query(
    `CREATE TABLE IF NOT EXISTS schema_migrations (
       name text PRIMARY KEY, applied_at timestamptz DEFAULT now())`,
  );

  for (const f of files) {
    const done = await client.query('SELECT 1 FROM schema_migrations WHERE name=$1', [f]);
    if (done.rowCount) {
      console.log('· skip', f);
      continue;
    }
    console.log('▸ apply', f);
    await client.query('BEGIN');
    try {
      await client.query(readFileSync(join(dir, f), 'utf8'));
      await client.query('INSERT INTO schema_migrations(name) VALUES($1)', [f]);
      await client.query('COMMIT');
    } catch (e) {
      await client.query('ROLLBACK');
      console.error('✗ failed', f, e);
      process.exit(1);
    }
  }
  await client.end();
  console.log('✓ migrations complete');
}

main();
