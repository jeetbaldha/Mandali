# PostgreSQL persistence

Run `npm run migrate` from `server/`. The migration runner applies sorted SQL files
in one transaction under an advisory migration lock, recording names in
`schema_migrations`. Re-running is safe. Do not edit a migration already deployed;
add a new numbered migration for future schema changes.

`001_initial.sql` creates users, hashed expiring sessions, rooms, room_players,
games, game_rounds, player_hands, player_actions, transactions, votes, game_results
and commands. UUIDs identify entities; bigint stores nonnegative virtual points.
Contribution uniqueness is game/player/round; ballot uniqueness is game/ballot/voter.

The room aggregate and normalized history commit in the same database transaction.
Room row locks serialize mutations. Command IDs and request hashes prevent retried
or conflicting commands from double-charging. Transactions distinguish INITIAL,
BALANCE_ADD, CONTRIBUTION and PAYOUT. Additions never enter the pot.

Private hands and votes are server-side data. HTTP history does not return cards;
Socket.IO snapshots redact hands and open ballots by recipient. Use a restricted
PostgreSQL role in production, encrypted transport, encrypted backups and a defined
retention policy. Local Compose binds PostgreSQL only to loopback on port 55432.
