/* Create (or promote) an admin user.
 *   npm run create-admin -- admin@example.com adminuser 'StrongPass123' 'Admin'
 */
import { Client } from 'pg';
import { hashPassword } from '../src/auth/password';

const url = process.env.MIGRATE_DATABASE_URL ?? process.env.DATABASE_URL;

async function main() {
  const [email, username, password, ...nameParts] = process.argv.slice(2);
  const displayName = nameParts.join(' ') || username;
  if (!email || !username || !password) {
    console.error('Usage: create-admin <email> <username> <password> [displayName]');
    process.exit(1);
  }
  const client = new Client({ connectionString: url });
  await client.connect();
  await client.query(
    `INSERT INTO users (email, username, password_hash, display_name, role, is_13_plus)
     VALUES ($1,$2,$3,$4,'admin',true)
     ON CONFLICT (email) DO UPDATE
       SET role='admin', password_hash=EXCLUDED.password_hash`,
    [email, username, hashPassword(password), displayName],
  );
  await client.end();
  console.log(`✓ admin ready: ${email}`);
}

main();
