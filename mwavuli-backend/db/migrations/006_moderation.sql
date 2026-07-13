-- 006_moderation.sql
-- Reporting, moderation actions, and user blocks — powers the admin dashboard.

CREATE TYPE report_target AS ENUM ('tree', 'comment', 'user');
CREATE TYPE report_reason AS ENUM (
  'inaccurate_id', 'wrong_location', 'spam', 'offensive',
  'sensitive_species', 'privacy', 'other');
CREATE TYPE report_status AS ENUM ('open', 'reviewing', 'actioned', 'dismissed');
CREATE TYPE mod_action   AS ENUM ('hide', 'remove', 'warn', 'ban', 'dismiss', 'restore');

CREATE TABLE reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid REFERENCES users(id) ON DELETE SET NULL,
  target_type report_target NOT NULL,
  target_id   uuid NOT NULL,
  reason      report_reason NOT NULL,
  details     text,
  status      report_status NOT NULL DEFAULT 'open',
  created_at  timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolver_id uuid REFERENCES users(id) ON DELETE SET NULL
);
CREATE INDEX reports_open_idx ON reports (created_at DESC) WHERE status = 'open';
CREATE INDEX reports_target_idx ON reports (target_type, target_id);

CREATE TABLE moderation_actions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  moderator_id uuid NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  report_id    uuid REFERENCES reports(id) ON DELETE SET NULL,
  target_type  report_target NOT NULL,
  target_id    uuid NOT NULL,
  action       mod_action NOT NULL,
  notes        text,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX mod_actions_target_idx ON moderation_actions (target_type, target_id);

CREATE TABLE user_blocks (
  blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CONSTRAINT no_self_block CHECK (blocker_id <> blocked_id)
);
