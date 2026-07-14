import Fastify from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import { config } from './config';
import { AppError } from './lib/errors';
import { registerAuth } from './auth/plugin';
import { authRoutes } from './auth/routes';
import { treeRoutes } from './routes/trees';
import { identifyRoutes } from './routes/identify';
import { commentRoutes } from './routes/comments';
import { socialRoutes } from './routes/social';
import { meRoutes } from './routes/me';
import { communityRoutes } from './routes/community';
import { moderationRoutes } from './routes/moderation';
import { exploreRoutes } from './routes/explore';
import { healthRoutes } from './routes/health';
import './types';

export async function buildApp() {
  const app = Fastify({
    logger: { level: config.LOG_LEVEL },
    trustProxy: true, // behind a load balancer — trust X-Forwarded-For for req.ip
    // Identify sends base64 JPEGs in JSON; default 1 MiB is far too small.
    bodyLimit: 25 * 1024 * 1024,
  });

  await app.register(helmet);
  await app.register(cors, {
    origin: config.CORS_ORIGIN === '*' ? true : config.CORS_ORIGIN.split(','),
    credentials: true,
  });

  // Auth first so req.principal exists when the limiter builds its key.
  await registerAuth(app);

  await app.register(rateLimit, {
    global: true,
    // Effectively disabled under test so parallel inject() calls don't 429.
    max: process.env.NODE_ENV === 'test' ? 100_000 : config.RATE_LIMIT_MAX,
    timeWindow: config.RATE_LIMIT_WINDOW,
    keyGenerator: (req) => req.principal?.userId ?? req.ip,
    // For horizontal scale, pass `redis: new Redis(...)` here so counters are
    // shared across instances.
  });

  // Raw image bytes for PUT /v1/photos/:id/upload (mobile → API → MinIO).
  app.addContentTypeParser(
    ['image/jpeg', 'image/png', 'image/webp', 'application/octet-stream'],
    { parseAs: 'buffer', bodyLimit: 12 * 1024 * 1024 },
    (_req, body, done) => {
      done(null, body);
    },
  );

  app.setErrorHandler((err, req, reply) => {
    if (err instanceof AppError) {
      reply.code(err.statusCode).send({ error: err.code, message: err.message });
      return;
    }
    if ((err as { validation?: unknown }).validation) {
      reply.code(400).send({ error: 'bad_request', message: err.message });
      return;
    }
    const status = (err as { statusCode?: number }).statusCode ?? 500;
    if (status >= 500) req.log.error(err);
    reply.code(status).send({
      error: status >= 500 ? 'internal' : 'error',
      message: status >= 500 ? 'Internal server error' : err.message,
    });
  });

  // Routes.
  await healthRoutes(app);
  await authRoutes(app);
  await treeRoutes(app);
  await identifyRoutes(app);
  await commentRoutes(app);
  await socialRoutes(app);
  await meRoutes(app);
  await communityRoutes(app);
  await exploreRoutes(app);
  await moderationRoutes(app);

  return app;
}

if (require.main === module) {
  buildApp()
    .then((app) => app.listen({ port: config.PORT, host: '0.0.0.0' }))
    .catch((err) => {
      // eslint-disable-next-line no-console
      console.error(err);
      process.exit(1);
    });
}
