-- 005_gamification.sql
-- Badges, points ledger, and the activity feed.

CREATE TABLE badges (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code        text UNIQUE NOT NULL,           -- 'oak_keeper', 'first_sprout'
  name        text NOT NULL,
  description text,
  icon        text,
  -- Machine-checkable rule, evaluated by the awarding job, e.g.
  -- {"metric":"species_count","species":"Quercus","gte":10}
  criteria    jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE user_badges (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_id   uuid NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
  awarded_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, badge_id)
);

-- Append-only ledger; users.points is the running total.
CREATE TABLE points_ledger (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delta      int NOT NULL,
  reason     text NOT NULL,                   -- 'log_tree', 'id_verified', ...
  tree_id    uuid REFERENCES trees(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX points_ledger_user_idx ON points_ledger (user_id, created_at DESC);

CREATE OR REPLACE FUNCTION app.apply_points() RETURNS trigger
  LANGUAGE plpgsql AS $$
BEGIN
  UPDATE users SET points = points + NEW.delta WHERE id = NEW.user_id;
  RETURN NEW;
END $$;
CREATE TRIGGER points_apply AFTER INSERT ON points_ledger
  FOR EACH ROW EXECUTE FUNCTION app.apply_points();

CREATE TYPE activity_verb AS ENUM (
  'logged_tree', 'earned_badge', 'verified_id', 'commented', 'followed');

CREATE TABLE activity (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  verb        activity_verb NOT NULL,
  object_type text,                            -- 'tree','badge','comment','user'
  object_id   uuid,
  metadata    jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX activity_recent_idx ON activity (created_at DESC);
CREATE INDEX activity_actor_idx  ON activity (actor_id, created_at DESC);

-- Weekly leaderboard, materialised on demand (refresh nightly in prod).
CREATE OR REPLACE VIEW leaderboard_week AS
  SELECT u.id, u.username, u.display_name, u.avatar_url,
         count(t.id) AS logs
    FROM users u
    JOIN trees t ON t.owner_id = u.id
   WHERE t.created_at >= now() - interval '7 days'
     AND t.deleted_at IS NULL
     AND u.deleted_at IS NULL
   GROUP BY u.id
   ORDER BY logs DESC;
