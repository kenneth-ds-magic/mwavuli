import {
  GetObjectCommand,
  PutObjectCommand,
} from '@aws-sdk/client-s3';
import sharp from 'sharp';
import { PoolClient, Client } from 'pg';
import { config } from '../config';
import { s3 } from './s3';

async function streamToBuffer(stream: unknown): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const c of stream as AsyncIterable<Uint8Array>) {
    chunks.push(Buffer.from(c));
  }
  return Buffer.concat(chunks);
}

function isJpeg(buffer: Buffer): boolean {
  return (
    buffer.length >= 100 &&
    buffer[0] === 0xff &&
    buffer[1] === 0xd8 &&
    buffer[2] === 0xff
  );
}

/** Exported for upload validation. */
export function isValidJpeg(buffer: Buffer): boolean {
  return isJpeg(buffer);
}

async function markPhotoFailed(
  c: PoolClient | Client,
  storageKey: string,
): Promise<void> {
  await c.query(
    `UPDATE tree_photos SET status = 'failed' WHERE storage_key = $1 AND status = 'pending'`,
    [storageKey],
  );
}

/**
 * Download an original from the private bucket, strip EXIF, publish derivatives
 * to the public bucket, and mark the DB row processed.
 */
export async function processTreePhoto(
  c: PoolClient | Client,
  storageKey: string,
): Promise<boolean> {
  const { rows } = await c.query(
    `SELECT id, tree_id, status FROM tree_photos WHERE storage_key = $1`,
    [storageKey],
  );
  if (!rows[0] || rows[0].status === 'processed') return false;

  const obj = await s3.send(
    new GetObjectCommand({
      Bucket: config.S3_BUCKET_UPLOADS,
      Key: storageKey,
    }),
  );
  if (!obj.Body) return false;

  const input = await streamToBuffer(obj.Body);
  if (!isJpeg(input)) {
    await markPhotoFailed(c, storageKey);
    return false;
  }

  try {
    const pipeline = sharp(input).rotate();
    const full = await pipeline
      .clone()
      .resize({ width: 1080, withoutEnlargement: true })
      .jpeg({ quality: 82, mozjpeg: true })
      .toBuffer();
    const thumb = await pipeline
      .clone()
      .resize({ width: 480, withoutEnlargement: true })
      .jpeg({ quality: 78, mozjpeg: true })
      .toBuffer();
    const meta = await sharp(full).metadata();

    const base = storageKey.replace(/^uploads\//, '').replace(/\.[^.]+$/, '');
    const fullKey = `public/${base}_1080.jpg`;
    const thumbKey = `public/${base}_480.jpg`;
    const cache = 'public,max-age=31536000,immutable';

    await s3.send(
      new PutObjectCommand({
        Bucket: config.S3_BUCKET_PUBLIC,
        Key: fullKey,
        Body: full,
        ContentType: 'image/jpeg',
        CacheControl: cache,
      }),
    );
    await s3.send(
      new PutObjectCommand({
        Bucket: config.S3_BUCKET_PUBLIC,
        Key: thumbKey,
        Body: thumb,
        ContentType: 'image/jpeg',
        CacheControl: cache,
      }),
    );

    await c.query(
      `UPDATE tree_photos
          SET public_url=$1, thumb_url=$2, width=$3, height=$4,
              exif_stripped=true, status='processed'
        WHERE storage_key=$5`,
      [fullKey, thumbKey, meta.width ?? null, meta.height ?? null, storageKey],
    );
    return true;
  } catch {
    await markPhotoFailed(c, storageKey);
    return false;
  }
}

/** Process a user avatar original (uploads/<userId>/avatar/...). */
export async function processAvatar(
  c: PoolClient | Client,
  storageKey: string,
): Promise<boolean> {
  const match = storageKey.match(/^uploads\/([^/]+)\/avatar\//);
  if (!match) return false;

  const obj = await s3.send(
    new GetObjectCommand({
      Bucket: config.S3_BUCKET_UPLOADS,
      Key: storageKey,
    }),
  );
  if (!obj.Body) return false;

  const input = await streamToBuffer(obj.Body);
  const thumb = await sharp(input)
    .rotate()
    .resize({ width: 480, height: 480, fit: 'cover' })
    .jpeg({ quality: 82, mozjpeg: true })
    .toBuffer();

  const base = storageKey.replace(/^uploads\//, '').replace(/\.[^.]+$/, '');
  const thumbKey = `public/${base}_480.jpg`;

  await s3.send(
    new PutObjectCommand({
      Bucket: config.S3_BUCKET_PUBLIC,
      Key: thumbKey,
      Body: thumb,
      ContentType: 'image/jpeg',
      CacheControl: 'public,max-age=31536000,immutable',
    }),
  );

  await c.query(
    `UPDATE users SET avatar_url = $1, updated_at = now()
      WHERE id = $2 AND deleted_at IS NULL`,
    [thumbKey, match[1]],
  );
  return true;
}
