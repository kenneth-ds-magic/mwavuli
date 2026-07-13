-- 004_social.sql
-- Follows, comments, likes.

CREATE TYPE comment_status AS ENUM ('visible', 'hidden', 'removed');

CREATE TABLE follows (
  follower_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id),
  CONSTRAINT no_self_follow CHECK (follower_id <> followee_id)
);
CREATE INDEX follows_followee_idx ON follows (followee_id);

CREATE TABLE comments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tree_id    uuid NOT NULL REFERENCES trees(id) ON DELETE CASCADE,
  author_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body       text NOT NULL CHECK (length(body) BETWEEN 1 AND 2000),
  status     comment_status NOT NULL DEFAULT 'visible',
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX comments_tree_idx ON comments (tree_id, created_at DESC)
  WHERE status = 'visible';

CREATE TABLE likes (
  tree_id    uuid NOT NULL REFERENCES trees(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tree_id, user_id)
);

-- Denormalised counters kept in sync by triggers.
CREATE OR REPLACE FUNCTION app.bump_like_count() RETURNS trigger
  LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE trees SET like_count = like_count + 1 WHERE id = NEW.tree_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE trees SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.tree_id;
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER likes_count AFTER INSERT OR DELETE ON likes
  FOR EACH ROW EXECUTE FUNCTION app.bump_like_count();

CREATE OR REPLACE FUNCTION app.bump_comment_count() RETURNS trigger
  LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE trees SET comment_count = comment_count + 1 WHERE id = NEW.tree_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE trees SET comment_count = GREATEST(comment_count - 1, 0) WHERE id = OLD.tree_id;
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER comments_count AFTER INSERT OR DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION app.bump_comment_count();
