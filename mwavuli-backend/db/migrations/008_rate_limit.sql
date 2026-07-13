-- 008_rate_limit.sql
-- API keys (for programmatic/partner access) and a DB-backed rate-limit
-- counter used as a fallback when Redis is unavailable.

CREATE TABLE api_keys (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       text NOT NULL,
  key_hash   text NOT NULL,                 -- sha-256 of the presented key
  scopes     text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  last_used  timestamptz
);
CREATE INDEX api_keys_user_idx ON api_keys (user_id) WHERE revoked_at IS NULL;

-- Fixed-window counters. Primary rate limiting is in Redis (see api plugin);
-- this table is the durable fallback and supports per-subject inspection.
CREATE TABLE rate_limit_counters (
  bucket       text NOT NULL,               -- 'ip:1.2.3.4' | 'user:<uuid>'
  route        text NOT NULL,               -- 'POST /v1/trees'
  window_start timestamptz NOT NULL,
  count        int NOT NULL DEFAULT 0,
  PRIMARY KEY (bucket, route, window_start)
);
CREATE INDEX rlc_window_idx ON rate_limit_counters (window_start);

-- Atomic increment-and-return, used by the fallback limiter.
CREATE OR REPLACE FUNCTION app.rate_hit(
  p_bucket text, p_route text, p_window_start timestamptz)
  RETURNS int
  LANGUAGE plpgsql AS $$
DECLARE new_count int;
BEGIN
  INSERT INTO rate_limit_counters (bucket, route, window_start, count)
  VALUES (p_bucket, p_route, p_window_start, 1)
  ON CONFLICT (bucket, route, window_start)
  DO UPDATE SET count = rate_limit_counters.count + 1
  RETURNING count INTO new_count;
  RETURN new_count;
END $$;
