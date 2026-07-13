import { Client } from 'pg';

/**
 * Flip the photo row to processed. NOTE: for production, front RDS with an RDS
 * Proxy (or use a Data API) so Lambda doesn't exhaust Postgres connections;
 * a per-invocation Client is fine for low volume / local testing.
 */
export async function updatePhoto(
  storageKey: string,
  publicKey: string,
  thumbKey: string,
  width: number | null,
  height: number | null,
) {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    await client.query(
      `UPDATE tree_photos
          SET public_url=$1, thumb_url=$2, width=$3, height=$4,
              exif_stripped=true, status='processed'
        WHERE storage_key=$5`,
      [publicKey, thumbKey, width, height, storageKey],
    );
  } finally {
    await client.end();
  }
}

/** Set the user's avatar to the processed thumb key (storage path, not full URL). */
export async function updateAvatar(storageKey: string, thumbKey: string) {
  const match = storageKey.match(/^uploads\/([^/]+)\/avatar\//);
  if (!match) return;
  const userId = match[1];

  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    await client.query(
      `UPDATE users
          SET avatar_url = $1, updated_at = now()
        WHERE id = $2 AND deleted_at IS NULL`,
      [thumbKey, userId],
    );
  } finally {
    await client.end();
  }
}
