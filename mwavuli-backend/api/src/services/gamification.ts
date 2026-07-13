import { PoolClient } from 'pg';

export const LEVEL_NAMES: Record<number, string> = {
  1: 'Seedling',
  2: 'Sprout',
  3: 'Sapling',
  4: 'Sapling Scout',
  5: 'Canopy Ranger',
  6: 'Forest Guardian',
};

/** Cumulative points required to reach each level (index 0 = level 1). */
export const LEVEL_THRESHOLDS = [0, 100, 300, 600, 1000, 1500, 2200, 3000];

export function levelFromPoints(points: number): number {
  let level = 1;
  for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
    if (points >= LEVEL_THRESHOLDS[i]) {
      level = i + 1;
      break;
    }
  }
  return Math.min(level, Math.max(...Object.keys(LEVEL_NAMES).map(Number)));
}

export function levelName(level: number): string {
  return LEVEL_NAMES[level] ?? `Level ${level}`;
}

export function levelProgress(points: number) {
  const level = levelFromPoints(points);
  const floor = LEVEL_THRESHOLDS[level - 1] ?? 0;
  const ceiling = LEVEL_THRESHOLDS[level] ?? floor + 500;
  const span = ceiling - floor;
  const progress = span > 0 ? (points - floor) / span : 1;
  return {
    level,
    levelName: levelName(level),
    nextLevel: level + 1,
    pointsToNextLevel: Math.max(0, ceiling - points),
    progress: Math.min(1, Math.max(0, progress)),
  };
}

/** Consecutive UTC days with at least one tree log, ending today or yesterday. */
export async function computeStreak(
  client: PoolClient,
  userId: string,
): Promise<number> {
  const { rows } = await client.query<{ day: Date }>(
    `SELECT DISTINCT (created_at AT TIME ZONE 'UTC')::date AS day
       FROM trees
      WHERE owner_id = $1 AND deleted_at IS NULL
      ORDER BY day DESC`,
    [userId],
  );
  if (!rows.length) return 0;

  const keys = new Set(rows.map((r) => dayKey(new Date(r.day))));

  const today = utcToday();
  const yesterday = new Date(today);
  yesterday.setUTCDate(yesterday.getUTCDate() - 1);

  let cursor: Date | null = null;
  if (keys.has(dayKey(today))) cursor = new Date(today);
  else if (keys.has(dayKey(yesterday))) cursor = new Date(yesterday);
  else return 0;

  let streak = 0;
  while (cursor && keys.has(dayKey(cursor))) {
    streak++;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return streak;
}

function utcToday(): Date {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

function dayKey(d: Date): string {
  return d.toISOString().slice(0, 10);
}
