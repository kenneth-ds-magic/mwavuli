-- 011_saved_trees.sql — user bookmarks / saved collection entries.

CREATE TABLE saved_trees (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tree_id    uuid NOT NULL REFERENCES trees(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, tree_id)
);
CREATE INDEX saved_trees_user_idx ON saved_trees (user_id, created_at DESC);

ALTER TABLE saved_trees ENABLE ROW LEVEL SECURITY;
CREATE POLICY saved_select ON saved_trees FOR SELECT
  USING (user_id = app.current_user_id());
CREATE POLICY saved_insert ON saved_trees FOR INSERT
  WITH CHECK (user_id = app.current_user_id());
CREATE POLICY saved_delete ON saved_trees FOR DELETE
  USING (user_id = app.current_user_id());
