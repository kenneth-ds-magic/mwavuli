import { FastifyInstance } from 'fastify';
import { PoolClient } from 'pg';
import { z } from 'zod';
import { runAs } from '../db';
import { notFound } from '../lib/errors';
import { parse } from '../lib/validate';
import { requireAuth, requireStaff } from '../auth/plugin';

const REASONS = [
  'inaccurate_id', 'wrong_location', 'spam', 'offensive',
  'sensitive_species', 'privacy', 'other',
] as const;

async function applyAction(
  c: PoolClient, targetType: string, targetId: string, action: string,
) {
  if (targetType === 'tree') {
    if (action === 'hide')
      await c.query(`UPDATE trees SET status='hidden' WHERE id=$1`, [targetId]);
    else if (action === 'remove')
      await c.query(`UPDATE trees SET status='removed', deleted_at=now() WHERE id=$1`, [targetId]);
    else if (action === 'restore')
      await c.query(`UPDATE trees SET status='active', deleted_at=NULL WHERE id=$1`, [targetId]);
  } else if (targetType === 'comment') {
    if (action === 'hide')
      await c.query(`UPDATE comments SET status='hidden' WHERE id=$1`, [targetId]);
    else if (action === 'remove')
      await c.query(`UPDATE comments SET status='removed', deleted_at=now() WHERE id=$1`, [targetId]);
    else if (action === 'restore')
      await c.query(`UPDATE comments SET status='visible' WHERE id=$1`, [targetId]);
  } else if (targetType === 'user' && action === 'ban') {
    await c.query(`UPDATE users SET deleted_at=now() WHERE id=$1`, [targetId]);
  }
}

export async function moderationRoutes(app: FastifyInstance) {
  // File a report (any authenticated user).
  app.post('/v1/reports', { preHandler: requireAuth }, async (req) => {
    const b = parse(
      z.object({
        targetType: z.enum(['tree', 'comment', 'user']),
        targetId: z.string().uuid(),
        reason: z.enum(REASONS),
        details: z.string().max(1000).optional(),
      }),
      req.body,
    );
    return runAs(req.principal, async (c) => {
      const { rows } = await c.query(
        `INSERT INTO reports (reporter_id, target_type, target_id, reason, details)
         VALUES ($1,$2,$3,$4,$5) RETURNING id, status, created_at`,
        [req.principal.userId, b.targetType, b.targetId, b.reason, b.details ?? null],
      );
      return rows[0];
    });
  });

  // --- Admin dashboard endpoints (staff only) ---
  app.get('/v1/admin/metrics', { preHandler: requireStaff }, async (req) =>
    runAs(req.principal, async (c) => {
      const { rows } = await c.query(`SELECT
        (SELECT count(*) FROM reports WHERE status='open')::int AS open_reports,
        (SELECT count(*) FROM trees WHERE deleted_at IS NULL)::int AS trees,
        (SELECT count(*) FROM users WHERE deleted_at IS NULL)::int AS users,
        (SELECT count(*) FROM trees WHERE created_at > now()-interval '7 days')::int AS trees_week,
        (SELECT count(*) FROM account_deletion_requests WHERE status='scheduled')::int AS pending_deletions`);
      return rows[0];
    }),
  );

  app.get('/v1/admin/reports', { preHandler: requireStaff }, async (req) => {
    const q = parse(
      z.object({
        status: z.enum(['open', 'reviewing', 'actioned', 'dismissed']).default('open'),
        limit: z.coerce.number().min(1).max(100).default(50),
      }),
      req.query,
    );
    return runAs(req.principal, async (c) => {
      const { rows } = await c.query(
        `SELECT r.id, r.target_type, r.target_id, r.reason, r.details, r.status,
                r.created_at, u.username AS reporter
           FROM reports r LEFT JOIN users u ON u.id = r.reporter_id
          WHERE r.status = $1 ORDER BY r.created_at DESC LIMIT $2`,
        [q.status, q.limit],
      );
      return { items: rows };
    });
  });

  app.post('/v1/admin/reports/:id/resolve', { preHandler: requireStaff }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    const b = parse(
      z.object({
        action: z.enum(['hide', 'remove', 'warn', 'ban', 'dismiss', 'restore']),
        notes: z.string().max(1000).optional(),
      }),
      req.body,
    );
    return runAs(req.principal, async (c) => {
      const rep = await c.query(
        `SELECT target_type, target_id FROM reports WHERE id = $1`, [id]);
      if (!rep.rows[0]) throw notFound('Report not found');
      const { target_type, target_id } = rep.rows[0];
      await applyAction(c, target_type, target_id, b.action);
      await c.query(
        `INSERT INTO moderation_actions
           (moderator_id, report_id, target_type, target_id, action, notes)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [req.principal.userId, id, target_type, target_id, b.action, b.notes ?? null],
      );
      const status = b.action === 'dismiss' ? 'dismissed' : 'actioned';
      await c.query(
        `UPDATE reports SET status=$2, resolved_at=now(), resolver_id=$3 WHERE id=$1`,
        [id, status, req.principal.userId],
      );
      await c.query(
        `INSERT INTO audit_log (actor_id, action, entity, entity_id, metadata)
         VALUES ($1,$2,$3,$4,$5)`,
        [req.principal.userId, `moderation.${b.action}`, target_type, target_id,
         JSON.stringify({ report: id })],
      );
      return { ok: true, status };
    });
  });
}
