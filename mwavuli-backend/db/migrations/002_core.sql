-- 002_core.sql
-- Identity, species reference, trees, and photos.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
CREATE TYPE user_role       AS ENUM ('user', 'moderator', 'admin');
CREATE TYPE tree_health     AS ENUM ('healthy', 'stressed', 'dead', 'unknown');
CREATE TYPE tree_visibility AS ENUM ('public', 'followers', 'private');
CREATE TYPE tree_status     AS ENUM ('active', 'hidden', 'removed');
CREATE TYPE photo_status    AS ENUM ('pending', 'processed', 'failed');

-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------
CREATE TABLE users (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email          citext UNIQUE NOT NULL,
  username       citext UNIQUE NOT NULL,
  password_hash  text NOT NULL,                 -- argon2id
  display_name   text NOT NULL,
  bio            text,
  avatar_url     text,
  role           user_role NOT NULL DEFAULT 'user',
  -- COPPA: we store only the birth year (data minimisation) and a boolean.
  birth_year     int,
  is_13_plus     boolean NOT NULL DEFAULT true,
  location_label text,
  points         int NOT NULL DEFAULT 0,
  level          int NOT NULL DEFAULT 1,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  deleted_at     timestamptz,                    -- soft-delete; hard purge by job
  CONSTRAINT users_min_age CHECK (is_13_plus = true)  -- enforce 13+ at signup
);
CREATE INDEX users_active_idx ON users (id) WHERE deleted_at IS NULL;

-- Refresh tokens (access tokens are stateless JWTs; refresh tokens are stored
-- hashed so they can be revoked).
CREATE TABLE refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash  text NOT NULL,                     -- sha-256 of the opaque token
  user_agent  text,
  ip          inet,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_user_idx ON refresh_tokens (user_id) WHERE revoked_at IS NULL;

-- ---------------------------------------------------------------------------
-- Species reference (curated + community-extended)
-- ---------------------------------------------------------------------------
CREATE TABLE species (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  common_name     text NOT NULL,
  scientific_name text UNIQUE NOT NULL,
  family          text,
  native_range    text,
  description     text,
  gbif_id         bigint,                         -- link to GBIF backbone
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX species_sci_trgm ON species USING gin (scientific_name gin_trgm_ops);
CREATE INDEX species_common_trgm ON species USING gin (common_name gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- Trees — the public record. The PUBLIC point is fuzzy_geom. The exact GPS
-- point lives in tree_exact_locations (003), protected by RLS.
-- ---------------------------------------------------------------------------
CREATE TABLE trees (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  species_id      uuid REFERENCES species(id) ON DELETE SET NULL,
  common_name     text NOT NULL,
  scientific_name text,
  height_m        numeric(5,1),
  girth_m         numeric(5,2),
  age_estimate    text,
  health          tree_health NOT NULL DEFAULT 'unknown',
  description     text,
  features        text[] NOT NULL DEFAULT '{}',
  confidence      int CHECK (confidence BETWEEN 0 AND 100),
  verified        boolean NOT NULL DEFAULT false, -- community-verified ID
  visibility      tree_visibility NOT NULL DEFAULT 'public',
  is_fuzzy        boolean NOT NULL DEFAULT true,
  -- The point safe to expose publicly (randomised within ~500 m when fuzzy).
  fuzzy_geom      geography(Point, 4326) NOT NULL,
  status          tree_status NOT NULL DEFAULT 'active',
  like_count      int NOT NULL DEFAULT 0,
  comment_count   int NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  deleted_at      timestamptz
);
CREATE INDEX trees_fuzzy_gix   ON trees USING gist (fuzzy_geom);
CREATE INDEX trees_owner_idx   ON trees (owner_id);
CREATE INDEX trees_species_idx ON trees (species_id);
CREATE INDEX trees_feed_idx    ON trees (created_at DESC)
  WHERE status = 'active' AND visibility = 'public' AND deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- Photos. Originals land in a private bucket; the serverless pipeline strips
-- EXIF/GPS and writes public thumbnails, then flips status to 'processed'.
-- ---------------------------------------------------------------------------
CREATE TABLE tree_photos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tree_id       uuid NOT NULL REFERENCES trees(id) ON DELETE CASCADE,
  organ         text CHECK (organ IN ('whole','bark','leaf','flower','fruit')),
  storage_key   text NOT NULL,                    -- private original object key
  public_url    text,                             -- EXIF-stripped derivative
  thumb_url     text,
  width         int,
  height        int,
  exif_stripped boolean NOT NULL DEFAULT false,
  status        photo_status NOT NULL DEFAULT 'pending',
  position      int NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX tree_photos_tree_idx ON tree_photos (tree_id, position);

-- Keep updated_at fresh.
CREATE OR REPLACE FUNCTION app.touch_updated_at() RETURNS trigger
  LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

CREATE TRIGGER trees_touch    BEFORE UPDATE ON trees
  FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
CREATE TRIGGER users_touch    BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION app.touch_updated_at();
