-- 009_rls_policies.sql
-- Row-level security. The API connects as `mwavuli_app`, a NOSUPERUSER,
-- NOBYPASSRLS role, and sets `app.user_id` / `app.user_role` per request. These
-- policies are the last line of defence for the privacy model — even a bug in
-- the API cannot leak exact coordinates or private trees.

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mwavuli_app') THEN
    CREATE ROLE mwavuli_app LOGIN PASSWORD 'change-me-in-prod'
      NOSUPERUSER NOCREATEDB NOBYPASSRLS;
  END IF;
END $$;

GRANT USAGE ON SCHEMA public, app TO mwavuli_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO mwavuli_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO mwavuli_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA app TO mwavuli_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO mwavuli_app;

-- === trees ===============================================================
ALTER TABLE trees ENABLE ROW LEVEL SECURITY;

CREATE POLICY trees_select ON trees FOR SELECT USING (
  deleted_at IS NULL AND (
    app.is_staff()
    OR owner_id = app.current_user_id()
    OR (status = 'active' AND (
         visibility = 'public'
         OR (visibility = 'followers' AND EXISTS (
              SELECT 1 FROM follows f
               WHERE f.followee_id = trees.owner_id
                 AND f.follower_id = app.current_user_id()))
       ))
  )
);
CREATE POLICY trees_insert ON trees FOR INSERT
  WITH CHECK (owner_id = app.current_user_id());
CREATE POLICY trees_modify ON trees FOR UPDATE
  USING (owner_id = app.current_user_id() OR app.is_staff());
CREATE POLICY trees_delete ON trees FOR DELETE
  USING (owner_id = app.current_user_id() OR app.is_staff());

-- === tree_exact_locations (the crux) =====================================
ALTER TABLE tree_exact_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE tree_exact_locations FORCE ROW LEVEL SECURITY;

CREATE POLICY exact_read ON tree_exact_locations FOR SELECT USING (
  app.is_staff()
  OR EXISTS (SELECT 1 FROM trees t
              WHERE t.id = tree_exact_locations.tree_id
                AND t.owner_id = app.current_user_id())
);
CREATE POLICY exact_write ON tree_exact_locations FOR ALL USING (
  app.is_staff()
  OR EXISTS (SELECT 1 FROM trees t
              WHERE t.id = tree_exact_locations.tree_id
                AND t.owner_id = app.current_user_id())
) WITH CHECK (
  app.is_staff()
  OR EXISTS (SELECT 1 FROM trees t
              WHERE t.id = tree_exact_locations.tree_id
                AND t.owner_id = app.current_user_id())
);

-- === tree_photos (inherit tree visibility) ================================
ALTER TABLE tree_photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY photos_select ON tree_photos FOR SELECT USING (
  EXISTS (SELECT 1 FROM trees t WHERE t.id = tree_photos.tree_id)  -- RLS on trees applies
);
CREATE POLICY photos_write ON tree_photos FOR ALL USING (
  app.is_staff()
  OR EXISTS (SELECT 1 FROM trees t
              WHERE t.id = tree_photos.tree_id AND t.owner_id = app.current_user_id())
) WITH CHECK (
  app.is_staff()
  OR EXISTS (SELECT 1 FROM trees t
              WHERE t.id = tree_photos.tree_id AND t.owner_id = app.current_user_id())
);

-- === comments ============================================================
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
CREATE POLICY comments_select ON comments FOR SELECT USING (
  status = 'visible' OR author_id = app.current_user_id() OR app.is_staff()
);
CREATE POLICY comments_insert ON comments FOR INSERT
  WITH CHECK (author_id = app.current_user_id());
CREATE POLICY comments_modify ON comments FOR UPDATE
  USING (author_id = app.current_user_id() OR app.is_staff());
CREATE POLICY comments_delete ON comments FOR DELETE
  USING (author_id = app.current_user_id() OR app.is_staff());

-- === reports (reporter sees own; staff sees all) =========================
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY reports_insert ON reports FOR INSERT
  WITH CHECK (reporter_id = app.current_user_id());
CREATE POLICY reports_select ON reports FOR SELECT
  USING (reporter_id = app.current_user_id() OR app.is_staff());
CREATE POLICY reports_modify ON reports FOR UPDATE USING (app.is_staff());

-- Staff-only tables
ALTER TABLE moderation_actions ENABLE ROW LEVEL SECURITY;
CREATE POLICY modactions_staff ON moderation_actions FOR ALL
  USING (app.is_staff()) WITH CHECK (app.is_staff());

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_insert ON audit_log FOR INSERT WITH CHECK (true);
CREATE POLICY audit_select ON audit_log FOR SELECT USING (app.is_staff());
