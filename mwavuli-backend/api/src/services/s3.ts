import { S3Client } from '@aws-sdk/client-s3';
import { config } from '../config';

function clientOptions(endpoint: string) {
  return {
    region: config.S3_REGION,
    endpoint,
    forcePathStyle: true as const,
    requestChecksumCalculation: 'WHEN_REQUIRED' as const,
    responseChecksumValidation: 'WHEN_REQUIRED' as const,
    credentials: {
      accessKeyId: config.AWS_ACCESS_KEY_ID,
      secretAccessKey: config.AWS_SECRET_ACCESS_KEY,
    },
  };
}

/** Internal S3 client — AWS in prod, Docker MinIO hostname locally. */
export const s3 = new S3Client(
  config.S3_ENDPOINT ? clientOptions(config.S3_ENDPOINT) : { region: config.S3_REGION },
);

const presignClients = new Map<string, S3Client>();

/** Presign against a client-reachable host (localhost / LAN / 10.0.2.2). */
export function s3ForEndpoint(endpoint: string): S3Client {
  if (config.S3_ENDPOINT && endpoint === config.S3_ENDPOINT) return s3;
  let client = presignClients.get(endpoint);
  if (!client) {
    client = new S3Client(clientOptions(endpoint));
    presignClients.set(endpoint, client);
  }
  return client;
}
