import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { runAs } from '../db';
import { notFound } from '../lib/errors';
import { parse } from '../lib/validate';
import { requireAuth } from '../auth/plugin';

export async function commentRoutes(app: FastifyInstance) {
  app.get('/v1/trees/:id/comments', async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      const { rows } = await c.query(
        `SELECT c.id, c.body, c.created_at, u.display_name AS author, u.username
           FROM comments c JOIN users u ON u.id = c.author_id
          WHERE c.tree_id = $1 AND c.status = 'visible'
          ORDER BY c.created_at ASC`,
        [id],
      );
      return { items: rows };
    });
  });

  app.post('/v1/trees/:id/comments', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    const { body } = parse(
      z.object({ body: z.string().min(1).max(2000) }),
      req.body,
    );
    return runAs(req.principal, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO comments (tree_id, author_id, body) VALUES ($1,$2,$3)
         RETURNING id, body, created_at`,
        [id, req.principal.userId, body],
      );
      await c.query(
        `INSERT INTO activity (actor_id, verb, object_type, object_id, metadata)
         VALUES ($1,'commented','tree',$2, jsonb_build_object('body', $3::text))`,
        [req.principal.userId, id, body],
      );
      return rows[0];
    });
  });

  app.delete('/v1/comments/:id', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      const r = await c.query(
        `UPDATE comments SET status='removed', deleted_at=now() WHERE id=$1`,
        [id],
      );
      if (!r.rowCount) throw notFound('Comment not found');
      return { ok: true };
    });
  });
}
