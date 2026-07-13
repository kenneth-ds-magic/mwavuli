-- 001_extensions.sql
-- Required Postgres extensions. Run once per database.

CREATE EXTENSION IF NOT EXISTS postgis;        -- geospatial types + indexes
CREATE EXTENSION IF NOT EXISTS pgcrypto;       -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;         -- case-insensitive email/username
CREATE EXTENSION IF NOT EXISTS pg_trgm;        -- fuzzy text search on species/place

-- Helper schema for app-scoped functions used by row-level security.
CREATE SCHEMA IF NOT EXISTS app;

-- The API sets these per-request with `SET LOCAL app.user_id = '...'`,
-- `SET LOCAL app.user_role = '...'` inside the transaction. RLS policies read
-- them through these helpers. When unset (e.g. anonymous), they return safe
-- defaults.
CREATE OR REPLACE FUNCTION app.current_user_id() RETURNS uuid
  LANGUAGE sql STABLE AS $$
    SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION app.current_user_role() RETURNS text
  LANGUAGE sql STABLE AS $$
    SELECT COALESCE(NULLIF(current_setting('app.user_role', true), ''), 'anon')
$$;

CREATE OR REPLACE FUNCTION app.is_staff() RETURNS boolean
  LANGUAGE sql STABLE AS $$
    SELECT app.current_user_role() IN ('moderator', 'admin')
$$;
