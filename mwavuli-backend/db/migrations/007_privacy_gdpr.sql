-- 007_privacy_gdpr.sql
-- Consent tracking, data-portability (export), erasure (delete), and the
-- audit log that records privileged reads (e.g. exact coordinates).

CREATE TYPE consent_kind AS ENUM ('tos', 'privacy', 'coppa_guardian');

CREATE TABLE consents (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind       consent_kind NOT NULL,
  version    text NOT NULL,               -- e.g. 'privacy-2026-05'
  granted    boolean NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX consents_user_idx ON consents (user_id, kind, created_at DESC);

-- GDPR Art. 20 — data portability.
CREATE TYPE export_status AS ENUM ('queued','processing','ready','failed','expired');
CREATE TYPE export_format AS ENUM ('json','csv');

CREATE TABLE data_export_jobs (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  format       export_format NOT NULL DEFAULT 'json',
  status       export_status NOT NULL DEFAULT 'queued',
  file_key     text,                       -- private object key of the archive
  download_url text,                        -- short-lived signed URL
  requested_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  expires_at   timestamptz                  -- signed URL / file expiry
);
CREATE INDEX export_jobs_user_idx ON data_export_jobs (user_id, requested_at DESC);

-- GDPR Art. 17 — right to erasure. Requests schedule a purge 30 days out
-- (grace period; user can cancel). A worker performs the hard delete.
CREATE TYPE deletion_status AS ENUM ('scheduled','cancelled','completed');

CREATE TABLE account_deletion_requests (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status       deletion_status NOT NULL DEFAULT 'scheduled',
  requested_at timestamptz NOT NULL DEFAULT now(),
  purge_after  timestamptz NOT NULL DEFAULT now() + interval '30 days',
  completed_at timestamptz
);
CREATE UNIQUE INDEX deletion_active_idx ON account_deletion_requests (user_id)
  WHERE status = 'scheduled';

-- Tamper-evident audit trail. Privileged reads of exact coordinates, exports,
-- deletions, and moderation actions are written here.
CREATE TABLE audit_log (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  actor_id   uuid REFERENCES users(id) ON DELETE SET NULL,
  action     text NOT NULL,                -- 'read_exact_location','export.request'
  entity     text,
  entity_id  uuid,
  ip         inet,
  user_agent text,
  metadata   jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_entity_idx ON audit_log (entity, entity_id, created_at DESC);
CREATE INDEX audit_actor_idx  ON audit_log (actor_id, created_at DESC);
