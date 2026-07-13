/* Background worker: performs due account purges (GDPR erasure) and can be
 * extended to process export jobs and award badges. Run on a schedule
 * (e.g. every 15 min) via cron/ECS Scheduled Task, or with --loop.
 *
 *   npm run worker            # single pass
 *   npm run worker -- --loop  # keep running
 */
import { Client } from 'pg';

const url = process.env.MIGRATE_DATABASE_URL ?? process.env.DATABASE_URL;

async function purgeDueAccounts(client: Client): Promise<number> {
  // Deleting the user cascades to trees, photos, comments, tokens, etc.
  const { rows } = await client.query(
    `SELECT user_id FROM account_deletion_requests
      WHERE status='scheduled' AND purge_after <= now()`,
  );
  for (const r of rows) {
    await client.query('BEGIN');
    try {
      // TODO: also delete the user's S3 objects (originals + derivatives).
      await client.query('DELETE FROM users WHERE id=$1', [r.user_id]);
      await client.query(
        `UPDATE account_deletion_requests
            SET status='completed', completed_at=now() WHERE user_id=$1`,
        [r.user_id],
      );
      await client.query(
        `INSERT INTO audit_log (action, entity, entity_id)
         VALUES ('account.purged','user',$1)`,
        [r.user_id],
      );
      await client.query('COMMIT');
      console.log('✓ purged', r.user_id);
    } catch (e) {
      await client.query('ROLLBACK');
      console.error('✗ purge failed', r.user_id, e);
    }
  }
  return rows.length;
}

async function awardBadges(client: Client): Promise<number> {
  const { rowCount } = await client.query(
    `WITH inserted AS (
       INSERT INTO user_badges (user_id, badge_id)
       SELECT t.owner_id, b.id
         FROM trees t
         CROSS JOIN badges b
        WHERE b.code = 'first_sprout' AND t.deleted_at IS NULL
        GROUP BY t.owner_id, b.id
       ON CONFLICT DO NOTHING
       RETURNING user_id, badge_id
     )
     INSERT INTO activity (actor_id, verb, object_type, object_id, metadata)
     SELECT i.user_id, 'earned_badge', 'badge', i.badge_id,
            jsonb_build_object('code', b.code, 'name', b.name)
       FROM inserted i
       JOIN badges b ON b.id = i.badge_id`,
  );
  return rowCount ?? 0;
}

async function pass() {
  const client = new Client({ connectionString: url });
  await client.connect();
  try {
    const purged = await purgeDueAccounts(client);
    const badges = await awardBadges(client);
    console.log(`pass complete (purged ${purged}, badge events ${badges})`);
  } finally {
    await client.end();
  }
}

async function main() {
  if (process.argv.includes('--loop')) {
    // eslint-disable-next-line no-constant-condition
    while (true) {
      await pass().catch((e) => console.error(e));
      await new Promise((r) => setTimeout(r, 15 * 60 * 1000));
    }
  } else {
    await pass();
  }
}

main();
