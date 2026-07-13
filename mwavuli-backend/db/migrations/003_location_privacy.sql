-- 003_location_privacy.sql
-- The exact-coordinates table is the crux of the location-privacy model.
-- It is PHYSICALLY SEPARATE from `trees`, and access is gated by RLS so only
-- the owner and staff (moderator/admin) can read precise GPS. Every read is
-- expected to be audited by the API (see audit_log in 007).

CREATE TABLE tree_exact_locations (
  tree_id     uuid PRIMARY KEY REFERENCES trees(id) ON DELETE CASCADE,
  exact_geom  geography(Point, 4326) NOT NULL,
  accuracy_m  numeric(6,1),
  captured_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX tree_exact_gix ON tree_exact_locations USING gist (exact_geom);

-- Randomise a point uniformly within `radius_m` (default 500 m). Used to derive
-- the public fuzzy point from the exact one. Mirrors the client-side fuzzing so
-- the exact point can be recomputed-safe server-side as defence in depth.
CREATE OR REPLACE FUNCTION app.fuzz_point(
  exact geography, radius_m double precision DEFAULT 500)
  RETURNS geography
  LANGUAGE plpgsql VOLATILE AS $$
DECLARE
  azimuth  double precision := 2 * pi() * random();
  distance double precision := radius_m * sqrt(random());
BEGIN
  -- ST_Project works on geography and returns a geography point.
  RETURN ST_Project(exact, distance, azimuth);
END $$;

-- Convenience: safely upsert an exact point AND refresh the public fuzzy point
-- in one call, keeping the two consistent.
CREATE OR REPLACE FUNCTION app.set_tree_location(
  p_tree_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_accuracy_m double precision,
  p_is_fuzzy boolean)
  RETURNS void
  LANGUAGE plpgsql AS $$
DECLARE
  g geography := ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography;
BEGIN
  INSERT INTO tree_exact_locations (tree_id, exact_geom, accuracy_m)
  VALUES (p_tree_id, g, p_accuracy_m)
  ON CONFLICT (tree_id)
  DO UPDATE SET exact_geom = EXCLUDED.exact_geom,
                accuracy_m = EXCLUDED.accuracy_m,
                captured_at = now();

  UPDATE trees
     SET fuzzy_geom = CASE WHEN p_is_fuzzy THEN app.fuzz_point(g, 500) ELSE g END,
         is_fuzzy   = p_is_fuzzy
   WHERE id = p_tree_id;
END $$;
