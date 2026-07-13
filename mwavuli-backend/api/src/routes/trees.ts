import { randomUUID } from 'node:crypto';
import { FastifyInstance } from 'fastify';
import { PoolClient } from 'pg';
import { z } from 'zod';
import { runAs } from '../db';
import { forbidden, notFound, badRequest } from '../lib/errors';
import { parse } from '../lib/validate';
import { requireAuth } from '../auth/plugin';
import { setTreeLocation } from '../services/location';
import { presignUpload, publicUrl, mediaBaseFromRequest, putPrivateObject } from '../services/storage';
import { processTreePhoto, isValidJpeg } from '../services/image-process';
import { levelFromPoints, levelName } from '../services/gamification';
import { config } from '../config';

const CreateTree = z.object({
  commonName: z.string().min(1).max(120),
  scientificName: z.string().max(160).optional(),
  speciesId: z.string().uuid().optional(),
  health: z.enum(['healthy', 'stressed', 'dead', 'unknown']).default('unknown'),
  heightM: z.number().min(0).max(150).optional(),
  girthM: z.number().min(0).max(50).optional(),
  ageEstimate: z.string().max(40).optional(),
  description: z.string().max(4000).optional(),
  features: z.array(z.string().max(40)).max(20).default([]),
  confidence: z.number().int().min(0).max(100).optional(),
  visibility: z.enum(['public', 'followers', 'private']).default('public'),
  isFuzzy: z.boolean().default(true),
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
  accuracyM: z.number().min(0).optional(),
  photos: z
    .array(z.object({
      organ: z.enum(['whole', 'bark', 'leaf', 'flower', 'fruit']),
      contentType: z.string().default('image/jpeg'),
    }))
    .max(8)
    .default([]),
});

export function mapTree(row: Record<string, any>, mediaBase?: string) {
  const thumbKey = row.thumb_url as string | null | undefined;
  return {
    id: row.id,
    contributor: row.contributor ?? null,
    ownerId: row.owner_id,
    commonName: row.common_name,
    scientificName: row.scientific_name,
    heightM: row.height_m == null ? null : Number(row.height_m),
    girthM: row.girth_m == null ? null : Number(row.girth_m),
    ageEstimate: row.age_estimate,
    health: row.health,
    features: row.features ?? [],
    confidence: row.confidence,
    verified: row.verified,
    visibility: row.visibility,
    isFuzzy: row.is_fuzzy,
    likeCount: row.like_count ?? 0,
    commentCount: row.comment_count ?? 0,
    description: row.description ?? '',
    createdAt: row.created_at,
    // PUBLIC point only. Exact coords are never in this payload.
    fuzzyLocation:
      row.fuzzy_lat == null ? null : { lat: row.fuzzy_lat, lng: row.fuzzy_lng },
    thumbUrl: thumbKey ? publicUrl(thumbKey, mediaBase) : null,
    photoStatus: (row.photo_status as string | null | undefined) ?? null,
  };
}

/** Latest processed thumb + overall photo pipeline status for list cards. */
export const TREE_PHOTO_COLS = `
  (SELECT tp.thumb_url FROM tree_photos tp
    WHERE tp.tree_id = t.id AND tp.status = 'processed'
    ORDER BY tp.position LIMIT 1) AS thumb_url,
  (SELECT tp.status FROM tree_photos tp
    WHERE tp.tree_id = t.id
    ORDER BY CASE tp.status
      WHEN 'processed' THEN 0
      WHEN 'pending' THEN 1
      ELSE 2 END, tp.position
    LIMIT 1) AS photo_status`;

export const TREE_COLS = `
  t.id, t.owner_id, u.display_name AS contributor, t.common_name, t.scientific_name,
  t.height_m, t.girth_m, t.age_estimate, t.health, t.features, t.confidence,
  t.verified, t.visibility, t.is_fuzzy, t.like_count, t.comment_count,
  t.description, t.created_at,
  ST_Y(t.fuzzy_geom::geometry) AS fuzzy_lat, ST_X(t.fuzzy_geom::geometry) AS fuzzy_lng`;

const FeedFilter = z.enum(['all', 'near', 'oak', 'flowering', 'autumn', 'rare', 'native']);

export function appendFeedFilters(
  where: string,
  params: unknown[],
  opts: {
    q?: string;
    filter?: z.infer<typeof FeedFilter>;
    lat?: number;
    lng?: number;
    radiusM?: number;
  },
): string {
  const q = opts.q?.trim();
  if (q) {
    params.push(`%${q}%`);
    const n = params.length;
    where += ` AND (t.common_name ILIKE $${n} OR t.scientific_name ILIKE $${n} OR u.display_name ILIKE $${n})`;
  }

  switch (opts.filter ?? 'all') {
    case 'near':
      if (opts.lat != null && opts.lng != null) {
        params.push(opts.lng, opts.lat, opts.radiusM ?? 50_000);
        const n = params.length;
        where += ` AND ST_DWithin(t.fuzzy_geom, ST_SetSRID(ST_MakePoint($${n - 2},$${n - 1}),4326)::geography, $${n})`;
      }
      break;
    case 'oak':
      where += ` AND (t.common_name ILIKE '%oak%' OR t.scientific_name ILIKE '%quercus%')`;
      break;
    case 'flowering':
      where += ` AND (t.common_name ILIKE '%cherry%' OR t.common_name ILIKE '%blossom%' OR t.common_name ILIKE '%jacaranda%' OR EXISTS (SELECT 1 FROM unnest(t.features) f WHERE f ILIKE '%flower%'))`;
      break;
    case 'autumn':
      where += ` AND (t.common_name ILIKE '%maple%' OR t.common_name ILIKE '%birch%')`;
      break;
    case 'rare':
      where += ` AND EXISTS (SELECT 1 FROM unnest(t.features) f WHERE f ILIKE '%rare%')`;
      break;
    case 'native':
      where += ` AND EXISTS (SELECT 1 FROM unnest(t.features) f WHERE f ILIKE '%native%')`;
      break;
    default:
      break;
  }
  return where;
}

export async function fetchPublicFeed(
  c: PoolClient,
  opts: {
    limit: number;
    before?: string;
    bbox?: string;
    q?: string;
    filter?: z.infer<typeof FeedFilter>;
    lat?: number;
    lng?: number;
    radiusM?: number;
    /** When set, include the viewer's own trees and followers-only trees. */
    viewerUserId?: string | null;
  },
  mediaBase?: string,
) {
  const params: unknown[] = [opts.limit];
  let where = `t.status='active' AND t.deleted_at IS NULL AND (t.visibility = 'public'`;
  if (opts.viewerUserId) {
    params.push(opts.viewerUserId);
    const n = params.length;
    where += ` OR t.owner_id = $${n}
      OR (t.visibility = 'followers' AND EXISTS (
            SELECT 1 FROM follows f
             WHERE f.followee_id = t.owner_id AND f.follower_id = $${n}))`;
  }
  where += `)`;
  if (opts.before) {
    params.push(opts.before);
    where += ` AND t.created_at < $${params.length}`;
  }
  if (opts.bbox) {
    const [a, b2, cc, d] = opts.bbox.split(',').map(Number);
    params.push(a, b2, cc, d);
    const n = params.length;
    where += ` AND ST_Intersects(t.fuzzy_geom, ST_MakeEnvelope($${n - 3},$${n - 2},$${n - 1},$${n},4326)::geography)`;
  }
  where = appendFeedFilters(where, params, opts);

  const { rows } = await c.query(
    `SELECT ${TREE_COLS},
            ${TREE_PHOTO_COLS}
       FROM trees t JOIN users u ON u.id = t.owner_id
      WHERE ${where} ORDER BY t.created_at DESC LIMIT $1`,
    params,
  );
  return rows.map((r) => mapTree(r, mediaBase));
}

export async function treeRoutes(app: FastifyInstance) {
  // --- Create ---
  app.post('/v1/trees', { preHandler: requireAuth }, async (req) => {
    const b = parse(CreateTree, req.body);
    const p = req.principal;
    const mediaBase = mediaBaseFromRequest(req);
    return runAs(p, async (c: PoolClient) => {
      const ins = await c.query(
        `INSERT INTO trees
           (owner_id, species_id, common_name, scientific_name, health, height_m,
            girth_m, age_estimate, description, features, confidence, visibility,
            is_fuzzy, fuzzy_geom)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,
                 ST_SetSRID(ST_MakePoint($15,$14),4326)::geography)
         RETURNING id`,
        [
          p.userId, b.speciesId ?? null, b.commonName, b.scientificName ?? null,
          b.health, b.heightM ?? null, b.girthM ?? null, b.ageEstimate ?? null,
          b.description ?? null, b.features, b.confidence ?? null, b.visibility,
          b.isFuzzy, b.lat, b.lng,
        ],
      );
      const treeId = ins.rows[0].id as string;

      // Store exact point (private) + refresh the public fuzzy point.
      await setTreeLocation(c, treeId, b.lat, b.lng, b.accuracyM ?? null, b.isFuzzy ?? true);

      // Presigned uploads: client PUTs originals straight to the private bucket.
      const uploads: Array<{ photoId: string; uploadUrl: string; key: string }> = [];
      for (let i = 0; i < (b.photos ?? []).length; i++) {
        const ph = (b.photos ?? [])[i];
        const key = `uploads/${p.userId}/${treeId}/${randomUUID()}.jpg`;
        const { rows } = await c.query(
          `INSERT INTO tree_photos (tree_id, organ, storage_key, position, status)
           VALUES ($1,$2,$3,$4,'pending') RETURNING id`,
          [treeId, ph.organ, key, i],
        );
        uploads.push({
          photoId: rows[0].id,
          uploadUrl: await presignUpload(key, ph.contentType ?? 'image/jpeg', req),
          key,
        });
      }

      // Gamification.
      await c.query(
        `INSERT INTO points_ledger (user_id, delta, reason, tree_id)
         VALUES ($1, 10, 'log_tree', $2)`,
        [p.userId, treeId],
      );
      await c.query(
        `INSERT INTO activity (actor_id, verb, object_type, object_id, metadata)
         VALUES ($1, 'logged_tree', 'tree', $2, jsonb_build_object('commonName', $3::text))`,
        [p.userId, treeId, b.commonName],
      );

      const { rows } = await c.query(
        `SELECT ${TREE_COLS} FROM trees t JOIN users u ON u.id = t.owner_id
          WHERE t.id = $1`,
        [treeId],
      );

      const { rows: userRows } = await c.query(
        `SELECT points FROM users WHERE id = $1`,
        [p.userId],
      );
      const totalPoints = (userRows[0]?.points as number) ?? 0;
      const level = levelFromPoints(totalPoints);

      return {
        tree: mapTree(rows[0], mediaBase),
        uploads,
        rewards: {
          pointsEarned: 10,
          totalPoints,
          level,
          levelName: levelName(level),
        },
      };
    });
  });

  // --- Public feed (optionally within a map bbox) ---
  app.get(
    '/v1/feed',
    { config: { rateLimit: { max: 300, timeWindow: 60_000 } } },
    async (req) => {
    const q = parse(
      z.object({
        limit: z.coerce.number().min(1).max(100).default(50),
        before: z.string().datetime().optional(),
        bbox: z.string().optional(),
        search: z.string().max(80).optional(),
        filter: FeedFilter.default('all'),
        lat: z.coerce.number().min(-90).max(90).optional(),
        lng: z.coerce.number().min(-180).max(180).optional(),
        radiusM: z.coerce.number().min(100).max(100_000).default(50_000),
      }),
      req.query,
    );
    return runAs(req.principal, async (c) => ({
      items: await fetchPublicFeed(c, {
        limit: q.limit ?? 50,
        before: q.before,
        bbox: q.bbox,
        q: q.search,
        filter: q.filter,
        lat: q.lat,
        lng: q.lng,
        radiusM: q.radiusM,
        viewerUserId:
          req.principal?.role !== 'anon' && req.principal?.userId
            ? req.principal.userId
            : null,
      }, mediaBaseFromRequest(req)),
    }));
  });

  // --- Single tree (+ photos) ---
  app.get('/v1/trees/:id', async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      const mediaBase = mediaBaseFromRequest(req);
      const { rows } = await c.query(
        `SELECT ${TREE_COLS} FROM trees t JOIN users u ON u.id = t.owner_id
          WHERE t.id = $1`,
        [id],
      );
      if (!rows[0]) throw notFound('Tree not found');
      const photos = await c.query(
        `SELECT id, organ, public_url, thumb_url, status
           FROM tree_photos WHERE tree_id = $1 AND status = 'processed'
          ORDER BY position`,
        [id],
      );
      let saved = false;
      let verificationCount = 0;
      let userVerified = false;
      if (req.principal.userId) {
        const savedRow = await c.query(
          `SELECT 1 FROM saved_trees WHERE user_id = $1 AND tree_id = $2`,
          [req.principal.userId, id],
        );
        saved = (savedRow.rowCount ?? 0) > 0;
        const v = await c.query(
          `SELECT count(*)::int AS n,
                  bool_or(user_id = $2) AS mine
             FROM tree_verifications WHERE tree_id = $1`,
          [id, req.principal.userId],
        );
        verificationCount = (v.rows[0]?.n as number) ?? 0;
        userVerified = Boolean(v.rows[0]?.mine);
      } else {
        const v = await c.query(
          `SELECT count(*)::int AS n FROM tree_verifications WHERE tree_id = $1`,
          [id],
        );
        verificationCount = (v.rows[0]?.n as number) ?? 0;
      }
      return {
        tree: mapTree(rows[0], mediaBase),
        photos: photos.rows.map((r) => ({
          id: r.id, organ: r.organ,
          url: r.public_url && publicUrl(r.public_url, mediaBase),
          thumbUrl: r.thumb_url && publicUrl(r.thumb_url, mediaBase),
        })),
        saved,
        verificationCount,
        userVerified,
        verificationsRequired: config.VERIFY_VOTES_REQUIRED,
      };
    });
  });

  // --- Community ID verification ---
  app.post('/v1/trees/:id/verify', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    const uid = req.principal.userId!;
    return runAs(req.principal, async (c) => {
      const { rows } = await c.query(
        `SELECT owner_id, verified, visibility FROM trees
          WHERE id = $1 AND deleted_at IS NULL`,
        [id],
      );
      if (!rows[0]) throw notFound('Tree not found');
      if (rows[0].owner_id === uid) {
        throw badRequest('You cannot verify your own tree.');
      }
      if (rows[0].visibility === 'private') {
        throw forbidden('Private trees cannot be community-verified.');
      }
      if (rows[0].verified) {
        const cnt = await c.query(
          `SELECT count(*)::int AS n FROM tree_verifications WHERE tree_id = $1`,
          [id],
        );
        return {
          verified: true,
          verificationCount: (cnt.rows[0]?.n as number) ?? 0,
          userVerified: true,
        };
      }

      await c.query(
        `INSERT INTO tree_verifications (tree_id, user_id) VALUES ($1, $2)
         ON CONFLICT DO NOTHING`,
        [id, uid],
      );

      const { rows: cntRows } = await c.query(
        `SELECT count(*)::int AS n FROM tree_verifications WHERE tree_id = $1`,
        [id],
      );
      const verificationCount = (cntRows[0]?.n as number) ?? 0;
      let verified = false;

      if (verificationCount >= config.VERIFY_VOTES_REQUIRED) {
        await c.query(`UPDATE trees SET verified = true WHERE id = $1`, [id]);
        verified = true;
        await c.query(
          `INSERT INTO activity (actor_id, verb, object_type, object_id)
           VALUES ($1, 'verified_id', 'tree', $2)`,
          [uid, id],
        );
        await c.query(
          `INSERT INTO points_ledger (user_id, delta, reason, tree_id)
           VALUES ($1, 5, 'id_verified', $2)`,
          [rows[0].owner_id, id],
        );
      }

      return { verified, verificationCount, userVerified: true };
    });
  });

  // --- Upload photo bytes through the API (reliable on emulators / USB debug) ---
  app.put(
    '/v1/photos/:id/upload',
    {
      preHandler: requireAuth,
      config: { rateLimit: { max: 40, timeWindow: 60_000 } },
    },
    async (req) => {
      const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
      const buffer = req.body as Buffer | undefined;
      if (!buffer?.length) throw badRequest('Empty image body');
      if (buffer.length > 12 * 1024 * 1024) throw badRequest('Image too large');
      if (!isValidJpeg(buffer)) throw badRequest('Invalid JPEG image');

      const contentType =
        (req.headers['content-type'] as string | undefined)?.split(';')[0] ??
        'image/jpeg';

      return runAs(req.principal, async (c) => {
        const { rows } = await c.query(
          `SELECT tp.storage_key, tp.status, t.owner_id
             FROM tree_photos tp
             JOIN trees t ON t.id = tp.tree_id
            WHERE tp.id = $1`,
          [id],
        );
        if (!rows[0]) throw notFound('Photo not found');
        if (
          rows[0].owner_id !== req.principal.userId &&
          req.principal.role !== 'admin'
        ) {
          throw forbidden('Not your photo');
        }

        const key = rows[0].storage_key as string;
        await putPrivateObject(key, buffer, contentType);

        if (rows[0].status !== 'processed') {
          const ok = await processTreePhoto(c, key);
          if (!ok) {
            return { uploaded: true, processed: false };
          }
        }
        return { uploaded: true, processed: true };
      });
    },
  );

  // --- Trigger image processing after client upload ---
  app.post('/v1/photos/:id/process', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      const { rows } = await c.query(
        `SELECT tp.storage_key, tp.status, t.owner_id
           FROM tree_photos tp
           JOIN trees t ON t.id = tp.tree_id
          WHERE tp.id = $1`,
        [id],
      );
      if (!rows[0]) throw notFound('Photo not found');
      if (rows[0].owner_id !== req.principal.userId && req.principal.role !== 'admin') {
        throw forbidden('Not your photo');
      }
      if (rows[0].status === 'processed') {
        return { processed: true };
      }
      try {
        await processTreePhoto(c, rows[0].storage_key as string);
        return { processed: true };
      } catch (e) {
        req.log.warn({ err: e, photoId: id }, 'photo process failed');
        return { processed: false };
      }
    });
  });

  // --- Exact location (owner/staff only; AUDITED) ---
  app.get('/v1/trees/:id/exact-location',
    { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      // RLS on tree_exact_locations decides whether this returns a row.
      const { rows } = await c.query(
        `SELECT ST_Y(exact_geom::geometry) AS lat, ST_X(exact_geom::geometry) AS lng,
                accuracy_m
           FROM tree_exact_locations WHERE tree_id = $1`,
        [id],
      );
      if (!rows[0]) throw forbidden('You may not view exact coordinates for this tree.');
      await c.query(
        `INSERT INTO audit_log (actor_id, action, entity, entity_id, ip, user_agent)
         VALUES ($1,'read_exact_location','tree',$2,$3,$4)`,
        [req.principal.userId, id, req.ip, req.headers['user-agent'] ?? null],
      );
      return { lat: rows[0].lat, lng: rows[0].lng, accuracyM: rows[0].accuracy_m };
    });
  });

  // --- Like / unlike ---
  app.post('/v1/trees/:id/like', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      await c.query(
        `INSERT INTO likes (tree_id, user_id) VALUES ($1,$2)
         ON CONFLICT DO NOTHING`,
        [id, req.principal.userId],
      );
      const { rows } = await c.query('SELECT like_count FROM trees WHERE id = $1', [id]);
      return { liked: true, likeCount: rows[0]?.like_count ?? 0 };
    });
  });

  app.delete('/v1/trees/:id/like', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      await c.query('DELETE FROM likes WHERE tree_id = $1 AND user_id = $2', [
        id, req.principal.userId,
      ]);
      const { rows } = await c.query('SELECT like_count FROM trees WHERE id = $1', [id]);
      return { liked: false, likeCount: rows[0]?.like_count ?? 0 };
    });
  });

  // --- Save / unsave (bookmark) ---
  app.post('/v1/trees/:id/save', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      const exists = await c.query(
        `SELECT 1 FROM trees WHERE id = $1 AND deleted_at IS NULL`,
        [id],
      );
      if (!exists.rowCount) throw notFound('Tree not found');
      await c.query(
        `INSERT INTO saved_trees (user_id, tree_id) VALUES ($1,$2)
         ON CONFLICT DO NOTHING`,
        [req.principal.userId, id],
      );
      return { saved: true };
    });
  });

  app.delete('/v1/trees/:id/save', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      await c.query(
        `DELETE FROM saved_trees WHERE user_id = $1 AND tree_id = $2`,
        [req.principal.userId, id],
      );
      return { saved: false };
    });
  });

  // --- Soft delete (owner/staff via RLS) ---
  app.delete('/v1/trees/:id', { preHandler: requireAuth }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    return runAs(req.principal, async (c) => {
      const r = await c.query(
        `UPDATE trees SET deleted_at = now(), status = 'removed' WHERE id = $1`,
        [id],
      );
      if (!r.rowCount) throw notFound('Tree not found');
      return { ok: true };
    });
  });
}
