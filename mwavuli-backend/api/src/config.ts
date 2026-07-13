import { z } from 'zod';

const Env = z.object({
  NODE_ENV: z.string().default('development'),
  PORT: z.coerce.number().default(8080),
  LOG_LEVEL: z.string().default('info'),
  DATABASE_URL: z.string(),
  JWT_SECRET: z.string().min(16, 'JWT_SECRET must be at least 16 chars'),
  JWT_ACCESS_TTL: z.coerce.number().default(900),
  JWT_REFRESH_TTL: z.coerce.number().default(2_592_000),
  CORS_ORIGIN: z.string().default('*'),
  RATE_LIMIT_MAX: z.coerce.number().default(120),
  RATE_LIMIT_WINDOW: z.coerce.number().default(60_000),
  S3_REGION: z.string().default('us-east-1'),
  S3_BUCKET_UPLOADS: z.string().default('mwavuli-uploads-private'),
  S3_BUCKET_PUBLIC: z.string().default('mwavuli-public'),
  S3_PUBLIC_BASE_URL: z.string().default('http://localhost:9000/mwavuli-public'),
  S3_PUBLIC_PORT: z.coerce.number().default(9000),
  S3_ENDPOINT: z.string().optional(),
  AWS_ACCESS_KEY_ID: z.string().default('minioadmin'),
  AWS_SECRET_ACCESS_KEY: z.string().default('minioadmin'),
  VERIFY_VOTES_REQUIRED: z.coerce.number().default(2),
  PLANTNET_API_KEY: z.string().default(''),
  PLANTNET_ENDPOINT: z
    .string()
    .default('https://my-api.plantnet.org/v2/identify/all'),
});

export const config = Env.parse(process.env);
export type Config = z.infer<typeof Env>;
