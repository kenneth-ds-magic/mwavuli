import 'fastify';
import type { Principal } from './db';

declare module 'fastify' {
  interface FastifyRequest {
    // Set by the auth plugin on every request (ANON when unauthenticated).
    principal: Principal;
  }
}
