import { FastifyInstance } from 'fastify';
import { pool } from '../db';

export async function healthRoutes(app: FastifyInstance) {
  app.get('/health', async (_req, reply) => {
    try {
      await pool.query('SELECT 1');
      return { status: 'ok', time: new Date().toISOString() };
    } catch {
      reply.code(503);
      return { status: 'degraded', db: 'unavailable' };
    }
  });
}
