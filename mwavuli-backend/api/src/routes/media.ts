import { GetObjectCommand } from '@aws-sdk/client-s3';
import { FastifyInstance } from 'fastify';
import { config } from '../config';
import { notFound } from '../lib/errors';
import { s3 } from './s3';

async function streamToBuffer(stream: unknown): Promise<Buffer> {
  const chunks: Buffer[] = [];
  for await (const c of stream as AsyncIterable<Uint8Array>) {
    chunks.push(Buffer.from(c));
  }
  return Buffer.concat(chunks);
}

/**
 * Proxy public MinIO/S3 objects through the API so phones never need :9000 open.
 * Keys look like `public/<user>/<tree>/…_480.jpg`.
 */
export async function mediaRoutes(app: FastifyInstance) {
  app.get('/v1/media/*', async (req, reply) => {
    const key = String((req.params as { '*': string })['*'] ?? '').replace(
      /^\//,
      '',
    );
    if (!key || key.includes('..') || !key.startsWith('public/')) {
      throw notFound('Media not found');
    }

    try {
      const obj = await s3.send(
        new GetObjectCommand({
          Bucket: config.S3_BUCKET_PUBLIC,
          Key: key,
        }),
      );
      if (!obj.Body) throw notFound('Media not found');

      const body = await streamToBuffer(obj.Body);
      reply
        .header(
          'Content-Type',
          obj.ContentType ?? 'image/jpeg',
        )
        .header('Cache-Control', 'public,max-age=86400')
        .send(body);
    } catch {
      throw notFound('Media not found');
    }
  });
}
