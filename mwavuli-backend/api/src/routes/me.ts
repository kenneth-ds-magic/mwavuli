import { randomUUID } from 'node:crypto';
import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { runAs } from '../db';
import { notFound } from '../lib/errors';
import { parse } from '../lib/validate';
import { requireAuth } from '../auth/plugin';
import { assembleExport, treesToCsv } from '../services/export';
import { presignUpload, publicUrl, mediaBaseFromRequest } from '../services/storage';
import { mapTree, TREE_COLS, TREE_PHOTO_COLS } from './trees';

import { levelFromPoints, levelName } from '../services/gamification';

const UpdateMe = z.object({
  displayName: z.string().min(1).max(80).optional(),
  bio: z.string().max(500).nullable().optional(),
  locationLabel: z.string().max(120).nullable().optional(),
});

function mapProfile(row: Record<string, unknown>, mediaBase?: string) {
  const points = (row.points as number | undefined) ?? 0;
  const level = levelFromPoints(points);
  const avatarKey = row.avatar_url as string | null | undefined;
  return {
    id: row.id,
    email: row.email,
    username: row.username,
    displayName: row.display_name,
    bio: row.bio,
    avatarUrl: avatarKey ? publicUrl(avatarKey, mediaBase) : null,
    role: row.role,
    points,
    level,
    levelName: levelName(level),
    locationLabel: row.location_label,
    createdAt: row.created_at,
  };
}

const AvatarUpload = z.object({
  contentType: z.string().default('image/jpeg'),
});

function mapSocialUser(row: Record<string, unknown>, mediaBase?: string) {
  const avatarKey = row.avatar_url as string | null | undefined;
  return {
    id: row.id,
    username: row.username,
    displayName: row.display_name,
    avatarUrl: avatarKey ? publicUrl(avatarKey, mediaBase) : null,
  };
}

function mapProfileTree(row: Record<string, unknown>, mediaBase?: string) {
  return mapTree(row, mediaBase);
}

export async function meRoutes(app: FastifyInstance) {
  // Profile, social counts, stats, badges, trees, and chart data.
  app.get('/v1/me', { preHandler: requireAuth }, async (req) =>
    runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const uid = req.principal.userId;
      const { rows } = await c.query(
        `SELECT id, email, username, display_name, bio, avatar_url, role,
                points, level, location_label, created_at
           FROM users WHERE id = $1 AND deleted_at IS NULL`,
        [uid],
      );
      if (!rows[0]) throw notFound('User not found');

      const social = await c.query(
        `SELECT
           (SELECT count(*)::int FROM follows WHERE follower_id = $1) AS following,
           (SELECT count(*)::int FROM follows WHERE followee_id = $1) AS followers`,
        [uid],
      );

      const stats = await c.query(
        `SELECT count(*)::int AS trees,
                count(DISTINCT species_id)::int AS species
           FROM trees WHERE owner_id = $1 AND deleted_at IS NULL`,
        [uid],
      );

      const badges = await c.query(
        `SELECT b.code, b.name, b.icon, ub.awarded_at
           FROM user_badges ub JOIN badges b ON b.id = ub.badge_id
          WHERE ub.user_id = $1
          ORDER BY ub.awarded_at DESC`,
        [uid],
      );

      const trees = await c.query(
        `SELECT ${TREE_COLS},
                ${TREE_PHOTO_COLS}
           FROM trees t JOIN users u ON u.id = t.owner_id
          WHERE t.owner_id = $1 AND t.deleted_at IS NULL
          ORDER BY t.created_at DESC LIMIT 50`,
        [uid],
      );

      const topSpecies = await c.query(
        `SELECT common_name, count(*)::int AS count
           FROM trees WHERE owner_id = $1 AND deleted_at IS NULL
          GROUP BY common_name ORDER BY count DESC LIMIT 5`,
        [uid],
      );

      const contributions = await c.query(
        `SELECT trim(to_char(m.month, 'Mon')) AS month,
                coalesce(c.count, 0)::int AS count
           FROM generate_series(
                  date_trunc('month', now()) - interval '5 months',
                  date_trunc('month', now()),
                  interval '1 month'
                ) AS m(month)
           LEFT JOIN (
                  SELECT date_trunc('month', created_at) AS month,
                         count(*)::int AS count
                    FROM trees
                   WHERE owner_id = $1 AND deleted_at IS NULL
                   GROUP BY date_trunc('month', created_at)
                ) c ON c.month = m.month
          ORDER BY m.month`,
        [uid],
      );

      return {
        profile: mapProfile(rows[0], mediaBase),
        social: {
          following: social.rows[0].following as number,
          followers: social.rows[0].followers as number,
        },
        stats: {
          trees: stats.rows[0].trees as number,
          species: stats.rows[0].species as number,
          points: rows[0].points as number,
        },
        badges: badges.rows.map((b) => ({
          code: b.code,
          name: b.name,
          icon: b.icon,
          awardedAt: b.awarded_at,
        })),
        trees: trees.rows.map((r) => mapProfileTree(r, mediaBase)),
        topSpecies: topSpecies.rows.map((s) => ({
          name: s.common_name as string,
          count: s.count as number,
        })),
        contributions: contributions.rows.map((m) => ({
          month: m.month as string,
          count: m.count as number,
        })),
      };
    }),
  );

  app.patch('/v1/me', { preHandler: requireAuth }, async (req) =>
    runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const b = parse(UpdateMe, req.body);
      const sets: string[] = [];
      const params: unknown[] = [];
      if (b.displayName !== undefined) {
        params.push(b.displayName);
        sets.push(`display_name = $${params.length}`);
      }
      if (b.bio !== undefined) {
        params.push(b.bio === '' ? null : b.bio);
        sets.push(`bio = $${params.length}`);
      }
      if (b.locationLabel !== undefined) {
        params.push(b.locationLabel === '' ? null : b.locationLabel);
        sets.push(`location_label = $${params.length}`);
      }
      if (!sets.length) return { profile: null };

      params.push(req.principal.userId);
      const { rows } = await c.query(
        `UPDATE users SET ${sets.join(', ')}, updated_at = now()
          WHERE id = $${params.length} AND deleted_at IS NULL
          RETURNING id, email, username, display_name, bio, avatar_url, role,
                    points, level, location_label, created_at`,
        params,
      );
      if (!rows[0]) throw notFound('User not found');
      return { profile: mapProfile(rows[0], mediaBase) };
    }),
  );

  app.get('/v1/me/following', { preHandler: requireAuth }, async (req) =>
    runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const { rows } = await c.query(
        `SELECT u.id, u.username, u.display_name, u.avatar_url
           FROM follows f JOIN users u ON u.id = f.followee_id
          WHERE f.follower_id = $1 AND u.deleted_at IS NULL
          ORDER BY f.created_at DESC`,
        [req.principal.userId],
      );
      return { items: rows.map((r) => mapSocialUser(r, mediaBase)) };
    }),
  );

  app.get('/v1/me/followers', { preHandler: requireAuth }, async (req) =>
    runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const { rows } = await c.query(
        `SELECT u.id, u.username, u.display_name, u.avatar_url
           FROM follows f JOIN users u ON u.id = f.follower_id
          WHERE f.followee_id = $1 AND u.deleted_at IS NULL
          ORDER BY f.created_at DESC`,
        [req.principal.userId],
      );
      return { items: rows.map((r) => mapSocialUser(r, mediaBase)) };
    }),
  );

  app.get('/v1/me/saved', { preHandler: requireAuth }, async (req) =>
    runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const { rows } = await c.query(
        `SELECT ${TREE_COLS},
                ${TREE_PHOTO_COLS}
           FROM saved_trees s
           JOIN trees t ON t.id = s.tree_id
           JOIN users u ON u.id = t.owner_id
          WHERE s.user_id = $1 AND t.deleted_at IS NULL
          ORDER BY s.created_at DESC
          LIMIT 100`,
        [req.principal.userId],
      );
      return { items: rows.map((r) => mapProfileTree(r, mediaBase)) };
    }),
  );

  app.get('/v1/me/reports', { preHandler: requireAuth }, async (req) =>
    runAs(req.principal, async (c) => {
      const { rows } = await c.query(
        `SELECT id, target_type, target_id, reason, status, created_at
           FROM reports
          WHERE reporter_id = $1
          ORDER BY created_at DESC
          LIMIT 50`,
        [req.principal.userId],
      );
      return {
        items: rows.map((r) => ({
          id: r.id,
          targetType: r.target_type,
          targetId: r.target_id,
          reason: r.reason,
          status: r.status,
          createdAt: r.created_at,
        })),
      };
    }),
  );

  // Presigned PUT for profile avatar. Pipeline writes public/{userId}/avatar/*_480.jpg
  // and sets users.avatar_url to the thumb key.
  app.post('/v1/me/avatar', { preHandler: requireAuth }, async (req) =>
    runAs(req.principal, async () => {
      const b = parse(AvatarUpload, req.body ?? {});
      const userId = req.principal.userId as string;
      const key = `uploads/${userId}/avatar/${randomUUID()}.jpg`;
      const contentType = b.contentType ?? 'image/jpeg';
      return {
        uploadUrl: await presignUpload(key, contentType, req),
        key,
      };
    }),
  );

  // GDPR Art. 20 — data export. Assembled inline for demoability; offload to
  // the worker + signed URL for large accounts. Rate-limited hard.
  app.post(
    '/v1/me/export',
    { preHandler: requireAuth, config: { rateLimit: { max: 3, timeWindow: 3_600_000 } } },
    async (req, reply) => {
      const { format } = parse(
        z.object({ format: z.enum(['json', 'csv']).default('json') }),
        req.query,
      );
      return runAs(req.principal, async (c) => {
        const data = await assembleExport(c, req.principal.userId as string);
        await c.query(
          `INSERT INTO data_export_jobs (user_id, format, status, completed_at)
           VALUES ($1,$2,'ready',now())`,
          [req.principal.userId, format],
        );
        await c.query(
          `INSERT INTO audit_log (actor_id, action, entity, entity_id)
           VALUES ($1,'export.request','user',$1)`,
          [req.principal.userId],
        );
        if (format === 'csv') {
          reply
            .header('content-type', 'text/csv')
            .header('content-disposition', 'attachment; filename="mwavuli-export.csv"');
          return treesToCsv(data.trees as Array<Record<string, unknown>>);
        }
        reply.header('content-disposition', 'attachment; filename="mwavuli-export.json"');
        return data;
      });
    },
  );

  // GDPR Art. 17 — schedule erasure (30-day grace). A worker performs the purge.
  app.post('/v1/me/deletion', { preHandler: requireAuth }, async (req) =>
    runAs(req.principal, async (c) => {
      const ins = await c.query(
        `INSERT INTO account_deletion_requests (user_id) VALUES ($1)
         ON CONFLICT (user_id) WHERE status = 'scheduled' DO NOTHING
         RETURNING id, purge_after, status`,
        [req.principal.userId],
      );
      let row = ins.rows[0];
      if (!row) {
        const ex = await c.query(
          `SELECT id, purge_after, status FROM account_deletion_requests
            WHERE user_id = $1 AND status = 'scheduled'`,
          [req.principal.userId],
        );
        row = ex.rows[0];
      }
      await c.query(
        `INSERT INTO audit_log (actor_id, action, entity, entity_id)
         VALUES ($1,'account.deletion_requested','user',$1)`,
        [req.principal.userId],
      );
      return { scheduled: row };
    }),
  );

  app.delete('/v1/me/deletion', { preHandler: requireAuth }, async (req) =>
    runAs(req.principal, async (c) => {
      await c.query(
        `UPDATE account_deletion_requests SET status='cancelled'
          WHERE user_id = $1 AND status = 'scheduled'`,
        [req.principal.userId],
      );
      return { ok: true };
    }),
  );
}
