-- Community ID verification votes (distinct users per tree).
CREATE TABLE tree_verifications (
  tree_id    uuid NOT NULL REFERENCES trees(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tree_id, user_id)
);
CREATE INDEX tree_verifications_tree_idx ON tree_verifications (tree_id);
