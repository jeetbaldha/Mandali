CREATE TABLE voice_revocations (
  room_id uuid NOT NULL REFERENCES rooms(id),
  user_id uuid NOT NULL REFERENCES users(id),
  revoked_before bigint NOT NULL,
  retry_after timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(room_id, user_id)
);
