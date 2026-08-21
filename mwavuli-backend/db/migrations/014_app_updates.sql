-- Migration 014: App updates table for mandatory version enforcement
CREATE TABLE IF NOT EXISTS updates (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  app_version   text NOT NULL UNIQUE,
  link          text NOT NULL,
  release_notes text NOT NULL DEFAULT '',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS updates_created_idx ON updates (created_at DESC);

-- Seed default initial version
INSERT INTO updates (app_version, link, release_notes)
VALUES ('0.1.0', 'http://129.205.2.218/mwavuli/download/app-latest.apk', 'Initial release of Mwavuli')
ON CONFLICT (app_version) DO NOTHING;
