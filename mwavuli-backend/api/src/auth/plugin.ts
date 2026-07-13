import { FastifyInstance, FastifyRequest } from 'fastify';
import { ANON, Principal, Role } from '../db';
import { forbidden, unauthorized } from '../lib/errors';
import { verifyAccess } from './jwt';

function readPrincipal(req: FastifyRequest): Principal {
  const h = req.headers.authorization;
  if (!h || !h.startsWith('Bearer ')) return ANON;
  const claims = verifyAccess(h.slice(7));
  if (!claims) return ANON;
  return { userId: claims.sub, role: (claims.role as Role) || 'user' };
}

/** Attaches `req.principal` to every request (ANON when unauthenticated). */
export async function registerAuth(app: FastifyInstance) {
  app.decorateRequest('principal', ANON);
  app.addHook('onRequest', async (req) => {
    req.principal = readPrincipal(req);
  });
}

/** preHandler: require a logged-in user. */
export async function requireAuth(req: FastifyRequest) {
  if (req.principal.role === 'anon' || !req.principal.userId) {
    throw unauthorized();
  }
}

/** preHandler: require moderator or admin. */
export async function requireStaff(req: FastifyRequest) {
  if (req.principal.role !== 'moderator' && req.principal.role !== 'admin') {
    throw forbidden('Staff only');
  }
}
