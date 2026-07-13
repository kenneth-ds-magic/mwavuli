import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { runAs } from '../db';
import { parse } from '../lib/validate';
import { publicUrl, mediaBaseFromRequest } from '../services/storage';
import { computeStreak, levelProgress } from '../services/gamification';
import { fetchEnrichedActivity } from '../services/activity';

function mapUserCard(row: Record<string, unknown>, mediaBase?: string) {
  const avatarKey = row.avatar_url as string | null | undefined;
  return {
    id: row.id,
    username: row.username,
    displayName: row.display_name,
    avatarUrl: avatarKey ? publicUrl(avatarKey, mediaBase) : null,
    bio: row.bio ?? null,
    logCount: row.log_count == null ? undefined : Number(row.log_count),
    isFollowing: Boolean(row.is_following),
  };
}

async function fetchLeaderboard(
  c: Parameters<Parameters<typeof runAs>[1]>[0],
  uid: string | undefined,
  limit: number,
  mediaBase?: string,
) {
  const { rows } = await c.query(
    `SELECT u.id, u.username, u.display_name, u.avatar_url, count(t.id)::int AS logs
       FROM users u
       JOIN trees t ON t.owner_id = u.id
      WHERE t.created_at >= now() - interval '7 days'
        AND t.deleted_at IS NULL
        AND u.deleted_at IS NULL
      GROUP BY u.id
      ORDER BY logs DESC, u.display_name
      LIMIT $1`,
    [limit],
  );
  return rows.map((r, i) => ({
    rank: i + 1,
    userId: r.id,
    username: r.username,
    displayName: r.display_name,
    avatarUrl: r.avatar_url ? publicUrl(r.avatar_url as string, mediaBase) : null,
    logCount: r.logs as number,
    isMe: uid != null && r.id === uid,
  }));
}

async function fetchBadges(
  c: Parameters<Parameters<typeof runAs>[1]>[0],
  uid: string | undefined,
) {
  const { rows } = await c.query(
    `SELECT b.code, b.name, b.description, b.icon,
            (ub.user_id IS NOT NULL) AS earned,
            ub.awarded_at
       FROM badges b
       LEFT JOIN user_badges ub
         ON ub.badge_id = b.id AND ub.user_id = $1
      ORDER BY earned DESC, b.name`,
    [uid ?? null],
  );
  return rows.map((r) => ({
    code: r.code,
    name: r.name,
    description: r.description,
    icon: r.icon,
    earned: Boolean(r.earned),
    awardedAt: r.awarded_at ?? null,
  }));
}

async function fetchSuggestions(
  c: Parameters<Parameters<typeof runAs>[1]>[0],
  uid: string,
  limit: number,
  mediaBase?: string,
) {
  const { rows } = await c.query(
    `SELECT u.id, u.username, u.display_name, u.avatar_url, u.bio,
            count(t.id)::int AS log_count,
            false AS is_following
       FROM users u
       JOIN trees t ON t.owner_id = u.id
      WHERE u.id <> $1
        AND u.deleted_at IS NULL
        AND t.deleted_at IS NULL
        AND t.created_at >= now() - interval '30 days'
        AND u.id NOT IN (
          SELECT followee_id FROM follows WHERE follower_id = $1
        )
      GROUP BY u.id
      ORDER BY log_count DESC, u.display_name
      LIMIT $2`,
    [uid, limit],
  );
  return rows.map((r) => mapUserCard(r, mediaBase));
}

export async function communityRoutes(app: FastifyInstance) {
  app.get('/v1/community', async (req) =>
    runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const uid = req.principal.userId ?? undefined;
      const q = parse(
        z.object({
          leaderboardLimit: z.coerce.number().min(1).max(50).default(10),
        }),
        req.query,
      );
      const limit = q.leaderboardLimit ?? 10;

      let profile: Record<string, unknown> | null = null;
      const userId = req.principal.userId;
      if (userId) {
        const { rows } = await c.query(
          `SELECT points,
                  (SELECT count(*)::int FROM trees WHERE owner_id = $1 AND deleted_at IS NULL) AS trees,
                  (SELECT count(DISTINCT species_id)::int FROM trees
                    WHERE owner_id = $1 AND deleted_at IS NULL) AS species,
                  (SELECT count(*)::int FROM follows WHERE followee_id = $1) AS followers
             FROM users WHERE id = $1 AND deleted_at IS NULL`,
          [userId],
        );
        if (rows[0]) {
          const points = rows[0].points as number;
          const prog = levelProgress(points);
          const streakDays = await computeStreak(c, userId);
          profile = {
            points,
            level: prog.level,
            levelName: prog.levelName,
            treeCount: rows[0].trees,
            speciesCount: rows[0].species,
            followers: rows[0].followers,
            gamification: {
              progress: prog.progress,
              pointsToNextLevel: prog.pointsToNextLevel,
              nextLevel: prog.nextLevel,
              streakDays,
            },
          };
        }
      }

      // Activity lives on GET /v1/activity (paginated) — not duplicated here.
      const [badges, leaderboard, suggestions] = await Promise.all([
        fetchBadges(c, uid),
        fetchLeaderboard(c, uid, limit, mediaBase),
        userId ? fetchSuggestions(c, userId, 12, mediaBase) : Promise.resolve([]),
      ]);

      const earnedCount = badges.filter((b) => b.earned).length;

      return {
        profile,
        badges,
        earnedBadgeCount: earnedCount,
        totalBadgeCount: badges.length,
        leaderboard: {
          period: 'week',
          items: leaderboard,
          hasMore: leaderboard.length >= limit,
        },
        suggestions,
      };
    }),
  );

  app.get('/v1/users/search', async (req) =>
    runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const q = parse(
        z.object({
          q: z.string().min(2).max(80),
          limit: z.coerce.number().min(1).max(30).default(20),
        }),
        req.query,
      );
      const like = `%${q.q}%`;
      const uid = req.principal.userId ?? undefined;
      const { rows } = await c.query(
        `SELECT u.id, u.username, u.display_name, u.avatar_url, u.bio,
                ($2::uuid IS NOT NULL AND EXISTS (
                  SELECT 1 FROM follows f
                   WHERE f.follower_id = $2 AND f.followee_id = u.id
                )) AS is_following
           FROM users u
          WHERE u.deleted_at IS NULL
            AND ($2::uuid IS NULL OR u.id <> $2)
            AND (u.username ILIKE $1 OR u.display_name ILIKE $1)
          ORDER BY u.display_name
          LIMIT $3`,
        [like, uid ?? null, q.limit],
      );
      return {
        items: rows.map((r) => mapUserCard(r, mediaBase)),
      };
    }),
  );
}
