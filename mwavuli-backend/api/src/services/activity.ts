import type { PoolClient } from 'pg';

/** Shared enriched activity query + mapper for /v1/activity, community, explore. */
export async function fetchEnrichedActivity(
  c: PoolClient,
  opts: { limit: number; before?: string },
) {
  const params: unknown[] = [opts.limit];
  let where = '';
  if (opts.before) {
    params.push(opts.before);
    where = ` WHERE a.created_at < $${params.length}`;
  }

  const { rows } = await c.query(
    `SELECT a.id, a.verb, a.object_type, a.object_id, a.metadata, a.created_at,
            u.id AS actor_id, u.display_name AS actor,
            t.common_name AS tree_name,
            ou.display_name AS object_user_name,
            coalesce(a.metadata->>'name', b.name) AS badge_name
       FROM activity a
       JOIN users u ON u.id = a.actor_id
       LEFT JOIN trees t
         ON a.object_type = 'tree' AND t.id = a.object_id
       LEFT JOIN users ou
         ON a.object_type = 'user' AND ou.id = a.object_id
       LEFT JOIN badges b
         ON a.object_type = 'badge' AND b.id = a.object_id
      ${where}
      ORDER BY a.created_at DESC
      LIMIT $1`,
    params,
  );

  return rows.map(mapActivityRow);
}

export function mapActivityRow(r: Record<string, unknown>) {
  const meta = {
    ...((r.metadata as Record<string, unknown> | null) ?? {}),
  };
  if (r.tree_name && meta.commonName == null) {
    meta.commonName = r.tree_name;
  }
  if (r.object_user_name && meta.displayName == null) {
    meta.displayName = r.object_user_name;
  }
  if (r.badge_name && meta.name == null) {
    meta.name = r.badge_name;
  }

  return {
    id: String(r.id),
    verb: r.verb,
    objectType: r.object_type,
    objectId: r.object_id,
    metadata: meta,
    createdAt: r.created_at,
    actorId: r.actor_id == null ? null : String(r.actor_id),
    actorDisplayName: r.actor,
  };
}
