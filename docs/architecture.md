# Architecture

The existing Flutter application remains in `card_game_flutter_application/`.
Sibling `server/`, `database/` and `docs/` directories form the monorepo.

Flutter uses feature-separated connection/session and voice controllers plus lobby,
table, reveal, voting, result and history UI. The client receives personalized
snapshots and sends commands; it never creates cards, computes a payout or authorizes
its own balance. A one-second UI timer displays the server deadline.

Express handles guest sessions and private history. Socket.IO transports commands
and versioned room snapshots. PostgreSQL holds normalized audit tables plus a room
aggregate used to restore state atomically. LiveKit provides configurable WebRTC voice.

Each command authenticates the token, validates its schema, locks the actor command
namespace and room row, checks the expected version and authorizes the action.
The state, ledger, votes and command deduplication key commit together. Snapshots are
published after commit. Exact duplicate commands return current state without
repeating their effects. Private cards and open vote counts are removed per recipient.

Timers store server start/end timestamps in PostgreSQL. The worker polls every 250ms.
Restart recovery expires overdue phases without replaying a charge. A disconnected
client keeps its identity via secure storage and resubscribes for server state.

The current deployment is one authoritative server process, enforced through a
PostgreSQL advisory lock. A second authority fails startup. Horizontal scaling needs
room partitioning plus a shared Socket.IO adapter; additional replicas alone are unsafe.

The engine supports one hand at a time per room. Each hand has a stable dealer and
cards, multiple payment rounds, optional Show, review, hidden voting, one tie-break,
settlement or a paused unresolved outcome. The next hand rotates dealer among selected
active seats and carries current balances. See rules.md for all approved policies.

Tests cover domain invariants, PostgreSQL transactions, real Socket.IO clients,
capacity/security/reconnect/restart and responsive Flutter layouts. Physical voice,
iOS compilation/signing, sustained network loss and production load testing remain
release validation tasks. See README.md and voice.md for exact setup and boundaries.
