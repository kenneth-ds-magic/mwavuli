-- 015_password_resets.sql
-- Password reset verification codes and tokens.

CREATE TABLE IF NOT EXISTS password_resets (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reset_code   text NOT NULL,
  expires_at   timestamptz NOT NULL,
  used_at      timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS password_resets_user_code_idx ON password_resets(user_id, reset_code) WHERE used_at IS NULL;
