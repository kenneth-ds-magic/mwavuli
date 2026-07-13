import {
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import sharp from 'sharp';
import { updateAvatar, updatePhoto } from './db';

const s3 = new S3Client({});
const PUBLIC_BUCKET = process.env.S3_BUCKET_PUBLIC as string;

// Minimal shape of the S3 trigger event (avoids an @types/aws-lambda dep).
interface S3Event {
  Records: Array<{ s3: { bucket: { name: string }; object: { key: string } } }>;
}

async function streamToBuffer(stream: unknown): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const c of stream as AsyncIterable<Uint8Array>) {
    chunks.push(Buffer.from(c));
  }
  return Buffer.concat(chunks);
}

/**
 * Triggered on upload of an original to the PRIVATE bucket. Produces
 * EXIF-stripped derivatives in the PUBLIC bucket and marks the photo processed.
 *
 * Privacy: sharp drops ALL metadata by default (we never call withMetadata()),
 * so GPS EXIF is removed. `.rotate()` bakes in the correct orientation first so
 * the visual result is right without keeping the orientation tag.
 */
export const handler = async (event: S3Event) => {
  for (const rec of event.Records) {
    const bucket = rec.s3.bucket.name;
    const key = decodeURIComponent(rec.s3.object.key.replace(/\+/g, ' '));

    const obj = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
    const input = await streamToBuffer(obj.Body);

    const pipeline = sharp(input).rotate(); // auto-orient + strip EXIF/GPS
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

    const base = key.replace(/^uploads\//, '').replace(/\.[^.]+$/, '');
    const fullKey = `public/${base}_1080.jpg`;
    const thumbKey = `public/${base}_480.jpg`;

    const cache = 'public,max-age=31536000,immutable';
    await s3.send(new PutObjectCommand({
      Bucket: PUBLIC_BUCKET, Key: fullKey, Body: full,
      ContentType: 'image/jpeg', CacheControl: cache,
    }));
    await s3.send(new PutObjectCommand({
      Bucket: PUBLIC_BUCKET, Key: thumbKey, Body: thumb,
      ContentType: 'image/jpeg', CacheControl: cache,
    }));

    if (key.includes('/avatar/')) {
      await updateAvatar(key, thumbKey);
    } else {
      await updatePhoto(key, fullKey, thumbKey, meta.width ?? null, meta.height ?? null);
    }
  }
  return { ok: true };
};
