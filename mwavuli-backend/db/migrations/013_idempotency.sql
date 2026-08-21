-- Client transaction ID for idempotency & duplicate prevention.
ALTER TABLE trees ADD COLUMN IF NOT EXISTS client_tx_id text;
CREATE UNIQUE INDEX IF NOT EXISTS trees_owner_client_tx_idx
  ON trees (owner_id, client_tx_id)
  WHERE client_tx_id IS NOT NULL;
