/* Polls for pending tree photos / avatars in S3 and runs the image pipeline.
 *
 *   npm run image-worker            # single pass
 *   npm run image-worker -- --loop  # every 5s (local dev)
 */
import { Client } from 'pg';
import { HeadObjectCommand } from '@aws-sdk/client-s3';
import { config } from '../src/config';
import { s3 } from '../src/services/s3';
import { processAvatar, processTreePhoto } from '../src/services/image-process';

const url = process.env.MIGRATE_DATABASE_URL ?? process.env.DATABASE_URL;

async function objectExists(key: string): Promise<boolean> {
  try {
    await s3.send(
      new HeadObjectCommand({ Bucket: config.S3_BUCKET_UPLOADS, Key: key }),
    );
    return true;
  } catch {
    return false;
  }
}

async function pass(): Promise<number> {
  const client = new Client({ connectionString: url });
  await client.connect();
  let n = 0;
  try {
    const { rows } = await client.query(
      `SELECT storage_key FROM tree_photos
        WHERE status = 'pending'
        ORDER BY created_at
        LIMIT 20`,
    );
    for (const r of rows) {
      const key = r.storage_key as string;
      if (!(await objectExists(key))) continue;
      try {
        if (key.includes('/avatar/')) {
          if (await processAvatar(client, key)) n += 1;
        } else if (await processTreePhoto(client, key)) {
          n += 1;
        }
      } catch (e) {
        console.error('process failed', key, e);
        await client.query(
          `UPDATE tree_photos SET status = 'failed'
            WHERE storage_key = $1 AND status = 'pending'`,
          [key],
        );
      }
    }
  } finally {
    await client.end();
  }
  if (n > 0) console.log(`processed ${n} image(s)`);
  return n;
}

async function main() {
  if (process.argv.includes('--loop')) {
    // eslint-disable-next-line no-constant-condition
    while (true) {
      await pass().catch((e) => console.error(e));
      await new Promise((r) => setTimeout(r, 5000));
    }
  } else {
    await pass();
  }
}

main();
