import { PoolClient } from 'pg';

/** JS mirror of the SQL fuzzing (uniform within `radiusM`). */
export function fuzz(lat: number, lng: number, radiusM = 500) {
  const az = 2 * Math.PI * Math.random();
  const dist = radiusM * Math.sqrt(Math.random());
  const dLat = (dist * Math.cos(az)) / 111_320;
  const dLng = (dist * Math.sin(az)) / (111_320 * Math.cos((lat * Math.PI) / 180));
  return { lat: lat + dLat, lng: lng + dLng };
}

/**
 * Store the exact point (access-controlled table) and refresh the public
 * fuzzy point atomically via the DB helper. The caller's transaction must be
 * running as the tree owner (RLS) or staff.
 */
export async function setTreeLocation(
  c: PoolClient,
  treeId: string,
  lat: number,
  lng: number,
  accuracyM: number | null,
  isFuzzy: boolean,
) {
  await c.query('SELECT app.set_tree_location($1,$2,$3,$4,$5)', [
    treeId, lat, lng, accuracyM, isFuzzy,
  ]);
}
