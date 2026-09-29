import { GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import type { IncomingHttpHeaders } from 'http';
import { config } from '../config';
import { s3, s3ForEndpoint } from './s3';

type ReqLike = { headers?: IncomingHttpHeaders };

/** Host used to build media URLs that the client can reach. */
function clientHostFromRequest(req?: ReqLike): string | null {
  const raw = (typeof req?.headers?.host === 'string' ? req.headers.host : req?.headers?.host?.[0])?.trim();
  if (!raw) return null;
  const host = raw.split(':')[0];
  if (!host || host === 'minio' || host.endsWith('.internal')) return null;
  // Use full Host (may include port) so nginx :80 and API :8080 both work.
  return raw;
}

/**
 * Public media base for JSON responses.
 * Prefer same-origin `/v1/media` proxy (works when MinIO :9000 is firewalled).
 */
export function mediaBaseFromRequest(req?: ReqLike): string {
  const host = clientHostFromRequest(req);
  if (host) {
    const rawProto = req?.headers?.['x-forwarded-proto'];
    const proto = (Array.isArray(rawProto) ? rawProto[0] : rawProto)?.trim() || 'http';
    const scheme = proto === 'https' ? 'https' : 'http';
    const rawPrefix = req?.headers?.['x-forwarded-prefix'];
    let prefix = (Array.isArray(rawPrefix) ? rawPrefix[0] : rawPrefix)?.replace(/^\/|\/$/g, '') ?? '';
    const rawReferer = req?.headers?.['referer'];
    const referer = Array.isArray(rawReferer) ? rawReferer[0] : rawReferer;
    const rawUri = req?.headers?.['x-forwarded-uri'];
    const uri = Array.isArray(rawUri) ? rawUri[0] : rawUri;
    if (!prefix && (referer?.includes('/mwavuli') || uri?.includes('/mwavuli'))) {
      prefix = 'mwavuli';
    }
    const prefixPath = prefix ? `/${prefix}` : '';
    return `${scheme}://${host}${prefixPath}/v1/media`;
  }
  return config.S3_PUBLIC_BASE_URL.replace(/\/$/, '');
}

/** MinIO/S3 origin for legacy presigned PUTs (prefer API upload proxy on mobile). */
export function uploadEndpointFromRequest(req?: ReqLike): string {
  const host = clientHostFromRequest(req)?.split(':')[0];
  if (host) return `http://${host}:${config.S3_PUBLIC_PORT}`;
  if (config.S3_ENDPOINT && !config.S3_ENDPOINT.includes('minio:')) {
    return config.S3_ENDPOINT;
  }
  return `http://localhost:${config.S3_PUBLIC_PORT}`;
}

/**
 * Presigned PUT so the client uploads the ORIGINAL straight to the private
 * bucket (never through the API). The image worker then strips EXIF and
 * publishes derivatives.
 */
export function presignUpload(
  key: string,
  contentType: string,
  req?: ReqLike,
) {
  const endpoint = uploadEndpointFromRequest(req);
  return getSignedUrl(
    s3ForEndpoint(endpoint),
    new PutObjectCommand({
      Bucket: config.S3_BUCKET_UPLOADS,
      Key: key,
      ContentType: contentType,
    }),
    { expiresIn: 900 },
  );
}

/** Short-lived signed download (used for GDPR export archives). */
export function presignDownload(bucket: string, key: string, expiresIn = 900) {
  return getSignedUrl(
    s3,
    new GetObjectCommand({ Bucket: bucket, Key: key }),
    { expiresIn },
  );
}

export function publicUrl(key: string, mediaBase?: string): string {
  if (!key) return '';
  let cleanKey = key;
  const idx = cleanKey.lastIndexOf('/v1/media/');
  if (idx !== -1) {
    cleanKey = cleanKey.substring(idx + '/v1/media/'.length);
  } else if (cleanKey.startsWith('http://') || cleanKey.startsWith('https://')) {
    return cleanKey;
  }
  const base = (mediaBase ?? config.S3_PUBLIC_BASE_URL).replace(/\/$/, '');
  return `${base}/${cleanKey.replace(/^\//, '')}`;
}

/** Upload bytes to the private bucket (e.g. short-lived identify staging). */
export async function putPrivateObject(
  key: string,
  body: Buffer,
  contentType: string,
) {
  await s3.send(
    new PutObjectCommand({
      Bucket: config.S3_BUCKET_UPLOADS,
      Key: key,
      Body: body,
      ContentType: contentType,
    }),
  );
}

export { s3 };
