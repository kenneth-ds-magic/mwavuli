import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { runAs } from '../db';
import { parse } from '../lib/validate';
import { mediaBaseFromRequest } from '../services/storage';
import { TREE_COLS, TREE_PHOTO_COLS, mapTree } from './trees';
import { fetchEnrichedActivity } from '../services/activity';

async function countPublicTrees(
  c: Parameters<Parameters<typeof runAs>[1]>[0],
  extraWhere: string,
  params: unknown[],
) {
  const { rows } = await c.query(
    `SELECT count(*)::int AS trees
       FROM trees t
       JOIN users u ON u.id = t.owner_id
      WHERE t.status = 'active' AND t.visibility = 'public' AND t.deleted_at IS NULL
        ${extraWhere}`,
    params,
  );
  return (rows[0]?.trees as number) ?? 0;
}

export async function exploreRoutes(app: FastifyInstance) {
  app.get('/v1/explore', async (req) =>
    runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const q = parse(
        z.object({
          lat: z.coerce.number().min(-90).max(90).optional(),
          lng: z.coerce.number().min(-180).max(180).optional(),
          radiusM: z.coerce.number().min(100).max(100_000).default(50_000),
          trendingLimit: z.coerce.number().min(1).max(20).default(8),
          activityLimit: z.coerce.number().min(1).max(20).default(8),
        }),
        req.query,
      );

      const treeCount = await countPublicTrees(c, '', []);

      let nearbyCount: number | null = null;
      if (q.lat != null && q.lng != null) {
        const nearParams: unknown[] = [q.lng, q.lat, q.radiusM];
        nearbyCount = await countPublicTrees(
          c,
          `AND ST_DWithin(t.fuzzy_geom, ST_SetSRID(ST_MakePoint($1,$2),4326)::geography, $3)`,
          nearParams,
        );
      }

      let locationLabel: string | null = null;
      const uid = req.principal.userId;
      if (uid) {
        const { rows } = await c.query(
          `SELECT location_label FROM users WHERE id = $1 AND deleted_at IS NULL`,
          [uid],
        );
        locationLabel = (rows[0]?.location_label as string | null) ?? null;
      }

      const { rows: trendingRows } = await c.query(
        `WITH species_counts AS (
           SELECT common_name, count(*)::int AS tree_count
             FROM trees
            WHERE status = 'active' AND visibility = 'public' AND deleted_at IS NULL
            GROUP BY common_name
            ORDER BY count(*) DESC, common_name
            LIMIT $1
         )
         SELECT sc.common_name, sc.tree_count,
                ${TREE_COLS},
                ${TREE_PHOTO_COLS}
           FROM species_counts sc
           JOIN LATERAL (
             SELECT id
               FROM trees
              WHERE common_name = sc.common_name
                AND status = 'active'
                AND visibility = 'public'
                AND deleted_at IS NULL
              ORDER BY created_at DESC
              LIMIT 1
           ) pick ON true
           JOIN trees t ON t.id = pick.id
           JOIN users u ON u.id = t.owner_id
          ORDER BY sc.tree_count DESC, sc.common_name`,
        [q.trendingLimit],
      );

      const activityRows = await fetchEnrichedActivity(c, {
        limit: q.activityLimit ?? 8,
      });

      return {
        treeCount,
        nearbyCount,
        locationLabel,
        trendingSpecies: trendingRows.map((r) => ({
          commonName: r.common_name as string,
          treeCount: r.tree_count as number,
          tree: mapTree(r, mediaBase),
        })),
        recentActivity: activityRows,
      };
    }),
  );
}
