CREATE TABLE users (
  id uuid PRIMARY KEY,
  display_name text NOT NULL CHECK (length(display_name) BETWEEN 1 AND 30),
  avatar text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE session_tokens (
  token_hash text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id),
  expires_at timestamptz NOT NULL
);
CREATE INDEX session_tokens_user_idx ON session_tokens(user_id);
CREATE TABLE rooms (
  id uuid PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  host_id uuid NOT NULL REFERENCES users(id),
  version integer NOT NULL DEFAULT 0,
  state jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE room_players (
  room_id uuid NOT NULL REFERENCES rooms(id),
  user_id uuid NOT NULL REFERENCES users(id),
  seat integer NOT NULL CHECK (seat BETWEEN 0 AND 9),
  balance bigint NOT NULL CHECK (balance >= 0),
  active boolean NOT NULL,
  PRIMARY KEY (room_id, user_id),
  UNIQUE (room_id, seat)
);
CREATE TABLE games (
  id uuid PRIMARY KEY,
  room_id uuid NOT NULL REFERENCES rooms(id),
  phase text NOT NULL,
  state jsonb NOT NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz
);
CREATE TABLE game_rounds (
  game_id uuid NOT NULL REFERENCES games(id),
  round_number integer NOT NULL CHECK (round_number > 0),
  call_amount bigint NOT NULL CHECK (call_amount >= 0),
  dealer_id uuid NOT NULL REFERENCES users(id),
  PRIMARY KEY (game_id, round_number)
);
CREATE TABLE player_hands (
  game_id uuid NOT NULL REFERENCES games(id),
  user_id uuid NOT NULL REFERENCES users(id),
  cards jsonb NOT NULL,
  PRIMARY KEY (game_id, user_id)
);
CREATE TABLE player_actions (
  id uuid PRIMARY KEY,
  room_id uuid NOT NULL REFERENCES rooms(id),
  game_id uuid REFERENCES games(id),
  user_id uuid NOT NULL REFERENCES users(id),
  kind text NOT NULL,
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE transactions (
  id uuid PRIMARY KEY,
  room_id uuid NOT NULL REFERENCES rooms(id),
  game_id uuid REFERENCES games(id),
  user_id uuid NOT NULL REFERENCES users(id),
  kind text NOT NULL CHECK (kind IN ('INITIAL', 'BALANCE_ADD', 'CONTRIBUTION', 'PAYOUT')),
  round_number integer,
  amount bigint NOT NULL CHECK (amount >= 0),
  balance_after bigint NOT NULL CHECK (balance_after >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX one_contribution_per_round ON transactions(game_id, user_id, round_number)
WHERE kind = 'CONTRIBUTION';
CREATE TABLE votes (
  game_id uuid NOT NULL REFERENCES games(id),
  ballot integer NOT NULL,
  voter_id uuid NOT NULL REFERENCES users(id),
  choice text NOT NULL,
  PRIMARY KEY (game_id, ballot, voter_id)
);
CREATE TABLE game_results (
  game_id uuid PRIMARY KEY REFERENCES games(id),
  result jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE commands (
  user_id uuid NOT NULL REFERENCES users(id),
  command_id uuid NOT NULL,
  request_hash text NOT NULL,
  room_id uuid REFERENCES rooms(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, command_id)
);
