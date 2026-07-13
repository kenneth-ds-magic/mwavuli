import { PoolClient } from 'pg';

/**
 * Assemble a complete export of a user's data (GDPR Art. 20). Runs inside the
 * user's own RLS transaction, so their EXACT coordinates ARE included (owners
 * may read their own precise data) while nothing belonging to others leaks.
 */
export async function assembleExport(c: PoolClient, userId: string) {
  const q = (sql: string, params: unknown[] = []) => c.query(sql, params);

  const [profile, trees, photos, comments, follows, likes, badges, consents] =
    await Promise.all([
      q(`SELECT id, email, username, display_name, bio, avatar_url, role,
                birth_year, points, level, location_label, created_at
           FROM users WHERE id = $1`, [userId]),
      q(`SELECT t.*, ST_Y(el.exact_geom::geometry) AS exact_lat,
                ST_X(el.exact_geom::geometry) AS exact_lng
           FROM trees t
           LEFT JOIN tree_exact_locations el ON el.tree_id = t.id
          WHERE t.owner_id = $1 AND t.deleted_at IS NULL`, [userId]),
      q(`SELECT p.* FROM tree_photos p
           JOIN trees t ON t.id = p.tree_id WHERE t.owner_id = $1`, [userId]),
      q(`SELECT id, tree_id, body, created_at FROM comments WHERE author_id = $1`, [userId]),
      q(`SELECT followee_id, created_at FROM follows WHERE follower_id = $1`, [userId]),
      q(`SELECT tree_id, created_at FROM likes WHERE user_id = $1`, [userId]),
      q(`SELECT b.code, b.name, ub.awarded_at FROM user_badges ub
           JOIN badges b ON b.id = ub.badge_id WHERE ub.user_id = $1`, [userId]),
      q(`SELECT kind, version, granted, created_at FROM consents WHERE user_id = $1`, [userId]),
    ]);

  return {
    exportedAt: new Date().toISOString(),
    schema: 'mwavuli.export/v1',
    profile: profile.rows[0] ?? null,
    trees: trees.rows,
    photos: photos.rows,
    comments: comments.rows,
    follows: follows.rows,
    likes: likes.rows,
    badges: badges.rows,
    consents: consents.rows,
  };
}

/** Flatten the trees section to CSV for the `format=csv` variant. */
export function treesToCsv(trees: Array<Record<string, unknown>>): string {
  const cols = [
    'id', 'common_name', 'scientific_name', 'health', 'height_m', 'girth_m',
    'features', 'visibility', 'is_fuzzy', 'exact_lat', 'exact_lng', 'created_at',
  ];
  const esc = (v: unknown) => {
    const s = v == null ? '' : Array.isArray(v) ? v.join('|') : String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const header = cols.join(',');
  const lines = trees.map((t) => cols.map((c) => esc(t[c])).join(','));
  return [header, ...lines].join('\n');
}
