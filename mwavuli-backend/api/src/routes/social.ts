import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { runAs } from '../db';
import { badRequest, notFound } from '../lib/errors';
import { parse } from '../lib/validate';
import { requireAuth } from '../auth/plugin';
import { publicUrl, mediaBaseFromRequest } from '../services/storage';
import { fetchEnrichedActivity } from '../services/activity';
import { TREE_COLS, TREE_PHOTO_COLS, mapTree } from './trees';
import { levelFromPoints, levelName } from '../services/gamification';

export async function socialRoutes(app: FastifyInstance) {
  app.post('/v1/users/:id/follow', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    if (id === req.principal.userId) throw badRequest('You cannot follow yourself.');
    return runAs(req.principal, async (c) => {
      await c.query(
        `INSERT INTO follows (follower_id, followee_id) VALUES ($1,$2)
         ON CONFLICT DO NOTHING`,
        [req.principal.userId, id],
      );
      await c.query(
        `INSERT INTO activity (actor_id, verb, object_type, object_id)
         VALUES ($1,'followed','user',$2)`,
        [req.principal.userId, id],
      );
      return { following: true };
    });
  });

  app.delete('/v1/users/:id/follow', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      await c.query(
        'DELETE FROM follows WHERE follower_id=$1 AND followee_id=$2',
        [req.principal.userId, id],
      );
      return { following: false };
    });
  });

  app.get('/v1/users/:id', async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const uid = req.principal.userId ?? null;
      const { rows } = await c.query(
        `SELECT u.id, u.username, u.display_name, u.avatar_url, u.bio, u.points, u.level,
                count(DISTINCT t.id)::int AS log_count,
                (SELECT count(*)::int FROM follows f WHERE f.followee_id = u.id) AS followers,
                (SELECT count(*)::int FROM follows f WHERE f.follower_id = u.id) AS following,
                ($2::uuid IS NOT NULL AND EXISTS (
                  SELECT 1 FROM follows f
                   WHERE f.follower_id = $2 AND f.followee_id = u.id
                )) AS is_following
           FROM users u
           LEFT JOIN trees t ON t.owner_id = u.id AND t.deleted_at IS NULL
            AND t.visibility = 'public' AND t.status = 'active'
          WHERE u.id = $1 AND u.deleted_at IS NULL
          GROUP BY u.id`,
        [id, uid],
      );
      if (!rows[0]) throw notFound('User not found');
      const r = rows[0];
      const avatarKey = r.avatar_url as string | null | undefined;
      const points = (r.points as number) ?? 0;
      const level = (r.level as number) ?? levelFromPoints(points);

      const { rows: treeRows } = await c.query(
        `SELECT ${TREE_COLS},
                ${TREE_PHOTO_COLS}
           FROM trees t JOIN users u ON u.id = t.owner_id
          WHERE t.owner_id = $1
            AND t.deleted_at IS NULL
            AND t.visibility = 'public'
            AND t.status = 'active'
          ORDER BY t.created_at DESC
          LIMIT 12`,
        [id],
      );

      return {
        id: r.id,
        username: r.username,
        displayName: r.display_name,
        avatarUrl: avatarKey ? publicUrl(avatarKey, mediaBase) : null,
        bio: r.bio ?? null,
        logCount: Number(r.log_count),
        followers: Number(r.followers),
        following: Number(r.following),
        points,
        level,
        levelName: levelName(level),
        isFollowing: Boolean(r.is_following),
        isMe: uid != null && r.id === uid,
        trees: treeRows.map((t) => mapTree(t, mediaBase)),
      };
    });
  });

  app.get('/v1/leaderboard', async (req) => {
    const q = parse(
      z.object({
        limit: z.coerce.number().min(1).max(50).default(20),
        offset: z.coerce.number().min(0).max(500).default(0),
      }),
      req.query,
    );
    return runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const uid = req.principal.userId;
      const limit = q.limit ?? 20;
      const offset = q.offset ?? 0;
      const { rows } = await c.query(
        `SELECT u.id, u.username, u.display_name, u.avatar_url, count(t.id)::int AS logs
           FROM users u
           JOIN trees t ON t.owner_id = u.id
          WHERE t.created_at >= now() - interval '7 days'
            AND t.deleted_at IS NULL
            AND u.deleted_at IS NULL
          GROUP BY u.id
          ORDER BY logs DESC, u.display_name
          LIMIT $1 OFFSET $2`,
        [limit, offset],
      );
      return {
        period: 'week',
        offset,
        hasMore: rows.length >= limit,
        items: rows.map((r, i) => ({
          rank: offset + i + 1,
          userId: r.id,
          username: r.username,
          displayName: r.display_name,
          avatarUrl: r.avatar_url ? publicUrl(r.avatar_url as string, mediaBase) : null,
          logCount: r.logs as number,
          isMe: uid != null && r.id === uid,
        })),
      };
    });
  });

  app.get('/v1/activity', async (req) => {
    const q = parse(
      z.object({
        limit: z.coerce.number().min(1).max(50).default(20),
        before: z.string().datetime().optional(),
      }),
      req.query,
    );
    return runAs(req.principal, async (c) => {
      const items = await fetchEnrichedActivity(c, {
        limit: q.limit ?? 20,
        before: q.before,
      });
      return {
        items,
        hasMore: items.length >= (q.limit ?? 20),
      };
    });
  });
}
