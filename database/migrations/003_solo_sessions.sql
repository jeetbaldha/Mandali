-- Practice opponents are seats, not fabricated human identities or online rooms.
CREATE TABLE solo_sessions (
  owner_id uuid PRIMARY KEY REFERENCES users(id),
  id uuid NOT NULL UNIQUE,
  state jsonb NOT NULL,
  next_action_at bigint,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX solo_due_idx ON solo_sessions(next_action_at) WHERE next_action_at IS NOT NULL;
CREATE TABLE solo_commands (
  owner_id uuid NOT NULL REFERENCES users(id),
  command_id uuid NOT NULL,
  request_hash text NOT NULL,
  PRIMARY KEY(owner_id, command_id)
);
CREATE TABLE solo_transactions (
  id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES users(id),
  session_id uuid NOT NULL,
  player_id uuid NOT NULL,
  kind text NOT NULL,
  amount bigint NOT NULL CHECK(amount >= 0),
  balance_after bigint NOT NULL CHECK(balance_after >= 0),
  game_id uuid,
  created_at timestamptz NOT NULL
);
CREATE INDEX solo_transactions_owner_idx ON solo_transactions(owner_id,created_at DESC);
CREATE TABLE solo_results (
  game_id uuid PRIMARY KEY,
  owner_id uuid NOT NULL REFERENCES users(id),
  result jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
